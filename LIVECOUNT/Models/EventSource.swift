//
//  EventSource.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

enum EventSource: String, Codable {
    case hardware
    case manual
    case `import`
    case simulated  // For demo/seeded data
}
