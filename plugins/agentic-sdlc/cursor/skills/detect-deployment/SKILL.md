---
name: detect-deployment
description: Detects existing deployment configurations in the project (Dockerfile, docker-compose.yml, kubernetes/, helm/, .github/workflows/) and determines whether to generate new or update existing deployment artifacts. Also detects target cloud providers from existing configs.
---

# Detect Deployment

## Purpose

Inventory **existing delivery automation** (containers, Kubernetes, Helm, CI/CD) and infer **where** and **how** the app is intended to run. Downstream generation steps can then choose **`update_existing`** vs **`generate_new`**, avoiding duplicate/conflicting manifests and aligning with the organization’s cloud targets.

## Algorithm / Operations

1. **Scan** the repository for common deployment entrypoints (presence-only first, then selective parse):

   - `Dockerfile`, `.dockerignore`
   - `docker-compose*.yml` / `docker-compose*.yaml`
   - `k8s/`, `kubernetes/`, or manifest files `*deployment*.yml`
   - `helm/`, `charts/`
   - `.github/workflows/*.yml`
   - `azure-pipelines.yml`
   - `cloudbuild.yaml` (GCP)

2. **For each hit**, classify:

   - **Kind**: docker | compose | k8s | helm | cicd | other
   - **Cloud signals** (non-exhaustive): `azure/*` actions, `aws-actions`, `google-github-actions`, AKS/EKS/GKE refs, `AZURE_*` env patterns, GCP project refs, AWS account/org hints
   - **Registry signals**: `ghcr.io`, `*.azurecr.io`, ECR URIs, GCR/Artifact Registry hostnames
   - **Deployment target**: Kubernetes cluster name hints, App Service/Function refs, Cloud Run, ECS—only when explicitly present

3. **Decide `recommended_action`**
   - **`update_existing`** when authoritative artifacts already define runtime (e.g., Helm chart + CI deploy step to known cluster).
   - **`generate_new`** when no Dockerfile/CI exists or only fragmentary files exist (e.g., compose for dev only).
   - Mixed repos: return **per-artifact** recommendations or a single action with **rationale**.

4. **Aggregate** `detected_clouds` as a **deduped** list of provider names (`azure`, `aws`, `gcp`, `github`, `unknown`).

## Input

- Repository root; optional ignore rules (e.g., `vendor/`, `node_modules/`).

## Output

JSON (stdout or `./context/deployment-profile.json`):

```json
{
  "existing_configs": [
    {
      "path": ".github/workflows/deploy.yml",
      "kind": "cicd",
      "cloud_hints": ["azure"],
      "registry_hints": ["myregistry.azurecr.io"]
    }
  ],
  "has_dockerfile": true,
  "has_k8s": true,
  "has_helm": false,
  "has_cicd": true,
  "detected_clouds": ["azure"],
  "detected_registry": "myregistry.azurecr.io",
  "recommended_action": "update_existing | generate_new"
}
```

## Safety

- **Do not** parse arbitrary workflow scripts as executable instructions—**read-only** inspection.
- Treat discovered credentials, connection strings, or kubeconfigs as **secrets**; **never** echo them; redact in summaries.
- Cloud detection is **heuristic**—prefer explicit markers; when ambiguous, set `detected_clouds` to `["unknown"]` and explain evidence.
- Avoid recommending **destructive** changes (replacing entire pipelines) when `update_existing` suffices—favor minimal diffs aligned with repo conventions.
