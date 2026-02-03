//
//  HistoryViewModel.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation
import Observation

@Observable
final class HistoryViewModel {
    // MARK: - Properties
    
    var selectedRangeType: TimeRangeType = .today
    var isLoading: Bool = false
    var errorMessage: String?
    var rangeOffsetDays: Int = 0
    
    var currentSnapshot: MetricsSnapshot?
    var comparison: MetricsComparison?
    var insights: [Insight] = []
    
    /// Ticket 4: Delta vs période précédente (for ReportComparisonCard)
    var reportDelta: ReportingDelta? {
        guard let comparison else { return nil }
        return ReportingEngine.makeDelta(comparison: comparison)
    }
    
    var location: Location?
    
    // Visualization data
    struct EntryBucket: Identifiable, Equatable {
        let id = UUID()
        let order: Int
        let label: String
        let current: Int
        let previous: Int?
        let cumulative: Int
        
        static func == (lhs: EntryBucket, rhs: EntryBucket) -> Bool {
            lhs.order == rhs.order &&
            lhs.label == rhs.label &&
            lhs.current == rhs.current &&
            lhs.previous == rhs.previous &&
            lhs.cumulative == rhs.cumulative
        }
    }
    
    struct OccupancyBucket: Identifiable, Equatable {
        let id = UUID()
        let order: Int
        let label: String
        let currentPercent: Double
        let previousPercent: Double?
        
        static func == (lhs: OccupancyBucket, rhs: OccupancyBucket) -> Bool {
            lhs.order == rhs.order &&
            lhs.label == rhs.label &&
            lhs.currentPercent == rhs.currentPercent &&
            lhs.previousPercent == rhs.previousPercent
        }
    }
    
    var entryBuckets: [EntryBucket] = []
    var occupancyBuckets: [OccupancyBucket] = []
    var coverageText: String?
    var hasNegativeDrift: Bool = false
    
    // MARK: - Dependencies
    
