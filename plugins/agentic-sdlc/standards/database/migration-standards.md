# Database Migration Safety Standards

DDL migrations must be **sequential**, **reviewable**, and **safe for production** with minimal downtime where the platform allows.

## File naming and ordering

- **Sequential numbering**: `V001__create_users.sql`, `V002__add_orders.sql` (Flyway style) or timestamped with **lexicographic** order guaranteed.
- **One logical change** per migration when possible — easier to roll back mentally and bisect failures.
- **Never** rewrite history of migrations already applied to **production** — add a new forward migration instead.

## Rollback scripts

- Prefer **paired** `up` / `down` (or `.undo`) migrations when tooling supports it safely.
- **Down** scripts must be tested in non-prod; destructive downs require explicit approval.
- For **data backfills**, document **idempotent** criteria (safe to re-run).

## Zero-downtime DDL pattern (relational)

Typical sequence for adding a **non-null** column or constraint:

1. **Add column** nullable (or with default that does not lock unacceptably — DB-specific).
2. **Backfill** in batches (application job or SQL batches) with monitoring.
3. **Set NOT NULL** / add **CHECK** after backfill complete.
4. **Add indexes** using `CONCURRENTLY` (PostgreSQL) or equivalent to avoid long locks.

For **renames**: add new column → dual-write → backfill → switch reads → drop old (multi-phase).

## Parameterized queries

- Application code uses **bound parameters** only — migrations may use static SQL; **never** inject user input into migration scripts.

## Connection pooling

- Pool size tuned for **DB max connections** / replica count; avoid **one pool per request** anti-pattern.
- **Timeouts** for acquisition and statement execution; **circuit breaker** on pool exhaustion alerts.

## Destructive operations

- **DROP TABLE**, **TRUNCATE**, **DELETE** without WHERE — require **ticket + approval** and backup verification.
- Prefer **soft delete** columns when product requires recovery.

## Environments

- Run **same** migration chain in **dev → staging → prod**; drift detection job compares `schema_migrations` vs files.

## Review checklist

- [ ] Migration is **forward-only** for prod history (no edit of applied files).
- [ ] Lock risk assessed (index creation, FK validation).
- [ ] Rollback or mitigation path documented.
- [ ] Data backfill is **batched** and **resumable** if large.
- [ ] No secrets in migration files.

## Tooling

- **Flyway**, **Liquibase**, **Alembic**, **EF Core migrations**, **golang-migrate** — team picks one per service; do not mix uncontrolled ad-hoc SQL.
