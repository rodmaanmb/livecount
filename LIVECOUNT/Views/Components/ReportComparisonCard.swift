//
//  ReportComparisonCard.swift
//  LIVECOUNT
//
//  Ticket 4: Comparaison vs période précédente (anti-ambiguïté)
//

import SwiftUI

struct ReportComparisonCard: View {
    let delta: ReportingDelta?
    
    var body: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "vs. Période précédente")
            
            if let delta, delta.isComparable {
                VStack(spacing: 0) {
                    comparisonRow(
                        label: "Entrées",
                        delta: delta.entriesDelta ?? "0",
                        percent: delta.entriesPercentChange
                    )
                    
                    NexusDivider()
                    
                    comparisonRow(
                        label: "Occupation moy.",
                        delta: delta.avgOccupancyDelta ?? "0",
                        percent: nil
                    )
                    
                    NexusDivider()
                    
                    comparisonRow(
                        label: "Pic d'occupation",
                        delta: delta.peakCountDelta ?? "0",
                        percent: nil
                    )
                }
                .padding(Nexus.Spacing.md)
                .nexusCard()
            } else {
                notComparableView
            }
        }
    }
    
    private func comparisonRow(label: String, delta: String, percent: String?) -> some View {
        HStack {
            Text(label)
                .font(Nexus.Typography.body)
                .foregroundColor(Nexus.Colors.textSecondary)
            
            Spacer()
            
            HStack(spacing: Nexus.Spacing.xs) {
                Text(delta)
                    .font(Nexus.Typography.bodyMono)
                
                if let pct = percent {
                    Text(pct)
                        .font(Nexus.Typography.micro)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
            }
            .foregroundColor(deltaColor(from: delta))
        }
        .padding(.vertical, Nexus.Spacing.sm)
    }
    
    private var notComparableView: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 24))
                .foregroundColor(Nexus.Colors.textDisabled)
            
            Text("Données insuffisantes pour comparaison")
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .nexusCard()
    }
    
    private func deltaColor(from text: String) -> Color {
        if text.contains("↑") || text.hasPrefix("+") {
            return Nexus.Colors.positive
        } else if text.contains("↓") || text.hasPrefix("−") {
            return Nexus.Colors.negative
        } else {
            return Nexus.Colors.textPrimary
        }
    }
}

#if DEBUG
#Preview {
    let delta = ReportingDelta(
        entriesDelta: "↑ 12",
        entriesPercentChange: "+3.2%",
        avgOccupancyDelta: "↓ 0.2 pts",
        peakCountDelta: "0",
        rawEntriesDelta: 12,
        rawEntriesPercentChange: 0.032,
        rawAvgOccupancyDelta: -0.2,
        rawPeakCountDelta: 0,
        isComparable: true
    )
    ReportComparisonCard(delta: delta)
        .padding()
}

#Preview("Non comparable") {
    ReportComparisonCard(delta: nil)
        .padding()
}
#endif
