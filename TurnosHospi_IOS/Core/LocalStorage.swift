//
//  LocalStorage.swift
//  TurnosHospi_IOS
//
//  Offline-first data layer with local storage using UserDefaults and file system
//

import Foundation
import Combine

// MARK: - Storage Keys

enum StorageKey: String {
    case userProfile = "user_profile"
    case currentPlantId = "current_plant_id"
    case cachedPlant = "cached_plant"
    case monthlyShifts = "monthly_shifts"
    case pendingRequests = "pending_requests"
    case lastSyncTime = "last_sync_time"
    case offlineQueue = "offline_queue"
    case themeSettings = "theme_settings"
    case notificationSettings = "notification_settings"

    func withSuffix(_ suffix: String) -> String {
        "\(rawValue)_\(suffix)"
    }
}

// MARK: - Offline Operation

struct OfflineOperation: Codable, Identifiable {
    let id: String
    let type: OperationType
    let path: String
    let data: Data
    let timestamp: Date
    var retryCount: Int

    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }
}

// MARK: - Local Storage Manager

final class LocalStorageManager {
    static let shared = LocalStorageManager()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var offlineQueue: [OfflineOperation] = []
    private let queue = DispatchQueue(label: "com.turnoshospi.storage")

    // Publishers
    private let syncSubject = PassthroughSubject<SyncEvent, Never>()
    var syncEvents: AnyPublisher<SyncEvent, Never> {
        syncSubject.eraseToAnyPublisher()
    }

    enum SyncEvent {
        case started
        case completed(successCount: Int, failureCount: Int)
        case failed(Error)
        case operationSynced(OfflineOperation)
    }

    private init() {
        loadOfflineQueue()
    }

    // MARK: - Documents Directory

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func storageURL(for key: String) -> URL {
        documentsDirectory.appendingPathComponent("\(key).json")
    }

    // MARK: - Generic Storage

    func save<T: Codable>(_ value: T, forKey key: StorageKey) {
        save(value, forKey: key.rawValue)
    }

    func save<T: Codable>(_ value: T, forKey key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try self.encoder.encode(value)

                // Save to file for larger data
                if data.count > 1024 {
                    try data.write(to: self.storageURL(for: key))
                } else {
                    // Save to UserDefaults for smaller data
                    self.defaults.set(data, forKey: key)
                }
            } catch {
                print("LocalStorage: Failed to save \(key): \(error)")
            }
        }
    }

    func load<T: Codable>(_ type: T.Type, forKey key: StorageKey) -> T? {
        load(type, forKey: key.rawValue)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Try UserDefaults first
        if let data = defaults.data(forKey: key) {
            return try? decoder.decode(type, from: data)
        }

        // Try file system
        let url = storageURL(for: key)
        if let data = try? Data(contentsOf: url) {
            return try? decoder.decode(type, from: data)
        }

        return nil
    }

    func remove(forKey key: StorageKey) {
        remove(forKey: key.rawValue)
    }

    func remove(forKey key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.defaults.removeObject(forKey: key)
            try? self.fileManager.removeItem(at: self.storageURL(for: key))
        }
    }

    // MARK: - Offline Queue

    func enqueueOfflineOperation(
        type: OfflineOperation.OperationType,
        path: String,
        data: Any
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let operation = OfflineOperation(
                    id: UUID().uuidString,
                    type: type,
                    path: path,
                    data: jsonData,
                    timestamp: Date(),
                    retryCount: 0
                )

                self.offlineQueue.append(operation)
                self.saveOfflineQueue()
            } catch {
                print("LocalStorage: Failed to enqueue operation: \(error)")
            }
        }
    }

    func processOfflineQueue(using executor: @escaping (OfflineOperation) async throws -> Void) async {
        guard !offlineQueue.isEmpty else { return }

        syncSubject.send(.started)

        var successCount = 0
        var failureCount = 0
        var remainingOperations: [OfflineOperation] = []

        for operation in offlineQueue {
            do {
                try await executor(operation)
                successCount += 1
                syncSubject.send(.operationSynced(operation))
            } catch {
                failureCount += 1
                var retryOperation = operation
                retryOperation.retryCount += 1

                // Keep for retry if under max attempts
                if retryOperation.retryCount < 3 {
                    remainingOperations.append(retryOperation)
                }
            }
        }

        queue.async { [weak self] in
            self?.offlineQueue = remainingOperations
            self?.saveOfflineQueue()
        }

        syncSubject.send(.completed(successCount: successCount, failureCount: failureCount))
    }

    var pendingOperationsCount: Int {
        offlineQueue.count
    }

    private func loadOfflineQueue() {
        if let operations: [OfflineOperation] = load([OfflineOperation].self, forKey: .offlineQueue) {
            offlineQueue = operations
        }
    }

    private func saveOfflineQueue() {
        save(offlineQueue, forKey: .offlineQueue)
    }

    // MARK: - Shift-Specific Storage

    func saveMonthlyShifts(_ shifts: [Date: [PlantShiftWorker]], plantId: String, month: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let key = StorageKey.monthlyShifts.withSuffix("\(plantId)_\(formatter.string(from: month))")

        // Convert to storable format
        let storableShifts = shifts.mapKeys { date in
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }.mapValues { workers in
            workers.map { StorablePlantShiftWorker(from: $0) }
        }

        save(storableShifts, forKey: key)
    }

    func loadMonthlyShifts(plantId: String, month: Date) -> [Date: [PlantShiftWorker]]? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let key = StorageKey.monthlyShifts.withSuffix("\(plantId)_\(formatter.string(from: month))")

        guard let storable: [String: [StorablePlantShiftWorker]] = load([String: [StorablePlantShiftWorker]].self, forKey: key) else {
            return nil
        }

        formatter.dateFormat = "yyyy-MM-dd"
        return storable.compactMapKeys { dateStr in
            formatter.date(from: dateStr)
        }.mapValues { workers in
            workers.map { $0.toPlantShiftWorker() }
        }
    }

    // MARK: - Last Sync Time

    func updateLastSyncTime(for key: String) {
        save(Date(), forKey: StorageKey.lastSyncTime.withSuffix(key))
    }

    func lastSyncTime(for key: String) -> Date? {
        load(Date.self, forKey: StorageKey.lastSyncTime.withSuffix(key))
    }

    func needsSync(for key: String, interval: TimeInterval = 300) -> Bool {
        guard let lastSync = lastSyncTime(for: key) else { return true }
        return Date().timeIntervalSince(lastSync) > interval
    }

    // MARK: - Clear All

    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Clear UserDefaults
            if let bundleId = Bundle.main.bundleIdentifier {
                self.defaults.removePersistentDomain(forName: bundleId)
            }

            // Clear files
            let contents = try? self.fileManager.contentsOfDirectory(
                at: self.documentsDirectory,
                includingPropertiesForKeys: nil
            )

            contents?.filter { $0.pathExtension == "json" }.forEach { url in
                try? self.fileManager.removeItem(at: url)
            }
        }
    }
}

