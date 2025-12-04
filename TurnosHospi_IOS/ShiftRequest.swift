import Foundation

// MARK: - Enums de Solicitudes
enum ChangeRequestStatus: String, Codable {
    case draft = "DRAFT"
    case searching = "SEARCHING"
    case pendingPartner = "PENDING_PARTNER"
    case awaitingSupervisor = "AWAITING_SUPERVISOR"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

enum ChangeType: String, Codable {
    case swap = "SWAP"
    case coverage = "COVERAGE"
}

// MARK: - Modelo de Solicitud de Cambio
struct ShiftChangeRequest: Codable, Identifiable {
    let id: String
    let type: ChangeType
    var status: ChangeRequestStatus
    
    // Solicitante
    let requesterId: String
    let requesterName: String
    let requesterShiftDate: String
    let requesterShiftName: String
    
    // Destinatario (Opcional si es búsqueda abierta)
    var targetUserId: String?
    var targetUserName: String?
    var targetShiftDate: String?
    
    // Fechas ofrecidas para intercambio (Swap)
    var offeredDates: [String]?
    
    // Metadatos
    var createdAt: TimeInterval?
}
