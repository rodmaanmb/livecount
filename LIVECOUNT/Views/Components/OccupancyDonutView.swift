//
//  OccupancyDonutView.swift
//  LIVECOUNT
//
//  Visual donut for occupied vs free seats (Dashboard, Journée)
//

import SwiftUI
import UIKit

struct OccupancyDonutView: View {
    let occupied: Int
    let capacity: Int
    
    private var data: OccupancyDonutData {
        OccupancyDonutData.compute(occupied: occupied, capacity: capacity)
    }
    
    var body: some View {
        VStack {
            ZStack {
                ringLayer
                ticksLayer
                centerContent
            }
            .frame(width: 155, height: 155)
            .padding(.vertical, Nexus.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilityLabel)
    }
    
    private var ringLayer: some View {
        ZStack {
            if data.showRing {
                Circle()
                    .trim(from: 0, to: data.ratio)
                    .stroke(
                        data.ringColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }
    
    private var ticksLayer: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let tickRatios: [Double] = [0.7, 0.85, 1.0]
            
            ZStack {
                ForEach(Array(tickRatios.enumerated()), id: \.offset) { _, ratio in
                    let angle = (ratio * 360) - 90
                    Capsule()
                        .fill(Nexus.Colors.textTertiary.opacity(0.6))
                        .frame(width: 10, height: 2)
                        .offset(y: -(radius - 6))
                        .rotationEffect(.degrees(angle))
                        .opacity(data.showRing ? 1 : 0)
                }
            }
        }
    }
    
    private var centerContent: some View {
        VStack(spacing: Nexus.Spacing.xs) {
            Text("\(data.clampedOccupied)")
                .font(Nexus.Typography.heroNumber)
                .foregroundColor(Nexus.Colors.textPrimary)
                .monospacedDigit()
            
            Text("présents")
                .font(Nexus.Typography.micro)
                .foregroundColor(Nexus.Colors.textTertiary)
            
            if let overText = data.overCapacityText {
                Text(overText)
                    .font(Nexus.Typography.micro)
                    .foregroundColor(Nexus.Colors.negative)
            }
        }
    }
}

// MARK: - Data helper (clamps + a11y)

struct OccupancyDonutData {
    let clampedOccupied: Int
    let free: Int
    let ratio: Double
    let percentText: String
    let capacityDisplay: String
    let overCapacityText: String?
    let ringColor: Color
    let showRing: Bool
    let accessibilityLabel: String
    
    static func compute(occupied: Int, capacity: Int) -> OccupancyDonutData {
        let clampedOccupied = max(0, occupied)
        let clampedCapacity = max(0, capacity)
        let free = max(0, clampedCapacity - clampedOccupied)
        
        let rawRatio: Double
        let percentText: String
        let capacityDisplay: String
        let overCapacityText: String?
        let ratio: Double
        
        if clampedCapacity > 0 {
            rawRatio = Double(clampedOccupied) / Double(clampedCapacity)
            ratio = min(max(rawRatio, 0), 1)
            percentText = "\(Int((rawRatio * 100).rounded()))%"
            capacityDisplay = "\(clampedCapacity)"
            overCapacityText = clampedOccupied > clampedCapacity ? "+\(clampedOccupied - clampedCapacity) surcap." : nil
        } else {
            rawRatio = 0
            ratio = 0
            percentText = "N/A"
            capacityDisplay = "N/A"
            overCapacityText = nil
        }
        
        let ringColor = color(for: rawRatio)
        let showRing = clampedCapacity > 0 && clampedOccupied > 0
        
        let a11y: String
        if clampedCapacity > 0 {
            a11y = "Occupation \(percentText), \(clampedOccupied) sur \(clampedCapacity), \(free) places libres"
        } else {
            a11y = "Occupation N/A, \(clampedOccupied) présents, capacité inconnue"
        }
        
        return OccupancyDonutData(
            clampedOccupied: clampedOccupied,
            free: free,
            ratio: ratio,
            percentText: percentText,
            capacityDisplay: capacityDisplay,
            overCapacityText: overCapacityText,
            ringColor: ringColor,
            showRing: showRing,
            accessibilityLabel: a11y
        )
    }
    
    private static func color(for ratio: Double) -> Color {
        let t = max(0, min(ratio, 1))
        let low = UIColor(Nexus.Colors.accent)
        let high = UIColor(red: 0.0, green: 0.65, blue: 0.68, alpha: 1.0) // Teal accent
        return Color(interpolatedColor(from: low, to: high, progress: CGFloat(t)))
    }
}

// MARK: - Color interpolation helper

private func interpolatedColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
    let fromComponents = from.rgba
    let toComponents = to.rgba
    
    let r = fromComponents.r + (toComponents.r - fromComponents.r) * progress
    let g = fromComponents.g + (toComponents.g - fromComponents.g) * progress
    let b = fromComponents.b + (toComponents.b - fromComponents.b) * progress
    let a = fromComponents.a + (toComponents.a - fromComponents.a) * progress
    
    return UIColor(red: r, green: g, blue: b, alpha: a)
}

private extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
