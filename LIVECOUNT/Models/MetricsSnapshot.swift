//
//  MetricsSnapshot.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Snapshot of metrics computed from a set of entries
struct MetricsSnapshot {
    // MARK: - Coverage
    
    /// Total number of entries (in + out)
    let totalEntries: Int
    
    /// Total number of entries (type: .in)
    let totalEntriesIn: Int
    
    /// Total number of exits (type: .out)
    let totalExits: Int
    
    /// Net change (entries - exits)
    let netChange: Int
    
    /// Number of calendar days with at least one event
    let daysCovered: Int
    
    /// Average entries per day (totalEntriesIn / daysCovered)
    let avgEntriesPerDay: Double
    
    // MARK: - Occupancy
    
    /// Average occupancy percentage (event-based average)
    /// Computed by replaying all entries and averaging currentCount/maxCapacity
    let avgOccupancyPercent: Double
    
    /// Peak occupancy count reached during the period
    let peakCount: Int
    
    /// Timestamp of peak occupancy (first occurrence if tie)
    let peakTimestamp: Date?
    
    // MARK: - Metadata
    
    /// Time range for these metrics
    let timeRange: TimeRange
    
    /// Location ID
    let locationId: String
}

/// Comparison between two metric snapshots (current vs previous period)
struct MetricsComparison {
    let currentSnapshot: MetricsSnapshot
    let previousSnapshot: MetricsSnapshot
    
    // MARK: - Computed Comparisons
    
    /// Change in total entries (absolute)
    var entriesDelta: Int {
        currentSnapshot.totalEntriesIn - previousSnapshot.totalEntriesIn
    }
    
    /// Change in total entries (percentage)
    var entriesPercentChange: Double? {
        guard previousSnapshot.totalEntriesIn > 0 else { return nil }
        return Double(entriesDelta) / Double(previousSnapshot.totalEntriesIn) * 100
    }
    
    /// Change in average occupancy (absolute, in percentage points)
    var avgOccupancyDelta: Double {
        currentSnapshot.avgOccupancyPercent - previousSnapshot.avgOccupancyPercent
    }
    
    /// Change in peak count (absolute)
    var peakCountDelta: Int {
        currentSnapshot.peakCount - previousSnapshot.peakCount
    }
}
