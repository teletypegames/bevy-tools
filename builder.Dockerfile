# CI builder image for Bevy projects: Rust toolchain with the
# wasm32-unknown-unknown target and the wasm-bindgen CLI preinstalled,
# so the pipeline's build step does not download them on every run.
#
# WASM_BINDGEN_VERSION must match the `wasm-bindgen` crate version pinned
# in the game repos' Cargo.toml (see README) — rebuild and retag this image
# when bumping it. The CLI is the x86_64 musl binary, so the image must be
# built for linux/amd64.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f builder.Dockerfile \
#     --build-arg WASM_BINDGEN_VERSION=0.2.100 \
#     -t git.teletypegames.org/internal/bevy-builder:latest .
#   docker push git.teletypegames.org/internal/bevy-builder:latest

FROM rust:1-alpine

ARG WASM_BINDGEN_VERSION=0.2.100

RUN apk add --no-cache musl-dev make zip curl git jq

RUN rustup target add wasm32-unknown-unknown

RUN curl -sSL "https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
      | tar xz -C /usr/local/bin --strip-components=1 \
 && wasm-bindgen --version

WORKDIR /workspace

CMD ["/bin/sh"]
