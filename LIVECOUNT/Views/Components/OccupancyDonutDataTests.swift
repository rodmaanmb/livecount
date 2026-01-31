//
//  OccupancyDonutDataTests.swift
//  LIVECOUNT
//
//  Lightweight sanity checks for clamp logic (DEBUG only)
//

#if DEBUG

import Foundation

enum OccupancyDonutDataTests {
    static func runAll() {
        testCapacityZero()
        testOverCapacityClamp()
        print("✅ OccupancyDonutDataTests passed")
    }
    
    private static func testCapacityZero() {
        let data = OccupancyDonutData.compute(occupied: 10, capacity: 0)
        assert(data.ratio == 0, "ratio should be zero when capacity is zero")
        assert(data.percentText == "N/A", "percentText should be N/A when capacity is zero")
        assert(data.free == 0, "free should be zero when capacity is zero")
        assert(data.accessibilityLabel.contains("N/A"), "a11y should mention N/A")
        assert(!data.showRing, "ring should be hidden when capacity is zero")
    }
    
    private static func testOverCapacityClamp() {
        let data = OccupancyDonutData.compute(occupied: 120, capacity: 100)
        assert(abs(data.ratio - 1.0) < 0.0001, "ratio should clamp to 1 when over capacity")
        assert(data.free == 0, "free clamps to zero when occupied exceeds capacity")
        assert(data.percentText == "120%", "percent should reflect actual occupancy even if ring clamps")
        assert(data.overCapacityText == "+20 surcap.", "over capacity text should reflect overflow")
    }
}

#endif
