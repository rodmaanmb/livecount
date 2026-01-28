//
//  CSVReportBuilder.swift
//  LIVECOUNT
//
//  Generates a CSV export for the current reporting period.
//

import Foundation

enum CSVReportBuilder {
    struct TimelineRow {
        let start: Date
        let end: Date
        let entries: Int
        let exits: Int
        let net: Int
        let peopleEnd: Int
        let occupancyRateEnd: Double?
    }
    
    static func build(
        snapshot: MetricsSnapshot,
        entries: [Entry],
        timeRange: TimeRange,
        location: Location?
    ) throws -> URL {
        let venue = location?.name ?? "venue"
        let rangeLabel = timeRange.rangeLabel(showPrefix: false, isCurrentPeriod: false)
        let sanitizedLabel = sanitize("\(venue)-\(rangeLabel)")
        let fileName = "report-\(sanitizedLabel).csv"
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var lines: [String] = []
        
        // Section 1: En-tête
        lines.append("venue;range_start;range_end;coverage_start;coverage_end;data_quality")
        lines.append(
            [
                venue,
                isoString(snapshot.timeRange.startDate),
                isoString(snapshot.timeRange.endDate),
                snapshot.coverageWindow.startTimestamp.map(isoString) ?? "",
                snapshot.coverageWindow.endTimestamp.map(isoString) ?? "",
                qualityString(for: snapshot)
            ]
            .joined(separator: ";")
        )
        
        // Section 2: KPIs
        lines.append("total_entries;total_exits;net;avg_occupancy;peak_occupancy;peak_time")
        lines.append(
            [
                snapshot.totalEntriesIn.formatted(),
                snapshot.totalExits.formatted(),
                snapshot.netChange.formattedWithSign(),
                formattedPercent(snapshot.avgOccupancyPercent),
                snapshot.peakCount.formatted(),
                snapshot.peakTimestamp.map(isoString) ?? ""
            ]
            .joined(separator: ";")
        )
        
        // Section 3: Timeline
        lines.append("bucket_start;bucket_end;entries;exits;net;people_present_end;occupancy_rate_end")
        let timeline = makeTimeline(
            entries: entries,
            timeRange: timeRange,
            maxCapacity: location?.maxCapacity ?? 0
        )
        for row in timeline {
            lines.append(
                [
                    isoString(row.start),
                    isoString(row.end),
                    row.entries == 0 && row.exits == 0 && row.net == 0 ? "" : "\(row.entries)",
                    row.entries == 0 && row.exits == 0 && row.net == 0 ? "" : "\(row.exits)",
                    row.entries == 0 && row.exits == 0 && row.net == 0 ? "" : "\(row.net)",
                    row.peopleEnd == 0 ? "" : "\(row.peopleEnd)",
                    row.occupancyRateEnd.map { formattedPercent($0) } ?? ""
                ]
                .joined(separator: ";")
            )
        }
        
        let csvString = lines.joined(separator: "\n")
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Helpers

private extension CSVReportBuilder {
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    static func formattedPercent(_ ratio: Double) -> String {
        let value = max(0, ratio) * 100
        return value.formattedDecimal(decimals: 1) + "%"
    }
    
    static func sanitize(_ text: String) -> String {
        let invalid = CharacterSet.alphanumerics.inverted
        return text
            .components(separatedBy: invalid)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
    }
    
    static func qualityString(for snapshot: MetricsSnapshot) -> String {
        let status = ReportingEngine.computeStatus(snapshot: snapshot)
        switch status {
        case .ok:
            return "ok"
        case .missing(let reason):
            return "missing: \(reason)"
        case .stale(let reason):
            return "stale: \(reason)"
        case .dataIssue(let reason):
            return "issue: \(reason)"
        }
    }
    
    static func makeTimeline(
        entries: [Entry],
        timeRange: TimeRange,
        maxCapacity: Int
    ) -> [TimelineRow] {
        guard !entries.isEmpty else {
            return generateEmptyTimeline(timeRange: timeRange)
        }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let granularity = BucketGranularity(from: timeRange.type)
        var cursor = granularity.alignedStart(for: timeRange.startDate, calendar: calendar)
        var rows: [TimelineRow] = []
        var occupancy = 0
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        var index = 0
        
        while cursor < timeRange.endDate {
            let next = granularity.advance(date: cursor, calendar: calendar)
            var entriesCount = 0
            var exitsCount = 0
            var deltaSum = 0
            
            while index < sorted.count && sorted[index].timestamp < next {
                let entry = sorted[index]
                if entry.type == .in {
                    entriesCount += 1
                } else if entry.type == .out {
                    exitsCount += 1
                }
                deltaSum += entry.delta
                index += 1
            }
            
            let net = entriesCount - exitsCount
            let nextOccupancy = occupancy + deltaSum
            occupancy = clamp(nextOccupancy, min: 0, max: maxCapacity)
            let occupancyRate = maxCapacity > 0 ? Double(occupancy) / Double(maxCapacity) : nil
            
            rows.append(
                TimelineRow(
                    start: cursor,
                    end: next,
                    entries: entriesCount,
                    exits: exitsCount,
                    net: net,
                    peopleEnd: occupancy,
                    occupancyRateEnd: occupancyRate
                )
            )
            
            cursor = next
        }
        
        return rows
    }
    
    static func generateEmptyTimeline(timeRange: TimeRange) -> [TimelineRow] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let granularity = BucketGranularity(from: timeRange.type)
        var cursor = granularity.alignedStart(for: timeRange.startDate, calendar: calendar)
        var rows: [TimelineRow] = []
        
        while cursor < timeRange.endDate {
            let next = granularity.advance(date: cursor, calendar: calendar)
            rows.append(
                TimelineRow(
                    start: cursor,
                    end: next,
                    entries: 0,
                    exits: 0,
                    net: 0,
                    peopleEnd: 0,
                    occupancyRateEnd: nil
                )
            )
            cursor = next
        }
        
        return rows
    }
    
    static func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(value, max > 0 ? max : Int.max))
    }
    
    enum BucketGranularity {
        case hour, day, month
        
        init(from rangeType: TimeRangeType) {
            switch rangeType {
            case .today: self = .hour
            case .last7Days, .last30Days: self = .day
            case .year: self = .month
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
    }
}
