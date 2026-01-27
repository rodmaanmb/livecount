//
//  ReportingStatus.swift
//  LIVECOUNT
//
//  TICKET 1: ReportingEngine - Status global pour rapports
//

import Foundation
import SwiftUI

/// Statut global d'un rapport (OK, problème d'intégrité, données staleness, manquantes)
enum ReportingStatus: Equatable {
    case ok
    case dataIssue(reason: String)     // Hard integrity issues (P0.1.1)
    case stale(reason: String)          // Coverage gaps, staleness
    case missing(reason: String)        // No data available
    
    // MARK: - Display Properties
    
    /// Texte à afficher pour ce statut
    var displayText: String {
        switch self {
        case .ok:
            return "Données valides"
        case .dataIssue(let reason):
            return reason
        case .stale(let reason):
            return reason
        case .missing(let reason):
            return reason
        }
    }
    
    /// Couleur associée au statut (Nexus Design System)
    var color: Color {
        switch self {
        case .ok:
            return Nexus.Colors.positive
        case .dataIssue:
            return Nexus.Colors.negative
        case .stale:
            return Nexus.Colors.warning
        case .missing:
            return Nexus.Colors.textSecondary
        }
    }
    
    /// Icône SF Symbol pour ce statut
    var icon: String {
        switch self {
        case .ok:
            return "checkmark.circle.fill"
        case .dataIssue:
            return "exclamationmark.triangle.fill"
        case .stale:
            return "clock.badge.exclamationmark"
        case .missing:
            return "questionmark.circle"
        }
    }
    
    /// Priorité pour tri/comparaison (plus haut = plus grave)
    var priority: Int {
        switch self {
        case .ok:
            return 0
        case .missing:
            return 1
        case .stale:
            return 2
        case .dataIssue:
            return 3
        }
    }
    
    // MARK: - Helpers
    
    /// True si le statut indique un problème (pas .ok)
    var hasIssue: Bool {
        switch self {
        case .ok:
            return false
        case .dataIssue, .stale, .missing:
            return true
        }
    }
    
    /// Retourne le statut le plus grave entre deux statuts
    static func mostSevere(_ lhs: ReportingStatus, _ rhs: ReportingStatus) -> ReportingStatus {
        return lhs.priority > rhs.priority ? lhs : rhs
    }
}
