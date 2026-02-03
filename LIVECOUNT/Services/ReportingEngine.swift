//
//  ReportingEngine.swift
//  LIVECOUNT
//
//  TICKET 1: ReportingEngine - Domain layer pour reporting cross-vues
//

import Foundation

/// Domain layer centralisé pour calcul et formatage des métriques de reporting
/// Élimine toute logique métier dispersée dans les vues
/// Expose des modèles riches pré-formatés, prêts à render
final class ReportingEngine {
    
    // MARK: - Public API
    
    /// Génère un résumé complet pour une période
    /// - Parameters:
    ///   - snapshot: MetricsSnapshot contenant les données brutes
    ///   - maxCapacity: Capacité maximum du lieu
    /// - Returns: ReportingSummary formaté ready-to-display
    static func makeSummary(
        snapshot: MetricsSnapshot,
        maxCapacity: Int
    ) -> ReportingSummary {
        
        // Bloc "Résumé rapide"
        let totalEntries = snapshot.totalEntriesIn.formatted()
        let avgOccupancyPercent = snapshot.avgOccupancyPercent.formattedPercent(decimals: 1)
        let peakOccupancy = snapshot.peakCount.formatted()
        let peakTimestamp = snapshot.peakTimestamp?.formattedForReport(style: .peakTimestamp)
        let netChange = snapshot.netChange.formattedWithSign()
        
        // Taux de rotation = total entries / capacité (x1.0)
        let rotationRate: String
        let rawRotation: Double?
        if maxCapacity <= 0 {
            rotationRate = "—"
            rawRotation = nil
        } else {
            let daysFactor: Double
            if snapshot.timeRange.type == .today {
                daysFactor = 1.0
            } else {
                daysFactor = snapshot.daysCovered > 0 ? Double(snapshot.daysCovered) : 0
            }
            
            if daysFactor <= 0 {
                rotationRate = "—"
                rawRotation = nil
            } else {
                let rate = Double(snapshot.totalEntriesIn) / (Double(maxCapacity) * daysFactor)
                rawRotation = rate
                rotationRate = String(format: "x%.1f", rate)
            }
        }
        
        // Bloc "Couverture/Qualité"
        let coveragePeriod = formatCoveragePeriod(window: snapshot.coverageWindow)
        let status = computeStatus(snapshot: snapshot)
        
        let daysCovered: String?
        if snapshot.timeRange.type == .today {
            daysCovered = nil  // Pas de "jours couverts" en mode Journée
        } else {
            let count = snapshot.daysCovered
            daysCovered = count == 1 ? "1 jour" : "\(count) jours"
        }
        
        // Bloc "Détails"
        let totalEvents = snapshot.totalEntries.formatted()
        let totalEntriesIn = snapshot.totalEntriesIn.formatted()
        let totalExits = snapshot.totalExits.formatted()
        
        let avgEntriesPerDay: String?
        if snapshot.timeRange.type == .today {
            avgEntriesPerDay = nil  // Pas pertinent en mode Journée
        } else {
            avgEntriesPerDay = snapshot.avgEntriesPerDay.formattedDecimal(decimals: 1)
        }
        
        return ReportingSummary(
            totalEntries: totalEntries,
            rotationRate: rotationRate,
            avgOccupancyPercent: avgOccupancyPercent,
            peakOccupancy: peakOccupancy,
            peakTimestamp: peakTimestamp,
            netChange: netChange,
            coveragePeriod: coveragePeriod,
            status: status,
            daysCovered: daysCovered,
            totalEvents: totalEvents,
            totalEntriesIn: totalEntriesIn,
            totalExits: totalExits,
            avgEntriesPerDay: avgEntriesPerDay,
            rawAvgOccupancy: snapshot.avgOccupancyPercent,
            rawPeakCount: snapshot.peakCount,
            rawNetChange: snapshot.netChange,
            rawDaysCovered: snapshot.daysCovered,
            rawTotalEntriesIn: snapshot.totalEntriesIn,
            rawRotationRate: rawRotation
        )
    }
    
