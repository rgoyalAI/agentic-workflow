# Concurrency and Synchronization

This document defines how concurrent, parallel, and asynchronous work MUST be structured: bounded resources, cancellation, clear ownership of mutable state, and documented thread-safety.

---

## Universal principles

1. **Cancellation and timeouts**: Every concurrent operation MUST accept or propagate cancellation (or equivalent) and honor deadlines. No fire-and-forget tasks without explicit lifecycle management.
2. **Bound concurrency**: Use worker pools, semaphores, or structured scopes—never unbounded goroutines, threads, or `Task` fan-out.
3. **Immutability and message passing**: Prefer immutable data and channels/queues over shared mutable state. When sharing is required, isolate it behind small, reviewed abstractions.
4. **Document thread-safety**: Public APIs MUST state whether they are safe for concurrent use, require external synchronization, or are single-threaded (e.g., UI dispatchers).

---

## Per-language reference

| Language | Concurrency Model | Key Patterns | Pitfalls to Enforce Against |
|----------|------------------|-------------|---------------------------|
| Java | Virtual threads (Java 21+), `CompletableFuture`, `ExecutorService` | Structured concurrency (`StructuredTaskScope`), `@Async` with bounded pools, `ReentrantLock` over `synchronized` for complex cases, thread-local replaced by scoped values | Unbounded thread pools, `synchronized` on mutable collections in hot paths, blocking I/O on platform threads |
| Python | `asyncio`, `threading`, `multiprocessing`, `concurrent.futures` | `asyncio.gather()` for concurrent I/O, `asyncio.Semaphore` for bounded concurrency, `ThreadPoolExecutor` for CPU-bound, `ProcessPoolExecutor` for true parallelism | Mixing sync and async (`loop.run_until_complete` in async context), bare `threading.Thread` without join/cleanup, GIL-unaware parallelism |
| Go | Goroutines + channels | Context-first (`ctx context.Context` as first param), `errgroup` for scoped goroutines, buffered channels for backpressure, `sync.WaitGroup` for fan-out/fan-in | Goroutine leaks (no cancellation path), unbuffered channels causing deadlocks, `sync.Mutex` held across I/O calls |
| C# / .NET | `async/await`, `Task`, `Channel<T>` | `CancellationToken` on all async methods, `Channel<T>` for producer/consumer, `SemaphoreSlim` for rate limiting, `ValueTask` for hot-path alloc reduction | `.Result` / `.Wait()` (sync-over-async deadlocks), `Task.Run()` in ASP.NET request handlers, fire-and-forget without error handling |
| TypeScript | Event loop, `Promise`, Web Workers | `Promise.allSettled()` for concurrent requests, `AbortController` for cancellation, worker threads for CPU-bound | Unhandled promise rejections, blocking the event loop with sync operations, no abort signal on fetch calls |

---

## Detailed guidance

### Java

- Prefer **virtual threads** for blocking I/O workloads; avoid blocking platform threads in pools sized for CPU work.
- Use **`StructuredTaskScope`** (or equivalent) so subtasks complete or cancel together.
- For async pipelines, **bound** `CompletableFuture` parallelism explicitly when composing many stages.

### Python

- **Never** call blocking I/O inside `async def` without `asyncio.to_thread()` or executors.
- Use **`asyncio.Semaphore`** to cap concurrent outbound HTTP calls.
- For CPU-heavy work, **multiprocessing** or **ProcessPoolExecutor**—not extra threads.

### Go

- **`context.Context`** MUST be the first parameter on APIs that do I/O or long work.
- Prefer **`errgroup.Group`** with context for “run these; fail all on first error” semantics.
- Always ensure **goroutines exit** when context is canceled (listen on `ctx.Done()`).

### C# / .NET

- Propagate **`CancellationToken`** from ASP.NET Core into all async calls.
- Avoid **`Task.Run`** solely to unblock sync-over-async in request handling—fix async all the way instead.
- Use **`IAsyncEnumerable<T>`** for streaming with cancellation support where applicable.

### TypeScript (Node and browser)

- Use **`AbortController`** with `fetch` and pass signals through service layers.
- Prefer **`Promise.allSettled`** when partial success is acceptable; handle each rejection.
- For CPU-heavy work in Node, use **`worker_threads`**; never block the event loop with sync file/crypto APIs on hot paths.

---

## Shared state checklist

