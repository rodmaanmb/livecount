//
//  MockEventSource.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// In-memory event source using AsyncStream
final class MockEventSource: EventStream {
    private let continuation: AsyncStream<Entry>.Continuation
    
    let events: AsyncStream<Entry>
    
    init() {
        var storedContinuation: AsyncStream<Entry>.Continuation?
        
        events = AsyncStream<Entry> { continuation in
            storedContinuation = continuation
        }
        
        self.continuation = storedContinuation!
    }
    
    /// Emit a manual event into the stream
    func emit(_ entry: Entry) {
        continuation.yield(entry)
    }
    
    deinit {
        continuation.finish()
    }
}
