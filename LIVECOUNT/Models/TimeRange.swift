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
        let endDate: Date
        switch type {
        case .today:
            // Today: startOfDay(shifted) → endOfDay(shifted) or now if offset=0
            startDate = shiftedTodayStart
            // If offset is in the past, use end of that day; if today (offset=0), use now
            if offsetDays < 0 {
                // Past day: get end of that day (start of next day)
                endDate = calendar.date(byAdding: .day, value: 1, to: shiftedTodayStart) ?? shiftedNow
            } else {
                // Today or future: use current time
                endDate = shiftedNow
            }
            
        case .last7Days:
            // Last 7 days: today + previous 6 days
            // startOfDay(now - 6 days) → now
            startDate = calendar.date(byAdding: .day, value: -6, to: shiftedTodayStart) ?? shiftedTodayStart
            endDate = shiftedNow
            
        case .last30Days:
            // Last 30 days: today + previous 29 days
            // startOfDay(now - 29 days) → now
            startDate = calendar.date(byAdding: .day, value: -29, to: shiftedTodayStart) ?? shiftedTodayStart
            endDate = shiftedNow
            
        case .year:
            // Rolling 365 days: today + previous 364 days
            // startOfDay(now - 364 days) → now
            startDate = calendar.date(byAdding: .day, value: -364, to: shiftedTodayStart) ?? shiftedTodayStart
            endDate = shiftedNow
        }
        
        #if DEBUG
        // Debug logs - P0.2 verification
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
        if type == .today && offsetDays < 0 {
            print("   ⚠️  P0.2 FIX ACTIVE: Using end of past day instead of current time")
        }
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
        let prevEndDate = calendar.date(byAdding: .second, value: -1, to: startDate) ?? startDate
        let prevStartBase = calendar.startOfDay(for: prevEndDate)
        
        // Previous period starts (days) before that
        let prevStartDate = calendar.date(byAdding: .day, value: -days, to: prevStartBase) ?? prevStartBase
        let safePrevStart = prevStartDate <= prevEndDate ? prevStartDate : prevEndDate
        
        return TimeRange(type: type, startDate: safePrevStart, endDate: prevEndDate)
    }
    
    /// For daily view: compare with the same weekday one week earlier
    func previousWeekSameWeekday() -> TimeRange {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let duration = calendar.dateComponents([.day, .hour, .minute, .second], from: startDate, to: endDate)
        let prevStart = calendar.date(byAdding: .day, value: -7, to: startDate) ?? startDate
        let prevEnd = calendar.date(byAdding: duration, to: prevStart) ?? prevStart
        
        return TimeRange(type: type, startDate: prevStart, endDate: prevEnd)
    }
    
    // MARK: - P0.2: Unified Range Labels
    
    /// Returns a formatted range label for display
    /// - Parameter showPrefix: If true, shows prefix like "7 derniers jours ·" for current period
    /// - Returns: Formatted string like "20–26 janv", "Déc 2025", "2025", etc.
    func rangeLabel(showPrefix: Bool = false, isCurrentPeriod: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        
        switch type {
        case .today:
            formatter.dateFormat = "d MMM yyyy"
            // P0.2 FIX: Use startDate (target day) instead of endDate for label display
            // Example: offset=-1 → startDate=26 Jan 00:00, endDate=27 Jan 00:00
            // Label should show "26 Jan" (the target day), not "27 Jan" (end boundary)
            let dateStr = formatter.string(from: startDate)
            
            if isCurrentPeriod && showPrefix {
                return "Aujourd'hui · \(dateStr)"
            } else {
                return dateStr
            }
            
        case .last7Days:
            // Format: "20–26 janv" or "28 déc–3 janv"
            formatter.dateFormat = "d"
            let startDay = formatter.string(from: startDate)
            
            if startMonth == endMonth {
                // Same month: "20–26 janv"
                formatter.dateFormat = "d MMM"
                let endFormatted = formatter.string(from: endDate)
                let label = "\(startDay)–\(endFormatted)"
                return (isCurrentPeriod && showPrefix) ? "7 derniers jours · \(label)" : label
            } else {
                // Different months: "28 déc–3 janv"
                formatter.dateFormat = "d MMM"
                let startFormatted = formatter.string(from: startDate)
                let endFormatted = formatter.string(from: endDate)
                let label = "\(startFormatted)–\(endFormatted)"
                return (isCurrentPeriod && showPrefix) ? "7 derniers jours · \(label)" : label
            }
            
        case .last30Days:
            // Format: "Nov–Déc 2025" or "Déc 2025" (if same month)
            if startMonth == endMonth {
                formatter.dateFormat = "MMM yyyy"
                let label = formatter.string(from: endDate)
                return (isCurrentPeriod && showPrefix) ? "30 derniers jours · \(label)" : label
            } else if startYear == endYear {
                // Same year: "Nov–Déc 2025"
                formatter.dateFormat = "MMM"
                let startFormatted = formatter.string(from: startDate)
                let endFormatted = formatter.string(from: endDate)
                let label = "\(startFormatted)–\(endFormatted) \(endYear)"
                return (isCurrentPeriod && showPrefix) ? "30 derniers jours · \(label)" : label
            } else {
                // Different years: "Déc 2024–Janv 2025"
                formatter.dateFormat = "MMM yyyy"
                let startFormatted = formatter.string(from: startDate)
                let endFormatted = formatter.string(from: endDate)
                let label = "\(startFormatted)–\(endFormatted)"
                return (isCurrentPeriod && showPrefix) ? "30 derniers jours · \(label)" : label
            }
            
        case .year:
            // Format: "2025" or "2024–2025"
            if startYear == endYear {
                let label = "\(endYear)"
                return (isCurrentPeriod && showPrefix) ? "Année · \(label)" : label
            } else {
                let label = "\(startYear)–\(endYear)"
                return (isCurrentPeriod && showPrefix) ? "Année · \(label)" : label
            }
        }
    }
}
