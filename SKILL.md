---
name: golang-review
description: "Use when reviewing Go code, pull requests, diffs, or bug-fix patches for correctness, concurrency safety, security vulnerabilities, memory/resource leaks, and production readiness."
metadata:
  category: discipline
  triggers:
    - "go code review"
    - "review go pr"
    - "golang diff"
    - "goroutine leak"
    - "data race"
    - "go.mod"
    - "nil pointer dereference"
---

# golang-review

Review Go code systematically with correctness, concurrency safety, security, resource management, reliability, and production readiness as primary criteria. All idiomatic evaluations strictly follow official [Effective Go](https://go.dev/doc/effective_go) and [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments).

## Scope & Boundaries

- **Default Scope:** Analyze changed files and immediately affected callers, contracts, and interfaces.
- **Selective Expansion:** Trace external packages or types only when verifying resource lifecycles, concurrency guarantees, context cancellation, or data flows.
- **Foundational Standards:** Align strictly with [Effective Go](https://go.dev/doc/effective_go) idioms (e.g. `gofmt` authority, guard clauses, "-er" interface naming, zero-value readiness).
- **Non-Goals:**
  - Enforcing personal or subjective style preferences as defects.
  - Demanding interface abstractions or error wrapping where standard concrete returns suffice.
  - Claiming data races, memory regressions, or performance bottlenecks without verifiable execution traces or benchmark evidence.

## Stop Conditions (Context Efficiency)

- **Stop Inspection:** Once changed files and their immediate interface boundaries have been verified against the relevant checklists.
- **Repo Audits:** Do not expand into whole-repository analysis unless explicitly requested by the user.
- **Finding Threshold:** Focus on high-impact defects (prioritize P0 and P1). Cap findings at the most critical issues to avoid reviewer fatigue.
- **Clean Diff:** If no defects are substantiated by evidence, state clearly that no actionable findings were identified within the reviewed scope. Do not invent speculative issues.

## Reference Routing

Load **only** the reference file corresponding to the categories present in the diff to conserve context:

| Category | Topics Covered | Reference File |
| :--- | :--- | :--- |
| **Correctness & Errors** | `errors.Is/As/Join`, typed nil vs interface nil, slice aliasing, loop scopes | [`references/correctness-and-error-handling.md`](references/correctness-and-error-handling.md) |
| **Concurrency & Context** | Goroutine leaks, mutex copy-by-value, channel deadlocks, context propagation | [`references/concurrency-and-context.md`](references/concurrency-and-context.md) |
| **Security** | SQL injection, shell command execution, path traversal, SSRF, `crypto/rand` | [`references/security.md`](references/security.md) |
| **Performance & Resources** | HTTP `Body.Close()`, `sql.Rows` leaks, `defer` in loops, slice memory retention | [`references/performance-and-resource-management.md`](references/performance-and-resource-management.md) |
| **Architecture** | Package cyclic dependencies, interface pollution, global state, API contracts | [`references/architecture-and-maintainability.md`](references/architecture-and-maintainability.md) |
| **Testing** | Table-driven tests, `t.Parallel()` capture, flaky timer sleeps, `-race` execution | [`references/testing-and-quality.md`](references/testing-and-quality.md) |
| **Dependencies & Tooling** | `go.mod` directives, CVE audits (`govulncheck`), replace directives, build tags | [`references/dependencies-and-tooling.md`](references/dependencies-and-tooling.md) |

## Review Workflow

1. **Repo Context & Go Version:** Read `go.mod` (determine Go version, e.g. `< 1.22` loop capture vs `>= 1.22`), `README.md`, and CI/linter configurations.
2. **Review Target:** Identify changed files, diffs, and base commit/branch.
3. **Tool Execution (Deterministic Evidence):**
   - Run available project tools (`go vet`, `gofmt -d`, `go test -race ./...`, `golangci-lint`) if permitted.
   - Record tool output honestly: distinguish executed checks from unexecuted ones.
4. **Categorical Analysis:** Route to specific categories above and consult only the matching reference files.
5. **Finding Verification:**
   - Verify exact file and line numbers.
   - Trace the concrete execution path triggering the defect.
   - Formulate specific, actionable remediation code.
6. **Report Generation:** Format the final output using [`templates/review-report.md`](templates/review-report.md) with findings matching [`templates/finding-examples.md`](templates/finding-examples.md).

## Severity Classification

- **P0 - Critical:** Immediate crash, remote code execution, SQLi, active memory corruption, or irrecoverable data loss in production.
- **P1 - High:** Goroutine leak under common failure paths, silent error swallow affecting core state, data race on shared state, resource leak under load.
- **P2 - Medium:** Incomplete error wrapping, unhandled edge cases, missing timeout on external I/O, suboptimal concurrency patterns.
- **P3 - Low:** Non-critical hygiene, minor test coverage gaps, unoptimized allocations without noticeable production degradation.

## Confidence Levels

- **High:** Confirmed by static code path proof, compiler error, test failure, or deterministic `-race` reproduction.
- **Medium:** Plausible execution path identified, but depends on external caller invariants or uninspected inputs.
- **Low:** Speculative risk; requires human maintainer domain clarification.

## Finding Format

Every finding must strictly follow this structure:

```markdown
[ Severity ] [ Confidence ] GR-CAT-XXX: Concise Title

File: path/to/file.go:lines

Evidence:
Concise description of the flawed code and why it violates Go correctness or runtime guarantees.

Trigger:
The runtime condition, user input, or caller behavior that triggers the issue.

Impact:
Concrete effect in production (e.g., goroutine leak, deadlock, data race, silent failure).

Recommendation:
Exact code correction or idiomatic Go refactoring needed to resolve the issue.
```

## Tooling & Safety Rules

- Inspect repository instructions and permissions before invoking any build tools.
- Never install external CLI tools, modify go module files, or edit project source code during review without explicit user approval.
- Never claim a tool or test passed unless it was actually executed and produced zero errors.

## Output

Render final review output according to [`templates/review-report.md`](templates/review-report.md).