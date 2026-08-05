# -----------------------------------------
# Makefile – Bevy project builder
# -----------------------------------------

PROJECT = bevydemo

# Must match the `wasm-bindgen` version pinned in Cargo.toml
# ([target.'cfg(target_arch = "wasm32")'.dependencies] wasm-bindgen = "=0.2.100")
WASM_BINDGEN_VERSION = 0.2.100

BIN_DIR      = bin
DIST_DIR     = dist
WASM_TARGET  = wasm32-unknown-unknown
WASM_RELEASE = target/$(WASM_TARGET)/release/$(PROJECT).wasm
OUTPUT_ZIP   = $(PROJECT)-$(VERSION).html.zip

VERSION_FILE = .version
INDEX_HTML_URL = https://git.teletypegames.org/tools/bevy-tools/raw/branch/master/web/index.html

all: build

build:
	@mkdir -p $(BIN_DIR)
	cargo build --release
	cp target/release/$(PROJECT) $(BIN_DIR)/$(PROJECT)

run:
	cargo run

wasm:
	@mkdir -p $(DIST_DIR)
	cargo build --release --target $(WASM_TARGET)
	wasm-bindgen --target web --no-typescript \
		--out-dir $(DIST_DIR) --out-name game $(WASM_RELEASE)

# -----------------------------------------
# Native binaries. linux-x64: glibc build in the debian-based builder
# image; win-x64: mingw-w64 cross-compile (x86_64-pc-windows-gnu).
# Mac needs osxcross, it is not built here.
# The zip gets the assets/ dir too if the project has one — bevy loads
# it at runtime, it is not embedded in the binary.
# -----------------------------------------

BINARY_SLUGS = win-x64 linux-x64
WIN_TARGET   = x86_64-pc-windows-gnu

# $(1) slug, $(2) built binary, $(3) file name inside the package
define f_pack_binary
	set -e; \
	PKG_DIR="$(PROJECT)-$(VERSION)-$(1)"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip"; \
	mkdir -p "$$PKG_DIR"; \
	cp "$(2)" "$$PKG_DIR/$(3)"; \
	chmod +x "$$PKG_DIR/$(3)"; \
	if [ -d assets ]; then cp -r assets "$$PKG_DIR/assets"; fi; \
	zip -qr "$$PKG_DIR.zip" "$$PKG_DIR"; \
	rm -rf "$$PKG_DIR"; \
	echo "==> $$PKG_DIR.zip kesz"
endef

binaries:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@$(MAKE) binary-linux binary-win VERSION=$(VERSION)

binary-linux:
	@echo "==> Building linux-x64 binary"
	cargo build --release
	@$(call f_pack_binary,linux-x64,target/release/$(PROJECT),$(PROJECT))

binary-win:
	@echo "==> Building win-x64 binary"
	CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
		cargo build --release --target $(WIN_TARGET)
	@$(call f_pack_binary,win-x64,target/$(WIN_TARGET)/release/$(PROJECT).exe,$(PROJECT).exe)

export: wasm
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@echo "==> Downloading index.html"
	curl -sSL $(INDEX_HTML_URL) -o $(DIST_DIR)/index.html
	@echo "==> Packaging HTML/WASM for $(VERSION)"
	zip -r $(OUTPUT_ZIP) -j $(DIST_DIR)/game_bg.wasm $(DIST_DIR)/game.js $(DIST_DIR)/index.html
	@echo "==> Cleaning temporary files"
	rm -f $(DIST_DIR)/game_bg.wasm $(DIST_DIR)/game.js $(DIST_DIR)/index.html

watch:
	fswatch -o src | while read; do make build; done

clean:
	rm -rf $(BIN_DIR) $(DIST_DIR) target

ci-version:
	@if [ -f metadata.json ]; then \
		VERSION=$$(jq -r '.version' metadata.json); \
	else \
		VERSION=$$(git rev-parse --short HEAD); \
	fi; \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ]; then \
		VERSION="dev-$$VERSION-$$BRANCH"; \
	fi; \
	echo $$VERSION > $(VERSION_FILE)

ci-export:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) export VERSION=$$VERSION

ci-binaries:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) binaries VERSION=$$VERSION

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	FILE="$(PROJECT)-$$VERSION.html.zip"; \
	META_SRC="metadata.json"; \
	META_DST="$(PROJECT)-$$VERSION.metadata.json"; \
	cp $$META_SRC $$META_DST; \
	BINS=""; \
	for slug in $(BINARY_SLUGS); do \
		[ -f "$(PROJECT)-$$VERSION-$$slug.zip" ] && BINS="$$BINS $(PROJECT)-$$VERSION-$$slug.zip"; \
	done; \
	for f in $$FILE $$META_DST $$BINS; do \
		curl -fsS -H "X-Update-Secret: $(UPDATE_SECRET)" \
			-F "file=@$$f" \
			"$(UPDATE_SERVER)/build/upload?name=$(PROJECT)&version=$$VERSION" || exit 1; \
	done

ci-update:
	@VERSION=$$(cat $(VERSION_FILE)); \
	curl -fsS -X POST -H "X-Update-Secret: $(UPDATE_SECRET)" "$(UPDATE_SERVER)/build/publish?name=$(PROJECT)&platform=bevy&version=$$VERSION"

.PHONY: all build run wasm export binaries binary-linux binary-win watch clean ci-version ci-export ci-binaries ci-upload ci-update
