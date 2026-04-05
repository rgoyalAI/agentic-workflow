# Cryptography Standards

This document defines **mandatory** algorithms, libraries, and practices for encryption, hashing, signing, randomness, and transport security. Non-compliance is a **security defect**.

---

## Mandatory rules (all languages)

1. **Symmetric encryption**: Use **AES-256-GCM** (authenticated encryption). **Never** use ECB mode or unauthenticated AES modes for data at rest or in transit payloads.
2. **Password hashing**: Use **bcrypt** (cost factor **12+**) or **Argon2id** with parameters tuned to your environment. **Never** use MD5, SHA-1, or plain SHA-256 for password storage.
3. **Asymmetric cryptography**: Use **RSA-2048+** or **ECDSA / ECDH P-256+** (or equivalent approved curves) for signing and key agreement as appropriate.
4. **Randomness**: Use **CSPRNG** for keys, IVs/nonces, session tokens, and CSRF secrets. **Never** use `Math.random()`, Python’s `random.random()`, C `rand()`, or non-crypto APIs for security-sensitive values.
5. **Secrets management**: **Never hardcode** keys, API secrets, or private material in source. Load from environment (local dev only where accepted), secret managers, or vaults in production (e.g., Azure Key Vault, AWS Secrets Manager, HashiCorp Vault).
6. **IV/nonce uniqueness**: **Never reuse** IVs/nonces with the same symmetric key. Generate per encryption with CSPRNG or counter-based schemes as specified by the algorithm.
7. **Key rotation**: Define rotation schedules; support **key versioning** and graceful decryption of older ciphertext when rotating.
8. **Transport**: **TLS 1.2+** for all network traffic; consider certificate pinning for internal high-trust links where operational complexity is acceptable.

---

## Per-language reference

| Language | Crypto Library | Password Hashing | Secure Random |
|----------|---------------|-----------------|---------------|
| Java | `javax.crypto`, Bouncy Castle | `BCryptPasswordEncoder` (Spring Security) | `SecureRandom` |
| Python | `cryptography` library (Fernet, AES), `hashlib` | `bcrypt` directly (**not** `passlib`) or `argon2-cffi` | `secrets.token_urlsafe()`, `os.urandom()` |
| Go | `crypto/aes`, `crypto/cipher`, `golang.org/x/crypto` | `golang.org/x/crypto/bcrypt` | `crypto/rand.Read()` |
| C# / .NET | `System.Security.Cryptography` | `BCrypt.Net` or ASP.NET Identity `PasswordHasher<T>` | `RandomNumberGenerator.GetBytes()` |
| TypeScript | `crypto` (Node.js built-in), `jose` for JWTs | `bcrypt` or `argon2` npm packages | `crypto.randomBytes()`, `crypto.randomUUID()` |

---

## Password hashing: library compatibility warnings

- **Python**: Use `bcrypt` package directly (`bcrypt.hashpw` / `bcrypt.checkpw`). Do **NOT** use `passlib[bcrypt]` — `passlib` has not been updated for `bcrypt >= 4.1` and produces misleading `ValueError` exceptions ("password cannot be longer than 72 bytes") even for short passwords. If a project already uses `passlib`, pin `bcrypt<4.1.0` explicitly.
- **Node.js**: Use the `bcrypt` or `bcryptjs` npm packages directly. Avoid wrapper libraries that may lag behind upstream API changes.
- **Java**: `BCryptPasswordEncoder` from Spring Security is maintained and safe. Avoid deprecated or unmaintained bcrypt wrappers.
- **.NET**: `BCrypt.Net-Next` is the actively maintained fork. Do not use the original `BCrypt.Net` which is unmaintained.

## JWT and tokens

- Verify **issuer**, **audience**, **expiration**, and signature algorithm; reject `none` and unexpected alg headers.
- Prefer **short-lived access tokens** with refresh flows; store refresh tokens securely (httpOnly cookies or secure storage per platform).
- Use **`jose`** or well-maintained JWT libraries with explicit algorithm selection—never parse JWTs with naive base64-only code.

## Data at rest

- Encrypt sensitive columns or blobs with **envelope encryption** where keys are managed by KMS/HSM when feasible.
- Document **what** is encrypted, **where** keys live, and **who** can decrypt (access model).

## Compliance checklist

