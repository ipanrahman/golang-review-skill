#!/usr/bin/env bash
# ==============================================================================
# validate_skill.sh
# Integrity and compliance validator for the golang-review agent skill.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ERRORS=$((ERRORS + 1))
}

echo "=========================================================="
echo "  Auditing Skill Integrity: golang-review"
echo "  Root: ${SKILL_ROOT}"
echo "=========================================================="

# 1. Required Files Existence
REQUIRED_FILES=(
    "SKILL.md"
    "README.md"
    "LICENSE"
    "CONTRIBUTING.md"
    ".gitignore"
    "scripts/README.md"
    "templates/finding-examples.md"
    "templates/review-report.md"
    "references/concurrency-and-context.md"
    "references/correctness-and-error-handling.md"
    "references/security.md"
    "references/performance-and-resource-management.md"
    "references/architecture-and-maintainability.md"
    "references/testing-and-quality.md"
    "references/dependencies-and-tooling.md"
)

log_info "Verifying required files existence..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "${SKILL_ROOT}/${file}" ]]; then
        log_pass "File exists: ${file}"
    else
        log_fail "Missing required file: ${file}"
    fi
done

# 2. Frontmatter Validation in SKILL.md
log_info "Checking SKILL.md frontmatter compliance..."
SKILL_FILE="${SKILL_ROOT}/SKILL.md"

if grep -q "^name: golang-review" "${SKILL_FILE}"; then
    log_pass "SKILL.md has valid name field"
else
    log_fail "SKILL.md missing 'name: golang-review'"
fi

if grep -q 'description: "Use when' "${SKILL_FILE}"; then
    log_pass "SKILL.md description uses standard 'Use when' trigger pattern"
else
    log_fail "SKILL.md description does not follow 'Use when...' standard"
fi

if grep -q "category: discipline" "${SKILL_FILE}"; then
    log_pass "SKILL.md category set to 'discipline'"
else
    log_fail "SKILL.md missing category: discipline"
fi

if grep -q "triggers:" "${SKILL_FILE}"; then
    log_pass "SKILL.md has metadata.triggers defined"
else
    log_fail "SKILL.md missing metadata.triggers"
fi

# 3. Reference Files Quality & Anti-Placeholder Check
log_info "Checking reference files depth and placeholder absence..."
REFERENCES=(
    "concurrency-and-context.md"
    "correctness-and-error-handling.md"
    "security.md"
    "performance-and-resource-management.md"
    "architecture-and-maintainability.md"
    "testing-and-quality.md"
    "dependencies-and-tooling.md"
)

for ref in "${REFERENCES[@]}"; do
    ref_path="${SKILL_ROOT}/references/${ref}"
    if [[ -f "${ref_path}" ]]; then
        # Check against obsolete placeholder text
        if grep -q "Actionable checks for Go code reviews. Load only when relevant to the change." "${ref_path}"; then
            log_fail "Reference ${ref} still contains generic placeholder boilerplate!"
        else
            log_pass "Reference ${ref} is free of placeholder boilerplate"
        fi

        # Check line count depth (> 40 lines)
        line_count=$(wc -l < "${ref_path}" | tr -d ' ')
        if [[ "${line_count}" -ge 40 ]]; then
            log_pass "Reference ${ref} has sufficient depth (${line_count} lines)"
        else
            log_warn "Reference ${ref} is short (${line_count} lines); ensure sufficient coverage"
        fi

        # Check supporting frontmatter
        if grep -q "^description:" "${ref_path}" && grep -q "tags:" "${ref_path}"; then
            log_pass "Reference ${ref} has supporting frontmatter"
        else
            log_fail "Reference ${ref} missing supporting frontmatter (description / tags)"
        fi
    fi
done

# 4. Templates Schema Alignment
log_info "Verifying templates structure..."
if grep -q "GR-CAT-XXX" "${SKILL_ROOT}/SKILL.md" && grep -q "Evidence:" "${SKILL_ROOT}/templates/finding-examples.md"; then
    log_pass "Templates finding schema aligns with SKILL.md specification"
else
    log_fail "Templates finding format does not align with SKILL.md"
fi

# 5. Final Report
echo "=========================================================="
if [[ ${ERRORS} -eq 0 ]]; then
    echo -e "${GREEN}VALIDATION SUCCEEDED!${NC} Total checks passed with 0 errors and ${WARNINGS} warning(s)."
    exit 0
else
    echo -e "${RED}VALIDATION FAILED!${NC} Detected ${ERRORS} error(s) and ${WARNINGS} warning(s)."
    exit 1
fi
