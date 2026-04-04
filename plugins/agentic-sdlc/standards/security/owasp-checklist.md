# OWASP Top 10 (2021) — Validation & Remediation Checklist

Use this during **design review**, **code review**, and **security agent** audits. Each row maps a category to **validation checks** and **remediation patterns**.

---

## A01:2021 — Broken Access Control

**Description**: Users perform actions outside their intended permissions (IDOR, missing role checks, path traversal).

| Validation check | Remediation pattern |
|------------------|---------------------|
| Every sensitive route has **authorization** after authentication | Central policy layer (Spring Security `@PreAuthorize`, ASP.NET policies, FastAPI deps) |
| Object access uses **server-side** user/tenant context, not client-supplied IDs alone | Resolve resource → verify `owner_id` / `tenant_id` matches session |
| Admin vs user endpoints **separated** and explicitly guarded | Role-based route groups + tests for forbidden paths |
| **CORS** not used as auth — validate tokens on API | Never allow `*` credentials with sensitive data without review |

---

## A02:2021 — Cryptographic Failures

**Description**: Weak or missing crypto for data at rest/in transit; hardcoded keys.

| Validation check | Remediation pattern |
|------------------|---------------------|
| Passwords hashed with **Argon2id**, **bcrypt**, or **scrypt** — not MD5/SHA1 alone | Use established libraries; tune cost factors |
| TLS **1.2+** for all external traffic | Terminate TLS at gateway; enforce HSTS |
| Secrets in **vault** or env — not in git | Pre-commit secret scan; rotate on leak |
| PII encrypted at rest when required by policy | Database TDE + column encryption for high-sensitivity fields |

---

## A03:2021 — Injection

**Description**: SQL, command, LDAP, template injection when untrusted input reaches interpreters.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Parameterized** queries / ORM bind parameters only | Ban string concatenation for SQL |
| **Input validation** at boundary (schema, allowlist) | Pydantic, Bean Validation, FluentValidation |
| **Shell** never built from user input | Use `exec` arrays with fixed commands |
| **NoSQL** queries use typed builders or sanitized keys | Avoid `$where` with user strings |

---

## A04:2021 — Insecure Design

**Description**: Missing threat modeling; business logic flaws (coupon abuse, workflow bypass).

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Threat model** for high-value flows | STRIDE-lite; document trust boundaries |
| **State machines** for multi-step processes | Server enforces valid transitions |
| **Rate limits** on auth and sensitive actions | CAPTCHA + backoff after failures |
| **Business rules** enforced server-side | Never trust client-only validation |

---

## A05:2021 — Security Misconfiguration

**Description**: Default creds, verbose errors, open directories, unnecessary features enabled.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Stack traces** off in production | Generic error envelope + correlation ID |
| **Debug** endpoints disabled in prod | Profile-specific config |
| **Headers**: `X-Content-Type-Options`, `X-Frame-Options`, CSP | Middleware or gateway config |
| **Dependencies** minimal attack surface | Disable unused modules and sample apps |

---

## A06:2021 — Vulnerable and Outdated Components

**Description**: Known CVEs in libraries and frameworks.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **SCA** in CI (Dependabot, Snyk, OWASP Dependency-Check) | Block on critical CVSS unless waiver |
| **Pin** versions in lockfiles | Reproducible builds |
| **Patch** cadence defined (e.g. monthly + critical same-day) | Process + ownership |

---

## A07:2021 — Identification and Authentication Failures

**Description**: Weak session management, credential stuffing, missing MFA for sensitive ops.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Sessions** use secure, `HttpOnly`, `SameSite` cookies or short-lived JWT + refresh rotation | OWASP Session Management Cheat Sheet |
| **Brute-force** protection on login | Lockout / exponential backoff |
| **MFA** for admin and high-risk actions | TOTP/WebAuthn per policy |
| **Password reset** tokens single-use, time-limited | Secure random, not guessable URLs |

---

## A08:2021 — Software and Data Integrity Failures

**Description**: Unsigned updates, CI/CD compromise, insecure deserialization.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **CI** pipelines require signed commits or protected branches | Branch protection rules |
| **Dependencies** from trusted registries with integrity hashes | Lockfiles |
| **Deserialization** of untrusted data avoided or strictly typed | No `pickle` / Java `ObjectInputStream` on untrusted input |
| **SBOM** for releases | CycloneDX / SPDX |

---

## A09:2021 — Security Logging and Monitoring Failures

**Description**: Insufficient logs to detect breach; logs contain secrets.

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Auth failures**, **privilege changes**, **admin actions** logged | Structured JSON logs |
| **Correlation ID** on all requests | Propagate `X-Correlation-ID` |
| **No secrets** in logs | Redact tokens, passwords, PII per policy |
| **Alerts** on suspicious patterns | SIEM integration |

---

## A10:2021 — Server-Side Request Forgery (SSRF)

**Description**: Server fetches attacker-controlled URLs (cloud metadata, internal services).

| Validation check | Remediation pattern |
|------------------|---------------------|
| **Outbound** URL fetchers allowlist **hostnames** or use internal DNS split | Block `169.254.169.254`, link-local |
| **No** raw user URL passed to HTTP client without validation | Parse URL; scheme `https` only; resolve IP after validation |
| **Webhooks** verified with HMAC signatures | Shared secret per tenant |

---

## Sign-off

- **Security**: Review for new external surfaces and data classes.
- **Engineering**: Attach SCA + DAST summary to release for major changes.