| Question | Requirement |
|----------|-------------|
| Who owns the mutable state? | Single writer or documented lock ordering |
| Is the collection concurrent? | Use concurrent collections or external lock |
| Cross-process? | Use queues/DB with atomic updates, not in-memory locks |

---

## Testing concurrent code

- Use **deterministic stress tests** sparingly; prefer **controlled concurrency** tests with barriers or fake clocks.
- Assert **no goroutine/thread leaks** in long-running integration tests where feasible.

Review MUST reject unbounded parallelism, missing cancellation, sync-over-async in server code, and undocumented concurrent access to shared mutable objects.

---

## Deadlocks, livelocks, and ordering

- Establish a **global lock ordering** when multiple locks are required (`A` then `B`) and document it for the team.
- Avoid **nested locks** across modules; prefer passing messages or using coarse-grained domain operations.
- **Go**: fixed channel topology reduces deadlock risk; document which goroutine closes each channel.
- **Java**: `java.util.concurrent` utilities over raw `wait`/`notify` for new code.

---

## Backpressure

| Mechanism | When to use |
|-----------|-------------|
| Bounded queues / channels | Producer faster than consumer |
| Semaphores | Cap parallel section execution |
| Rate limiters | Protect downstream systems |

Expose **metrics** on queue depth and dropped work policy (block vs drop vs shed load) where applicable.

---

## UI and client considerations

- **JavaScript in browser**: long CPU work off main thread via Workers; coordinate with `requestIdleCallback` only for non-critical tasks.
- **Desktop UI** (.NET WPF/WinUI, JavaFX): marshal to UI thread; never block UI thread on I/O.
- **Mobile**: respect platform lifecycle; cancel network when activities pause.

---

## Structured concurrency (concept)

Parent tasks own child lifetimes: when the parent completes or cancels, **all children** must finish or abort—no orphaned background work. Map this to:

- Java `StructuredTaskScope`
- Go `errgroup` with context
- .NET linked `CancellationTokenSource`
- Python `asyncio.TaskGroup` (3.11+)

---

## Review checklist (concurrency)

| # | Check |
|---|--------|
| C1 | Cancellation/timeouts propagated through async stack |
| C2 | Concurrency bounded (pool, semaphore, or scope) |
| C3 | Shared mutable state documented or eliminated |
| C4 | No sync-over-async in ASP.NET/library code |
| C5 | Go: context on I/O boundaries; no leaked goroutines |
| C6 | Node: no long sync CPU on event loop |

Load tests MUST validate behavior under cancellation (client disconnect) for long-running operations.

---

## Virtual threads vs platform threads (Java)

| Workload | Recommendation |
|----------|------------------|
| Blocking JDBC / HTTP client | Virtual threads |
| CPU-bound math | Platform threads at fixed pool size |
| Pin-sensitive native code | Platform threads or `Thread.ofPlatform().factory()` |

Pin virtual threads only when required (native locks, JNI); document such cases.

---

## asyncio task lifecycle (Python)

- Store **strong references** to tasks you must await; fire-and-forget tasks should log exceptions via `task.add_done_callback`.
- Use **`asyncio.timeout`** (3.11+) or `wait_for` with explicit seconds.
- **Shutdown**: cancel outstanding tasks on SIGTERM in long-running workers.

---

## Go channel discipline

- **Sender closes** the channel when sends are complete; receivers drain until zero value + closed.
- Prefer **`select`** with `ctx.Done()` for interruptible waits.
- **nil channels** block forever—useful in `select` patterns but dangerous if accidental.

---

## .NET channels and backpressure

- `BoundedChannelFullMode.Wait` vs `DropWrite`—choose explicitly for overload behavior.
- **Complete** the writer when producers finish; consumers use `ReadAllAsync` with cancellation.

---

## TypeScript Promise utilities

| API | Use when |
|-----|----------|
| `Promise.all` | All must succeed |
| `Promise.allSettled` | Partial success acceptable |
| `Promise.race` | First completion wins; handle rejections |
| `AbortSignal.any` | Combine multiple cancel sources |

---

## Observability for concurrent systems

- Emit **active task/goroutine/thread** gauges where safe (avoid per-request cardinality explosion).
- Log **pool exhaustion** events at WARN before timeouts cascade.

---

## Further reading (team standards)

Map language-specific books and internal runbooks here: Java *Concurrency in Practice*, Go *Effective Go* concurrency section, Python asyncio docs, .NET async best practices, MDN Promise guides.

This section is intentionally **extensible**—link org wiki pages without duplicating proprietary policies.
