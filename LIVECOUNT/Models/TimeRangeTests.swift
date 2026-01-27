//
//  TimeRangeTests.swift
//  LIVECOUNT
//
//  Regression tests for P0.2 Date Navigation Bug
//

import Foundation

#if DEBUG

/// Self-tests for TimeRange (run in-app for development)
enum TimeRangeTests {
    
    // MARK: - Test Runner
    
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 Running TimeRange Tests (P0.2 Regression)")
        print(String(repeating: "=", count: 60))
        
        testRangeLabelForToday()
        testRangeLabelForPastDays()
        testRangeLabelForFutureSafeguard()
        testRangeIntervalForPastDays()
        testLast7DaysWithOffset()
        
        print("\n✅ All TimeRange tests passed!")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Test Cases
    
    /// Test 1: Label for today (offset=0) shows correct date
    static func testRangeLabelForToday() {
        print("\n📋 Test 1: Label for today (offset=0)")
        
        let today = TimeRange.from(type: .today, offsetDays: 0)
        let label = today.rangeLabel(showPrefix: false, isCurrentPeriod: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        let expectedLabel = formatter.string(from: today.startDate)
        
        assert(label == expectedLabel, "Today label mismatch: '\(label)' != '\(expectedLabel)'")
        print("   ✓ Today label correct: \(label)")
    }
    
    /// Test 2: P0.2 REGRESSION — Label for past days shows correct date (not endDate)
    static func testRangeLabelForPastDays() {
        print("\n📋 Test 2: P0.2 REGRESSION — Label for past days")
        
        // Test offset = -1 (yesterday)
        let yesterday = TimeRange.from(type: .today, offsetDays: -1)
        let labelYesterday = yesterday.rangeLabel(showPrefix: false, isCurrentPeriod: false)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        
        // Expected: label should show startDate (the target day), NOT endDate
        let expectedYesterday = formatter.string(from: yesterday.startDate)
        
        assert(labelYesterday == expectedYesterday, 
               "Yesterday label WRONG: '\(labelYesterday)' should be '\(expectedYesterday)' (was showing endDate before fix)")
        print("   ✓ Yesterday label correct: \(labelYesterday)")
        
        // Test offset = -7 (1 week ago)
        let lastWeek = TimeRange.from(type: .today, offsetDays: -7)
        let labelLastWeek = lastWeek.rangeLabel(showPrefix: false, isCurrentPeriod: false)
        let expectedLastWeek = formatter.string(from: lastWeek.startDate)
        
        assert(labelLastWeek == expectedLastWeek, 
               "Last week label WRONG: '\(labelLastWeek)' should be '\(expectedLastWeek)'")
        print("   ✓ Last week label correct: \(labelLastWeek)")
    }
    
    /// Test 3: Future offset safeguard (should not happen in UI but test anyway)
    static func testRangeLabelForFutureSafeguard() {
        print("\n📋 Test 3: Future offset safeguard (offset > 0)")
        
        // Note: In production, rangeOffsetDays > 0 is prevented by shiftRange()
        // But TimeRange.from() should still handle it gracefully
        let tomorrow = TimeRange.from(type: .today, offsetDays: 1)
        let label = tomorrow.rangeLabel(showPrefix: false, isCurrentPeriod: false)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        let expectedLabel = formatter.string(from: tomorrow.startDate)
        
        assert(label == expectedLabel, "Future label mismatch: '\(label)' != '\(expectedLabel)'")
        print("   ✓ Future label handled: \(label)")
    }
    
    /// Test 4: Range interval for past days covers the full day
    static func testRangeIntervalForPastDays() {
        print("\n📋 Test 4: Range interval for past days covers full day")
        
        let yesterday = TimeRange.from(type: .today, offsetDays: -1)
        
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: yesterday.startDate)
        let endDay = calendar.date(byAdding: .day, value: 1, to: startDay)!
        
        // startDate should be start of yesterday
        assert(yesterday.startDate == startDay, "startDate should be start of day")
        
        // endDate should be start of today (= end of yesterday)
        assert(yesterday.endDate == endDay, "endDate should be start of next day")
        
        let duration = yesterday.interval.duration
        let expectedDuration: TimeInterval = 24 * 60 * 60 // 24 hours
        
        // Allow small floating point error
        assert(abs(duration - expectedDuration) < 1, 
               "Duration should be ~24h, got \(duration / 3600)h")
        
        print("   ✓ Interval covers full 24h: \(String(format: "%.1f", duration / 3600))h")
    }
    
    /// Test 5: last7Days with offset also shifts correctly
    static func testLast7DaysWithOffset() {
        print("\n📋 Test 5: last7Days with offset shifts correctly")
        
        // Current week (offset=0)
        let thisWeek = TimeRange.from(type: .last7Days, offsetDays: 0)
        
        // Previous week (offset=-7)
        let lastWeek = TimeRange.from(type: .last7Days, offsetDays: -7)
        
        // lastWeek.endDate should be ~7 days before thisWeek.endDate
        let daysDiff = Calendar.current.dateComponents([.day], from: lastWeek.endDate, to: thisWeek.endDate).day ?? 0
        
        assert(daysDiff >= 6 && daysDiff <= 8, 
               "Offset=-7 should shift by ~7 days, got \(daysDiff) days")
        
        print("   ✓ Offset=-7 shifts by \(daysDiff) days (expected ~7)")
    }
    
    // MARK: - Helpers
    
    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }
}

#endif
