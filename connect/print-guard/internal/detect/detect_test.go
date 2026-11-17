package detect

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/jpeg"
	"math/rand/v2"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// scene draws a dark bed with a grey block that grows layer by layer, and
// optionally a tangle of bright strands.
func scene(t *testing.T, layer int, strands int, seed uint64) []byte {
	t.Helper()

	img := image.NewRGBA(image.Rect(0, 0, 640, 480))
	for y := range 480 {
		for x := range 640 {
			img.Set(x, y, color.RGBA{R: 40, G: 40, B: 45, A: 255})
		}
	}

	// The part: 200 px wide, growing up from y=400.
	top := 400 - layer
	for y := top; y < 400; y++ {
		for x := 220; x < 420; x++ {
			img.Set(x, y, color.RGBA{R: 150, G: 120, B: 60, A: 255})
		}
	}

	rng := rand.New(rand.NewPCG(seed, seed+1))
	for range strands {
		x, y := 120+rng.Float64()*400, 120+rng.Float64()*300
		dx, dy := rng.Float64()*2-1, rng.Float64()*2-1

		for range 120 {
			x, y = x+dx*2, y+dy*2
			dx += (rng.Float64() - 0.5) * 0.6
			dy += (rng.Float64() - 0.5) * 0.6

			if x >= 0 && y >= 0 && x < 640 && y < 480 {
				img.Set(int(x), int(y), color.RGBA{R: 240, G: 220, B: 120, A: 255})
				img.Set(int(x)+1, int(y), color.RGBA{R: 240, G: 220, B: 120, A: 255})
			}
		}
	}

	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: 85}); err != nil {
		t.Fatal(err)
	}

	return out.Bytes()
}

func TestTheHeuristicStaysQuietOnAGrowingPrint(t *testing.T) {
	h := NewHeuristic()
	tracker := NewTracker(DefaultParams())

	for layer := range 40 {
		result, err := h.Detect(context.Background(), "cam", scene(t, layer, 0, 1))
		if err != nil {
			t.Fatal(err)
		}

		if v := tracker.Add(result.Score, time.Now()); v == VerdictFailing || v == VerdictWarning {
			t.Fatalf("layer %d: a normal print was judged %s (score %.3f, excess %.3f)",
				layer, v, result.Score, tracker.Excess())
		}
	}
}

func TestTheHeuristicFlagsSpaghetti(t *testing.T) {
	h := NewHeuristic()
	tracker := NewTracker(DefaultParams())

	for layer := range 20 {
		result, _ := h.Detect(context.Background(), "cam", scene(t, layer, 0, 1))
		tracker.Add(result.Score, time.Now())
	}

	verdict := VerdictOK

	for frame := range 15 {
		// The tangle grows and moves from frame to frame.
		result, err := h.Detect(context.Background(), "cam", scene(t, 20, 30+frame*4, uint64(frame)))
		if err != nil {
			t.Fatal(err)
		}

		verdict = tracker.Add(result.Score, time.Now())
		if verdict == VerdictFailing {
			return
		}
	}

	t.Fatalf("spaghetti was judged %s (excess %.3f)", verdict, tracker.Excess())
}

func TestTheHeuristicRefusesNonJPEG(t *testing.T) {
	if _, err := NewHeuristic().Detect(context.Background(), "cam", []byte("nope")); err == nil {
		t.Fatal("a non-JPEG was scored")
	}
}

func TestOneBadFrameDoesNotFail(t *testing.T) {
	tracker := NewTracker(DefaultParams())
	for range 10 {
		tracker.Add(0.02, time.Now())
	}

	if v := tracker.Add(1.5, time.Now()); v == VerdictFailing {
		t.Fatalf("a single frame failed the print (excess %.3f)", tracker.Excess())
	}
}

