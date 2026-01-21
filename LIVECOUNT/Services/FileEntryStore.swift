//
//  FileEntryStore.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 19/01/2026.
//

import Foundation

/// File-based persistent storage for Entry events using daily JSONL chunks
final class FileEntryStore: EntryStore {
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.livecount.fileentrystore", qos: .utility)
    private let storageDirectory: URL
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    /// Cache of open file handles (dateKey -> FileHandle)
    private var fileHandles: [String: FileHandle] = [:]
    
    // MARK: - Initialization
    
    init() throws {
        self.fileManager = FileManager.default
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
        
        // Configure date encoding/decoding
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        // Get Application Support directory
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw EntryStoreError.storageDirectoryNotFound
        }
        
        // Create subdirectory for entry storage
        self.storageDirectory = appSupportURL.appendingPathComponent("EntryStore", isDirectory: true)
        
        // Ensure directory exists
        try fileManager.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - EntryStore Protocol
    
    /// Append a new entry to the store
    func append(_ entry: Entry) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    try self.appendSync(entry)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    private func appendSync(_ entry: Entry) throws {
        let dateKey = dateKey(for: entry.timestamp)
        let fileURL = fileURL(for: dateKey)
        
        // 📝 LOG: Write-side (reduced for seeding)
        let isSimulated = entry.source == .simulated
        
        if !isSimulated {
            // Only log non-simulated entries (manual/hardware)
            print("💾 [WRITE] Persisting entry:")
            print("   • ID: \(entry.id)")
            print("   • Timestamp: \(entry.timestamp)")
            print("   • LocationId: \(entry.locationId)")
            print("   • Type: \(entry.type)")
            print("   • Delta: \(entry.delta)")
            print("   • DayKey: \(dateKey)")
            print("   • Target file: \(fileURL.path)")
        }
        
        // Encode entry to JSON
        let entryData = try jsonEncoder.encode(entry)
        
        // Get or create file handle
        let handle = try getOrCreateFileHandle(for: dateKey, fileURL: fileURL)
        
        // Append entry as JSONL (one line per entry)
        try handle.seekToEnd()
        try handle.write(contentsOf: entryData)
        try handle.write(contentsOf: Data([0x0A])) // newline
        try handle.synchronize() // flush to disk
        
        // 📝 LOG: Write-side success (only for non-simulated)
        if !isSimulated {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attrs[.size] as? UInt64 {
                print("   ✅ SUCCESS: File size after write: \(fileSize) bytes")
            } else {
                print("   ✅ SUCCESS (could not read file size)")
            }
        }
    }
    
    /// Fetch entries within a time range, optionally filtered by location and device
    func fetch(
        timeRange: DateInterval,
        locationId: String? = nil,
        deviceId: String? = nil
    ) async throws -> [Entry] {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    let result = try self.fetchSync(timeRange: timeRange, locationId: locationId, deviceId: deviceId)
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    private func fetchSync(
        timeRange: DateInterval,
        locationId: String? = nil,
        deviceId: String? = nil
    ) throws -> [Entry] {
        // 📝 LOG: Read-side start
        print("📖 [READ] Fetching entries:")
        print("   • Time range: \(timeRange.start) → \(timeRange.end)")
        print("   • LocationId filter: \(locationId ?? "none")")
        print("   • DeviceId filter: \(deviceId ?? "none")")
        
        #if DEBUG
        // List files in storage directory
        print("   📁 Storage directory: \(storageDirectory.path)")
        if let files = try? fileManager.contentsOfDirectory(atPath: storageDirectory.path) {
            print("   📂 Files present: \(files.count) files")
            let sortedFiles = files.sorted()
            if sortedFiles.isEmpty {
                print("      (empty directory)")
            } else {
                for file in sortedFiles.prefix(5) {
                    print("      • \(file)")
                }
                if sortedFiles.count > 5 {
                    print("      ... and \(sortedFiles.count - 5) more")
                }
            }
        }
        #endif
        
        // Get all relevant date keys within the time range
        let dateKeys = dateKeysInRange(timeRange)
        
        var allEntries: [Entry] = []
        
        // Read entries from each relevant daily file
        for dateKey in dateKeys {
            let fileURL = fileURL(for: dateKey)
            
            // Skip if file doesn't exist
            guard fileManager.fileExists(atPath: fileURL.path) else {
                print("   ⊘ File not found: \(dateKey).jsonl")
                continue
            }
            
            // Read file contents
            let data = try Data(contentsOf: fileURL)
            print("   📄 File \(dateKey).jsonl: \(data.count) bytes")
            
            // Parse JSONL (one entry per line)
            let entries = try parseJSONL(data)
            print("      → Parsed \(entries.count) entries")
            
            // Filter by time range and optional filters
            let filtered = entries.filter { entry in
                guard timeRange.contains(entry.timestamp) else { return false }
                
                if let locationId = locationId, entry.locationId != locationId {
                    return false
                }
                
                if let deviceId = deviceId, entry.deviceId != deviceId {
                    return false
                }
                
                return true
            }
            print("      → After filtering: \(filtered.count) entries")
            
            allEntries.append(contentsOf: filtered)
        }
        
        // Sort by timestamp (primary) and id (tie-breaker) for deterministic ordering
        let sorted = allEntries.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.id < rhs.id
            }
            return lhs.timestamp < rhs.timestamp
        }
        
