---
description: Concrete few-shot examples of Go code review findings adhering strictly to the finding schema, including positive findings, edge cases, and rejected style issues.
metadata:
  tags: [template, examples, findings, few-shot, code-review]
---

# Finding Examples

This document provides few-shot reference examples demonstrating how findings must be formatted. Each finding must follow the exact structure defined in [`SKILL.md`](../SKILL.md).

---

### Example 1: Security Vulnerability (P0 - High Confidence)

```markdown
[ P0 ] [ High confidence ] GR-SEC-001: SQL Injection via unescaped string formatting in query

File: internal/repository/user_repo.go:58-64

Evidence:
The SQL query string is constructed using `fmt.Sprintf` with unescaped user input:
`query := fmt.Sprintf("SELECT id, email, role FROM users WHERE org_id = '%s' AND status = 'active'", orgID)`
No parameter binding or sanitization is performed prior to database execution via `r.db.QueryContext`.

Trigger:
An API request where `orgID` contains malicious SQL fragments (e.g. `' OR '1'='1' --`).

Impact:
Full bypass of organization tenancy isolation and arbitrary database exfiltration or tampering.

Recommendation:
Replace string formatting with parameterized positional placeholders:
```go
query := "SELECT id, email, role FROM users WHERE org_id = $1 AND status = 'active'"
rows, err := r.db.QueryContext(ctx, query, orgID)
```

```

---

### Example 2: Concurrency & Goroutine Leak (P1 - High Confidence)

```markdown
[ P1 ] [ High confidence ] GR-CONC-001: Goroutine leak on unbuffered channel during context cancellation

File: pkg/worker/fetcher.go:112-129

Evidence:
The worker spawns a goroutine that writes to an unbuffered channel: `resCh <- result`. When `ctx.Done()` fires first, the parent function immediately returns, leaving no reader on `resCh`. The goroutine remains blocked indefinitely on the channel send.

Trigger:
External HTTP service latency exceeds the 3-second context deadline, causing `ctx.Done()` to trigger before the worker finishes.

Impact:
Accumulation of leaked goroutines and uncollected memory over time, leading to memory bloat and eventual process starvation under high traffic.

Recommendation:
Allocate a buffered channel of size 1 so the goroutine can complete its send and terminate even if the caller has returned:
```go
resCh := make(chan Result, 1)
go func() {
    resCh <- doWork()
}()
```

```

---

### Example 3: Correctness / Typed Nil Trap (P1 - High Confidence)

```markdown
[ P1 ] [ High confidence ] GR-CORR-001: Typed nil struct returned as error interface causes false-positive error check

File: internal/validator/order.go:34-45

Evidence:
The function defines `var valErr *ValidationError = nil` and returns `valErr` directly as the `error` interface. In Go runtime semantics, an interface holding a typed nil pointer is not equal to `nil` (`err != nil` evaluates to `true`).

Trigger:
Calling `ValidateOrder(order)` with valid order data.

Impact:
Callers inspecting `if err := ValidateOrder(order); err != nil` will treat all valid orders as failed, halting order checkout workflows.

Recommendation:
Return an explicit untyped `nil` on success:
```go
func ValidateOrder(o *Order) error {
    if len(o.Items) == 0 {
        return &ValidationError{Msg: "no items"}
    }
    return nil // Return untyped nil interface
}
```

```

---

### Example 4: Performance & Resource Leak (P2 - High Confidence)

```markdown
[ P2 ] [ High confidence ] GR-RES-001: Deferred file close inside unbounded loop causes descriptor exhaustion

File: cmd/importer/bulk.go:78-92

Evidence:
`defer f.Close()` is declared inside the `for _, path := range filePaths` loop. In Go, `defer` is evaluated at the exit of the enclosing function (`ImportAll`), not at the end of each loop iteration.

Trigger:
Importing a directory containing more files than the system's open file descriptor limit (e.g. >1024 files).

Impact:
Runtime crash with `too many open files` OS error during bulk import batches.

Recommendation:
Encapsulate the single-file processing logic in a separate helper function to ensure the file is closed immediately when that function exits:
```go
for _, path := range filePaths {
    if err := importSingleFile(path); err != nil {
        return err
    }
}
```

```

---

### Example 5: Negative Example (Rejected Style Preference - DO NOT REPORT)

```markdown
<!-- The following is an example of what an agent must REJECT and NOT report -->

Scenario:
The reviewer prefers `idx` instead of `i` for loop counter, or prefers explicit variable initialization over short declarations:
`var count int = 0` vs `count := 0`.

Decision:
DO NOT REPORT. This is a personal aesthetic preference. Go standard tooling (`gofmt`, `go vet`) does not mandate this, and it does not affect correctness, concurrency safety, performance, or security.
```

---

### Example 6: Pre-existing Defect Handling

```markdown
<!-- Guideline for defects outside the diff -->

Scenario:
While inspecting `internal/service/user.go`, the reviewer notices a bug in an unedited function `DeleteAccount()` that was written 2 years ago and is not touched or referenced by the current PR.

Decision:
Do NOT attribute this finding as a blocking defect on the current PR. If critical, mention it briefly under the "Additional Observations / Non-Blocking Notes" section with low priority, or file a separate tracking issue.
```
