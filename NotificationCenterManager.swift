import Foundation
import FirebaseDatabase
import FirebaseAuth

// 1. Actualizamos el modelo para incluir 'title' y 'read'
struct NotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String      // Nuevo campo
    let message: String
    let timestamp: Date
    var read: Bool         // Nuevo campo
}

private struct TrackedShiftRequestState {
    let status: RequestStatus
    let targetUserId: String?
}

class NotificationCenterManager: ObservableObject {
    @Published private(set) var notifications: [NotificationItem] = []
    
    private var currentUserId: String?
    private var currentPlantId: String?
    private var isCurrentUserSupervisor = false
    private let storage = UserDefaults.standard
    private let ref = Database.database().reference()
    private var shiftRequestsRef: DatabaseReference?
    private var shiftRequestsHandle: DatabaseHandle?
    private var lastShiftRequestStates: [String: TrackedShiftRequestState] = [:]
    private var shiftRequestsInitialized = false
    
    // Propiedad calculada para el contador
    var unreadCount: Int {
        return notifications.filter { !$0.read }.count
    }
    
    func updateContext(userId: String?, plantId: String?, isSupervisor: Bool) {
        let userChanged = userId != currentUserId
        let plantChanged = plantId != currentPlantId
        let roleChanged = isSupervisor != isCurrentUserSupervisor
        
        currentUserId = userId
        currentPlantId = plantId
        isCurrentUserSupervisor = isSupervisor
        
        if userChanged {
            loadNotifications()
        }
        
        if userId?.isEmpty ?? true || plantId?.isEmpty ?? true {
            stopListeningShiftRequests()
            return
        }
        
        if userChanged || plantChanged || roleChanged {
            stopListeningShiftRequests()
            startListeningShiftRequests()
        }
    }
    
    // 2. Método actualizado para incluir título y estado de lectura
    func addNotification(title: String = "Aviso", message: String, sendPush: Bool = true) {
        guard currentUserId != nil else { return }
        
        let item = NotificationItem(
            id: UUID().uuidString,
            title: title,
            message: message,
            timestamp: Date(),
            read: false
        )
        
        notifications.insert(item, at: 0)
        persistNotifications()
        
        if sendPush {
            enqueuePushNotification(message: message)
        }
    }
    
    func addScheduleNotification(message: String) {
        addNotification(title: "Turnos", message: message, sendPush: true)
    }
    
    // 3. Renombrado de 'remove' a 'delete' para coincidir con la vista
    func delete(_ item: NotificationItem) {
        notifications.removeAll { $0.id == item.id }
        persistNotifications()
    }
    
    // 4. Nuevo método para marcar como leído
    func markAsRead(_ item: NotificationItem) {
        if let index = notifications.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.read = true
            notifications[index] = updatedItem
            persistNotifications()
        }
    }
    
    func clearAll() {
        notifications.removeAll()
        persistNotifications()
    }
    
    // MARK: - Persistencia
    
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
    
    // MARK: - Lógica de Firebase (Turnos)
    
    private func startListeningShiftRequests() {
        guard let uid = currentUserId,
              let plantId = currentPlantId,
              !uid.isEmpty,
              !plantId.isEmpty else { return }
        
        let nodeRef = ref.child("plants").child(plantId).child("shift_requests")
        shiftRequestsRef = nodeRef
        
        shiftRequestsHandle = nodeRef.observe(.value) { [weak self] snapshot in
            guard let self else { return }
            var newStates: [String: TrackedShiftRequestState] = [:]
            var requestData: [String: [String: Any]] = [:]
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any],
                      let statusString = dict["status"] as? String,
                      let status = RequestStatus(rawValue: statusString) else { continue }
                
                let state = TrackedShiftRequestState(
                    status: status,
                    targetUserId: dict["targetUserId"] as? String
                )
                newStates[child.key] = state
                requestData[child.key] = dict
            }
            
            if !self.shiftRequestsInitialized {
                self.lastShiftRequestStates = newStates
                self.shiftRequestsInitialized = true
                return
            }
            
            for (requestId, state) in newStates {
                guard let data = requestData[requestId] else { continue }
                let previous = self.lastShiftRequestStates[requestId]
                self.handleShiftRequestChange(
                    data: data,
                    previous: previous,
                    current: state
                )
            }
            
            self.lastShiftRequestStates = newStates
        }
    }
    
    private func stopListeningShiftRequests() {
        if let handle = shiftRequestsHandle {
            shiftRequestsRef?.removeObserver(withHandle: handle)
        }
        shiftRequestsRef = nil
        shiftRequestsHandle = nil
        shiftRequestsInitialized = false
        lastShiftRequestStates = [:]
    }
    
    private func handleShiftRequestChange(
        data: [String: Any],
        previous: TrackedShiftRequestState?,
        current: TrackedShiftRequestState
    ) {
        guard shiftRequestsInitialized,
              let uid = currentUserId else { return }
        
        let requesterId = data["requesterId"] as? String ?? ""
        let requesterName = data["requesterName"] as? String ?? "Compañero"
        let targetUserId = data["targetUserId"] as? String
        let targetName = data["targetUserName"] as? String ?? "Compañero"
        let shiftDate = data["requesterShiftDate"] as? String ?? ""
        let shiftName = data["requesterShiftName"] as? String ?? ""
        
        let userIsRequester = requesterId == uid
        let userIsTarget = targetUserId == uid
        
        switch current.status {
        case .pendingPartner:
            if userIsTarget && (previous?.status != .pendingPartner || previous?.targetUserId != uid) {
                addNotification(title: "Solicitud de Cambio", message: "\(requesterName) quiere intercambiar su turno \(shiftName) del \(shiftDate) contigo.")
            }
        case .awaitingSupervisor:
            if previous?.status != .awaitingSupervisor {
                if userIsRequester {
                    addNotification(title: "Cambio Aceptado", message: "\(targetName) aceptó tu solicitud para \(shiftName) del \(shiftDate).")
                }
                if isCurrentUserSupervisor {
                    addNotification(title: "Aprobación Requerida", message: "\(requesterName) y \(targetName) esperan tu aprobación para el cambio del \(shiftDate).")
                }
            }
        case .rejected:
            if previous?.status == .pendingPartner && userIsRequester {
                addNotification(title: "Solicitud Rechazada", message: "\(targetName) rechazó tu solicitud para \(shiftName) del \(shiftDate).")
            } else if previous?.status == .awaitingSupervisor && (userIsRequester || userIsTarget) {
                addNotification(title: "Cambio Denegado", message: "El supervisor rechazó el cambio \(shiftName) del \(shiftDate).")
            }
        case .approved:
            if previous?.status != .approved && (userIsRequester || userIsTarget) {
                addNotification(title: "Cambio Aprobado", message: "El supervisor aprobó el cambio \(shiftName) del \(shiftDate).")
            }
        default:
            break
        }
    }
    
    private func enqueuePushNotification(message: String) {
        guard let targetUserId = currentUserId, !targetUserId.isEmpty else { return }
        
        let notifRef = ref.child("notifications_queue").childByAutoId()
        let senderId = Auth.auth().currentUser?.uid ?? targetUserId
        let senderName = AuthManager.shared.currentUserName
        let payload: [String: Any] = [
            "targetUserId": targetUserId,
            "senderId": senderId,
            "senderName": senderName,
            "type": "IN_APP_NOTIFICATION",
            "message": message,
            "targetScreen": "NotificationCenter",
            "plantId": currentPlantId ?? "",
            "timestamp": ServerValue.timestamp()
        ]
        notifRef.setValue(payload)
    }
}
