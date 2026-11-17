# Changelog

## 0.1.0

- First release. Follows every camera with periodic capture, scores each new
  snapshot while its printer prints, and pauses the print when it looks failed.
- Two detectors: a built-in heuristic and a self-hosted Obico ML API.
- Routes `GET /status`, `GET /incidents` and `POST /printers/{printer}/reset`,
  and the `failure.detected` event.
