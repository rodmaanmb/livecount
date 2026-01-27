//
//  InsightsEngineTests.swift
//  LIVECOUNT
//
//  Lightweight self-tests for rule-based insights
//

#if DEBUG

import Foundation

enum InsightsEngineTests {
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 Running InsightsEngine tests")
        print(String(repeating: "=", count: 60))
        
        testEntriesDeltaInsight()
        testPeakShiftInsight()
        testConcentrationInsight()
        
        print("\n✅ InsightsEngine tests passed")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    /// Delta vs previous period with division-by-zero guard
    private static func testEntriesDeltaInsight() {
        let ranges = makeSevenDayRanges()
        let currentSnapshot = makeSnapshot(totalIn: 110, totalOut: 0, peak: 12, timeRange: ranges.current)
        let previousSnapshot = makeSnapshot(totalIn: 100, totalOut: 0, peak: 10, timeRange: ranges.previous)
        
        // Distribution identical → only delta should qualify
        let currentEntries = makeDailyEntries(counts: [20, 20, 20, 20, 30], start: ranges.current.startDate)
        let previousEntries = makeDailyEntries(counts: [20, 20, 20, 20, 20], start: ranges.previous.startDate)
        
        let insights = InsightsEngine.generate(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot,
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            currentRange: ranges.current,
            previousRange: ranges.previous
        )
        
        guard let delta = insights.first(where: { $0.title.contains("Entrées en") }) else {
            assertionFailure("Expected delta insight")
            return
        }
        assert(delta.title.contains("+10,0%"), "Expected +10% delta, got \(delta.title)")
        
        // Baseline missing → insight omitted
        let missingBaseline = InsightsEngine.generate(
            currentSnapshot: currentSnapshot,
            previousSnapshot: makeSnapshot(totalIn: 0, totalOut: 0, peak: 0, timeRange: ranges.previous),
            currentEntries: currentEntries,
            previousEntries: [],
            currentRange: ranges.current,
            previousRange: ranges.previous
        )
        assert(missingBaseline.isEmpty, "Expected no insights when baseline is empty")
    }
    
    /// Peak bucket shift detection (earlier vs later)
    private static func testPeakShiftInsight() {
        let start = Date(timeIntervalSince1970: 0)
        let currentRange = TimeRange(type: .today, startDate: start, endDate: start.addingTimeInterval(4 * 3600))
        let previousRange = TimeRange(type: .today, startDate: start.addingTimeInterval(-4 * 3600), endDate: start)
        
        let currentSnapshot = makeSnapshot(totalIn: 8, totalOut: 0, peak: 5, timeRange: currentRange)
        let previousSnapshot = makeSnapshot(totalIn: 8, totalOut: 0, peak: 4, timeRange: previousRange)
        
        // Current peak late (hour 3), previous peak early (hour 1)
        let currentEntries = makeHourlyEntries(counts: [1, 1, 1, 5], start: currentRange.startDate)
        let previousEntries = makeHourlyEntries(counts: [4, 3, 1, 0], start: previousRange.startDate)
        
        let insights = InsightsEngine.generate(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot,
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            currentRange: currentRange,
            previousRange: previousRange
        )
        
        let peakInsight = insights.first(where: { $0.title.contains("Pic") })
        assert(peakInsight != nil, "Expected peak shift insight")
        assert(peakInsight?.title.contains("plus tard") == true, "Expected 'plus tard', got \(peakInsight?.title ?? "nil")")
    }
    
    /// Concentration rule: totals within ±5% and top quartile share +10 pts
    private static func testConcentrationInsight() {
        let ranges = makeSevenDayRanges()
        let currentSnapshot = makeSnapshot(totalIn: 102, totalOut: 0, peak: 60, timeRange: ranges.current)
        let previousSnapshot = makeSnapshot(totalIn: 100, totalOut: 0, peak: 25, timeRange: ranges.previous)
        
        // Current more concentrated on day 0; totals within ±5%
        let currentEntries = makeDailyEntries(counts: [60, 14, 14, 14], start: ranges.current.startDate)
        let previousEntries = makeDailyEntries(counts: [25, 25, 25, 25], start: ranges.previous.startDate)
        
        let insights = InsightsEngine.generate(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot,
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            currentRange: ranges.current,
            previousRange: ranges.previous
        )
        
        let concentration = insights.first(where: { $0.title.contains("concentré") })
        assert(concentration != nil, "Expected concentration insight when top quartile share increases")
    }
    
    // MARK: - Helpers
    
    private static func makeSnapshot(
        totalIn: Int,
        totalOut: Int,
        peak: Int,
        timeRange: TimeRange
    ) -> MetricsSnapshot {
        MetricsSnapshot(
            totalEntries: totalIn + totalOut,
            totalEntriesIn: totalIn,
            totalExits: totalOut,
            netChange: totalIn - totalOut,
            daysCovered: 1,
            avgEntriesPerDay: Double(totalIn),
            avgOccupancyPercent: 0,
            peakCount: peak,
            peakTimestamp: timeRange.startDate,
            timeRange: timeRange,
            locationId: "test-loc",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: timeRange.startDate,
                endTimestamp: timeRange.endDate,
                gaps: []
            )
        )
    }
    
    private static func makeHourlyEntries(counts: [Int], start: Date) -> [Entry] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var result: [Entry] = []
        
        for (hourOffset, count) in counts.enumerated() {
            guard count > 0 else { continue }
            for idx in 0..<count {
                let timestamp = calendar.date(byAdding: .minute, value: idx, to: start.addingTimeInterval(Double(hourOffset) * 3600)) ?? start
                result.append(makeEntry(at: timestamp))
            }
        }
        return result
    }
    
    private static func makeDailyEntries(counts: [Int], start: Date) -> [Entry] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var result: [Entry] = []
        
        for (dayOffset, count) in counts.enumerated() {
            guard count > 0 else { continue }
            for idx in 0..<count {
                let timestamp = calendar.date(byAdding: .minute, value: idx, to: start.addingTimeInterval(Double(dayOffset) * 86_400)) ?? start
                result.append(makeEntry(at: timestamp))
            }
        }
        return result
    }
    
    private static func makeEntry(at date: Date) -> Entry {
        Entry(
            id: UUID().uuidString,
            locationId: "test-loc",
            userId: nil,
            timestamp: date,
            type: .in,
            delta: 1,
            deviceId: "device",
            source: .simulated,
            sequenceNumber: nil
        )
    }
    
    private static func makeSevenDayRanges() -> (current: TimeRange, previous: TimeRange) {
        let start = Date(timeIntervalSince1970: 0)
        let current = TimeRange(
            type: .last7Days,
            startDate: start,
            endDate: start.addingTimeInterval(7 * 86_400)
        )
        let previous = TimeRange(
            type: .last7Days,
            startDate: start.addingTimeInterval(-7 * 86_400),
            endDate: start
        )
        return (current, previous)
    }
}

#endif
