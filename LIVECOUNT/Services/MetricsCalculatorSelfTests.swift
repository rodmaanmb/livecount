//
//  MetricsCalculatorSelfTests.swift
//  LIVECOUNT
//
//  Created by Codex on 2026-01-19.
//

import Foundation

#if DEBUG
/// Lightweight, pure calculation checks for MetricsCalculator (manually callable).
enum MetricsCalculatorSelfTests {
    static func runAll() {
        testAvgOccupancyWithinBounds()
        testPeakClampedToCapacity()
        testEmptyEntriesReturnsZero()
        testInactiveWindowIgnored()
        print("✅ MetricsCalculatorSelfTests passed")
    }
    
    private static func testAvgOccupancyWithinBounds() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600)
        let timeRange = TimeRange(type: .today, startDate: start, endDate: end)
        let entries = makeEntries(
            startAt: start.addingTimeInterval(600),
            count: 120,
            delta: 1,
            type: .in
        )
        
        let snapshot = MetricsCalculator.compute(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: 120,
            locationId: "loc-1"
        )
        
        // BUGFIX: avgOccupancyPercent est maintenant un ratio (0.0-1.0), pas un pourcentage
        assert(snapshot.avgOccupancyPercent >= 0.0 && snapshot.avgOccupancyPercent <= 1.0)
        assert(snapshot.peakCount == 120)
    }
    
    private static func testPeakClampedToCapacity() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600)
        let timeRange = TimeRange(type: .today, startDate: start, endDate: end)
        let entries = makeEntries(
            startAt: start.addingTimeInterval(10),
            count: 150,
            delta: 1,
            type: .in
        )
        
        let snapshot = MetricsCalculator.compute(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: 120,
            locationId: "loc-1"
        )
        
        assert(snapshot.peakCount == 120)
        // BUGFIX: avgOccupancyPercent est maintenant un ratio (0.0-1.0), pas un pourcentage
        assert(snapshot.avgOccupancyPercent <= 1.0)
    }
    
    private static func testEmptyEntriesReturnsZero() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600)
        let timeRange = TimeRange(type: .today, startDate: start, endDate: end)
        
        let snapshot = MetricsCalculator.compute(
            entries: [],
            timeRange: timeRange,
            maxCapacity: 120,
            locationId: "loc-1"
        )
        
        assert(snapshot.avgOccupancyPercent == 0.0)
        assert(snapshot.peakCount == 0)
    }
    
    private static func testInactiveWindowIgnored() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 6 * 60 * 60)
        let timeRange = TimeRange(type: .today, startDate: start, endDate: end)
        let eventTimestamp = start.addingTimeInterval(3 * 60 * 60)
        let entries: [Entry] = [
            Entry(
                id: "e-1",
                locationId: "loc-1",
                userId: nil,
                timestamp: eventTimestamp,
                type: .in,
                delta: 1,
                deviceId: "device-1",
                source: .simulated,
                sequenceNumber: nil
            ),
            Entry(
                id: "e-2",
                locationId: "loc-1",
                userId: nil,
                timestamp: eventTimestamp,
                type: .out,
                delta: -1,
                deviceId: "device-1",
                source: .simulated,
                sequenceNumber: nil
            )
        ]
        
        let snapshot = MetricsCalculator.compute(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: 120,
            locationId: "loc-1"
        )
        
        print("🔎 [testInactiveWindowIgnored]")
        print("   • avgOccupancyPercent: \(snapshot.avgOccupancyPercent)")
        print("   • peakCount: \(snapshot.peakCount)")
        print("   • timeRange: \(timeRange.startDate) → \(timeRange.endDate)")
        print("   • entry timestamps: \(entries.map { $0.timestamp })")
        assert(snapshot.avgOccupancyPercent == 0.0)
    }
    
    private static func makeEntries(
        startAt: Date,
        count: Int,
        delta: Int,
        type: EntryType
    ) -> [Entry] {
        (0..<count).map { index in
            Entry(
                id: "e-\(index)",
                locationId: "loc-1",
                userId: nil,
                timestamp: startAt.addingTimeInterval(TimeInterval(index)),
                type: type,
                delta: delta,
                deviceId: "device-1",
                source: .simulated,
                sequenceNumber: nil
            )
        }
    }
}
#endif
