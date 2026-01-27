# 📘 LifeCount — Product Requirements Document (AI Context v3)

## 0. Context & Role

**Role**  
You are an expert **Senior iOS Engineer** acting as the **Lead Architect** for the LifeCount project.

**Input**  
This PRD is the **single source of truth**.

**Goal**  
Generate **production-ready, clean, scalable SwiftUI code** with a coherent architecture and reliable data flow.

**Strict Constraints**
- Do **not hallucinate features** not listed here.
- If a requirement is ambiguous, **ask for clarification** before implementing.
- **Core product truth:** LifeCount is **not** a clicker app. It is an **observability + synchronization + analytics** app fed by **external hardware events**.

---

## 1. Product Definition (Source of Truth & Responsibilities)

### What LifeCount is
LifeCount is an iOS application that **ingests timestamped +1 / -1 events emitted by an external counter device**, stores them in a backend as the **single source of truth**, and provides:
- a **LIVE dashboard** (status, occupancy, freshness),
- an **history/overview** (aggregations, trends),
- **KPIs and anomaly flags** derived from the event stream.

### What LifeCount is NOT
- Not a “manual counting” application as the primary workflow.
- Not a hardware-testing lab for click accuracy (double-clicks happen; not the problem being solved).
- Not a heavy BI/reporting suite in v1.

### Responsibility split
- **Hardware device:** event emitter only (produces +1/-1 signals with metadata).
- **Backend (Firestore):** **single source of truth**, stores events and derived state.
- **App:** observes live state, renders dashboard, computes/lightly aggregates KPIs (v1), provides admin controls.

---

## 2. Tech Stack & Architecture

### Core Technologies
- **Language:** Swift 5.10+
- **Framework:** SwiftUI
- **Minimum OS:** iOS 17.0+
- **Architecture:** MVVM using the **Observation Framework** (`@Observable`)
- **Dependency Injection:** Lightweight Container or Factory pattern (no third-party libraries)

### Backend (Firebase)
- **Authentication:** Firebase Auth (Anonymous + Email/Link)
- **Database:** Firestore (NoSQL)
- **Realtime Updates:** Firestore listeners
- **Concurrency:** Swift Concurrency (`async / await`)

### Architecture Rules
- **Views:** Dumb UI, render ViewModel state only
- **ViewModels:** Business logic + state mapping, marked with `@Observable`
- **Services:** Firestore access, device ingestion adapters, aggregation logic
- **Models:** Immutable `struct`, `Codable` + `Identifiable`

---

## 3. External Counter Integration (Core Requirement)

### Connectivity
- **Primary transport:** Wi-Fi (exact protocol may vary: REST/HTTP, WebSocket, MQTT, or device → cloud push).  
  If ambiguous, ask and implement an abstraction that supports multiple transports.

### Event mode
- **Realtime mode:** device emits events as they happen.
- **Batch fallback:** in case of lost connectivity, events are buffered and sent later.

### Payload (minimum)
Each emitted event MUST be representable as:
- `delta` (+1 or -1)
- `timestamp`
- `deviceId`
- `locationId`

Optional but recommended if supported by hardware:
- `sequenceNumber` (monotonic per device) to help detect missing events

### Authority & reconciliation
- The hardware is **not** authoritative; it only emits events.
- The **backend event history** is authoritative.
- The **live counter** shown in the app is derived from backend state (either:
  - aggregated server-side into `CounterState`, or
  - computed from `Entry` stream in v1 for a single operational day).

### Multi-device / multi-location
- **Default:** one device per location.
- **Designed to support:** multiple devices per account across different locations; each device acts as an independent event source.

---

## 4. Data Model (Schema Definition)

**Naming conventions and structures below must be used.**  
If Firestore schema needs adjustment, ask before changing the model names.

```swift
// MARK: - Core Models

struct User: Identifiable, Codable {
    let id: String                 // Firebase Auth UID
    let email: String?
    let role: UserRole             // .admin, .viewer
    let createdAt: Date
}

struct Location: Identifiable, Codable {
    let id: String
    var name: String
    var maxCapacity: Int
    var timezone: String           // IANA identifier
}

/// Represents the live aggregate state (stored in Firestore)
struct CounterState: Codable {
    var currentCount: Int
    var lastUpdated: Date          // last time aggregate changed
    var status: OccupancyStatus    // derived from currentCount vs maxCapacity
    var lastEventAt: Date?         // timestamp of last ingested event
}

/// Atomic event (source of truth for KPI and reconstruction)
struct Entry: Identifiable, Codable {
    let id: String
    let locationId: String
    let userId: String?            // null/absent for hardware-origin events if desired
    let timestamp: Date
    let type: EntryType            // .in (+1), .out (-1)
    let delta: Int                 // +1 or -1 (must match type)
    let deviceId: String
    let source: EventSource        // .hardware, .manual, .import
    let sequenceNumber: Int?       // optional, if hardware provides it
}

/// Hardware device metadata (enables "Live • Xs" and health checks)
struct Device: Identifiable, Codable {
    let id: String                 // deviceId
    let locationId: String
    var name: String
    var lastSeenAt: Date?          // last heartbeat or last event received
    var isActive: Bool
}

// MARK: - Enums

enum OccupancyStatus: String, Codable {
    case ok       // 0% - 79%
    case warning  // 80% - 99%
    case full     // 100%+
}

enum EntryType: String, Codable {
    case `in`
    case out
}

enum EventSource: String, Codable {
    case hardware
    case manual      // fallback / admin override / test
    case `import`
}

enum UserRole: String, Codable {
    case admin
    case viewer
}
```

