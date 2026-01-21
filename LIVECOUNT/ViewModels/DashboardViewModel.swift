//
//  DashboardViewModel.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation
import Observation

@Observable
final class DashboardViewModel {
    // MARK: - Properties
    
    var currentCount: Int = 0
    var status: OccupancyStatus = .ok
    var lastEventAt: Date?
    var maxCapacity: Int = 100
    
    // Dashboard LIVE fields
    var occupancyPercent: Double = 0.0
    var remainingSpots: Int = 0
    var entriesLastXMin: Int = 0
    var exitsLastXMin: Int = 0
    var netLastXMin: Int = 0
    
    // Period selection (single source of truth)
    var selectedPeriod: TimeRangeType = .today

    // MARK: - Today Chart Data (Entries/hour + Cumulative entries)
    struct HourlyEntryBucket: Identifiable {
        let id: Int
        let date: Date
        let hour: Int
        let entries: Int
        let cumulative: Int
    }

    var isTodayChartLoading: Bool = false
    var todayChartBuckets: [HourlyEntryBucket] = []
    var todayCoverageHint: String?
    
    var location: Location?
    var user: User?
    
    // MARK: - Dependencies
    
    private let eventSource: MockEventSource
    private let aggregator: LiveAggregator
    private let entryStore: EntryStore
    private var pipelineTask: Task<Void, Never>?
    private var todayEntries: [Entry] = []
    
    // MARK: - Computed Properties
    
    var occupancyPercentage: Double {
        occupancyPercent * 100
    }
    
    /// Freshness in seconds since last event
    var freshnessSeconds: Int? {
        guard let lastEventAt = lastEventAt else { return nil }
        return Int(Date().timeIntervalSince(lastEventAt))
    }
    
    /// Formatted Live status: "Live • 54s" or "Stale • 2m 34s"
    var liveStatusText: String {
        guard let freshness = freshnessSeconds else { return "En attente..." }
        
        if freshness < 30 {
            return "Live • \(freshness)s"
        } else if freshness < 60 {
            return "Stale • \(freshness)s"
        } else {
            let minutes = freshness / 60
            let seconds = freshness % 60
            return "Stale • \(minutes)m \(seconds)s"
        }
    }
    
    /// True if data is fresh (< 30 seconds)
    var isLive: Bool {
        guard let freshness = freshnessSeconds else { return false }
        return freshness < 30
    }
    
    var canDecrement: Bool {
        currentCount > 0
    }
    
    var isAdmin: Bool {
        user?.role == .admin
    }
    
    /// Dynamic subtitle showing the selected period with date range
    var periodSubtitle: String {
        let timeRange = TimeRange.from(type: selectedPeriod)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        
        switch selectedPeriod {
        case .today:
            // "Aujourd'hui · 17 jan 2026"
            formatter.dateFormat = "d MMM yyyy"
            return "Aujourd'hui · \(formatter.string(from: Date()))"
            
        case .last7Days:
            // "7 derniers jours · 11–17 jan"
            formatter.dateFormat = "d"
            let startDay = formatter.string(from: timeRange.interval.start)
            formatter.dateFormat = "d MMM"
            let endFormatted = formatter.string(from: timeRange.interval.end)
            return "7 derniers jours · \(startDay)–\(endFormatted)"
            
        case .last30Days:
            // "30 derniers jours · 18 déc–17 jan"
            formatter.dateFormat = "d MMM"
            let startFormatted = formatter.string(from: timeRange.interval.start)
            let endFormatted = formatter.string(from: timeRange.interval.end)
            return "30 derniers jours · \(startFormatted)–\(endFormatted)"
            
        case .year:
            // "Année · 18 jan 2025–17 jan 2026"
            formatter.dateFormat = "d MMM yyyy"
            let startFormatted = formatter.string(from: timeRange.interval.start)
            formatter.dateFormat = "d MMM yyyy"
            let endFormatted = formatter.string(from: timeRange.interval.end)
            return "Année · \(startFormatted)–\(endFormatted)"
        }
    }
    
    // MARK: - Initialization
    
    init(
        location: Location? = nil,
        user: User? = nil,
        eventSource: MockEventSource = MockEventSource(),
        entryStore: EntryStore? = nil,
        maxCapacity: Int = 100
    ) {
        let resolvedMaxCapacity = location?.maxCapacity ?? maxCapacity

        self.location = location
        self.user = user
        self.eventSource = eventSource
        self.maxCapacity = resolvedMaxCapacity
        self.aggregator = LiveAggregator(eventStream: eventSource, maxCapacity: resolvedMaxCapacity)
        
        // Use provided store or create default FileEntryStore
        if let store = entryStore {
            self.entryStore = store
        } else {
            // Create FileEntryStore with error handling
            do {
                self.entryStore = try FileEntryStore()
            } catch {
                print("Warning: Failed to initialize FileEntryStore: \(error)")
                // Fallback to a no-op store to keep app functional
                self.entryStore = NoOpEntryStore()
            }
        }

        startPipeline()
    }

    
    // MARK: - Public Methods
    
    func increment() {
        emitEvent(delta: 1, type: .in)
    }
    
    func decrement() {
        guard canDecrement || isAdmin else { return }
        emitEvent(delta: -1, type: .out)
    }
    
    // MARK: - Private Methods
    
