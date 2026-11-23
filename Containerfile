# syntax=docker/dockerfile:1
# Builds the Mayberry branch daemon as a small, rootless container image.
# Works with `podman build` / `buildah bud` (and `docker build`).

ARG GO_VERSION=1.26

# ---- build stage ----------------------------------------------------------
FROM --platform=$BUILDPLATFORM docker.io/library/golang:${GO_VERSION}-alpine AS build
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev
WORKDIR /src

# Let Go fetch the exact toolchain pinned in go.mod if the base image is older.
ENV GOTOOLCHAIN=auto CGO_ENABLED=0

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w -X main.Version=${VERSION}" \
      -o /out/mayberry ./cmd/branch

# ---- runtime stage --------------------------------------------------------
# distroless/static: CA certs + tzdata, no shell, runs as non-root (65532).
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/mayberry /usr/local/bin/mayberry

# Config lives in $HOME/.mayberry, so point HOME at a persistent volume.
ENV HOME=/data \
    MAYBERRY_LIBRARY=/library
VOLUME ["/data", "/library"]

EXPOSE 1950
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/mayberry"]
CMD ["--daemon"]
