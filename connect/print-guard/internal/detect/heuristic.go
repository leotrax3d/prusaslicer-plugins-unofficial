package detect

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/jpeg"
	"math"
	"slices"
	"sync"
)

// The heuristic works on a small grey image cut into square cells.
const (
	gridW    = 128
	gridH    = 96
	cellSize = 8
	cellsX   = gridW / cellSize
	cellsY   = gridH / cellSize
	cells    = cellsX * cellsY

	// backgroundAlpha is how fast the background model follows the scene. A
	// print grows a fraction of a millimetre per layer, so a slow model
	// absorbs normal growth and a sudden tangle of strands stands out.
	backgroundAlpha = 0.08
	// diffThreshold is the mean grey difference, 0..255, a cell must move by
	// to count as changed. A thin strand covers a small part of a cell, so
	// the bar is low; the texture test does the rest.
	diffThreshold = 8.0
	// textureFactor is how much more edge energy than the background a
	// changed cell needs to count as chaotic. Spaghetti is thin, bright and
	// tangled: many strong edges where there were few.
	textureFactor = 1.6
	// edgeStrength is the grey step, 0..255, that counts a pixel as an edge.
	edgeStrength = 20.0
	// minEdgePixels is how many edge pixels a cell needs to be chaotic. One
	// straight edge across a cell, the top of a growing part, is one or two
	// rows of cellSize pixels after downscaling; a tangle is many more.
	minEdgePixels = 3 * cellSize
	// textureFloor stops a dark, flat background from turning noise into a
	// huge relative jump.
	textureFloor = 6.0
)

// Heuristic is a detector that needs no model and no network. It keeps a
// slowly adapting background per camera and scores the share of cells that
// both changed and became much more textured than the background. That is
// what loose strands, a blob or a part knocked over look like from a fixed
// camera, and what steady layer-by-layer growth does not.
//
// It is a heuristic, not a trained model: lighting changes, a person in the
// frame or a moving camera raise its score. The tracker's smoothing and the
// warm-up period take most of that out; Obico is the stronger option.
type Heuristic struct {
	mu     sync.Mutex
	models map[string]*background
}

type background struct {
	grey    []float64
	texture []float64
	frames  int
}

// NewHeuristic returns the built-in detector.
func NewHeuristic() *Heuristic {
	return &Heuristic{models: map[string]*background{}}
}

// Name implements Detector.
func (*Heuristic) Name() string { return "heuristic" }

// Reset implements Detector.
func (h *Heuristic) Reset(key string) {
	h.mu.Lock()
	delete(h.models, key)
	h.mu.Unlock()
}

// Detect implements Detector.
func (h *Heuristic) Detect(_ context.Context, key string, frame []byte) (Result, error) {
	img, err := jpeg.Decode(bytes.NewReader(frame))
	if err != nil {
		return Result{}, fmt.Errorf("%w: %v", ErrNotJPEG, err)
	}

	grey := downscale(img)
	texture, edges := cellTexture(grey)

	h.mu.Lock()
	defer h.mu.Unlock()

	model, ok := h.models[key]
	if !ok {
		model = &background{grey: slices.Clone(grey), texture: slices.Clone(texture)}
		h.models[key] = model
	}

	result := score(model, grey, texture, edges, img.Bounds())
	model.update(grey, texture)

	return result, nil
}

