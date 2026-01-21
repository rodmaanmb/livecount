//
//  Entry.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation

struct Entry: Identifiable, Codable {
    let id: String
    let locationId: String
    let userId: String?
    let timestamp: Date
    let type: EntryType
    let delta: Int // +1 or -1 (must match type)
    let deviceId: String
    let source: EventSource
    let sequenceNumber: Int?
}