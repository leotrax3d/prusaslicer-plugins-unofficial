package detect

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// FramePublisher makes one frame reachable over HTTP for a short while and
// answers its URL. The Obico ML API fetches the picture itself from a URL it
// is given, so the module has to serve each frame it wants scored.
type FramePublisher interface {
	Publish(jpeg []byte) (frameURL string, done func(), err error)
}

// Obico scores frames with a self-hosted Obico ML API server
// (github.com/TheSpaghettiDetective/obico-server, directory ml_api). That
// server runs Obico's trained failure-detection model and answers
//
//	GET {base}/p/?img=<url>  ->  {"detections": [[label, confidence, [x, y, w, h]], ...]}
//
// with an optional "Authorization: Bearer <ML_API_TOKEN>".
type Obico struct {
	base   *url.URL
	token  string
	frames FramePublisher
	client *http.Client
}

// NewObico returns a detector on the ML API at base.
func NewObico(base, token string, frames FramePublisher, client *http.Client) (*Obico, error) {
	parsed, err := url.Parse(base)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" {
		return nil, fmt.Errorf("detect: obico_url %q is not an http(s) address", base)
	}

	if frames == nil {
		return nil, errors.New("detect: obico needs frame_base_url and the frames port, so the ML API can fetch the picture")
	}

	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}

	return &Obico{base: parsed, token: token, frames: frames, client: client}, nil
}

// Name implements Detector.
func (*Obico) Name() string { return "obico" }

// Reset implements Detector. The ML API keeps no state.
func (*Obico) Reset(string) {}

// Detect implements Detector.
func (o *Obico) Detect(ctx context.Context, _ string, jpeg []byte) (Result, error) {
	frameURL, done, err := o.frames.Publish(jpeg)
	if err != nil {
		return Result{}, fmt.Errorf("detect: publish the frame: %w", err)
	}
	defer done()

	endpoint := o.base.JoinPath("p/")
	endpoint.RawQuery = url.Values{"img": {frameURL}}.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint.String(), nil)
	if err != nil {
		return Result{}, err
	}

	if o.token != "" {
		req.Header.Set("Authorization", "Bearer "+o.token)
	}

	resp, err := o.client.Do(req)
	if err != nil {
		return Result{}, fmt.Errorf("detect: obico: %w", err)
	}
	defer resp.Body.Close()

	var body struct {
		Detections []json.RawMessage `json:"detections"`
		Message    string            `json:"message"`
	}

	if err = json.NewDecoder(http.MaxBytesReader(nil, resp.Body, 1<<20)).Decode(&body); err != nil {
		return Result{}, fmt.Errorf("detect: obico answered %s and no JSON: %w", resp.Status, err)
	}

	if resp.StatusCode != http.StatusOK {
		return Result{}, fmt.Errorf("detect: obico answered %s: %s", resp.Status, body.Message)
	}

	return parseDetections(body.Detections)
}

// parseDetections reads Obico's [label, confidence, [cx, cy, w, h]] triples.
func parseDetections(raw []json.RawMessage) (Result, error) {
	result := Result{}

	for _, item := range raw {
		var triple []json.RawMessage
		if err := json.Unmarshal(item, &triple); err != nil || len(triple) < 2 {
			return Result{}, fmt.Errorf("detect: obico sent a detection that is not [label, confidence, box]: %s", item)
		}

		var box Box
		if err := json.Unmarshal(triple[0], &box.Label); err != nil {
			return Result{}, fmt.Errorf("detect: obico sent a label that is not text: %s", triple[0])
		}

		if err := json.Unmarshal(triple[1], &box.Confidence); err != nil {
			return Result{}, fmt.Errorf("detect: obico sent a confidence that is not a number: %s", triple[1])
		}

		if len(triple) > 2 {
			var xywh []float64
			if json.Unmarshal(triple[2], &xywh) == nil && len(xywh) == 4 {
				// Obico's boxes are centre-based.
				box.X, box.Y, box.W, box.H = xywh[0]-xywh[2]/2, xywh[1]-xywh[3]/2, xywh[2], xywh[3]
			}
		}

		result.Score += box.Confidence
		result.Boxes = append(result.Boxes, box)
	}

	result.Score = round3(result.Score)

	return result, nil
}
