



FROM rust:alpine3.19 as base

WORKDIR /app
RUN apk add --no-cache \
  build-base \
  musl-dev \
  openssl-dev \
  openssl-libs-static \
  pkgconfig

ENV LC_ALL=C
ENV LANG=C 
ENV LANGUAGE=C
ENV RUSTFLAGS="-C linker=cc"

RUN cargo install sccache --locked
RUN cargo install cargo-chef --version 0.1.67
ENV RUSTC_WRAPPER=sccache SCCACHE_DIR=/sccache
RUN rustup target add x86_64-unknown-linux-musl

FROM base as planner
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef prepare --recipe-path recipe.json

FROM base as builder
COPY --from=planner /app/recipe.json recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json

COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo build -r --target x86_64-unknown-linux-musl

# runtime stage
FROM alpine:3.19 as runtime
WORKDIR /app
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/bat bat

ENTRYPOINT ["./bat"]
