//
//  ReportingEngineTests.swift
//  LIVECOUNT
//
//  TICKET 1: Tests for ReportingEngine + Format Helpers
//

#if DEBUG

import Foundation

enum ReportingEngineTests {
    
    /// Run all TICKET 1 tests
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 [TICKET 1 Tests] Running all tests...")
        print(String(repeating: "=", count: 60))
        
        testFormatHelpers_Int()
        testFormatHelpers_Double()
        testFormatHelpers_Date()
        testReportingSummary_NominalCase()
        testReportingSummary_EmptyData()
        testReportingSummary_LargeNumbers()
        testReportingDelta_NominalCase()
        testReportingDelta_DivisionByZero()
        testReportingStatus_Priority()
        
        print("\n" + String(repeating: "=", count: 60))
        print("✅ [TICKET 1 Tests] All tests passed!")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Format Helpers Tests
    
    static func testFormatHelpers_Int() {
        print("\n🧪 Test 1: Int formatting")
        
        // formatted()
        assert(1234.formatted() == "1,234", "Expected '1,234'")
        assert(0.formatted() == "0", "Expected '0'")
        assert(1234567.formatted() == "1,234,567", "Expected '1,234,567'")
        
        // formattedWithSign()
        assert(342.formattedWithSign() == "+342", "Expected '+342'")
        assert((-12).formattedWithSign() == "−12", "Expected '−12' (minus sign)")
        assert(0.formattedWithSign() == "0", "Expected '0' (not '+0')")
        
        // formattedDelta()
        assert(85.formattedDelta() == "↑ 85", "Expected '↑ 85'")
        assert((-12).formattedDelta() == "↓ 12", "Expected '↓ 12'")
        assert(0.formattedDelta() == "0", "Expected '0'")
        
        print("   ✅ Int formatting correct")
    }
    
    static func testFormatHelpers_Double() {
        print("\n🧪 Test 2: Double formatting")
        
        // formattedPercent()
        assert(0.723.formattedPercent(decimals: 1) == "72,3%", "Expected '72,3%'")
        assert(0.0.formattedPercent(decimals: 1) == "0,0%", "Expected '0,0%'")
        assert(1.0.formattedPercent(decimals: 1) == "100,0%", "Expected '100,0%'")
        
        // formattedPoints()
        let delta1 = 0.023.formattedPoints(decimals: 1)
        assert(delta1.contains("↑") && delta1.contains("2,3") && delta1.contains("pts"), "Expected '↑ 2,3 pts'")
        
        let delta2 = (-0.005).formattedPoints(decimals: 1)
        assert(delta2.contains("↓") && delta2.contains("0,5") && delta2.contains("pts"), "Expected '↓ 0,5 pts'")
        
        let delta3 = 0.0.formattedPoints(decimals: 1)
        assert(delta3.contains("0,0") && delta3.contains("pts"), "Expected '0,0 pts'")
        
        // formattedDecimal()
        assert(176.3.formattedDecimal(decimals: 1) == "176,3", "Expected '176,3'")
        assert(0.0.formattedDecimal(decimals: 1) == "0,0", "Expected '0,0'")
        
        print("   ✅ Double formatting correct")
    }
    
    static func testFormatHelpers_Date() {
        print("\n🧪 Test 3: Date formatting")
        
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 1, day: 14, hour: 22, minute: 15)
        let date = calendar.date(from: components)!
        
        // peakTimestamp: "14 janv · 22h15"
        let peakStr = date.formattedForReport(style: .peakTimestamp)
        assert(peakStr.contains("14") && peakStr.contains("janv") && peakStr.contains("22h15"), "Expected '14 janv · 22h15'")
        
        // coveragePeriod: "22:15"
        let coverageStr = date.formattedForReport(style: .coveragePeriod)
        assert(coverageStr == "22:15", "Expected '22:15'")
        
        // dayMonth: "14 janv"
        let dayMonthStr = date.formattedForReport(style: .dayMonth)
        assert(dayMonthStr.contains("14") && dayMonthStr.contains("janv"), "Expected '14 janv'")
        
