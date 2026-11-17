// Package guard follows every camera that takes periodic snapshots, scores
// each new picture while its printer prints, and pauses the print when the
// trend says it has failed.
//
// It runs in the extension's own process, so it watches with no browser open:
// the host publishes com.prusa.connect.camera.snapshot.captured for every
// stored snapshot, the event names the storage and path of the JPEG, and the
// module reads it back through the storage door.
package guard

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"slices"
	"sync"
	"time"

	"github.com/prusa3d/prusa-connect/sdk/busapi"
	"github.com/prusa3d/prusa-connect/sdk/deviceapi"
	"github.com/prusa3d/prusa-connect/sdk/event"
	"github.com/prusa3d/prusa-connect/sdk/storageapi"

	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/detect"
)

// The device verb that pauses a print, from the core's vocabulary.
const verbPause = "core.command.pause_print"

// maxFrameBytes bounds one snapshot read; the core itself stores at most
// 8 MiB per frame.
const maxFrameBytes = 8 << 20

// staleAfter is how old a snapshot event may be and still be judged. Events
// replayed after a restart describe a print that has moved on.
const staleAfter = 3 * time.Minute

// Action is what the guard does when a print is failing.
type Action string

// The actions.
const (
	ActionPause  Action = "pause"
	ActionNotify Action = "notify"
)

// Devices is the part of deviceapi.Client the guard uses.
type Devices interface {
	Get(ctx context.Context, params deviceapi.GetParams) (deviceapi.Device, error)
	Command(ctx context.Context, params deviceapi.CommandParams) (deviceapi.Result, error)
}

// Storage is the part of storageapi.Client the guard uses.
type Storage interface {
	Read(ctx context.Context, params storageapi.ReadParams) (storageapi.Chunk, error)
}

// Emitter publishes the module's own events.
type Emitter interface {
	Emit(ctx context.Context, endpoint, key string, data any) error
}

// Subscriber opens the event stream, as busapi.Subscribe does.
type Subscriber func(ctx context.Context, params busapi.SubscribeParams, onWindow func(busapi.Window) error) error

// Config is what the guard runs on.
type Config struct {
	Detector detect.Detector
	Params   detect.Params
	Action   Action
}

// Snapshot is the payload of com.prusa.connect.camera.snapshot.captured.
type Snapshot struct {
	Camera  string    `json:"camera"`
	Printer string    `json:"printer,omitempty"`
	Storage string    `json:"storage"`
	Path    string    `json:"path"`
	Bytes   int64     `json:"bytes"`
	Taken   time.Time `json:"taken"`
}

// Watch is what the guard knows about one camera right now.
type Watch struct {
	Camera   string         `json:"camera"`
	Printer  string         `json:"printer"`
	Printing bool           `json:"printing"`
	Verdict  detect.Verdict `json:"verdict"`
	Score    float64        `json:"score"`
	Excess   float64        `json:"excess"`
	Frames   int            `json:"frames"`
	Last     time.Time      `json:"last"`
	Error    string         `json:"error,omitempty"`
	// Acted is true once the guard acted on this print. It acts once per
	// print: a person who resumes has looked and decided.
	Acted bool `json:"acted"`

	tracker *detect.Tracker
}

// Guard follows the cameras.
type Guard struct {
	devices   Devices
	storage   Storage
	incidents *Incidents
	emitter   Emitter
	subscribe Subscriber
	log       *slog.Logger
	now       func() time.Time

	mu      sync.Mutex
	config  Config
	watches map[string]*Watch
	cursor  string
}

// New builds a guard. Configure must be called before Run judges a frame.
func New(devices Devices, storage Storage, incidents *Incidents, emitter Emitter,
	subscribe Subscriber, log *slog.Logger,
) *Guard {
	return &Guard{
		devices: devices, storage: storage, incidents: incidents, emitter: emitter,
		subscribe: subscribe, log: log, now: time.Now, watches: map[string]*Watch{},
	}
}

// Configure swaps the detector and the thresholds. Every camera starts over,
// because scores of different detectors do not compare.
func (g *Guard) Configure(config Config) {
	g.mu.Lock()
	defer g.mu.Unlock()

	g.config = config
	g.watches = map[string]*Watch{}
}

