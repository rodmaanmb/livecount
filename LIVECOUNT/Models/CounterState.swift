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
}