# Performance Standards

This document defines performance **principles**, **budgets**, and **patterns** for APIs, data access, memory, network, serialization, and startup. Optimize based on **measurements**, not assumptions.

---

## Universal principles

1. **Measure before optimizing**: Use profilers, APM, distributed tracing, and database `EXPLAIN`—not guesswork.
2. **Response time budgets**:
   - **API endpoints**: **&lt; 200ms p95** under expected load (adjust per product SLAs if documented stricter).
   - **Database queries**: **&lt; 50ms p95** for typical transactional queries (complex reporting may use separate paths with explicit expectations).
3. **Caching**: Cache expensive computation, DB reads, and external API responses with **explicit TTL**, **size bounds**, and **invalidation** strategy—never “cache forever” without plan.
4. **Pagination**: Prefer paginated list endpoints; enforce **maximum page size** and default limits.
5. **Lazy loading**: Load expensive resources only when needed; **eager** load only when access is guaranteed in the same request to avoid N+1.
6. **Resource pooling**: Pool threads, DB connections, HTTP clients, and buffers—align pool sizes with concurrency limits.

---

## Concerns matrix

| Concern | Pattern | Anti-Pattern |
|---------|---------|--------------|
| Database queries | Use indexes, avoid N+1 (use JOINs or batch loading), `EXPLAIN ANALYZE` for slow queries | `SELECT *`, unbounded queries, query-per-loop |
| Memory | Stream large data, bound collection sizes, use weak references for caches | Loading entire files/result sets into memory, unbounded caches |
| Network | Connection pooling, request batching, HTTP/2 multiplexing, gzip compression | Per-request connection creation, synchronous serial calls to independent services |
| Serialization | Use efficient formats (Protocol Buffers, MessagePack) for internal services; JSON for external APIs | Serializing/deserializing in hot loops, custom serialization without benchmarks |
| Startup | Lazy initialization for non-critical dependencies, async warmup for caches/pools | Blocking startup on external services, loading all configs eagerly |

---

## Database

- **Indexes**: Match query predicates and sort columns; monitor index bloat and unused indexes.
- **N+1**: Use batch loaders, JOINs, or ORM eager-load hints where appropriate; verify with query logs in dev.
- **Unbounded scans**: Always cap list queries with `LIMIT` + cursor/keyset pagination for large tables.

## Memory and streaming

- **Stream** file uploads/downloads and large HTTP bodies; avoid `readAll` into byte arrays for unbounded inputs.
- **Bound** in-memory caches (entries and bytes); evict with LRU/TTL policies.

## Network

- **Reuse** connections; tune pool sizes for peak RPS.
- **Parallelize** independent outbound calls with bounded concurrency (see `concurrency.md`).
- Enable **compression** where CPU cost is acceptable vs. payload size.

## Serialization

- Prefer **schema evolution**-friendly formats for internal gRPC/Protobuf services.
- For JSON APIs, avoid serializing huge graphs—use DTOs and pagination.

## Startup

- **Fail fast** on misconfiguration, but avoid blocking on non-critical optional services during boot.
- **Warm** critical caches after deploy if cold start violates SLO—coordinate with orchestration health checks.

---

## Observability for performance

| Signal | Use |
|--------|-----|
| Latency histograms | p50/p95/p99 per route and dependency |
| Saturation | Pool usage, queue depth, CPU |
| Errors | Timeout rate, 5xx correlated with load |

---

## Review gates

- Flag **N+1** patterns, **unbounded** queries, **per-request** connection creation, and **hot-path** JSON without evidence of acceptable cost.
- Verify **pagination** on new list endpoints and **indexes** for new filter/sort fields.

Performance work MUST preserve correctness and security; do not cache without invalidation analysis or skip validation for speed.

---

## Caching strategies

| Strategy | When | Risk |
|----------|------|------|
| Cache-aside | Read-heavy, tolerates stale | Stale reads on update—need TTL or invalidation |
| Write-through | Strong consistency needs | Higher write latency |
| CDN / edge | Static or semi-static assets | Cache poisoning if headers misconfigured |

Always define **cache key** versioning when schema changes—avoid silent incompatible entries.

---

## Pagination patterns

- **Offset/limit**: simple but degrades on large offsets—prefer **keyset** (seek) pagination for deep lists.
- Enforce **max limit** server-side; ignore or clamp client-provided `limit`.

---

## Profiling workflow

1. Reproduce under **representative** load (data volume + concurrency).
2. Capture **CPU flame graphs** and **allocation** profiles for hot endpoints.
3. Optimize the **top contributors** first; re-measure after each change.
4. Add **regression tests** or benchmarks for fixed hotspots.

---

## Database indexing checklist

| Step | Action |
|------|--------|
| 1 | List filters, joins, and sort columns for each query |
| 2 | Add composite indexes matching **leftmost prefix** rules |
| 3 | Run `EXPLAIN (ANALYZE, BUFFERS)` on production-like data |
| 4 | Monitor **index hit ratio** and **bloat** post-deploy |

---

## Cold starts and serverless

- Minimize **bundle size** and **import** graphs in lambdas/edge functions.
- **Reuse** clients across invocations where the runtime allows (connection reuse).
- Avoid **synchronous** dependency chain during init—defer non-critical setup.

---

## Review checklist (performance)

| # | Check |
|---|--------|
| P1 | p95 budgets considered for new endpoints |
| P2 | No N+1; pagination on lists |
| P3 | Caches have TTL/size/invalidation |
| P4 | Pools used for DB/HTTP |
| P5 | Large payloads streamed |
| P6 | Indexes for new query paths verified |

Performance optimizations MUST NOT weaken **authz**, **validation**, or **audit** trails.

---

## API latency budget breakdown (example)

| Segment | Target share of 200ms p95 |
|---------|---------------------------|
| AuthN/AuthZ | 10–20ms |
| Business logic | Remainder |
| DB round-trips | Minimize count |
| Serialization | Single pass |

Adjust per product; document **internal** vs **external** dependency budgets separately.

---

## N+1 detection (ORM)

- Enable **SQL logging** in dev/staging with thresholds.
- Use **DataLoader** pattern (GraphQL/Node), **JOIN FETCH** (JPA), **Include** (EF Core) deliberately.
- Add **integration tests** that assert query count for representative pages.

---

## Memory profiling

- Capture **heap dumps** only in controlled environments; **redact** PII before sharing.
- Watch for **large object heap** pressure on .NET for big JSON payloads—stream instead.

---

## Network fan-out

- **Batch** calls to downstream services when APIs support it.
- **Circuit break** chatty dependencies; degrade gracefully with cached defaults only when business-approved.

---

## JSON performance

- Avoid **pretty-print** in production logs hot paths.
- Reuse **`JsonSerializer`** / `ObjectMapper` instances where thread-safe and expensive to create.

---

## Load testing

- Define **RPS**, **payload size**, and **think time** profiles matching production peaks.
- **Soak** tests catch memory leaks and connection pool misconfigurations.

---

## Cost vs performance

- Faster **does not always mean cheaper**—more caching nodes add cost. Document **trade-offs** in ADRs for major changes.

Performance is a **feature** tied to reliability and user trust—measure continuously, not only before launch.
