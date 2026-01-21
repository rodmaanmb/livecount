//
//  NexusDesignSystem.swift
//  LIVECOUNT
//
//  Nexus Design System — Tokens & Components
//  Professional data dashboard foundation
//

import SwiftUI

// MARK: - Design Tokens

enum Nexus {
    
    // MARK: - Spacing (8pt grid)
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Radius
    
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
    
    // MARK: - Elevation (Shadows)
    
    enum Elevation {
        case none
        case low
        case medium
        case high
        
        var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            switch self {
            case .none:
                return (Color.clear, 0, 0, 0)
            case .low:
                return (Color.black.opacity(0.05), 2, 0, 1)
            case .medium:
                return (Color.black.opacity(0.1), 8, 0, 4)
            case .high:
                return (Color.black.opacity(0.15), 16, 0, 8)
            }
        }
    }
    
    // MARK: - Colors (Light/Dark adaptive)
    
    enum Colors {
        // Surface hierarchy
        static let background = Color(uiColor: .systemBackground)
        static let surface = Color(uiColor: .secondarySystemBackground)
        static let surfaceElevated = Color(uiColor: .tertiarySystemBackground)
        
        // Borders
        static let border = Color(uiColor: .separator)
        static let borderSubtle = Color(uiColor: .separator).opacity(0.5)
        
        // Text hierarchy
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textTertiary = Color(uiColor: .tertiaryLabel)
        static let textDisabled = Color(uiColor: .quaternaryLabel)
        
        // Semantic (data meaning)
        static let positive = Color(red: 0.13, green: 0.59, blue: 0.33)
        static let negative = Color(red: 0.86, green: 0.24, blue: 0.24)
        static let warning = Color(red: 0.89, green: 0.65, blue: 0.15)
        static let info = Color(red: 0.18, green: 0.42, blue: 0.91)
        
        // Interactive
        static let accent = Color(red: 0.18, green: 0.42, blue: 0.91)
        static let accentHover = Color(red: 0.15, green: 0.36, blue: 0.78)
        
        // Status colors helper
        static func status(_ status: OccupancyStatus) -> Color {
            switch status {
            case .ok: return positive
            case .warning: return warning
            case .full: return negative
            }
        }
        
        // Delta color helper
        static func delta(_ value: Int) -> Color {
            if value > 0 { return positive }
            if value < 0 { return negative }
            return textSecondary
        }
        
        static func delta(_ value: Double) -> Color {
            if value > 0 { return positive }
            if value < 0 { return negative }
            return textSecondary
        }
    }
    
    // MARK: - Typography (Dynamic Type support)
    
    enum Typography {
        // Hero metrics
        static let heroNumber = Font.system(size: 56, weight: .semibold, design: .rounded)
        static let largeNumber = Font.system(size: 32, weight: .semibold, design: .rounded)
        static let mediumNumber = Font.system(size: 24, weight: .medium, design: .rounded)
        static let smallNumber = Font.system(size: 18, weight: .medium, design: .rounded)
        
        // Text styles
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyEmphasis = Font.system(size: 15, weight: .medium)
        static let caption = Font.system(size: 13, weight: .regular)
        static let captionEmphasis = Font.system(size: 13, weight: .medium)
        static let micro = Font.system(size: 11, weight: .regular)
        static let microEmphasis = Font.system(size: 11, weight: .medium)
        
        // Monospaced variants
        static let bodyMono = Font.system(size: 15, weight: .regular, design: .monospaced)
        static let captionMono = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
}

// MARK: - Core Components

