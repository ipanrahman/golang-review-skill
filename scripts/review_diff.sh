#!/usr/bin/env bash
# ==============================================================================
# review_diff.sh
# Automated, read-only static analysis and AST heuristic harvester for Go code reviews.
# Designed for developers and AI agents running golang-review-skill.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_REF="${1:-HEAD}"

echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD}  golang-review: Automated Diff Analysis Harvester       ${NC}"
echo -e "${BOLD}  Target Ref: ${TARGET_REF}${NC}"
echo -e "${BOLD}==========================================================${NC}"

# 1. Detect Go Version from go.mod
GO_VERSION="unknown"
if [ -f "${REPO_ROOT}/go.mod" ]; then
    GO_VERSION=$(grep -E '^go [0-9]+\.[0-9]+' "${REPO_ROOT}/go.mod" | awk '{print $2}' || echo "unknown")
fi
echo -e "${BLUE}[INFO]${NC} Detected Go Directive: ${BOLD}${GO_VERSION}${NC}"

if [ "${GO_VERSION}" != "unknown" ]; then
    MAJOR=$(echo "${GO_VERSION}" | cut -d. -f1)
    MINOR=$(echo "${GO_VERSION}" | cut -d. -f2)
    if [ "${MAJOR}" -eq 1 ] && [ "${MINOR}" -ge 22 ]; then
        echo -e "${GREEN}[NOTE]${NC} Go >= 1.22 detected: Loop variables have per-iteration scope. Do NOT flag for loop variable captures."
    else
        echo -e "${YELLOW}[NOTE]${NC} Go < 1.22 detected: Watch out for loop variable capture in goroutines and t.Parallel() subtests."
    fi
fi

# 2. Extract Changed Go Files
echo ""
echo -e "${BLUE}[INFO]${NC} Identifying changed Go files..."
CHANGED_FILES=()
if git rev-parse --verify "${TARGET_REF}" >/dev/null 2>&1; then
    # Diff against ref or staged/unstaged
    if [ "${TARGET_REF}" = "HEAD" ]; then
        # Check both staged and unstaged
        while IFS= read -r file; do
            [ -n "$file" ] && CHANGED_FILES+=("$file")
        done < <(git diff --name-only HEAD | grep -E '\.go$|go\.mod$' || true)
    else
        while IFS= read -r file; do
            [ -n "$file" ] && CHANGED_FILES+=("$file")
        done < <(git diff --name-only "${TARGET_REF}" | grep -E '\.go$|go\.mod$' || true)
    fi
fi