// Run follows the event stream until ctx ends, reconnecting with backoff.
func (g *Guard) Run(ctx context.Context) {
	params := busapi.SubscribeParams{Types: []string{event.TypeCameraSnapshotCaptured}}

	for wait := time.Second; ; {
		g.mu.Lock()
		params.Resume = g.cursor
		g.mu.Unlock()

		read := false
		err := g.subscribe(ctx, params, func(w busapi.Window) error {
			read = true

			for _, raw := range w.Events {
				g.handle(ctx, raw)
			}

			if w.Cursor != "" {
				g.mu.Lock()
				g.cursor = w.Cursor
				g.mu.Unlock()
			}

			return nil
		})

		if ctx.Err() != nil {
			return
		}

		if read {
			wait = time.Second
		}

		g.log.WarnContext(ctx, "the snapshot stream ended, following it again", "error", err, "wait", wait)

		select {
		case <-ctx.Done():
			return
		case <-time.After(wait):
		}

		wait = min(wait*2, time.Minute)
	}
}

// handle reads one envelope and judges its snapshot.
func (g *Guard) handle(ctx context.Context, raw json.RawMessage) {
	var envelope event.Envelope
	if err := json.Unmarshal(raw, &envelope); err != nil || envelope.Type != event.TypeCameraSnapshotCaptured {
		return
	}

	var shot Snapshot
	if err := json.Unmarshal(envelope.Data, &shot); err != nil || shot.Camera == "" || shot.Path == "" {
		g.log.WarnContext(ctx, "a snapshot event could not be read", "id", envelope.ID)

		return
	}

	if err := g.Judge(ctx, shot); err != nil {
		g.log.WarnContext(ctx, "a snapshot could not be judged", "camera", shot.Camera, "error", err)
	}
}

// Judge scores one stored snapshot and acts on the verdict.
func (g *Guard) Judge(ctx context.Context, shot Snapshot) error {
	g.mu.Lock()
	config := g.config
	g.mu.Unlock()

	if config.Detector == nil || shot.Printer == "" {
		// A camera pointed at no printer has nothing to pause.
		return nil
	}

	if !shot.Taken.IsZero() && g.now().Sub(shot.Taken) > staleAfter {
		return nil
	}

	printing, err := g.printing(ctx, shot.Printer)
	if err != nil {
		return g.fail(shot, fmt.Errorf("read printer %s: %w", shot.Printer, err))
	}

	watch := g.watch(shot, config)

	if !printing {
		// Between prints, and while paused, the next frame starts a new
		// baseline: a person who resumes a paused print has looked at it.
		g.mu.Lock()
		if watch.Printing || watch.tracker.Frames > 0 {
			config.Detector.Reset(shot.Camera)
		}
		*watch = Watch{Camera: shot.Camera, Printer: shot.Printer, Verdict: detect.VerdictWarmingUp,
			tracker: detect.NewTracker(config.Params)}
		g.mu.Unlock()

		return nil
	}

	frame, err := g.read(ctx, shot)
	if err != nil {
		return g.fail(shot, err)
	}

	result, err := config.Detector.Detect(ctx, shot.Camera, frame)
	if err != nil {
		return g.fail(shot, err)
	}

	at := shot.Taken
	if at.IsZero() {
		at = g.now()
	}

	g.mu.Lock()
	verdict := watch.tracker.Add(result.Score, at)
	watch.Printing = true
	watch.Verdict = verdict
	watch.Score = result.Score
	watch.Excess = watch.tracker.Excess()
	watch.Frames = watch.tracker.Frames
	watch.Last = at
	watch.Error = ""
	act := verdict == detect.VerdictFailing && !watch.Acted
	if act {
		watch.Acted = true
	}
	snapshot := *watch
	g.mu.Unlock()

	if act {
		g.act(ctx, config, shot, snapshot, result)
	}

	return nil
}

