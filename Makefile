# koreader-komga — test & lint targets.
#
#   make test              -> fast unit tests of the pure modules (plain busted, no KOReader)
#   make lint              -> luacheck static analysis
#   make test-integration  -> drive the real KOReader widgets headlessly via `kodev test front`
#   make release VERSION=   -> cut a CalVer release (see scripts/release.sh)

KOREADER_HOME ?= ../koreader

# luacheck binary. On macOS with Homebrew Lua 5.5, luacheck 1.2.0 crashes; install it
# under LuaJIT and point here:  make lint LUACHECK=$$HOME/.luarocks/bin/luacheck
LUACHECK ?= luacheck

SRC := src
# Name used inside koreader/plugins and in the release zip.
PLUGIN := komga.koplugin
INTEGRATION_SPEC := spec/integration/komga_spec.lua
# kodev's meson runner registers each test by basename minus "_spec.lua"
# (komga_spec.lua -> komga), so that's the name passed to `kodev test front`.
INTEGRATION_NAME := $(patsubst %_spec.lua,%,$(notdir $(INTEGRATION_SPEC)))

.PHONY: test lint test-integration link-integration unlink-integration release help

help:
	@echo "Targets: test | lint | test-integration | link-integration | unlink-integration | release VERSION=YYYY.MM.DD"

test:
	busted

lint:
	$(LUACHECK) $(SRC) spec

# Symlink our source (as komga.koplugin) + integration spec into a koreader checkout,
# then run the frontend test harness (busted inside the real KOReader env, headless).
test-integration: link-integration
	cd "$(KOREADER_HOME)" && ./kodev test front $(INTEGRATION_NAME)

link-integration:
	@test -d "$(KOREADER_HOME)" || { echo "KOREADER_HOME='$(KOREADER_HOME)' is not a koreader checkout. Set KOREADER_HOME=/path/to/koreader"; exit 1; }
	@test -x "$(KOREADER_HOME)/kodev" || { echo "No kodev in '$(KOREADER_HOME)'. Clone koreader and run ./kodev build first."; exit 1; }
	ln -sfn "$(CURDIR)/$(SRC)" "$(KOREADER_HOME)/plugins/$(PLUGIN)"
	ln -sfn "$(CURDIR)/$(INTEGRATION_SPEC)" "$(KOREADER_HOME)/spec/unit/komga_spec.lua"
	@echo "Linked $(SRC) (as $(PLUGIN)) and komga_spec.lua into $(KOREADER_HOME)."

unlink-integration:
	rm -f "$(KOREADER_HOME)/plugins/$(PLUGIN)" "$(KOREADER_HOME)/spec/unit/komga_spec.lua"
	@echo "Removed komga symlinks from $(KOREADER_HOME)."

release:
	./scripts/release.sh $(VERSION)
