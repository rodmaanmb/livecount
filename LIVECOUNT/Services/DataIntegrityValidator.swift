//
//  DataIntegrityValidator.swift
//  LIVECOUNT
//
//  Created for P0.1 Data Integrity
//

import Foundation

// MARK: - Configuration

/// Configuration for data gap detection thresholds
struct DataGapConfiguration {
    /// Seuil minimal pour afficher un gap dans l'UI (info contextuelle)
    let displayThreshold: TimeInterval
    
    /// Seuil pour considérer le gap comme une issue détectable (warning/critical)
    let issueThreshold: TimeInterval
    
    /// Seuil pour considérer le gap comme inactivité attendue (ex: fermeture, nuit)
    let inactivityThreshold: TimeInterval
    
    /// Configuration par défaut: 20 min display, 60 min issue, 6h inactivité
    static let `default` = DataGapConfiguration(
        displayThreshold: 20 * 60,      // 20 minutes
        issueThreshold: 60 * 60,        // 60 minutes
        inactivityThreshold: 6 * 60 * 60 // 6 heures
    )
}

/// Severity classification for detected gaps
enum GapSeverity {
    case info          // 20–59 min: ralentissement normal (affiché, pas une issue)
    case warning       // 1–3h: gap significatif (issue)
    case critical      // 3–6h: problème majeur (issue)
    case inactivity    // > 6h: probablement fermeture/inactivité attendue (pas une issue)
}

/// Represents a detected gap with severity classification
struct ClassifiedGap {
    let interval: DateInterval
    let duration: TimeInterval
    let severity: GapSeverity
    
    var start: Date { interval.start }
    var end: Date { interval.end }
}

// MARK: - Data Integrity Validator

/// Service for validating data integrity in event streams
final class DataIntegrityValidator {
    
    // MARK: - Thresholds
    
    /// Negative count below this threshold is considered a hard integrity issue
    private static let hardNegativeThreshold: Int = -5
    
    // MARK: - Main Validation (P0.1.1: Hard Issues Only)
    
    /// P0.1.1: Validates HARD integrity issues only (proven inconsistencies)
    /// Returns only critical issues that require immediate attention (red alert banner)
    /// - Parameters:
    ///   - entries: Array of Entry events to validate
    ///   - timeRange: Time range for the validation
    /// - Returns: List of HARD integrity issues (people_present < 0 only)
    static func validate(
        entries: [Entry],
        timeRange: DateInterval
    ) -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        guard !entries.isEmpty else {
            return issues
        }
        
        let sorted = entries.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
        
        // P0.1.1: ONLY detect people_present < 0 (impossible state, HARD issue)
        let negativeIssues = detectNegativeCount(entries: sorted)
        issues.append(contentsOf: negativeIssues)
        
        // P0.1.1: Gaps and other signals moved to analyzeFlowSignals()
        