// act pauses the print, or only reports, and records the incident.
func (g *Guard) act(ctx context.Context, config Config, shot Snapshot, watch Watch, result detect.Result) {
	incident := Incident{
		Printer:  shot.Printer,
		Camera:   shot.Camera,
		Time:     watch.Last,
		Score:    result.Score,
		Excess:   watch.Excess,
		Detector: config.Detector.Name(),
		Action:   config.Action,
		Storage:  shot.Storage,
		Path:     shot.Path,
		Boxes:    result.Boxes,
	}

	if config.Action == ActionPause {
		answer, err := g.devices.Command(ctx, deviceapi.CommandParams{ID: shot.Printer, Verb: verbPause})

		switch {
		case err != nil:
			incident.Outcome = "pause failed: " + err.Error()
		case !answer.OK:
			incident.Outcome = "the printer refused to pause: " + answer.MachineReason
		default:
			incident.Outcome = "paused"
		}
	} else {
		incident.Outcome = "reported"
	}

	g.log.WarnContext(ctx, "a print looks failed",
		"printer", shot.Printer, "camera", shot.Camera, "score", result.Score, "outcome", incident.Outcome)

	stored, err := g.incidents.Add(ctx, incident)
	if err != nil {
		g.log.ErrorContext(ctx, "the incident could not be stored", "error", err)

		stored = incident
	}

	if g.emitter != nil {
		if err = g.emitter.Emit(ctx, "failure", shot.Printer, stored); err != nil {
			g.log.WarnContext(ctx, "the failure event could not be published", "error", err)
		}
	}
}

// printing answers whether the printer's state machine says PRINTING.
func (g *Guard) printing(ctx context.Context, printer string) (bool, error) {
	device, err := g.devices.Get(ctx, deviceapi.GetParams{ID: printer})
	if err != nil {
		return false, err
	}

	var state string
	if raw, ok := device.State["/state"]; ok {
		_ = json.Unmarshal(raw, &state)
	}

	return device.Connected && state == "PRINTING", nil
}

// read fetches the whole JPEG in chunks.
func (g *Guard) read(ctx context.Context, shot Snapshot) ([]byte, error) {
	var frame []byte

	for {
		chunk, err := g.storage.Read(ctx, storageapi.ReadParams{
			Storage: shot.Storage, Path: shot.Path,
			Offset: int64(len(frame)), Length: storageapi.MaxReadBytes,
		})
		if err != nil {
			return nil, fmt.Errorf("read %s from %s: %w", shot.Path, shot.Storage, err)
		}

		frame = append(frame, chunk.Data...)

		if len(frame) > maxFrameBytes {
			return nil, fmt.Errorf("the snapshot %s is larger than %d bytes", shot.Path, maxFrameBytes)
		}

		if chunk.EOF || len(chunk.Data) == 0 {
			return frame, nil
		}
	}
}

func (g *Guard) watch(shot Snapshot, config Config) *Watch {
	g.mu.Lock()
	defer g.mu.Unlock()

	watch, ok := g.watches[shot.Camera]
	if !ok || watch.Printer != shot.Printer {
		watch = &Watch{Camera: shot.Camera, Printer: shot.Printer, Verdict: detect.VerdictWarmingUp,
			tracker: detect.NewTracker(config.Params)}
		g.watches[shot.Camera] = watch
	}

	return watch
}

func (g *Guard) fail(shot Snapshot, err error) error {
	g.mu.Lock()
	if watch, ok := g.watches[shot.Camera]; ok {
		watch.Error = err.Error()
	}
	g.mu.Unlock()

	return err
}

// Watches lists every camera seen, by camera name.
func (g *Guard) Watches() []Watch {
	g.mu.Lock()
	defer g.mu.Unlock()

	out := make([]Watch, 0, len(g.watches))
	for _, key := range slices.Sorted(maps.Keys(g.watches)) {
		out = append(out, *g.watches[key])
	}

	return out
}

// ErrUnknownPrinter is a reset for a printer the guard has not seen.
var ErrUnknownPrinter = errors.New("guard: no camera of that printer has been seen")

// Reset marks the current state of a printer as normal: a false alarm. The
// baseline starts over and the guard may act again on this print.
func (g *Guard) Reset(printer string) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	found := false

	for camera, watch := range g.watches {
		if watch.Printer != printer {
			continue
		}

		found = true

		if g.config.Detector != nil {
			g.config.Detector.Reset(camera)
		}

		g.watches[camera] = &Watch{Camera: camera, Printer: printer, Printing: watch.Printing,
			Verdict: detect.VerdictWarmingUp, tracker: detect.NewTracker(g.config.Params)}
	}

	if !found {
		return ErrUnknownPrinter
	}

	return nil
}
