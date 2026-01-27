//
//  DashboardView.swift
//  LIVECOUNT
//
//  Nexus Design System — Migrated Dashboard
//

import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var showTools: Bool = false
    @State private var selectedHour: Date?
    
    // P0.3-A: Chart display mode persistence
    @AppStorage("chartDisplayMode") private var chartDisplayMode: ChartDisplayMode = .combined
    
    // History view model for historical KPIs (range != .today)
    @State private var historyViewModel: HistoryViewModel
    
    // Seeding state
    @State private var isSeeding: Bool = false
    @State private var seedingError: String?
    @State private var showSeedAlert: Bool = false
    
    init(viewModel: DashboardViewModel = DashboardViewModel()) {
        _viewModel = State(initialValue: viewModel)
        _historyViewModel = State(initialValue: HistoryViewModel(
            location: viewModel.location,
            entryStore: nil
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    
                    // P0.1.1: Hard issues banner (red alert)
                    if viewModel.hasHardIntegrityIssues && viewModel.selectedPeriod == .today {
                        hardIntegrityBanner
                            .padding(.horizontal, Nexus.Spacing.lg)
                            .padding(.top, Nexus.Spacing.md)
                    }
                    
                    // P0.1.1: Soft signals section (neutral info)
                    if viewModel.hasSoftSignals && viewModel.selectedPeriod == .today {
                        softSignalsSection
                            .padding(.horizontal, Nexus.Spacing.lg)
                            .padding(.top, Nexus.Spacing.sm)
                    }
                    
                    contentForSelectedRange
                        .padding(.horizontal, Nexus.Spacing.lg)
                        .padding(.top, Nexus.Spacing.lg)
                }
            }
            .background(Nexus.Colors.background)
            .navigationTitle("LIVECOUNT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showTools) {
                SimulatorView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                triggerHapticFeedback(.light)
                
                // P0.2: Reset offset when changing period
                viewModel.rangeOffsetDays = 0
                
                if newPeriod != .today {
                    historyViewModel.selectedRangeType = newPeriod
                    historyViewModel.rangeOffsetDays = 0  // P0.2: Also reset history VM offset
                    historyViewModel.loadMetrics()
                }
            }
            .alert("Seed Demo Data", isPresented: $showSeedAlert) {
                Button("OK") { showSeedAlert = false; seedingError = nil }
            } message: {
                Text(seedingError ?? "6 mois de données générées avec succès.")
            }
            .overlay { seedingOverlay }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: Nexus.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                    Text(viewModel.location?.name ?? "Dashboard")
                        .font(Nexus.Typography.headline)
                        .foregroundColor(Nexus.Colors.textPrimary)
                    
                    Text(viewModel.periodSubtitle)
                        .font(Nexus.Typography.caption)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
                
                Spacer()
                
                if viewModel.selectedPeriod == .today && viewModel.rangeOffsetDays == 0 {
                    liveStatusChip
                }
            }
            
            Picker("Période", selection: $viewModel.selectedPeriod) {
                ForEach(TimeRangeType.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            // P0.2: Time navigation buttons
            navigationButtons
        }
        .padding(.horizontal, Nexus.Spacing.lg)
        .padding(.vertical, Nexus.Spacing.md)
        .background(Nexus.Colors.background)
        .nexusDivider()
    }
    
    // P0.2: Navigation buttons component
    private var navigationButtons: some View {
        HStack {
            Button {
                shiftCurrentRange(by: -1)
            } label: {
                Label("Précédent", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
            
            Spacer()
            
            Button {
                shiftCurrentRange(by: 1)
            } label: {
                Label("Suivant", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
            .disabled(!canNavigateForward)
            .opacity(canNavigateForward ? 1 : 0.4)
        }
        .padding(.horizontal, Nexus.Spacing.sm)
    }
    
    // P0.2: Navigation helpers
    
    private var canNavigateForward: Bool {
        if viewModel.selectedPeriod == .today {
            return viewModel.canShiftForward
        } else {
            return historyViewModel.canShiftForward
        }
    }
    
    private func shiftCurrentRange(by step: Int) {
        triggerHapticFeedback(.light)
        
        if viewModel.selectedPeriod == .today {
            viewModel.shiftRange(by: step)
            historyViewModel.selectedRangeType = .today
            historyViewModel.rangeOffsetDays = viewModel.rangeOffsetDays
            historyViewModel.loadMetrics()
        } else {
            historyViewModel.shiftRange(by: step)
        }
    }
    
    private var liveStatusChip: some View {
        Chip(
            label: viewModel.liveStatusText,
            icon: viewModel.isLive ? "circle.fill" : "circle",
            style: viewModel.isLive ? .positive : .normal
        )
    }
    
    // MARK: - Data Integrity UI (P0.1.1: Hard Issues vs Soft Signals)
    
    /// P0.1.1: Red alert banner for HARD integrity issues (people_present < 0)
    @ViewBuilder
    private var hardIntegrityBanner: some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.xs) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Nexus.Colors.negative)  // P0.1.1: Rouge critique
                Text("Incohérence détectée")
                    .font(Nexus.Typography.bodyEmphasis)
                    .foregroundColor(Nexus.Colors.textPrimary)
            }
            
            ForEach(viewModel.dataIntegrityIssues.filter { $0.severity == .critical }) { issue in
                Text("• \(issue.message)")
                    .font(Nexus.Typography.caption)
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
        }
        .padding(Nexus.Spacing.md)
        .background(Nexus.Colors.negative.opacity(0.15))  // P0.1.1: Fond rouge clair
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Nexus.Radius.md)
                .strokeBorder(Nexus.Colors.negative, lineWidth: 2)  // P0.1.1: Bordure rouge épaisse
        )
    }
    
    /// P0.1.1: Neutral info section for SOFT flow signals (negative drain, inactivity)
    @ViewBuilder
    private var softSignalsSection: some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.xs) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Nexus.Colors.textSecondary)  // P0.1.1: Neutre
                Text("Activité")
                    .font(Nexus.Typography.caption)
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
            
            ForEach(viewModel.dataFlowSignals) { signal in
                Text("• \(signal.message)")
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.textTertiary)
            }
        }
        .padding(Nexus.Spacing.sm)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.sm))
    }
    
    // MARK: - Content Routing
    
    @ViewBuilder
    private var contentForSelectedRange: some View {
        if viewModel.selectedPeriod == .today && viewModel.rangeOffsetDays == 0 {
            liveContent
        } else {
            HistoryMetricsContent(viewModel: historyViewModel)
        }
    }
    
    // MARK: - Live Content (Today)
    
    private var liveContent: some View {
        VStack(spacing: Nexus.Spacing.xl) {
            // Hero metric: Current occupancy (dominant visual weight)
            heroOccupancyCard
            
            // Secondary metrics grid
            secondaryKPIsGrid
            
            // Combined chart
            todayCombinedChartSection
            
            // Rolling window stats
            rollingWindowSection
            
            Spacer(minLength: Nexus.Spacing.xxl)
        }
    }
    
    // MARK: - Hero Occupancy Card
    
    private var heroOccupancyCard: some View {
        VStack(spacing: Nexus.Spacing.lg) {
            // Status chip
            HStack {
                Chip(
                    label: statusLabel,
                    icon: "circle.fill",
                    style: chipStyle(for: viewModel.status)
                )
                Spacer()
            }
            
            // Main count value
            HStack(alignment: .firstTextBaseline, spacing: Nexus.Spacing.sm) {
                Text("\(viewModel.currentCount)")
                    .font(Nexus.Typography.heroNumber)
                    .foregroundColor(Nexus.Colors.status(viewModel.status))
                    .monospacedDigit()
                
                Text("/ \(viewModel.maxCapacity)")
                    .font(Nexus.Typography.mediumNumber)
                    .foregroundColor(Nexus.Colors.textTertiary)
                    .monospacedDigit()
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Nexus.Colors.surface)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Nexus.Colors.status(viewModel.status))
                        .frame(
                            width: geo.size.width * min(viewModel.occupancyPercent, 1.0),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            
            // Metrics row
            HStack(spacing: Nexus.Spacing.lg) {
                metricDetail(
                    icon: "percent",
                    label: "Occupation",
                    value: "\(Int(viewModel.occupancyPercentage))%"
                )
                
                Spacer()
                
                metricDetail(
                    icon: "person.badge.plus",
                    label: "Disponibles",
                    value: "\(viewModel.remainingSpots)"
                )
            }
        }
        .nexusCard(elevation: .medium)
    }
    
    private func metricDetail(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Nexus.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Nexus.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.textTertiary)
                
                Text(value)
                    .font(Nexus.Typography.captionEmphasis)
                    .foregroundColor(Nexus.Colors.textPrimary)
                    .monospacedDigit()
            }
        }
    }
    
    private var statusLabel: String {
        switch viewModel.status {
        case .ok: return "Normal"
        case .warning: return "Élevé"
        case .full: return "Saturé"
        }
    }
    
    private func chipStyle(for status: OccupancyStatus) -> Chip.ChipStyle {
        switch status {
        case .ok: return .positive
        case .warning: return .warning
        case .full: return .negative
        }
    }
    
    // MARK: - Secondary KPIs Grid
    
    private var secondaryKPIsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Nexus.Spacing.md),
                GridItem(.flexible(), spacing: Nexus.Spacing.md)
            ],
            spacing: Nexus.Spacing.md
        ) {
            MetricCard(
                title: "Occupation",
                value: "\(Int(viewModel.occupancyPercentage))",
                unit: "%",
                size: .medium
            )
            
            MetricCard(
                title: "Places libres",
                value: "\(viewModel.remainingSpots)",
                size: .medium
            )
        }
    }
    
    // MARK: - Combined Chart
    
    private var todayCombinedChartSection: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            VStack(alignment: .leading, spacing: Nexus.Spacing.sm) {
                HStack {
                    Text("Flux d'entrées")
                        .font(Nexus.Typography.bodyEmphasis)
                        .foregroundColor(Nexus.Colors.textPrimary)
                    Spacer()
                    Text("Aujourd'hui")
                        .font(Nexus.Typography.caption)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
                
                // P0.3-A: Chart display mode toggle
                Picker("Mode d'affichage", selection: $chartDisplayMode) {
                    ForEach(ChartDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: chartDisplayMode) { _, _ in
                    // Reset selection when changing mode
                    selectedHour = nil
                    triggerHapticFeedback(.light)
                }
                
                chartLegend
                
                if viewModel.isTodayChartLoading {
                    loadingSkeleton
                } else if isTodayChartEmpty {
                    emptyChartState
                } else {
                    combinedChart
                }
                
                // P0.1: Enhanced coverage display
                if let coverage = viewModel.coverageWindow {
                    VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                        Text(coverage.detailedDescription)
                            .font(Nexus.Typography.micro)
                            .foregroundColor(Nexus.Colors.textTertiary)
                        
                        if coverage.hasGaps {
                            HStack(spacing: Nexus.Spacing.xxs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Nexus.Colors.warning)
                                Text("Des trous ont été détectés dans le flux")
                                    .font(Nexus.Typography.micro)
                                    .foregroundColor(Nexus.Colors.warning)
                            }
                        }
                    }
                } else if let hint = viewModel.todayCoverageHint {
                    Text(hint)
                        .font(Nexus.Typography.micro)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
            }
            .padding(Nexus.Spacing.lg)
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.lg)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    // P0.3-A: Adaptive legend based on display mode
    private var chartLegend: some View {
        HStack(spacing: Nexus.Spacing.lg) {
            if chartDisplayMode == .bars || chartDisplayMode == .combined {
                legendItem(
                    color: Nexus.Colors.accent,
                    label: "Entrées / heure",
                    isLine: false
                )
            }
            if chartDisplayMode == .cumulative || chartDisplayMode == .combined {
                legendItem(
                    color: Nexus.Colors.positive.opacity(0.8),
                    label: "Cumul journée",
                    isLine: true
                )
            }
        }
    }
    
    private func legendItem(color: Color, label: String, isLine: Bool) -> some View {
        HStack(spacing: Nexus.Spacing.xs) {
            if isLine {
                Capsule()
                    .fill(color)
                    .frame(width: 20, height: 3)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            Text(label)
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textSecondary)
        }
    }
    
    private var loadingSkeleton: some View {
        RoundedRectangle(cornerRadius: Nexus.Radius.sm)
            .fill(Nexus.Colors.surface)
            .frame(height: 220)
            .shimmer()
    }
    
    private var emptyChartState: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Nexus.Colors.textDisabled)
            
            Text("Aucune donnée aujourd'hui")
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }
    
    /// P0.3-A: Chart with conditional display based on chartDisplayMode
    /// - `.bars`: Barres uniquement (axe Y gauche)
    /// - `.cumulative`: Ligne cumul uniquement (axe Y gauche)
    /// - `.combined`: Barres (axe Y gauche) + Ligne cumul (axe Y droit)
    private var combinedChart: some View {
        Group {
            switch chartDisplayMode {
            case .bars:
                barsOnlyChart
            case .cumulative:
                cumulativeOnlyChart
            case .combined:
                combinedBarsAndLineChart
            }
        }
        .frame(height: 240)
    }
    
    /// P0.3-A: Bars only mode
    private var barsOnlyChart: some View {
        Chart(viewModel.todayChartBuckets) { bucket in
            BarMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Entrées", bucket.entries),
                width: .fixed(16)
            )
            .foregroundStyle(Nexus.Colors.accent)
            
            if let selected = selectedBucket {
                RuleMark(x: .value("Sélection", selected.date))
                    .foregroundStyle(Nexus.Colors.border)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .leading) {
                        chartTooltip(for: selected)
                    }
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: normalizedBarsDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: hourLabelStride)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .foregroundStyle(Nexus.Colors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.textSecondary)
            }
        }
        .chartXSelection(value: $selectedHour)
    }
    
    /// P0.3-A: Cumulative line only mode
    private var cumulativeOnlyChart: some View {
        Chart(viewModel.todayChartBuckets) { bucket in
            let cumulValue = max(0, bucket.cumulative)
            
            LineMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Cumul", cumulValue)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            
            PointMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Cumul", cumulValue)
            )
            .foregroundStyle(Nexus.Colors.positive)
            .symbolSize(16)
            
            if let selected = selectedBucket {
                RuleMark(x: .value("Sélection", selected.date))
                    .foregroundStyle(Nexus.Colors.border)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .leading) {
                        chartTooltip(for: selected)
                    }
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: normalizedCumulativeDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: hourLabelStride)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .foregroundStyle(Nexus.Colors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            }
        }
        .chartXSelection(value: $selectedHour)
    }
    
    /// P0.3-A: Combined mode (original behavior)
    private var combinedBarsAndLineChart: some View {
        ZStack {
            todayBarChart
            todayCumulativeLineChart
        }
    }
    
    /// Barres d'entrées/heure avec axe Y à gauche (position: .leading)
    private var todayBarChart: some View {
        Chart(viewModel.todayChartBuckets) { bucket in
            BarMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Entrées", bucket.entries),
                width: .fixed(16)
            )
            .foregroundStyle(Nexus.Colors.accent)
            
            if let selected = selectedBucket {
                RuleMark(x: .value("Sélection", selected.date))
                    .foregroundStyle(Nexus.Colors.border)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .leading) {
                        chartTooltip(for: selected)
                    }
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: normalizedBarsDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: hourLabelStride)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .foregroundStyle(Nexus.Colors.textTertiary)
            }
        }
        .chartYAxis {
            // Axe Y gauche pour les barres (métrique primaire)
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Nexus.Colors.borderSubtle)
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.textSecondary)
            }
        }
        .chartXSelection(value: $selectedHour)
    }
    
    /// Ligne de cumul avec axe Y à droite (position: .trailing)
    /// Le cumul est strictement monotone croissant et jamais < 0
    private var todayCumulativeLineChart: some View {
        Chart(viewModel.todayChartBuckets) { bucket in
            // Cumul = somme progressive, jamais négatif
            let cumulValue = max(0, bucket.cumulative)
            
            LineMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Cumul", cumulValue)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            
            // Points sur la ligne pour lisibilité
            PointMark(
                x: .value("Heure", bucket.date, unit: .hour),
                y: .value("Cumul", cumulValue)
            )
            .foregroundStyle(Nexus.Colors.positive)
            .symbolSize(16)
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: normalizedCumulativeDomain)
        .chartXAxis(.hidden) // X axis déjà affiché par le chart des barres
        .chartYAxis {
            // Axe Y droit pour le cumul (métrique secondaire)
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                // Pas de gridlines pour éviter la confusion
                AxisTick()
                AxisValueLabel()
                    .foregroundStyle(Nexus.Colors.positive.opacity(0.8))
            }
        }
    }
    
    // P0.3-A: Enhanced tooltip with delta vs previous hour
    private func chartTooltip(for bucket: DashboardViewModel.HourlyEntryBucket) -> some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
            Text(hourLabel(for: bucket.date))
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textSecondary)
            
            // Show based on display mode
            if chartDisplayMode == .bars || chartDisplayMode == .combined {
                HStack {
                    Text("Entrées")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatNumber(bucket.entries))
                        if let delta = previousHourDelta(for: bucket) {
                            Text(delta.formatted)
                                .font(Nexus.Typography.micro)
                                .foregroundColor(delta.color)
                        }
                    }
                }
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textPrimary)
            }
            
            if chartDisplayMode == .cumulative || chartDisplayMode == .combined {
                HStack {
                    Text("Cumul")
                    Spacer()
                    Text(formatNumber(bucket.cumulative))
                }
                .font(Nexus.Typography.caption)
                .foregroundColor(Nexus.Colors.textPrimary)
            }
        }
        .padding(Nexus.Spacing.sm)
        .background(Nexus.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Nexus.Radius.sm)
                .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
        )
        .applyShadow(.medium)
    }
    
    // P0.3-A: Calculate delta vs previous hour
    private func previousHourDelta(for bucket: DashboardViewModel.HourlyEntryBucket) -> (formatted: String, color: Color)? {
        guard let index = viewModel.todayChartBuckets.firstIndex(where: { $0.id == bucket.id }),
              index > 0 else {
            return nil
        }
        
        let previousBucket = viewModel.todayChartBuckets[index - 1]
        let delta = bucket.entries - previousBucket.entries
        
        if delta == 0 {
            return ("=", Nexus.Colors.textTertiary)
        } else if delta > 0 {
            return ("+\(delta)", Nexus.Colors.positive)
        } else {
            return ("\(delta)", Nexus.Colors.negative)
        }
    }
    
    // Chart helpers
    private var selectedBucket: DashboardViewModel.HourlyEntryBucket? {
        guard let selectedHour else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        guard let hourStart = calendar.dateInterval(of: .hour, for: selectedHour)?.start else { return nil }
        return viewModel.todayChartBuckets.first { $0.date == hourStart }
    }
    
    private var isTodayChartEmpty: Bool {
        viewModel.todayChartBuckets.reduce(0) { $0 + $1.entries } == 0
    }
    
    private var maxEntries: Int {
        viewModel.todayChartBuckets.map(\.entries).max() ?? 0
    }
    
    private var maxCumulative: Int {
        viewModel.todayChartBuckets.map(\.cumulative).max() ?? 0
    }
    
    // P0.3-A: Normalized domains with 10% margin
    private var normalizedBarsDomain: ClosedRange<Double> {
        let max = Double(maxEntries)
        let upperBound = max > 0 ? max * 1.1 : 1.0
        return 0...upperBound
    }
    
    private var normalizedCumulativeDomain: ClosedRange<Double> {
        let max = Double(maxCumulative)
        let upperBound = max > 0 ? max * 1.1 : 1.0
        return 0...upperBound
    }
    
    private var hourLabelStride: Int {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let hours = calendar.dateComponents([.hour], from: chartXDomain.lowerBound, to: chartXDomain.upperBound).hour ?? 1
        return max(1, Int(ceil(Double(max(1, hours)) / 6.0)))
    }
    
    private var chartXDomain: ClosedRange<Date> {
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let windowHours = 8
        let windowStart = calendar.date(byAdding: .hour, value: -windowHours, to: now) ?? now
        
        if let first = viewModel.todayChartBuckets.first?.date {
            let start = max(first, windowStart)
            return start...now
        }
        
        return windowStart...now
    }
    
    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH'h'"
        return formatter.string(from: date)
    }
    
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    // MARK: - Rolling Window Section
    
    private var rollingWindowSection: some View {
        VStack(spacing: Nexus.Spacing.md) {
            SectionHeader(
                title: "Flux temps réel",
                subtitle: "5 dernières minutes"
            )
            
            HStack(spacing: Nexus.Spacing.md) {
                StatTile(
                    label: "Entrées",
                    value: "\(viewModel.entriesLastXMin)",
                    icon: "arrow.down.circle",
                    color: Nexus.Colors.positive
                )
                
                StatTile(
                    label: "Sorties",
                    value: "\(viewModel.exitsLastXMin)",
                    icon: "arrow.up.circle",
                    color: Nexus.Colors.negative
                )
                
                StatTile(
                    label: "Net",
                    value: "\(viewModel.netLastXMin)",
                    icon: "plusminus.circle",
                    color: Nexus.Colors.delta(viewModel.netLastXMin),
                    showSign: true
                )
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: { Task { await seedDemoData() } }) {
                    Label("Générer données (6 mois)", systemImage: "wand.and.stars")
                }
                .disabled(isSeeding)
                
                Button(role: .destructive, action: { Task { await clearSeededData() } }) {
                    Label("Effacer données", systemImage: "trash")
                }
                .disabled(isSeeding)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showTools = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Nexus.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Seeding Overlay
    
    @ViewBuilder
    private var seedingOverlay: some View {
        if isSeeding {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: Nexus.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Nexus.Colors.textPrimary)
                    
                    Text("Génération en cours...")
                        .font(Nexus.Typography.bodyEmphasis)
                        .foregroundColor(Nexus.Colors.textPrimary)
                }
                .padding(Nexus.Spacing.xl)
                .background(Nexus.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
                .applyShadow(.high)
            }
        }
    }
    
    // MARK: - Actions
    
    private func seedDemoData() async {
        isSeeding = true
        seedingError = nil
        
        do {
            let store = try FileEntryStore()
            let seeder = DemoDataSeeder(entryStore: store)
            
            if await seeder.hasSeededData {
                seedingError = "Données déjà présentes. Effacez d'abord."
                showSeedAlert = true
                isSeeding = false
                return
            }
            
            let locationId = viewModel.location?.id ?? "default-location"
            let maxCapacity = viewModel.location?.maxCapacity ?? 100
            
            try await seeder.seedLast6Months(locationId: locationId, maxCapacity: maxCapacity)
            
            isSeeding = false
            showSeedAlert = true
            
            if viewModel.selectedPeriod != .today {
                historyViewModel.loadMetrics()
            }
        } catch {
            seedingError = "Erreur: \(error.localizedDescription)"
            showSeedAlert = true
            isSeeding = false
        }
    }
    
    private func clearSeededData() async {
        isSeeding = true
        seedingError = nil
        
        do {
            let store = try FileEntryStore()
            let seeder = DemoDataSeeder(entryStore: store)
            
            try await seeder.clearSeededData(locationId: viewModel.location?.id ?? "default-location")
            
            isSeeding = false
            
            if viewModel.selectedPeriod != .today {
                historyViewModel.loadMetrics()
            }
        } catch {
            seedingError = "Erreur: \(error.localizedDescription)"
            showSeedAlert = true
            isSeeding = false
        }
    }
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Nexus.Colors.textDisabled.opacity(0.15),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

#Preview("With Data") {
    let location = Location(id: "1", name: "Salle Principale", maxCapacity: 100, timezone: "Europe/Paris")
    let user = User(id: "1", email: "admin@test.com", role: .admin, createdAt: Date())
    let vm = DashboardViewModel(location: location, user: user)
    vm.currentCount = 72
    return DashboardView(viewModel: vm)
}
