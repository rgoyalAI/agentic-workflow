# Readability and Maintainability

This document defines structural limits, formatting, imports, and design principles so code stays **reviewable**, **testable**, and **safe to change** over time.

---

## Universal principles

### Complexity and size limits

| Metric | Guideline | Hard limit |
|--------|-----------|------------|
| Cyclomatic complexity (per method) | Aim low | **10** maximum (enforced by linter) |
| Method length | **30 lines** (guideline) | **50 lines** maximum |
| File length (non-generated) | **300 lines** (guideline) | **500 lines** maximum |
| Method parameters | Prefer DTOs | **4** maximum |

### Structure

- **One class per file** (Java, C#); **one primary export** per file where idiomatic (Python module contract, TypeScript module, Go package cohesion).
- **Import ordering**: **stdlib** → **third-party** → **internal** (enforce with formatter/linter; exact style may follow language defaults).
- **No dead code**: Remove unused imports, variables, functions, and commented-out blocks—use version control for history.
- **Consistent formatting**: Apply the language standard tool (`gofmt`, `black`, `prettier`, `dotnet format`, `google-java-format`, etc.) in CI.

### Documentation

- **Self-documenting code**: Prefer precise names and small functions over comments.
- **Comments for “why”**: Business rules, non-obvious trade-offs, regulatory constraints, or performance hacks—**not** narration of what the code already says.

### SOLID principles

| Principle | Definition |
|-----------|------------|
| **S**ingle Responsibility | Each class or module has **one reason to change**—one cohesive job. |
| **O**pen/Closed | Extend behavior through **composition, interfaces, or new types**—avoid modifying stable core code for every new variant. |
| **L**iskov Substitution | Subtypes must be **substitutable** for their base types without breaking callers’ expectations (contracts, invariants). |
| **I**nterface Segregation | Prefer **small, focused** interfaces over large “god” interfaces that force irrelevant implementations. |
| **D**ependency Inversion | Depend on **abstractions** (ports/interfaces), not concrete implementations—inject dependencies from composition roots. |

---

## Applying limits pragmatically

- **Generated code** (protobuf, OpenAPI clients) may exceed file limits; exclude from default lint rules or place in dedicated directories per project policy.
- When a method approaches **50 lines**, extract private helpers or a small class—**do not** split artificially at line 49 with no semantic gain.
- When parameters exceed **four**, introduce a **parameter object** or **builder** with validation in one place.

---

## Naming alignment

- Follow `naming-conventions.md` for language-specific casing and test naming.
- **Feature folders** should mirror domain language (`billing`, `shipment`) not org chart.

---

## Review checklist

| ID | Check |
|----|--------|
| R1 | Cyclomatic complexity ≤ 10 for new/changed methods |
| R2 | Methods ≤ 50 lines; files ≤ 500 lines (non-generated) |
| R3 | Parameters ≤ 4 or refactored to DTO |
| R4 | Imports ordered; no unused imports (lint-clean) |
| R5 | No dead code or commented-out production logic |
| R6 | SOLID: no obvious god-classes; dependencies injected |
| R7 | Comments explain non-obvious “why” only |

---

## Anti-patterns

- **Copy-paste** large blocks instead of extracting shared behavior.
- **Boolean parameters** that change behavior in incompatible ways—prefer enums or separate methods.
- **Deep nesting** (>3 levels) without guard clauses or early returns—flatten for readability.

Readable code reduces defect rates and speeds reviews; treat these limits as **defaults**, not obstacles to clear structure.

---

## Cyclomatic complexity (practical)

Tools (SonarQube, ESLint complexity, Checkstyle) count branching. Reduce complexity by:

- **Guard clauses** instead of deep nesting
- **Extracting** validation and mapping into named functions
- **Replacing** large `switch` with polymorphism when variants grow

A score of **10** is the ceiling—aim lower for critical paths (payments, auth).

---

## Method and file length (examples)

| Situation | Action |
|---------|--------|
| Method > 30 lines | Look for cohesive steps to extract |
| Method > 50 lines | Mandatory refactor unless approved exception |
| File > 300 lines | Consider splitting by responsibility |
| File > 500 lines | Split or move generated code to excluded paths |

**Exceptions** (document in PR): performance-critical inlined code with benchmark evidence; generated files.

---

## Import and module hygiene

- **Remove** unused imports on every save (IDE + CI).
- **Barrel files** (`index.ts`): avoid deep re-export cycles; keep public surface intentional.
- **Python**: explicit relative imports within packages; avoid `from module import *` in production code.

---

## Control flow clarity

- Prefer **early returns** over nested `if/else` ladders.
- **Flag arguments** (`process(order, isRefund)`) split into `processOrder` / `processRefund` when behavior diverges.
- **Magic numbers** become named constants with units in the name (`maxRetryAttempts`, `defaultTimeoutMs`).

---

## Testing and maintainability

- **Unit tests** protect refactors—if code is hard to test, it is often too coupled (SOLID violation).
- **Test doubles** (fakes/mocks) at boundaries—not deep mocking of internals.

---

## Tooling integration

| Language | Formatter | Complexity |
|----------|-----------|------------|
| Java | google-java-format | Checkstyle / Sonar |
| Python | black / ruff format | ruff mccabe |
| Go | gofmt | staticcheck |
| C# | dotnet format | analyzers |
| TS/JS | prettier | eslint complexity |

Configure CI to **fail** on violations of hard limits where possible.

---

## Review checklist (readability — extended)

| # | Check |
|---|--------|
| R8 | Guard clauses; nesting ≤3 levels in new code |
| R9 | No magic strings/numbers without constants |
| R10 | Parameter objects when >4 args |
| R11 | SOLID violations called out in review when systemic |
| R12 | Formatter/linter clean |

These standards align with `ReviewCode` **C9** and **C10** findings in the SDLC plan—reference file paths when logging violations.

---

## Refactoring triggers

| Smell | Refactor |
|-------|----------|
| Duplicate logic in 3+ places | Extract function or policy object |
| Class name ends with `Manager`, `Helper` | Rename to domain role or split |
| Method needs comment to explain *what* | Rename/split instead |

---

## Feature flags in code

- Isolate flag checks in **small functions** (`isBillingV2Enabled()`).
- Remove **dead branches** when flags graduate to 100%—avoid permanent `if (false)` litter.

---

## Error handling readability

- **One level** of try/catch per logical operation when possible; avoid catch inside tight loops.
- **Centralize** HTTP error mapping (see `exception-handling.md`) so business code stays linear.

---

## Documentation blocks

- **File-level** docstrings only when the module has non-obvious invariants.
- **API docs** (OpenAPI) are authoritative for REST—keep code and spec synchronized.

---

## Onboarding and readability

- **README** snippets for local run reduce “tribal knowledge” in conditionals.
- **Architecture Decision Records** explain *why* unusual patterns exist—link from code comments via ticket/ADR ID.

---

## Measuring complexity

- Run **SonarQube** or **CodeClimate** on PRs; track **technical debt** ratio over time.
- **Suppressions** of complexity rules require **ticket** and **expiry**.

---

## Pairing with naming

Unreadable code often starts with **poor names**—fix naming before extracting micro-functions. See `naming-conventions.md`.

---

## Final review mantra

**Small, named, tested, and formatted** beats clever every time. Maintainability is measured in **time to safe change**, not lines of code.
