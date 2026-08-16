# CI builder image for Bevy projects: Rust toolchain with the
# wasm32-unknown-unknown target and the wasm-bindgen CLI preinstalled,
# so the pipeline's build step does not download them on every run.
#
# Debian-based (glibc) rather than alpine: the native linux binary needs
# glibc + alsa/udev dev libs (wgpu/winit), which bevy cannot build against
# musl. The windows binary is cross-compiled with mingw-w64
# (x86_64-pc-windows-gnu target). Mac is not cross-compiled here — that
# is the same osxcross story as the ebitengine mac targets.
#
# WASM_BINDGEN_VERSION must match the `wasm-bindgen` crate version pinned
# in the game repos' Cargo.toml (see README) — rebuild and retag this image
# when bumping it. The CLI is the x86_64 musl binary (static, runs on
# glibc too), so the image must be built for linux/amd64.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f builder.Dockerfile \
#     --build-arg WASM_BINDGEN_VERSION=0.2.100 \
#     -t git.teletypegames.org/build/bevy-builder:latest .
#   docker push git.teletypegames.org/build/bevy-builder:latest

FROM rust:1-bookworm

ARG WASM_BINDGEN_VERSION=0.2.100

RUN apt-get update && apt-get install -y --no-install-recommends \
      make zip curl git jq pkg-config \
      libasound2-dev libudev-dev libwayland-dev libxkbcommon-dev \
      gcc-mingw-w64-x86-64 \
 && rm -rf /var/lib/apt/lists/*

# linux-arm64 cross-build (Raspberry Pi, Odroid, retro handhelds). Debian's
# main mirror carries arm64, so a plain `dpkg --add-architecture` is enough —
# no ports repository needed. The :arm64 -dev packages are what alsa-sys and
# libudev-sys link against; pkg-config finds them via PKG_CONFIG_PATH, which
# the pipeline sets.
RUN dpkg --add-architecture arm64 \
 && apt-get update && apt-get install -y --no-install-recommends \
      gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
      libasound2-dev:arm64 libudev-dev:arm64 \
      libwayland-dev:arm64 libxkbcommon-dev:arm64 \
 && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown x86_64-pc-windows-gnu aarch64-unknown-linux-gnu

RUN curl -sSL "https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar xz -C /usr/local/bin --strip-components=1 \
 && wasm-bindgen --version

WORKDIR /workspace

CMD ["/bin/sh"]
