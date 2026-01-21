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
}