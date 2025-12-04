import Foundation

// MARK: - Enums de Turno
enum ShiftType: String, Codable {
    case morning = "Mañana"
    case afternoon = "Tarde"
    case night = "Noche"
    case unknown = "Desconocido"
}

// MARK: - Modelos de Turno
struct UserShift: Codable, Identifiable, Hashable {
    // ID compuesto para listas (Fecha_Turno)
    var id: String { "\(date)_\(shiftName)" }
    
    let date: String // YYYY-MM-DD
    let shiftName: String // "Mañana", "Tarde", "Noche"
    let isHalfDay: Bool
}

// MARK: - Modelos de Planta (Hospital)
struct Plant: Codable, Identifiable {
    let id: String
    let name: String
    let accessPassword: String
    let shiftDuration: Int // Horas
    let shiftTimes: [String: String] // Ej: ["morning_start": "08:00"]
    var staffRequirements: [String: Int]?
}

// MARK: - Modelos de Chat
struct ChatMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: TimeInterval
    
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
