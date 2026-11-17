package guard

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/prusa3d/prusa-connect/sdk/busapi"
	"github.com/prusa3d/prusa-connect/sdk/deviceapi"
	"github.com/prusa3d/prusa-connect/sdk/event"
	"github.com/prusa3d/prusa-connect/sdk/stateapi"
	"github.com/prusa3d/prusa-connect/sdk/storageapi"

	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/detect"
)

type fakeDevices struct {
	mu       sync.Mutex
	state    string
	commands []deviceapi.CommandParams
}

func (d *fakeDevices) Get(_ context.Context, p deviceapi.GetParams) (deviceapi.Device, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	raw, _ := json.Marshal(d.state)

	return deviceapi.Device{ID: p.ID, Connected: true, State: map[string]json.RawMessage{"/state": raw}}, nil
}

func (d *fakeDevices) Command(_ context.Context, p deviceapi.CommandParams) (deviceapi.Result, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	d.commands = append(d.commands, p)
	d.state = "PAUSED"

	return deviceapi.Result{OK: true}, nil
}

// fakeStorage serves a file in small chunks, to exercise the read loop.
type fakeStorage struct{ files map[string][]byte }

func (s fakeStorage) Read(_ context.Context, p storageapi.ReadParams) (storageapi.Chunk, error) {
	file := s.files[p.Storage+":"+p.Path]
	end := min(int(p.Offset)+3, len(file))

	return storageapi.Chunk{Data: file[p.Offset:end], Size: int64(len(file)), EOF: end == len(file)}, nil
}

type fakeRecords struct {
	mu   sync.Mutex
	data map[stateapi.Key][]byte
}

func (r *fakeRecords) Get(_ context.Context, k stateapi.Key) (stateapi.Value, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	v, ok := r.data[k]
	if !ok {
		return stateapi.Value{}, stateapi.ErrNoRecord
	}

	return stateapi.Value{Bytes: v, Version: 1}, nil
}

func (r *fakeRecords) Put(_ context.Context, k stateapi.Key, v []byte) (uint64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.data[k] = v

	return 1, nil
}

func (r *fakeRecords) Delete(_ context.Context, k stateapi.Key) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	delete(r.data, k)

	return nil
}

func (r *fakeRecords) List(_ context.Context, prefix stateapi.Key) ([]stateapi.Key, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	var out []stateapi.Key

	for k := range r.data {
		if strings.HasPrefix(string(k), string(prefix)+"/") {
			out = append(out, k)
		}
	}

	slices.Sort(out)

	return out, nil
}

type fakeEmitter struct{ emitted []string }

func (e *fakeEmitter) Emit(_ context.Context, endpoint, key string, _ any) error {
	e.emitted = append(e.emitted, endpoint+":"+key)

	return nil
}

// scripted answers the score its frame's bytes name, so a test writes the
// scores it wants.
type scripted struct{ resets int }

func (*scripted) Name() string { return "scripted" }
func (s *scripted) Reset(string) { s.resets++ }
func (*scripted) Detect(_ context.Context, _ string, jpeg []byte) (detect.Result, error) {
	var score float64
	if err := json.Unmarshal(jpeg, &score); err != nil {
		return detect.Result{}, err
	}

	return detect.Result{Score: score}, nil
}

type rig struct {
	guard   *Guard
	devices *fakeDevices
	storage fakeStorage
	records *fakeRecords
	emitter *fakeEmitter
	det     *scripted
	frame   int
	now     time.Time
}

func newRig(action Action) *rig {
	r := &rig{
		devices: &fakeDevices{state: "PRINTING"},
		storage: fakeStorage{files: map[string][]byte{}},
		records: &fakeRecords{data: map[stateapi.Key][]byte{}},
		emitter: &fakeEmitter{},
		det:     &scripted{},
		now:     time.Date(2026, 11, 17, 12, 0, 0, 0, time.UTC),
	}
	r.guard = New(r.devices, r.storage, NewIncidents(r.records), r.emitter, nil,
		slog.New(slog.NewTextHandler(io.Discard, nil)))
	r.guard.now = func() time.Time { return r.now }
	r.guard.Configure(Config{Detector: r.det, Params: detect.DefaultParams(), Action: action})

	return r
}

// shot stores one frame scoring score and judges it.
func (r *rig) shot(t *testing.T, score float64) {
	t.Helper()

	r.frame++
	r.now = r.now.Add(10 * time.Second)
	path := "camera/c1/" + r.now.Format("150405") + ".jpg"
	body, _ := json.Marshal(score)
	r.storage.files["snaps:"+path] = body

	if err := r.guard.Judge(context.Background(), Snapshot{
		Camera: "c1", Printer: "p1", Storage: "snaps", Path: path, Taken: r.now,
	}); err != nil {
		t.Fatal(err)
	}
}

func TestAFailingPrintIsPausedOnce(t *testing.T) {
	r := newRig(ActionPause)

	for range 10 {
		r.shot(t, 0.05)
	}

	if len(r.devices.commands) != 0 {
		t.Fatal("a good print was paused")
	}

	for range 10 {
		r.shot(t, 2)
	}

	if len(r.devices.commands) != 1 || r.devices.commands[0].Verb != verbPause || r.devices.commands[0].ID != "p1" {
		t.Fatalf("commands sent: %+v", r.devices.commands)
	}

	if !slices.Equal(r.emitter.emitted, []string{"failure:p1"}) {
		t.Fatalf("events: %v", r.emitter.emitted)
	}

	list, err := NewIncidents(r.records).List(context.Background(), "p1")
	if err != nil || len(list) != 1 || list[0].Outcome != "paused" || list[0].Storage != "snaps" {
		t.Fatalf("incidents: %+v, %v", list, err)
	}
}

