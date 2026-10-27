---
description: Standardized Markdown template for Go code review reports, providing structured sections for scope, findings table, detailed evidence blocks, and verification audit.
metadata:
  tags: [template, report, code-review, golang]
---

# Go Code Review Report

## 1. Executive Summary

- **Overall Outcome:** [ Changes Requested | Follow-up Recommended | Approved / No Actionable Findings ]
- **Risk Assessment:** [ High Risk | Moderate Risk | Low Risk / Production-Ready ]
- **Key Highlights:** Brief 2-3 sentence overview of the most critical findings (if any) or validation summary.

---

## 2. Review Scope & Environment

- **Review Target:** `[PR #, branch name, or commit hash]`
- **Base Revision:** `[main / target commit]`
- **Go Version:** `[e.g. Go 1.22 from go.mod]`
- **Reviewed Files:**
  - `path/to/file1.go`
  - `path/to/file2.go`

---

## 3. Findings Summary

| ID | Severity | Confidence | Location | Title |
| :--- | :---: | :---: | :--- | :--- |
| **GR-SEC-001** | P0 | High | `internal/repo/user.go:58` | SQL Injection via string formatting |
| **GR-CONC-001** | P1 | High | `pkg/worker/fetcher.go:112` | Goroutine leak on unbuffered channel |

*(If no issues are identified, state: "No actionable findings identified within the reviewed scope.")*

---

## 4. Detailed Findings

### [ Severity ] [ Confidence ] GR-CAT-XXX: Concise Title

**File:** `path/to/file.go:lines`

**Evidence:**
Detailed description of the code flaw, citing the exact lines and why it violates Go runtime, concurrency, or correctness semantics.

**Trigger:**
The concrete runtime condition, caller argument, or error scenario that triggers this defect.

**Impact:**
Real-world production consequence (e.g. panic, memory leak, security compromise, data race).

**Recommendation:**
Idiomatic Go code or architectural modification to resolve the issue:

```go
// Proposed fix
```

---

## 5. Verification & Tooling Execution

| Tool | Status | Result / Findings |
| :--- | :---: | :--- |
| `gofmt -l -d` | Executed | Clean / Formatting diff found |
| `go vet ./...` | Executed | 0 issues reported |
| `go test -race ./...` | Executed | All tests passed; 0 data races detected |
| `govulncheck ./...` | Not Run | Tool not installed in runtime environment |

> [!NOTE]
> All checks marked as **Executed** reflect real commands run in the environment. Checks that could not be run are explicitly documented above.

---

## 6. Limitations & Assumptions

- Document any unexecuted tests, external dependencies that could not be verified, or assumptions made about upstream caller inputs.

---

## 7. Recommendation & Next Steps

- **Action:** [ Block merge until P0/P1 resolved | Merge with non-blocking follow-up | Proceed to merge ]
