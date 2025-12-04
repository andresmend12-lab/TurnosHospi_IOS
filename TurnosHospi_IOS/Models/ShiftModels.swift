import Foundation

// --- ENUMS ---
enum RequestType: String, Codable {
    case coverage = "COVERAGE"
    case swap = "SWAP"
}

enum RequestMode: String, Codable {
    case strict = "STRICT"
    case flexible = "FLEXIBLE"
}

enum RequestStatus: String, Codable {
    case draft = "DRAFT"
    case searching = "SEARCHING"
    case pendingPartner = "PENDING_PARTNER"
    case awaitingSupervisor = "AWAITING_SUPERVISOR"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

// --- DATA STRUCTS ---

// Solicitud de cambio/cobertura
struct ShiftChangeRequest: Identifiable, Codable {
    var id: String = ""
    var type: RequestType = .swap
    var status: RequestStatus = .searching
    var mode: RequestMode = .flexible
    var hardnessLevel: Hardness = .normal // Definido en ShiftRulesEngine
    var requesterId: String = ""
    var requesterName: String = ""
    var requesterRole: String = ""
    var requesterShiftDate: String = ""
    var requesterShiftName: String = ""
    var offeredDates: [String] = []
    
    // Target fields added for swap logic
    var targetUserId: String? = nil
    var targetUserName: String? = nil
    var targetShiftDate: String? = nil
    var targetShiftName: String? = nil
    
    // Timestamp en milisegundos para compatibilidad con Android/Firebase
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}

// Historial de favores (Marketplace)
struct FavorTransaction: Identifiable, Codable {
    var id: String = ""
    var covererId: String = ""
    var covererName: String = ""
    var requesterId: String = ""
    var requesterName: String = ""
    var date: String = ""
    var shiftName: String = ""
    var timestamp: Int64 = 0
}

// Visualización de mis turnos en calendario
struct MyShiftDisplay: Identifiable {
    var id = UUID()
    let date: String
    let shiftName: String
    let fullDate: Date
    var isHalfDay: Bool = false
}

// Turno genérico de planta para listas y selección
struct PlantShift: Identifiable {
    var id = UUID()
    let userId: String
    let userName: String
    let userRole: String
    let date: Date
    let shiftName: String
}
