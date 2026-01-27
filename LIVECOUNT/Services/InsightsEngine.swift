//
//  InsightsEngine.swift
//  LIVECOUNT
//
//  Rule-based insights for dashboard historical views
//

import Foundation

/// Deterministic insight ready for display with a tap-for-details explanation
struct Insight: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let rule: String
    let inputs: [String]
    let thresholds: [String]
}

/// Stateless engine that derives up to three deterministic insights by comparing
/// the active period to the previous period of identical length.
enum InsightsEngine {
    /// Generate insights for the current time range.
    /// - Parameters:
    ///   - currentSnapshot: Metrics for the active period.
    ///   - previousSnapshot: Metrics for the previous period (nil if missing).
    ///   - currentEntries: Raw entries for the active period.
    ///   - previousEntries: Raw entries for the previous period.
    ///   - currentRange: Active time range.
    ///   - previousRange: Previous time range (same duration as currentRange).
    /// - Returns: Up to 3 deterministic insights. Each rule is gated on baseline availability.
    static func generate(
        currentSnapshot: MetricsSnapshot,
        previousSnapshot: MetricsSnapshot?,
        currentEntries: [Entry],
        previousEntries: [Entry],
        currentRange: TimeRange,
        previousRange: TimeRange
    ) -> [Insight] {
        var results: [Insight] = []
        
        if let delta = makeEntriesDeltaInsight(
            currentTotal: currentSnapshot.totalEntriesIn,
            previousTotal: previousSnapshot?.totalEntriesIn
        ) {
            results.append(delta)
        }
        
        if let peak = makePeakShiftInsight(
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            currentRange: currentRange,
            previousRange: previousRange
        ) {
            results.append(peak)
        }
        
        if let concentration = makeConcentrationInsight(
            currentSnapshot: currentSnapshot,
            previousSnapshot: previousSnapshot,
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            rangeType: currentRange.type,
            currentRange: currentRange,
            previousRange: previousRange
        ) {
            results.append(concentration)
        }
        
        return Array(results.prefix(3))
    }
}

// MARK: - Rule 1: Entries Delta

private extension InsightsEngine {
    static func makeEntriesDeltaInsight(
        currentTotal: Int,
        previousTotal: Int?
    ) -> Insight? {
        guard let previousTotal, previousTotal > 0 else {
            return nil
        }
        
        let delta = currentTotal - previousTotal
        let percentChange = (Double(delta) / Double(previousTotal)) * 100.0
        let direction: String
        if delta > 0 {
            direction = "hausse"
        } else if delta < 0 {
            direction = "baisse"
        } else {
            direction = "stables"
        }
        
        let percentText = formattedPercentChange(percentChange)
        let title: String
        if delta == 0 {
            title = "Entrées stables vs période précédente (0%)"
        } else {
            title = "Entrées en \(direction) vs période précédente (\(percentText))"
        }
        
        return Insight(
            title: title,
            rule: "Delta = (actuel − précédent) / précédent",
            inputs: [
                "Actuel: \(currentTotal.formatted())",
                "Précédent: \(previousTotal.formatted())",
                "Δ brut: \(delta.formattedWithSign())"
            ],
            thresholds: [
                "Ignoré si période précédente manquante ou = 0",
                "Basé sur les entrées (in) uniquement"
            ]
        )
    }
    
    static func formattedPercentChange(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(value.formattedDecimal(decimals: 1))%"
    }
}

// MARK: - Rule 2: Peak Shift Detection

private extension InsightsEngine {
    static func makePeakShiftInsight(
        currentEntries: [Entry],
        previousEntries: [Entry],
        currentRange: TimeRange,
        previousRange: TimeRange
    ) -> Insight? {
        guard !currentEntries.isEmpty, !previousEntries.isEmpty else {
            return nil
        }
        
        let granularity = BucketGranularity(from: currentRange.type)
        let currentBuckets = bucketize(entries: currentEntries, range: currentRange, granularity: granularity)
        let previousBuckets = bucketize(entries: previousEntries, range: previousRange, granularity: granularity)
        
        guard
            let currentPeak = peakBucket(in: currentBuckets),
            let previousPeak = peakBucket(in: previousBuckets),
            currentPeak.bucket.count > 0,
            previousPeak.bucket.count > 0
        else {
            return nil
        }
        
        let shift = currentPeak.index - previousPeak.index
        guard shift != 0 else { return nil }
        
        let direction = shift < 0 ? "plus tôt" : "plus tard"
        let title = "Pic \(direction) que d'habitude"
        
        return Insight(
            title: title,
            rule: "Comparer le bucket de pic actuel vs précédent (granularité \(granularity.label))",
            inputs: [
                "Actuel: \(currentPeak.bucket.label) (\(currentPeak.bucket.count.formatted()) entrées)",
                "Précédent: \(previousPeak.bucket.label) (\(previousPeak.bucket.count.formatted()) entrées)"
            ],
            thresholds: [
                "Ecart minimal: 1 bucket",
                "En cas de pics identiques ou baseline vide: aucune alerte"
            ]
        )
    }
    
