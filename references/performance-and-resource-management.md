---
description: Actionable code review checks for Go performance, resource leaks, memory retention, buffer handling, and connection pooling.
metadata:
  tags: [performance, resource-management, memory-leaks, defer-in-loop, http-body, sql-rows]
---

# Performance & Resource Management Review Checks

Review Go code for resource leaks, unbounded memory retention, file descriptor exhaustion, and allocation bottlenecks.

---

## 1. HTTP Response Body Handling

### Detection Rules

- **Nil Dereference on Defer:** Placing `defer resp.Body.Close()` before checking `if err != nil`. When an error occurs (e.g. DNS failure, timeout), `resp` is `nil` and the deferred call panics.
- **Connection Reuse Leak (Keep-Alive):** To enable HTTP keep-alive connection reuse, the client must consume the remaining response body before closing it.

```go
// ❌ BAD: Panics if err != nil because resp is nil
resp, err := http.Get(url)
defer resp.Body.Close() // PANIC if err != nil!
if err != nil {
    return err
}

// ✅ GOOD: Check error first; consume body for connection reuse
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
io.Copy(io.Discard, resp.Body) // Drain body to reuse TCP connection
```

---

## 2. Defer in Loops (Resource Exhaustion)

### Detection Rules

- `defer` statements inside loops only execute when the **enclosing function** returns, not at the end of each iteration.
- Placing `defer f.Close()` or `defer tx.Rollback()` in a loop processing thousands of items can exhaust file descriptors, database connections, or memory.

```go
// ❌ BAD: Descriptors remain open until ProcessAll returns
func ProcessAll(paths []string) error {
    for _, p := range paths {
        f, err := os.Open(p)
        if err != nil {
            return err
        }
        defer f.Close() // Stacks up hundreds of unclosed file handles!
        consume(f)
    }
    return nil
}

// ✅ GOOD: Encapsulate iteration in a separate function to release resources immediately
func ProcessAll(paths []string) error {
    for _, p := range paths {
        if err := processOne(p); err != nil {
            return err
        }
    }
    return nil
}

func processOne(p string) error {
    f, err := os.Open(p)
    if err != nil {
        return err
    }
    defer f.Close()
    return consume(f)
}
```

---

## 3. Database Resource Lifecycles

### Detection Rules

- **Unclosed `sql.Rows`:** Calling `db.Query` or `db.QueryContext` without deferring `rows.Close()` leaks database connection pool slots.
- **Missing `rows.Err()` Check:** After `for rows.Next()`, always verify `if err := rows.Err(); err != nil` to catch network disconnections or driver errors mid-iteration.

```go
// ❌ BAD: Connection pool slot leaks on early return; errors mid-scan missed
rows, err := db.QueryContext(ctx, "SELECT id FROM items")
if err != nil {
    return err
}
for rows.Next() {
    // missing defer rows.Close()!
}

// ✅ GOOD: Guaranteed cleanup and error verification
rows, err := db.QueryContext(ctx, "SELECT id FROM items")
if err != nil {
    return err
}
defer rows.Close()

for rows.Next() {
    if err := rows.Scan(&id); err != nil {
        return err
    }
}
if err := rows.Err(); err != nil {
    return err
}
```

---

## 4. Unbounded Memory Retention (Sub-slicing)

### Detection Rules

- Taking a small sub-slice from a massive slice or byte buffer (`header := hugeBuffer[0:8]`) retains the entire backing array in heap memory as long as `header` is referenced.
- Mitigate by allocating a small target slice and using `copy()`.

```go
// ❌ BAD: Retains entire 50MB buffer in memory for a 4-byte header
func GetPrefix(hugeData []byte) []byte {
    return hugeData[:4]
}

// ✅ GOOD: Explicit copy allows GC to reclaim hugeData
func GetPrefix(hugeData []byte) []byte {
    prefix := make([]byte, 4)
    copy(prefix, hugeData[:4])
    return prefix
}
```

---

## 5. String Building & Allocations

### Detection Rules

- Repeatedly concatenating strings (`s += item`) inside a loop reallocates and copies memory on every iteration ($O(n^2)$ complexity).
- Use `strings.Builder` with `Grow()` when size is predictable.

---

## False Positive Prevention Checklist

- [ ] Do NOT demand `sync.Pool` usage without benchmark evidence showing high GC pause times or heap allocation pressure.
- [ ] Do NOT flag `defer` in loops if the loop is statically bounded to a tiny fixed count (e.g., 2 or 3 attempts).
- [ ] Do NOT claim a performance regression unless an algorithmic complexity increase or excessive allocation path can be proven.
