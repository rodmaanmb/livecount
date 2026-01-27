//
//  ReportingSummary.swift
//  LIVECOUNT
//
//  TICKET 1: ReportingEngine - Résumé formaté ready-to-display
//

import Foundation

/// Résumé complet formaté d'une période, prêt à afficher dans l'UI
/// Tous les champs sont pré-formatés selon les spécifications du ticket P0.4
struct ReportingSummary {
    
    // MARK: - Bloc "Résumé rapide"
    
    /// Total d'entrées (in) formaté: "1,234"
    let totalEntries: String
    
    /// Occupation moyenne en pourcentage: "72.3%"
    let avgOccupancyPercent: String
    
    /// Pic d'occupation: "95"
    let peakOccupancy: String
    
    /// Timestamp du pic: "14 janv · 22h15" ou nil
    let peakTimestamp: String?
    
    /// Changement net avec signe: "+342" ou "−12"
    let netChange: String
    
    // MARK: - Bloc "Couverture/Qualité"
    
    /// Période de couverture: "10:07–14:29"
    let coveragePeriod: String
    
    /// Statut global (OK, issue, stale, missing)
    let status: ReportingStatus
    
    /// Nombre de jours couverts: "7 jours" ou nil si mode Journée
    let daysCovered: String?
    
    // MARK: - Bloc "Détails" - Table Couverture
    
    /// Total d'événements (in + out): "2,456"
    let totalEvents: String
    
    /// Total d'entrées (in): "1,234"
    let totalEntriesIn: String
    
    /// Total de sorties (out): "1,222"
    let totalExits: String
    
    /// Moyenne d'entrées par jour: "176.3" ou nil si mode Journée
    let avgEntriesPerDay: String?
    
    // MARK: - Raw Values (pour calculs, charts, etc.)
    
    /// Occupation moyenne (0.0 - 1.0+)
    let rawAvgOccupancy: Double
    
    /// Pic d'occupation (count)
    let rawPeakCount: Int
    
    /// Changement net (peut être négatif)
    let rawNetChange: Int
    
    /// Nombre de jours couverts (raw)
    let rawDaysCovered: Int
    
    /// Total d'entrées (raw)
    let rawTotalEntriesIn: Int
}
