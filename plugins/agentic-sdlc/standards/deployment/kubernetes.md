# Kubernetes Manifest Standards

This document defines conventions for workloads running on Kubernetes. Treat these as defaults; platform teams may enforce additional constraints via admission controllers.

## Resource Requests and Limits

- Every container **must** declare `resources.requests` and `resources.limits` for **CPU** and **memory** unless exempted by policy (e.g., batch jobs with defined profiles).
- Set **requests** to the expected steady-state usage; set **limits** to prevent noisy neighbors while avoiding OOM thrashing.
- Use the same unit families consistently (`cpu: "500m"`, `memory: "512Mi"`).
- Document sizing in the service’s runbook and adjust using production metrics.

## Health Probes

- **Liveness**: detects deadlocks or unrecoverable states; should **restart** the container. Avoid checks that fail during normal load spikes.
- **Readiness**: gates **Service** endpoints; should fail when the app cannot serve traffic (dependencies down, migrations incomplete).
- **Startup**: for slow-starting apps (JVM warm-up, large caches); prevents liveness from killing containers during boot.
- Prefer **HTTP** probes hitting a lightweight `/health/live` and `/health/ready` (paths are examples—standardize per org).
- Configure `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, and `failureThreshold` explicitly—do not rely on defaults without review.

## Security Context (Pod and Container)

- **Pod security**:
  - `runAsNonRoot: true`
  - `runAsUser` / `fsGroup` aligned with image UID (**1001** default)
  - `seccompProfile` where cluster supports it (`RuntimeDefault` or approved custom profile)
- **Container security**:
  - `readOnlyRootFilesystem: true` with writable mounts only where required (`emptyDir`, volumes)
  - `allowPrivilegeEscalation: false`
  - `capabilities.drop: ["ALL"]`; add only **NET_BIND_SERVICE** or other strictly required caps by exception
- Avoid `hostNetwork`, `hostPID`, `hostIPC`, and privileged containers unless approved.

## Pod Disruption Budgets (PDB)

- For **HA** services, define `PodDisruptionBudget` to ensure minimum availability during node drains and upgrades.
- Choose `minAvailable` or `maxUnavailable` based on replica count and blast radius (e.g., `maxUnavailable: 1` for small clusters).
- Align PDB with **Deployment** replica count and **HPA** max replicas.

## Namespace Isolation

- Deploy application workloads into **dedicated namespaces** per team, environment, or system boundary—not a single shared `default` namespace.
- Use **ResourceQuotas** and **LimitRanges** per namespace to prevent resource exhaustion.
- Apply consistent **labels** (`app`, `version`, `env`, `team`) for selection and observability.

## Network Policies

- Default-deny **ingress** and **egress** where possible; allow only required paths:
  - Ingress from Ingress controller / mesh
  - Egress to DNS, APIs, databases, and observability endpoints
- Document allowed peers in the service’s network diagram or runbook.
- Prefer **CNI** features compatible with your mesh (e.g., Istio Linkerd) without duplicating conflicting rules.

## ConfigMaps and Secrets

- **ConfigMap**: non-sensitive configuration (feature flags as non-secret, log levels, public endpoints).
- **Secret**: credentials, tokens, TLS keys, connection strings with passwords.
- Mount Secrets as **files** or use **secretKeyRef** for env vars; avoid logging env at startup.
- Rotate Secrets via automation; version ConfigMaps when rolling config changes safely (sometimes requires Deployment rollout).

## High Availability and Scheduling

- For HA, run **multiple replicas** across **failure domains**:
  - `podAntiAffinity` (preferred or required) to spread pods across nodes/zones
  - Topology spread constraints (`topology.kubernetes.io/zone`) when clusters are multi-AZ
- Set **PodDisruptionBudget** and **maxUnavailable** in Deployments for controlled rollouts.

## Ingress and TLS

- Use **Ingress** or Gateway API with a **single** ingress class per environment.
- Terminate TLS at the ingress/controller or use **mesh** mTLS per policy; document the choice.
- Annotate for **timeouts**, **body size**, and **rate limits** as needed.

## Observability

- Ensure labels match **Prometheus**/`ServiceMonitor` conventions if metrics are scraped.
- Forward logs to the cluster logging stack; include **correlation IDs** in app logs (see platform logging standards).

## GitOps and Declarative State

- Store manifests in Git; apply via **GitOps** (Flux, Argo CD) or audited CI pipelines—avoid ad-hoc `kubectl apply` for production.

## Priority Classes and QoS

- Assign **PriorityClass** for critical platform services where the cluster uses preemption.
- Understand **QoS classes**: `Guaranteed` (limits = requests for all containers), `Burstable`, `BestEffort`. Production workloads should avoid **BestEffort** for latency-sensitive services.

## Storage

- Prefer **stateless** Deployments; use **StatefulSet** only when stable network identity or ordered rollout is required.
- For persistent data, use **CSI** drivers supported by your cloud; set `storageClassName` explicitly.

## Upgrades and Rollbacks

- Use **Deployment** rollout history (`kubectl rollout history`) and test rollback procedures (`kubectl rollout undo`).
- Coordinate **database migrations** with application rollouts using init jobs or external orchestration—avoid breaking schema compatibility.

## Resource Quotas and Limits

- Namespace **ResourceQuota** caps aggregate CPU/memory/object counts; **LimitRange** sets defaults for pods without explicit resources.

## Service Mesh (Optional)

- When using a mesh, align **probe ports** and **exclude** health endpoints from mTLS where required by the mesh vendor.
- Prefer **Workload Identity** for egress to cloud APIs instead of static keys in pods.

## Windows Nodes (If Applicable)

- Mixed Linux/Windows clusters require explicit **node selectors** and **tolerations**; this repo’s templates assume **Linux** unless stated otherwise.

## Review Checklist

- [ ] Requests/limits on every container  
- [ ] Liveness, readiness, and startup probes where applicable  
- [ ] `runAsNonRoot`, read-only root FS, dropped capabilities  
- [ ] PDB for HA workloads  
- [ ] Namespace + labels + NetworkPolicy considered  
- [ ] ConfigMap vs Secret separation  
- [ ] Anti-affinity / topology spread for HA  
- [ ] Rollback path validated; migrations coordinated  
