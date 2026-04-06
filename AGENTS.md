# AGENTS.md

## 1. Authority (Non-negotiable)
- `AGENTS.md` is the single source of truth for all AI agents in this repo.
- Always follow `AGENTS.md`. If any tool-specific file contradicts it, `AGENTS.md` wins.
- Never assume information you have not loaded or verified from the repo.

## 2. Deterministic Context Loading (Required)
Always follow this exact procedure before planning or writing code.

1. Load this file (`AGENTS.md`) first.
2. Detect project signals using only verifiable repo evidence (file names/paths you can read or search).
3. Load ONLY the relevant context files from `./contexts/` in this fixed order:
   - (a) Language context (exactly one, by priority): `java`, then `python`, then `dotnet`
   - (b) Domain contexts (may be multiple, in this order): `api-design`, then `database`, then `security`
4. If a context file is missing or cannot be loaded, do not hallucinate its content. Continue with what is available and record missing files.

### 2.1 Project language (priority order)
Set `project.language` as the first matching language in this order:

- Java if any of the following is present: `pom.xml`, `build.gradle` or `build.gradle.kts`, or any `**/*.java`.
- Python if any of the following is present: `pyproject.toml`, `requirements*.txt`, or any `**/*.py`.
- Dotnet if any of the following is present: any `*.csproj`, `global.json`, or any `**/*.cs`.

If none match, set `project.language = Unknown` and load no language context.

Then apply:
- IF `project.language == Java` load `./contexts/java.md`
- IF `project.language == Python` load `./contexts/python.md`
- IF `project.language == Dotnet` load `./contexts/dotnet.md`

### 2.2 Domain detection
- API detected if any of the following is present: any `openapi*.{yml,yaml,json}`, any `swagger*.{yml,yaml,json}`, or any `**/*.graphql`.
- Database detected if any of the following is present: any `**/*.sql`, `migrations/**`, `**/schema.prisma`, or `**/prisma/migrations/**`.
- Security concerns detected if any of the following is present: `**/security/**`, `**/auth/**`, any file/dir name containing `jwt`, or any file/dir name containing `oauth`.

Then load:
- IF API detected load `./contexts/api-design.md`
- IF Database detected load `./contexts/database.md`
- IF Security concerns detected load `./contexts/security.md`

### 2.3 Conflict resolution
Use this precedence, highest to lowest:
1. `AGENTS.md`
2. Language context (`java`/`python`/`dotnet`)
3. `contexts/api-design.md`
4. `contexts/database.md`
5. `contexts/security.md`

## 3. Architecture Principles (Enterprise-grade)
When proposing or implementing changes:
- Modular: keep boundaries clear; avoid god-modules; each module has a single reason to change.
- Scalable: design for throughput and bounded latency; prefer pagination/limits.
- Observable: emit structured logs, correlation IDs, and metrics for critical flows.
- Secure by default: least privilege, input validation, safe error handling, and secure defaults.
- Deterministic builds: pin versions; avoid hidden state.

## 4. Agent-Oriented Design (How agents work)
### 4.1 Default orchestration
- Use a planner/orchestrator agent to produce a plan with acceptance criteria.
- Use specialist agents (implementer, verifier, security-auditor) for focused work.
- Never let a specialist directly finalize risky outputs without a verifier step.

### 4.2 Task decomposition and quality gates
- Decompose into small steps that can be verified.
- After each implementation step, run the smallest relevant check:
  - lint/format
  - unit tests
  - integration/contract checks (if changed surface area)

### 4.3 Inter-agent communication (A2A readiness)
When handing off to another agent, include the following envelope verbatim:

```text
A2A:
intent: <what to do>
assumptions: <what you are assuming>
constraints: <what you must obey>
loaded_context: <list of contexts you actually loaded>
proposed_plan: <steps with ordering>
artifacts: <files or outputs to produce>
acceptance_criteria: <measurable pass/fail checks>
open_questions: <only if required>
```

### 4.4 Stateless vs stateful
- Default specialists are stateless: they do not rely on past conversation.
- Only the orchestrator maintains the authoritative decision state.
- Persist memory only for non-sensitive, stable facts explicitly approved by these rules.

## 5. API Design Standards
- Version safely; keep backward compatibility; consistent envelopes and errors.
- Validate at boundaries: 4xx for client errors, 5xx for server only; pagination for lists.
- Never leak secrets or stack traces; include a request correlation ID.

## 6. Security Standards (OWASP + operations)
- Treat all external input as untrusted; validate and sanitize before use.
- Enforce auth on every sensitive action; use parameterized queries / ORM safe APIs.
- Secrets via env vars or secret managers; never commit, persist, or echo credentials.
- No bypassing auth, disabling TLS, or destructive actions without an explicit approval gate.

## 7. Testing, Docs, Naming, Observability
- Tests: deterministic, edge cases, error paths; report `missing-data` if tests cannot run.
- Docs: update README and ADRs for meaningful changes; include run/test commands.
- Naming: intention-revealing, follow existing casing, nouns for resources / verbs for actions.
- Logging: structured key/value with `correlation_id`; no PII; redact secrets.

---

## Coding Behavior Guidelines
Favor correctness, clarity, and minimal diffs. For trivial tasks, use judgment.

### 8. Think Before You Code
- State assumptions clearly; ask if anything is ambiguous — do not guess silently.
- If multiple approaches exist, briefly present the tradeoff before picking one.
- If the request seems mistaken or overcomplicated, say so; recommend simpler alternatives.
- Do not act certain when you are uncertain.

### 9. Keep It Simple, Stay in Scope
- Solve the requested problem with the minimum necessary code — no unasked features, abstractions, or generalization.
- Only change what the task requires; do not refactor unrelated code or fix neighboring issues.
- Match existing style and conventions; every changed line should be justifiable from the request.
- Self-check: is this the smallest change? Would a senior engineer call it unnecessarily complex?

### 10. Surgical Diffs
- Touch as few files as possible; change as little code as necessary.
- Preserve existing structure, comments, and behavior unless the task requires altering them.
- Remove only dead code/imports created by your own changes — not pre-existing ones.
- Call out any intentional behavior change explicitly; do not make hidden design decisions.

### 11. Verify Outcomes
- Turn requests into clear success criteria: reproduce → fix → verify.
- For multi-step tasks: plan with verification points; run tests or checks at each step.
- Prefer concrete validation over verbal confidence.

### 12. Read Before You Write
- Read enough surrounding code to understand how the target piece fits in.
- Identify local conventions before introducing new patterns.
- If context is missing, say so — do not patch blindly.

### 13. Ask and Confirm
- Pause and ask when: ambiguity affects implementation, behavior is unclear, or the task requires a product/architectural decision.
- Before finishing, confirm: request addressed, change minimal, assumptions surfaced, tests run where possible.
- If something could not be verified, say that clearly.

