package guard

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/prusa3d/prusa-connect/sdk/stateapi"

	"github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard/internal/detect"
)

// keepIncidents is how many incidents are kept per printer.
const keepIncidents = 50

// Incident is one print the guard judged failed.
type Incident struct {
	ID       string       `json:"id"`
	Printer  string       `json:"printer"`
	Camera   string       `json:"camera"`
	Time     time.Time    `json:"time"`
	Score    float64      `json:"score"`
	Excess   float64      `json:"excess"`
	Detector string       `json:"detector"`
	Action   Action       `json:"action"`
	Outcome  string       `json:"outcome"`
	Storage  string       `json:"storage"`
	Path     string       `json:"path"`
	Boxes    []detect.Box `json:"boxes,omitempty"`
}

// Records is the part of stateapi.Client incidents are kept in.
type Records interface {
	Get(ctx context.Context, key stateapi.Key) (stateapi.Value, error)
	Put(ctx context.Context, key stateapi.Key, value []byte) (uint64, error)
	Delete(ctx context.Context, key stateapi.Key) error
	List(ctx context.Context, prefix stateapi.Key) ([]stateapi.Key, error)
}

// Incidents keeps incidents in the module's record namespace, one record per
// incident under incidents/<printer>/<time>.
type Incidents struct {
	records Records
}

// NewIncidents keeps incidents in records.
func NewIncidents(records Records) *Incidents { return &Incidents{records: records} }

// Add stores one incident and drops the oldest past keepIncidents.
func (s *Incidents) Add(ctx context.Context, incident Incident) (Incident, error) {
	if s == nil || s.records == nil {
		return incident, errors.New("guard: no record store")
	}

	// A fixed-width time sorts as text.
	incident.ID = fmt.Sprintf("%020d", incident.Time.UnixNano())
	incident.Boxes = incident.Boxes[:min(len(incident.Boxes), 64)]

	body, err := json.Marshal(incident)
	if err != nil {
		return incident, err
	}

	prefix := stateapi.Key("incidents/" + safe(incident.Printer))
	if _, err = s.records.Put(ctx, prefix+"/"+stateapi.Key(incident.ID), body); err != nil {
		return incident, err
	}

	keys, err := s.records.List(ctx, prefix)
	if err != nil || len(keys) <= keepIncidents {
		return incident, nil
	}

	slices.Sort(keys)

	for _, old := range keys[:len(keys)-keepIncidents] {
		_ = s.records.Delete(ctx, old)
	}

	return incident, nil
}

// List answers the incidents of one printer, or of all when printer is empty,
// newest first.
func (s *Incidents) List(ctx context.Context, printer string) ([]Incident, error) {
	prefix := stateapi.Key("incidents")
	if printer != "" {
		prefix += stateapi.Key("/" + safe(printer))
	}

	keys, err := s.records.List(ctx, prefix)
	if err != nil {
		return nil, err
	}

	out := make([]Incident, 0, len(keys))

	for _, key := range keys {
		value, err := s.records.Get(ctx, key)
		if errors.Is(err, stateapi.ErrNoRecord) {
			continue
		}

		if err != nil {
			return nil, err
		}

		var incident Incident
		if json.Unmarshal(value.Bytes, &incident) == nil {
			out = append(out, incident)
		}
	}

	slices.SortFunc(out, func(a, b Incident) int { return b.Time.Compare(a.Time) })

	return out, nil
}

// safe makes a device id one key level.
func safe(id string) string {
	return strings.NewReplacer("/", "_", "\\", "_").Replace(id)
}
