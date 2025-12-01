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

    func listenToUserShifts(plantId: String, userId: String, onChange: @escaping ([Shift]) -> Void) -> (DatabaseReference, DatabaseHandle) {
        let ref = database.child("plants").child(plantId).child("userPlants").child(userId).child("shifts")
        let handle = ref.observe(.value) { snapshot in
            var shifts: [Shift] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let raw = child.value as? [String: Any] else { continue }
                let dateValue = raw["date"] as? TimeInterval ?? 0
                let statusString = raw["status"] as? String ?? Shift.Status.assigned.rawValue
                let shift = Shift(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: dateValue / 1000),
                    name: raw["name"] as? String ?? (raw["shiftName"] as? String ?? "Turno"),
                    location: raw["location"] as? String ?? "",
                    status: mapStatus(statusString),
                    isNight: raw["isNight"] as? Bool ?? false,
                    notes: raw["notes"] as? String ?? ""
                )
                shifts.append(shift)
            }
            onChange(shifts.sorted { $0.date < $1.date })
        }
        return (ref, handle)
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
