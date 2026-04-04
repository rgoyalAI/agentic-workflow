# Context: Database

## When to use
- `database_detected == true`

## How to apply
- Prefer migrations (versioned schema changes) over ad-hoc schema edits.
- Use parameterized queries or ORM-safe APIs to prevent injection.
- Define transaction boundaries explicitly for multi-step writes.
- Avoid N+1 query patterns; use batching/joins according to the repo's data access patterns.
- Ensure migrations and queries handle timezone and serialization consistently.

## What not to do
- Do not hardcode credentials, connection strings, or secrets in code.
- Do not perform destructive schema changes (DROP/TRUNCATE) without explicit approval.
- Do not skip referential integrity and error-handling in data-access layers.

