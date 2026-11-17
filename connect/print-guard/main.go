// Command print-guard is a Prusa Connect extension that watches printer
// cameras and pauses a print that has visibly failed.
//
// # How it watches with no browser open
//
// The operator switches on periodic capture for a camera. The host then stores
// a snapshot on that cadence and publishes
// com.prusa.connect.camera.snapshot.captured, naming the storage and path of
// the JPEG and the printer the camera watches. This process subscribes to that
// event, reads the JPEG through the storage door, asks the printer whether it
// is printing, scores the frame and follows the score over the print. When the
// trend says the print failed it sends core.command.pause_print, stores an
// incident and publishes failure.detected.
//
// # Routes
//
//	GET  /status                     every camera followed, with its verdict
//	GET  /incidents?printer=<id>     the incidents, newest first
//	POST /printers/{printer}/reset   a false alarm: start the baseline over
package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"maps"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/prusa3d/prusa-connect/sdk/busapi"
	"github.com/prusa3d/prusa-connect/sdk/deviceapi"
	"github.com/prusa3d/prusa-connect/sdk/extension"
	"github.com/prusa3d/prusa-connect/sdk/fault"
	"github.com/prusa3d/prusa-connect/sdk/routesapi"
	"github.com/prusa3d/prusa-connect/sdk/stateapi"
	"github.com/prusa3d/prusa-connect/sdk/storageapi"
	"github.com/prusa3d/prusa-connect/sdk/wire"
	"github.com/prusa3d/prusa-connect/sdk/wirerpc"

	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/detect"
	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/guard"
)

//go:embed module.yaml
var manifestYAML []byte

//go:embed openapi.json
var openAPI []byte

//nolint:gochecknoglobals // read once from the embedded manifest.
var (
	name    = manifestScalar(manifestYAML, "name")
	release = extension.Version(manifestScalar(manifestYAML, "version"))
)

func manifestScalar(document []byte, key string) string {
	for _, line := range strings.Split(string(document), "\n") {
		value, found := strings.CutPrefix(line, key+":")
		if !found {
			continue
		}

		if comment := strings.Index(value, " #"); comment >= 0 {
			value = value[:comment]
		}

		return strings.Trim(strings.TrimSpace(value), `"'`)
	}

	return ""
}

// Settings is what an operator writes under this instance's config block.
type Settings struct {
	Detector     string  `json:"detector"`
	Action       string  `json:"action"`
	Sensitivity  float64 `json:"sensitivity"`
	WarmupFrames int     `json:"warmup_frames"`
	ObicoURL     string  `json:"obico_url"`
	ObicoToken   string  `json:"obico_token"`
	FrameBaseURL string  `json:"frame_base_url"`
}

// defaults are module.yaml's defaults, for a host that sends nothing.
// TestTheManifestPublishesTheCodesDefaults holds the two together.
func defaults() Settings {
	return Settings{Detector: "auto", Action: "pause", Sensitivity: 1, WarmupFrames: 5}
}

// buildConfig turns settings into what the guard runs on.
func buildConfig(s Settings, frames detect.FramePublisher) (guard.Config, error) {
	params := detect.DefaultParams()
	if s.Sensitivity > 0 {
		params.Sensitivity = s.Sensitivity
	}

	if s.WarmupFrames >= 0 {
		params.WarmupFrames = s.WarmupFrames
	}

	action := guard.Action(s.Action)
	if action == "" {
		action = guard.ActionPause
	}

	if action != guard.ActionPause && action != guard.ActionNotify {
		return guard.Config{}, fmt.Errorf("action is %q; it is pause or notify", s.Action)
	}

	kind := s.Detector
	if kind == "" || kind == "auto" {
		kind = "heuristic"
		if s.ObicoURL != "" {
			kind = "obico"
		}
	}

	var detector detect.Detector

	switch kind {
	case "heuristic":
		detector = detect.NewHeuristic()
	case "obico":
		if s.ObicoURL == "" {
			return guard.Config{}, errors.New("detector is obico but obico_url is empty")
		}

		if s.FrameBaseURL == "" {
			return guard.Config{}, errors.New("detector is obico but frame_base_url is empty: the ML API needs it to fetch the frame")
		}

		obico, err := detect.NewObico(s.ObicoURL, s.ObicoToken, frames, nil)
		if err != nil {
			return guard.Config{}, err
		}

		detector = obico
	default:
		return guard.Config{}, fmt.Errorf("detector is %q; it is auto, heuristic or obico", s.Detector)
	}

	return guard.Config{Detector: detector, Params: params, Action: action}, nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	line, err := wire.Handshake{
		Protocol: wire.ProtocolMajor,
		MinMinor: wire.MinMinor,
		MaxMinor: wire.MaxMinor,
		Address:  wire.StdioAddress,
	}.Line()
	if err != nil {
		return fmt.Errorf("render the handshake: %w", err)
	}

	if _, err = os.Stdout.WriteString(line); err != nil {
		return fmt.Errorf("write the handshake: %w", err)
	}

	// The method set is filled once the session exists, because the guard
	// calls the host through it.
	serves := wirerpc.Methods{}

	conn, err := wirerpc.NewConn(stdio{}, wirerpc.Options{Role: wirerpc.RoleChild, Methods: serves})
	if err != nil {
		return fmt.Errorf("build the session: %w", err)
	}

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	incidents := guard.NewIncidents(stateapi.NewClient(conn))
	m := &module{
		incidents: incidents,
		guard: guard.New(
			deviceapi.NewClient(conn),
			storageapi.NewClient(conn),
			incidents,
			busapi.NewClient(conn),
			func(ctx context.Context, p busapi.SubscribeParams, onWindow func(busapi.Window) error) error {
				return busapi.Subscribe(ctx, conn, p, onWindow)
			},
			log,
		),
		log: log,
	}
	defer m.stop()

	maps.Copy(serves, m.methods(ctx))

	fmt.Fprintf(os.Stderr, "%s %s is serving on stdio as pid %d\n", name, release, os.Getpid())

	if err = conn.Serve(ctx); err != nil {
		return fmt.Errorf("serve: %w", err)
	}

	return nil
}

