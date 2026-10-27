---
description: Actionable code review checks for Go correctness, nil-safety, typed nil traps, error wrapping, and slice/map semantics.
metadata:
  tags: [correctness, error-handling, typed-nil, errors-is, errors-as, slices, maps]
---

# Correctness & Error Handling Review Checks

Review Go code for logical bugs, nil interface pitfalls, error propagation flaws, and subtle runtime semantics.

---

## 1. The "Typed Nil" Interface Trap

### Detection Rules

- An interface variable holding a concrete pointer of value `nil` is **NOT equal to `nil`** because the interface header contains type information.
- Returning a concrete pointer type as an `error` interface often causes callers to evaluate `if err != nil` as `true`.

```go
// ❌ BAD: Returns non-nil interface holding (*MyError)(nil)
func Validate(data []byte) error {
    var err *CustomValidationError = nil
    if len(data) == 0 {
        err = &CustomValidationError{Msg: "empty"}
    }
    return err // Even if empty is false, caller's `err != nil` is TRUE!
}

// ✅ GOOD: Return explicit nil interface value
func Validate(data []byte) error {
    if len(data) == 0 {
        return &CustomValidationError{Msg: "empty"}
    }
    return nil // Explicit nil interface
}
```

---

## 2. Modern Error Propagation & Inspection

### Detection Rules

- **String Error Comparison:** Never check errors using `err.Error() == "record not found"`. Always use `errors.Is(err, ErrNotFound)` to support wrapped errors.
- **Error Casting:** Never use direct type assertions (`err.(*CustomError)`) without handling wrapping. Use `errors.As(err, &target)`.
- **Error Wrapping:** Use `%w` in `fmt.Errorf` when callers need to inspect root causes. Use `%v` only when intentionally hiding implementation details.
- **Multi-Errors (Go 1.20+):** Use `errors.Join(err1, err2)` instead of custom slice aggregators.

```go
// ❌ BAD: Breaks error unwrapping and brittle on string changes
if err != nil && err.Error() == "not found" {
    return handleNotFound()
}

// ✅ GOOD: Robustly traverses the error chain
if errors.Is(err, sql.ErrNoRows) {
    return handleNotFound()
}
```

---

## 3. Slice Aliasing & Capacity Mutation

### Detection Rules

- **Shared Backing Array Mutation:** Slicing an existing slice (`sub := orig[0:2]`) shares the same backing array. An `append(sub, x)` will overwrite elements in `orig` if `cap(sub) > len(sub)`.
- **Full Slice Expressions:** Use 3-index slice syntax `orig[0:2:2]` to bound capacity, forcing `append` to allocate a fresh array instead of corrupting the parent.

```go
// ❌ BAD: append modifies parent slice elements if capacity allows
func process(items []int) []int {
    prefix := items[:2]
    return append(prefix, 999) // May overwrite items[2]!
}

// ✅ GOOD: Full slice expression clamps capacity
func process(items []int) []int {
    prefix := items[:2:2] // cap is 2; append guaranteed to reallocate
    return append(prefix, 999)
}
```

---

## 4. Unchecked Close Errors on Write Streams

### Detection Rules

- **Deferred `Close()` on Writers:** In write operations (`*os.File`, `gzip.Writer`, `bufio.Writer`), unwritten buffer data is flushed during `Close()`. Ignoring the error via a raw `defer f.Close()` can silently swallow disk full or I/O failure errors.
- **Read Streams vs Write Streams:** Deferring `Close()` without checking error is acceptable for pure read streams (e.g. `resp.Body.Close()`), but critical for writes.

```go
// ❌ BAD: Write error during final buffer flush is silently lost
func Save(filename string, data []byte) error {
    f, err := os.Create(filename)
    if err != nil {
        return err
    }
    defer f.Close()
    _, err = f.Write(data)
    return err
}

// ✅ GOOD: Capture and handle Close error on writers
func Save(filename string, data []byte) (err error) {
    f, err := os.Create(filename)
    if err != nil {
        return err
    }
    defer func() {
        closeErr := f.Close()
        if err == nil {
            err = closeErr
        }
    }()
    _, err = f.Write(data)
    return err
}
```

