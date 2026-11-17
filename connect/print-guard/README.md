# Print Guard: Prusa Connect extension

Print Guard watches your printer cameras in Prusa Connect and **pauses a print that has
visibly failed** (spaghetti, a part knocked loose, a blob). It runs inside the Connect
server's own extension process, so **no browser tab has to stay open**.

## How it works

1. You switch on **periodic capture** for a printer's camera in Prusa Connect. The server
   then stores a snapshot on that cadence and publishes the event
   `com.prusa.connect.camera.snapshot.captured`.
2. Print Guard subscribes to that event, reads the JPEG from the storage, and asks the
   printer whether it is `PRINTING`. It judges nothing between prints or while paused.
3. A **detector** scores the frame:
   - `obico`: your self-hosted [Obico ML API](https://github.com/TheSpaghettiDetective/obico-server/tree/release/ml_api)
     with Obico's trained failure-detection model. This is the AI option and the more accurate one.
   - `heuristic` (built in, no setup): compares each frame with a slowly adapting
     background and counts cells that changed *and* turned into dense, tangled edges.
     A global light change is taken out, and steady layer growth is absorbed.
4. A tracker follows the score over the print. It compares an EWMA of recent frames
   with a baseline built from the unsuspicious frames. It skips the first frames of a
   print (warm-up), so one bad frame never fails a print.
5. Once the excess passes the threshold, Print Guard sends `core.command.pause_print`
   (or only reports, with `action: notify`). It stores an incident and publishes
   `failure.detected`. It acts **once per print**: if you resume, the picture becomes
   the new normal.

## Settings

| key | default | meaning |
| --- | --- | --- |
| `detector` | `auto` | `heuristic`, `obico`, or `auto` (obico when `obico_url` is set) |
| `action` | `pause` | `pause` or `notify` |
| `sensitivity` | `1` | 2 reacts to half the evidence, 0.5 needs twice as much |
| `warmup_frames` | `5` | snapshots never judged at the start of a print and after a resume |
| `obico_url` | | e.g. `http://192.168.1.20:3333` |
| `obico_token` | | the `ML_API_TOKEN` of your ML API, if set |
| `frame_base_url` | | how the ML API reaches this server's frames port, e.g. `http://192.168.1.10:18491` |

```yaml
resources:
  sink:
    print-guard:
      config:
        detector: obico
        obico_url: http://192.168.1.20:3333
        frame_base_url: http://192.168.1.10:18491
```

### Obico ML API

The Obico ML API fetches the picture from a URL itself. Print Guard therefore serves each
frame once, under a random path, for at most a minute, on the `frames` port (TCP 18491).
The operator approves that port at install. Start the ML API, for example from the
obico-server repository:

```bash
docker compose up -d ml_api
```

## Routes

| route | answer |
| --- | --- |
| `GET /status` | detector, action, and for each camera: printer, verdict, score, frames |
| `GET /incidents?printer=<id>` | stored incidents, newest first (50 per printer) |
| `POST /printers/{printer}/reset` | false alarm: the baseline starts over |

## Build

```bash
make check
```

```bash
make release
```

`make core` clones Prusa Connect `v0.1.0-beta.1` into `.core/` (the SDK is not yet
published as a Go module). Publishing follows the
[marketplace docs](https://plugin-marketplace.prusa3d.com/docs/connect/github-actions).

## Limits

- The heuristic is not a trained model. A person in the frame or a moving camera can
  raise its score. Use Obico for reliable detection.
- This release has no page in the Connect web app. Status and incidents are available
  through the routes.

## Publishing

`.github/workflows/connect-print-guard.yml` follows the
[GitHub Actions guide](https://plugin-marketplace.prusa3d.com/docs/connect/github-actions).
After the one-time setup described at the top of that file, a release is:

```bash
gh release create print-guard/v0.1.0 --title "Print Guard 0.1.0" --notes-file connect/print-guard/CHANGELOG.md
```