    /// Start the live data pipeline with rehydration from persisted entries
    private func startPipeline() {
        pipelineTask = Task { @MainActor in
            // REHYDRATION: Load today's entries from storage
            let initialEntries = await loadTodaysEntries()

            // Keep in-memory list for charting
            todayEntries = initialEntries
            recomputeTodayChartData()
            
            // Start aggregation with initial entries (replay)
            for await state in aggregator.aggregatedState(initialEntries: initialEntries) {
                self.currentCount = state.currentCount
                self.status = state.status
                self.lastEventAt = state.lastEventAt
                self.occupancyPercent = state.occupancyPercent
                self.remainingSpots = state.remainingSpots
                self.entriesLastXMin = state.entriesLastXMin
                self.exitsLastXMin = state.exitsLastXMin
                self.netLastXMin = state.netLastXMin
            }
        }
    }
    
    /// Load today's entries from storage for rehydration
    private func loadTodaysEntries() async -> [Entry] {
        isTodayChartLoading = true
        defer { isTodayChartLoading = false }

        print("\n" + String(repeating: "=", count: 60))
        print("🔄 [REHYDRATION] Starting app launch rehydration...")
        print(String(repeating: "=", count: 60))
        
        do {
            // Log storage directory
            logStorageDirectory()
            
            // Debug dump: show all files in storage
            if let store = entryStore as? FileEntryStore {
                await store.debugDumpStore()
            }
            
            // Get today's date range (start of day to now)
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let now = Date()
            let timeRange = DateInterval(start: startOfToday, end: now)
            
            let locationId = location?.id ?? "default-location"
            
            // Format dates for display (local timezone)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            dateFormatter.timeZone = TimeZone.current
            
            print("\n🔎 [REHYDRATION] Query parameters:")
            print("   • Start of today: \(dateFormatter.string(from: startOfToday))")
            print("   • Now: \(dateFormatter.string(from: now))")
            print("   • Timezone: \(TimeZone.current.identifier)")
            print("   • LocationId: \(locationId)")
            print("   • DeviceId: nil (no filter)")
            
            // Fetch entries for today with same locationId
            let entries = try await entryStore.fetch(
                timeRange: timeRange,
                locationId: locationId,
                deviceId: nil
            )
            
            // Log rehydration result
            print("\n✅ [REHYDRATION] Completed: Loaded \(entries.count) entries from disk")
            if !entries.isEmpty {
                print("   First entry: \(entries.first!.timestamp)")
                print("   Last entry: \(entries.last!.timestamp)")
            }
            print(String(repeating: "=", count: 60) + "\n")
            
            todayEntries = entries
            recomputeTodayChartData()
            return entries
        } catch {
            print("\n❌ [REHYDRATION] Failed: \(error)")
            print(String(repeating: "=", count: 60) + "\n")
            todayEntries = []
            recomputeTodayChartData()
            return []
        }
    }
    
    /// Log storage directory info for debugging
    private func logStorageDirectory() {
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let storageDir = appSupport.appendingPathComponent("EntryStore")
            print("\n📁 [STORAGE] Directory:")
            print("   Path: \(storageDir.path)")
            
            // List files in directory
            if let files = try? FileManager.default.contentsOfDirectory(atPath: storageDir.path) {
                print("   Files in directory: \(files.count)")
                for file in files.sorted() {
                    let filePath = storageDir.appendingPathComponent(file).path
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? UInt64 {
                        print("      • \(file): \(size) bytes")
                    } else {
                        print("      • \(file)")
                    }
                }
            } else {
                print("   ⚠️ Could not list files in directory")
            }
        }
    }
    
    /// Emit an event into the stream and persist it
    private func emitEvent(delta: Int, type: EntryType) {
        let entry = Entry(
            id: UUID().uuidString,
            locationId: location?.id ?? "default-location",
            userId: user?.id,
            timestamp: Date(),
            type: type,
            delta: delta,
            deviceId: "manual-device",
            source: .manual,
            sequenceNumber: nil
        )
        
        // Emit to live pipeline (always succeeds)
        eventSource.emit(entry)

        // Update in-memory list for charting
        todayEntries.append(entry)
        recomputeTodayChartData()
        
        // Persist to storage (non-fatal if fails)
        Task {
            do {
                try await entryStore.append(entry)
            } catch {
                print("Warning: Failed to persist entry: \(error)")
                // Continue without blocking UI
            }
        }
    }
    
    deinit {
        pipelineTask?.cancel()
    }

    // MARK: - Today Chart Data Derivation

    private func recomputeTodayChartData() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)

        // Bucket entries (entries only, ignore exits)
        var hourlyEntries = Array(repeating: 0, count: currentHour + 1)
        let entryEvents = todayEntries.filter { $0.delta > 0 }

        for entry in entryEvents {
            let entryDayStart = calendar.startOfDay(for: entry.timestamp)
            guard entryDayStart == startOfDay else { continue }

            let hour = calendar.component(.hour, from: entry.timestamp)
            if hour >= 0, hour <= currentHour {
                hourlyEntries[hour] += max(0, entry.delta)
            }
        }

        var buckets: [HourlyEntryBucket] = []
        var running = 0

        for hour in 0...currentHour {
            running += hourlyEntries[hour]
            if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                buckets.append(
                    HourlyEntryBucket(
                        id: hour,
                        date: hourDate,
                        hour: hour,
                        entries: hourlyEntries[hour],
                        cumulative: running
                    )
                )
            }
        }

        todayChartBuckets = buckets

        // Coverage hint
        if let first = entryEvents.min(by: { $0.timestamp < $1.timestamp }),
           let last = entryEvents.max(by: { $0.timestamp < $1.timestamp }) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "HH:mm"
            todayCoverageHint = "Couverture: \(formatter.string(from: first.timestamp))–\(formatter.string(from: last.timestamp))"
        } else {
            todayCoverageHint = nil
        }
    }
}
