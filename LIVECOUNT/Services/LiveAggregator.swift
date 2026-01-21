//
//  LiveAggregator.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Aggregates Entry events into live CounterState with rolling window analytics
final class LiveAggregator {
    private let eventStream: EventStream
    private let maxCapacity: Int
    private let windowDurationMinutes: Int
    
    init(
        eventStream: EventStream,
        maxCapacity: Int = 100,
        windowDurationMinutes: Int = 5
    ) {
        self.eventStream = eventStream
        self.maxCapacity = maxCapacity
        self.windowDurationMinutes = windowDurationMinutes
    }
    
    /// Returns an AsyncStream of CounterState computed from events
    /// - Parameter initialEntries: Entries to replay before starting the live stream (for rehydration)
    func aggregatedState(initialEntries: [Entry] = []) -> AsyncStream<CounterState> {
        AsyncStream<CounterState> { continuation in
            Task {
                var currentCount = 0
                var lastEventAt: Date?
                
                // Rolling window: keep events from the last X minutes
                var recentEvents: [Entry] = []
                
                // REHYDRATION: Replay initial entries to rebuild state
                if !initialEntries.isEmpty {
                    let sortedInitialEntries = initialEntries.sorted { lhs, rhs in
                        if lhs.timestamp == rhs.timestamp {
                            return lhs.id < rhs.id
                        }
                        return lhs.timestamp < rhs.timestamp
                    }
                    
                    for entry in sortedInitialEntries {
                        currentCount = max(0, currentCount + entry.delta)
                        lastEventAt = entry.timestamp
                        recentEvents.append(entry)
                    }
                    
                    // Purge old events outside the window based on most recent timestamp
                    if let mostRecentTimestamp = lastEventAt {
                        let windowStart = mostRecentTimestamp.addingTimeInterval(-Double(windowDurationMinutes * 60))
                        recentEvents.removeAll { $0.timestamp < windowStart }
                    }
                    
                    // Emit initial state after rehydration
                    let initialState = computeState(
                        currentCount: currentCount,
                        lastEventAt: lastEventAt,
                        recentEvents: recentEvents
                    )
                    continuation.yield(initialState)
                }
                
                // LIVE STREAM: Process new events as they arrive
                for await entry in eventStream.events {
                    // Apply delta, clamping to 0 minimum
                    currentCount = max(0, currentCount + entry.delta)
                    lastEventAt = entry.timestamp
                    
                    // Add event to rolling window
                    recentEvents.append(entry)
                    
                    // Purge old events outside the window
                    let windowStart = entry.timestamp.addingTimeInterval(-Double(windowDurationMinutes * 60))
                    recentEvents.removeAll { $0.timestamp < windowStart }
                    
                    // Emit updated state
                    let state = computeState(
                        currentCount: currentCount,
                        lastEventAt: lastEventAt,
                        recentEvents: recentEvents
                    )
                    continuation.yield(state)
                }
                
                continuation.finish()
            }
        }
    }
    
    /// Compute CounterState from current values and recent events
    private func computeState(
        currentCount: Int,
        lastEventAt: Date?,
        recentEvents: [Entry]
    ) -> CounterState {
        // Compute window aggregates
        let entriesLastXMin = recentEvents.filter { $0.type == .in }.count
        let exitsLastXMin = recentEvents.filter { $0.type == .out }.count
        let netLastXMin = entriesLastXMin - exitsLastXMin
        
        // Compute derived fields
        let occupancyPercent = computeOccupancyPercent(count: currentCount, maxCapacity: maxCapacity)
        let remainingSpots = max(0, maxCapacity - currentCount)
        let status = computeStatus(occupancyPercent: occupancyPercent)
        
        return CounterState(
            currentCount: currentCount,
            lastUpdated: Date(),
            status: status,
            lastEventAt: lastEventAt,
            occupancyPercent: occupancyPercent,
            remainingSpots: remainingSpots,
            entriesLastXMin: entriesLastXMin,
            exitsLastXMin: exitsLastXMin,
            netLastXMin: netLastXMin
        )
    }
    
    /// Compute occupancy percentage (0.0 - 1.0+)
    private func computeOccupancyPercent(count: Int, maxCapacity: Int) -> Double {
        guard maxCapacity > 0 else { return 0.0 }
        return Double(count) / Double(maxCapacity)
    }
    
    /// Compute occupancy status based on percentage
    private func computeStatus(occupancyPercent: Double) -> OccupancyStatus {
        if occupancyPercent >= 1.0 {
            return .full
        } else if occupancyPercent >= 0.8 {
            return .warning
        } else {
            return .ok
        }
    }
}
