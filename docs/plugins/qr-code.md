# QR Code Generator

Available independently as `dev.leotrax3d.qr-code` and in **Utilities**, under
**Generators → QR Code**. Requires PrusaSlicer 3.0.0-alpha13 or newer.

Enter text or a URL (1–120 bytes), module size (0.8–5 mm), plate thickness
(0.4–10 mm), and relief height (0.2–3 mm). Defaults are 1.2, 2 and 0.6 mm.
The encoder selects the QR version automatically with medium error correction.
The plate includes a four-module quiet zone. No network access is needed.

Print a light plate and dark raised modules, using a filament change at the
plate's top height or painting the raised faces. Geometry alone does not ensure
optical contrast. Keep the quiet zone light; test the finished print with a scanner.
Unicode is encoded as UTF-8 bytes without an ECI marker; reader support can vary.
No printer or filament presets are changed. Slicer integration and physical
scan reliability require manual verification.

The bundled `qrencode.lua` is speedata/luaqrcode (BSD-3-Clause), upstream commit
`5a9c34bc04d5113048df8528af72ef31d25b7300`:
https://github.com/speedata/luaqrcode . Its full license is retained in the source.
The plugin wrapper is MIT licensed.
