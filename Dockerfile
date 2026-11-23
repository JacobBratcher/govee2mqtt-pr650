# Builds govee2mqtt from manuveli's fork (PR #650 — APP_VERSION bump)
# Drop-in replacement for ghcr.io/wez/govee2mqtt

ARG SOURCE_REPO=https://github.com/manuveli/govee2mqtt.git
ARG SOURCE_REF=main

####################################################################################################
## Builder — native Rust build
####################################################################################################
FROM rust:1-bookworm AS builder
ARG SOURCE_REPO
ARG SOURCE_REF

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_REPO}" .

# Apply wez/govee2mqtt PR #645 — fix H66A1 i18n name field parse crash
COPY patches/ /patches/
RUN git apply --verbose /patches/0001-pr645-h66a1-i18n.patch

# One-clicks: fall back to the app account token when community-api login is
# rejected, and default to Govee Home app version 7.7.02
RUN git apply --verbose /patches/0002-oneclick-app-token-fallback.patch

# One-clicks: cache the Tap-to-Run list for 5 minutes instead of a day, so
# new scenes show up after a restart instead of up to a day later
RUN git apply --verbose /patches/0003-oneclick-short-cache.patch

RUN cargo build --release --bin govee
RUN strip target/release/govee

# Create the govee user/group files we'll copy into the final image
RUN adduser \
        --disabled-password \
        --gecos "" \
        --home "/nonexistent" \
        --shell "/sbin/nologin" \
        --no-create-home \
        --uid "1000" \
        govee

# Empty /data we can chown into the final image
RUN mkdir -p /data && chown 1000:1000 /data

####################################################################################################
## Final image — matches upstream layout exactly
####################################################################################################
FROM gcr.io/distroless/cc-debian12

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

WORKDIR /app

COPY --from=builder /src/target/release/govee /app/govee
COPY --from=builder /src/AmazonRootCA1.pem /app/AmazonRootCA1.pem
COPY --from=builder /src/assets /app/assets
COPY --from=builder --chown=govee:govee /data /data

USER govee:govee
LABEL org.opencontainers.image.source="https://github.com/manuveli/govee2mqtt"
LABEL org.opencontainers.image.description="govee2mqtt built from manuveli PR #650 + wez PR #645 (H66A1 i18n fix) + one-click app-token fallback (APP_VERSION 7.7.02) + 5-minute one-click cache"

ENV \
  RUST_BACKTRACE=full \
  PATH=/app:$PATH \
  XDG_CACHE_HOME=/data

VOLUME /data

CMD ["/app/govee", \
  "serve", \
  "--govee-iot-key=/data/iot.key", \
  "--govee-iot-cert=/data/iot.cert", \
  "--amazon-root-ca=/app/AmazonRootCA1.pem"]
