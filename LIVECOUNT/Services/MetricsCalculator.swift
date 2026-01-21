//
//  MetricsCalculator.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Stateless calculator for computing metrics from Entry arrays
enum MetricsCalculator {
    #if DEBUG
    private static let diagnosticsEnabled = false
    #endif
    
    /// Compute metrics snapshot from entries
    /// - Parameters:
    ///   - entries: Array of Entry events (must be sorted by timestamp)
    ///   - timeRange: Time range for the metrics
    ///   - maxCapacity: Maximum capacity for occupancy calculations
    ///   - locationId: Location ID for the metrics
    /// - Returns: A MetricsSnapshot with all computed metrics
    static func compute(
        entries: [Entry],
        timeRange: TimeRange,
        maxCapacity: Int,
        locationId: String
    ) -> MetricsSnapshot {
        // Basic counts
        let totalEntries = entries.count
        let totalEntriesIn = entries.filter { $0.type == .in }.count
        let totalExits = entries.filter { $0.type == .out }.count
        let netChange = totalEntriesIn - totalExits
        
        // Days covered (unique calendar days with events)
        let daysCovered = computeDaysCovered(entries: entries, timeRange: timeRange)
        
        // Average entries per day
        let avgEntriesPerDay: Double
        if daysCovered > 0 {
            avgEntriesPerDay = Double(totalEntriesIn) / Double(daysCovered)
        } else {
            avgEntriesPerDay = 0
        }
        
        // Occupancy metrics (replay-based)
        let (avgOccupancy, peakCount, peakTimestamp) = computeOccupancyMetrics(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: maxCapacity
        )
        
        return MetricsSnapshot(
            totalEntries: totalEntries,
            totalEntriesIn: totalEntriesIn,
            totalExits: totalExits,
            netChange: netChange,
            daysCovered: daysCovered,
            avgEntriesPerDay: avgEntriesPerDay,
            avgOccupancyPercent: avgOccupancy,
            peakCount: peakCount,
            peakTimestamp: peakTimestamp,
            timeRange: timeRange,
            locationId: locationId
        )
    }
    
    /// Compute comparison between current and previous snapshots
    /// - Parameters:
    ///   - currentSnapshot: Current period metrics
    ///   - previousEntries: Entries from previous period
    ///   - previousRange: Time range for previous period
    ///   - maxCapacity: Maximum capacity
    /// - Returns: A MetricsComparison if previous period has events, nil otherwise
    static func computeComparison(
        currentSnapshot: MetricsSnapshot,
        previousEntries: [Entry],
        previousRange: TimeRange,
        maxCapacity: Int
    ) -> MetricsComparison? {
        // If previous period has no events, no comparison possible
        guard !previousEntries.isEmpty else { return nil }
        
        let previousSnapshot = compute(
            entries: previousEntries,
            timeRange: previousRange,
            maxCapacity: maxCapacity,
            locationId: currentSnapshot.locationId
        )
        
        return MetricsComparison(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot
        )
    }
    
    // MARK: - Private Helpers
    
    /// Compute number of unique calendar days with at least one event
    private static func computeDaysCovered(entries: [Entry], timeRange: TimeRange) -> Int {
        guard !entries.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        
        // Extract unique date components (year, month, day)
        let uniqueDays = Set(entries.map { entry in
            calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
        })
        
        return uniqueDays.count
    }
    
