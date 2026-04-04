# Helm Chart Standards

This document defines how to structure and maintain Helm charts for microservices and shared platform components.

## Chart Layout

- Use **Helm 3** (`apiVersion: v2` in `Chart.yaml`).
- Standard directories:
  - `Chart.yaml` — metadata, version, dependencies
  - `values.yaml` — **default** safe defaults for local/minimal installs
  - `values-*.yaml` — environment or cloud overlays
  - `templates/` — Kubernetes manifests as Go templates
  - `templates/_helpers.tpl` — shared naming and labels

## `values.yaml` Structure

- Organize keys by concern:
  - `replicaCount`, `image`, `imagePullSecrets`
  - `service`, `ingress`, `resources`, `autoscaling`, `podSecurityContext`, `securityContext`
  - `config`, `env`, `extraVolumes`, `extraVolumeMounts`
  - `serviceAccount`, `rbac`, `monitoring`
- Document **every** top-level key with comments in `values.yaml` or in `README.md` for the chart.
- Avoid embedding **secrets** in values files committed to Git; use `existingSecret`, external secrets operator, or CI-injected `-f` files not stored in repo.

## Environment Overlays

- Maintain separate files such as:
  - `values-dev.yaml` — low replicas, debug, ingress off or internal
  - `values-staging.yaml` — production-like, smaller scale
  - `values-prod.yaml` — HA, strict resources, PDB, HPA, TLS
- **Compose** at install time:

```bash
helm upgrade --install myapp ./chart \
  -f values.yaml \
  -f values-prod.yaml \
  -f values-azure-aks.yaml \
  --namespace prod --create-namespace
```

Later files **override** earlier ones for duplicate keys.

## Cloud-Specific Overlays

- Split cloud differences into dedicated files:
  - `values-azure-aks.yaml` — ACR image registry, AGIC/APP Gateway ingress, Azure Monitor, Key Vault CSI
  - `values-aws-eks.yaml` — ECR, ALB annotations, Secrets Store CSI, CloudWatch
  - `values-gcp-gke.yaml` — Artifact Registry, GKE Ingress/Gateway, Secret Manager CSI, Cloud Logging
- Keep **shared** behavior in `values.yaml`; put only deltas in cloud files.

## `_helpers.tpl` Conventions

- Define consistent helpers (names are examples—use one pattern per org):
  - `chart.name` — chart name short form
  - `chart.fullname` — release-expanded name for resources
  - `chart.labels` — standard labels (`app.kubernetes.io/name`, `instance`, `version`)
  - `chart.selectorLabels` — subset used in `spec.selector`
  - `serviceAccount.name` — computed SA name
- Prefix helper names with the **chart name** or `common` to avoid collisions in umbrella charts.

## `Chart.yaml` Metadata

- Required fields: `apiVersion`, `name`, `version`, `description`.
- Set `appVersion` to the application version (may differ from chart `version`).
- Use `keywords`, `maintainers`, `sources` for discoverability.
- Declare `dependencies` with **version ranges** pinned responsibly (`^1.2.0` vs exact `1.2.3` per risk tolerance).

## Dependency Management

- Vendor subcharts under `charts/` via `helm dependency update` for reproducible builds, or reference OCI/registry dependencies with locked versions in `Chart.lock`.
- Document upgrade steps for subchart major versions.

## Umbrella Charts

- Use an **umbrella** chart to deploy multiple microservices in one release when release coupling is intentional (same rollout train).
- Children charts should remain **independently releasable** where possible; umbrella composes versions via `dependencies`.
- Share common values through **global** (`global.imageRegistry`) sparingly—prefer explicit per-subchart values for clarity.

## Values Composition Rules

- **Base** + **env** + **cloud** is the default pattern.
- Never duplicate large blocks; use YAML anchors only if your tooling supports them consistently (often prefer Helm `tpl` and smaller includes).
- Validate composed values with `helm template` and `helm lint` in CI for every overlay combination you support.

## Testing and CI

- Run `helm lint` and `helm template` with representative `-f` combinations.
- Use **chart-testing** (`ct`) or equivalent for PR validation when charts live in a multi-chart repo.

## Schema and Validation

- Optionally add **`values.schema.json`** to validate value types and required keys for safer upgrades.
- Use **`helm unittest`** or similar for template assertions on critical labels and resource blocks.

## Rollbacks

- `helm rollback <release> <revision>` restores prior manifests; ensure **database** and **cache** compatibility when rolling back application logic.

## Secrets and External Systems

- Prefer **External Secrets Operator**, **Secrets Store CSI**, or cloud-specific operators over committing encrypted secrets in Git unless using **SOPS/Sealed Secrets** with a documented key management process.

## Chart Versioning vs App Version

- Bump **chart `version`** when templates or default values change behavior.
- Bump **`appVersion`** when the packaged application version changes, even if templates are unchanged.

## Review Checklist

- [ ] `Chart.yaml` complete with `version` and `appVersion`  
- [ ] `values.yaml` documented and safe by default  
- [ ] Environment and cloud overlays separated  
- [ ] Helpers consistent for name, labels, selectors  
- [ ] No plaintext secrets in Git-tracked values  
- [ ] Install docs show `helm install` with composed `-f` files  
- [ ] Rollback and upgrade notes captured for breaking changes  
