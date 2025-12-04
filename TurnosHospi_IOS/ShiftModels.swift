import Foundation

// MARK: - Enums

enum UserRole: String, Codable, CaseIterable {
    case supervisor = "Supervisor"
    case enfermero = "Enfermero"
    case auxiliar = "Auxiliar"
}

enum ShiftType: String, Codable {
    case morning = "Mañana"
    case afternoon = "Tarde"
    case night = "Noche"
    case unknown = "Desconocido"
}

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

// MARK: - Structs

struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    var fcmToken: String?
    
    // Computed property para nombre completo
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

struct Plant: Codable, Identifiable {
    let id: String
    let name: String
    let accessPassword: String
    let shiftDuration: Int // Duración en horas
    let shiftTimes: [String: String] // Ej: ["morning_start": "08:00", "morning_end": "15:00"]
    var staffRequirements: [String: Int]? // Ej: ["Enfermero_Morning": 3]
}

struct PlantMembership: Codable {
    let plantId: String
    let userId: String
    let staffId: String // ID interno en el hospital o número de colegiado
    let staffName: String
    let staffRole: UserRole
}

struct UserShift: Codable, Identifiable, Hashable {
    // Generamos un ID único combinando fecha y turno para listas en SwiftUI
    var id: String { "\(date)_\(shiftName)" }
    
    let date: String // Formato YYYY-MM-DD
    let shiftName: String // "Mañana", "Tarde", "Noche"
    let isHalfDay: Bool
    
    // Implementación de Hashable manual si fuera necesaria,
    // pero Swift la sintetiza automáticamente al ser propiedades básicas.
}

struct ShiftChangeRequest: Codable, Identifiable {
    let id: String
    let type: ChangeType
    var status: ChangeRequestStatus
    
    // Datos del solicitante
    let requesterId: String
    let requesterName: String
    let requesterShiftDate: String
    let requesterShiftName: String
    
    // Datos del destinatario (puede ser nulo si es una búsqueda abierta en la bolsa)
    var targetUserId: String?
    var targetUserName: String?
    var targetShiftDate: String?
    
    // Lista de fechas que el solicitante acepta a cambio (para SWAP)
    var offeredDates: [String]?
    
    // Timestamp de creación (opcional, útil para ordenar)
    var createdAt: TimeInterval?
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: TimeInterval
    
    // Helper para formatear la hora en la UI
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
