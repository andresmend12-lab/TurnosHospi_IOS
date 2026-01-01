//
//  ShiftRepository.swift
//  TurnosHospi_IOS
//
//  Optimized data repository with caching, pagination, and offline support
//

import Foundation
import FirebaseDatabase
import Combine

// MARK: - Cached Shift Data

struct CachedShiftData: Codable {
    let plantId: String
    let month: String
    let assignments: [String: [CachedWorker]]
    let fetchedAt: Date

    struct CachedWorker: Codable {
        let id: String
        let name: String
        let role: String
        let shiftName: String?
    }
}

// MARK: - Shift Repository

final class ShiftRepository: ObservableObject {
    static let shared = ShiftRepository()

    private let ref = Database.database().reference()
    private let cache = CacheManager.shared
    private let network = NetworkManager.shared

    // Published state
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: AppError?

    // Active listeners
    private var activeHandles: [String: DatabaseHandle] = [:]
    private var activeRefs: [String: DatabaseReference] = [:]

    // Pagination state
    private var loadedMonths: Set<String> = []

    private init() {}

    deinit {
        removeAllListeners()
    }

    // MARK: - Monthly Assignments (Optimized)

    func fetchMonthlyAssignments(
        plantId: String,
        month: Date,
        forceRefresh: Bool = false
    ) async throws -> [Date: [PlantShiftWorker]] {
        let cacheKey = ShiftCacheKey.monthlyShifts(plantId: plantId, month: month)

        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = cache.get(CachedShiftData.self, forKey: cacheKey) {
            return convertCachedToAssignments(cached)
        }

        isLoading = true
        defer { isLoading = false }

        // Fetch with retry
        return try await network.withRetry { [weak self] in
            guard let self = self else { throw AppError.unknown(message: "Repository deallocated") }

            let (startDate, endDate) = self.monthBounds(for: month)
            let startKey = "turnos-\(self.formatDate(startDate))"
            let endKey = "turnos-\(self.formatDate(endDate))"

            return try await withCheckedThrowingContinuation { continuation in
                self.ref.child("plants/\(plantId)/turnos")
                    .queryOrderedByKey()
                    .queryStarting(atValue: startKey)
                    .queryEnding(atValue: endKey)
                    .observeSingleEvent(of: .value) { snapshot in
                        let assignments = self.parseAssignments(from: snapshot)

                        // Cache the result
                        let cachedData = self.createCachedData(
                            plantId: plantId,
                            month: month,
                            assignments: assignments
                        )
                        self.cache.set(cachedData, forKey: cacheKey, ttl: 300) // 5 min TTL

                        continuation.resume(returning: assignments)
                    } withCancel: { error in
                        continuation.resume(throwing: AppError.from(error))
                    }
            }
        }
    }

    // MARK: - Real-time Listener (Optimized)

    func observeMonthlyAssignments(
        plantId: String,
        month: Date,
        onChange: @escaping (Result<[Date: [PlantShiftWorker]], AppError>) -> Void
    ) -> String {
        let listenerId = UUID().uuidString
        let cacheKey = ShiftCacheKey.monthlyShifts(plantId: plantId, month: month)

        // Return cached data immediately if available
        if let cached = cache.get(CachedShiftData.self, forKey: cacheKey) {
            onChange(.success(convertCachedToAssignments(cached)))
        }

        let (startDate, endDate) = monthBounds(for: month)
        let startKey = "turnos-\(formatDate(startDate))"
        let endKey = "turnos-\(formatDate(endDate))"

        let nodeRef = ref.child("plants/\(plantId)/turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: startKey)
            .queryEnding(atValue: endKey)

        let handle = nodeRef.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }

            let assignments = self.parseAssignments(from: snapshot)

            // Update cache
            let cachedData = self.createCachedData(
                plantId: plantId,
                month: month,
                assignments: assignments
            )
            self.cache.set(cachedData, forKey: cacheKey, ttl: 300)

            onChange(.success(assignments))
        } withCancel: { error in
            onChange(.failure(.from(error)))
        }

        // Store for cleanup
        activeHandles[listenerId] = handle
        activeRefs[listenerId] = ref.child("plants/\(plantId)/turnos")

