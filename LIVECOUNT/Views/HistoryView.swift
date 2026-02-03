//
//  HistoryView.swift
//  LIVECOUNT
//
//  Nexus Design System - Historical KPIs
//

import SwiftUI
import Charts

// MARK: - Legacy History View (standalone, kept for compatibility)

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var isSeeding: Bool = false
    @State private var seedingError: String?
    @State private var showSeedAlert: Bool = false
    
    init(viewModel: HistoryViewModel = HistoryViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Period picker
                    VStack(spacing: Nexus.Spacing.md) {
                        Picker("Période", selection: $viewModel.selectedRangeType) {
                            ForEach(TimeRangeType.allCases) { rangeType in
                                Text(rangeType.rawValue).tag(rangeType)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Button {
                                viewModel.shiftRange(by: -1)
                            } label: {
                                Label("Précédent", systemImage: "chevron.left")
                                    .labelStyle(.iconOnly)
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.shiftRange(by: 1)
                            } label: {
                                Label("Suivant", systemImage: "chevron.right")
                                    .labelStyle(.iconOnly)
                            }
                            .disabled(!viewModel.canShiftForward)
                            .opacity(viewModel.canShiftForward ? 1 : 0.4)
                        }
                        .padding(.horizontal, Nexus.Spacing.sm)
                    }
                    .padding(Nexus.Spacing.lg)
                    .background(Nexus.Colors.background)
                    .overlay(alignment: .bottom) { NexusDivider() }
                    
                    // Content
                    HistoryMetricsContent(viewModel: viewModel)
                        .padding(.horizontal, Nexus.Spacing.lg)
                        .padding(.top, Nexus.Spacing.lg)
                }
            }
            .background(Nexus.Colors.background)
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.loadMetrics() }
            .onChange(of: viewModel.selectedRangeType) { _, _ in
                viewModel.rangeOffsetDays = 0
                viewModel.loadMetrics()
            }
        }
    }
}

// MARK: - Reusable History Metrics Content (Finance Dashboard Style)

/// Reusable component for displaying historical metrics
/// Used by both HistoryView and DashboardView
struct HistoryMetricsContent: View {
    @Bindable var viewModel: HistoryViewModel
    @State private var entryScrollPosition: Double = 0
    @State private var selectedInsight: Insight?
    
    // P0.3-A': Chart display mode for Entrées chart (reusing same enum as Dashboard)
    @AppStorage("historyChartDisplayMode") private var chartDisplayMode: ChartDisplayMode = .combined
    
    private var visibleSpan: Double {
        switch viewModel.selectedRangeType {
        case .today:
            return 8
        case .last7Days:
            return 7
        case .last30Days:
            return 13
        case .year:
            return 12
        }
    }
    
    private var allowsHorizontalScroll: Bool {
        switch viewModel.selectedRangeType {
        case .today, .last30Days:
            return true
        case .last7Days, .year:
            return false
        }
    }
    
    private func resetEntryScrollPositionIfNeeded() {
        guard allowsHorizontalScroll else {
            entryScrollPosition = 0
            return
        }
        if let last = viewModel.entryBuckets.last?.order {
            entryScrollPosition = Double(last)
        }
    }
    
    private var horizontalDomainPadding: Double {
        allowsHorizontalScroll ? 0.6 : 0.45
    }
    
    private var entryXDomain: ClosedRange<Double>? {
        guard let first = viewModel.entryBuckets.first?.order,
              let last = viewModel.entryBuckets.last?.order else {
            return nil
        }
        return (Double(first) - horizontalDomainPadding)...(Double(last) + horizontalDomainPadding)
    }
    
    private var maxEntryDaily: Int {
        viewModel.entryBuckets.reduce(0) { acc, bucket in
            max(acc, max(bucket.current, bucket.previous ?? 0))
        }
    }
    
    private var maxEntryCumulative: Int {
        viewModel.entryBuckets.map(\.cumulative).max() ?? 0
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if let snapshot = viewModel.currentSnapshot {
                metricsContent(snapshot: snapshot)
            } else {
                emptyView
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Nexus.Spacing.lg) {
            loadingSkeleton(height: 80)
            
            HStack(spacing: Nexus.Spacing.md) {
                loadingSkeleton(height: 100)
                loadingSkeleton(height: 100)
            }
            
            loadingSkeleton(height: 200)
        }
        .padding(.top, Nexus.Spacing.lg)
    }
    
