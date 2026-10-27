# GitHub Copilot Instructions for golang-review

These instructions apply when using GitHub Copilot to review Go code, write Go code, or analyze Go diffs.

## Core Review Philosophy

- **Evidence-based**: Every finding must cite exact file:line and concrete execution path.
- **Version-aware**: Read `go.mod` first. Apply version gates (see below).
- **Non-destructive**: Never run mutating commands during review.
- **Severity-focused**: Prioritize P0/P1 (crash, RCE, goroutine leak, data race, connection leak).

## Go Version Gates (Mandatory)

Check `go.mod` for `go 1.xx` directive before reviewing:

| Version | Rule |
|---|---|
| `< 1.22` | Flag loop variable capture in goroutines and `t.Parallel()` subtests. Require `tc := tc` shadowing. |
| `>= 1.22` | Loop variables have per-iteration scope. **Do NOT flag** captures. |
| `>= 1.23` | Iterators (`iter.Seq`, `iter.Seq2`) must check `yield` return: `if !yield(v) { return }`. Unreferenced timers are GC-collected. |
| `>= 1.24` | Prefer `os.OpenRoot(base)` for path containment (kernel-level, TOCTOU-proof). Avoid `filepath.Clean`/`Rel` alone. |

## High-Impact Patterns (Always Check)

### Concurrency (GR-CONC)
- Unbuffered channel send without `select { case <-ctx.Done() }`
- Missing `defer cancel()` for `context.WithTimeout/WithCancel/WithDeadline`
- `sync.Mutex` in value receiver or passed by value
- `time.Ticker` without `defer ticker.Stop()`
- Iterator ignoring `yield` false return (Go 1.23+)
- `sync.OnceValue`/`OnceValues` preferred over manual `sync.Once` (Go 1.21+)

### Security (GR-SEC)
- SQL via `fmt.Sprintf`/concat → use parameterized queries (`$1`, `?`)
- `exec.Command("sh", "-c", input)` → use direct args: `exec.Command("bin", "arg", input)`
- Path traversal: `filepath.Clean` alone is insufficient. Use `os.Root` (1.24+) or `filepath.Rel` prefix check
- SSRF: `http.Get(userURL)` → block loopback, RFC1918, 169.254.169.254
- `math/rand` for secrets → use `crypto/rand`
- `InsecureSkipVerify: true` in production
- Logging credentials in `slog` (password, token, secret, apiKey)

### Resource Management (GR-RES)
- `defer resp.Body.Close()` before error check → nil panic
- `defer f.Close()` in loop → use helper function
- `db.BeginTx()` without `defer tx.Rollback()` → connection leak
- `sql.Rows` without `defer rows.Close()` + `rows.Err()` check
- HTTP server without timeouts → Slowloris DoS:
  ```go
  ReadHeaderTimeout: 5s, ReadTimeout: 15s, WriteTimeout: 30s, IdleTimeout: 60s
  ```
- Sub-slice retaining large backing array → use `copy()` to new slice

### Performance (GR-PERF)
- Struct field ordering: 8-byte (int64, uint64, ptr) → 4-byte → 2-byte → 1-byte
- String concat in loop → `strings.Builder` with `Grow()`
- Custom loops for slice/map ops → `slices`/`maps` pkg (Go 1.21+)
- Error string comparison → `errors.Is/As/Join`

## Finding Output Format

```markdown
[P0|P1|P2|P3] [High|Medium|Low] GR-CAT-XXX: Title

File: path/to/file.go:123

Evidence: <code snippet + why it violates guarantees>

Trigger: <runtime condition/user input>

Impact: <production effect>

Recommendation: <exact code fix>
```

## Automated Harvester

Run before manual review for deterministic evidence:
```bash
.agents/skills/golang-review/scripts/review_diff.sh [HEAD|branch]
```

Outputs: Go version, changed files, gofmt diff, go vet, and regex pattern triggers for all categories above.

## Reference Files

Load only the relevant reference from `.agents/skills/golang-review/references/`:
- `correctness-and-error-handling.md`
- `concurrency-and-context.md`
- `security.md`
- `performance-and-resource-management.md`
- `architecture-and-maintainability.md`
- `testing-and-quality.md`
- `dependencies-and-tooling.md`