    static func bucketize(
        entries: [Entry],
        range: TimeRange,
        granularity: BucketGranularity
    ) -> [Bucket] {
        guard !entries.isEmpty else {
            return generateEmptyBuckets(range: range, granularity: granularity)
        }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var buckets: [Bucket] = []
        var cursor = granularity.alignedStart(for: range.startDate, calendar: calendar)
        
        while cursor <= range.endDate {
            let next = granularity.advance(date: cursor, calendar: calendar)
            let count = entries.filter { entry in
                entry.type == .in && entry.timestamp >= cursor && entry.timestamp < next
            }.count
            
            let label = granularity.label(for: cursor)
            buckets.append(Bucket(start: cursor, count: count, label: label))
            cursor = next
        }
        
        return buckets
    }
    
    static func generateEmptyBuckets(
        range: TimeRange,
        granularity: BucketGranularity
    ) -> [Bucket] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var buckets: [Bucket] = []
        var cursor = granularity.alignedStart(for: range.startDate, calendar: calendar)
        
        while cursor <= range.endDate {
            buckets.append(Bucket(start: cursor, count: 0, label: granularity.label(for: cursor)))
            cursor = granularity.advance(date: cursor, calendar: calendar)
        }
        
        return buckets
    }
    
    static func peakBucket(in buckets: [Bucket]) -> (bucket: Bucket, index: Int)? {
        guard !buckets.isEmpty else { return nil }
        var maxIndex = 0
        var maxCount = buckets[0].count
        
        for (idx, bucket) in buckets.enumerated() where bucket.count > maxCount {
            maxCount = bucket.count
            maxIndex = idx
        }
        
        return (buckets[maxIndex], maxIndex)
    }
}

// MARK: - Rule 3: Concentration

private extension InsightsEngine {
    static func makeConcentrationInsight(
        currentSnapshot: MetricsSnapshot,
        previousSnapshot: MetricsSnapshot?,
        currentEntries: [Entry],
        previousEntries: [Entry],
        rangeType: TimeRangeType,
        currentRange: TimeRange,
        previousRange: TimeRange
    ) -> Insight? {
        guard
            let previousSnapshot,
            previousSnapshot.totalEntriesIn > 0,
            !currentEntries.isEmpty,
            !previousEntries.isEmpty
        else {
            return nil
        }
        
        let currentTotal = currentSnapshot.totalEntriesIn
        let previousTotal = previousSnapshot.totalEntriesIn
        let withinFivePercent = abs(Double(currentTotal - previousTotal)) <= Double(previousTotal) * 0.05
        guard withinFivePercent else { return nil }
        
        let granularity = BucketGranularity(from: rangeType)
        let currentBuckets = bucketize(entries: currentEntries, range: currentRange, granularity: granularity)
        let previousBuckets = bucketize(entries: previousEntries, range: previousRange, granularity: granularity)
        
        guard
            let currentShare = topQuartileShare(from: currentBuckets),
            let previousShare = topQuartileShare(from: previousBuckets)
        else {
            return nil
        }
        
        let shareDelta = currentShare - previousShare
        guard shareDelta >= 0.10 else { return nil }
        
        let deltaPts = (shareDelta * 100).formattedDecimal(decimals: 1)
        let title = "Occupation stable mais flux plus concentré (+\(deltaPts) pts top quartile)"
        
        return Insight(
            title: title,
            rule: "Comparer la part des entrées dans les \(granularity.topQuartileLabel) de buckets les plus chargés",
            inputs: [
                "Entrées actuelles: \(currentTotal.formatted())",
                "Entrées précédentes: \(previousTotal.formatted())",
                "Top 25% actuel: \(currentShare.formattedPercent(decimals: 1) ?? "n/a")",
                "Top 25% précédent: \(previousShare.formattedPercent(decimals: 1) ?? "n/a")"
            ],
            thresholds: [
                "Total dans ±5% vs précédent",
                "Hausse ≥ 10 points de la part du top 25%",
                "Ignoré si période précédente vide"
            ]
        )
    }
    
    static func topQuartileShare(from buckets: [Bucket]) -> Double? {
        guard !buckets.isEmpty else { return nil }
        let total = buckets.reduce(0) { $0 + $1.count }
        guard total > 0 else { return nil }
        
        let sorted = buckets.map(\.count).sorted(by: >)
        let takeCount = max(1, Int(ceil(Double(sorted.count) * 0.25)))
        let topSum = sorted.prefix(takeCount).reduce(0, +)
        
        return Double(topSum) / Double(total)
    }
}

// MARK: - Bucket Helpers

private struct Bucket {
    let start: Date
    let count: Int
    let label: String
}

private enum BucketGranularity {
    case hour, day, month
    
    init(from rangeType: TimeRangeType) {
        switch rangeType {
        case .today:
            self = .hour
        case .last7Days, .last30Days:
            self = .day
        case .year:
            self = .month
        }
    }
    
    func alignedStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? date
        }
    }
    
    func advance(date: Date, calendar: Calendar) -> Date {
        switch self {
        case .hour:
            return calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
    
    func label(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        
        switch self {
        case .hour:
            formatter.dateFormat = "HH'h'"
        case .day:
            formatter.dateFormat = "dd MMM"
        case .month:
            formatter.dateFormat = "MMM yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    var label: String {
        switch self {
        case .hour: return "heure"
        case .day: return "jour"
        case .month: return "mois"
        }
    }
    
    var topQuartileLabel: String {
        switch self {
        case .hour: return "25% heures"
        case .day: return "25% jours"
        case .month: return "25% mois"
        }
    }
}