// MARK: - Storable Models

struct StorablePlantShiftWorker: Codable {
    let id: String
    let name: String
    let role: String
    let shiftName: String?

    init(from worker: PlantShiftWorker) {
        self.id = worker.id
        self.name = worker.name
        self.role = worker.role
        self.shiftName = worker.shiftName
    }

    func toPlantShiftWorker() -> PlantShiftWorker {
        PlantShiftWorker(id: id, name: name, role: role, shiftName: shiftName)
    }
}

// MARK: - Dictionary Extensions

extension Dictionary {
    func mapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        Dictionary<NewKey, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }

    func compactMapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey?) -> [NewKey: Value] {
        Dictionary<NewKey, Value>(uniqueKeysWithValues: compactMap { key, value in
            guard let newKey = transform(key) else { return nil }
            return (newKey, value)
        })
    }
}

// MARK: - Offline-First Data Provider

final class OfflineFirstDataProvider<T: Codable>: ObservableObject {
    @Published private(set) var data: T?
    @Published private(set) var isLoading = false
    @Published private(set) var isStale = false
    @Published private(set) var error: AppError?

    private let storageKey: String
    private let fetchFromNetwork: () async throws -> T
    private let staleDuration: TimeInterval

    init(
        storageKey: String,
        staleDuration: TimeInterval = 300,
        fetchFromNetwork: @escaping () async throws -> T
    ) {
        self.storageKey = storageKey
        self.staleDuration = staleDuration
        self.fetchFromNetwork = fetchFromNetwork

        loadFromStorage()
    }

    private func loadFromStorage() {
        if let cached = LocalStorageManager.shared.load(T.self, forKey: storageKey) {
            data = cached
            isStale = LocalStorageManager.shared.needsSync(for: storageKey, interval: staleDuration)
        }
    }

    func refresh(force: Bool = false) async {
        guard force || isStale || data == nil else { return }

        isLoading = true
        error = nil

        do {
            let freshData = try await fetchFromNetwork()

            await MainActor.run {
                self.data = freshData
                self.isStale = false
                self.isLoading = false
            }

            LocalStorageManager.shared.save(freshData, forKey: storageKey)
            LocalStorageManager.shared.updateLastSyncTime(for: storageKey)

        } catch let appError as AppError {
            await MainActor.run {
                self.error = appError
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = .from(error)
                self.isLoading = false
            }
        }
    }

    func invalidate() {
        LocalStorageManager.shared.remove(forKey: storageKey)
        data = nil
        isStale = true
    }
}
