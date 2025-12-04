import SwiftUI

enum ShiftType: String, Codable {
    case manana = "Mañana"
    case mediaManana = "Media mañana"
    case tarde = "Tarde"
    case mediaTarde = "Media tarde"
    case noche = "Noche"
    
    var color: Color {
        switch self {
        case .manana: return Color.yellow // Sol brillante
        case .mediaManana: return Color(red: 1.0, green: 0.9, blue: 0.6) // Luz suave
        case .tarde: return Color.orange // Atardecer
        case .mediaTarde: return Color(red: 1.0, green: 0.6, blue: 0.4) // Naranja suave
        case .noche: return Color(red: 0.3, green: 0.3, blue: 1.0) // Azul profundo
        }
    }
}

struct Shift: Identifiable, Codable {
    let id: String
    let timestamp: TimeInterval // Fecha en formato Unix (milisegundos)
    let type: ShiftType
    
    var date: Date {
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
}