if [ ${#CHANGED_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}[WARN]${NC} No changed Go files detected against ${TARGET_REF}. Inspecting all tracked Go files in workspace..."
    while IFS= read -r file; do
        [ -n "$file" ] && CHANGED_FILES+=("$file")
    done < <(git ls-files '*.go' 'go.mod' | head -n 30 || true)
fi

echo -e "${GREEN}[OK]${NC} Found ${#CHANGED_FILES[@]} relevant file(s) for review."
for f in "${CHANGED_FILES[@]}"; do
    echo "  - $f"
done

# 3. Deterministic Formatting Verification (gofmt)
echo ""
echo -e "${BLUE}[INFO]${NC} Running non-destructive formatting check (gofmt -d)..."
FORMAT_ISSUES=0
for f in "${CHANGED_FILES[@]}"; do
    if [[ "$f" =~ \.go$ ]] && [ -f "$f" ]; then
        DIFF_OUT=$(gofmt -d "$f" 2>&1 || true)
        if [ -n "$DIFF_OUT" ]; then
            echo -e "${RED}[FAIL]${NC} Formatting discrepancy in: $f"
            echo "$DIFF_OUT" | head -n 20
            FORMAT_ISSUES=$((FORMAT_ISSUES + 1))
        fi
    fi
done
if [ $FORMAT_ISSUES -eq 0 ]; then
    echo -e "${GREEN}[PASS]${NC} All analyzed files adhere strictly to standard gofmt."
fi

# 4. Standard Compiler Static Analysis (go vet)
echo ""
echo -e "${BLUE}[INFO]${NC} Running go vet..."
if command -v go >/dev/null 2>&1 && [ -f "${REPO_ROOT}/go.mod" ]; then
    VET_OUT=$(go vet ./... 2>&1 || true)
    if [ -n "$VET_OUT" ]; then
        echo -e "${YELLOW}[WARN]${NC} go vet reported issues:"
        echo "$VET_OUT"
    else
        echo -e "${GREEN}[PASS]${NC} go vet produced 0 errors."
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} go command or go.mod not found. Skipping go vet."
fi

# 5. Security & Concurrency Pattern Harvester (Diff Regex Scan)
echo ""
echo -e "${BLUE}[INFO]${NC} Scanning changes for high-risk runtime anti-patterns..."
DIFF_CONTENT=$(git diff "${TARGET_REF}" -- '*.go' 2>/dev/null || git diff HEAD -- '*.go' 2>/dev/null || true)

check_pattern() {
    local pattern="$1"
    local category="$2"
    local warning="$3"
    if echo "$DIFF_CONTENT" | grep -E "^\+.*${pattern}" >/dev/null 2>&1; then
        echo -e "${YELLOW}[TRIGGER]${NC} [${category}] ${warning}"
    fi
}

check_pattern "make\(chan [a-zA-Z0-9_\*]+\)" "GR-CONC" "Unbuffered channel creation detected. Ensure reader cannot return early or use buffer of 1."
check_pattern "defer .*\.Close\(\)" "GR-RES" "Deferred Close() detected. Verify error is not ignored on write streams, or resp is not nil before defer."
check_pattern "fmt\.Sprintf\(.*(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)" "GR-SEC" "Potential raw SQL formatting detected. Verify parameterized queries."
check_pattern "exec\.Command\(\"(sh|bash|zsh)\"" "GR-SEC" "Shell interpreter invocation detected. Prefer direct binary arguments to avoid command injection."
check_pattern "http\.ListenAndServe\(" "GR-RES" "Default http.ListenAndServe without timeouts detected. Prefer http.Server with ReadHeaderTimeout."
check_pattern "slog\.(Info|Error|Warn|Debug)\(.*(password|token|secret|apiKey)" "GR-SEC" "Potential sensitive credential logging detected in slog call."

# 5b. Advanced Runtime Pattern Harvester (Iterator, os.Root, Struct Alignment, Tx Rollback)
echo ""
echo -e "${BLUE}[INFO]${NC} Scanning for Go 1.23+/1.24+ runtime anti-patterns..."

check_pattern "func\(yield func\([^)]+\) bool\)" "GR-CONC" "Iterator (iter.Seq) definition detected. Verify yield return value is checked: 'if !yield(v) { return }'."
check_pattern "yield\([^)]+\)" "GR-CONC" "Yield call detected. Ensure caller checks return value and returns on false."
check_pattern "os\.OpenRoot\(" "GR-SEC" "os.Root usage detected (Go 1.24+). Verify untrusted paths use root.Open() for kernel-level sandboxing."
check_pattern "filepath\.Clean\(|filepath\.Rel\(" "GR-SEC" "Lexical path sanitization (filepath.Clean/Rel) detected. Consider os.Root (Go 1.24+) for TOCTOU-proof containment."
check_pattern "db\.BeginTx\(|db\.Begin\(" "GR-RES" "Transaction started. Verify 'defer tx.Rollback()' immediately follows BeginTx for guaranteed cleanup."
check_pattern "tx\.Commit\(\)" "GR-RES" "Transaction commit detected. Ensure deferred Rollback() precedes it (safe no-op idiom)."
check_pattern "type [A-Z][a-zA-Z0-9]* struct \{" "GR-PERF" "Struct definition detected. Consider field ordering: 8-byte (int64, uint64, pointer) first, then 4-byte, 2-byte, 1-byte to minimize padding."
check_pattern "ReadHeaderTimeout" "GR-RES" "ReadHeaderTimeout explicitly set. Verify ReadTimeout, WriteTimeout, IdleTimeout are also configured."
check_pattern "sync\.OnceValue|sync\.OnceValues" "GR-CONC" "sync.OnceValue/OnceValues detected (Go 1.21+). Idiomatic for thread-safe lazy init with return values."
check_pattern "iter\.Seq|iter\.Seq2" "GR-CONC" "iter.Seq/Seq2 type usage detected. Ensure iterator implementations respect yield contract."

echo ""
echo -e "${BOLD}==========================================================${NC}"
echo -e "${GREEN}Diff Analysis Harvest Complete.${NC}"
echo -e "${BOLD}Use the output above as deterministic evidence for your code review.${NC}"
echo -e "${BOLD}==========================================================${NC}"
