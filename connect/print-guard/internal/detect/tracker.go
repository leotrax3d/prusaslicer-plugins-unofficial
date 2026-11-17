package detect

import "time"

// Verdict is what the tracker makes of a print so far.
type Verdict string

// The verdicts, from good to bad.
const (
	VerdictWarmingUp Verdict = "warming_up"
	VerdictOK        Verdict = "ok"
	VerdictWarning   Verdict = "warning"
	VerdictFailing   Verdict = "failing"
)

// Params tune a Tracker.
type Params struct {
	// Sensitivity multiplies the smoothed excess before it meets the
	// thresholds: 1 is the default, 2 reacts to half the evidence.
	Sensitivity float64
	// WarmupFrames is how many frames of a print are never judged. The first
	// layers of a print change the picture more than anything after.
	WarmupFrames int
	// Low and High are the thresholds on the smoothed excess for a warning and
	// for a failure.
	Low, High float64
	// Span is the EWMA span in frames: about how many recent frames the short
	// average weighs.
	Span int
	// LongWindow is the window of the long average, the print's own baseline.
	LongWindow int
}

// DefaultParams suit Obico's summed confidences, which sit near zero on a good
// print and climb past one on spaghetti. The heuristic's 0..1 score uses the
// same numbers.
func DefaultParams() Params {
	return Params{Sensitivity: 1, WarmupFrames: 5, Low: 0.38, High: 0.78, Span: 12, LongWindow: 1200}
}

// Tracker follows one print on one camera.
//
// It keeps an exponentially weighted mean of the recent scores and a long
// running mean of the unsuspicious ones, which serves as the print's own
// baseline, and judges the difference. A camera that always shows a little noise therefore does not
// alarm, and a sudden, sustained rise does. A single bad frame moves the EWMA
// by at most 2/(Span+1) of its score.
type Tracker struct {
	params Params

	Frames   int       `json:"frames"`
	Current  float64   `json:"current"`
	EWMA     float64   `json:"ewma"`
	LongMean float64   `json:"long_mean"`
	Last     time.Time `json:"last"`

	baselineFrames int
}

// NewTracker starts following a print.
func NewTracker(p Params) *Tracker {
	if p.Span < 1 {
		p.Span = 1
	}

	if p.LongWindow < 1 {
		p.LongWindow = 1
	}

	if p.Sensitivity <= 0 {
		p.Sensitivity = 1
	}

	return &Tracker{params: p}
}

// Add takes one frame's score and answers the verdict after it.
func (t *Tracker) Add(score float64, at time.Time) Verdict {
	alpha := 2 / (float64(t.params.Span) + 1)
	t.Frames++
	t.Current = score
	t.Last = at

	if t.Frames == 1 {
		t.EWMA = score
		t.LongMean = score
		t.baselineFrames = 1
	} else {
		t.EWMA = score*alpha + t.EWMA*(1-alpha)

		// The baseline learns only from frames that do not look suspicious,
		// so a failure that persists is not slowly accepted as normal.
		if (score-t.LongMean)*t.params.Sensitivity < t.params.Low {
			t.baselineFrames++
			window := min(t.baselineFrames, t.params.LongWindow)
			t.LongMean += (score - t.LongMean) / float64(window)
		}
	}

	return t.Verdict()
}

// Excess is the smoothed score above the print's own baseline, scaled by the
// sensitivity.
func (t *Tracker) Excess() float64 {
	return (t.EWMA - t.LongMean) * t.params.Sensitivity
}

// Verdict judges the frames so far.
func (t *Tracker) Verdict() Verdict {
	switch excess := t.Excess(); {
	case t.Frames <= t.params.WarmupFrames:
		return VerdictWarmingUp
	case excess >= t.params.High:
		return VerdictFailing
	case excess >= t.params.Low:
		return VerdictWarning
	default:
		return VerdictOK
	}
}
