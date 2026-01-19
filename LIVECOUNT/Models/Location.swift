//
//  Location.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation

struct Location: Identifiable, Codable {
    let id: String
    var name: String
    var maxCapacity: Int
    var timezone: String
}