        return listenerId
    }

    func removeListener(_ listenerId: String) {
        if let handle = activeHandles[listenerId],
           let ref = activeRefs[listenerId] {
            ref.removeObserver(withHandle: handle)
        }
        activeHandles.removeValue(forKey: listenerId)
        activeRefs.removeValue(forKey: listenerId)
    }

    func removeAllListeners() {
        for (id, handle) in activeHandles {
            activeRefs[id]?.removeObserver(withHandle: handle)
        }
        activeHandles.removeAll()
        activeRefs.removeAll()
    }

    // MARK: - Pagination Support

    func fetchShiftRange(
        plantId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [Date: [PlantShiftWorker]] {
        let startKey = "turnos-\(formatDate(startDate))"
        let endKey = "turnos-\(formatDate(endDate))"

        return try await network.withRetry { [weak self] in
            guard let self = self else { throw AppError.unknown(message: "Repository deallocated") }

            return try await withCheckedThrowingContinuation { continuation in
                self.ref.child("plants/\(plantId)/turnos")
                    .queryOrderedByKey()
                    .queryStarting(atValue: startKey)
                    .queryEnding(atValue: endKey)
                    .observeSingleEvent(of: .value) { snapshot in
                        let assignments = self.parseAssignments(from: snapshot)
                        continuation.resume(returning: assignments)
                    } withCancel: { error in
                        continuation.resume(throwing: AppError.from(error))
                    }
            }
        }
    }

    // MARK: - Prefetching

    func prefetchAdjacentMonths(plantId: String, currentMonth: Date) {
        Task {
            // Prefetch previous and next month in background
            let calendar = Calendar.current

            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                let key = ShiftCacheKey.monthlyShifts(plantId: plantId, month: prevMonth)
                if cache.get(CachedShiftData.self, forKey: key) == nil {
                    _ = try? await fetchMonthlyAssignments(plantId: plantId, month: prevMonth)
                }
            }

            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                let key = ShiftCacheKey.monthlyShifts(plantId: plantId, month: nextMonth)
                if cache.get(CachedShiftData.self, forKey: key) == nil {
                    _ = try? await fetchMonthlyAssignments(plantId: plantId, month: nextMonth)
                }
            }
        }
    }

    // MARK: - Shift Requests

    func fetchShiftRequests(plantId: String) async throws -> [ShiftChangeRequest] {
        let cacheKey = ShiftCacheKey.shiftRequests(plantId: plantId)

        return try await network.withRetry { [weak self] in
            guard let self = self else { throw AppError.unknown(message: "Repository deallocated") }

            return try await withCheckedThrowingContinuation { continuation in
                self.ref.child("plants/\(plantId)/shift_requests")
                    .observeSingleEvent(of: .value) { snapshot in
                        var requests: [ShiftChangeRequest] = []

                        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                            if let dict = child.value as? [String: Any],
                               let request = self.parseRequest(dict: dict, id: child.key) {
                                requests.append(request)
                            }
                        }

                        continuation.resume(returning: requests)
                    } withCancel: { error in
                        continuation.resume(throwing: AppError.from(error))
                    }
            }
        }
    }

    // MARK: - User Schedule

    func fetchUserSchedule(
        userId: String,
        plantId: String,
        month: Date
    ) async throws -> [String: String] {
        let assignments = try await fetchMonthlyAssignments(plantId: plantId, month: month)

        var schedule: [String: String] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for (date, workers) in assignments {
            let dateStr = formatter.string(from: date)
            if let worker = workers.first(where: { $0.name == userId || $0.id.contains(userId) }) {
                schedule[dateStr] = worker.shiftName ?? ""
            }
        }

        return schedule
    }

    // MARK: - Private Helpers

    private func monthBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components)!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        return (startOfMonth, endOfMonth)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseAssignments(from snapshot: DataSnapshot) -> [Date: [PlantShiftWorker]] {
        var assignments: [Date: [PlantShiftWorker]] = [:]
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let allDatesDict = snapshot.value as? [String: Any] else {
            return [:]
        }

        for (nodeName, value) in allDatesDict {
            guard nodeName.hasPrefix("turnos-") else { continue }
            let dateString = String(nodeName.dropFirst("turnos-".count))

            guard let date = formatter.date(from: dateString),
                  let shiftsDict = value as? [String: Any] else { continue }

            var workersForDay: [PlantShiftWorker] = []

            for (shiftName, shiftValue) in shiftsDict {
                if let shiftData = shiftValue as? [String: Any] {
                    workersForDay.append(contentsOf: parseWorkersForShift(
                        shiftName: shiftName,
                        shiftData: shiftData
                    ))
                }
            }

            if !workersForDay.isEmpty {
                var unique: [String: PlantShiftWorker] = [:]
                for w in workersForDay {
                    let key = "\(w.name)_\(w.shiftName ?? "")"
                    unique[key] = w
                }

                let startOfDay = calendar.startOfDay(for: date)
                assignments[startOfDay] = Array(unique.values)
            }
        }

        return assignments
    }

    private func parseWorkersForShift(
        shiftName: String,
        shiftData: [String: Any]
    ) -> [PlantShiftWorker] {
        var workers: [PlantShiftWorker] = []
        let unassigned = "Sin asignar"

        func processArray(_ list: [[String: Any]], roleName: String) {
            for (index, slot) in list.enumerated() {
                let halfDay = slot["halfDay"] as? Bool ?? false
                let primary = (slot["primary"] as? String) ?? ""
                let secondary = (slot["secondary"] as? String) ?? ""

                if !primary.isEmpty && primary != unassigned {
                    workers.append(PlantShiftWorker(
                        id: "\(roleName)_\(shiftName)_\(index)_P",
                        name: primary,
                        role: halfDay ? "\(roleName) (media)" : roleName,
                        shiftName: shiftName
                    ))
                }
                if halfDay, !secondary.isEmpty, secondary != unassigned {
                    workers.append(PlantShiftWorker(
                        id: "\(roleName)_\(shiftName)_\(index)_S",
                        name: secondary,
                        role: "\(roleName) (media)",
                        shiftName: shiftName
                    ))
                }
            }
        }

        if let nurses = shiftData["nurses"] as? [[String: Any]] {
            processArray(nurses, roleName: "Enfermero")
        }
        if let auxs = shiftData["auxiliaries"] as? [[String: Any]] {
            processArray(auxs, roleName: "TCAE")
        }

        return workers
    }

    private func createCachedData(
        plantId: String,
        month: Date,
        assignments: [Date: [PlantShiftWorker]]
    ) -> CachedShiftData {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthStr = formatter.string(from: month)

        formatter.dateFormat = "yyyy-MM-dd"
        var cachedAssignments: [String: [CachedShiftData.CachedWorker]] = [:]

        for (date, workers) in assignments {
            let dateStr = formatter.string(from: date)
            cachedAssignments[dateStr] = workers.map { worker in
                CachedShiftData.CachedWorker(
                    id: worker.id,
                    name: worker.name,
                    role: worker.role,
                    shiftName: worker.shiftName
                )
            }
        }

        return CachedShiftData(
            plantId: plantId,
            month: monthStr,
            assignments: cachedAssignments,
            fetchedAt: Date()
        )
    }

    private func convertCachedToAssignments(_ cached: CachedShiftData) -> [Date: [PlantShiftWorker]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        var assignments: [Date: [PlantShiftWorker]] = [:]

        for (dateStr, workers) in cached.assignments {
            if let date = formatter.date(from: dateStr) {
                let startOfDay = calendar.startOfDay(for: date)
                assignments[startOfDay] = workers.map { cached in
                    PlantShiftWorker(
                        id: cached.id,
                        name: cached.name,
                        role: cached.role,
                        shiftName: cached.shiftName
                    )
                }
            }
        }

        return assignments
    }

    private func parseRequest(dict: [String: Any], id: String) -> ShiftChangeRequest? {
        guard let rId = dict["requesterId"] as? String,
              let rName = dict["requesterName"] as? String,
              let rRole = dict["requesterRole"] as? String,
              let rDate = dict["requesterShiftDate"] as? String,
              let rShift = dict["requesterShiftName"] as? String else { return nil }

        let statusStr = dict["status"] as? String ?? "SEARCHING"

        return ShiftChangeRequest(
            id: id,
            type: .swap,
            status: RequestStatus(rawValue: statusStr) ?? .searching,
            requesterId: rId,
            requesterName: rName,
            requesterRole: rRole,
            requesterShiftDate: rDate,
            requesterShiftName: rShift,
            targetUserId: dict["targetUserId"] as? String,
            targetUserName: dict["targetUserName"] as? String,
            targetShiftDate: dict["targetShiftDate"] as? String,
            targetShiftName: dict["targetShiftName"] as? String
        )
    }
}