    /// Calcule les deltas vs période précédente
    /// - Parameter comparison: MetricsComparison contenant current + previous
    /// - Returns: ReportingDelta formaté ou nil si incomparable
    static func makeDelta(
        comparison: MetricsComparison
    ) -> ReportingDelta? {
        
        let previousSnapshot = comparison.previousSnapshot
        
        // Vérifier si la comparaison est valide
        guard previousSnapshot.totalEntries > 0 else {
            // Période précédente vide → incomparable
            return ReportingDelta(
                entriesDelta: nil,
                entriesPercentChange: nil,
                avgOccupancyDelta: nil,
                peakCountDelta: nil,
                rawEntriesDelta: 0,
                rawEntriesPercentChange: nil,
                rawAvgOccupancyDelta: 0,
                rawPeakCountDelta: 0,
                isComparable: false
            )
        }
        
        // Delta d'entrées
        let entriesDelta = comparison.entriesDelta
        let entriesDeltaFormatted = entriesDelta.formattedDelta()
        
        // Pourcentage de changement (nil si division par zéro)
        let percentChange = comparison.entriesPercentChange
        let percentChangeFormatted: String?
        if let percent = percentChange {
            let sign = percent >= 0 ? "+" : ""
            percentChangeFormatted = "(\(sign)\(percent.formattedDecimal(decimals: 1))%)"
        } else {
            percentChangeFormatted = nil
        }
        
        // Delta d'occupation (en points)
        let avgOccupancyDelta = comparison.avgOccupancyDelta
        let avgOccupancyDeltaFormatted = avgOccupancyDelta.formattedPoints(decimals: 1)
        
        // Delta du pic
        let peakCountDelta = comparison.peakCountDelta
        let peakCountDeltaFormatted = peakCountDelta.formattedDelta()
        
        return ReportingDelta(
            entriesDelta: entriesDeltaFormatted,
            entriesPercentChange: percentChangeFormatted,
            avgOccupancyDelta: avgOccupancyDeltaFormatted,
            peakCountDelta: peakCountDeltaFormatted,
            rawEntriesDelta: entriesDelta,
            rawEntriesPercentChange: percentChange,
            rawAvgOccupancyDelta: avgOccupancyDelta,
            rawPeakCountDelta: peakCountDelta,
            isComparable: true
        )
    }
    
    /// Calcule la période précédente (même durée, shifted)
    /// - Parameter range: TimeRange actuel
    /// - Returns: TimeRange de la période précédente équivalente
    static func previousRange(for range: TimeRange) -> TimeRange {
        return range.previousPeriod()
    }
    
    /// Détermine le statut global d'un rapport
    /// - Parameter snapshot: MetricsSnapshot à analyser
    /// - Returns: ReportingStatus (priorité: dataIssue > stale > missing > ok)
    static func computeStatus(
        snapshot: MetricsSnapshot
    ) -> ReportingStatus {
        
        // Priorité 1: Hard integrity issues (P0.1.1)
        if snapshot.hasHardIntegrityIssues {
            let count = snapshot.dataIntegrityIssues.filter { $0.severity == .critical }.count
            let reason = count == 1 ? "1 incohérence détectée" : "\(count) incohérences détectées"
            return .dataIssue(reason: reason)
        }
        
        // Priorité 2: Staleness (coverage gaps)
        if snapshot.coverageWindow.hasGaps {
            let gapCount = snapshot.coverageWindow.gaps.count
            let reason = gapCount == 1 ? "1 trou de données" : "\(gapCount) trous de données"
            return .stale(reason: reason)
        }
        
        // Priorité 3: Missing data
        if snapshot.totalEntries == 0 {
            return .missing(reason: "Aucune donnée disponible")
        }
        
        // Priorité 4: OK
        return .ok
    }
    
    // MARK: - Private Helpers
    
    /// Formate la période de couverture depuis DataCoverageWindow
    private static func formatCoveragePeriod(window: DataCoverageWindow) -> String {
        guard let start = window.startTimestamp, let end = window.endTimestamp else {
            return "Aucune donnée"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        
        return "\(startStr)–\(endStr)"
    }
}
