//
//  SimulatorView.swift
//  LIVECOUNT
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI
import Observation

struct SimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DashboardViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                header
                controlButtons
                statusSummary
                Spacer()
            }
            .padding()
            .navigationTitle("Tools / Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Simulateur d’événements")
                .font(.headline)
            Text("Utilisez ce clicker temporaire pour générer des entrées/sorties.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            Button(action: {
                viewModel.decrement()
                triggerHapticFeedback(.medium)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(viewModel.canDecrement || viewModel.isAdmin ? .red : .gray)
            }
            .disabled(!viewModel.canDecrement && !viewModel.isAdmin)
            
            Button(action: {
                viewModel.increment()
                triggerHapticFeedback(.medium)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
            }
        }
    }
    
    private var statusSummary: some View {
        VStack(spacing: 8) {
            Text("Compteur actuel")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("\(viewModel.currentCount) / \(viewModel.maxCapacity)")
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
            Text(viewModel.liveStatusText)
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview {
    let viewModel = DashboardViewModel()
    SimulatorView(viewModel: viewModel)
}
