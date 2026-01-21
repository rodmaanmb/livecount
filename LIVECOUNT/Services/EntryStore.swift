//
//  EntryStore.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Protocol for persistent storage of Entry events
protocol EntryStore {
    /// Append a new entry to the store
    func append(_ entry: Entry) async throws
    
    /// Fetch entries within a time range, optionally filtered by location and device
    func fetch(
        timeRange: DateInterval,
        locationId: String?,
        deviceId: String?
    ) async throws -> [Entry]
}

// MARK: - No-Op Implementation (Fallback)

/// No-op implementation of EntryStore that silently ignores all operations
/// Used as a fallback when FileEntryStore initialization fails
struct NoOpEntryStore: EntryStore {
    func append(_ entry: Entry) async throws {
        // No-op: silently ignore
    }
    
    func fetch(
        timeRange: DateInterval,
        locationId: String?,
        deviceId: String?
    ) async throws -> [Entry] {
        // No-op: return empty array
        return []
    }
}