        print("   ✅ Total entries loaded: \(sorted.count)")
        return sorted
    }
    
    /// Delete all .jsonl files in the storage directory
    /// - Returns: Number of files deleted
    func deleteAllFiles() -> Int {
        queue.sync {
            var deletedCount = 0
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: storageDirectory,
                    includingPropertiesForKeys: nil
                )
                
                // Close all cached file handles first
                for (_, handle) in fileHandles {
                    try? handle.close()
                }
                fileHandles.removeAll()
                
                // Delete each .jsonl file
                for fileURL in contents where fileURL.pathExtension == "jsonl" {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        deletedCount += 1
                    } catch {
                        print("   ⚠️ Failed to delete \(fileURL.lastPathComponent): \(error)")
                    }
                }
            } catch {
                print("   ❌ Failed to list directory: \(error)")
            }
            
            return deletedCount
        }
    }
    
    /// Debug helper: Dump storage directory info
    func debugDumpStore() async {
        await withCheckedContinuation { cont in
            queue.async {
                self.debugDumpStoreSync()
                cont.resume()
            }
        }
    }
    
    private func debugDumpStoreSync() {
        print("\n🔍 [DEBUG] Storage dump:")
        print("   📁 Directory: \(storageDirectory.path)")
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: []
            )
            
            if contents.isEmpty {
                print("   ⚠️ Directory is EMPTY")
            } else {
                print("   📂 Files found: \(contents.count)")
                
                var totalBytes: UInt64 = 0
                for fileURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let size = attrs[.size] as? UInt64 {
                        totalBytes += size
                        print("      • \(fileURL.lastPathComponent): \(size) bytes")
                    } else {
                        print("      • \(fileURL.lastPathComponent): size unknown")
                    }
                }
                print("   📊 Total storage: \(totalBytes) bytes")
            }
        } catch {
            print("   ❌ Failed to read directory: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Get or create a file handle for the given date key
    private func getOrCreateFileHandle(for dateKey: String, fileURL: URL) throws -> FileHandle {
        // Return cached handle if exists
        if let handle = fileHandles[dateKey] {
            return handle
        }
        
        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        // Open file handle for appending
        let handle = try FileHandle(forWritingTo: fileURL)
        fileHandles[dateKey] = handle
        
        return handle
    }
    
    /// Parse JSONL data into array of Entry objects
    private func parseJSONL(_ data: Data) throws -> [Entry] {
        guard !data.isEmpty else { return [] }
        
        var entries: [Entry] = []
        
        // Split by newlines and decode each line
        let lines = data.split(separator: 0x0A) // newline
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            do {
                let entry = try jsonDecoder.decode(Entry.self, from: Data(line))
                entries.append(entry)
            } catch {
                // Skip malformed lines but continue processing
                print("Warning: Failed to decode entry line: \(error)")
                continue
            }
        }
        
        return entries
    }
    
    /// Generate date key for a given date (YYYY-MM-DD)
    /// Uses local timezone to ensure correct date component extraction
    private func dateKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            in: TimeZone.current,
            from: date
        )
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            // Fallback to ISO formatter if components extraction fails
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            formatter.timeZone = TimeZone.current
            return formatter.string(from: date)
        }
        
        // Format as YYYY-MM-DD with zero-padding
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    /// Get file URL for a given date key
    private func fileURL(for dateKey: String) -> URL {
        storageDirectory.appendingPathComponent("\(dateKey).jsonl")
    }
    
    /// Get all date keys within a date interval
    /// Generates keys for every calendar day touched by [interval.start, interval.end] inclusive
    /// Uses local timezone for day boundaries
    private func dateKeysInRange(_ interval: DateInterval) -> [String] {
        var dateKeys: [String] = []
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        // Get start of day for start date
        let startDay = calendar.startOfDay(for: interval.start)
        
        // Get start of day for end date
        // Important: if interval.end is "now" (e.g., 14:30), we need to include that day
        let endDay = calendar.startOfDay(for: interval.end)
        
        var currentDate = startDay
        
        #if DEBUG
        print("   🗓️  [dateKeysInRange] Computing keys:")
        print("      • interval.start: \(interval.start)")
        print("      • interval.end: \(interval.end)")
        print("      • startDay: \(startDay)")
        print("      • endDay: \(endDay)")
        #endif
        
        // Iterate through each day from startDay to endDay (inclusive)
        while currentDate <= endDay {
            let key = dateKey(for: currentDate)
            dateKeys.append(key)
            
            // Move to next day (start of next day)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        // 📝 LOG: Show computed keys
        print("   🗓️  Computed date keys: \(dateKeys)")
        
        return dateKeys
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Close all file handles
        for (_, handle) in fileHandles {
            try? handle.close()
        }
    }
}

// MARK: - Error Types

enum EntryStoreError: LocalizedError {
    case storageDirectoryNotFound
    case fileWriteFailed
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .storageDirectoryNotFound:
            return "Could not locate application storage directory"
        case .fileWriteFailed:
            return "Failed to write entry to storage"
        case .fileReadFailed:
            return "Failed to read entries from storage"
        }
    }
}