        print("   ✅ Date formatting correct")
    }
    
    // MARK: - ReportingSummary Tests
    
    static func testReportingSummary_NominalCase() {
        print("\n🧪 Test 4: ReportingSummary nominal case")
        
        let now = Date()
        let timeRange = TimeRange(type: .last7Days, offsetDays: 0, referenceDate: now)
        
        let snapshot = MetricsSnapshot(
            totalEntries: 2456,
            totalEntriesIn: 1234,
            totalExits: 1222,
            netChange: 12,
            daysCovered: 7,
            avgEntriesPerDay: 176.3,
            avgOccupancyPercent: 0.723,
            peakCount: 95,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: now.addingTimeInterval(-3600),
                endTimestamp: now,
                gaps: []
            )
        )
        
        let summary = ReportingEngine.makeSummary(snapshot: snapshot, maxCapacity: 100)
        
        assert(summary.totalEntries == "1,234", "Expected '1,234'")
        assert(summary.avgOccupancyPercent == "72,3%", "Expected '72,3%'")
        assert(summary.peakOccupancy == "95", "Expected '95'")
        assert(summary.netChange == "+12", "Expected '+12'")
        assert(summary.status == .ok, "Expected .ok status")
        assert(summary.daysCovered == "7 jours", "Expected '7 jours'")
        assert(summary.avgEntriesPerDay == "176,3", "Expected '176,3'")
        
        print("   ✅ ReportingSummary nominal case correct")
    }
    
    static func testReportingSummary_EmptyData() {
        print("\n🧪 Test 5: ReportingSummary with empty data")
        
        let now = Date()
        let timeRange = TimeRange(type: .today, offsetDays: 0, referenceDate: now)
        
        let snapshot = MetricsSnapshot(
            totalEntries: 0,
            totalEntriesIn: 0,
            totalExits: 0,
            netChange: 0,
            daysCovered: 0,
            avgEntriesPerDay: 0,
            avgOccupancyPercent: 0.0,
            peakCount: 0,
            peakTimestamp: nil,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: nil,
                endTimestamp: nil,
                gaps: []
            )
        )
        
        let summary = ReportingEngine.makeSummary(snapshot: snapshot, maxCapacity: 100)
        
        assert(summary.totalEntries == "0", "Expected '0'")
        assert(summary.avgOccupancyPercent == "0,0%", "Expected '0,0%'")
        assert(summary.netChange == "0", "Expected '0' (not '+0')")
        assert(summary.peakTimestamp == nil, "Expected nil peak timestamp")
        assert(summary.status == .missing(reason: "Aucune donnée disponible"), "Expected .missing status")
        assert(summary.coveragePeriod == "Aucune donnée", "Expected 'Aucune donnée'")
        assert(summary.daysCovered == nil, "Expected nil daysCovered (mode Journée)")
        
        print("   ✅ ReportingSummary empty data correct")
    }
    
    static func testReportingSummary_LargeNumbers() {
        print("\n🧪 Test 6: ReportingSummary with large numbers")
        
        let now = Date()
        let timeRange = TimeRange(type: .year, offsetDays: 0, referenceDate: now)
        
        let snapshot = MetricsSnapshot(
            totalEntries: 2456789,
            totalEntriesIn: 1234567,
            totalExits: 1222222,
            netChange: 12345,
            daysCovered: 365,
            avgEntriesPerDay: 3382.4,
            avgOccupancyPercent: 0.82,
            peakCount: 150,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: now.addingTimeInterval(-86400 * 365),
                endTimestamp: now,
                gaps: []
            )
        )
        
        let summary = ReportingEngine.makeSummary(snapshot: snapshot, maxCapacity: 200)
        
        assert(summary.totalEntries == "1,234,567", "Expected '1,234,567'")
        assert(summary.totalEvents == "2,456,789", "Expected '2,456,789'")
        assert(summary.netChange == "+12,345", "Expected '+12,345'")
        
        print("   ✅ ReportingSummary large numbers correct")
    }
    
    // MARK: - ReportingDelta Tests
    
    static func testReportingDelta_NominalCase() {
        print("\n🧪 Test 7: ReportingDelta nominal case")
        
        let now = Date()
        let timeRange = TimeRange(type: .last7Days, offsetDays: 0, referenceDate: now)
        
        let currentSnapshot = MetricsSnapshot(
            totalEntries: 2456,
            totalEntriesIn: 1234,
            totalExits: 1222,
            netChange: 12,
            daysCovered: 7,
            avgEntriesPerDay: 176.3,
            avgOccupancyPercent: 0.75,
            peakCount: 95,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow()
        )
        
        let previousSnapshot = MetricsSnapshot(
            totalEntries: 2300,
            totalEntriesIn: 1149,
            totalExits: 1151,
            netChange: -2,
            daysCovered: 7,
            avgEntriesPerDay: 164.1,
            avgOccupancyPercent: 0.723,
            peakCount: 90,
            peakTimestamp: now.addingTimeInterval(-86400 * 7),
            timeRange: timeRange.previousPeriod(),
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow()
        )
        
        let comparison = MetricsComparison(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot
        )
        
        let delta = ReportingEngine.makeDelta(comparison: comparison)!
        
        assert(delta.isComparable, "Expected comparable")
        assert(delta.entriesDelta?.contains("↑") ?? false, "Expected ↑ for positive delta")
        assert(delta.entriesDelta?.contains("85") ?? false, "Expected 85")
        assert(delta.avgOccupancyDelta?.contains("pts") ?? false, "Expected 'pts'")
        assert(delta.peakCountDelta?.contains("↑") ?? false, "Expected ↑ for peak delta")
        
        print("   ✅ ReportingDelta nominal case correct")
    }
    
    static func testReportingDelta_DivisionByZero() {
        print("\n🧪 Test 8: ReportingDelta division by zero")
        
        let now = Date()
        let timeRange = TimeRange(type: .last7Days, offsetDays: 0, referenceDate: now)
        
        let currentSnapshot = MetricsSnapshot(
            totalEntries: 1234,
            totalEntriesIn: 1234,
            totalExits: 0,
            netChange: 1234,
            daysCovered: 7,
            avgEntriesPerDay: 176.3,
            avgOccupancyPercent: 0.75,
            peakCount: 95,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow()
        )
        
        // Previous period has 0 entries → division by zero
        let previousSnapshot = MetricsSnapshot(
            totalEntries: 0,
            totalEntriesIn: 0,
            totalExits: 0,
            netChange: 0,
            daysCovered: 0,
            avgEntriesPerDay: 0,
            avgOccupancyPercent: 0.0,
            peakCount: 0,
            peakTimestamp: nil,
            timeRange: timeRange.previousPeriod(),
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow()
        )
        
        let comparison = MetricsComparison(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot
        )
        
        let delta = ReportingEngine.makeDelta(comparison: comparison)!
        
        assert(!delta.isComparable, "Expected NOT comparable")
        assert(delta.entriesDelta == nil, "Expected nil entries delta")
        assert(delta.entriesPercentChange == nil, "Expected nil percent change (division by zero)")
        
        print("   ✅ ReportingDelta division by zero handled")
    }
    
    // MARK: - ReportingStatus Tests
    
    static func testReportingStatus_Priority() {
        print("\n🧪 Test 9: ReportingStatus priority")
        
        let now = Date()
        let timeRange = TimeRange(type: .today, offsetDays: 0, referenceDate: now)
        
        // Test 1: dataIssue (highest priority)
        let snapshotWithIssue = MetricsSnapshot(
            totalEntries: 100,
            totalEntriesIn: 50,
            totalExits: 50,
            netChange: 0,
            daysCovered: 1,
            avgEntriesPerDay: 50,
            avgOccupancyPercent: 0.5,
            peakCount: 50,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [
                DataIntegrityIssue(
                    type: .negativeCount,
                    severity: .critical,
                    message: "Test issue",
                    detectedAt: now
                )
            ],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: now,
                endTimestamp: now,
                gaps: []
            )
        )
        
        let statusIssue = ReportingEngine.computeStatus(snapshot: snapshotWithIssue)
        assert(statusIssue == .dataIssue(reason: "1 incohérence détectée"), "Expected .dataIssue")
        
        // Test 2: stale (gaps)
        let snapshotWithGaps = MetricsSnapshot(
            totalEntries: 100,
            totalEntriesIn: 50,
            totalExits: 50,
            netChange: 0,
            daysCovered: 1,
            avgEntriesPerDay: 50,
            avgOccupancyPercent: 0.5,
            peakCount: 50,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: now,
                endTimestamp: now,
                gaps: [DateInterval(start: now, end: now.addingTimeInterval(3600))]
            )
        )
        
        let statusStale = ReportingEngine.computeStatus(snapshot: snapshotWithGaps)
        assert(statusStale == .stale(reason: "1 trou de données"), "Expected .stale")
        
        // Test 3: missing (no data)
        let snapshotEmpty = MetricsSnapshot(
            totalEntries: 0,
            totalEntriesIn: 0,
            totalExits: 0,
            netChange: 0,
            daysCovered: 0,
            avgEntriesPerDay: 0,
            avgOccupancyPercent: 0.0,
            peakCount: 0,
            peakTimestamp: nil,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow()
        )
        
        let statusMissing = ReportingEngine.computeStatus(snapshot: snapshotEmpty)
        assert(statusMissing == .missing(reason: "Aucune donnée disponible"), "Expected .missing")
        
        // Test 4: ok
        let snapshotOk = MetricsSnapshot(
            totalEntries: 100,
            totalEntriesIn: 50,
            totalExits: 50,
            netChange: 0,
            daysCovered: 1,
            avgEntriesPerDay: 50,
            avgOccupancyPercent: 0.5,
            peakCount: 50,
            peakTimestamp: now,
            timeRange: timeRange,
            locationId: "test",
            dataIntegrityIssues: [],
            dataFlowSignals: [],
            coverageWindow: DataCoverageWindow(
                startTimestamp: now,
                endTimestamp: now,
                gaps: []
            )
        )
        
        let statusOk = ReportingEngine.computeStatus(snapshot: snapshotOk)
        assert(statusOk == .ok, "Expected .ok")
        
        print("   ✅ ReportingStatus priority correct")
    }
}

#endif