/// MetricCard — Hero metric display with optional delta/subtitle
struct MetricCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var delta: String? = nil
    var deltaValue: Double? = nil
    var subtitle: String? = nil
    var size: MetricSize = .medium
    var elevation: Nexus.Elevation = .low
    
    enum MetricSize {
        case small, medium, large, hero
        
        var valueFont: Font {
            switch self {
            case .small: return Nexus.Typography.smallNumber
            case .medium: return Nexus.Typography.mediumNumber
            case .large: return Nexus.Typography.largeNumber
            case .hero: return Nexus.Typography.heroNumber
            }
        }
        
        var titleFont: Font {
            switch self {
            case .small: return Nexus.Typography.micro
            case .medium, .large, .hero: return Nexus.Typography.caption
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Nexus.Spacing.sm) {
            // Title
            Text(title.uppercased())
                .font(size.titleFont)
                .foregroundColor(Nexus.Colors.textTertiary)
                .tracking(0.5)
                .lineLimit(1)
            
            // Value + Unit row
            HStack(alignment: .firstTextBaseline, spacing: Nexus.Spacing.xs) {
                Text(value)
                    .font(size.valueFont)
                    .foregroundColor(Nexus.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let unit = unit {
                    Text(unit)
                        .font(Nexus.Typography.bodyEmphasis)
                        .foregroundColor(Nexus.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            
            // Delta indicator (optional)
            if let delta = delta, let deltaValue = deltaValue {
                HStack(spacing: Nexus.Spacing.xxs) {
                    Image(systemName: deltaValue > 0 ? "arrow.up" : (deltaValue < 0 ? "arrow.down" : "minus"))
                        .font(.system(size: 10, weight: .bold))
                    Text(delta)
                        .font(Nexus.Typography.captionEmphasis)
                }
                .foregroundColor(Nexus.Colors.delta(deltaValue))
            }
            
            // Subtitle (optional)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Nexus.Spacing.lg)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Nexus.Radius.lg)
                .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
        )
        .applyShadow(elevation)
    }
}

/// Chip — Compact status/category indicator
struct Chip: View {
    let label: String
    var icon: String? = nil
    var style: ChipStyle = .normal
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var action: (() -> Void)? = nil
    
    enum ChipStyle {
        case normal, positive, negative, warning, info
        
        var backgroundColor: Color {
            switch self {
            case .normal: return Nexus.Colors.surface
            case .positive: return Nexus.Colors.positive.opacity(0.15)
            case .negative: return Nexus.Colors.negative.opacity(0.15)
            case .warning: return Nexus.Colors.warning.opacity(0.15)
            case .info: return Nexus.Colors.info.opacity(0.15)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .normal: return Nexus.Colors.textPrimary
            case .positive: return Nexus.Colors.positive
            case .negative: return Nexus.Colors.negative
            case .warning: return Nexus.Colors.warning
            case .info: return Nexus.Colors.info
            }
        }
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
        .disabled(isDisabled)
    }
    
    private var chipContent: some View {
        HStack(spacing: Nexus.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
            }
            
            Text(label)
                .font(Nexus.Typography.captionEmphasis)
                .lineLimit(1)
        }
        .foregroundColor(isSelected ? Nexus.Colors.accent : style.foregroundColor)
        .padding(.horizontal, Nexus.Spacing.md)
        .padding(.vertical, Nexus.Spacing.xs)
        .background(
            isSelected
            ? Nexus.Colors.accent.opacity(0.15)
            : style.backgroundColor
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    isSelected ? Nexus.Colors.accent : Nexus.Colors.borderSubtle,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }
}

/// SectionHeader — Section title with optional action button
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Nexus.Spacing.md) {
            VStack(alignment: .leading, spacing: Nexus.Spacing.xxs) {
                Text(title.uppercased())
                    .font(Nexus.Typography.captionEmphasis)
                    .foregroundColor(Nexus.Colors.textSecondary)
                    .tracking(0.8)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Nexus.Typography.micro)
                        .foregroundColor(Nexus.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    HStack(spacing: Nexus.Spacing.xxs) {
                        Text(label)
                            .font(Nexus.Typography.captionEmphasis)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Nexus.Colors.accent)
                }
            }
        }
    }
}

/// StatTile — Compact secondary metric (perfect for 2-column grids)
struct StatTile: View {
    let label: String
    let value: String
    var icon: String? = nil
    var color: Color = Nexus.Colors.textPrimary
    var showSign: Bool = false
    
