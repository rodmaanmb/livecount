//
//  SeedEntries.swift
//  LIVECOUNT (external tool)
//

import Foundation

struct SeedEntriesTool {
    struct Options {
        var locationId: String = "default-location"
        var maxCapacity: Int = 120
        var days: Int = 180
        var writeMode: Bool = false
    }
    
    static func run() {
        var options = Options()
        let args = CommandLine.arguments.dropFirst()
        var iterator = args.makeIterator()
        
        while let arg = iterator.next() {
            switch arg {
            case "--write":
                options.writeMode = true
            case "--location":
                if let value = iterator.next() {
                    options.locationId = value
                }
            case "--max-capacity":
                if let value = iterator.next(), let parsed = Int(value) {
                    options.maxCapacity = parsed
                }
            case "--days":
                if let value = iterator.next(), let parsed = Int(value) {
                    options.days = parsed
                }
            case "--help":
                printUsage()
                return
            default:
                print("Unknown arg: \(arg)")
                printUsage()
                return
            }
        }
        
        if options.maxCapacity <= 0 || options.days <= 0 {
            print("Invalid options: max-capacity and days must be > 0.")
            return
        }
        
        do {
            let store = try FileEntryStore()
            let generator = EntryGenerator(
                locationId: options.locationId,
                maxCapacity: options.maxCapacity
            )
            
            let entries = generator.generateLastDays(options.days)
            let summary = summarize(entries)
            printSummary(summary, options: options)
            
            if options.writeMode {
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    do {
                        for entry in entries {
                            try await store.append(entry)
                        }
                        print("✅ Write complete: \(entries.count) entries appended.")
                    } catch {
                        print("❌ Failed to write: \(error)")
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            } else {
                print("ℹ️ Dry-run only. Use --write to append.")
            }
        } catch {
            print("❌ Failed: \(error)")
        }
    }
    
    private static func printUsage() {
        print("""
        Usage: SeedEntries [--write] [--location <id>] [--max-capacity <int>] [--days <int>]
        
        Defaults:
          --location default-location
          --max-capacity 120
          --days 180
        
        Modes:
          (no --write) Dry-run: prints counts + samples
          --write       Appends entries to FileEntryStore
        """)
    }
    
    private static func summarize(_ entries: [Entry]) -> (count: Int, first: [Entry], last: [Entry]) {
        let first = Array(entries.prefix(3))
        let last = Array(entries.suffix(3))
        return (entries.count, first, last)
    }
    
    private static func printSummary(_ summary: (count: Int, first: [Entry], last: [Entry]), options: Options) {
        print("📦 Seed summary")
        print("   • LocationId: \(options.locationId)")
        print("   • MaxCapacity: \(options.maxCapacity)")
        print("   • Days: \(options.days)")
        print("   • Total entries: \(summary.count)")
        if !summary.first.isEmpty {
            print("   • First entries:")
            summary.first.forEach { entry in
                print("     - \(entry.timestamp) \(entry.type.rawValue) delta=\(entry.delta)")
            }
        }
        if !summary.last.isEmpty {
            print("   • Last entries:")
            summary.last.forEach { entry in
                print("     - \(entry.timestamp) \(entry.type.rawValue) delta=\(entry.delta)")
            }
        }
    }
}

private struct EntryGenerator {
    let locationId: String
    let maxCapacity: Int
    let calendar: Calendar
    
    init(locationId: String, maxCapacity: Int) {
        self.locationId = locationId
        self.maxCapacity = maxCapacity
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        self.calendar = calendar
    }
    
    func generateLastDays(_ days: Int) -> [Entry] {
        var entries: [Entry] = []
        let now = Date()
        
        for dayOffset in (0..<days).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }
            let dayEntries = generateEntriesForDay(startOfDay: calendar.startOfDay(for: targetDate), now: now)
            entries.append(contentsOf: dayEntries)
        }
        
        entries.sort { $0.timestamp < $1.timestamp }
        return entries
    }
    
    private func generateEntriesForDay(startOfDay: Date, now: Date) -> [Entry] {
        var entries: [Entry] = []
        var currentOccupancy = 0
        let operatingHours = 9...21
        let eventsPerHour = 12
        
        for hour in operatingHours {
            for _ in 0..<eventsPerHour {
                guard let timestamp = calendar.date(
                    bySettingHour: hour,
                    minute: Int.random(in: 0..<60),
                    second: Int.random(in: 0..<60),
                    of: startOfDay
                ) else { continue }
                
                let type = nextEntryType(currentOccupancy: currentOccupancy)
                let entry = makeEntry(timestamp: timestamp, type: type)
                entries.append(entry)
                
                currentOccupancy = max(0, currentOccupancy + entry.delta)
            }
        }
        
        // Ensure some events exist for today near "now"
        if calendar.isDate(now, inSameDayAs: startOfDay) {
            let recentTimestamps = [
                now.addingTimeInterval(-600),
                now.addingTimeInterval(-300),
                now.addingTimeInterval(-60)
            ]
            for timestamp in recentTimestamps {
                let type = nextEntryType(currentOccupancy: currentOccupancy)
                let entry = makeEntry(timestamp: timestamp, type: type)
                entries.append(entry)
                currentOccupancy = max(0, currentOccupancy + entry.delta)
            }
        }
        
        entries.sort { $0.timestamp < $1.timestamp }
        return entries
    }
    
    private func nextEntryType(currentOccupancy: Int) -> EntryType {
        if currentOccupancy <= 0 {
            return .in
        }
        if currentOccupancy >= maxCapacity {
            return .out
        }
        return Double.random(in: 0...1) < 0.55 ? .in : .out
    }
    
    private func makeEntry(timestamp: Date, type: EntryType) -> Entry {
        Entry(
            id: UUID().uuidString,
            locationId: locationId,
            userId: nil,
            timestamp: timestamp,
            type: type,
            delta: type == .in ? 1 : -1,
            deviceId: "seed-tool",
            source: .simulated,
            sequenceNumber: nil
        )
    }
}

SeedEntriesTool.run()
