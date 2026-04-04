# Multi-stage Go service — static binary + distroless
# Build context: module root (go.mod at root).
# Set BINARY_NAME to your main package path if not ./cmd/server

ARG GO_VERSION=1.22-alpine
ARG MAIN_PATH=./cmd/server
ARG APP_UID=1001
ARG APP_GID=1001

# --- Build ---
FROM golang:${GO_VERSION} AS builder
WORKDIR /src

RUN apk add --no-cache ca-certificates git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

RUN go build -trimpath -ldflags="-s -w -extldflags '-static'" -o /out/app ${MAIN_PATH}

# --- Runtime: distroless static (nonroot) ---
FROM gcr.io/distroless/static:nonroot AS runtime

# distroless nonroot user is typically uid 65532; align with platform policy.
# For strict UID 1001, use static-debian12 + USER 1001 (larger image) — this template uses official nonroot.

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /out/app /app/app

WORKDIR /app

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/app"]

# Distroless has no shell/wget; rely on K8s probes or add minimal health binary.
# HEALTHCHECK omitted — configure liveness/readiness in Kubernetes manifests.

LABEL org.opencontainers.image.title="go-service" \
      org.opencontainers.image.description="Go static binary on distroless static nonroot"