        return issues
    }
    
    // MARK: - Hard Issue Detection
    
    /// P0.1.1: Detects people_present < 0 (impossible state, HARD issue)
    /// This is the ONLY hard integrity issue we detect
    private static func detectNegativeCount(entries: [Entry]) -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        var runningCount = 0
        
        for entry in entries {
            runningCount += entry.delta
            
            guard runningCount < 0 else { continue }
            
            // Ignore small transient negatives (noise when inactive / short window)
            if runningCount > hardNegativeThreshold {
                runningCount = 0
                continue
            }
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "HH:mm"
            
            issues.append(DataIntegrityIssue(
                type: .negativeCount,
                severity: .critical,
                message: "Incohérence : compteur négatif (\(runningCount)) à \(formatter.string(from: entry.timestamp))",
                detectedAt: entry.timestamp,
                affectedTimeRange: nil
            ))
            
            // Clamp to 0 to continue validation
            runningCount = 0
        }
        
        return issues
    }
    
    /// Deduplicate issues and cap the number displayed to avoid UI spam
    /// - Parameters:
    ///   - issues: List of issues to process
    ///   - limit: Maximum number of issues to keep (most recent first)
    static func deduplicateIssues(_ issues: [DataIntegrityIssue], limit: Int = 3) -> [DataIntegrityIssue] {
        guard !issues.isEmpty else { return issues }
        
        let sorted = issues.sorted { $0.detectedAt > $1.detectedAt }
        var seen = Set<String>()
        var deduped: [DataIntegrityIssue] = []
        
        for issue in sorted {
            let key = "\(issue.type.rawValue)|\(issue.detectedAt.timeIntervalSinceReferenceDate)"
            guard seen.insert(key).inserted else { continue }
            
            deduped.append(issue)
            if deduped.count == limit { break }
        }
        
        return deduped
    }
    
    // MARK: - Soft Signal Analysis (P0.1.1)
    
    /// P0.1.1: Analyzes data flow signals (soft signals, contextual information)
    /// These are normal behaviors that don't require red alert banners
    /// - Parameters:
    ///   - entries: Array of Entry events
    ///   - timeRange: Time range for analysis
    ///   - config: Gap detection configuration
    /// - Returns: List of soft signals (negative drain, inactivity, etc.)
    static func analyzeFlowSignals(
        entries: [Entry],
        timeRange: DateInterval,
        config: DataGapConfiguration = .default
    ) -> [DataFlowSignal] {
        var signals: [DataFlowSignal] = []
        
        guard !entries.isEmpty else {
            return signals
        }
        
        // 1. Negative drain (net flow < 0, normal at end of period)
        let totalIn = entries.filter { $0.type == .in }.count
        let totalOut = entries.filter { $0.type == .out }.count
        let netFlow = totalIn - totalOut
        
        if netFlow < -10 {  // Threshold: -10 entries
            signals.append(DataFlowSignal(
                type: .negativeDrain,
                message: "Drain net: \(netFlow) entrées (sorties > entrées, normal en fin de période)",
                detectedAt: entries.last?.timestamp ?? Date(),
                affectedTimeRange: timeRange
            ))
        }
        
        // 2. Inactivity periods (gaps > threshold, normal when closed)
        let sorted = entries.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
        
        let gaps = detectGapsWithClassification(entries: sorted, config: config)
        
        for gap in gaps where gap.severity == .inactivity {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "HH:mm"
            
            let hours = Int(gap.duration / 3600)
            
            signals.append(DataFlowSignal(
                type: .inactivityPeriod,
                message: "Inactivité: \(formatter.string(from: gap.start))–\(formatter.string(from: gap.end)) (\(hours)h, club fermé ou matériel inactif)",
                detectedAt: gap.start,
                affectedTimeRange: gap.interval
            ))
        }
        
        // 3. High activity (optional, informational)
        // Future: detect peak hours, spikes, etc.
        
        return signals
    }
    
    // MARK: - Gap Detection
    
    /// Detects gaps with severity classification based on duration and context
    /// - Parameters:
    ///   - entries: Sorted array of entries
    ///   - config: Gap detection configuration
    /// - Returns: Array of classified gaps
    static func detectGapsWithClassification(
        entries: [Entry],
        config: DataGapConfiguration
    ) -> [ClassifiedGap] {
        guard entries.count > 1 else { return [] }
        
        var gaps: [ClassifiedGap] = []
        
        for i in 0..<(entries.count - 1) {
            let current = entries[i]
            let next = entries[i + 1]
            let duration = next.timestamp.timeIntervalSince(current.timestamp)
            
            // Ignore gaps below display threshold (< 20 min by default)
            guard duration >= config.displayThreshold else {
                continue
            }
            
            let interval = DateInterval(start: current.timestamp, end: next.timestamp)
            
            // Classify gap severity based on duration
            let severity: GapSeverity
            if duration >= config.inactivityThreshold {
                // Long gap (≥ 6h by default) → probably expected inactivity (closing hours, night)
                severity = .inactivity
            } else if duration >= 3 * 60 * 60 {
                // 3–6h → critical issue (major data loss)
                severity = .critical
            } else if duration >= config.issueThreshold {
                // 1–3h → warning (significant gap, needs attention)
                severity = .warning
            } else {
                // 20–59 min → info (displayed but not flagged as issue)
                severity = .info
            }
            
            gaps.append(ClassifiedGap(
                interval: interval,
                duration: duration,
                severity: severity
            ))
        }
        
        return gaps
    }
    
    /// Legacy method: Detects gaps above a threshold (for backward compatibility)
    /// - Parameters:
    ///   - entries: Sorted array of entries
    ///   - threshold: Minimum gap duration to be considered a gap
    /// - Returns: Array of detected gaps
    static func detectGaps(entries: [Entry], threshold: TimeInterval) -> [DateInterval] {
        let config = DataGapConfiguration(
            displayThreshold: threshold,
            issueThreshold: threshold,
            inactivityThreshold: 6 * 60 * 60
        )
        return detectGapsWithClassification(entries: entries, config: config)
            .map { $0.interval }
    }
    
    // MARK: - Coverage Window
    
    /// Computes the coverage window from a set of entries
    /// - Parameters:
    ///   - entries: Array of Entry events
    ///   - config: Gap detection configuration (default: .default)
    /// - Returns: DataCoverageWindow with start, end, and significant gaps (warning/critical only)
    static func computeCoverageWindow(
        entries: [Entry],
        config: DataGapConfiguration = .default
    ) -> DataCoverageWindow {
        guard !entries.isEmpty else {
            return DataCoverageWindow(
                startTimestamp: nil,
                endTimestamp: nil,
                gaps: []
            )
        }
        
        let sorted = entries.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
        
        let start = sorted.first?.timestamp
        let end = sorted.last?.timestamp
        
        // Use new classification, but only return gaps that are issues (warning/critical)
        let classifiedGaps = detectGapsWithClassification(entries: sorted, config: config)
        let significantGaps = classifiedGaps
            .filter { $0.severity == .warning || $0.severity == .critical }
            .map { $0.interval }
        
        return DataCoverageWindow(
            startTimestamp: start,
            endTimestamp: end,
            gaps: significantGaps
        )
    }
    
    // MARK: - Stale Source Detection
    
    /// Detects if a source is stale (no recent activity)
    /// - Parameters:
    ///   - lastSeenAt: Last time the source was seen
    ///   - threshold: Maximum allowed inactivity (default: 5 minutes)
    /// - Returns: DataIntegrityIssue if stale, nil otherwise
    static func detectStaleSource(
        lastSeenAt: Date?,
        threshold: TimeInterval = 5 * 60
    ) -> DataIntegrityIssue? {
        guard let lastSeen = lastSeenAt else {
            return DataIntegrityIssue(
                type: .staleSource,
                severity: .warning,
                message: "Source jamais vue",
                detectedAt: Date()
            )
        }
        
        let now = Date()
        let inactivity = now.timeIntervalSince(lastSeen)
        
        if inactivity > threshold {
            let minutes = Int(inactivity / 60)
            return DataIntegrityIssue(
                type: .staleSource,
                severity: minutes > 30 ? .critical : .warning,
                message: "Source inactive depuis \(minutes) min",
                detectedAt: now
            )
        }
        
        return nil
    }
}
