//
//  DataIntegrityIssue.swift
//  LIVECOUNT
//
//  Created for P0.1 Data Integrity
//  P0.1.1: Redéfinition Hard Issues vs Soft Signals
//

import Foundation

// MARK: - Hard Issues (Critical Integrity Problems)

/// P0.1.1: Represents a HARD integrity issue (requires immediate attention)
/// Hard issues are proven inconsistencies like people_present < 0
/// These trigger red alert banners in the UI
struct DataIntegrityIssue: Identifiable, Codable {
    let id: UUID
    let type: IssueType
    let severity: Severity
    let message: String
    let detectedAt: Date
    let affectedTimeRange: DateInterval?
    
    init(
        id: UUID = UUID(),
        type: IssueType,
        severity: Severity,
        message: String,
        detectedAt: Date,
        affectedTimeRange: DateInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.message = message
        self.detectedAt = detectedAt
        self.affectedTimeRange = affectedTimeRange
    }
    
    enum IssueType: String, Codable {
        case negativeCount  // P0.1.1: people_present < 0 (impossible state, HARD issue)
        case dataGap        // TODO P0.1.1: Migrate to DataFlowSignal (soft signal)
        case staleSource    // TODO P0.1.1: Migrate to DataFlowSignal (soft signal)
    }
    
    enum Severity: String, Codable {
        case warning        // TODO P0.1.1: Migrate to DataFlowSignal
        case critical       // P0.1.1: Only severity for hard issues (red alert banner)
    }
}

/// Represents the coverage window of event data with gap detection
struct DataCoverageWindow: Codable {
    let startTimestamp: Date?
    let endTimestamp: Date?
    let gaps: [DateInterval]
    
    init(
        startTimestamp: Date? = nil,
        endTimestamp: Date? = nil,
        gaps: [DateInterval] = []
    ) {
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.gaps = gaps
    }
    
    /// Returns true if there are any gaps detected
    var hasGaps: Bool {
        !gaps.isEmpty
    }
    
    /// Returns true if there are any integrity issues (gaps or missing data)
    var hasIssues: Bool {
        hasGaps || (startTimestamp == nil && endTimestamp == nil)
    }
    
    /// Formatted display text: "10:07–14:29"
    var displayText: String {
        guard let start = startTimestamp, let end = endTimestamp else {
            return "Aucune donnée"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }
    
    /// Description of gaps if any: "Trous: 11:34–11:42, 13:15–13:18"
    var gapsDescription: String? {
        guard !gaps.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        
        let gapStrings = gaps.map { gap in
            "\(formatter.string(from: gap.start))–\(formatter.string(from: gap.end))"
        }
        
        return "Trous: \(gapStrings.joined(separator: ", "))"
    }
    
    /// Detailed description including coverage and gaps
    var detailedDescription: String {
        var parts: [String] = []
        
        if startTimestamp != nil && endTimestamp != nil {
            parts.append("Couverture: \(displayText)")
        } else {
            parts.append("Aucune donnée")
        }
        
        if let gapsDesc = gapsDescription {
            parts.append(gapsDesc)
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Soft Signals (Contextual Information)

/// P0.1.1: Represents a SOFT flow signal (normal behavior, contextual info)
/// Soft signals are expected patterns like negative drain (end of day), inactivity (closed hours)
/// These display in neutral info sections, NOT red alert banners
struct DataFlowSignal: Identifiable, Codable {
    let id: UUID
    let type: SignalType
    let message: String
    let detectedAt: Date
    let affectedTimeRange: DateInterval?
    
    init(
        id: UUID = UUID(),
        type: SignalType,
        message: String,
        detectedAt: Date,
        affectedTimeRange: DateInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.message = message
        self.detectedAt = detectedAt
        self.affectedTimeRange = affectedTimeRange
    }
    
    enum SignalType: String, Codable {
        case negativeDrain    // Net flow < 0 (more exits than entries, normal at end of period)
        case inactivityPeriod // No events for extended period (closed hours, normal)
        case highActivity     // Peak activity (informational, positive)
    }
}
