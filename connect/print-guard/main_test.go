package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/prusa3d/prusa-connect/sdk/extension"
	"github.com/prusa3d/prusa-connect/sdk/routesapi"

	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/guard"
)

func testModule() *module {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))

	return &module{
		guard:     guard.New(nil, nil, nil, nil, nil, log),
		incidents: guard.NewIncidents(nil),
		log:       log,
		settings:  defaults(),
	}
}

func TestStatusAnswersTheDefaults(t *testing.T) {
	recorder := httptest.NewRecorder()
	testModule().routes().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/status", nil))

	if recorder.Code != http.StatusOK {
		t.Fatalf("GET /status answered %d", recorder.Code)
	}

	var body status
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}

	if body.Detector != "heuristic" || body.Action != "pause" || body.Cameras == nil {
		t.Fatalf("GET /status answered %+v", body)
	}
}

func TestAResetOfAnUnknownPrinterIsRefusedByCode(t *testing.T) {
	recorder := httptest.NewRecorder()
	testModule().routes().ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/printers/p1/reset", nil))

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("answered %d", recorder.Code)
	}

	var problem struct {
		Code string `json:"code"`
	}

	_ = json.Unmarshal(recorder.Body.Bytes(), &problem)

	if problem.Code != PrinterNotWatched.Code().String() {
		t.Fatalf("code %q", problem.Code)
	}
}

func TestAnUnservedPathIsRefusedByCode(t *testing.T) {
	recorder := httptest.NewRecorder()
	testModule().routes().ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/nothing", nil))

	if recorder.Code != http.StatusNotFound ||
		!strings.Contains(recorder.Body.String(), RouteNotFound.Code().String()) {
		t.Fatalf("answered %d %s", recorder.Code, recorder.Body.String())
	}
}

func TestBuildConfigChoosesTheDetector(t *testing.T) {
	cases := []struct {
		settings Settings
		want     string
		fails    bool
	}{
		{settings: defaults(), want: "heuristic"},
		{settings: Settings{Detector: "auto", ObicoURL: "http://ml:3333", FrameBaseURL: "http://me:18491"}, want: "obico"},
		{settings: Settings{Detector: "obico"}, fails: true},
		{settings: Settings{Detector: "obico", ObicoURL: "http://ml:3333"}, fails: true},
		{settings: Settings{Detector: "magic"}, fails: true},
		{settings: Settings{Action: "explode"}, fails: true},
	}

	for _, c := range cases {
		config, err := buildConfig(c.settings, guard.NewFrames(c.settings.FrameBaseURL))
		if c.fails {
			if err == nil {
				t.Errorf("%+v was accepted", c.settings)
			}

			continue
		}

		if err != nil || config.Detector.Name() != c.want {
			t.Errorf("%+v: got %v, %v", c.settings, config.Detector, err)
		}
	}
}

// The manifest is the documentation an operator reads, so its defaults must
// be the ones the code falls back on.
func TestTheManifestPublishesTheCodesDefaults(t *testing.T) {
	d := defaults()
	for key, want := range map[string]string{
		"detector": d.Detector, "action": d.Action, "sensitivity": "1", "warmup_frames": "5",
	} {
		pattern := "- key: " + key + "\n"
		at := bytes.Index(manifestYAML, []byte(pattern))
		if at < 0 {
			t.Fatalf("module.yaml declares no %s", key)
		}

		block := string(manifestYAML[at:])
		def := block[strings.Index(block, "default:")+len("default:"):]
		def = strings.TrimSpace(def[:strings.Index(def, "\n")])

		if def != want {
			t.Errorf("module.yaml publishes %s default %q, the code uses %q", key, def, want)
		}
	}
}

func TestTheFaultDomainIsTheDerivedNamespace(t *testing.T) {
	gomod, err := os.ReadFile("go.mod")
	if err != nil {
		t.Fatal(err)
	}

	path := strings.TrimSpace(strings.SplitN(strings.TrimPrefix(string(gomod), "module "), "\n", 2)[0])

	derived, err := extension.NamespaceOf(path)
	if err != nil {
		t.Fatal(err)
	}

	if derived.String() != namespace {
		t.Fatalf("go.mod derives %s, faults.go names %s", derived, namespace)
	}
}

func TestTheOpenAPIFragmentParses(t *testing.T) {
	if _, err := routesapi.ParseFragment(openAPI); err != nil {
		t.Fatal(err)
	}
}
