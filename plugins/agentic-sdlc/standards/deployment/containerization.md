# Containerization Standards

This document defines enterprise-grade practices for building and maintaining container images. Apply these rules to every service that ships as a Docker/OCI image.

## Goals

- **Reproducible builds** with deterministic layers and pinned base tags where practical.
- **Least privilege** at runtime (non-root, minimal filesystem permissions).
- **Small attack surface** via minimal bases and stripped artifacts.
- **Operability** via health checks and standard metadata.

## Multi-Stage Builds

- Use **at least two stages**: a **build** stage (compilers, package managers, tests) and a **runtime** stage (only what is required to run the app).
- Copy **only** compiled artifacts, virtual environments, or static bundles into the final stage. Never copy source repositories with `.git` history into runtime images.
- Name stages explicitly (`AS builder`, `AS runtime`) and document why each stage exists.
- Avoid `RUN` commands in the final stage that pull tooling unrelated to runtime (e.g., no `apt-get install build-essential` in runtime).

## Base Images

- Prefer **official** or **vendor-maintained** images with regular security updates.
- Prefer **slim**, **alpine** (when glibc compatibility allows), or **distroless** for production runtimes.
- **Pin** major/minor versions in tags (e.g., `python:3.12-slim-bookworm`) and adopt a process to bump bases on a schedule.
- Document any deviation from slim/distroless (e.g., native dependencies requiring full Debian).

## Non-Root User (UID 1001)

- Create a dedicated user and group in the Dockerfile (or rely on base image conventions) with **fixed UID/GID 1001** unless the platform mandates otherwise.
- Set `USER 1001:1001` (or named user mapped to that UID) before `ENTRYPOINT`/`CMD`.
- Ensure application directories are `chown`’d to that user; avoid world-writable paths.
- Do not rely on `root` to bind privileged ports; use **non-privileged ports** (e.g., 8080, 8443) or platform port mapping.

## `.dockerignore`

- Maintain a **`.dockerignore`** at the repository root (or image context root) that excludes:
  - VCS metadata (`.git`, `.gitignore` if not needed)
  - CI artifacts, local env files (`.env`, `*.pem`, `*.key`)
  - Test outputs, coverage, `node_modules` when reinstalled in build, IDE folders
- Keep the build context **small** to speed builds and reduce accidental secret inclusion.

## Layer Caching

- Order Dockerfile instructions from **least to most frequently changing**:
  - System packages and dependency manifests first (`package.json`, `pom.xml`, `go.mod`)
  - Application source last
- Combine `RUN` steps that change together to reduce layer count, but split when it hurts cacheability of expensive steps.
- Use **BuildKit** cache mounts where appropriate (`--mount=type=cache`) for package managers.

## Secrets and Configuration

- **Never** `ARG` or `ENV` long-lived secrets into image layers. Use runtime injection (Kubernetes Secrets, secret stores, OIDC).
- Avoid copying `kubeconfig`, cloud credentials, or `.env` files into the image.
- Use **multi-stage** builds so intermediate layers with build secrets are not present in the final image when using secret mounts.

## HEALTHCHECK

- Define `HEALTHCHECK` for long-running processes using the application’s **HTTP** or **TCP** readiness endpoint where possible.
- Use intervals and timeouts appropriate to orchestrator expectations; avoid aggressive probes that overload the app.
- For worker-only containers, use a command that validates process health or queue connectivity as agreed with SRE.

## LABEL Metadata

- Set **OCI-standard** labels where applicable:
  - `org.opencontainers.image.title`, `version`, `revision`, `source`
  - `maintainer` or org-specific contact
- Include **build timestamp** and **git commit** as labels only if they do not embed secrets and align with supply-chain policies.

## Minimal Attack Surface

- Remove package managers and shells from runtime images when feasible (distroless/static binaries).
- Run with **read-only root filesystem** where the orchestrator supports it; mount writable paths explicitly.
- Do not install debugging tools in production images; use ephemeral debug sidecars or dedicated debug images.

## Supply Chain

- Scan images in CI (**Trivy**, **Grype**, or equivalent) and fail on **critical** vulnerabilities per policy.
- Prefer **digest-pinned** bases in high-assurance environments (`image@sha256:...`).
- Sign images (Cosign/Notation) when the registry and cluster policy require it.

## Runtime Contract with Kubernetes

- Expose the **same port** documented in Helm/Kubernetes manifests (commonly **8080**).
- Ensure the process **binds to `0.0.0.0`**, not only `127.0.0.1`, so probes from the pod network succeed.
- Prefer **graceful shutdown** on `SIGTERM` with a timeout aligned to `terminationGracePeriodSeconds`.

## Windows and Cross-Platform Builds

- When developers build on Windows, enforce **Linux** as the target OS for production images (`GOOS=linux`, Node builds in Linux containers).
- Document any **platform-specific** paths in `COPY` instructions and validate with CI builds on Linux.

## Image Tagging and Promotion

- Immutable tags: **`git SHA`** or **`digest`** for production; avoid mutable `latest` in production deploys.
- Retain build provenance: CI should record **Dockerfile path**, **base image digest**, and **SBOM** when required by compliance.

## Troubleshooting

- **Permission denied** on volume mounts: verify `fsGroup` and read-only root with writable mount points.
- **Binary not found** in distroless: ensure `ENTRYPOINT` uses absolute paths and architecture matches (`amd64` vs `arm64`).

## Review Checklist

- [ ] Multi-stage build with minimal runtime stage  
- [ ] Non-root user UID **1001** (or documented exception)  
- [ ] `.dockerignore` present and excludes secrets/artifacts  
- [ ] No secrets in layers or build args persisted in image  
- [ ] HEALTHCHECK and LABELs defined  
- [ ] Base image justified and pinned appropriately  
- [ ] CI scanning enabled for the published tag  
- [ ] Port binding and graceful shutdown aligned with orchestrator settings  
