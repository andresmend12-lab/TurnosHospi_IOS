//
//  CacheManager.swift
//  TurnosHospi_IOS
//
//  In-memory and disk caching system for Firebase data
//

import Foundation

// MARK: - Cache Entry

struct CacheEntry<T> {
    let value: T
    let timestamp: Date
    let expirationInterval: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > expirationInterval
    }

    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

// MARK: - Cache Configuration

struct CacheConfiguration {
    let maxMemoryEntries: Int
    let defaultTTL: TimeInterval
    let persistToDisk: Bool

    static let `default` = CacheConfiguration(
        maxMemoryEntries: 100,
        defaultTTL: 300, // 5 minutes
        persistToDisk: true
    )

    static let aggressive = CacheConfiguration(
        maxMemoryEntries: 200,
        defaultTTL: 600, // 10 minutes
        persistToDisk: true
    )

    static let minimal = CacheConfiguration(
        maxMemoryEntries: 50,
        defaultTTL: 60, // 1 minute
        persistToDisk: false
    )
}

// MARK: - Cache Manager

final class CacheManager {
    static let shared = CacheManager()

    private var memoryCache: [String: Any] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private var cacheTTL: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "com.turnoshospi.cache", attributes: .concurrent)
    private let configuration: CacheConfiguration

    // Cache statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0

    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }

    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        clearExpired()
        // If still over limit, clear oldest entries
        if memoryCache.count > configuration.maxMemoryEntries / 2 {
            clearOldestEntries(keep: configuration.maxMemoryEntries / 4)
        }
    }

    // MARK: - Public API

    func set<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.memoryCache[key] = value
            self.cacheTimestamps[key] = Date()
            self.cacheTTL[key] = ttl ?? self.configuration.defaultTTL

            // Persist to disk if enabled
            if self.configuration.persistToDisk {
                self.persistToDisk(value, forKey: key)
            }

            // Evict if over limit
            if self.memoryCache.count > self.configuration.maxMemoryEntries {
                self.evictOldestEntry()
            }
        }
    }

    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        var result: T?

        queue.sync { [weak self] in
            guard let self = self else { return }

            // Check memory cache
            if let cached = self.memoryCache[key] as? T,
               let timestamp = self.cacheTimestamps[key],
               let ttl = self.cacheTTL[key] {

                let age = Date().timeIntervalSince(timestamp)
                if age < ttl {
                    self.hits += 1
                    result = cached
                    return
                } else {
                    // Expired, remove from cache
                    self.memoryCache.removeValue(forKey: key)
                    self.cacheTimestamps.removeValue(forKey: key)
                    self.cacheTTL.removeValue(forKey: key)
                }
            }

            // Check disk cache
            if self.configuration.persistToDisk {
                if let diskValue: T = self.loadFromDisk(forKey: key) {
                    self.memoryCache[key] = diskValue
                    self.cacheTimestamps[key] = Date()
                    self.cacheTTL[key] = self.configuration.defaultTTL
                    self.hits += 1
                    result = diskValue
                    return
                }
            }

            self.misses += 1
        }

        return result
    }

    func getOrFetch<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        ttl: TimeInterval? = nil,
        fetch: @escaping () async throws -> T
    ) async throws -> T {
        // Try cache first
        if let cached = get(type, forKey: key) {
            return cached
        }

        // Fetch and cache
        let value = try await fetch()
        set(value, forKey: key, ttl: ttl)
        return value
    }

    func invalidate(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeValue(forKey: key)
            self?.cacheTimestamps.removeValue(forKey: key)
            self?.cacheTTL.removeValue(forKey: key)
            self?.removeFromDisk(forKey: key)
        }
    }

    func invalidateAll(matching pattern: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let keysToRemove = self.memoryCache.keys.filter { $0.contains(pattern) }
            for key in keysToRemove {
                self.memoryCache.removeValue(forKey: key)
                self.cacheTimestamps.removeValue(forKey: key)
                self.cacheTTL.removeValue(forKey: key)
                self.removeFromDisk(forKey: key)
            }
        }
    }

    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAll()
            self?.cacheTimestamps.removeAll()
            self?.cacheTTL.removeAll()
            self?.clearDiskCache()
        }
    }

    func clearExpired() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let now = Date()
            var keysToRemove: [String] = []

            for (key, timestamp) in self.cacheTimestamps {
                if let ttl = self.cacheTTL[key] {
                    let age = now.timeIntervalSince(timestamp)
                    if age >= ttl {
                        keysToRemove.append(key)
                    }
                }
            }

            for key in keysToRemove {
                self.memoryCache.removeValue(forKey: key)
                self.cacheTimestamps.removeValue(forKey: key)
                self.cacheTTL.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Private Helpers

    private func evictOldestEntry() {
        guard let oldestKey = cacheTimestamps.min(by: { $0.value < $1.value })?.key else { return }
        memoryCache.removeValue(forKey: oldestKey)
        cacheTimestamps.removeValue(forKey: oldestKey)
        cacheTTL.removeValue(forKey: oldestKey)
    }

    private func clearOldestEntries(keep count: Int) {
        let sorted = cacheTimestamps.sorted { $0.value > $1.value }
        let toKeep = Set(sorted.prefix(count).map { $0.key })

        for key in memoryCache.keys {
            if !toKeep.contains(key) {
                memoryCache.removeValue(forKey: key)
                cacheTimestamps.removeValue(forKey: key)
                cacheTTL.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TurnosHospiCache")
    }

    private func persistToDisk<T: Codable>(_ value: T, forKey key: String) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
        } catch {
            print("Cache: Failed to persist \(key) to disk: \(error)")
        }
    }

    private func loadFromDisk<T: Codable>(forKey key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}

// MARK: - String Extension for Hashing

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: 32)

        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import for SHA256
import CommonCrypto

// MARK: - Shift-Specific Cache Keys

enum ShiftCacheKey {
    static func monthlyShifts(plantId: String, month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "shifts_\(plantId)_\(formatter.string(from: month))"
    }

    static func dailyShifts(plantId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "daily_\(plantId)_\(formatter.string(from: date))"
    }

    static func plantData(plantId: String) -> String {
        return "plant_\(plantId)"
    }

    static func userSchedule(userId: String, month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "schedule_\(userId)_\(formatter.string(from: month))"
    }

    static func shiftRequests(plantId: String) -> String {
        return "requests_\(plantId)"
    }
}
