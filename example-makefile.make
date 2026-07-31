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

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	FILE="$(PROJECT)-$$VERSION.html.zip"; \
	META_SRC="metadata.json"; \
	META_DST="$(PROJECT)-$$VERSION.metadata.json"; \
	cp $$META_SRC $$META_DST; \
	sshpass -p "$(DROPAREA_SSH_PASSWORD)" scp -o StrictHostKeyChecking=no -P $(DROPAREA_PORT) \
		$$FILE $$META_DST \
		$(DROPAREA_USER)@$(DROPAREA_HOST):$(DROPAREA_TARGET_PATH)/

ci-update:
	@VERSION=$$(cat $(VERSION_FILE)); \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=bevy&version=$$VERSION"

.PHONY: all build run wasm export watch clean ci-version ci-export ci-upload ci-update
