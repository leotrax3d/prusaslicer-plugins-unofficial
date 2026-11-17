// Package detect turns one camera frame into a failure score.
//
// A Detector looks at a single JPEG and answers how much of it looks like a
// failed print. A Tracker remembers those answers over one print and decides
// when the trend is bad enough to act on. Detectors are stateless towards
// the tracker, so the same tracker logic serves the built-in heuristic and the
// Obico ML API.
package detect

import (
	"context"
	"errors"
)

// Box is one region a detector flagged, in pixels of the frame it was given.
type Box struct {
	Label      string  `json:"label"`
	Confidence float64 `json:"confidence"`
	X          float64 `json:"x"`
	Y          float64 `json:"y"`
	W          float64 `json:"w"`
	H          float64 `json:"h"`
}

// Result is what one frame scored.
type Result struct {
	// Score is the frame's failure evidence. For Obico it is the sum of the
	// confidences of every detection, the same quantity Obico itself smooths;
	// for the heuristic it is a value in 0..1.
	Score float64 `json:"score"`
	Boxes []Box   `json:"boxes,omitempty"`
}

// Detector scores one frame. key identifies the camera, so a detector that
// keeps per-camera state (the heuristic keeps a background model) keeps it
// apart.
type Detector interface {
	Name() string
	Detect(ctx context.Context, key string, jpeg []byte) (Result, error)
	// Reset forgets what the detector holds for key, at the start of a print.
	Reset(key string)
}

// ErrNotJPEG is a frame that does not decode.
var ErrNotJPEG = errors.New("detect: the frame is not a decodable JPEG")
