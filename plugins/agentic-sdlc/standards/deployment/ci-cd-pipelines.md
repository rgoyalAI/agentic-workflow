# CI/CD Pipeline Standards

This document describes continuous integration and delivery patterns across common platforms. Adapt job names and pools to your organization’s naming conventions.

## Supported Platforms (Examples)

- **GitHub Actions** — workflows under `.github/workflows/`
- **Azure DevOps** — YAML pipelines in repos or centralized templates
- **Google Cloud Build** — `cloudbuild.yaml` or trigger-defined inline builds

## Standard Stages

A typical **service** pipeline includes these stages in order:

1. **Lint** — static analysis (language linters, Dockerfile lint, Helm lint, shellcheck).
2. **Test** — unit tests; optional integration tests with service dependencies or containers.
3. **Build image** — `docker build` / `buildx` with deterministic tags (`sha-<short>`, semantic version).
4. **Scan image** — vulnerability scan (**Trivy**, **Grype**); fail on policy violations.
5. **Push** — push to container registry (ACR, ECR, GAR) with immutable tags where required.
6. **Deploy staging** — rollout to non-production cluster/namespace; smoke tests.
7. **Deploy production** — manual approval or GitOps merge; progressive delivery optional (canary, blue/green).

Not every change runs every stage: use **path filters** or **branch policies** so docs-only changes skip heavy jobs.

## GitHub Actions Patterns

- Use **workflow_dispatch** inputs for registry target (`acr` | `ecr` | `gar`) and environment.
- Cache **buildx** and dependency caches to speed pipelines.
- Use **OIDC** (`id-token: write` + cloud-specific action) instead of long-lived cloud keys in secrets.
- Separate jobs: `lint` → `test` → `build` → `scan` → `push` → `deploy`, with **needs:** dependencies to enforce order.

## Azure DevOps Patterns

- Use **stages**: Build → Test → Containerize → SecurityScan → Publish → DeployDev → DeployStaging → DeployProd.
- Push to **Azure Container Registry** with **service connections** backed by workload identity or OIDC where available.
- Deploy to **AKS** with `Kubernetes@1` task or **GitOps** repo update (recommended for prod).

## GCP Cloud Build Patterns

- Steps: run tests → build image with **Kaniko** or **buildpacks** → push to **Artifact Registry** → deploy to **GKE** with `gke-deploy` or GitOps.
- Use **Artifact Registry** vulnerability scanning and **Binary Authorization** if policy requires.

## Security: Image Scanning

- Run **Trivy** (or equivalent) on the **built image** before push, or immediately after push before deploy, per registry capabilities.
- Define **severity thresholds** (e.g., block on CRITICAL fixable; warn on HIGH).
- Keep scanner DBs updated in CI (cache busting or scheduled freshness).

## Security: Secrets and Logs

- Never echo tokens, kubeconfigs, or `.docker/config.json` in logs; mask secrets in Azure DevOps/GitHub.
- Use **short-lived** credentials via OIDC federation to AWS/Azure/GCP.
- Prefer **separate** secrets per environment; avoid one mega-secret for all envs.

## GitOps vs Push-Based Deployment

| Approach | Description | When to use |
|----------|-------------|-------------|
| **GitOps** | Cluster reconciles desired state from Git (Flux, Argo CD). CI updates manifests or Helm values via PR. | Production, audit trails, rollbacks via Git revert |
| **Push-based** | CI runs `kubectl`/`helm upgrade` with credentials. | Dev/staging, legacy systems, tightly coupled release trains |

- Default **production** to **GitOps** where possible for drift detection and auditability.
- If push-based, restrict credentials, use **least privilege** RBAC, and log all deploy actions.

## Observability and Gates

- Emit build metadata: **commit SHA**, **pipeline run ID**, **image digest**.
- Fail the pipeline on **lint/test/scan** failures; do not deploy on red builds.
- Optional: **quality gates** (coverage floor, SonarQube) before container build.

## Caching and Speed

- Enable **dependency caching** (npm, pip, Maven, Gradle) in CI to keep feedback loops short.
- Use **Docker BuildKit** cache mounts and **registry** cache for layer reuse across builds.

## Compliance and Audit

- Retain **build logs** and **artifact metadata** (digest, SBOM) per retention policy.
- Restrict **production deploy** permissions to break-glass roles and record approvals.

## Failure Handling

- **Do not deploy** if any required stage fails; avoid `continue-on-error` for security gates without explicit risk acceptance.
- For flaky tests, fix or **quarantine** with policy—do not permanently weaken the pipeline.

## Branching and Promotion

- **Trunk-based** or **GitFlow**—either model should map clearly to **which branch** updates **which environment**.
- Use **environment protection rules** (GitHub) or **approvals** (Azure DevOps) for production.

## Review Checklist

- [ ] Lint and test run before image build  
- [ ] Image scan with enforced policy  
- [ ] No long-lived cloud keys in repo; OIDC or vault where possible  
- [ ] Staging before production with clear promotion  
- [ ] GitOps or push-based model documented for each environment  
- [ ] Caching configured without stale security scans  