func TestASustainedRiseFailsAndTheBaselineDoesNotAbsorbIt(t *testing.T) {
	tracker := NewTracker(DefaultParams())
	for range 10 {
		tracker.Add(0.02, time.Now())
	}

	failedAt := -1

	for i := range 200 {
		if tracker.Add(1.2, time.Now()) == VerdictFailing && failedAt < 0 {
			failedAt = i
		}
	}

	if failedAt < 0 || failedAt > 10 {
		t.Fatalf("a sustained failure was judged failing at frame %d", failedAt)
	}

	if tracker.Verdict() != VerdictFailing {
		t.Fatalf("after 200 bad frames the verdict is %s: the baseline absorbed the failure", tracker.Verdict())
	}
}

func TestWarmupIsNeverJudged(t *testing.T) {
	tracker := NewTracker(DefaultParams())
	for i := range 5 {
		if v := tracker.Add(5, time.Now()); v != VerdictWarmingUp {
			t.Fatalf("frame %d judged %s", i, v)
		}
	}
}

type fakeFrames struct{ url string }

func (f fakeFrames) Publish([]byte) (string, func(), error) { return f.url, func() {}, nil }

func TestObicoSumsTheDetections(t *testing.T) {
	var gotImg, gotAuth string

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/p/" {
			http.NotFound(w, r)

			return
		}

		gotImg, gotAuth = r.URL.Query().Get("img"), r.Header.Get("Authorization")
		_, _ = w.Write([]byte(`{"detections": [["failure", 0.5, [100, 100, 20, 40]], ["failure", 0.25, [10, 10, 2, 2]]]}`))
	}))
	defer server.Close()

	obico, err := NewObico(server.URL, "secret", fakeFrames{url: "http://me/frames/x.jpg"}, nil)
	if err != nil {
		t.Fatal(err)
	}

	result, err := obico.Detect(context.Background(), "cam", []byte{0xff})
	if err != nil {
		t.Fatal(err)
	}

	if result.Score != 0.75 || len(result.Boxes) != 2 || result.Boxes[0].X != 90 || result.Boxes[0].H != 40 {
		t.Fatalf("got %+v", result)
	}

	if gotImg != "http://me/frames/x.jpg" || gotAuth != "Bearer secret" {
		t.Fatalf("obico was asked for %q with %q", gotImg, gotAuth)
	}
}

func TestObicoReportsItsErrors(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"detections": [], "message": "Failed to get image"}`))
	}))
	defer server.Close()

	obico, _ := NewObico(server.URL, "", fakeFrames{url: "http://me/x.jpg"}, nil)
	if _, err := obico.Detect(context.Background(), "cam", nil); err == nil {
		t.Fatal("an error answer was scored")
	}
}

func TestObicoNeedsAnAddressAndFrames(t *testing.T) {
	if _, err := NewObico("ftp://x", "", fakeFrames{}, nil); err == nil {
		t.Fatal("ftp was accepted")
	}

	if _, err := NewObico("http://x", "", nil, nil); err == nil {
		t.Fatal("no frame publisher was accepted")
	}
}

func TestALightChangeIsNotSpaghetti(t *testing.T) {
	h := NewHeuristic()

	for layer := range 10 {
		_, _ = h.Detect(context.Background(), "cam", scene(t, layer, 0, 1))
	}

	// The same scene, much brighter: every cell changes, none gains texture.
	img, _ := jpeg.Decode(bytes.NewReader(scene(t, 10, 0, 1)))
	bright := image.NewRGBA(img.Bounds())

	for y := range 480 {
		for x := range 640 {
			r, g, b, _ := img.At(x, y).RGBA()
			bright.Set(x, y, color.RGBA{R: uint8(min(255, r>>8+60)), G: uint8(min(255, g>>8+60)), B: uint8(min(255, b>>8+60)), A: 255})
		}
	}

	var out bytes.Buffer
	_ = jpeg.Encode(&out, bright, &jpeg.Options{Quality: 85})

	result, err := h.Detect(context.Background(), "cam", out.Bytes())
	if err != nil {
		t.Fatal(err)
	}

	if result.Score > 0.2 {
		t.Fatalf("a light change scored %.3f: %+v", result.Score, result.Boxes)
	}
}
