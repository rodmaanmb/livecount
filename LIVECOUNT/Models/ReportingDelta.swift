//
//  ReportingDelta.swift
//  LIVECOUNT
//
//  TICKET 1: ReportingEngine - Deltas vs période précédente (anti-ambiguïté)
//

import Foundation

/// Deltas formatés vs période précédente
/// Tous les champs sont optionnels si la comparaison n'est pas possible (division par zéro, période vide)
/// Règle: jamais "— 0", afficher "0" ou nil
struct ReportingDelta {
    
    // MARK: - Deltas Formatés
    
    /// Delta d'entrées: "↑ 85", "↓ 12", "0", ou nil si N/A
    let entriesDelta: String?
    
    /// Pourcentage de changement d'entrées: "(+6.1%)", "(−12.3%)", ou nil si N/A
    /// Nil si période précédente a 0 entrées (division par zéro)
    let entriesPercentChange: String?
    
    /// Delta d'occupation moyenne en points: "↑ 2.3 pts", "↓ 0.5 pts", "0.0 pts", ou nil
    let avgOccupancyDelta: String?
    
    /// Delta du pic d'occupation: "↑ 5", "↓ 3", "0", ou nil
    let peakCountDelta: String?
    
    // MARK: - Raw Values
    
    /// Delta d'entrées (raw)
    let rawEntriesDelta: Int
    
    /// Pourcentage de changement (raw, 0.0 - 1.0)
    let rawEntriesPercentChange: Double?
    
    /// Delta d'occupation (raw, en points de pourcentage: 0.0 - 1.0)
    let rawAvgOccupancyDelta: Double
    
    /// Delta du pic (raw)
    let rawPeakCountDelta: Int
    
    // MARK: - Comparability Flag
    
    /// True si les données permettent une comparaison valide
    /// False si période précédente est vide, incomplète, ou incomparable
    let isComparable: Bool
    
    // MARK: - Helpers
    
    /// True si au moins un delta est disponible
    var hasAnyDelta: Bool {
        entriesDelta != nil || avgOccupancyDelta != nil || peakCountDelta != nil
    }
}
