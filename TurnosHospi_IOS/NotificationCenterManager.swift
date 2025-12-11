import Foundation

struct NotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let message: String
    let timestamp: Date
}

class NotificationCenterManager: ObservableObject {
    @Published private(set) var notifications: [NotificationItem] = []
    private var currentUserId: String?
    private let storage = UserDefaults.standard
    
    var unreadCount: Int {
        return notifications.count
    }
    
    func setCurrentUser(id: String?) {
        guard currentUserId != id else { return }
        currentUserId = id
        loadNotifications()
    }
    
    func addNotification(message: String) {
        guard currentUserId != nil else { return }
        let item = NotificationItem(id: UUID().uuidString, message: message, timestamp: Date())
        notifications.insert(item, at: 0)
        persistNotifications()
    }
    
    func removeNotifications(at offsets: IndexSet) {
        notifications.remove(atOffsets: offsets)
        persistNotifications()
    }
    
    func remove(_ item: NotificationItem) {
        notifications.removeAll { $0.id == item.id }
        persistNotifications()
    }
    
    func clearAll() {
        notifications.removeAll()
        persistNotifications()
    }
    
    private func loadNotifications() {
        guard let uid = currentUserId, !uid.isEmpty else {
            notifications = []
            return
        }
        let key = storageKey(for: uid)
        if let data = storage.data(forKey: key),
           let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) {
            notifications = decoded.sorted { $0.timestamp > $1.timestamp }
        } else {
            notifications = []
        }
    }
    
    private func persistNotifications() {
        guard let uid = currentUserId, !uid.isEmpty else { return }
        let key = storageKey(for: uid)
        if let data = try? JSONEncoder().encode(notifications) {
            storage.set(data, forKey: key)
        }
    }
    
    private func storageKey(for uid: String) -> String {
        return "notifications_\(uid)"
    }
}
