# I/O Management

This document defines how file, network, stream, and database I/O MUST be performed: deterministic cleanup, buffering, streaming, timeouts, and pooling.

---

## Universal principles

1. **Deterministic resource cleanup**: Every acquired resource (streams, connections, clients) MUST be released via language-native mechanisms (`try-with-resources`, `with`, `defer`, `using`, `finally` with idempotent close).
2. **Buffered I/O**: Use buffered readers/writers for file workloads to reduce syscall overhead unless a single small read/write is guaranteed.
3. **Streaming for large payloads**: Prefer incremental read/write (HTTP chunked, `io.Copy`, async iterators) over loading entire bodies into memory.
4. **Explicit timeouts**: All network I/O (HTTP, DB, message queues) MUST use connect/read timeouts aligned with SLAs—never infinite waits.
5. **Connection pooling**: Database and HTTP clients MUST reuse pools configured for expected concurrency; do not open a new connection per request in hot paths.

---

## Per-language reference

| Language | Resource Cleanup | HTTP Client | File I/O | Database |
|----------|-----------------|-------------|----------|----------|
| Java | `try-with-resources` (AutoCloseable) | `HttpClient` (Java 11+) with timeouts, connection pool via `WebClient` (Spring) | `Files.newBufferedReader()`, NIO for large files | HikariCP pool, `@Transactional` scope |
| Python | `with` statement (context managers) | `httpx` (async), `requests` (sync) with `Session` for pooling and timeouts | `pathlib.Path`, `aiofiles` for async | SQLAlchemy session with `scoped_session`, asyncpg for async Postgres |
| Go | `defer file.Close()` | `http.Client{Timeout: 30*time.Second}`, reuse client instances | `os.Open` + `bufio.Scanner`, `io.Copy` for streaming | `sql.DB` (built-in pooling), `pgxpool` for Postgres |
| C# / .NET | `using` statement / `await using` | `IHttpClientFactory` (pooled, typed), `HttpClient` with `CancellationToken` | `FileStream` with `using`, `StreamReader` for buffered | `DbContext` lifetime via DI, `EF Core` connection pool |
| TypeScript | `try/finally`, `AbortController` | `fetch` with `AbortSignal.timeout()`, Axios with interceptors | `fs.createReadStream()` (Node), `fs/promises` for async | Prisma/Drizzle with connection pooling |

---

## HTTP clients

- **Single shared client** per process for a given base URL when the library is thread-safe / reusable (e.g., `HttpClient` factory in .NET, shared `httpx.AsyncClient`).
- Set **timeouts** at client or per-request level: connection establishment, total request, and optionally per-read for streaming.
- For **retries**, only retry idempotent methods or operations with deduplication keys; respect `Retry-After` when present.

## File I/O

- **Large files**: stream with fixed-size buffers; log progress only at coarse intervals to avoid log I/O overhead.
- **Path handling**: Use language APIs (`Path`, `filepath`, `pathlib`)—no string concatenation for cross-platform paths.
- **Temporary files**: create with restrictive permissions; delete in `finally` or equivalent.

## Database access

- Acquire connections from the **pool**; keep transactions **short**; avoid holding DB transactions open across network calls.
- Use **`@Transactional`** (or equivalent) at appropriate boundaries; read-only transactions for queries when supported.

---

## Observability

| Signal | Practice |
|--------|----------|
| Metrics | Pool saturation, wait time, query duration histograms |
| Logs | Slow query thresholds; never log full SQL with secrets |
| Traces | Span around external I/O with peer service name |

---

## Anti-patterns

- Relying on **finalizers** for cleanup (Java) instead of try-with-resources.
- **Global** `HttpClient` misuse in .NET (socket exhaustion)—always use `IHttpClientFactory`.
- **Unbounded** in-memory buffers for uploads/downloads.
- **Synchronous** blocking calls on async-only runtimes (e.g., Node event loop).

Agents MUST generate code that closes resources, sets timeouts, and uses pools as specified for the stack.

---

## Timeout selection

| Dependency | Typical starting point | Notes |
|------------|------------------------|-------|
| Internal HTTP | 1–5s connect, 5–30s total | Tune from p95 latency + slack |
| External SaaS | Stricter budgets + circuit breaker | See `performance.md` |
| Database queries | Statement timeout aligned to 50ms p95 goal | OLTP vs reporting |
| Message publish | Short with retry policy | Idempotency required |

Document overrides when **batch** or **ETL** jobs need longer windows—do not apply batch timeouts to interactive APIs.

---

## Streaming HTTP and multipart

- **Uploads**: stream request bodies to disk or storage; virus scan or validate **after** size caps enforced at reverse proxy.
- **Downloads**: stream to client; set `Content-Length` when known or use chunked encoding.
- **SSE/WebSockets**: heartbeats and idle timeouts to detect half-open connections.

---

## Filesystem edge cases

- **Symlinks**: decide policy (follow vs reject) for security-sensitive paths.
- **Concurrent writers**: use OS-level temp + atomic rename patterns for config files.
- **Windows vs POSIX**: line endings and path length—use APIs that abstract platform quirks.

---

## Database pool tuning (conceptual)

| Knob | Guidance |
|------|----------|
| Max pool size | Enough for peak concurrent requests; avoid exceeding DB max connections |
| Idle timeout | Recycle connections without churn |
| Statement timeout | Prevent runaway queries |

Use **read replicas** for read-heavy workloads; route writes only to primary.

---

## Review checklist (I/O)

| # | Check |
|---|--------|
| I1 | Resources closed on all paths (success, error, early return) |
| I2 | HTTP/DB timeouts explicit |
| I3 | Pooling used for DB and HTTP clients |
| I4 | Large payloads streamed |
| I5 | No secrets in logs for query/URL debug |

Pair with `exception-handling.md` for timeout mapping to classified errors (transient vs fatal).

---

## Message queues and streaming

- **Acknowledge** messages only after successful processing or durable handoff.
- **Idempotent consumers** with deduplication keys where at-least-once delivery applies.
- **Back-pressure**: prefetch limits in AMQP; `max.poll.records` tuning in Kafka consumers.

---

## DNS and connection establishment

- Cache DNS **respecting TTL**; use HTTP client connection pools that honor **keep-alive**.
- For **multi-region** failover, combine DNS/health checks with client-side retry policies carefully to avoid **retry storms**.

---

## Compression

- Enable **gzip/brotli** for text-heavy responses when CPU permits.
- Do not compress **small** payloads blindly—overhead can exceed savings.

---

## Read-after-write consistency

- After writes, **read-your-writes** semantics may require sticky sessions or replication lag handling—document in API behavior, not hidden I/O retries in random layers.

---

## Storage I/O (object stores)

- Use **multipart upload** for large objects; verify **ETag** on completion.
- **Server-side encryption** flags per bucket policy; never embed decryption keys in URLs.

---

## Observability (extended)

| Metric | Description |
|--------|-------------|
| `io_errors_total` | Count by operation and error class |
| `pool_wait_seconds` | Histogram of wait time for pooled resources |

Alert when error rate or wait time **SLO** breaches.

---

## Review checklist (I/O extended)

| # | Check |
|---|--------|
| I6 | Queue consumers ack correctly |
| I7 | Large object uploads use multipart/streaming |
| I8 | Compression configured sensibly |

I/O defects often manifest as **latency spikes** under load—validate with soak tests, not single-request manual checks.