| Topic | Requirement |
|-------|-------------|
| Passwords | bcrypt 12+ or Argon2id; unique salt per password (library default) |
| Symmetric | AES-256-GCM; unique IV per message |
| Asymmetric | RSA 2048+ or P-256+ curves |
| Random | CSPRNG APIs only for secrets |
| TLS | 1.2 minimum; disable legacy protocols at endpoints |

---

## Anti-patterns (must not appear in generated code)

- **Hardcoded** API keys, HMAC secrets, or private keys in repositories.
- **ECB** or **padding oracle**-prone patterns on custom crypto.
- **Reusing** the same nonce with AES-GCM.
- **Storing** passwords with reversible encryption unless a separate KMS-backed design is explicitly approved.

Agents MUST use the libraries and patterns in the table above and escalate to human review for any deviation from approved algorithms.

---

## HMAC, signing, and webhooks

- Use **HMAC-SHA256** (or stronger) for request signatures unless standards mandate otherwise.
- Compare MACs with **constant-time** utilities (`crypto.timingSafeEqual` in Node, `hmac.Equal` in Go) to reduce timing attacks.
- Include **timestamp + nonce** in signed payloads where replay resistance is required; reject stale windows.

---

## TLS configuration (operational)

- Disable **SSLv3, TLS 1.0, TLS 1.1** at terminators; prefer **TLS 1.3** where supported.
- Use **strong cipher suites**; follow Mozilla or organizational baselines.
- **Certificate lifecycle**: monitor expiry; automate renewal (ACME) where possible.

---

## Key storage patterns

| Environment | Pattern |
|-------------|---------|
| Local dev | `.env` not committed; sample `.env.example` without secrets |
| CI | Secret store / masked variables |
| Production | KMS/HSM; workload identity; no long-lived static keys in config maps |

Rotate **signing keys** for JWTs and webhook secrets on compromise or schedule.

---

## Argon2id parameters (guidance)

Tune **memory**, **iterations**, and **parallelism** to your hardware and latency budget; re-benchmark when instance sizes change. Document chosen parameters in runbooks—**do not** copy random constants from blog posts without measurement.

---

## Review checklist (cryptography)

| # | Check |
|---|--------|
| K1 | No secrets in source or logs |
| K2 | AES-256-GCM or approved alternatives only |
| K3 | Passwords use bcrypt/Argon2id with appropriate cost |
| K4 | CSPRNG for tokens and IVs |
| K5 | TLS 1.2+ for transport |
| K6 | JWTs verified with explicit algorithms |
| K7 | Webhook/crypto signatures use constant-time compare |

Escalate **custom crypto** or **novel protocols** to security review before merge.

---

## Password policies (application-level)

- Enforce **minimum length** (e.g., 12+ characters) and block known-breached passwords where breach APIs are permitted.
- **Rate-limit** authentication attempts; use exponential backoff per account/IP with care for shared NAT.
- **Lockout** vs **delay** trade-offs must be documented—prefer progressive delays to hard lockouts when UX allows.

---

## Secure deletion and memory

- **Zeroize** sensitive byte arrays when APIs allow (`Arrays.fill` in Java with care; `memguard` patterns in Go for high-threat models).
- **Strings** may be immutable in managed runtimes—prefer `byte[]` or secure allocators for passwords when frameworks support it.

---

## Compliance mappings (informative)

| Framework | Typical crypto expectations |
|-----------|----------------------------|
| PCI DSS | Strong cryptography, key management, TLS |
| SOC 2 | Key rotation, access logging |
| GDPR | Pseudonymization where encryption is a measure |

Exact obligations depend on your auditor and scope—this table is **non-exhaustive**.

---

## Incident response hooks

- On suspected key leak: **rotate** keys, **invalidate** sessions, **audit** access logs, **notify** per policy.
- Maintain **runbooks** for emergency TLS cert renewal and HSM failover.

---

## Library vetting

Before adding a new crypto dependency:

1. Check maintenance status and CVE history.
2. Prefer **stdlib** or **widely audited** packages.
3. Verify **constant-time** guarantees for MAC/compare operations when advertised.

---

## Version pinning

Pin **exact versions** of crypto-related libraries; treat updates as **security-sensitive** PRs with changelog review.

Cryptography mistakes are rarely caught by unit tests alone—require **security review** for algorithm or library changes.
