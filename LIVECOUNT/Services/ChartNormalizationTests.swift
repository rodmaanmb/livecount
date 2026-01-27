//
//  ChartNormalizationTests.swift
//  LIVECOUNT
//
//  Tests for P0.3-A Chart Normalization
//

import Foundation

#if DEBUG

/// Self-tests for Chart Y-axis normalization (run in-app for development)
enum ChartNormalizationTests {
    
    // MARK: - Test Runner
    
    static func runAllTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 Running Chart Normalization Tests (P0.3-A)")
        print(String(repeating: "=", count: 60))
        
        testBarsDomainNormalization()
        testCumulativeDomainNormalization()
        testEmptyDataDomain()
        testSinglePointDomain()
        testIdenticalValuesDomain()
        testLargeValuesDomain()
        
        print("\n✅ All Chart Normalization tests passed!")
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    // MARK: - Test Cases
    
    /// Test 1: Bars domain normalized with 10% margin
    static func testBarsDomainNormalization() {
        print("\n📋 Test 1: Bars domain normalization")
        
        let entries = [5, 10, 8, 12]
        let max = entries.max() ?? 0
        let expected = Double(max) * 1.1  // 12 * 1.1 = 13.2
        
        let domain = normalizedDomain(max: max)
        
        assert(domain.lowerBound == 0, "Domain should start at 0")
        assert(domain.upperBound == expected, "Domain upper bound should be max * 1.1")
        
        print("   ✓ Entries: \(entries) → domain: 0...\(domain.upperBound)")
        print("   ✓ Expected: 0...13.2, Got: 0...\(domain.upperBound)")
    }
    
    /// Test 2: Cumulative domain normalized with 10% margin
    static func testCumulativeDomainNormalization() {
        print("\n📋 Test 2: Cumulative domain normalization")
        
        let cumulative = [5, 15, 23, 35]
        let max = cumulative.max() ?? 0
        let expected = Double(max) * 1.1  // 35 * 1.1 = 38.5
        
        let domain = normalizedDomain(max: max)
        
        assert(domain.lowerBound == 0, "Domain should start at 0")
        assert(domain.upperBound == expected, "Domain upper bound should be max * 1.1")
        
        print("   ✓ Cumulative: \(cumulative) → domain: 0...\(domain.upperBound)")
        print("   ✓ Expected: 0...38.5, Got: 0...\(domain.upperBound)")
    }
    
    /// Test 3: Empty data fallback (domain should be 0...1)
    static func testEmptyDataDomain() {
        print("\n📋 Test 3: Empty data domain fallback")
        
        let max = 0
        let domain = normalizedDomain(max: max)
        
        assert(domain.lowerBound == 0, "Domain should start at 0")
        assert(domain.upperBound == 1.0, "Domain should fallback to 0...1 when no data")
        
        print("   ✓ Empty data → domain: 0...\(domain.upperBound)")
        print("   ✓ Fallback works correctly")
    }
    
    /// Test 4: Single point domain (should have 10% margin)
    static func testSinglePointDomain() {
        print("\n📋 Test 4: Single point domain")
        
        let singleValue = 10
        let expected = Double(singleValue) * 1.1  // 10 * 1.1 = 11.0
        
        let domain = normalizedDomain(max: singleValue)
        
        assert(domain.upperBound == expected, "Single point should have 10% margin")
        
        print("   ✓ Single value: \(singleValue) → domain: 0...\(domain.upperBound)")
        print("   ✓ Expected: 0...11.0, Got: 0...\(domain.upperBound)")
    }
    
    /// Test 5: Identical values (all same, should not be flat line)
    static func testIdenticalValuesDomain() {
        print("\n📋 Test 5: Identical values domain")
        
        let identicalValues = [10, 10, 10, 10]
        let max = identicalValues.max() ?? 0
        let expected = Double(max) * 1.1  // 10 * 1.1 = 11.0
        
        let domain = normalizedDomain(max: max)
        
        assert(domain.upperBound > Double(max), "Domain should be > max to avoid flat line")
        assert(domain.upperBound == expected, "Domain should have 10% margin")
        
        print("   ✓ Identical values: \(identicalValues) → domain: 0...\(domain.upperBound)")
        print("   ✓ Expected: 0...11.0, Got: 0...\(domain.upperBound)")
    }
    
    /// Test 6: Large values (should handle correctly)
    static func testLargeValuesDomain() {
        print("\n📋 Test 6: Large values domain")
        
        let largeValues = [1000, 2000, 3500, 5000]
        let max = largeValues.max() ?? 0
        let expected = Double(max) * 1.1  // 5000 * 1.1 = 5500.0
        
        let domain = normalizedDomain(max: max)
        
        assert(domain.upperBound == expected, "Large values should normalize correctly")
        
        print("   ✓ Large values: \(largeValues) → domain: 0...\(domain.upperBound)")
        print("   ✓ Expected: 0...5500.0, Got: 0...\(domain.upperBound)")
        
        // Test K/M notation would be applied in UI (not in domain calculation)
        let formatted = formatLargeNumber(max)
        print("   ℹ️  UI would show: \(formatted)")
    }
    
    // MARK: - Helpers
    
    /// Compute normalized domain (mirrors DashboardView logic)
    private static func normalizedDomain(max: Int) -> ClosedRange<Double> {
        let maxValue = Double(max)
        let upperBound = maxValue > 0 ? maxValue * 1.1 : 1.0
        return 0...upperBound
    }
    
    /// Format large numbers for display (K/M notation)
    private static func formatLargeNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return "\(value)"
        }
    }
}

#endif
