# bevy-tools

CI/CD templates for [Bevy](https://bevyengine.org) (Rust) game
projects, in the same spirit as
[ebitengine-tools](../ebitengine-tools) and
[godot-tools](../godot-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `run`, `wasm`, `export`, `watch`, `clean`) plus the
  Woodpecker pipeline targets (`ci-version`, `ci-export`, `ci-upload`,
  `ci-update`).
- `example-woodpecker.yaml` — Woodpecker pipeline: version → build
  (Rust, `wasm32-unknown-unknown` target + `wasm-bindgen` in the
  `git.teletypegames.org/internal/bevy-builder` image) → upload (scp to the
  droparea) → update (calls the teletypegames `/update` endpoint with
  `platform=bevy`).
- `builder.Dockerfile` — the CI builder image: `rust:1-alpine` with
  the wasm target, the wasm-bindgen CLI and make/zip/curl baked in.
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run** (`cargo run`, default build task, `Cmd+Shift+B`),
  **Build & Run**, **Build WASM** and **Make build**.
- `web/index.html` — the HTML shell downloaded by `make export` and
  packaged next to the `wasm-bindgen` output (`game.js` +
  `game_bg.wasm`).

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (must match the crate name in `Cargo.toml`; the native binary is
   built to `bin/$(PROJECT)`).
2. Pin the `wasm-bindgen` crate in `Cargo.toml` to the exact version
   in `WASM_BINDGEN_VERSION`:

   ```toml
   [target.'cfg(target_arch = "wasm32")'.dependencies]
   wasm-bindgen = "=0.2.100"
   ```

   The `wasm-bindgen` CLI and the crate **must be the same version**,
   otherwise the generated JS glue refuses to load. The builder image
   ships the CLI — when bumping the version, rebuild the image with
   the matching `--build-arg WASM_BINDGEN_VERSION`.
3. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` and add the
   `droparea_ssh_password` / `update_secret_key` secrets in Woodpecker.
4. Copy `example-tasks.json` to `.vscode/tasks.json` and replace the
   binary name (`bevydemo`) with `$(PROJECT)`.

Local WASM builds additionally need
`rustup target add wasm32-unknown-unknown` and the `wasm-bindgen` CLI
(`cargo install wasm-bindgen-cli --version 0.2.100`).

The pipeline uploads `$(PROJECT)-$(VERSION).html.zip` to the droparea,
then triggers
`/update?platform=bevy&name=$(PROJECT)&version=$(VERSION)`.

## Builder image

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  --build-arg WASM_BINDGEN_VERSION=0.2.100 \
  -t git.teletypegames.org/internal/bevy-builder:latest .
docker push git.teletypegames.org/internal/bevy-builder:latest
```

Detailed documentation lives on the wiki: `/development/bevy`.
