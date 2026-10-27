---
description: Actionable code review checks for Go application security, injection vulnerabilities, path traversal, SSRF, and cryptography.
metadata:
  tags: [security, appsec, sql-injection, command-injection, ssrf, path-traversal, cryptography]
---

# Security Review Checks

Review Go code for application security flaws, untrusted input handling, injection vulnerabilities, and weak cryptographic practices.

---

## 1. Injection Vulnerabilities

### A. SQL Injection

- **Detection Rules:** Look for query strings constructed using `fmt.Sprintf`, string concatenation (`+`), or template rendering rather than parameterized queries (`?`, `$1`).
- **ORM Vulnerabilities:** Using raw query fragments in GORM or sqlx (`db.Where(fmt.Sprintf("name = '%s'", input))`).

```go
// ❌ BAD: SQL query constructed via string formatting
query := fmt.Sprintf("SELECT id, name FROM users WHERE email = '%s'", userEmail)
db.Query(query)

// ✅ GOOD: Parameterized query prevents injection
query := "SELECT id, name FROM users WHERE email = $1"
db.Query(query, userEmail)
```

### B. Command Injection

- **Detection Rules:** Invoking shell interpreters (`exec.Command("sh", "-c", userInput)` or `exec.Command("bash", "-c", ...)`).
- **Direct Execution:** Using `exec.Command(binary, args...)` where args are split properly is safe; invoking through an intermediate shell enables command chaining (`|`, `;`, `&&`).

```go
// ❌ BAD: Shell interpretation executes malicious command separators
cmd := exec.Command("sh", "-c", "ping -c 1 "+hostInput)

// ✅ GOOD: Direct process execution without shell interpretation
cmd := exec.Command("ping", "-c", "1", hostInput)
```

---

## 2. Path Traversal

### Detection Rules

- **Flawed Assumption with `filepath.Clean`:** `filepath.Clean` alone does **NOT** prevent escaping outside a base directory. `filepath.Clean("../../etc/passwd")` returns `../../etc/passwd`.
- **Safe Directory Containment:** After joining base directory and user input, ensure the canonicalized path starts with the base directory prefix.

```go
// ❌ BAD: User input can escape the target root directory
cleanPath := filepath.Clean(userInput)
target := filepath.Join(baseDir, cleanPath) // target can resolve to /etc/passwd

// ✅ GOOD: Strict prefix verification ensures path stays inside baseDir
target := filepath.Join(baseDir, filepath.Clean("/"+userInput))
rel, err := filepath.Rel(baseDir, target)
if err != nil || strings.HasPrefix(rel, "..") {
    return fmt.Errorf("invalid path traversal attempt")
}
```

---

## 3. Server-Side Request Forgery (SSRF)

### Detection Rules

- Using `http.Get(userInputURL)` or `http.NewRequest` where the destination host is provided by the client.
- Failure to block internal network segments:
  - Loopback (`127.0.0.0/8`, `::1`)
  - Private RFC 1918 ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
  - Cloud Metadata services (`169.254.169.254`)
- Mitigate using a custom `net.Dialer` with an explicit IP validation hook.

---

## 4. Cryptographic Weaknesses

### Detection Rules

- **`math/rand` vs `crypto/rand`:** Using `math/rand` (or `math/rand/v2`) for security-sensitive tokens, passwords, sessions, or salts. `math/rand` produces pseudo-random, predictable sequences.
- **Insecure TLS:** Setting `tls.Config{InsecureSkipVerify: true}` disables server certificate validation, allowing Man-in-the-Middle (MitM) attacks.
- **Weak Hashing:** Using MD5 or SHA1 for passwords or integrity signatures. Passwords must use Argon2id, bcrypt, or scrypt.

```go
// ❌ BAD: Predictable token generation using math/rand
import "math/rand"
token := rand.Int63()

// ✅ GOOD: Cryptographically secure random bytes
import "crypto/rand"
b := make([]byte, 32)
if _, err := rand.Read(b); err != nil {
    return err
}
```

---

## 5. Sensitive Data Exposure

### Detection Rules

- Logging structs that contain sensitive fields (`Password`, `Token`, `CreditCard`) directly with `slog`, `fmt.Printf("%+v")`, or JSON encoders.
- Custom `String()` or `GoString()` methods should redact sensitive fields.

---

## False Positive Prevention Checklist

- [ ] Do NOT flag `math/rand` if used exclusively for non-cryptographic simulations, testing seeds, or exponential backoff jitters.
- [ ] Do NOT flag `InsecureSkipVerify: true` if strictly enclosed in test fixtures or mock HTTP servers (`httptest.NewServer`).
- [ ] Do NOT flag path concatenation if the input variable is proven to be a hardcoded internal constant or bounded enum.