    private let entryStore: EntryStore
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        location: Location? = nil,
        entryStore: EntryStore? = nil
    ) {
        self.location = location
        
        // Use provided store or create default FileEntryStore
        if let store = entryStore {
            self.entryStore = store
        } else {
            do {
                self.entryStore = try FileEntryStore()
            } catch {
                print("Warning: Failed to initialize FileEntryStore: \(error)")
                self.entryStore = NoOpEntryStore()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load metrics for the selected time range
    func loadMetrics() {
        // Cancel previous task if any
        loadTask?.cancel()
        
        loadTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            do {
                // Create time range from selected type with offset
                let timeRange = TimeRange.from(type: selectedRangeType, offsetDays: rangeOffsetDays)
                let comparisonRange = timeRange.previousPeriod()
                let chartPreviousRange = selectedRangeType == .today
                    ? timeRange.previousWeekSameWeekday()
                    : comparisonRange
                
                // #region agent log
                #if DEBUG
                let formatter = ISO8601DateFormatter()
                print("📊 [loadMetrics] TimeRange created: \(selectedRangeType.rawValue) offset=\(rangeOffsetDays)")
                print("   Range: \(formatter.string(from: timeRange.startDate)) → \(formatter.string(from: timeRange.endDate))")
                #endif
                // #endregion
                
                let locationId = location?.id ?? "default-location"
                let maxCapacity = location?.maxCapacity ?? 100
                
                // Warn if timezone mismatch
                if let locationTimezone = location?.timezone,
                   locationTimezone != TimeZone.current.identifier {
                    print("⚠️ Timezone mismatch: Location uses \(locationTimezone), current is \(TimeZone.current.identifier)")
                }
                
                // Fetch current period entries
                let currentEntries = try await entryStore.fetch(
                    timeRange: timeRange.interval,
                    locationId: locationId,
                    deviceId: nil
                )
                
                // #region agent log
                #if DEBUG
                print("📥 [loadMetrics] Fetched \(currentEntries.count) entries")
                if let first = currentEntries.first, let last = currentEntries.last {
                    let fmt = ISO8601DateFormatter()
                    print("   First: \(fmt.string(from: first.timestamp))")
                    print("   Last: \(fmt.string(from: last.timestamp))")
                }
                #endif
                // #endregion
                
                // Compute current snapshot
                let snapshot = MetricsCalculator.compute(
                    entries: currentEntries,
                    timeRange: timeRange,
                    maxCapacity: maxCapacity,
                    locationId: locationId
                )
                
                // Fetch previous period entries for comparison
                let previousEntries = try await entryStore.fetch(
                    timeRange: comparisonRange.interval,
                    locationId: locationId,
                    deviceId: nil
                )
                
                let previousChartEntries: [Entry]
                if selectedRangeType == .today {
                    previousChartEntries = try await entryStore.fetch(
                        timeRange: chartPreviousRange.interval,
                        locationId: locationId,
                        deviceId: nil
                    )
                } else {
                    previousChartEntries = previousEntries
                }
                
                // Compute comparison
                let comparisonResult = MetricsCalculator.computeComparison(
                    currentSnapshot: snapshot,
                    previousEntries: previousEntries,
                    previousRange: comparisonRange,
                    maxCapacity: maxCapacity
                )
                let previousSnapshot = comparisonResult?.previousSnapshot
                
                // Insights vs période précédente (rules-based)
                self.insights = InsightsEngine.generate(
                    currentSnapshot: snapshot,
                    previousSnapshot: previousSnapshot,
                    currentEntries: currentEntries,
                    previousEntries: previousEntries,
                    currentRange: timeRange,
                    previousRange: comparisonRange
                )
                
                // Derive visualization and quality indicators
                deriveVisualizationData(
                    entries: currentEntries,
                    previousEntries: previousEntries,
                    previousChartEntries: previousChartEntries,
                    timeRange: timeRange,
                    previousRange: comparisonRange,
                    previousChartRange: chartPreviousRange,
                    maxCapacity: maxCapacity
                )
                
                // Update state
                self.currentSnapshot = snapshot
                self.comparison = comparisonResult
                self.isLoading = false
                
                // #region agent log
                #if DEBUG
                print("✅ [loadMetrics] State updated: totalEntriesIn=\(snapshot.totalEntriesIn), buckets=\(self.entryBuckets.count)")
                #endif
                // #endregion
                
            } catch {
                self.errorMessage = "Erreur de chargement: \(error.localizedDescription)"
                self.insights = []
                self.isLoading = false
            }
        }
    }
    
    /// Change selected time range and reload
    func selectRange(_ type: TimeRangeType) {
        selectedRangeType = type
        loadMetrics()
    }
    
    // MARK: - Cleanup
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Export
    
    /// Build CSV export for the currently selected period (with offset)
    func exportCSV(location: Location?) async throws -> URL {
        let timeRange = TimeRange.from(type: selectedRangeType, offsetDays: rangeOffsetDays)
        let locationId = location?.id ?? "default-location"
        let maxCapacity = location?.maxCapacity ?? 100
        
        let entries = try await entryStore.fetch(
            timeRange: timeRange.interval,
            locationId: locationId,
            deviceId: nil
        )
        
        let snapshot = MetricsCalculator.compute(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: maxCapacity,
            locationId: locationId
        )
        
        return try CSVReportBuilder.build(
            snapshot: snapshot,
            entries: entries,
            timeRange: timeRange,
            location: location
        )
    }

    // MARK: - Navigation
    
    func shiftRange(by step: Int) {
        let delta: Int
        switch selectedRangeType {
        case .today:
            delta = step
        case .last7Days:
            delta = step * 7
        case .last30Days:
            delta = step * 30
        case .year:
            delta = step * 365
        }
        
        // Prevent going in the future
        if rangeOffsetDays + delta > 0 {
            return
        }
        
        rangeOffsetDays += delta
        
        #if DEBUG
        print("🔄 [shiftRange] \(selectedRangeType.rawValue) step=\(step) → newOffset=\(rangeOffsetDays)")
        #endif
        
        loadMetrics()
    }
    
    var canShiftForward: Bool {
        rangeOffsetDays < 0
    }
    
    /// TICKET 2: ReportingSummary pour affichage unifié
    var reportSummary: ReportingSummary? {
        guard let snapshot = currentSnapshot else { return nil }
        return ReportingEngine.makeSummary(
            snapshot: snapshot,
            maxCapacity: location?.maxCapacity ?? 100
        )
    }
    
    // MARK: - Derived data for charts & quality
    
    private func deriveVisualizationData(
        entries: [Entry],
        previousEntries: [Entry],
        previousChartEntries: [Entry],
        timeRange: TimeRange,
        previousRange: TimeRange,
        previousChartRange: TimeRange,
        maxCapacity: Int
    ) {
        guard !entries.isEmpty else {
            entryBuckets = []
            occupancyBuckets = []
            coverageText = nil
            hasNegativeDrift = false
            return
        }
        
        let granularity = bucketGranularity(for: timeRange.type)
        let bucketStarts = generateBucketStarts(for: timeRange.interval, granularity: granularity)
        let previousBucketStarts = generateBucketStarts(for: previousRange.interval, granularity: granularity)
        let previousChartBucketStarts = generateBucketStarts(for: previousChartRange.interval, granularity: granularity)
        
        let currentAgg = aggregateBuckets(
            entries: entries,
            bucketStarts: bucketStarts,
            granularity: granularity,
            maxCapacity: maxCapacity
        )
        
        let previousAgg = aggregateBuckets(
            entries: previousEntries,
            bucketStarts: previousBucketStarts,
            granularity: granularity,
            maxCapacity: maxCapacity
        )
        
        let previousChartAgg = aggregateBuckets(
            entries: previousChartEntries,
            bucketStarts: previousChartBucketStarts,
            granularity: granularity,
            maxCapacity: maxCapacity
        )
        
        let count = currentAgg.count
        var entryResult: [EntryBucket] = []
        var occupancyResult: [OccupancyBucket] = []
        hasNegativeDrift = currentAgg.contains { $0.negativeDrift }
        
        for index in 0..<count {
            let current = currentAgg[index]
            let previous = index < previousAgg.count ? previousAgg[index] : nil
            let previousChart = index < previousChartAgg.count ? previousChartAgg[index] : nil
            
            entryResult.append(
                EntryBucket(
                    order: index,
                    label: current.label,
                    current: current.inCount,
                    previous: previousChart?.inCount,
                    cumulative: current.cumulativeIn
                )
            )
            
            occupancyResult.append(
                OccupancyBucket(
                    order: index,
                    label: current.label,
                    currentPercent: current.occupancyPercent,
                    previousPercent: previous?.occupancyPercent
                )
            )
        }
        
        entryBuckets = entryResult
        occupancyBuckets = occupancyResult
        
        if let first = entries.min(by: { $0.timestamp < $1.timestamp })?.timestamp,
           let last = entries.max(by: { $0.timestamp < $1.timestamp })?.timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.timeZone = TimeZone.current
            coverageText = "\(formatter.string(from: first)) → \(formatter.string(from: last))"
        } else {
            coverageText = nil
        }
    }
    
    private enum BucketGranularity {
        case hour, day, month
    }
    
    private struct BucketAggregate {
        let label: String
        let inCount: Int
        let cumulativeIn: Int
        let occupancyPercent: Double
        let negativeDrift: Bool
    }
    
    private func bucketGranularity(for type: TimeRangeType) -> BucketGranularity {
        switch type {
        case .today:
            return .hour
        case .last7Days, .last30Days:
            return .day
        case .year:
            return .month
        }
    }
    
    private func generateBucketStarts(for interval: DateInterval, granularity: BucketGranularity) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var dates: [Date] = []
        
        switch granularity {
        case .hour:
            let start = calendar.dateInterval(of: .hour, for: interval.start)?.start ?? interval.start
            var current = start
            while current <= interval.end {
                dates.append(current)
                guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
                current = next
            }
        case .day:
            let start = calendar.startOfDay(for: interval.start)
            var current = start
            while current <= interval.end {
                dates.append(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: interval.start)
            let start = calendar.date(from: comps) ?? interval.start
            var current = start
            while current <= interval.end {
                dates.append(current)
                guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
                current = next
            }
        }
        
        return dates
    }
    
    private func aggregateBuckets(
        entries: [Entry],
        bucketStarts: [Date],
        granularity: BucketGranularity,
        maxCapacity: Int
    ) -> [BucketAggregate] {
        guard !bucketStarts.isEmpty else { return [] }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        var index = 0
        var runningCumulative = 0
        var occupancy = 0
        var results: [BucketAggregate] = []
        
        for i in 0..<bucketStarts.count {
            let start = bucketStarts[i]
            let end: Date
            switch granularity {
            case .hour:
                end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            case .day:
                end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            case .month:
                end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            }
            
            var inCount = 0
            var deltaSum = 0
            while index < sorted.count && sorted[index].timestamp < end {
                let entry = sorted[index]
                if entry.type == .in { inCount += 1 }
                deltaSum += entry.delta
                index += 1
            }
            
            runningCumulative += inCount
            let nextOccupancy = occupancy + deltaSum
            let clamped = max(0, min(nextOccupancy, maxCapacity))
            let negativeDrift = nextOccupancy < 0
            occupancy = clamped
            
            let label: String
            switch granularity {
            case .hour:
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "fr_FR")
                formatter.dateFormat = "HH'h'"
                formatter.timeZone = TimeZone.current
                label = formatter.string(from: start)
            case .day:
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "fr_FR")
                formatter.dateFormat = "dd/MM"
                formatter.timeZone = TimeZone.current
                label = formatter.string(from: start)
            case .month:
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "fr_FR")
                formatter.dateFormat = "MM/yy"
                formatter.timeZone = TimeZone.current
                label = formatter.string(from: start)
            }
            
            let occupancyPercent = max(0.0, min(Double(occupancy) / Double(maxCapacity) * 100.0, 100.0))
            
            results.append(
                BucketAggregate(
                    label: label,
                    inCount: inCount,
                    cumulativeIn: runningCumulative,
                    occupancyPercent: occupancyPercent,
                    negativeDrift: negativeDrift
                )
            )
        }
        
        return results
    }
}
