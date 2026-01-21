//
//  TimeRange.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Time range type for history queries
enum TimeRangeType: String, CaseIterable, Identifiable {
    case today = "Journée"
    case last7Days = "7 derniers jours"
    case last30Days = "30 derniers jours"
    case year = "Année"
    
    var id: String { rawValue }
}

/// Represents a time range for querying entries
struct TimeRange {
    let type: TimeRangeType
    let startDate: Date
    let endDate: Date
    
    var interval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }
    
    /// Create a time range from a preset type
    /// - Parameter type: The preset type (today, last 7 days, last 30 days, year)
    /// - Parameter offsetDays: Shift the entire window by N days (negative = past)
    /// - Parameter timezone: The timezone to use for date calculations (defaults to current)
    /// - Returns: A TimeRange with startDate = startOfDay and endDate = now
    /// - Note: This method computes dates fresh each time it's called (not cached)
    static func from(type: TimeRangeType, offsetDays: Int = 0, timezone: TimeZone = .current) -> TimeRange {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        let now = Date()
        let shiftedNow = calendar.date(byAdding: .day, value: offsetDays, to: now) ?? now
        let shiftedTodayStart = calendar.startOfDay(for: shiftedNow)
        
        let startDate: Date
        let endDate: Date = shiftedNow
        switch type {
        case .today:
            // Today: startOfDay(now) → now
            startDate = shiftedTodayStart
            
        case .last7Days:
            // Last 7 days: today + previous 6 days
            // startOfDay(now - 6 days) → now
            startDate = calendar.date(byAdding: .day, value: -6, to: shiftedTodayStart)!
            
        case .last30Days:
            // Last 30 days: today + previous 29 days
            // startOfDay(now - 29 days) → now
            startDate = calendar.date(byAdding: .day, value: -29, to: shiftedTodayStart)!
            
        case .year:
            // Rolling 365 days: today + previous 364 days
            // startOfDay(now - 364 days) → now
            startDate = calendar.date(byAdding: .day, value: -364, to: shiftedTodayStart)!
        }
        
        #if DEBUG
        // Debug logs
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = timezone
        
        print("\n🗓️  [TimeRange.from] Creating \(type.rawValue) offset \(offsetDays)j:")
        print("   • Now (local): \(formatter.string(from: shiftedNow))")
        print("   • Now (UTC): \(shiftedNow)")
        print("   • StartDate (local): \(formatter.string(from: startDate))")
        print("   • StartDate (UTC): \(startDate)")
        print("   • EndDate (local): \(formatter.string(from: endDate))")
        print("   • EndDate (UTC): \(endDate)")
        print("   • Timezone: \(timezone.identifier)")
        #endif
        
        return TimeRange(type: type, startDate: startDate, endDate: endDate)
    }
    
    /// Get the previous period of the same duration for comparison
    /// - Returns: A TimeRange for the previous period
    func previousPeriod() -> TimeRange {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let duration = calendar.dateComponents([.day], from: startDate, to: endDate)
        
        guard let days = duration.day else {
            return TimeRange(type: type, startDate: startDate, endDate: startDate)
        }
        
        // Previous period ends where current period starts (exclusive)
        let prevEndDate = calendar.date(byAdding: .second, value: -1, to: startDate)!
        
        // Previous period starts (days) before that
        let prevStartDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: prevEndDate))!
        
        return TimeRange(type: type, startDate: prevStartDate, endDate: prevEndDate)
    }
}
