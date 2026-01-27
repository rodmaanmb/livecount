//
//  ReportSummaryCard.swift
//  LIVECOUNT
//
//  TICKET 2: Component réutilisable "Résumé rapide" (cross-vues)
//

import SwiftUI

/// Bloc "Résumé rapide" unifié affichant les 4 KPI clés
/// Utilise ReportingSummary (TICKET 1) pour formatage cohérent
struct ReportSummaryCard: View {
    let summary: ReportingSummary
    
    var body: some View {
        VStack(spacing: Nexus.Spacing.md) {
            // Header
            HStack {
                Text("Résumé rapide")
                    .font(Nexus.Typography.headline)
                    .foregroundColor(Nexus.Colors.textPrimary)
                Spacer()
            }
            
            // Grid 2x2 des KPIs
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Nexus.Spacing.md),
                    GridItem(.flexible(), spacing: Nexus.Spacing.md)
                ],
                spacing: Nexus.Spacing.md
            ) {
                // KPI 1: Total entrées
                MetricCard(
                    title: "Total entrées",
                    value: summary.totalEntries,
                    size: .large
                )
                
                // KPI 2: Occupation moyenne
                MetricCard(
                    title: "Occupation moy.",
                    value: summary.avgOccupancyPercent,
                    size: .large
                )
                
                // KPI 3: Pic d'occupation
                MetricCard(
                    title: "Pic d'occupation",
                    value: summary.peakOccupancy,
                    subtitle: summary.peakTimestamp,
                    size: .medium
                )
                
                // KPI 4: Variation nette
                MetricCard(
                    title: "Variation nette",
                    value: summary.netChange,
                    valueColor: deltaColor(for: summary.rawNetChange),
                    size: .medium
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Détermine la couleur du delta selon le signe
    private func deltaColor(for value: Int) -> Color {
        if value > 0 {
            return Nexus.Colors.positive
        } else if value < 0 {
            return Nexus.Colors.negative
        } else {
            return Nexus.Colors.textSecondary
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ReportSummaryCard - Nominal") {
    let now = Date()
    
    let summary = ReportingSummary(
        totalEntries: "1,234",
        avgOccupancyPercent: "72,3%",
        peakOccupancy: "95",
        peakTimestamp: "14 janv · 22h15",
        netChange: "+342",
        coveragePeriod: "10:07–14:29",
        status: .ok,
        daysCovered: "7 jours",
        totalEvents: "2,456",
        totalEntriesIn: "1,234",
        totalExits: "1,222",
        avgEntriesPerDay: "176,3",
        rawAvgOccupancy: 0.723,
        rawPeakCount: 95,
        rawNetChange: 342,
        rawDaysCovered: 7,
        rawTotalEntriesIn: 1234
    )
    
    ReportSummaryCard(summary: summary)
        .padding()
}

#Preview("ReportSummaryCard - Empty Data") {
    let summary = ReportingSummary(
        totalEntries: "0",
        avgOccupancyPercent: "0,0%",
        peakOccupancy: "0",
        peakTimestamp: nil,
        netChange: "0",
        coveragePeriod: "Aucune donnée",
        status: .missing(reason: "Aucune donnée disponible"),
        daysCovered: nil,
        totalEvents: "0",
        totalEntriesIn: "0",
        totalExits: "0",
        avgEntriesPerDay: nil,
        rawAvgOccupancy: 0.0,
        rawPeakCount: 0,
        rawNetChange: 0,
        rawDaysCovered: 0,
        rawTotalEntriesIn: 0
    )
    
    ReportSummaryCard(summary: summary)
        .padding()
}

#Preview("ReportSummaryCard - Negative Net") {
    let now = Date()
    
    let summary = ReportingSummary(
        totalEntries: "1,234",
        avgOccupancyPercent: "68,5%",
        peakOccupancy: "90",
        peakTimestamp: "13 janv · 18h45",
        netChange: "−85",
        coveragePeriod: "09:15–23:30",
        status: .ok,
        daysCovered: "7 jours",
        totalEvents: "2,500",
        totalEntriesIn: "1,234",
        totalExits: "1,319",
        avgEntriesPerDay: "176,3",
        rawAvgOccupancy: 0.685,
        rawPeakCount: 90,
        rawNetChange: -85,
        rawDaysCovered: 7,
        rawTotalEntriesIn: 1234
    )
    
    ReportSummaryCard(summary: summary)
        .padding()
}
#endif
