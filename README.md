# bevy-tools

CI/CD templates for [Bevy](https://bevyengine.org) (Rust) game
projects, in the same spirit as
[ebitengine-tools](../ebitengine-tools) and
[godot-tools](../godot-tools).

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `run`, `wasm`, `export`, `binaries`, `watch`, `clean`).
- `example-woodpecker.yaml` — a one-line marker (`platform: bevy`): the
  full pipeline (version → build → binaries → upload → publish) is served by the update server's Woodpecker
  configuration extension — preview it with
  `curl "https://teletypegames.org/build/config?platform=bevy"`.
- `builder.Dockerfile` — the CI builder image: `rust:1-bookworm`
  (glibc — bevy's native linux build needs alsa/udev, which does not
  build against musl) with the wasm + `x86_64-pc-windows-gnu`
  targets, mingw-w64, the wasm-bindgen CLI and make/zip/curl baked
  in.
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
3. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` (a one-line marker — the
   pipeline itself is served by the update server; add `name:` when the
   software name differs from the repo name) and add the
   `application_token` secret in Woodpecker (an ApplicationToken with
   the `update` + `upload` scopes, created in the admin).
4. Copy `example-tasks.json` to `.vscode/tasks.json` and replace the
   binary name (`bevydemo`) with `$(PROJECT)`.

Local WASM builds additionally need
`rustup target add wasm32-unknown-unknown` and the `wasm-bindgen` CLI
(`cargo install wasm-bindgen-cli --version 0.2.100`).

The served pipeline uploads `$(PROJECT)-$(VERSION).html.zip` and the native
binary zips (`-win-x64.zip`, `-linux-x64.zip`) via `/build/upload`, then
triggers `/build/publish?platform=bevy&name=$(PROJECT)&version=$(VERSION)`.
The API's `BinaryAttachment` concern picks up the
`<name>-<version>-<slug>.zip` files automatically and registers them
as `win_x64` / `linux_x64` release assets.

## Native binaries

`make binaries VERSION=x.y` builds:

- **linux-x64** — a regular `cargo build --release` in the
  debian-based builder; the binary links against the builder's glibc
  and the usual desktop libs (alsa, udev).
- **win-x64** — mingw-w64 cross-compile via the
  `x86_64-pc-windows-gnu` target; the linker is set from the
  Makefile (`CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER`), no
  per-repo `.cargo/config` needed.
- **mac** — not built here: cgo-style native cross-compilation to
  darwin needs osxcross, the same (planned) toolchain as the
  ebitengine mac targets.

If the project has an `assets/` directory it is packaged next to the
binary — bevy loads it at runtime, it is not embedded.

## Builder image

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  --build-arg WASM_BINDGEN_VERSION=0.2.100 \
  -t git.teletypegames.org/build/bevy-builder:latest .
docker push git.teletypegames.org/build/bevy-builder:latest
```

Detailed documentation lives on the wiki: `/development/bevy`.
