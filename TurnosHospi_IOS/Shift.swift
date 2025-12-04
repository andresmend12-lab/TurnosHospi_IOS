import SwiftUI

// Tipos de turno disponibles
enum ShiftType: String, Codable {
    case manana = "Mañana"
    case mediaManana = "Media mañana"
    case tarde = "Tarde"
    case mediaTarde = "Media tarde"
    case noche = "Noche"
    
    // Color característico para cada turno (Tema Espacial)
    var color: Color {
        switch self {
        case .manana: return Color.yellow // Sol
        case .mediaManana: return Color(red: 1.0, green: 0.9, blue: 0.6) // Luz suave
        case .tarde: return Color.orange // Atardecer
        case .mediaTarde: return Color(red: 1.0, green: 0.6, blue: 0.4) // Atardecer suave
        case .noche: return Color(red: 0.3, green: 0.3, blue: 1.0) // Azul noche profundo
        }
    }
}

struct Shift: Identifiable, Codable {
    let id: String
    let timestamp: TimeInterval // Fecha del turno en formato Unix
    let type: ShiftType
    
    // Helper para obtener la fecha como objeto Date
    var date: Date {
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
    
    // Helper para saber qué día del mes es (ej: 5, 20, 31)
    var dayNumber: Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: date)
    }
    
    // Helper para saber el mes y año
    var monthYear: DateComponents {
        return Calendar.current.dateComponents([.month, .year], from: date)
    }
}
