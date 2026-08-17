# Multi-stage build producing a static, CGO-free binary in a minimal
# distroless runtime image.

FROM golang:1.26-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags "-s -w" -o /out/wallet ./cmd/wallet

# Distroless has no shell/chown, so the empty data directory is prepared
# here and copied in with the "nonroot" image's UID:GID (65532:65532).
# Docker seeds a freshly created named volume from the image's content at
# that mount path, so this is what makes /data (and therefore /data/blobs,
# created by the server at startup) writable by the nonroot process -
# without it, the volume is created root-owned and the server fails with
# "permission denied" on its first MkdirAll. See DECISIONS.md.
RUN mkdir -p /out/data

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/wallet /app/wallet
COPY --from=build --chown=65532:65532 /out/data /data

ENV WALLET_ADDR=:8443
ENV WALLET_DB_PATH=/data/wallet.db
ENV WALLET_BLOB_DIR=/data/blobs

VOLUME ["/data"]
EXPOSE 8443

ENTRYPOINT ["/app/wallet"]
