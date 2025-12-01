import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseMessaging
import UserNotifications
import UIKit

@MainActor
final class FirebaseService: NSObject, ObservableObject {
    static let shared = FirebaseService()
    private let databaseURL = "https://turnoshospi-f4870-default-rtdb.firebaseio.com/"
    private var notificationsHandle: DatabaseHandle?
    private var notificationsRef: DatabaseReference?

    private override init() {
        super.init()
    }

    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    private var database: DatabaseReference {
        Database.database(url: databaseURL).reference()
    }

    // MARK: - Notifications

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func handleAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func updateFCMToken(_ fcmToken: String?) {
        guard let fcmToken, let uid = Auth.auth().currentUser?.uid else { return }
        database.child("users").child(uid).child("fcmToken").setValue(fcmToken)
    }

    func refreshMessagingToken() {
        Messaging.messaging().token { [weak self] token, error in
            guard error == nil else { return }
            self?.updateFCMToken(token)
        }
    }

    func listenToNotifications(userId: String, onChange: @escaping ([NotificationItem]) -> Void) {
        notificationsHandle.map { handle in
            notificationsRef?.removeObserver(withHandle: handle)
        }
        let ref = database.child("user_notifications").child(userId)
        notificationsRef = ref
        notificationsHandle = ref
            .queryOrdered(byChild: "timestamp")
            .observe(.value) { snapshot in
                var items: [NotificationItem] = []
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    guard let raw = child.value as? [String: Any] else { continue }
                    let timestamp = raw["timestamp"] as? TimeInterval ?? 0
                    let type = raw["type"] as? String ?? ""
                    let lowercasedType = type.lowercased()
                    let normalizedKind = NotificationItem.Kind(rawValue: lowercasedType)
                        ?? (lowercasedType.contains("chat") ? .chat : nil)
                        ?? (lowercasedType.contains("shift") ? .shift : .generic)
                    let item = NotificationItem(
                        id: child.key,
                        type: type.isEmpty ? "GENERIC" : type,
                        title: type.isEmpty ? "Notificación" : type,
                        message: raw["message"] as? String ?? "",
                        date: Date(timeIntervalSince1970: timestamp / 1000),
                        kind: normalizedKind,
                        isRead: raw["isRead"] as? Bool ?? false,
                        targetScreen: raw["targetScreen"] as? String,
                        targetId: raw["targetId"] as? String
                    )
                    items.append(item)
                }
                onChange(items.sorted { $0.date > $1.date })
            }
    }

    func markNotificationAsRead(userId: String, notificationId: String) {
        database.child("user_notifications").child(userId).child(notificationId).child("isRead").setValue(true)
    }

    func deleteNotification(userId: String, notificationId: String) {
        database.child("user_notifications").child(userId).child(notificationId).removeValue()
    }

    func clearNotifications(userId: String) {
        database.child("user_notifications").child(userId).removeValue()
    }

    func stopListeningNotifications() {
        guard let ref = notificationsRef, let handle = notificationsHandle else { return }
        ref.removeObserver(withHandle: handle)
        notificationsHandle = nil
        notificationsRef = nil
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        return result.user
    }

    func createAccount(profile: UserProfile, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: profile.email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        let now = Date()
        let payload: [String: Any] = [
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "role": profile.role,
            "gender": profile.gender,
            "email": profile.email,
            "plantId": profile.plantId ?? "",
            "specialty": profile.specialty,
            "createdAt": Int(now.timeIntervalSince1970 * 1000),
            "updatedAt": Int(now.timeIntervalSince1970 * 1000)
        ]
        try await database.child("users").child(result.user.uid).setValue(payload)
        return result.user
    }

    func createPlant(name: String, code: String, description: String, creator: UserProfile) async throws -> Plant {
        let plantId = code.uppercased()
        let plantPayload: [String: Any] = [
            "id": plantId,
            "name": name,
            "description": description,
            "hospitalName": description,
            "createdBy": creator.id,
            "createdAt": Int(Date().timeIntervalSince1970 * 1000)
        ]

        try await database.child("plants").child(plantId).setValue(plantPayload)
        try await link(userId: creator.id, toPlant: plantId)

        return Plant(id: plantId, name: name, code: plantId, description: description, members: StaffMember.demoMembers, staffRequirements: [:], shiftTimes: [:])
    }

    func joinPlant(code: String, userId: String) async throws -> Plant {
        let plantId = code.uppercased()
        let snapshot = try await database.child("plants").child(plantId).getData()
        guard let raw = snapshot.value as? [String: Any], let plant = Plant(firebase: raw, id: plantId) else {
            throw NSError(domain: "Plant", code: 404, userInfo: [NSLocalizedDescriptionKey: "Planta no encontrada"])
        }
        try await link(userId: userId, toPlant: plantId)
        return plant
    }

    private func link(userId: String, toPlant plantId: String) async throws {
        try await database.child("users").child(userId).child("plantId").setValue(plantId)
        try await database.child("plants").child(plantId).child("userPlants").child(userId).setValue(["role": "member"])
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Data

    func loadUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await database.child("users").child(userId).getData()
        guard let raw = snapshot.value as? [String: Any] else { return nil }
        return UserProfile(
            id: userId,
            firstName: raw["firstName"] as? String ?? "",
            lastName: raw["lastName"] as? String ?? "",
            role: raw["role"] as? String ?? "",
            gender: raw["gender"] as? String ?? "",
            email: raw["email"] as? String ?? "",
            plantId: raw["plantId"] as? String,
            avatarSystemName: "person.crop.circle.fill",
            specialty: raw["specialty"] as? String ?? "",
            createdAt: (raw["createdAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) },
            updatedAt: (raw["updatedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }

    func loadPlant(for userId: String) async throws -> Plant? {
        let mapping = try await database.child("users").child(userId).child("plantId").getData()
        guard let plantId = mapping.value as? String, !plantId.isEmpty else { return nil }
        let snapshot = try await database.child("plants").child(plantId).getData()
        guard let raw = snapshot.value as? [String: Any] else { return nil }
        return Plant(firebase: raw, id: plantId)
    }

    func fetchPlantMembers(plantId: String) async -> [String: UserProfile] {
        var members: [String: UserProfile] = [:]
        do {
            let plantMembers = try await database.child("plants").child(plantId).child("userPlants").getData()
            for child in plantMembers.children.allObjects as? [DataSnapshot] ?? [] {
                let uid = child.key
                let userSnap = try await database.child("users").child(uid).getData()
                if let raw = userSnap.value as? [String: Any], let profile = Self.makeProfile(from: raw, id: uid) {
                    members[uid] = profile
                }
            }
        } catch {
            return members
        }
        return members
    }

    func fetchUserSchedule(plantId: String, userId: String) async -> [Date: String] {
        var schedule: [Date: String] = [:]
        do {
            let snapshot = try await database.child("plants").child(plantId).child("userPlants").child(userId).child("shifts").getData()
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let dateValue = raw["date"] as? TimeInterval ?? 0
                let date = Date(timeIntervalSince1970: dateValue / 1000)
                let name = raw["name"] as? String ?? (raw["shiftName"] as? String ?? "Turno")
                schedule[Calendar.current.startOfDay(for: date)] = name
            }
        } catch {
            return schedule
        }
        return schedule
    }

    func listenToUserShifts(plantId: String, userId: String, onChange: @escaping ([Shift]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("userPlants").child(userId).child("shifts")
        let handle = ref.observe(.value) { snapshot in
            var shifts: [Shift] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let dateValue = raw["date"] as? TimeInterval ?? 0
                let statusString = raw["status"] as? String ?? Shift.Status.assigned.rawValue
                let segmentRaw = (raw["segment"] as? String ?? raw["type"] as? String) ?? Shift.Segment.fullDay.rawValue
                let shift = Shift(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: dateValue / 1000),
                    name: raw["name"] as? String ?? (raw["shiftName"] as? String ?? "Turno"),
                    location: raw["location"] as? String ?? "",
                    status: mapStatus(statusString),
                    isNight: raw["isNight"] as? Bool ?? false,
                    notes: raw["notes"] as? String ?? "",
                    segment: Shift.Segment(rawValue: segmentRaw.uppercased()) ?? .fullDay,
                    hours: raw["hours"] as? Double ?? (raw["segment"] as? String == Shift.Segment.halfDay.rawValue ? 6 : 12)
                )
                shifts.append(shift)
            }
            onChange(shifts.sorted { $0.date < $1.date })
        }
        return (ref, handle)
    }

    func listenToShiftRequests(plantId: String, currentUserId: String, onChange: @escaping ([ShiftChangeRequest]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("shift_requests")
        let handle = ref
            .queryOrdered(byChild: "status")
            .queryEqual(toValue: RequestStatus.searching.rawValue)
            .observe(.value) { snapshot in
                var requests: [ShiftChangeRequest] = []
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    guard let raw = child.value as? [String: Any],
                          let request = ShiftChangeRequest(firebase: raw, id: child.key),
                          request.requesterId != currentUserId else { continue }
                    requests.append(request)
                }
                onChange(requests.sorted { $0.timestamp > $1.timestamp })
            }
        return (ref, handle)
    }

    func listenToGroupChat(plantId: String, currentUserId: String, onChange: @escaping ([ChatMessage]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("chat")
        let handle = ref.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let message = ChatMessage(
                    id: child.key,
                    senderId: raw["senderId"] as? String ?? "",
                    senderName: raw["senderName"] as? String ?? "",
                    text: raw["text"] as? String ?? "",
                    date: Date(timeIntervalSince1970: (raw["timestamp"] as? TimeInterval ?? 0) / 1000),
                    isMine: (raw["senderId"] as? String ?? "") == currentUserId
                )
                messages.append(message)
            }
            onChange(messages.sorted { $0.date < $1.date })
        }
        return (ref, handle)
    }

    func sendGroupMessage(plantId: String, user: UserProfile, text: String) {
        let payload: [String: Any] = [
            "senderId": user.id,
            "senderName": user.name,
            "text": text,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        database.child("plants").child(plantId).child("chat").childByAutoId().setValue(payload)
    }

    func respondToShiftRequest(plantId: String, request: ShiftChangeRequest, responder: UserProfile, selectedShift: Shift?) {
        let ref = database.child("plants").child(plantId).child("shift_requests").child(request.id)
        var payload: [String: Any] = [
            "status": RequestStatus.pendingPartner.rawValue,
            "targetUserId": responder.id,
            "targetUserName": responder.name
        ]
        if let selectedShift {
            payload["targetShiftDate"] = Int(selectedShift.date.timeIntervalSince1970 * 1000)
            payload["targetShiftName"] = selectedShift.name
        }
        ref.updateChildValues(payload)
    }

    func listenToDirectChats(plantId: String, currentUserId: String, onChange: @escaping ([ChatThread]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("direct_chats")
        let handle = ref.observe(.value) { snapshot in
            var threads: [ChatThread] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let chatId = child.key, chatId.contains(currentUserId) else { continue }
                let ids = chatId.components(separatedBy: "_")
                guard let otherId = ids.first(where: { $0 != currentUserId }) else { continue }
                let messagesSnapshot = child.childSnapshot(forPath: "messages")
                let lastMessageSnap = messagesSnapshot.children.allObjects.last as? DataSnapshot
                let lastText = lastMessageSnap?.childSnapshot(forPath: "text").value as? String ?? ""
                let timestamp = lastMessageSnap?.childSnapshot(forPath: "timestamp").value as? TimeInterval ?? 0
                let unread = child.childSnapshot(forPath: "unread").childSnapshot(forPath: currentUserId).value as? Int ?? 0
                let thread = ChatThread(
                    id: chatId,
                    otherUserId: otherId,
                    otherUserName: otherId,
                    lastMessage: lastText,
                    unreadCount: unread,
                    updatedAt: Date(timeIntervalSince1970: timestamp / 1000),
                    messages: []
                )
                threads.append(thread)
            }
            onChange(threads.sorted { $0.updatedAt > $1.updatedAt })
        }
        return (ref, handle)
    }

    func listenToMessages(plantId: String, chatId: String, currentUserId: String, onChange: @escaping ([ChatMessage]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("direct_chats").child(chatId).child("messages")
        let handle = ref.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let senderId = raw["userId"] as? String ?? ""
                let senderName = raw["userName"] as? String ?? ""
                let text = raw["text"] as? String ?? ""
                let timestamp = raw["timestamp"] as? TimeInterval ?? 0
                let message = ChatMessage(
                    id: child.key,
                    senderId: senderId,
                    senderName: senderName.isEmpty ? senderId : senderName,
                    text: text,
                    date: Date(timeIntervalSince1970: timestamp / 1000),
                    isMine: senderId == currentUserId
                )
                messages.append(message)
            }
            onChange(messages.sorted { $0.date < $1.date })
        }
        return (ref, handle)
    }

    func sendMessage(plantId: String, chatId: String, user: UserProfile, text: String) {
        let ref = database.child("plants").child(plantId).child("direct_chats").child(chatId).child("messages").childByAutoId()
        let payload: [String: Any] = [
            "text": text,
            "userId": user.id,
            "userName": user.name,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        ref.setValue(payload)
    }

    func listenToVacations(plantId: String, userId: String, onChange: @escaping ([VacationRecord]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("vacations").child(userId)
        let handle = ref.observe(.value) { snapshot in
            var records: [VacationRecord] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let record = VacationRecord(
                    id: child.key,
                    userId: userId,
                    startDate: ShiftChangeRequest.parseDate(raw["startDate"]) ?? Date(),
                    endDate: ShiftChangeRequest.parseDate(raw["endDate"]) ?? Date(),
                    status: VacationRecord.Status(rawValue: (raw["status"] as? String ?? "").uppercased()) ?? .pending,
                    notes: raw["notes"] as? String ?? ""
                )
                records.append(record)
            }
            onChange(records.sorted { $0.startDate < $1.startDate })
        }
        return (ref, handle)
    }

    func submitSuggestion(userId: String, message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let ref = database.child("suggestions").child(userId).childByAutoId()
        let payload: [String: Any] = [
            "message": message,
            "status": "ENVIADO",
            "createdAt": Int(Date().timeIntervalSince1970 * 1000)
        ]
        do { try await ref.setValue(payload) } catch {}
    }

    func listenToSuggestions(userId: String, onChange: @escaping ([Suggestion]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("suggestions").child(userId)
        let handle = ref.observe(.value) { snapshot in
            var suggestions: [Suggestion] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let createdAt = ShiftChangeRequest.parseDate(raw["createdAt"]) ?? Date()
                suggestions.append(Suggestion(
                    id: child.key,
                    userId: userId,
                    message: raw["message"] as? String ?? "",
                    createdAt: createdAt,
                    status: raw["status"] as? String ?? "ENVIADO"
                ))
            }
            onChange(suggestions.sorted { $0.createdAt > $1.createdAt })
        }
        return (ref, handle)
    }

    func buildStats(from shifts: [Shift], vacations: [VacationRecord], suggestions: [Suggestion], completedSwaps: Int) -> ShiftStats {
        let totalHours = shifts.reduce(0) { $0 + $1.hours }
        let nightCount = shifts.filter { $0.isNight }.count
        let halfDays = shifts.filter { $0.segment == .halfDay }.count
        let vacationsCount = vacations.count + shifts.filter { $0.segment == .vacation }.count
        return ShiftStats(
            totalHours: totalHours,
            nightCount: nightCount,
            halfDays: halfDays,
            vacations: vacationsCount,
            swapsCompleted: completedSwaps,
            suggestionsSent: suggestions.count
        )
    }

    func ensureChatId(currentUserId: String, otherUserId: String) -> String {
        [currentUserId, otherUserId].sorted().joined(separator: "_")
    }

    func detachListener(ref: DatabaseReference?, handle: DatabaseHandle?) {
        guard let ref, let handle else { return }
        ref.removeObserver(withHandle: handle)
    }

    private func mapStatus(_ statusString: String) -> Shift.Status {
        let normalized = statusString.lowercased()
        switch normalized {
        case "assigned": return .assigned
        case "offered", "exchange", "in_exchange": return .offered
        case "swapped", "changed": return .swapped
        case "unavailable": return .unavailable
        default:
            return Shift.Status(rawValue: statusString) ?? Shift.Status(rawValue: statusString.capitalized) ?? .assigned
        }
    }
}

// MARK: - Firebase Messaging delegates

extension FirebaseService: MessagingDelegate, UNUserNotificationCenterDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateFCMToken(fcmToken)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

// MARK: - Model helpers

private extension Plant {
    init?(firebase raw: [String: Any], id: String) {
        let shiftTimesRaw = raw["shiftTimes"] as? [String: [String: String]] ?? [:]
        let shiftTimes = shiftTimesRaw.reduce(into: [String: ShiftTime]()) { partialResult, entry in
            guard let start = entry.value["start"], let end = entry.value["end"] else { return }
            partialResult[entry.key] = ShiftTime(start: start, end: end)
        }

        let staffRequirements = raw["staffRequirements"] as? [String: Int] ?? [:]
        let description = raw["unitType"] as? String ?? raw["hospitalName"] as? String ?? ""

        self.init(
            id: id,
            name: raw["name"] as? String ?? (raw["hospitalName"] as? String ?? "Planta"),
            code: raw["id"] as? String ?? id,
            description: description,
            members: StaffMember.demoMembers,
            staffRequirements: staffRequirements,
            shiftTimes: shiftTimes
        )
    }
}

private extension ShiftChangeRequest {
    init?(firebase raw: [String: Any], id: String) {
        let timestamp = raw["timestamp"]
        let offeredDatesRaw = raw["offeredDates"] as? [Any] ?? []
        let requesterDate = raw["requesterShiftDate"]

        guard let type = RequestType(rawValue: (raw["type"] as? String ?? "").uppercased()),
              let status = RequestStatus(rawValue: (raw["status"] as? String ?? "").uppercased()),
              let mode = RequestMode(rawValue: (raw["mode"] as? String ?? "").uppercased()) else { return nil }

        self.init(
            id: id,
            type: type,
            status: status,
            mode: mode,
            requesterId: raw["requesterId"] as? String ?? "",
            requesterName: raw["requesterName"] as? String ?? "",
            requesterRole: raw["requesterRole"] as? String ?? "",
            requesterShiftDate: Self.parseDate(requesterDate) ?? Date(),
            requesterShiftName: raw["requesterShiftName"] as? String ?? "",
            offeredDates: offeredDatesRaw.compactMap { Self.parseDate($0) },
            targetUserId: raw["targetUserId"] as? String,
            targetUserName: raw["targetUserName"] as? String,
            targetShiftDate: Self.parseDate(raw["targetShiftDate"]),
            targetShiftName: raw["targetShiftName"] as? String,
            timestamp: Self.parseDate(timestamp) ?? Date()
        )
    }

    static func parseDate(_ value: Any?) -> Date? {
        if let ms = value as? TimeInterval {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        if let str = value as? String {
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: str) { return date }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: str)
        }
        return nil
    }
}

private extension FirebaseService {
    static func makeProfile(from raw: [String: Any], id: String) -> UserProfile? {
        guard !(raw["email"] as? String ?? "").isEmpty else { return nil }
        return UserProfile(
            id: id,
            firstName: raw["firstName"] as? String ?? "",
            lastName: raw["lastName"] as? String ?? "",
            role: raw["role"] as? String ?? "",
            gender: raw["gender"] as? String ?? "",
            email: raw["email"] as? String ?? "",
            plantId: raw["plantId"] as? String,
            avatarSystemName: "person.crop.circle.fill",
            specialty: raw["specialty"] as? String ?? "",
            createdAt: (raw["createdAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) },
            updatedAt: (raw["updatedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
        )
    }
}
