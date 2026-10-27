---
description: Actionable code review checks for Go concurrency, goroutine lifecycles, synchronization, and context propagation.
metadata:
  tags: [concurrency, goroutines, mutex, channels, context, race-conditions]
---

# Concurrency & Context Review Checks

Review concurrent Go code for deadlocks, goroutine leaks, data races, and improper context cancellation propagation.

---

## 1. Goroutine Leaks

### Detection Rules

- **Unbuffered Channel Send upon Cancellation:** Spawning a goroutine that writes to an unbuffered or inadequately buffered channel when the parent function can return early (e.g. timeout, context cancel, or error).
- **Missing `select` with `ctx.Done()`:** Goroutines waiting indefinitely on channel reads or I/O without listening for context cancellation.
- **Unstopped `time.Ticker`:** Using `time.Tick` (which can never be GC'd) or `time.NewTicker` without `defer ticker.Stop()`.

```go
// ❌ BAD: Goroutine leaks if ctx cancels before worker completes
ch := make(chan Result)
go func() {
    ch <- doWork() // Blocks forever if receiver returned
}()
select {
case res := <-ch:
    return res, nil
case <-ctx.Done():
    return Result{}, ctx.Err()
}

// ✅ GOOD: Buffered channel allows goroutine to finish and exit without blocking
ch := make(chan Result, 1)
go func() {
    ch <- doWork()
}()
select {
case res := <-ch:
    return res, nil
case <-ctx.Done():
    return Result{}, ctx.Err()
}
```

---

## 2. Mutex Misuse & Copying

### Detection Rules

- **Passing Mutex by Value:** Passing a struct containing `sync.Mutex` or `sync.RWMutex` by value copies the lock state, breaking mutual exclusion.
- **Value Receiver with Lock:** Methods defining `func (s State) Update()` with a mutex copy the struct on every call. Receiver must be a pointer: `func (s *State) Update()`.
- **Unlock Placement:** Forgetting `defer mu.Unlock()` or unlocking after a conditional return that causes a deadlock.

```go
// ❌ BAD: Receiver is value; copies mutex on invocation
type Counter struct {
    mu sync.Mutex
    n  int
}
func (c Counter) Inc() { // Value receiver copies lock!
    c.mu.Lock()
    defer c.mu.Unlock()
    c.n++
}

// ✅ GOOD: Pointer receiver preserves lock identity
func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.n++
}
```

---

## 3. Loop Variable Scoping (Go Version Sensitivity)

### Detection Rules

- **Go < 1.22:** Capturing loop variables by reference inside goroutines (`for _, item := range list { go func() { use(item) }() }`) captures the single shared loop variable.
- **Go >= 1.22:** Loop variables have per-iteration scope. Goroutine captures are safe.
- **False Positive Prevention:** Always inspect `go.mod`. If Go version is `>= 1.22`, **do not** flag loop variable capture in goroutines as a bug.

```go
// ❌ BAD in Go < 1.22 (all goroutines may see the last item)
for _, v := range items {
    go func() {
        process(v)
    }()
}

// ✅ GOOD in Go < 1.22 (explicit shadow or parameter passing)
for _, v := range items {
    v := v // shadow variable locally
    go func() {
        process(v)
    }()
}
// Note: In Go 1.22+, the top syntax is already safe by language spec.
```

---

## 4. Context Propagation & Lifecycles

### Detection Rules

- **Context in Structs:** `context.Context` must not be stored inside struct fields (except standard exceptions like `http.Request`); pass as first parameter `ctx context.Context`.
- **Cancel Function Leak:** Not calling or deferring the cancel function returned by `context.WithCancel`, `WithTimeout`, or `WithDeadline` leaks timer goroutines and memory until expiry.
- **Replacing Incoming Context:** Replacing caller's `ctx` with `context.Background()` drops caller tracing and deadlines. If detached async work is required in Go 1.21+, use `context.WithoutCancel(ctx)`.

```go
// ❌ BAD: Cancel func not deferred, leaking context timer resources
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
res, err := client.Fetch(ctx)
if err != nil {
    return err // cancel() is never called!
}

// ✅ GOOD: Immediate defer ensures resources are freed
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel()
res, err := client.Fetch(ctx)
```

---

## 5. Channel Pitfalls & Deadlocks

### Detection Rules

- **Sending to a Closed Channel:** Panics at runtime. Only the sender (producer) should close the channel.
- **Closing a Nil Channel:** Panics at runtime.
- **Reading from Nil Channel:** Blocks forever.
- **Busy-Waiting Select:** A `select` block with an active `default:` inside an unthrottled loop pegs the CPU at 100%.

```go
// ❌ BAD: 100% CPU spike due to unthrottled busy-wait
for {
    select {
    case msg := <-ch:
        handle(msg)
    default:
        // Spinned constantly without pause or block
    }
}

// ✅ GOOD: Blocks cleanly until channel message or context cancellation
for {
    select {
    case msg, ok := <-ch:
        if !ok {
            return
        }
        handle(msg)
    case <-ctx.Done():
        return
    }
}
```

---

## 6. Go 1.23+ Range-Over-Func Iterators (`iter.Seq`, `iter.Seq2`)

### Detection Rules

- **Ignoring `yield` Return Value:** In Go 1.23+, iterators are defined as `func(yield func(V) bool)` or `func(yield func(K, V) bool)`. When consumer terminates a loop early (via `break`, `return`, or `goto`), `yield(...)` returns `false`.
- **Iterator Leak & Zombie Loops:** If a custom iterator ignores `!yield(...)` and continues iterating, background resource acquisition, channel consumption, or loop execution continues fruitlessly, leaking CPU and goroutines.
- **Panic on Calling Yield After False:** Yield must never be called again once it returns `false`.

```go
// ❌ BAD: Generator ignores yield() returning false upon consumer break
func StreamRecords(db *DB) iter.Seq[Record] {
    return func(yield func(Record) bool) {
        rows := db.Query("SELECT ...")
        defer rows.Close()
        for rows.Next() {
            rec := parseRecord(rows)
            yield(rec) // BUG: If caller 'break's, loop continues to end of table!
        }
    }
}

// ✅ GOOD: Immediately terminate iterator when yield returns false
func StreamRecords(db *DB) iter.Seq[Record] {
    return func(yield func(Record) bool) {
        rows := db.Query("SELECT ...")
        defer rows.Close()
        for rows.Next() {
            rec := parseRecord(rows)
            if !yield(rec) {
                return // Exits promptly and invokes defer rows.Close()
            }
        }
    }
}
```

---

## 7. Thread-Safe Lazy Initialization (`sync.OnceValues` Go 1.21+)

### Detection Rules

- **Boilerplate Mutex for One-Time Computation:** Using a custom `sync.RWMutex` with a double-checked locking flag or manual `sync.Once` pattern with package variables when initializing resources that yield values or errors.
- **Idiomatic `sync.OnceValue` / `sync.OnceValues`:** In Go 1.21+, use `sync.OnceValue` (for a single return value) or `sync.OnceValues` (for `(value, error)` returns) to safely encapsulate thread-safe single initialization.

```go
// ❌ BAD: Verbose manual Once with leaked package variable
var (
    cfg     *Config
    cfgErr  error
    cfgOnce sync.Once
)
func GetConfig() (*Config, error) {
    cfgOnce.Do(func() {
        cfg, cfgErr = loadConfig()
    })
    return cfg, cfgErr
}

// ✅ GOOD (Go 1.21+): Clean encapsulation with sync.OnceValues
var loadConfigOnce = sync.OnceValues(func() (*Config, error) {
    return loadConfig()
})

func GetConfig() (*Config, error) {
    return loadConfigOnce()
}
```

---

## False Positive Prevention Checklist

- [ ] Do NOT flag `go func() { ... }` as a leak if it has a bounded, deterministic completion path (e.g., standard WaitGroup synchronization).
- [ ] Do NOT flag loop variable captures if `go.mod` specifies Go version `1.22` or newer.
- [ ] Do NOT flag `time.NewTicker` or `time.NewTimer` without `Stop()` as permanent uncollected leaks if `go.mod` specifies Go version `1.23` or newer (Go 1.23 GC automatically collects unreferenced timers), though calling `Stop()` remains best practice.
- [ ] Do NOT flag lock-free patterns if atomic primitives (`sync/atomic`) are properly applied.
