---
description: Actionable code review checks for Go package structure, interface design idioms, global state, and API maintainability.
metadata:
  tags: [architecture, maintainability, interfaces, package-design, global-state, api-contracts]
---

# Architecture & Maintainability Review Checks

Review Go code for clean package boundaries, idiomatic interface segregation, avoidance of global state, and backward compatibility.

---

## 1. Interface Design Idioms

### Detection Rules

- **"Accept Interfaces, Return Concrete Types":** Functions and constructors should generally accept interfaces for flexibility (test mocks, pluggability) but return concrete structs so callers have access to full capabilities without unnecessary interface boxing.
- **Interface Pollution (Producer-side Interfaces):** Defining interfaces in the package implementing the service instead of letting consumers declare the narrow interfaces they need.
- **Large Interfaces:** Interfaces with dozens of methods violate the Interface Segregation Principle. Favor single-method interfaces (`io.Reader`, `io.Closer`) composed together.

```go
// ❌ BAD: Producer defines monolithic interface with unnecessary abstractions
package storage
type Storage interface {
    Save() error
    Load() error
    Delete() error
    List() error
    HealthCheck() error
}
func NewStorage() Storage { return &diskStorage{} }

// ✅ GOOD: Producer returns concrete struct; consumer defines focused interface
package storage
type DiskStorage struct { /* ... */ }
func NewDiskStorage() *DiskStorage { return &DiskStorage{} }

// In consumer package:
type Saver interface {
    Save() error
}
```

---

## 2. Global State & Mutable Singletons

### Detection Rules

- **Package-Level Mutable Variables:** Package-level variables (`var DefaultConfig = ...` or `var DB *sql.DB`) cause test contamination, race conditions when mutated concurrently, and make dependency injection difficult.
- **Overuse of `init()`:** `init()` functions should only be used for registration patterns (e.g. database drivers). Avoid network calls, complex configuration parsing, or logic that can panic during `init()`.

```go
// ❌ BAD: Mutable global state prone to race conditions and test interference
package service
var GlobalClient *http.Client

// ✅ GOOD: Explicit dependencies passed via constructor
package service
type Service struct {
    client *http.Client
}
func New(client *http.Client) *Service {
    return &Service{client: client}
}
```

---

## 3. Package Structure & Circular Dependencies

### Detection Rules

- **The "util" / "common" Anti-Pattern:** Dumping unrelated functions into `pkg/util` or `common` creates an architectural magnet for circular imports and obscures domain models.
- **Package Cyclical Workarounds:** Creating convoluted bridging packages solely to work around Go's compile-time cyclic import restrictions.

---

## 4. API Contract & Exported Stability

### Detection Rules

- **Exported Surface Modifications:** Renaming or removing exported functions, structs, or struct fields in non-internal packages breaks external consumers.
- **Unexported Struct Fields in Exported Structs:** Be intentional about whether struct fields are exported (for serialization/marshaling) or unexported (for encapsulation).

---

## 5. Effective Go Naming & Idioms

### Detection Rules:
- **Package Name Stuttering (Effective Go § Package names):** Exported symbols must not repeat the package name. Write `http.Client` (not `http.HttpClient`), `ring.New` (not `ring.NewRing`), and `json.Encoder` (not `json.JSONEncoder`).
- **Getter/Setter Conventions (Effective Go § Getters):** Go does not use `Get` in getter methods. Use `user.Owner()` instead of `user.GetOwner()`. Setter remains `user.SetOwner(...)`.
- **Interface Naming Conventions (Effective Go § Interface names):** One-method interfaces must be named with an `-er` suffix or agent noun (`Reader`, `Writer`, `Closer`, `Formatter`, `Scanner`).
- **Zero-Value Readiness (Effective Go § Allocation with new):** Design types so their zero-value state is safe and ready to use without explicit constructor calls where possible (e.g. `sync.Mutex` begins unlocked, `bytes.Buffer` begins ready to write).

```go
// ❌ BAD: Stuttering package names and unidiomatic getter
package cache
type CacheItem struct {} // Stutters: cache.CacheItem
func (c *Cache) GetTTL() time.Duration // Unidiomatic Get prefix

// ✅ GOOD: Clean Effective Go naming
package cache
type Item struct {} // Clean: cache.Item
func (c *Cache) TTL() time.Duration // Idiomatic getter
```

---

## False Positive Prevention Checklist

- [ ] Do NOT enforce interfaces if a concrete type has only one implementation and test mocking is not required.
- [ ] Do NOT flag `var ErrNotFound = errors.New(...)` as global state; sentinel errors are standard Go idioms when immutable.
- [ ] Do NOT demand Clean Architecture / Hexagonal boilerplate for small, single-purpose CLI utilities or scripts.
