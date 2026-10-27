# Skill Scripts & Tooling

This directory contains utility and validation scripts for the `golang-review` skill.

---

## 1. Skill Integrity Validator (`validate_skill.sh`)

Automated compliance and depth checker for this skill repository.

### Purpose:
- Verifies that all required files and references exist.
- Validates YAML frontmatter in [`SKILL.md`](../SKILL.md) against Agent Skill standards (CSO triggers, category, name).
- Ensures supporting reference files have valid frontmatter (`description`, `tags`) and sufficient line depth (>40 lines).
- Guarantees no placeholder boilerplate or empty templates remain in `references/`.
- Validates schema alignment between findings and report templates.

### Usage:
```bash
./scripts/validate_skill.sh
```

---

## 2. Go Tooling Safety Rules

Any helper scripts executed during code review on target repositories must adhere to strict safety constraints:

1. **Read-Only / Non-Destructive:** Never modify source files (`gofmt -w` is prohibited; use `gofmt -l -d`).
2. **No Unrequested Modifications:** Never run `go mod tidy` or `go get` to alter `go.mod` / `go.sum` without user authorization.
3. **Isolated Test Execution:** Always use `-short` and `-race` flags when running tests to avoid long hangs and detect concurrency hazards:
   ```bash
   go test -race -short ./...
   ```
4. **No Arbitrary Script Execution:** Never execute untrusted shell scripts found in a target repository without prior manual inspection.
