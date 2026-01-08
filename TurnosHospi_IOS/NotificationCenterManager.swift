import Foundation
import FirebaseDatabase

struct NotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let message: String
    let timestamp: Date
    let read: Bool
    let targetScreen: String?
    let targetId: String?
    let argument: String?
}

final class NotificationCenterManager: ObservableObject {
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var unreadCount: Int = 0

    private var currentUserId: String?
    private var currentPlantId: String?

    private let ref = Database.database().reference()
    private var notificationsRef: DatabaseReference?
    private var notificationsHandle: DatabaseHandle?

    func updateContext(userId: String?, plantId: String?, isSupervisor: Bool) {
        let userChanged = userId != currentUserId
        currentUserId = userId
        currentPlantId = plantId

        if userChanged {
            stopListeningUserNotifications()
            notifications = []
            unreadCount = 0
        }

        guard let uid = userId, !uid.isEmpty else { return }

        if userChanged {
            startListeningUserNotifications(for: uid)
        }
    }

    func addScheduleNotification(message: String) {
        guard let uid = currentUserId else { return }
        NotificationAPI.shared.saveNotification(
            to: uid,
            title: "Actualización de turnos",
            message: message,
            targetScreen: "MainMenu",
            targetId: currentPlantId,
            argument: nil,
            completion: nil
        )
    }

    func markAsRead(_ item: NotificationItem) {
        guard let uid = currentUserId else { return }
        ref.child("user_notifications").child(uid).child(item.id).child("read").setValue(true)
    }

    func delete(_ item: NotificationItem) {
        guard let uid = currentUserId else { return }
        ref.child("user_notifications").child(uid).child(item.id).removeValue()
    }

    func clearAll() {
        guard let uid = currentUserId else { return }
        ref.child("user_notifications").child(uid).removeValue()
    }

    private func startListeningUserNotifications(for userId: String) {
        stopListeningUserNotifications()
        notificationsRef = ref.child("user_notifications").child(userId)
        notificationsHandle = notificationsRef?.observe(.value, with: { [weak self] snapshot in
            guard let self else { return }
            var newItems: [NotificationItem] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                let timestampValue = dict["timestamp"] as? TimeInterval ?? 0
                let timestamp: Date
                if timestampValue > 1_000_000_000_000 {
                    timestamp = Date(timeIntervalSince1970: timestampValue / 1000)
                } else if timestampValue > 0 {
                    timestamp = Date(timeIntervalSince1970: timestampValue)
                } else if let serverTimestamp = dict["timestamp"] as? NSNumber {
                    timestamp = Date(timeIntervalSince1970: serverTimestamp.doubleValue / 1000)
                } else {
                    timestamp = Date()
                }

                let item = NotificationItem(
                    id: child.key,
                    title: dict["title"] as? String ?? "TurnosHospi",
                    message: dict["message"] as? String ?? "",
                    timestamp: timestamp,
                    read: dict["read"] as? Bool ?? false,
                    targetScreen: dict["targetScreen"] as? String,
                    targetId: dict["targetId"] as? String,
                    argument: dict["argument"] as? String
                )
                newItems.append(item)
            }

            DispatchQueue.main.async {
                self.notifications = newItems.sorted { $0.timestamp > $1.timestamp }
                self.unreadCount = self.notifications.filter { !$0.read }.count
            }
        })
    }

    private func stopListeningUserNotifications() {
        if let handle = notificationsHandle {
            notificationsRef?.removeObserver(withHandle: handle)
        }
        notificationsHandle = nil
        notificationsRef = nil
    }
}
