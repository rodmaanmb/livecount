//
//  DashboardViewModel.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation
import Observation

@Observable
final class DashboardViewModel {
    // MARK: - Properties
    
    var currentCount: Int = 0 {
        didSet {
            updateStatus()
        }
    }
    
    var maxCapacity: Int = 100
    var status: OccupancyStatus = .ok
    var location: Location?
    var user: User?
    
    // MARK: - Computed Properties
    
    var occupancyPercentage: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentCount) / Double(maxCapacity) * 100
    }
    
    var canDecrement: Bool {
        currentCount > 0
    }
    
    var isAdmin: Bool {
        user?.role == .admin
    }
    
    // MARK: - Initialization
    
    init(location: Location? = nil, user: User? = nil) {
        self.location = location
        self.user = user
        if let location = location {
            self.maxCapacity = location.maxCapacity
        }
        updateStatus()
    }
    
    // MARK: - Public Methods
    
    func increment() {
        currentCount += 1
        // TODO: Log entry to Firestore when service is implemented
    }
    
    func decrement() {
        guard canDecrement || isAdmin else { return }
        currentCount = max(0, currentCount - 1)
        // TODO: Log entry to Firestore when service is implemented
    }
    
    // MARK: - Private Methods
    
    private func updateStatus() {
        let percentage = occupancyPercentage
        
        if percentage >= 110 {
            status = .full
        } else if percentage >= 90 {
            status = .warning
        } else {
            status = .ok
        }
    }
}