//
//  DashboardView.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    
    init(viewModel: DashboardViewModel = DashboardViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Status Indicator
            statusIndicator
            
            // Large Numeric Counter
            counterDisplay
            
            // Control Buttons
            controlButtons
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 16, height: 16)
            
            Text(viewModel.status.rawValue.capitalized)
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundColor(.primary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Counter Display
    
    private var counterDisplay: some View {
        VStack(spacing: 8) {
            Text("\(viewModel.currentCount)")
                .font(.system(size: 80, weight: .bold, design: .default))
                .foregroundColor(statusColor)
                .monospacedDigit()
            
            Text("sur \(viewModel.maxCapacity)")
                .font(.system(size: 20, weight: .regular, design: .default))
                .foregroundColor(.secondary)
            
            Text("\(Int(viewModel.occupancyPercentage))%")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            // Decrement Button
            Button(action: {
                viewModel.decrement()
                triggerHapticFeedback(.medium)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.canDecrement || viewModel.isAdmin ? .red : .gray)
            }
            .disabled(!viewModel.canDecrement && !viewModel.isAdmin)
            
            // Increment Button
            Button(action: {
                viewModel.increment()
                triggerHapticFeedback(.medium)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // MARK: - Helper Methods
    
    private var statusColor: Color {
        switch viewModel.status {
        case .ok:
            return .green
        case .warning:
            return .orange
        case .full:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

#Preview("With Sample Data") {
    let sampleLocation = Location(
        id: "1",
        name: "Salle principale",
        maxCapacity: 50,
        timezone: "Europe/Paris"
    )
    let sampleUser = User(
        id: "1",
        email: "admin@example.com",
        role: .admin,
        createdAt: Date()
    )
    let viewModel = DashboardViewModel(location: sampleLocation, user: sampleUser)
    viewModel.currentCount = 45
    
    return DashboardView(viewModel: viewModel)
}