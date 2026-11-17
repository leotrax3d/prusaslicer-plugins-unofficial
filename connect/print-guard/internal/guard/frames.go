package guard

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"
)

// frameTTL is how long one published frame stays fetchable. Obico fetches it
// within the request this module is waiting on, so a minute is generous.
const frameTTL = time.Minute

// Frames serves each frame under a random, single-use path, so the Obico ML
// API can fetch it. Nothing else is served, and a path is unguessable and
// gone after the detector is done with it or after frameTTL.
type Frames struct {
	base string

	mu    sync.Mutex
	held  map[string]heldFrame
	clock func() time.Time
}

type heldFrame struct {
	jpeg    []byte
	expires time.Time
}

// NewFrames serves frames that the ML API reaches under base, for example
// http://192.168.1.10:18491.
func NewFrames(base string) *Frames {
	return &Frames{base: strings.TrimRight(base, "/"), held: map[string]heldFrame{}, clock: time.Now}
}

// SetBase changes the address the ML API reaches frames under.
func (f *Frames) SetBase(base string) {
	f.mu.Lock()
	f.base = strings.TrimRight(base, "/")
	f.mu.Unlock()
}

// Publish implements detect.FramePublisher.
func (f *Frames) Publish(jpeg []byte) (string, func(), error) {
	f.mu.Lock()
	base := f.base
	f.mu.Unlock()

	if base == "" {
		return "", nil, errors.New("frame_base_url is not set")
	}

	raw := make([]byte, 16)
	if _, err := rand.Read(raw); err != nil {
		return "", nil, err
	}

	token := hex.EncodeToString(raw)
	now := f.clock()

	f.mu.Lock()
	for key, held := range f.held {
		if now.After(held.expires) {
			delete(f.held, key)
		}
	}
	f.held[token] = heldFrame{jpeg: jpeg, expires: now.Add(frameTTL)}
	f.mu.Unlock()

	done := func() {
		f.mu.Lock()
		delete(f.held, token)
		f.mu.Unlock()
	}

	return base + "/frames/" + token + ".jpg", done, nil
}

// ServeHTTP answers GET /frames/<token>.jpg.
func (f *Frames) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	name, ok := strings.CutPrefix(r.URL.Path, "/frames/")
	token, isJPEG := strings.CutSuffix(name, ".jpg")

	if r.Method != http.MethodGet || !ok || !isJPEG {
		http.NotFound(w, r)

		return
	}

	f.mu.Lock()
	held, found := f.held[token]
	f.mu.Unlock()

	if !found || f.clock().After(held.expires) {
		http.NotFound(w, r)

		return
	}

	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(held.jpeg)
}