    var body: some View {
        VStack(spacing: Nexus.Spacing.sm) {
            // Icon (optional)
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(color.opacity(0.7))
            }
            
            // Value
            Text(showSign && !value.hasPrefix("-") && !value.hasPrefix("+") ? "+\(value)" : value)
                .font(Nexus.Typography.mediumNumber)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Label
            Text(label.uppercased())
                .font(Nexus.Typography.micro)
                .foregroundColor(Nexus.Colors.textTertiary)
                .tracking(0.3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Nexus.Spacing.lg)
        .padding(.horizontal, Nexus.Spacing.md)
        .background(Nexus.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Nexus.Radius.md)
                .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - ViewModifiers

extension View {
    /// Apply elevation shadow
    func applyShadow(_ elevation: Nexus.Elevation) -> some View {
        let shadow = elevation.shadow
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Standard card style
    func nexusCard(padding: CGFloat = Nexus.Spacing.lg, elevation: Nexus.Elevation = .low) -> some View {
        self
            .padding(padding)
            .background(Nexus.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Nexus.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Nexus.Radius.lg)
                    .strokeBorder(Nexus.Colors.borderSubtle, lineWidth: 1)
            )
            .applyShadow(elevation)
    }
    
    /// Standard divider
    func nexusDivider() -> some View {
        self.overlay(alignment: .bottom) {
            Rectangle()
                .fill(Nexus.Colors.borderSubtle)
                .frame(height: 1)
        }
    }
}

// MARK: - Helpers

struct NexusDivider: View {
    var body: some View {
        Rectangle()
            .fill(Nexus.Colors.borderSubtle)
            .frame(height: 1)
    }
}

// MARK: - Previews

#Preview("MetricCard") {
    VStack(spacing: Nexus.Spacing.lg) {
        MetricCard(
            title: "Occupation actuelle",
            value: "72",
            unit: "%",
            delta: "+5.2%",
            deltaValue: 5.2,
            subtitle: "vs. hier",
            size: .hero
        )
        
        HStack(spacing: Nexus.Spacing.md) {
            MetricCard(
                title: "Entrées",
                value: "234",
                delta: "+12",
                deltaValue: 12,
                size: .medium
            )
            
            MetricCard(
                title: "Places",
                value: "28",
                size: .medium
            )
        }
    }
    .padding()
    .background(Nexus.Colors.background)
}

#Preview("Chips") {
    VStack(spacing: Nexus.Spacing.lg) {
        HStack(spacing: Nexus.Spacing.sm) {
            Chip(label: "Normal")
            Chip(label: "Sélectionné", isSelected: true)
            Chip(label: "Désactivé", isDisabled: true)
        }
        
        HStack(spacing: Nexus.Spacing.sm) {
            Chip(label: "OK", icon: "checkmark.circle.fill", style: .positive)
            Chip(label: "Alerte", icon: "exclamationmark.triangle.fill", style: .warning)
            Chip(label: "Erreur", icon: "xmark.circle.fill", style: .negative)
        }
    }
    .padding()
    .background(Nexus.Colors.background)
}

#Preview("StatTiles") {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: Nexus.Spacing.md),
        GridItem(.flexible(), spacing: Nexus.Spacing.md),
        GridItem(.flexible(), spacing: Nexus.Spacing.md)
    ], spacing: Nexus.Spacing.md) {
        StatTile(label: "Entrées", value: "12", icon: "arrow.down.circle", color: Nexus.Colors.positive)
        StatTile(label: "Sorties", value: "8", icon: "arrow.up.circle", color: Nexus.Colors.negative)
        StatTile(label: "Net", value: "4", icon: "plusminus.circle", color: Nexus.Colors.info, showSign: true)
    }
    .padding()
    .background(Nexus.Colors.background)
}

#Preview("Dark Mode") {
    VStack(spacing: Nexus.Spacing.xl) {
        MetricCard(
            title: "Occupation",
            value: "72",
            unit: "%",
            delta: "+5%",
            deltaValue: 5,
            size: .large
        )
        
        SectionHeader(
            title: "Flux temps réel",
            subtitle: "5 dernières minutes"
        )
        
        HStack(spacing: Nexus.Spacing.md) {
            StatTile(label: "Entrées", value: "12", color: Nexus.Colors.positive)
            StatTile(label: "Sorties", value: "8", color: Nexus.Colors.negative)
        }
    }
    .padding()
    .background(Nexus.Colors.background)
    .preferredColorScheme(.dark)
}