func TestAResumedPrintStartsOver(t *testing.T) {
	r := newRig(ActionPause)

	for range 10 {
		r.shot(t, 0.05)
	}

	for range 5 {
		r.shot(t, 2)
	}

	// Paused now; the fake set PAUSED. A frame while paused resets.
	r.shot(t, 2)

	watches := r.guard.Watches()
	if len(watches) != 1 || watches[0].Acted || watches[0].Frames != 0 {
		t.Fatalf("after the pause: %+v", watches)
	}

	// The person looked and resumed: the same picture is the new normal.
	r.devices.state = "PRINTING"

	for range 20 {
		r.shot(t, 2)
	}

	if len(r.devices.commands) != 1 {
		t.Fatalf("the resumed print was paused again: %d commands", len(r.devices.commands))
	}
}

func TestNotifyOnlyRecords(t *testing.T) {
	r := newRig(ActionNotify)

	for range 10 {
		r.shot(t, 0.05)
	}

	for range 10 {
		r.shot(t, 2)
	}

	if len(r.devices.commands) != 0 {
		t.Fatal("notify paused the print")
	}

	list, _ := NewIncidents(r.records).List(context.Background(), "")
	if len(list) != 1 || list[0].Outcome != "reported" {
		t.Fatalf("incidents: %+v", list)
	}
}

func TestAnIdlePrinterIsNotJudged(t *testing.T) {
	r := newRig(ActionPause)
	r.devices.state = "IDLE"

	for range 20 {
		r.shot(t, 5)
	}

	if len(r.devices.commands) != 0 || r.guard.Watches()[0].Frames != 0 {
		t.Fatal("an idle printer was judged")
	}
}

func TestAStaleSnapshotIsSkipped(t *testing.T) {
	r := newRig(ActionPause)
	if err := r.guard.Judge(context.Background(), Snapshot{
		Camera: "c1", Printer: "p1", Storage: "snaps", Path: "x.jpg", Taken: r.now.Add(-time.Hour),
	}); err != nil {
		t.Fatal(err)
	}

	if len(r.guard.Watches()) != 0 {
		t.Fatal("a stale snapshot was judged")
	}
}

func TestResetGivesAFalseAlarmAnotherChance(t *testing.T) {
	r := newRig(ActionNotify)

	if err := r.guard.Reset("p1"); err == nil {
		t.Fatal("a reset of an unseen printer was accepted")
	}

	for range 10 {
		r.shot(t, 0.05)
	}

	for range 10 {
		r.shot(t, 2)
	}

	if err := r.guard.Reset("p1"); err != nil {
		t.Fatal(err)
	}

	if w := r.guard.Watches()[0]; w.Acted || w.Frames != 0 || w.Verdict != detect.VerdictWarmingUp {
		t.Fatalf("after reset: %+v", w)
	}
}

func TestIncidentsAreCapped(t *testing.T) {
	records := &fakeRecords{data: map[stateapi.Key][]byte{}}
	store := NewIncidents(records)
	at := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	for i := range keepIncidents + 7 {
		if _, err := store.Add(context.Background(), Incident{Printer: "p/1", Time: at.Add(time.Duration(i) * time.Minute)}); err != nil {
			t.Fatal(err)
		}
	}

	list, _ := store.List(context.Background(), "p/1")
	if len(list) != keepIncidents || !list[0].Time.After(list[1].Time) {
		t.Fatalf("kept %d, newest first: %v", len(list), list[0].Time)
	}
}

func TestRunReadsSnapshotEvents(t *testing.T) {
	r := newRig(ActionPause)

	var windows []busapi.Window

	for range 10 {
		r.now = r.now.Add(10 * time.Second)
		path := "camera/c1/" + r.now.Format("150405") + ".jpg"
		r.storage.files["snaps:"+path] = []byte("3")
		data, _ := json.Marshal(Snapshot{Camera: "c1", Printer: "p1", Storage: "snaps", Path: path, Taken: r.now})
		envelope, _ := json.Marshal(event.Envelope{Type: event.TypeCameraSnapshotCaptured, Data: data})
		windows = append(windows, busapi.Window{Events: []json.RawMessage{envelope}, Cursor: "c"})
	}

	ctx, cancel := context.WithCancel(context.Background())
	r.guard.subscribe = func(_ context.Context, p busapi.SubscribeParams, onWindow func(busapi.Window) error) error {
		if !slices.Equal(p.Types, []string{event.TypeCameraSnapshotCaptured}) {
			t.Errorf("subscribed to %v", p.Types)
		}

		for _, w := range windows {
			_ = onWindow(w)
		}

		cancel()

		return nil
	}

	r.guard.Run(ctx)

	if w := r.guard.Watches(); len(w) != 1 || w[0].Frames != 10 {
		t.Fatalf("watches: %+v", w)
	}
}

func TestFramesServeEachFrameUntilDone(t *testing.T) {
	frames := NewFrames("http://me:18491/")

	url, done, err := frames.Publish([]byte("jpeg"))
	if err != nil || !strings.HasPrefix(url, "http://me:18491/frames/") {
		t.Fatalf("%q, %v", url, err)
	}

	path := strings.TrimPrefix(url, "http://me:18491")
	get := func(p string) int {
		rec := httptest.NewRecorder()
		frames.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, p, nil))

		return rec.Code
	}

	if get(path) != http.StatusOK || get("/frames/guess.jpg") != http.StatusNotFound {
		t.Fatal("the frame is not served, or a guess is")
	}

	done()

	if get(path) != http.StatusNotFound {
		t.Fatal("a finished frame is still served")
	}

	if _, _, err := NewFrames("").Publish(nil); err == nil {
		t.Fatal("a frame was published with no base")
	}
}