// score compares one frame with the background model.
func score(model *background, grey, texture []float64, edges []int, bounds image.Rectangle) Result {
	if model.frames == 0 {
		return Result{}
	}

	// A light switched on or the sun moving shifts every pixel alike. That
	// shift is taken out before cells are compared, so only local change
	// counts.
	shift := mean(grey) - mean(model.grey)

	scaleX := float64(bounds.Dx()) / gridW
	scaleY := float64(bounds.Dy()) / gridH
	chaotic := 0

	var boxes []Box

	for cy := range cellsY {
		for cx := range cellsX {
			i := cy*cellsX + cx
			diff := cellDiff(grey, model.grey, shift, cx, cy)
			base := math.Max(model.texture[i], textureFloor)

			if diff < diffThreshold || texture[i] < base*textureFactor || edges[i] < minEdgePixels {
				continue
			}

			chaotic++
			confidence := math.Min(1, (texture[i]/base-1)/textureFactor)
			boxes = append(boxes, Box{
				Label:      "chaotic",
				Confidence: round3(confidence),
				X:          float64(cx*cellSize) * scaleX,
				Y:          float64(cy*cellSize) * scaleY,
				W:          cellSize * scaleX,
				H:          cellSize * scaleY,
			})
		}
	}

	// A handful of cells is noise; a fifth of the frame is a disaster. The
	// square root lifts small but clustered regions, which is what a print
	// starting to fail looks like.
	share := float64(chaotic) / cells

	return Result{Score: round3(math.Min(1, math.Sqrt(share*5))), Boxes: boxes}
}

func (b *background) update(grey, texture []float64) {
	b.frames++
	alpha := backgroundAlpha
	// The first frames build the model quickly.
	if b.frames < 4 {
		alpha = 0.5
	}

	for i := range b.grey {
		b.grey[i] += (grey[i] - b.grey[i]) * alpha
	}

	for i := range b.texture {
		b.texture[i] += (texture[i] - b.texture[i]) * alpha
	}
}

// downscale reads any image into a gridW×gridH grey buffer by box averaging.
func downscale(img image.Image) []float64 {
	b := img.Bounds()
	out := make([]float64, gridW*gridH)
	counts := make([]float64, gridW*gridH)

	// Sample at most ~4 pixels per output pixel in each direction, so a 4K
	// frame costs the same as a 512 px one.
	stepX := max(1, b.Dx()/(gridW*4))
	stepY := max(1, b.Dy()/(gridH*4))

	for y := b.Min.Y; y < b.Max.Y; y += stepY {
		gy := (y - b.Min.Y) * gridH / b.Dy()

		for x := b.Min.X; x < b.Max.X; x += stepX {
			gx := (x - b.Min.X) * gridW / b.Dx()
			r, g, bl, _ := img.At(x, y).RGBA()
			lum := (0.299*float64(r) + 0.587*float64(g) + 0.114*float64(bl)) / 257
			out[gy*gridW+gx] += lum
			counts[gy*gridW+gx]++
		}
	}

	for i := range out {
		if counts[i] > 0 {
			out[i] /= counts[i]
		}
	}

	return out
}

// cellTexture is the mean absolute gradient inside each cell, and how many of
// its pixels sit on a strong edge.
func cellTexture(grey []float64) ([]float64, []int) {
	out := make([]float64, cells)
	edges := make([]int, cells)

	for cy := range cellsY {
		for cx := range cellsX {
			sum := 0.0
			strong := 0

			for y := cy * cellSize; y < (cy+1)*cellSize; y++ {
				for x := cx * cellSize; x < (cx+1)*cellSize; x++ {
					g := 0.0
					if x+1 < gridW {
						g += math.Abs(grey[y*gridW+x+1] - grey[y*gridW+x])
					}

					if y+1 < gridH {
						g += math.Abs(grey[(y+1)*gridW+x] - grey[y*gridW+x])
					}

					sum += g
					if g >= edgeStrength {
						strong++
					}
				}
			}

			out[cy*cellsX+cx] = sum / (cellSize * cellSize)
			edges[cy*cellsX+cx] = strong
		}
	}

	return out, edges
}

func mean(values []float64) float64 {
	sum := 0.0
	for _, v := range values {
		sum += v
	}

	return sum / float64(len(values))
}

func cellDiff(a, b []float64, shift float64, cx, cy int) float64 {
	sum := 0.0

	for y := cy * cellSize; y < (cy+1)*cellSize; y++ {
		for x := cx * cellSize; x < (cx+1)*cellSize; x++ {
			sum += math.Abs(a[y*gridW+x] - shift - b[y*gridW+x])
		}
	}

	return sum / (cellSize * cellSize)
}

func round3(v float64) float64 { return math.Round(v*1000) / 1000 }