---

## 5. Folder Structure (Project Layout)

Generated files must follow this structure:

```text
LifeCount/
├── App/
│   ├── LifeCountApp.swift
│   └── DependencyContainer.swift
├── Models/
│   ├── User.swift
│   ├── UserRole.swift
│   ├── Location.swift
│   ├── Device.swift
│   ├── CounterState.swift
│   ├── Entry.swift
│   ├── EntryType.swift
│   ├── EventSource.swift
│   └── OccupancyStatus.swift
├── Services/
│   ├── AuthService.swift
│   ├── CounterService.swift          // Firestore listeners + writes (admin/manual)
│   ├── DeviceIngestionService.swift  // abstraction for receiving hardware events (v1 stub ok)
│   └── AnalyticsService.swift        // local aggregation & KPI computation
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── HistoryViewModel.swift
│   └── AdminViewModel.swift
├── Views/
│   ├── Dashboard/
│   ├── History/
│   └── Admin/
├── Utils/
│   ├── Extensions/
│   └── Constants.swift
└── Resources/
    └── Assets.xcassets
```

---

## 6. Feature Specifications (v1)

### A) Dashboard LIVE (Primary)

**Purpose:** show the operational truth at a glance: occupancy, status, freshness, KPIs.

**Must display**
- `currentCount` (large, primary)
- `maxCapacity`
- occupancy percentage `currentCount / maxCapacity`
- remaining places `maxCapacity - currentCount` (min 0)
- status indicator: `ok / warning / full`
- **freshness indicator:** `Live • Xs` derived from `lastEventAt` or `Device.lastSeenAt`

**Visual feedback**
- semantic color based on `OccupancyStatus` (green/orange/red)
- keep UI minimal and readable

**Interactions**
- By default, the dashboard is **read-first** (observability).
- **Manual +/− controls exist only as fallback/test/admin override.**
  - If shown to non-admins, they should be disabled or hidden based on role.

**Haptics**
- Mandatory haptic feedback on manual actions:
  - Light for normal
  - Heavy for error/limit conditions

**Business rules**
- `currentCount` cannot be < 0
- if `currentCount >= maxCapacity`, status is `.full`
- if occupancy >= 80% and < 100% => `.warning`
- admin may override (manual) even if full (configurable)
- device/hardware events are accepted as emitted; app does not attempt to “fix” double clicks.

---

### B) History / Overview (Primary)

**Purpose:** exploit event history to understand flow patterns and anomalies.

**Must include**
- time-range selection for a location:
  - today (operational day), last 7 days (minimum)
- aggregated KPIs computed from `Entry` stream:
  - Total Entries (in)
  - Total Exits (out)
  - Net change
  - Peak hour (hour block with max entries)
  - Average occupancy (simple approximation allowed in v1)
- basic visual trend chart(s) (Swift Charts if available; otherwise simple lists)
- data freshness / quality indicators:
  - missing data windows (if `lastSeenAt` is old)
  - overcrowding flag

**Anomaly detection (simple)**
- Overcrowding: `currentCount > maxCapacity * 1.1` => flag “Overcrowding”
- Stale device: if `now - lastSeenAt` > threshold => flag “Device offline / stale”

---

### C) Admin (Primary for operators)

**Purpose:** configuration + governance.

**Must include**
- edit `maxCapacity`
- view current user role / id
- list devices (per location) with lastSeenAt (simple list)
- “End Day” / reset (Admin only):
  - archives snapshot and resets counter to 0
  - preserves event history (do not delete events)

**Manual override mode**
- Admin can create manual entries (`EventSource.manual`) to correct the live count if needed.
- Non-admins should not be able to override.

---

## 7. UI / UX Guidelines

- System font (San Francisco)
- SwiftUI native components (List, Button, Label)
- Semantic colors:
  - `.green` (ok)
  - `.orange` (warning)
  - `.red` (full / critical)
- Priorities:
  1) readability
  2) speed of comprehension
  3) aesthetics

---

## 8. Coding Standards

- No `Any`
- Proper error handling in Services (`do/catch`) with user-friendly surfaced errors
- Mandatory `#Preview` with mock data for each View
- Keep views modular (split into subviews when large)
- Comments only for non-trivial business logic (use `///`)

---

## 9. Implementation Roadmap (Step-by-Step)

When asked to “Start Project”, follow this order:

1. **Setup**
   - Xcode project + SwiftUI app
   - Firebase SDK integration
   - Auth (Anonymous first)

2. **Models**
   - Implement models exactly as specified (User, Location, Device, CounterState, Entry, enums)

3. **Services**
   - `AuthService`: anonymous sign-in
   - `CounterService`: Firestore read/write + listeners for `CounterState` and `Entry`
   - `AnalyticsService`: local KPI aggregation from `Entry`
   - `DeviceIngestionService`: create an abstraction/stub; implement Firestore-based ingestion first (hardware → backend → app)

4. **MVVM**
   - DashboardViewModel reads live `CounterState` + device freshness
   - HistoryViewModel queries entries and computes KPIs
   - AdminViewModel for capacity, devices, resets, manual overrides

5. **UI**
   - Dashboard LIVE (read-first, manual override gated)
   - History/Overview
   - Admin

6. **Refinement**
   - Haptics
   - Edge cases: stale device, empty history, reset flows
   - Ensure everything compiles and runs clean

---

## ✅ End of PRD (AI Context v3)
