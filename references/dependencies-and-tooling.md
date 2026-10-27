---
description: Actionable code review checks for Go module dependencies, go.mod hygiene, replace directives, and tooling execution.
metadata:
  tags: [dependencies, tooling, go-mod, go-sum, govulncheck, replace-directive]
---

# Dependencies & Tooling Review Checks

Review Go modules, dependency hygiene, build tags, and deterministic verification tools.

---

## 1. `go.mod` & Dependency Hygiene

### Detection Rules:
- **Local `replace` Directives in PRs:** Developers often add `replace github.com/foo/bar => ../local-bar` during local development. Committing local relative path replace directives breaks CI and downstream consumers.
- **Dependency Bloat:** Adding heavy third-party dependencies for simple utilities already provided by the Go standard library (e.g. importing an entire helper library for string padding or basic math).
- **Direct vs Indirect Dependencies:** Ensure new direct imports are tracked properly in `go.mod` and verified in `go.sum`.

```go
// ❌ BAD: Committed local replace directive breaks external builds
module github.com/org/repo

go 1.22

require github.com/external/pkg v1.0.0

replace github.com/external/pkg => ../../local/pkg // BREAKS CI!
```

---

## 2. Vulnerability Auditing (`govulncheck`)

### Detection Rules:
- When changes introduce or bump dependencies, check if the module has known CVEs.
- If `govulncheck` is available in the environment, run:
  ```bash
  govulncheck ./...
  ```
- **Distinguish Direct Call vs Unused Vulnerability:** `govulncheck` uses call-graph analysis to report whether vulnerable symbols are actually invoked by the application code.

---

## 3. Tool Execution Guidelines (Safe & Deterministic)

### Permitted Verification Commands:
- `gofmt -l -d .` (Checks formatting compliance without mutating files).
- `go vet ./...` (Standard Go compiler static analysis).
- `go test -race -short ./...` (Runs fast tests with the LLVM-based race detector enabled).
- `golangci-lint run --fast` (Runs configured linters if repository contains `.golangci.yml`).

### Prohibited Actions During Review:
- **DO NOT** run `go mod tidy` or `go get` to modify `go.mod` or `go.sum`.
- **DO NOT** execute uncurated shell scripts from the repository without reviewing their source code.
- **DO NOT** install global binaries or mutate developer configuration files.

---

## False Positive Prevention Checklist

- [ ] Do NOT flag `replace` directives if they are pinned to an official fork branch (`replace example.com/pkg => github.com/myfork/pkg v1.0.1`).
- [ ] Do NOT flag tool execution skips as code defects; record unexecuted tools under the `Limitations` section of the review report.
