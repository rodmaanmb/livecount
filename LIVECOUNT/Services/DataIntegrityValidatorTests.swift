//
//  DataIntegrityValidatorTests.swift
//  LIVECOUNT
//
//  Tests for P0.1 Data Integrity
//

import Foundation

#if DEBUG

/// Self-tests for DataIntegrityValidator (run in-app for development)
enum DataIntegrityValidatorTests {
    
    // MARK: - Test Runner
    
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 Running DataIntegrityValidator Tests")
        print(String(repeating: "=", count: 60))
        
        testNoIssues()
        testNegativeCount()
        testGapDetection()
        testCoverageWindow()
        testStaleSource()
        
        // New tests for gap classification thresholds
        testGapsBelowDisplayThresholdAreIgnored()
        testGaps20to59MinutesDisplayedButNotFlagged()
        testGaps60to180MinutesFlaggedAsWarning()
        testGapsOver3HoursFlaggedAsCritical()
        testGapsOver6HoursClassifiedAsInactivity()
        
        print("\n✅ All DataIntegrityValidator tests passed!")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Test Cases
    
    /// Test 1: No issues with valid data
    static func testNoIssues() {
        print("\n📋 Test 1: No issues with valid data")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 5), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 10), delta: -1),
            makeEntry(timestamp: date(hour: 10, minute: 15), delta: 1)
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 10, minute: 30)
        )
        
        let issues = DataIntegrityValidator.validate(
            entries: entries,
            timeRange: timeRange
        )
        
        assert(issues.isEmpty, "Expected no issues, got \(issues.count)")
        print("   ✓ No issues detected as expected")
    }
    
    /// Test 2: Detect negative count (more exits than entries)
    static func testNegativeCount() {
        print("\n📋 Test 2: Detect negative count")
        
        // Small negative drift should NOT trigger a hard issue (noise)
        let smallNegative = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 5), delta: -1),
            makeEntry(timestamp: date(hour: 10, minute: 10), delta: -1)
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 10, minute: 30)
        )
        
        let issuesNoise = DataIntegrityValidator.validate(
            entries: smallNegative,
            timeRange: timeRange
        )
        
        assert(issuesNoise.isEmpty, "Expected NO hard issues for small negative drift, got \(issuesNoise.count)")
        print("   ✓ Small negative drift ignored as expected")
        
        // Large negative should trigger a hard issue
        let largeNegative = [
            makeEntry(timestamp: date(hour: 11, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 11, minute: 5), delta: -6)  // count = -5 → hard issue
        ]
        
        let issues = DataIntegrityValidator.validate(
            entries: largeNegative,
            timeRange: timeRange
        )
        
        let negativeIssues = issues.filter { $0.type == DataIntegrityIssue.IssueType.negativeCount }
        assert(negativeIssues.count == 1, "Expected 1 negative count issue for severe drop, got \(negativeIssues.count)")
        assert(negativeIssues.first?.severity == .critical, "Expected critical severity")
        print("   ✓ Severe negative count detected correctly")
        print("   ℹ️  Message: \(negativeIssues.first?.message ?? "none")")
    }
    
    /// Test 3: Detect gaps in event stream
    static func testGapDetection() {
        print("\n📋 Test 3: Detect gaps in event stream")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 5), delta: 1),
            // 20 minute gap here
            makeEntry(timestamp: date(hour: 10, minute: 25), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 30), delta: 1)
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 10, minute: 35)
        )
        
        let issues = DataIntegrityValidator.validate(
            entries: entries,
            timeRange: timeRange
        )
        
        let gapIssues = issues.filter { $0.type == DataIntegrityIssue.IssueType.dataGap }
        assert(gapIssues.count == 1, "Expected 1 gap issue, got \(gapIssues.count)")
        assert(gapIssues.first?.severity == .warning, "Expected warning severity")
        print("   ✓ Gap detected correctly")
        print("   ℹ️  Message: \(gapIssues.first?.message ?? "none")")
    }
    
    /// Test 4: Coverage window calculation
    static func testCoverageWindow() {
        print("\n📋 Test 4: Coverage window calculation")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 30), delta: 1),
            makeEntry(timestamp: date(hour: 11, minute: 0), delta: -1)
        ]
        
        let coverage = DataIntegrityValidator.computeCoverageWindow(
            entries: entries
        )
        
        assert(coverage.startTimestamp != nil, "Expected start timestamp")
        assert(coverage.endTimestamp != nil, "Expected end timestamp")
        assert(coverage.gaps.count == 1, "Expected 1 gap (30 min between first two events)")
        
        print("   ✓ Coverage window calculated correctly")
        print("   ℹ️  Display text: \(coverage.displayText)")
        print("   ℹ️  Has gaps: \(coverage.hasGaps)")
        if let gapsDesc = coverage.gapsDescription {
            print("   ℹ️  Gaps: \(gapsDesc)")
        }
    }
    
    /// Test 5: Stale source detection
    static func testStaleSource() {
        print("\n📋 Test 5: Stale source detection")
        
        // Test with recent activity (should be OK)
        let recent = Date().addingTimeInterval(-2 * 60)  // 2 minutes ago
        let recentIssue = DataIntegrityValidator.detectStaleSource(
            lastSeenAt: recent,
            threshold: 5 * 60
        )
        assert(recentIssue == nil, "Expected no issue for recent activity")
        print("   ✓ Recent activity: no issue")
        
        // Test with stale activity (should trigger warning)
        let stale = Date().addingTimeInterval(-10 * 60)  // 10 minutes ago
        let staleIssue = DataIntegrityValidator.detectStaleSource(
            lastSeenAt: stale,
            threshold: 5 * 60
        )
        assert(staleIssue != nil, "Expected stale source issue")
        assert(staleIssue?.type == DataIntegrityIssue.IssueType.staleSource, "Expected stale source type")
        print("   ✓ Stale source detected correctly")
        print("   ℹ️  Message: \(staleIssue?.message ?? "none")")
        
        // Test with no activity (should trigger warning)
        let noActivityIssue = DataIntegrityValidator.detectStaleSource(
            lastSeenAt: nil,
            threshold: 5 * 60
        )
        assert(noActivityIssue != nil, "Expected issue for no activity")
        print("   ✓ No activity detected correctly")
        print("   ℹ️  Message: \(noActivityIssue?.message ?? "none")")
    }
    
    // MARK: - New Gap Classification Tests
    
    /// Test 6: Gaps below 20 min are ignored
    static func testGapsBelowDisplayThresholdAreIgnored() {
        print("\n📋 Test 6: Gaps below 20 min are ignored")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 15), delta: 1)  // 15 min gap
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 10, minute: 30)
        )
        
        let issues = DataIntegrityValidator.validate(
            entries: entries,
            timeRange: timeRange
        )
        
        assert(issues.isEmpty, "Expected no issues for gaps < 20 min, got \(issues.count)")
        print("   ✓ Gaps < 20 min ignored as expected")
    }
    
    /// Test 7: Gap 20-59 min displayed but not flagged as issue
    static func testGaps20to59MinutesDisplayedButNotFlagged() {
        print("\n📋 Test 7: Gap 20-59 min detected but not flagged")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 10, minute: 45), delta: 1)  // 45 min gap
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 11, minute: 0)
        )
        
        // Check classification
        let classified = DataIntegrityValidator.detectGapsWithClassification(
            entries: entries,
            config: .default
        )
        
        assert(classified.count == 1, "Expected 1 classified gap, got \(classified.count)")
        assert(classified.first?.severity == .info, "Expected .info severity, got \(String(describing: classified.first?.severity))")
        
        // Check that it's NOT in issues
        let issues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        assert(issues.isEmpty, "Expected no issues (info-level gaps not flagged), got \(issues.count)")
        
        print("   ✓ Gap 20-59 min detected as .info but not flagged as issue")
    }
    
    /// Test 8: Gap 60-180 min flagged as warning
    static func testGaps60to180MinutesFlaggedAsWarning() {
        print("\n📋 Test 8: Gap 60-180 min flagged as warning")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 12, minute: 0), delta: 1)  // 2h (120 min) gap
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 12, minute: 30)
        )
        
        let issues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        
        let gapIssues = issues.filter { $0.type == DataIntegrityIssue.IssueType.dataGap }
        assert(gapIssues.count == 1, "Expected 1 gap issue, got \(gapIssues.count)")
        assert(gapIssues.first?.severity == .warning, "Expected .warning severity, got \(String(describing: gapIssues.first?.severity))")
        
        print("   ✓ Gap 60-180 min flagged as warning")
        print("   ℹ️  Message: \(gapIssues.first?.message ?? "none")")
    }
    
    /// Test 9: Gap > 3h flagged as critical
    static func testGapsOver3HoursFlaggedAsCritical() {
        print("\n📋 Test 9: Gap > 3h flagged as critical")
        
        let entries = [
            makeEntry(timestamp: date(hour: 10, minute: 0), delta: 1),
            makeEntry(timestamp: date(hour: 14, minute: 30), delta: 1)  // 4.5h gap
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 10, minute: 0),
            end: date(hour: 15, minute: 0)
        )
        
        let issues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        
        let gapIssues = issues.filter { $0.type == DataIntegrityIssue.IssueType.dataGap }
        assert(gapIssues.count == 1, "Expected 1 gap issue, got \(gapIssues.count)")
        assert(gapIssues.first?.severity == .critical, "Expected .critical severity, got \(String(describing: gapIssues.first?.severity))")
        
        print("   ✓ Gap > 3h flagged as critical")
        print("   ℹ️  Message: \(gapIssues.first?.message ?? "none")")
    }
    
    /// Test 10: Gap > 6h classified as expected inactivity
    static func testGapsOver6HoursClassifiedAsInactivity() {
        print("\n📋 Test 10: Gap > 6h classified as inactivity")
        
        let entries = [
            makeEntry(timestamp: date(hour: 22, minute: 0), delta: 1),
            makeEntry(timestamp: dateNextDay(hour: 10, minute: 0), delta: 1)  // 12h gap (closing hours)
        ]
        
        let timeRange = DateInterval(
            start: date(hour: 22, minute: 0),
            end: dateNextDay(hour: 10, minute: 30)
        )
        
        // Check classification
        let classified = DataIntegrityValidator.detectGapsWithClassification(
            entries: entries,
            config: .default
        )
        
        assert(classified.count == 1, "Expected 1 classified gap, got \(classified.count)")
        assert(classified.first?.severity == .inactivity, "Expected .inactivity severity, got \(String(describing: classified.first?.severity))")
        
        // Check that it's NOT flagged as issue
        let issues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        let gapIssues = issues.filter { $0.type == DataIntegrityIssue.IssueType.dataGap }
        assert(gapIssues.isEmpty, "Expected no gap issues (inactivity not flagged), got \(gapIssues.count)")
        
        print("   ✓ Gap > 6h classified as inactivity (not an issue)")
    }
    
    // MARK: - Helpers
    
    private static func makeEntry(
        timestamp: Date,
        delta: Int,
        id: String = UUID().uuidString
    ) -> Entry {
        Entry(
            id: id,
            locationId: "test-location",
            userId: nil,
            timestamp: timestamp,
            type: delta > 0 ? .in : .out,
            delta: delta,
            deviceId: "test-device",
            source: .hardware,
            sequenceNumber: nil
        )
    }
    
    private static func date(hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components) ?? now
    }
    
    private static func dateNextDay(hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day = (components.day ?? 1) + 1
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components) ?? now
    }
}

#endif
