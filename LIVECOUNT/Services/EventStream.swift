//
//  EventStream.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Protocol for event stream sources
protocol EventStream {
    /// AsyncStream of Entry events
    var events: AsyncStream<Entry> { get }
    
    /// Emit a manual event (for testing/debug/admin override)
    func emit(_ entry: Entry)
}
