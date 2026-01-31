//
//  ChartScaler.swift
//  LIVECOUNT
//
//  Percentile-based soft capping for chart domains (anti-outlier)
//

import Foundation

struct ChartScaler {
    private let values: [Double]
    private let percentile: Double
    
    init(values: [Double], percentile: Double = 0.95) {
        self.values = values.filter { $0 > 0 }
        self.percentile = percentile
    }
    
    /// Maximum value to display (soft cap at percentile)
    var displayMax: Double {
        guard !values.isEmpty else { return 1.0 }
        let sorted = values.sorted()
        let idx = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * percentile)))
        let p = sorted[idx]
        let maxVal = sorted.last ?? 0
        // Avoid collapsing if data is flat
        return max(p, maxVal * 0.7, 1.0)
    }
    
    /// True if any value exceeds the display cap
    var isCapped: Bool {
        guard !values.isEmpty else { return false }
        return values.contains { $0 > displayMax }
    }
    
    /// Return a capped value for rendering
    func capped(_ value: Double) -> Double {
        min(value, displayMax)
    }
}
