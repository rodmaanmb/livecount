//
//  DemoDataSeeder.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// Service for seeding demo data into EntryStore
actor DemoDataSeeder {
    
    // MARK: - Properties
    
    private let entryStore: EntryStore
    private let userDefaults: UserDefaults
    
    // UserDefaults key for idempotence
    private let hasSeedKey = "com.livecount.hasSeededDemoData"
    
    // MARK: - Configuration
    
    private struct Config {
        static let daysToSeed = 180  // 6 months
        static let targetEntriesPerDay = 300
        
        // Operating hours (local time)
        static let startHour = 10
        static let endHour = 22
        static let noonHour = 12
        
        // Occupancy bounds
        static let minOccupancy = 50
        static let maxOccupancy = 120
        static let typicalLow = 50
        
        // Peak hours (18:00-20:00)
        static let peakStartHour = 18
        static let peakEndHour = 20
    }
    
    // MARK: - Initialization
    
    init(entryStore: EntryStore, userDefaults: UserDefaults = .standard) {
        self.entryStore = entryStore
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public Methods
    
    /// Check if demo data has already been seeded
    var hasSeededData: Bool {
        userDefaults.bool(forKey: hasSeedKey)
    }
    
    /// Seed 6 months of demo data
    /// - Parameters:
    ///   - locationId: Location ID for seeded entries
    ///   - maxCapacity: Maximum capacity for occupancy calculations
    /// - Throws: If seeding fails
    func seedLast6Months(locationId: String, maxCapacity: Int) async throws {
        // Idempotence check
        guard !hasSeededData else {
            print("⚠️ Demo data already seeded. Skipping.")
            return
        }
        
        print("🌱 [SEED] Starting 6-month demo data generation...")
        print("   • Days: \(Config.daysToSeed)")
        print("   • LocationId: \(locationId)")
        print("   • MaxCapacity: \(maxCapacity)")
        print("   • Timezone: \(TimeZone.current.identifier)")
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current  // ✅ FIX: Timezone explicite
        
        let now = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        
        var totalEntriesWritten = 0
        var filesExpected = Set<String>()
        
        // Generate entries for each of the last 180 days
        for dayOffset in (0..<Config.daysToSeed).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                print("   ⚠️ Failed to compute date for dayOffset=\(dayOffset)")
                continue
            }
            
            let startOfDay = calendar.startOfDay(for: targetDate)
            let dateKey = dateFormatter.string(from: startOfDay)
            filesExpected.insert(dateKey)
            
            // Log first, last, and every 30th day for verification
            let dayNumber = Config.daysToSeed - dayOffset
            let shouldLog = dayOffset == Config.daysToSeed - 1 || dayOffset == 0 || dayNumber % 30 == 0
            
            if shouldLog {
                print("   📅 Day \(dayNumber)/\(Config.daysToSeed): \(dateKey)")
            }
            
            // Generate entries for this day
            let entries = generateEntriesForDay(
                date: startOfDay,
                locationId: locationId,
                maxCapacity: maxCapacity,
                calendar: calendar
            )
            
            if entries.isEmpty {
                print("   ⚠️ Day \(dayNumber) generated 0 entries!")
            }
            
            // Persist all entries for this day
            for entry in entries {
                try await entryStore.append(entry)
                totalEntriesWritten += 1
            }
        }
        
        print("\n   📊 Seeding summary:")
        print("      • Total entries written: \(totalEntriesWritten)")
        print("      • Expected files: \(filesExpected.count)")
        
        // Mark as seeded
        userDefaults.set(true, forKey: hasSeedKey)
        
        // Verify files created
        if let store = entryStore as? FileEntryStore {
            await store.debugDumpStore()
        }
        
        print("✅ [SEED] Completed: 6 months of demo data generated")
    }
    
    /// Clear all seeded demo data by deleting ALL .jsonl files
    /// - Parameter locationId: Location ID (unused, clears all files)
    func clearSeededData(locationId: String) async throws {
        print("🗑️  [CLEAR] Clearing ALL seeded demo data...")
        
        // Delete all .jsonl files in the EntryStore directory
        if let store = entryStore as? FileEntryStore {
            let deletedCount = await store.deleteAllFiles()
            print("   🗑️  Deleted \(deletedCount) .jsonl files")
        }
        
        // Reset the seeded flag
        userDefaults.set(false, forKey: hasSeedKey)
        
        print("✅ [CLEAR] Seeded data and flag cleared")
    }
    
    // MARK: - Private Methods
    
    /// Generate entries for a single day using random-walk occupancy model
    private func generateEntriesForDay(
        date startOfDay: Date,
        locationId: String,
        maxCapacity: Int,
        calendar: Calendar
    ) -> [Entry] {
        var entries: [Entry] = []
        var currentOccupancy = 0
        
        // Operating window: 10:00 - 22:00
        let operatingHours = Config.startHour...Config.endHour
        
        for hour in operatingHours {
            // Number of events this hour (more during peak hours)
            let isPeakHour = hour >= Config.peakStartHour && hour <= Config.peakEndHour
            let eventsPerHour = isPeakHour ? 35 : 20
            
            // Noon reset: force occupancy back to 0
            if hour == Config.noonHour && currentOccupancy > 0 {
                let noonTimestamp = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay)!
                
                // Generate "out" events to bring occupancy to 0
                for i in 0..<currentOccupancy {
                    let entry = createEntry(
                        timestamp: noonTimestamp.addingTimeInterval(Double(i)),
                        type: .out,
                        locationId: locationId
                    )
                    entries.append(entry)
                }
                currentOccupancy = 0
            }
            
            // Generate events throughout the hour
            for _ in 0..<eventsPerHour {
                let minute = Int.random(in: 0..<60)
                let second = Int.random(in: 0..<60)
                
                guard let timestamp = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: second,
                    of: startOfDay
                ) else { continue }
                
                // Random walk: decide if this is an "in" or "out"
                // Use maxCapacity parameter (NOT Config.maxOccupancy) to respect location limits
                let type: EntryType
                
                // Target range: 50% to 80% of maxCapacity for realistic occupancy
                let targetMin = max(Config.typicalLow, maxCapacity / 2)
                let targetMax = min(Config.maxOccupancy, Int(Double(maxCapacity) * 0.8))
                
                if currentOccupancy < targetMin {
                    // Below target min: bias toward "in"
                    type = Double.random(in: 0...1) < 0.8 ? .in : .out
                } else if currentOccupancy >= targetMax {
                    // At or above target max: force "out"
                    type = .out
                } else if currentOccupancy >= targetMax - 10 {
                    // Near target max: bias toward "out"
                    type = Double.random(in: 0...1) < 0.7 ? .out : .in
                } else {
                    // Normal range: random walk
                    type = Double.random(in: 0...1) < 0.6 ? .in : .out
                }
                
                // Create entry
                let entry = createEntry(
                    timestamp: timestamp,
                    type: type,
                    locationId: locationId
                )
                entries.append(entry)
                
                // Update occupancy (clamped to 0)
                currentOccupancy = max(0, currentOccupancy + entry.delta)
            }
        }
        
        // Sort entries by timestamp (critical for correct replay)
        entries.sort { $0.timestamp < $1.timestamp }
        
        return entries
    }
    
    /// Create a seeded entry
    private func createEntry(
        timestamp: Date,
        type: EntryType,
        locationId: String
    ) -> Entry {
        Entry(
            id: UUID().uuidString,
            locationId: locationId,
            userId: nil,
            timestamp: timestamp,
            type: type,
            delta: type == .in ? 1 : -1,
            deviceId: "simulator-seed",
            source: .simulated,
            sequenceNumber: nil
        )
    }
}