    /// Compute occupancy metrics by replaying entries
    /// - Parameters:
    ///   - entries: Array of Entry events (must be sorted)
    ///   - maxCapacity: Maximum capacity
    /// - Returns: (avgOccupancyPercent, peakCount, peakTimestamp)
    private static func computeOccupancyMetrics(
        entries: [Entry],
        timeRange: TimeRange,
        maxCapacity: Int
    ) -> (avgOccupancy: Double, peakCount: Int, peakTimestamp: Date?) {
        guard maxCapacity > 0 else {
            #if DEBUG
            if diagnosticsEnabled {
                print("⚠️ [MetricsCalculator] computeOccupancyMetrics: maxCapacity=\(maxCapacity)")
            }
            #endif
            return (0.0, 0, nil)
        }
        
        guard !entries.isEmpty else {
            #if DEBUG
            if diagnosticsEnabled {
                print("⚠️ [MetricsCalculator] computeOccupancyMetrics: entries.isEmpty=true")
            }
            #endif
            return (0.0, 0, nil)
        }
        
        let interval = timeRange.interval
        guard interval.duration > 0 else {
            #if DEBUG
            if diagnosticsEnabled {
                print("⚠️ [MetricsCalculator] computeOccupancyMetrics: interval.duration=\(interval.duration)")
            }
            #endif
            return (0.0, 0, nil)
        }
        
        var rawCount = 0
        var peakCount = 0
        var peakTimestamp: Date?
        var weightedOccupancySum: Double = 0.0
        var totalDuration: TimeInterval = 0.0
        var lastTimestamp = interval.start
        
        #if DEBUG
        var countSamples: [Int] = []
        var ratioSamples: [Double] = []
        #endif
        
        #if DEBUG
        if diagnosticsEnabled {
            print("📊 [MetricsCalculator] Computing occupancy metrics:")
            print("   • Entry count: \(entries.count)")
            print("   • MaxCapacity: \(maxCapacity)")
            print("   • Interval: \(interval.start) → \(interval.end)")
        }
        #endif
        
        let sortedEntries = entries.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
        
        let idleThreshold: TimeInterval = 2 * 60 * 60
        let hardIdleThreshold: TimeInterval = 6 * 60 * 60
        let idleOccupancyLimit = 10
        
        // Replay all entries with time-weighted averaging (active windows only)
        for (index, entry) in sortedEntries.enumerated() {
            let segmentEnd = min(entry.timestamp, interval.end)
            let duration = segmentEnd.timeIntervalSince(lastTimestamp)
            if duration > 0 {
                let boundedCount = min(max(0, rawCount), maxCapacity)
                let isInactive = duration >= hardIdleThreshold
                    || (duration >= idleThreshold && boundedCount <= idleOccupancyLimit)
                if !isInactive {
                    let occupancyRatio = Double(boundedCount) / Double(maxCapacity)
                    weightedOccupancySum += occupancyRatio * duration
                    totalDuration += duration
                }
                
                #if DEBUG
                if diagnosticsEnabled && (index < 10 || index >= sortedEntries.count - 10 || index % 1000 == 0) {
                    countSamples.append(boundedCount)
                    if !isInactive {
                        ratioSamples.append(Double(boundedCount) / Double(maxCapacity))
                    }
                }
                #endif
            }
            
            rawCount += entry.delta
            lastTimestamp = max(lastTimestamp, segmentEnd)
            
            let boundedCount = min(max(0, rawCount), maxCapacity)
            if boundedCount > peakCount {
                peakCount = boundedCount
                peakTimestamp = entry.timestamp
            } else if boundedCount == peakCount && peakTimestamp == nil {
                peakTimestamp = entry.timestamp
            }
        }
        
        if lastTimestamp < interval.end {
            let duration = interval.end.timeIntervalSince(lastTimestamp)
            if duration > 0 {
                let boundedCount = min(max(0, rawCount), maxCapacity)
                let isInactive = duration >= hardIdleThreshold
                    || (duration >= idleThreshold && boundedCount <= idleOccupancyLimit)
                if !isInactive {
                    let occupancyRatio = Double(boundedCount) / Double(maxCapacity)
                    weightedOccupancySum += occupancyRatio * duration
                    totalDuration += duration
                }
                
                #if DEBUG
                if diagnosticsEnabled {
                    countSamples.append(boundedCount)
                    if !isInactive {
                        ratioSamples.append(Double(boundedCount) / Double(maxCapacity))
                    }
                }
                #endif
            }
        }
        
        let avgRatio = totalDuration > 0 ? (weightedOccupancySum / totalDuration) : 0.0
        var avgOccupancy = avgRatio * 100
        if !avgOccupancy.isFinite {
            avgOccupancy = 0.0
        }
        avgOccupancy = min(max(avgOccupancy, 0.0), 100.0)
        
        #if DEBUG
        if diagnosticsEnabled {
            let logData: [String: Any] = [
                "entryCount": sortedEntries.count,
                "maxCapacity": maxCapacity,
                "weightedOccupancySum": weightedOccupancySum,
                "totalDuration": totalDuration,
                "avgOccupancyFinal": avgOccupancy,
                "peakCount": peakCount,
                "countSamplesFirst10": Array(countSamples.prefix(10)),
                "countSamplesLast10": Array(countSamples.suffix(10)),
                "ratioSamplesFirst10": Array(ratioSamples.prefix(10)),
                "ratioSamplesLast10": Array(ratioSamples.suffix(10))
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: [
                "sessionId": "debug-session",
                "runId": "occupancy-bug",
                "hypothesisId": "A-B",
                "location": "MetricsCalculator.swift:114",
                "message": "Occupancy calculation completed",
                "data": logData,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]), let jsonString = String(data: jsonData, encoding: .utf8) {
                let logPath = "/Users/romanmbarali/Desktop/Livecount App/.cursor/debug.log"
                if let handle = FileHandle(forWritingAtPath: logPath) ?? (FileManager.default.createFile(atPath: logPath, contents: nil) ? FileHandle(forWritingAtPath: logPath) : nil) {
                    handle.seekToEndOfFile()
                    handle.write((jsonString + "\n").data(using: .utf8)!)
                    handle.closeFile()
                }
            }
        }
        #endif
        
        #if DEBUG
        if diagnosticsEnabled {
            print("   • Peak count: \(peakCount)")
            print("   • Peak occupancy: \(String(format: "%.1f%%", Double(peakCount) / Double(maxCapacity) * 100))")
            print("   • Avg occupancy: \(String(format: "%.1f%%", avgOccupancy))")
        }
        if diagnosticsEnabled {
            let isValid = avgOccupancy.isFinite && avgOccupancy >= 0.0 && avgOccupancy <= 100.0
            assert(isValid, "avgOccupancyPercent out of bounds: \(avgOccupancy)")
        }
        #endif
        
        return (avgOccupancy, peakCount, peakTimestamp)
    }
}