    private func loadingSkeleton(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Nexus.Radius.sm)
            .fill(Nexus.Colors.surface)
            .frame(height: height)
            .shimmer()
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: Nexus.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Nexus.Colors.warning)
            
            Text("Erreur de chargement")
                .font(Nexus.Typography.bodyEmphasis)
                .foregroundColor(Nexus.Colors.textPrimary)
            
            Text(message)
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textTertiary)
                .multilineTextAlignment(.center)
            
            Button(action: { viewModel.loadMetrics() }) {
                Text("Réessayer")
                    .font(Nexus.Typography.bodyEmphasis)
                    .foregroundColor(Nexus.Colors.accent)
            }
            .padding(.top, Nexus.Spacing.sm)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(Nexus.Spacing.xl)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: Nexus.Spacing.md) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Nexus.Colors.textDisabled)
            
            Text("Aucune donnée sur cette période")
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
    }
    
    // MARK: - Metrics Content
    
    private func metricsContent(snapshot: MetricsSnapshot) -> some View {
        VStack(spacing: Nexus.Spacing.xl) {
            // Hero KPIs
            // TICKET 2: Résumé rapide unifié
            if let summary = viewModel.reportSummary {
                ReportSummaryCard(summary: summary)
            }
            
            if !viewModel.insights.isEmpty {
                insightsSection()
            }
            
            // Visualisations
            visualisationSection()
            
            // Qualité
            qualitySection()
            
            // Coverage section
            coverageSection(snapshot: snapshot)
            
            // Occupancy section
            occupancySection(snapshot: snapshot)
            
            // Comparison section (Ticket 4)
            ReportComparisonCard(delta: viewModel.reportDelta)
            
            Spacer(minLength: Nexus.Spacing.xxl)
        }
        .sheet(item: $selectedInsight) { insight in
            InsightDetailSheet(insight: insight)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: viewModel.insights) { _, _ in
            selectedInsight = nil
        }
    }
    
    // MARK: - Insights
    
    private func insightsSection() -> some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "Insights déterministes", subtitle: "vs période précédente")
            
            VStack(alignment: .leading, spacing: Nexus.Spacing.sm) {
                ForEach(viewModel.insights) { insight in
                    Button {
                        selectedInsight = insight
                    } label: {
                        insightRow(for: insight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Nexus.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Nexus.Colors.accent.opacity(0.16),
                        Nexus.Colors.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.md)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private func insightRow(for insight: Insight) -> some View {
        HStack(alignment: .top, spacing: Nexus.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Nexus.Colors.accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Nexus.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: Nexus.Spacing.xs) {
                Text(insight.title)
                    .font(Nexus.Typography.bodyEmphasis)
                    .foregroundColor(Nexus.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Voir le calcul et les seuils")
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Nexus.Colors.textSecondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, Nexus.Spacing.xs)
    }
    
    // MARK: - Visualisation
    
    private func visualisationSection() -> some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "Visualisation")
            
            VStack(spacing: Nexus.Spacing.md) {
                // Chart 1: Entrées journalières (barres) + Cumul (ligne)
                // Dual Y-axis: gauche = barres, droite = cumul
                entriesWithCumulChart
                
                // Chart 2: Taux de remplissage (%)
                occupancyChart
            }
        }
    }
    
    /// P0.3-A': Chart combiné avec toggle mode (Barres / Cumul / Combiné)
    /// Les barres sont la métrique primaire, la ligne est secondaire pour la tendance
    private var entriesWithCumulChart: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            chartCard(
                title: "Entrées",
                subtitle: chartDisplayModeSubtitle,
                content: {
                    VStack(spacing: Nexus.Spacing.md) {
                        // P0.3-A': Chart display mode toggle
                        Picker("Mode d'affichage", selection: $chartDisplayMode) {
                            ForEach(ChartDisplayMode.historyModes) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onAppear {
                            if !ChartDisplayMode.historyModes.contains(chartDisplayMode) {
                                chartDisplayMode = .combined
                            }
                        }
                        
                        if viewModel.entryBuckets.isEmpty {
                            emptyChartPlaceholder
                        } else {
                            dualAxisEntriesChart
                        }
                    }
                }
            )
        }
    }
    
    // P0.3-A': Dynamic subtitle based on display mode
    private var chartDisplayModeSubtitle: String {
        switch chartDisplayMode {
        case .bars, .netFlow:
            return "Barres journalières (Actuel vs Précédent)"
        case .cumulative:
            return "Cumul progressif"
        case .combined:
            return "Barres = journalier • Ligne = cumul"
        }
    }
    
    /// P0.3-A': Chart with conditional display based on chartDisplayMode
    /// - `.bars`: Barres uniquement (Actuel/Précédent)
    /// - `.cumulative`: Ligne cumul uniquement
    /// - `.combined`: Barres + Ligne (dual Y-axis, comportement original)
    @ViewBuilder
    private var dualAxisEntriesChart: some View {
        let barValues = viewModel.entryBuckets.flatMap { bucket -> [Double] in
            var arr: [Double] = [Double(bucket.current)]
            if let prev = bucket.previous { arr.append(Double(prev)) }
            return arr
        }
        let cumulValues = viewModel.entryBuckets.map { Double($0.cumulative) }
        let scalerBars = ChartScaler(values: barValues)
        let scalerCumul = ChartScaler(values: cumulValues)
        let domain = entryXDomain ?? {
            let first = Double(viewModel.entryBuckets.first?.order ?? 0)
            let last = Double(viewModel.entryBuckets.last?.order ?? 0)
            return (first - horizontalDomainPadding)...(last + horizontalDomainPadding)
        }()
        
        // Domaines Y indépendants
        let yDomainBars = 0.0...max(1.0, scalerBars.displayMax * 1.1)
        let yDomainCumul = 0.0...max(1.0, scalerCumul.displayMax * 1.1)
        
        VStack(spacing: Nexus.Spacing.xs) {
            switch chartDisplayMode {
            case .bars, .netFlow:
                // Barres seules (axe Y gauche uniquement)
                barChartLayer(domain: domain, yDomain: yDomainBars, scaler: scalerBars)
                    .onChange(of: viewModel.entryBuckets) { _, _ in
                        resetEntryScrollPositionIfNeeded()
                    }
                
            case .cumulative:
                // Ligne de cumul seule (axe Y gauche uniquement)
                cumulativeLineLayerSolo(domain: domain, yDomain: yDomainCumul, scaler: scalerCumul)
                    .onChange(of: viewModel.entryBuckets) { _, _ in
                        resetEntryScrollPositionIfNeeded()
                    }
                
            case .combined:
                // Dual-axis: barres (gauche) + cumul (droite) - comportement original
                ZStack {
                    barChartLayer(domain: domain, yDomain: yDomainBars, scaler: scalerBars)
                    cumulativeLineLayer(domain: domain, yDomain: yDomainCumul, scaler: scalerCumul)
                }
                .onChange(of: viewModel.entryBuckets) { _, _ in
                    resetEntryScrollPositionIfNeeded()
                }
            }
            
            if scalerBars.isCapped || scalerCumul.isCapped {
                Text("Capage P95 pour lisibilité (valeurs réelles dans les tooltips).")
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 200)
    }
    
    /// Layer des barres d'entrées avec axe Y à gauche
    @ViewBuilder
    private func barChartLayer(domain: ClosedRange<Double>, yDomain: ClosedRange<Double>, scaler: ChartScaler) -> some View {
        let seriesCurrent = "Actuel"
        let seriesPrevious = "Précédent"
        
        Chart {
            ForEach(viewModel.entryBuckets) { bucket in
                let base = Double(bucket.order)
                let cappedCurrent = scaler.capped(Double(bucket.current))
                
                // Barre période actuelle
                BarMark(
                    x: .value("Index", base - 0.15),
                    y: .value("Entrées", cappedCurrent),
                    width: .fixed(12)
                )
                .foregroundStyle(by: .value("Série", seriesCurrent))
                
                // Barre période précédente (optionnelle)
                if let previous = bucket.previous {
                    let cappedPrev = scaler.capped(Double(previous))
                    BarMark(
                        x: .value("Index", base + 0.15),
                        y: .value("Entrées", cappedPrev),
                        width: .fixed(12)
                    )
                    .foregroundStyle(by: .value("Série", seriesPrevious))
                }
            }
        }
        .if(allowsHorizontalScroll) { chart in
            chart.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleSpan)
                .chartScrollPosition(x: $entryScrollPosition)
        }
        .if(!allowsHorizontalScroll) { chart in
            chart.chartXScale(domain: domain)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            // Axe Y gauche pour les barres (position: .leading)
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                if let doubleVal = value.as(Double.self) {
                    let intVal = Int(doubleVal.rounded())
                    if abs(doubleVal - Double(intVal)) < 0.01,
                       let label = viewModel.entryBuckets.first(where: { $0.order == intVal })?.label {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Nexus.Colors.borderSubtle)
                        AxisTick()
                        AxisValueLabel {
                            Text(label)
                                .font(Nexus.Typography.micro)
                                .foregroundStyle(Nexus.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .chartForegroundStyleScale([
            seriesCurrent: Nexus.Colors.accent,
            seriesPrevious: Nexus.Colors.warning.opacity(0.6)
        ])
        .chartLegend(position: .top, alignment: .leading) {
            // P0.3-A': Adaptive legend based on display mode
            HStack(spacing: Nexus.Spacing.lg) {
                if chartDisplayMode == .bars || chartDisplayMode == .combined {
                    legendItem(color: Nexus.Colors.accent, label: "Actuel", isLine: false)
                    legendItem(color: Nexus.Colors.warning.opacity(0.6), label: "Précédent", isLine: false)
                }
                if chartDisplayMode == .cumulative || chartDisplayMode == .combined {
                    legendItem(color: Nexus.Colors.positive.opacity(0.8), label: "Cumul", isLine: true)
                }
            }
        }
    }
    
    /// Layer de la ligne de cumul avec axe Y à droite
    private func cumulativeLineLayer(domain: ClosedRange<Double>, yDomain: ClosedRange<Double>, scaler: ChartScaler) -> some View {
        Chart {
            ForEach(viewModel.entryBuckets) { bucket in
                // Cumul = somme progressive, monotone croissante, jamais < 0
                let cumulValue = max(0, bucket.cumulative)
                let capped = scaler.capped(Double(cumulValue))
                
                LineMark(
                    x: .value("Index", Double(bucket.order)),
                    y: .value("Cumul", capped)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                
                // Points sur la ligne pour lisibilité
                PointMark(
                    x: .value("Index", Double(bucket.order)),
                    y: .value("Cumul", capped)
                )
                .foregroundStyle(Nexus.Colors.positive)
                .symbolSize(20)
            }
        }
        .if(allowsHorizontalScroll) { chart in
            chart.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleSpan)
                .chartScrollPosition(x: $entryScrollPosition)
        }
        .if(!allowsHorizontalScroll) { chart in
            chart.chartXScale(domain: domain)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            // Axe Y droit pour le cumul (position: .trailing)
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                // Pas de grid line pour éviter la confusion visuelle
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            }
        }
        .chartXAxis(.hidden) // X axis déjà affiché par le chart des barres
        .chartLegend(.hidden) // Légende déjà affichée par le chart des barres
    }
    
    /// P0.3-A': Ligne de cumul seule (mode .cumulative) avec axe Y à gauche
    private func cumulativeLineLayerSolo(domain: ClosedRange<Double>, yDomain: ClosedRange<Double>, scaler: ChartScaler) -> some View {
        Chart {
            ForEach(viewModel.entryBuckets) { bucket in
                let cumulValue = max(0, bucket.cumulative)
                let capped = scaler.capped(Double(cumulValue))
                
                LineMark(
                    x: .value("Index", Double(bucket.order)),
                    y: .value("Cumul", capped)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                
                PointMark(
                    x: .value("Index", Double(bucket.order)),
                    y: .value("Cumul", capped)
                )
                .foregroundStyle(Nexus.Colors.positive)
                .symbolSize(20)
            }
        }
        .if(allowsHorizontalScroll) { chart in
            chart.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleSpan)
                .chartScrollPosition(x: $entryScrollPosition)
        }
        .if(!allowsHorizontalScroll) { chart in
            chart.chartXScale(domain: domain)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            // Axe Y gauche pour le cumul (position: .leading)
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                if let doubleVal = value.as(Double.self) {
                    let intVal = Int(doubleVal.rounded())
                    if abs(doubleVal - Double(intVal)) < 0.01,
                       let label = viewModel.entryBuckets.first(where: { $0.order == intVal })?.label {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Nexus.Colors.borderSubtle)
                        AxisTick()
                        AxisValueLabel {
                            Text(label)
                                .font(Nexus.Typography.micro)
                                .foregroundStyle(Nexus.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading) {
            HStack(spacing: Nexus.Spacing.lg) {
                legendItem(color: Nexus.Colors.positive.opacity(0.8), label: "Cumul", isLine: true)
            }
        }
    }
    
    /// Légende item helper
    private func legendItem(color: Color, label: String, isLine: Bool) -> some View {
        HStack(spacing: Nexus.Spacing.xs) {
            if isLine {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 16, height: 3)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(label)
                .font(Nexus.Typography.micro)
                .foregroundColor(Nexus.Colors.textSecondary)
        }
    }
    
    /// Chart taux de remplissage (%)
    private var occupancyChart: some View {
        chartCard(
            title: "Taux de remplissage",
            subtitle: "Moyenne journalière (%)",
            content: {
                if viewModel.occupancyBuckets.isEmpty {
                    emptyChartPlaceholder
                } else {
                    occupancyBarsChart
                }
            }
        )
    }
    
    @ViewBuilder
    private var occupancyBarsChart: some View {
        let seriesCurrent = "Actuel"
        let seriesPrevious = "Précédent"
        let domain = (Double(viewModel.occupancyBuckets.first?.order ?? 0) - horizontalDomainPadding)
            ... (Double(viewModel.occupancyBuckets.last?.order ?? 0) + horizontalDomainPadding)
        
        Chart {
            ForEach(viewModel.occupancyBuckets) { bucket in
                let base = Double(bucket.order)
                
                BarMark(
                    x: .value("Index", base - 0.15),
                    y: .value("Occup.", bucket.currentPercent),
                    width: .fixed(12)
                )
                .foregroundStyle(by: .value("Série", seriesCurrent))
                
                if let previous = bucket.previousPercent {
                    BarMark(
                        x: .value("Index", base + 0.15),
                        y: .value("Occup.", previous),
                        width: .fixed(12)
                    )
                    .foregroundStyle(by: .value("Série", seriesPrevious))
                }
            }
        }
        .if(allowsHorizontalScroll) { chart in
            chart.chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleSpan)
        }
        .if(!allowsHorizontalScroll) { chart in
            chart.chartXScale(domain: domain)
        }
        .chartYScale(domain: 0...100)
        .chartForegroundStyleScale([
            seriesCurrent: Nexus.Colors.accent,
            seriesPrevious: Nexus.Colors.warning.opacity(0.6)
        ])
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(Nexus.Typography.micro)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                if let doubleVal = value.as(Double.self) {
                    let intVal = Int(doubleVal.rounded())
                    if abs(doubleVal - Double(intVal)) < 0.01,
                       let label = viewModel.occupancyBuckets.first(where: { $0.order == intVal })?.label {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Nexus.Colors.borderSubtle)
                        AxisTick()
                        AxisValueLabel {
                            Text(label)
                                .font(Nexus.Typography.micro)
                                .foregroundStyle(Nexus.Colors.textTertiary)
                        }
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 200)
    }
    
    private var emptyChartPlaceholder: some View {
        Text("Aucune donnée")
            .font(Nexus.Typography.caption)
            .foregroundColor(Nexus.Colors.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }
    
    // MARK: - Qualité & Résumé
    
    private func qualitySection() -> some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "Qualité / Couverture")
            
            VStack(spacing: 0) {
                // P0.1: Enhanced coverage display
                if let snapshot = viewModel.currentSnapshot {
                    dataRow(
                        label: "Période couverte",
                        value: snapshot.coverageWindow.displayText
                    )
                    
                    // Show gaps if detected
                    if snapshot.coverageWindow.hasGaps {
                        NexusDivider()
                        VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Nexus.Colors.warning)
                                Text("Trous détectés")
                                    .font(Nexus.Typography.body)
                                    .foregroundColor(Nexus.Colors.textSecondary)
                                Spacer()
                                Text("\(snapshot.coverageWindow.gaps.count)")
                                    .font(Nexus.Typography.bodyMono)
                                    .foregroundColor(Nexus.Colors.warning)
                            }
                            
                            if let gapsDesc = snapshot.coverageWindow.gapsDescription {
                                Text(gapsDesc)
                                    .font(Nexus.Typography.micro)
                                    .foregroundColor(Nexus.Colors.textTertiary)
                                    .padding(.leading, 20)
                            }
                        }
                        .padding(.vertical, Nexus.Spacing.sm)
                        .padding(.horizontal, Nexus.Spacing.md)
                    }
                    
                    NexusDivider()
                    
                    // Data integrity issues
                    if snapshot.hasDataIssues {
                        VStack(alignment: .leading, spacing: Nexus.Spacing.xs) {
                            HStack {
                                Text("Intégrité des données")
                                    .font(Nexus.Typography.body)
                                    .foregroundColor(Nexus.Colors.textSecondary)
                                Spacer()
                                Chip(
                                    label: "\(snapshot.dataIntegrityIssues.count) problème\(snapshot.dataIntegrityIssues.count > 1 ? "s" : "")",
                                    icon: "exclamationmark.triangle.fill",
                                    style: .warning
                                )
                            }
                            
                            ForEach(snapshot.dataIntegrityIssues) { issue in
                                HStack(alignment: .top, spacing: Nexus.Spacing.xs) {
                                    Image(systemName: issue.severity == .critical ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(issue.severity == .critical ? Nexus.Colors.negative : Nexus.Colors.warning)
                                    Text(issue.message)
                                        .font(Nexus.Typography.micro)
                                        .foregroundColor(Nexus.Colors.textTertiary)
                                }
                                .padding(.leading, 20)
                            }
                        }
                        .padding(.vertical, Nexus.Spacing.sm)
                        .padding(.horizontal, Nexus.Spacing.md)
                        
                        NexusDivider()
                    }
                    
                    // Overall status
                    HStack {
                        Text("Statut global")
                            .font(Nexus.Typography.body)
                            .foregroundColor(Nexus.Colors.textSecondary)
                        Spacer()
                        if snapshot.hasDataIssues || snapshot.coverageWindow.hasGaps {
                            Chip(label: "Problèmes détectés", icon: "exclamationmark.triangle.fill", style: .warning)
                        } else {
                            Chip(label: "OK", icon: "checkmark.circle.fill", style: .positive)
                        }
                    }
                    .padding(.vertical, Nexus.Spacing.sm)
                    .padding(.horizontal, Nexus.Spacing.md)
                } else {
                    dataRow(
                        label: "Période couverte",
                        value: viewModel.coverageText ?? "n/a"
                    )
                    NexusDivider()
                    HStack {
                        Text("Cohérence (pas de négatif)")
                            .font(Nexus.Typography.body)
                            .foregroundColor(Nexus.Colors.textSecondary)
                        Spacer()
                        if viewModel.hasNegativeDrift {
                            Chip(label: "Alerte", icon: "exclamationmark.triangle.fill", style: .warning)
                        } else {
                            Chip(label: "OK", icon: "checkmark.circle.fill", style: .positive)
                        }
                    }
                    .padding(.vertical, Nexus.Spacing.sm)
                    .padding(.horizontal, Nexus.Spacing.md)
                }
            }
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.md)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.sm) {
            VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                Text(title)
                    .font(Nexus.Typography.bodyEmphasis)
                    .foregroundColor(Nexus.Colors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Nexus.Typography.micro)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
            }
            
            content()
        }
        .padding(Nexus.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Nexus.Radius.md)
                .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    // MARK: - Coverage Section
    
    private func coverageSection(snapshot: MetricsSnapshot) -> some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "Couverture")
            
            VStack(spacing: 0) {
                dataRow(label: "Événements totaux", value: formatNumber(snapshot.totalEntries))
                NexusDivider()
                dataRow(
                    label: "Entrées",
                    value: formatNumber(snapshot.totalEntriesIn),
                    valueColor: Nexus.Colors.positive
                )
                NexusDivider()
                dataRow(
                    label: "Sorties",
                    value: formatNumber(snapshot.totalExits),
                    valueColor: Nexus.Colors.negative
                )
                NexusDivider()
                dataRow(
                    label: "Variation nette",
                    value: formatDelta(snapshot.netChange),
                    valueColor: Nexus.Colors.delta(snapshot.netChange)
                )
                NexusDivider()
                dataRow(label: "Jours couverts", value: "\(snapshot.daysCovered)")
                NexusDivider()
                dataRow(label: "Moy. entrées/jour", value: String(format: "%.1f", snapshot.avgEntriesPerDay))
            }
            .padding(Nexus.Spacing.md)
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.md)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private func dataRow(label: String, value: String, valueColor: Color = Nexus.Colors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(Nexus.Typography.body)
                .foregroundColor(Nexus.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(Nexus.Typography.bodyMono)
                .foregroundColor(valueColor)
        }
        .padding(.vertical, Nexus.Spacing.sm)
    }
    
    // MARK: - Occupancy Section
    
    private func occupancySection(snapshot: MetricsSnapshot) -> some View {
        VStack(spacing: Nexus.Spacing.sm) {
            SectionHeader(title: "Occupation")
            
            VStack(spacing: 0) {
                dataRow(
                    label: "Occupation moyenne",
                    value: String(format: "%.1f%%", snapshot.avgOccupancyPercent * 100)
                )
                NexusDivider()
                dataRow(
                    label: "Pic d'occupation",
                    value: "\(snapshot.peakCount)",
                    valueColor: snapshot.peakCount > 0 ? Nexus.Colors.warning : Nexus.Colors.textPrimary
                )
                
                if let peakTimestamp = snapshot.peakTimestamp {
                    NexusDivider()
                    HStack {
                        Text("Moment du pic")
                            .font(Nexus.Typography.body)
                            .foregroundColor(Nexus.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(formatTimestamp(peakTimestamp))
                            .font(Nexus.Typography.body)
                            .foregroundColor(Nexus.Colors.textPrimary)
                    }
                    .padding(.vertical, Nexus.Spacing.sm)
                }
            }
            .padding(Nexus.Spacing.md)
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.md)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Formatters
    
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func formatDelta(_ value: Int) -> String {
        let formatted = formatNumber(abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "−\(formatted)" }
        return formatted
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}

#Preview("Metrics Content") {
    ScrollView {
        HistoryMetricsContent(viewModel: HistoryViewModel())
            .padding()
    }
    .background(Nexus.Colors.background)
}

// MARK: - Conditional Modifier Helper

private extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Insight Detail Sheet

struct InsightDetailSheet: View {
    let insight: Insight
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Nexus.Spacing.lg) {
                Text(insight.title)
                    .font(Nexus.Typography.headline)
                    .foregroundColor(Nexus.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                detailBlock(title: "Règle", lines: [insight.rule])
                detailBlock(title: "Inputs", lines: insight.inputs)
                detailBlock(title: "Seuils", lines: insight.thresholds)
            }
            .padding(Nexus.Spacing.xl)
        }
        .background(Nexus.Colors.background)
    }
    
    private func detailBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.xs) {
            Text(title)
                .font(Nexus.Typography.captionEmphasis)
                .foregroundColor(Nexus.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: Nexus.Spacing.xs) {
                        Circle()
                            .fill(Nexus.Colors.accent.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                        
                        Text(line)
                            .font(Nexus.Typography.body)
                            .foregroundColor(Nexus.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Nexus.Spacing.md)
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.md)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
}
