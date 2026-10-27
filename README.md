# golang-review-skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.21%2B-00ADD8.svg?logo=go)](https://go.dev)
[![Effective Go](https://img.shields.io/badge/Standard-Effective_Go-blue.svg)](https://go.dev/doc/effective_go)
[![Agent Skill Spec](https://img.shields.io/badge/Spec-Agent_Skills-green.svg)](https://agentskills.io)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **Systematic, evidence-based code review agent skill for Go repositories, Pull Requests, and AI vibe-coding.**

`golang-review` is a production-grade AI Agent Skill designed to catch silent runtime bugs, concurrency deadlocks, memory/resource leaks, and security vulnerabilities in Go code. It strictly adheres to [Effective Go](https://go.dev/doc/effective_go) and [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments).

---

## ⚡ Why `golang-review`?

When building Go applications—especially when **vibe coding** with AI assistants—models frequently generate code that compiles but harbors subtle runtime disasters:
- **The "Typed Nil" Trap:** Returning a typed nil pointer as an `error` interface (`err != nil` always evaluates to `true`).
- **Goroutine Leaks:** Writing to unbuffered channels during timeout or early return.
- **Nil Dereference on Defer:** Calling `defer resp.Body.Close()` before checking `if err != nil`.
- **False-Positive Loop Races:** Old linters/models flagging loop variable captures in Go `>= 1.22` where loop variables have per-iteration scope.
- **Descriptor Exhaustion:** Placing raw `defer file.Close()` inside unbounded loops.

`golang-review` equips your AI coding agent with the exact heuristics to catch these defects while preventing frivolous, pedantic style arguments.

---

## 🚀 Key Capabilities

- **Evidence-Based Scoring:** Every finding requires exact file lines, concrete runtime trigger conditions, production impact, and an immediate copy-paste recommendation.
- **Effective Go & Go 1.21+ Certified:** Evaluates code using official idioms (guard clauses, "-er" interface naming, zero-value readiness).
- **Progressive Disclosure:** Token-efficient architecture. The agent loads only the reference document relevant to the current diff.
- **Safe & Non-Destructive:** Runs read-only checks (`gofmt -l -d`, `go vet`, `go test -short -race`) and prohibits unauthorized module modifications.

---

## 📂 Repository Structure

```text
.
├── SKILL.md                                        # Master Agent Entrypoint (CSO triggers, routing, stop criteria)
├── README.md                                       # Human-facing documentation & quickstart
├── LICENSE                                         # MIT License
├── CONTRIBUTING.md                                 # Guidelines for community contributions
├── references/                                     # Progressive disclosure technical guides
│   ├── concurrency-and-context.md                  # Goroutine leaks, mutex copies, loop variables, deadlocks
│   ├── correctness-and-error-handling.md           # Typed nil trap, errors.Is/As/Join, slice aliasing
│   ├── security.md                                 # SQLi, command injection, path traversal, SSRF, crypto/rand
│   ├── performance-and-resource-management.md      # HTTP body leaks, defer in loops, memory retention
│   ├── architecture-and-maintainability.md         # Interface idioms, global state, package cycles, naming
│   ├── testing-and-quality.md                      # t.Parallel() scoping, flaky tests, t.Cleanup, t.Helper
│   └── dependencies-and-tooling.md                 # go.mod hygiene, replace directives, govulncheck
├── templates/
│   ├── finding-examples.md                         # Standardized few-shot finding blocks & negative examples
│   └── review-report.md                            # Markdown report schema & tooling audit
└── scripts/
    ├── README.md                                   # Script documentation & safety guidelines
    └── validate_skill.sh                           # Automated skill integrity & compliance validator
```

---

## 📦 Installation & Setup

### Option 1: Claude Code / OpenClaw
Clone or copy this skill into your local skill directory:
```bash
# User-global installation
mkdir -p ~/.claude/skills/golang-review
git clone https://github.com/ipanrahman/golang-review-skill.git ~/.claude/skills/golang-review
```

### Option 2: Antigravity / Gemini CLI / Agent Environment
```bash
mkdir -p ~/.agents/skills/golang-review
git clone https://github.com/ipanrahman/golang-review-skill.git ~/.agents/skills/golang-review
```

### Option 3: Project-Local (Cursor / IDE)
Add the skill to your project repository:
```bash
git submodule add https://github.com/ipanrahman/golang-review-skill.git .agents/skills/golang-review
```

---

## 🛠️ Usage Example

Once installed, your agent automatically activates `golang-review` whenever you ask for Go code review, PR analysis, or bug hunting:

```text
User: "Review my staged changes in internal/worker/ before I commit."
```

The agent will output a structured report following `templates/review-report.md`:

```markdown
[ P1 ] [ High confidence ] GR-CONC-001: Goroutine leak on unbuffered channel upon timeout

File: internal/worker/fetcher.go:44-52

Evidence:
Spawning goroutine sends to unbuffered channel `ch <- res`. If `ctx.Done()` fires first,
the function returns and the goroutine blocks forever.

Trigger:
External API latency exceeding request context deadline.

Impact:
Accumulation of leaked goroutines and uncollected memory leading to process memory bloat.

Recommendation:
Allocate a buffered channel of size 1:
```go
ch := make(chan Result, 1)
go func() { ch <- doWork() }()
```
```

---

## 🧪 Validating the Skill

Run the built-in integrity validator to ensure all files, frontmatter, and references comply with the Agent Skills Specification:

```bash
./scripts/validate_skill.sh
```

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on adding new Go review heuristics, anti-pattern checks, and submitting pull requests.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
