import Foundation
import SwiftUI

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

enum ShiftHardness: String, Codable {
    case night = "NIGHT"
    case weekend = "WEEKEND"
    case holiday = "HOLIDAY"
    case normal = "NORMAL"
}

// --- DATA STRUCTS ---

// Solicitud de cambio/cobertura
struct ShiftChangeRequest: Identifiable, Codable {
    var id: String
    var type: RequestType
    var status: RequestStatus
    var mode: RequestMode
    var hardnessLevel: ShiftHardness
    var requesterId: String
    var requesterName: String
    var requesterRole: String
    var requesterShiftDate: String // Formato yyyy-MM-dd
    var requesterShiftName: String
    var offeredDates: [String] = []
    
    // Campos para intercambio (Swap)
    var targetUserId: String?
    var targetUserName: String?
    var targetShiftDate: String?
    var targetShiftName: String?
    var timestamp: TimeInterval = Date().timeIntervalSince1970
    
    // Inicializador por defecto para facilitar la creación
    init(id: String = UUID().uuidString,
         type: RequestType = .swap,
         status: RequestStatus = .searching,
         mode: RequestMode = .flexible,
         hardnessLevel: ShiftHardness = .normal,
         requesterId: String = "",
         requesterName: String = "",
         requesterRole: String = "",
         requesterShiftDate: String = "",
         requesterShiftName: String = "",
         offeredDates: [String] = [],
         targetUserId: String? = nil,
         targetUserName: String? = nil,
         targetShiftDate: String? = nil,
         targetShiftName: String? = nil) {
        
        self.id = id
        self.type = type
        self.status = status
        self.mode = mode
        self.hardnessLevel = hardnessLevel
        self.requesterId = requesterId
        self.requesterName = requesterName
        self.requesterRole = requesterRole
        self.requesterShiftDate = requesterShiftDate
        self.requesterShiftName = requesterShiftName
        self.offeredDates = offeredDates
        self.targetUserId = targetUserId
        self.targetUserName = targetUserName
        self.targetShiftDate = targetShiftDate
        self.targetShiftName = targetShiftName
    }
}

// Historial de favores (Marketplace)
struct FavorTransaction: Identifiable, Codable {
    var id: String
    var covererId: String
    var covererName: String
    var requesterId: String
    var requesterName: String
    var date: String
    var shiftName: String
    var timestamp: TimeInterval
}

// Visualización auxiliar para calendarios
struct MyShiftDisplay: Identifiable {
    var id: String { fullDateString }
    let dateString: String
    let shiftName: String
    let fullDate: Date
    let fullDateString: String // yyyy-MM-dd
}

// Turno genérico de planta
struct PlantShift: Identifiable {
    var id: String { "\(userId)_\(dateString)" }
    let userId: String
    let userName: String
    let userRole: String
    let date: Date
    let dateString: String
    let shiftName: String
}
