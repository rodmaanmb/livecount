//
//  FormatHelpers.swift
//  LIVECOUNT
//
//  TICKET 1: ReportingEngine - Format helpers (DRY)
//

import Foundation
import SwiftUI

// MARK: - Report Date Styles

/// Styles de formatage de date pour rapports
enum ReportDateStyle {
    case peakTimestamp     // "14 janv · 22h15"
    case coveragePeriod    // "10:07–14:29"
    case dayMonth          // "14 janv"
    case dayMonthYear      // "14 janv 2026"
}

// MARK: - Int Extensions

extension Int {
    /// Formate un nombre entier avec séparateurs de milliers
    /// - Returns: "1,234" ou "0"
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// Formate un nombre entier avec signe explicite
    /// - Returns: "+342", "−12", ou "0" (jamais "+0" ni "−0")
    func formattedWithSign() -> String {
        if self == 0 {
            return "0"
        }
        
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "−"  // U+2212 (minus sign), pas hyphen
        
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// Formate un delta avec flèche directionnelle
    /// - Returns: "↑ 85", "↓ 12", ou "0"
    func formattedDelta() -> String {
        if self == 0 {
            return "0"
        }
        
        let arrow = self > 0 ? "↑" : "↓"
        let absValue = abs(self)
        return "\(arrow) \(absValue.formatted())"
    }
}

// MARK: - Double Extensions

extension Double {
    /// Formate un pourcentage avec nombre de décimales spécifié
    /// - Parameter decimals: Nombre de décimales (défaut: 1)
    /// - Returns: "72.3%" ou "0.0%"
    func formattedPercent(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        
        let percentValue = self * 100
        let numberString = formatter.string(from: NSNumber(value: percentValue)) ?? String(format: "%.\(decimals)f", percentValue)
        return "\(numberString)%"
    }
    
    /// Formate un delta en points (pour occupation, etc.)
    /// - Parameter decimals: Nombre de décimales (défaut: 1)
    /// - Returns: "↑ 2.3 pts", "↓ 0.5 pts", ou "0.0 pts"
    func formattedPoints(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        
        if self == 0 {
            let zeroString = formatter.string(from: NSNumber(value: 0)) ?? "0.0"
            return "\(zeroString) pts"
        }
        
        let arrow = self > 0 ? "↑" : "↓"
        let absValue = abs(self * 100)  // Convertir en points de pourcentage
        let numberString = formatter.string(from: NSNumber(value: absValue)) ?? String(format: "%.\(decimals)f", absValue)
        return "\(arrow) \(numberString) pts"
    }
    
    /// Formate un nombre décimal simple
    /// - Parameter decimals: Nombre de décimales (défaut: 1)
    /// - Returns: "176.3" ou "0.0"
    func formattedDecimal(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.\(decimals)f", self)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formate une date selon le style de rapport spécifié
    /// - Parameter style: Style de formatage
    /// - Returns: String formaté selon le style
    func formattedForReport(style: ReportDateStyle) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        
        switch style {
        case .peakTimestamp:
            // "14 janv · 22h15"
            formatter.dateFormat = "d MMM · HH'h'mm"
            return formatter.string(from: self)
            
        case .coveragePeriod:
            // "10:07–14:29" (utilisé pour intervalles)
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
            
        case .dayMonth:
            // "14 janv"
            formatter.dateFormat = "d MMM"
            return formatter.string(from: self)
            
        case .dayMonthYear:
            // "14 janv 2026"
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: self)
        }
    }
}

// MARK: - DateInterval Extensions

extension DateInterval {
    /// Formate un intervalle de temps pour couverture
    /// - Returns: "10:07–14:29"
    func formattedCoveragePeriod() -> String {
        let startStr = start.formattedForReport(style: .coveragePeriod)
        let endStr = end.formattedForReport(style: .coveragePeriod)
        return "\(startStr)–\(endStr)"
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == Double {
    /// Formate un pourcentage optionnel
    /// - Parameter decimals: Nombre de décimales (défaut: 1)
    /// - Returns: "72.3%" ou nil
    func formattedPercent(decimals: Int = 1) -> String? {
        guard let value = self else { return nil }
        return value.formattedPercent(decimals: decimals)
    }
}

extension Optional where Wrapped == Int {
    /// Formate un entier optionnel
    /// - Returns: "1,234" ou nil
    func formatted() -> String? {
        guard let value = self else { return nil }
        return value.formatted()
    }
}
