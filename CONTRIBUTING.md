# Contributing to `golang-review`

Thank you for your interest in improving `golang-review`! We welcome contributions from the Go and AI agent community.

---

## Code of Conduct & Philosophy

Our goal is to provide a **precise, actionable, and evidence-based** code review skill. Every rule and recommendation in this skill must:
1. **Adhere to Official Go Standards:** Follow [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), and standard Go language specifications.
2. **Be Evidence-Based:** Address real runtime bugs, data races, leaks, or vulnerabilities—never subjective stylistic taste.
3. **Include Concrete Examples:** Pair detection rules with short `// ❌ BAD` vs `// ✅ GOOD` code blocks.
4. **Prevent False Positives:** Clearly specify when a pattern should *not* be flagged (e.g. version-specific semantics like Go 1.22 loop variable scoping).

---

## How to Contribute

### 1. Adding or Enhancing a Review Check
All review checks live in the [`references/`](references/) directory:
- [`concurrency-and-context.md`](references/concurrency-and-context.md): Goroutines, sync, locks, channels, context.
- [`correctness-and-error-handling.md`](references/correctness-and-error-handling.md): Logic errors, typed nil, error wrapping, slices, maps.
- [`security.md`](references/security.md): Injections, path traversal, SSRF, cryptography, secrets.
- [`performance-and-resource-management.md`](references/performance-and-resource-management.md): Resource leaks, defer in loops, memory retention.
- [`architecture-and-maintainability.md`](references/architecture-and-maintainability.md): Interface design, package cycles, global state, naming.
- [`testing-and-quality.md`](references/testing-and-quality.md): Test reliability, `t.Parallel()`, flaky tests, helpers.
- [`dependencies-and-tooling.md`](references/dependencies-and-tooling.md): Module hygiene, vulnerabilities, replace directives.

When adding a new check, use this structure:

```markdown
## X. Title of the Check

### Detection Rules:
- Bulleted description of what flawed pattern to look for.
- Clear technical explanation of why it violates Go runtime or correctness guarantees.

```go
// ❌ BAD: Problematic code
...

// ✅ GOOD: Idiomatic, safe fix
...
```

### False Positive Prevention Checklist:
- [ ] Do NOT flag if [specific valid condition] is met.
```

---

## Validation & Quality Gate

Before opening a pull request, run the integrity validation script:

```bash
./scripts/validate_skill.sh
```

Ensure that:
- All required files exist.
- Frontmatter follows the Agent Skills specification.
- All reference files have supporting frontmatter (`description`, `tags`) and sufficient depth (>40 lines).
- No placeholder boilerplate exists.
- The validator exits with `VALIDATION SUCCEEDED! (0 errors)`.

---

## Pull Request Process

1. Fork the repository and create your branch from `main`:
   ```bash
   git checkout -b feature/my-new-check
   ```
2. Make your edits and run `./scripts/validate_skill.sh`.
3. Commit your changes with clear, conventional commit messages:
   ```bash
   git commit -m "feat(references): add check for context cancellation timer leak"
   ```
4. Push to your fork and submit a Pull Request.
5. In your PR description, explain the rationale, the Go standard cited, and any edge cases considered.
