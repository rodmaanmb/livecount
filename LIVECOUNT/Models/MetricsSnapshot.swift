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
    
    // MARK: - Data Integrity (P0.1.1: Hard Issues vs Soft Signals)
    
    /// P0.1.1: HARD integrity issues only (people_present < 0)
    /// These trigger red alert banners
    let dataIntegrityIssues: [DataIntegrityIssue]
    
    /// P0.1.1: SOFT flow signals (negative drain, inactivity)
    /// These display in neutral info sections
    let dataFlowSignals: [DataFlowSignal]
    
    /// Coverage window with gap detection
    let coverageWindow: DataCoverageWindow
    
    /// P0.1.1: True if there are HARD integrity issues (red banner)
    var hasHardIntegrityIssues: Bool {
        dataIntegrityIssues.contains { $0.severity == .critical }
    }
    
    /// P0.1.1: True if there are soft signals (info section)
    var hasSoftSignals: Bool {
        !dataFlowSignals.isEmpty
    }
    
    /// Deprecated: Use hasHardIntegrityIssues instead
    var hasDataIssues: Bool {
        hasHardIntegrityIssues
    }
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
