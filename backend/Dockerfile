FROM rust:1.95-slim-bookworm AS builder
WORKDIR /app

# aws-lc-sys (pulled in by jsonwebtoken's aws_lc_rs feature) builds from
# source and needs a C toolchain + cmake; sqlx's offline mode below means
# no DATABASE_URL/network access is needed for the build itself.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake perl pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./
COPY .sqlx ./.sqlx
COPY migrations ./migrations
COPY src ./src

ENV SQLX_OFFLINE=true
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
# sqlx::migrate! embeds the migration files into the binary at compile
# time, so the runtime image needs nothing but the executable.
COPY --from=builder /app/target/release/moelan-api /usr/local/bin/moelan-api
EXPOSE 8000
CMD ["moelan-api"]
