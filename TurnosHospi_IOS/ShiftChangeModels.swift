import Foundation

enum ChangeStatus: String, Codable {
    case pending = "Pendiente"
    case accepted = "Aceptado"
    case rejected = "Rechazado"
}

struct ShiftChangeRequest: Identifiable, Codable {
    let id: String
    let requesterId: String
    let requesterName: String
    let originalShiftDate: String // formato yyyy-MM-dd
    let originalShiftType: String // "Mañana", "Tarde", etc.
    let targetDate: String?       // Opcional: Si busca un día específico a cambio
    let targetShiftType: String?
    let status: ChangeStatus
    let timestamp: TimeInterval
    
    // Inicializador para crear una nueva solicitud
    init(id: String = UUID().uuidString, requesterId: String, requesterName: String, originalShiftDate: String, originalShiftType: String, targetDate: String? = nil, targetShiftType: String? = nil) {
        self.id = id
        self.requesterId = requesterId
        self.requesterName = requesterName
        self.originalShiftDate = originalShiftDate
        self.originalShiftType = originalShiftType
        self.targetDate = targetDate
        self.targetShiftType = targetShiftType
        self.status = .pending
        self.timestamp = Date().timeIntervalSince1970
    }
}
