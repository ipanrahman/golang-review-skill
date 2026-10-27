---
description: Actionable code review checks for Go tests, table-driven patterns, t.Parallel() scoping, flakiness, and test helpers.
metadata:
  tags: [testing, quality, table-driven, t-parallel, flaky-tests, test-helpers, race-detector]
---

# Testing & Quality Review Checks

Review Go tests for reliability, race conditions, edge case coverage, deterministic execution, and idiomatic test patterns.

---

## 1. Table-Driven Tests & `t.Parallel()` Scoping

### Detection Rules

- **Go < 1.22 Scoping Trap:** In Go versions earlier than 1.22, running subtests with `t.Parallel()` without local re-binding (`tc := tc`) causes all parallel subtests to run concurrently using the **last iteration's test case**.
- **Go >= 1.22:** The loop variable has per-iteration scope. Do not flag parallel subtests as bugs if `go.mod` specifies Go `>= 1.22`.

```go
// ❌ BAD in Go < 1.22: All subtests execute with the final test case
func TestCalculator(t *testing.T) {
    tests := []TestCase{ /* ... */ }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel() // Runs concurrently on the single shared tc variable!
            assert.Equal(t, tc.expected, calculate(tc.input))
        })
    }
}

// ✅ GOOD in Go < 1.22: Local variable capture isolates each subtest
for _, tc := range tests {
    tc := tc // Shadow variable
    t.Run(tc.name, func(t *testing.T) {
        t.Parallel()
        assert.Equal(t, tc.expected, calculate(tc.input))
    })
}
```

---

## 2. Flaky Tests & Arbitrary Sleep Timing

### Detection Rules

- **Sleeping for Synchronization:** Using `time.Sleep(50 * time.Millisecond)` to "wait for background worker" creates brittle, slow, and flaky tests on congested CI runners.
- **Deterministic Synchronization:** Synchronize using channels, `sync.WaitGroup`, or event-driven polling (`assert.Eventually` / bounded retry loops).

```go
// ❌ BAD: Arbitrary sleep causes flaky test failures under CI CPU load
go worker.Start()
time.Sleep(100 * time.Millisecond) // Unreliable wait
assert.True(t, worker.IsReady())

// ✅ GOOD: Channel-based or condition-based notification
readyCh := make(chan struct{})
go worker.StartWithSignal(readyCh)
select {
case <-readyCh:
    // Worker is deterministically ready
case <-time.After(2 * time.Second):
    t.Fatal("timed out waiting for worker startup")
}
```

---

## 3. Test Fixture Cleanup & `t.Cleanup`

### Detection Rules

- **Deferred Cleanup after `t.Fatal()`:** Using raw `defer cleanup()` inside a test helper after `t.Fatal()` or assertions that invoke `t.FailNow()`. If the assertion fails, subsequent defers in that scope may not run.
- **Use `t.Cleanup()`:** Register teardown logic with `t.Cleanup(func() { ... })`. Go guarantees cleanup runs regardless of test panics or early test failures.

---

## 4. Test Helper Stack Traces (`t.Helper()`)

### Detection Rules

- Custom test assertions and setup functions should invoke `t.Helper()` at the start.
- Without `t.Helper()`, failure line numbers point to the assertion helper itself rather than the actual failing test line in the test file.

---

## 5. Negative Path & Error Verification

### Detection Rules

- Verifying only that `err != nil` without checking the specific expected error type or sentinel value.
- When testing validation or failure branches, use `assert.ErrorIs(t, err, ErrExpected)` to ensure the expected failure occurred, rather than an unrelated initialization error.

---

## False Positive Prevention Checklist

- [ ] Do NOT flag `t.Parallel()` without `tc := tc` if `go.mod` specifies Go version `1.22` or newer.
- [ ] Do NOT flag simple unit tests for lack of mock interfaces if using real in-memory concrete structs is faster and clearer.
- [ ] Do NOT demand 100% test coverage; focus on high-risk concurrency, edge cases, and business domain invariants.
