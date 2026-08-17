# Multi-stage build producing a static, CGO-free binary in a minimal
# distroless runtime image.

FROM golang:1.26-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags "-s -w" -o /out/wallet ./cmd/wallet

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/wallet /app/wallet

ENV WALLET_ADDR=:8443
ENV WALLET_DB_PATH=/data/wallet.db
ENV WALLET_BLOB_DIR=/data/blobs

VOLUME ["/data"]
EXPOSE 8443

ENTRYPOINT ["/app/wallet"]