---

## 5. Map & Nil Pointer Semantics

### Detection Rules

- **Writing to a Nil Map:** Reading from a `nil` map is safe (returns zero value), but writing to a `nil` map (`var m map[string]int; m["key"] = 1`) causes an immediate runtime panic.
- **Concurrent Map Access:** Go runtime detects concurrent map read/write and panics fatally. Use `sync.Mutex` or `sync.Map`.

---

## 6. Control Flow & Guard Clauses (Effective Go § If)

### Detection Rules

- **Eliminating Unnecessary Else:** If the `if` branch ends in a `return`, `break`, `continue`, or `panic`, omit the `else` block. Keep the happy path aligned to the left margin ("line of sight" coding).
- **Multiple Error Cascades:** Avoid deep nesting of `else if` for error checking. Handle and return errors early.

```go
// ❌ BAD: Deep indentation with unnecessary else blocks
func ReadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    } else {
        cfg, err := parse(data)
        if err != nil {
            return nil, err
        } else {
            return cfg, nil
        }
    }
}

// ✅ GOOD: Clean line-of-sight guard clauses per Effective Go
func ReadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    cfg, err := parse(data)
    if err != nil {
        return nil, err
    }
    return cfg, nil
}
```

---

## 7. Errors as Values vs Panic (Effective Go § Panic)

### Detection Rules

- **No Panic for Normal Failures:** Never use `panic` for routine errors (such as file not found, bad network connection, or invalid user input). Functions must return `(Result, error)`.
- **Panic Boundary:** `panic` is reserved strictly for unrecoverable programmer errors or package initialization failures (`MustCompile`).

---

## 8. Structured Logging Hygiene (`log/slog` Go 1.21+)

### Detection Rules

- **Odd Key-Value Argument Count:** `slog` methods (`slog.Info`, `slog.Error`) accept variadic `...any` key-value pairs. Passing an odd number of arguments causes `slog` to synthesize an unintended `!BADKEY` attribute in log outputs.
- **Sensitive Data Exposure:** Never log unsanitized tokens, authorization headers, passwords, or PII into structured logs.
- **Performance in Hot Loops:** In performance-sensitive code, prefer strongly typed `slog.Attr` (`slog.String("k", v)`, `slog.Int("k", v)`) with `LogAttrs` over loose key-value pairs (`slog.Any`) to avoid heap boxing.

```go
// ❌ BAD: Odd argument count creates "!BADKEY" attribute; logs raw credential
slog.Info("user login attempt", "user", username, "auth_header", authHeader, "attempt") // attempt has no value!

// ✅ GOOD: Balanced attributes and sanitized sensitive data
slog.Info("user login attempt",
    "user", username,
    "auth_present", authHeader != "",
    "attempt_count", 1,
)
```

---

## 9. Idiomatic Standard Library Helpers (`slices` & `maps` Go 1.21+)

### Detection Rules

- **Reinventing Standard Helpers:** Writing custom loops for element searching, deletion, or map cloning instead of using the standard generic packages `slices` and `maps`.
- **Slice Mutation Safety:** Using `slices.Delete` or `slices.Compact` modifies the slice in-place but returns a new shortened slice. Callers must assign the result back: `s = slices.Delete(s, i, j)`.

```go
// ❌ BAD: Custom boilerplate loop prone to off-by-one or slice aliasing
found := false
for _, v := range items {
    if v == target {
        found = true
        break
    }
}

// ✅ GOOD (Go 1.21+): Concise and optimized stdlib helper
found := slices.Contains(items, target)
```

---

## False Positive Prevention Checklist

- [ ] Do NOT require `errors.Wrap` / `%w` if the function boundary intentionally encapsulates external error details as an internal implementation detail.
- [ ] Do NOT flag `defer resp.Body.Close()` without error checking on read streams unless the stream requires transactional confirmation.
- [ ] Do NOT flag simple struct copying unless the struct contains mutexes, large arrays, or pointer invariants.
- [ ] Do NOT flag `log/slog` string attributes if the call site is not on a proven performance-critical hot path.
