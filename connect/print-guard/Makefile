# Build, test and package this extension.
#
#   make core      fetch the pinned Prusa Connect checkout into .core/
#   make check     Go vet and tests
#   make release   the release directory the marketplace takes, in release/
#   make install   install release/ into a local Prusa Connect data dir, to try it
#
# Until the Prusa Connect SDK and the @prusa npm packages are published, both
# halves build against a checkout of Prusa Connect at CORE_REF. Raise CORE_REF
# to build against a newer core, and raise `require.core` in module.yaml with it.

CORE_REPO ?= https://github.com/prusa3d/prusa-connect.git
CORE_REF ?= v0.1.0-beta.1
CORE := .core

NAME := $(shell sed -n 's/^name:[[:space:]]*//p' module.yaml | head -1)
VERSION := $(shell sed -n 's/^version:[[:space:]]*//p' module.yaml | head -1)
MODULE := $(shell sed -n 's/^module[[:space:]]*//p' go.mod | head -1)
# github.com/acme/spools -> com.github.aux.acme.spools, the host's own rule for
# a GitHub module path.
NAMESPACE := $(shell echo $(MODULE) | sed -n 's|^github\.com/\([^/]*\)/\([^/]*\)$$|com.github.aux.\1.\2|p')
PLATFORMS := $(shell sh scripts/platforms.sh)

RELEASE := release
export CI ?= true

.PHONY: core check release install clean

# The checkout is cloned once. To move to another CORE_REF, `rm -rf .core`
# first.
$(CORE)/.git:
	git -c advice.detachedHead=false clone --quiet --depth 1 --branch $(CORE_REF) $(CORE_REPO) $(CORE)

check: core
	go vet ./...
	go test ./...

# The release holds module.yaml, the docs and one binary per platform.
# Each binary is built with CGO off and -trimpath.
release: core
	rm -rf $(RELEASE)
	mkdir -p $(RELEASE)
	cp module.yaml $(RELEASE)/
	cp LICENSE README.md CHANGELOG.md $(RELEASE)/
	@for platform in $(PLATFORMS); do \
		goos=$${platform%%_*}; goarch=$${platform#*_}; \
		binary=$(NAME)_$$platform; [ $$goos = windows ] && binary=$$binary.exe; \
		echo "building $$binary"; \
		CGO_ENABLED=0 GOOS=$$goos GOARCH=$$goarch go build -trimpath -ldflags='-s -w' -o $(RELEASE)/$$binary . || exit 1; \
		chmod +x $(RELEASE)/$$binary; \
	done
	@echo "$(NAME) $(VERSION) is in $(RELEASE)/"

# Installs release/ into bin/try with the pinned core's own `module add`, then
# prints how to start that core with it. Only this machine's binary is needed.
TRY := $(CURDIR)/bin/try
install: release
	mkdir -p $(TRY)
	printf 'core:\n  overlay: %s/resources.json\n  modules: %s/modules\n  authz:\n    database: %s/authz.db\n  api:\n    addr: 127.0.0.1:18480\n' \
		"$(TRY)" "$(TRY)" "$(TRY)" > $(TRY)/config.yaml
	go -C $(CORE) run ./cmd/prusa-connect module add "$(MODULE)@$(VERSION)" \
		-config "$(TRY)/config.yaml" -from "$(CURDIR)/$(RELEASE)" -approve
	@echo
	@echo "Installed. Build the core with its web app once:  make -C $(CORE) build"
	@echo "Then start it:                                    (cd $(TRY) && $(CURDIR)/$(CORE)/bin/server -config config.yaml)"
	@echo "Finish the first run at http://127.0.0.1:18480 with the setup code it logs, and open Hello in the sidebar."

clean:
	rm -rf $(RELEASE) bin

core: $(CORE)/.git
