module github.com/leotrax3d/prusaslicer-plugins-unofficial/connect/print-guard

go 1.26.11

require github.com/prusa3d/prusa-connect/sdk v0.0.0

// Until the SDK is published as a Go module, it is built from the pinned
// Prusa Connect checkout that `make core` puts in .core/ (see CORE_REF in
// the Makefile). Delete these lines once `go get` can fetch it.
replace github.com/prusa3d/prusa-connect/sdk => ./.core/sdk
