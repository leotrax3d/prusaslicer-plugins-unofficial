#!/bin/sh
# Prints the platforms module.yaml declares, one GOOS_GOARCH per line: the
# list under `platforms:`, up to the next key at the left margin.
awk '
	/^platforms:/ { inside = 1; next }
	inside && /^[^ \t#]/ { inside = 0 }
	inside && /^[ \t]*-[ \t]/ { sub(/^[ \t]*-[ \t]*/, ""); sub(/[ \t]*(#.*)?$/, ""); print }
' "${1:-module.yaml}"
