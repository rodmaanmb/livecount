//
//  CounterState.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation

struct CounterState: Codable {
    var currentCount: Int
    var lastUpdated: Date
    var status: OccupancyStatus
    var lastEventAt: Date?
    
    // MARK: - Derived fields (Dashboard LIVE)
    
    /// Occupancy percentage (0.0 - 1.0+)
    var occupancyPercent: Double
    
    /// Remaining spots (maxCapacity - currentCount, clamped to 0)
    var remainingSpots: Int
    
    // MARK: - Rolling window aggregates (last X minutes)
    
    /// Number of entries in the last X minutes
    var entriesLastXMin: Int
    
    /// Number of exits in the last X minutes
    var exitsLastXMin: Int
    
    /// Net change in the last X minutes (entries - exits)
    var netLastXMin: Int
    
    // MARK: - Data Integrity (P0.1.1: Hard Issues vs Soft Signals)
    
    /// P0.1.1: HARD integrity issues only (people_present < 0)
    /// These trigger red alert banners
    var dataIntegrityIssues: [DataIntegrityIssue]
    
    /// P0.1.1: SOFT flow signals (negative drain, inactivity)
    /// These display in neutral info sections
    var dataFlowSignals: [DataFlowSignal]
    
    /// Coverage window with gap detection
    var coverageWindow: DataCoverageWindow
    
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