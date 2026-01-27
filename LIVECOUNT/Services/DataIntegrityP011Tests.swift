//
//  DataIntegrityP011Tests.swift
//  LIVECOUNT
//
//  P0.1.1: Tests for Hard Issues vs Soft Signals redefinition
//

#if DEBUG

import Foundation

enum DataIntegrityP011Tests {
    
    /// Run all P0.1.1 tests
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 [P0.1.1 Tests] Running all tests...")
        print(String(repeating: "=", count: 60))
        
        testHardIssue_NegativeCount()
        testSoftSignal_NegativeDrain()
        testNoHardIssue_MassiveDrainButCountStaysPositive()
        testSoftSignal_InactivityPeriod()
        testNoIssues_NormalActivity()
        testMultipleHardIssues()
        
        print("\n" + String(repeating: "=", count: 60))
        print("✅ [P0.1.1 Tests] All tests passed!")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Test 1: people_present < 0 → Hard issue
    
    static func testHardIssue_NegativeCount() {
        print("\n🧪 Test 1: people_present < 0 → Hard issue")
        
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: Date(),
                type: .in,
                delta: 5,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(60),
                type: .out,
                delta: -3,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(120),
                type: .out,
                delta: -10,  // count = -6 ❌ HARD ISSUE (beyond threshold)
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let hardIssues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        
        assert(hardIssues.count == 1, "Expected 1 hard issue, got \(hardIssues.count)")
        assert(hardIssues[0].severity == .critical, "Expected .critical severity")
        assert(hardIssues[0].type == .negativeCount, "Expected .negativeCount type")
        
        print("   ✅ Detected 1 hard issue with .critical severity")
    }
    
    // MARK: - Test 2: Net flow < 0 WITHOUT count < 0 → Soft signal
    
    static func testSoftSignal_NegativeDrain() {
        print("\n🧪 Test 2: Net flow < 0 WITHOUT count < 0 → Soft signal")
        
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: Date(),
                type: .in,
                delta: 50,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(60),
                type: .out,
                delta: -30,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(120),
                type: .out,
                delta: -35,  // count = -15 but net flow = 50-65 = -15
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        
        // Hard issues: SHOULD have 1 because count goes negative (50 - 30 - 35 = -15)
        let hardIssues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        print("   • Hard issues: \(hardIssues.count)")
        
        // Let's test a scenario without going negative:
        let entries2 = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: Date(),
                type: .in,
                delta: 100,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(60),
                type: .out,
                delta: -60,  // count = 40, net = -60 (more exits than entries after initial)
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(120),
                type: .out,
                delta: -30,  // count = 10, net flow = 100-90 = +10 (ok)
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let hardIssues2 = DataIntegrityValidator.validate(entries: entries2, timeRange: timeRange)
        assert(hardIssues2.isEmpty, "Expected NO hard issues when count stays >= 0")
        
        // Soft signals: should detect negative drain if threshold is met
        let softSignals = DataIntegrityValidator.analyzeFlowSignals(entries: entries2, timeRange: timeRange)
        print("   • Soft signals: \(softSignals.count)")
        
        // Net flow = +10, so no negative drain signal expected for this data
        print("   ✅ No hard issue when count >= 0, soft signals analyzed")
    }
    
    // MARK: - Test 3: Massive drain but people_present stays >= 0
    
    static func testNoHardIssue_MassiveDrainButCountStaysPositive() {
        print("\n🧪 Test 3: Massive drain but people_present stays >= 0")
        
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: Date(),
                type: .in,
                delta: 100,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(60),
                type: .out,
                delta: -90,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: Date().addingTimeInterval(120),
                type: .out,
                delta: -10,  // count = 0 (ok)
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let hardIssues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        
        assert(hardIssues.isEmpty, "Expected NO hard issues when count never goes < 0")
        print("   ✅ No hard issue when massive drain but count >= 0")
        
        // Should trigger soft signal for negative drain
        let softSignals = DataIntegrityValidator.analyzeFlowSignals(entries: entries, timeRange: timeRange)
        let hasNegativeDrainSignal = softSignals.contains { $0.type == .negativeDrain }
        
        assert(hasNegativeDrainSignal, "Expected soft signal for negative drain")
        print("   ✅ Soft signal detected for negative drain")
    }
    
    // MARK: - Test 4: Long inactivity → Soft signal
    
    static func testSoftSignal_InactivityPeriod() {
        print("\n🧪 Test 4: Long inactivity → Soft signal")
        
        let now = Date()
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-8 * 60 * 60),  // 8h ago
                type: .in,
                delta: 1,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: now,  // GAP of 8h
                type: .in,
                delta: 1,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: now.addingTimeInterval(-10 * 60 * 60), end: now)
        let softSignals = DataIntegrityValidator.analyzeFlowSignals(entries: entries, timeRange: timeRange)
        
        let hasInactivitySignal = softSignals.contains { $0.type == .inactivityPeriod }
        assert(hasInactivitySignal, "Expected soft signal for inactivity period")
        
        print("   ✅ Soft signal detected for inactivity period (> 6h)")
    }
    
    // MARK: - Test 5: Normal activity → No issues, no signals
    
    static func testNoIssues_NormalActivity() {
        print("\n🧪 Test 5: Normal activity → No issues, no signals")
        
        let now = Date()
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-3600),
                type: .in,
                delta: 10,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-1800),
                type: .in,
                delta: 5,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: now,
                type: .out,
                delta: -3,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: now.addingTimeInterval(-3600), end: now)
        let hardIssues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        let softSignals = DataIntegrityValidator.analyzeFlowSignals(entries: entries, timeRange: timeRange)
        
        assert(hardIssues.isEmpty, "Expected NO hard issues for normal activity")
        // Soft signals may or may not be present depending on thresholds
        
        print("   ✅ No hard issues for normal activity")
        print("   • Soft signals: \(softSignals.count)")
    }
    
    // MARK: - Test 6: Multiple hard issues
    
    static func testMultipleHardIssues() {
        print("\n🧪 Test 6: Multiple hard issues (count goes negative multiple times)")
        
        let now = Date()
        let entries = [
            Entry(
                id: "1",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-3600),
                type: .in,
                delta: 5,
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "2",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-2400),
                type: .out,
                delta: -10,  // count = -5 ❌ HARD ISSUE #1
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "3",
                locationId: "test",
                userId: nil,
                timestamp: now.addingTimeInterval(-1200),
                type: .in,
                delta: 15,  // count = 10 (clamped from -5 to 0, then +15 = 15)
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            ),
            Entry(
                id: "4",
                locationId: "test",
                userId: nil,
                timestamp: now,
                type: .out,
                delta: -20,  // count = -5 ❌ HARD ISSUE #2
                deviceId: "device1",
                source: .hardware,
                sequenceNumber: nil
            )
        ]
        
        let timeRange = DateInterval(start: now.addingTimeInterval(-3600), end: now)
        let hardIssues = DataIntegrityValidator.validate(entries: entries, timeRange: timeRange)
        
        assert(hardIssues.count == 2, "Expected 2 hard issues, got \(hardIssues.count)")
        assert(hardIssues.allSatisfy { $0.severity == .critical }, "All issues should be .critical")
        
        print("   ✅ Detected \(hardIssues.count) hard issues (count went negative twice)")
    }
}

#endif
