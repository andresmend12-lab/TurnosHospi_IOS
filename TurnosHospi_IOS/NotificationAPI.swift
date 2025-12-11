import Foundation
import FirebaseDatabase

/// Helper responsible for writing notification records to Firebase so Cloud Functions can deliver pushes.
final class NotificationAPI {
    static let shared = NotificationAPI()
    private let ref = Database.database().reference()

    private init() {}

    /// Persists a notification under `user_notifications/{userId}`.
    func saveNotification(
        to userId: String,
        title: String,
        message: String,
        targetScreen: String,
        targetId: String?,
        argument: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard !userId.isEmpty,
              !userId.starts(with: "UNREGISTERED"),
              userId != "GROUP_CHAT_FANOUT_ID",
              userId != "SUPERVISOR_ID_PLACEHOLDER",
              userId != "SHIFT_STAFF_PLACEHOLDER" else {
            completion?(true)
            return
        }

        let node = ref.child("user_notifications").child(userId).childByAutoId()
        let notificationId = node.key ?? UUID().uuidString
        var payload: [String: Any] = [
            "id": notificationId,
            "title": title,
            "message": message,
            "targetScreen": targetScreen,
            "timestamp": ServerValue.timestamp(),
            "read": false
        ]
        if let targetId = targetId {
            payload["targetId"] = targetId
        }
        if let argument = argument {
            payload["argument"] = argument
        }

        node.setValue(payload) { error, _ in
            completion?(error == nil)
        }
    }

    /// Sends the same notification to every user registered under a plant, excluding the sender.
    func broadcastToPlant(
        plantId: String,
        excluding excludedUserId: String?,
        title: String,
        message: String,
        targetScreen: String,
        argument: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        let usersRef = ref.child("plants").child(plantId).child("userPlants")
        usersRef.observeSingleEvent(of: .value) { snapshot in
            var pending = 0
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let uid = child.key
                if uid == excludedUserId { continue }
                pending += 1
                self.saveNotification(
                    to: uid,
                    title: title,
                    message: message,
                    targetScreen: targetScreen,
                    targetId: plantId,
                    argument: argument
                ) { _ in
                    pending -= 1
                    if pending == 0 {
                        completion?()
                    }
                }
            }
            if pending == 0 {
                completion?()
            }
        }
    }
}