// module holds what the process runs.
type module struct {
	guard     *guard.Guard
	incidents *guard.Incidents
	log       *slog.Logger

	mu       sync.Mutex
	started  bool
	cancel   context.CancelFunc
	frames   *guard.Frames
	server   *http.Server
	settings Settings
}

func (m *module) methods(ctx context.Context) wirerpc.Methods {
	return wirerpc.Methods{
		wirerpc.MethodInfo: func(context.Context, wirerpc.Call) (any, error) {
			return routesapi.Describe(wirerpc.Info{
				Name: name, Version: release, Contract: wirerpc.Contract,
				Serves: []wirerpc.Method{wirerpc.MethodConfigure},
			}, openAPI)
		},
		wirerpc.MethodConfigure: wirerpc.ConfigureGranted(func(_ context.Context, sent Settings, grants wirerpc.Grants) error {
			return m.configure(ctx, sent, grants)
		}),
		wirerpc.MethodShutdown: func(context.Context, wirerpc.Call) (any, error) {
			fmt.Fprintf(os.Stderr, "%s was asked to stop\n", name)
			m.stop()

			return nil, nil
		},
		routesapi.MethodServe: routesapi.Serve(m.routes()),
	}
}

// configure applies settings and starts the guard and the frames port once.
func (m *module) configure(ctx context.Context, sent Settings, grants wirerpc.Grants) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.frames == nil {
		m.frames = guard.NewFrames(sent.FrameBaseURL)

		if port, ok := grants.Listen["frames"]; ok && port.Network == "tcp" {
			listener, err := net.Listen("tcp", ":"+strconv.Itoa(port.Port))
			if err != nil {
				return fmt.Errorf("listen on the frames port %d: %w", port.Port, err)
			}

			m.server = &http.Server{Handler: m.frames, ReadHeaderTimeout: 5 * time.Second}

			go func() { _ = m.server.Serve(listener) }()
		}
	}

	m.frames.SetBase(sent.FrameBaseURL)

	// Obico can only fetch a frame when the port is granted and the operator
	// said how the ML API reaches it.
	var publisher detect.FramePublisher
	if m.server != nil && sent.FrameBaseURL != "" {
		publisher = m.frames
	}

	config, err := buildConfig(sent, publisher)
	if err != nil {
		return err
	}

	m.settings = sent
	m.guard.Configure(config)

	if !m.started {
		m.started = true

		runCtx, cancel := context.WithCancel(ctx)
		m.cancel = cancel

		go m.guard.Run(runCtx)
	}

	m.log.Info("configured", "detector", config.Detector.Name(), "action", config.Action,
		"sensitivity", config.Params.Sensitivity)

	return nil
}

func (m *module) stop() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.cancel != nil {
		m.cancel()
	}

	if m.server != nil {
		_ = m.server.Close()
	}
}

// status is what GET /status answers.
type status struct {
	Detector string        `json:"detector"`
	Action   string        `json:"action"`
	Cameras  []guard.Watch `json:"cameras"`
}

func (m *module) routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /status", func(w http.ResponseWriter, _ *http.Request) {
		m.mu.Lock()
		s := m.settings
		m.mu.Unlock()

		detector := s.Detector
		if detector == "" || detector == "auto" {
			detector = "heuristic"
			if s.ObicoURL != "" {
				detector = "obico"
			}
		}

		action := s.Action
		if action == "" {
			action = string(guard.ActionPause)
		}

		answer(w, http.StatusOK, status{Detector: detector, Action: action, Cameras: m.guard.Watches()})
	})

	mux.HandleFunc("GET /incidents", func(w http.ResponseWriter, r *http.Request) {
		list, err := m.incidents.List(r.Context(), r.URL.Query().Get("printer"))
		if err != nil {
			m.log.ErrorContext(r.Context(), "the incidents could not be listed", "error", err)
			refuse(w, r, IncidentsUnavailable.New(err.Error()))

			return
		}

		answer(w, http.StatusOK, map[string]any{"incidents": list})
	})

	mux.HandleFunc("POST /printers/{printer}/reset", func(w http.ResponseWriter, r *http.Request) {
		printer := r.PathValue("printer")
		if err := m.guard.Reset(printer); err != nil {
			refuse(w, r, PrinterNotWatched.New("no snapshot of "+printer+" has arrived").
				With(fault.StringParam("printer", printer)))

			return
		}

		w.WriteHeader(http.StatusNoContent)
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		refuse(w, r, RouteNotFound.New("this module serves no route at "+r.URL.Path).
			With(fault.StringParam("path", r.URL.Path)))
	})

	return mux
}

func answer(w http.ResponseWriter, code int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)

	_ = json.NewEncoder(w).Encode(body)
}

type stdio struct{}

func (stdio) Read(p []byte) (int, error)  { return os.Stdin.Read(p) }
func (stdio) Write(p []byte) (int, error) { return os.Stdout.Write(p) }
func (stdio) Close() error                { return os.Stdin.Close() }
