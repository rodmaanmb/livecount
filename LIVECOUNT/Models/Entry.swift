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
    let userId: String
    let timestamp: Date
    let type: EntryType
    let deviceId: String
}