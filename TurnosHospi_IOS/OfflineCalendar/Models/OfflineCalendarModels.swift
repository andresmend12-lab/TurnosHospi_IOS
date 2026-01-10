import SwiftUI

// MARK: - Modelos de Datos para Calendario Offline

/// Representa un turno asignado a un día específico
struct UserShift: Codable, Equatable {
    let shiftName: String
    let isHalfDay: Bool
}

/// Patrones de turno disponibles
enum ShiftPattern: String, Codable, CaseIterable, Identifiable {
    case three = "THREE_SHIFTS"    // Mañana, Tarde, Noche
    case two = "TWO_SHIFTS"        // Día (12h), Noche (12h)
    case custom = "CUSTOM_SHIFTS"  // Turnos personalizados

    var id: String { rawValue }

    var title: String {
        switch self {
        case .three: return "3 Turnos (M/T/N)"
        case .two: return "2 Turnos (Día 12h / Noche 12h)"
        case .custom: return "Turnos personalizados"
        }
    }
}

/// Tipo de turno personalizado creado por el usuario
struct CustomShiftType: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let durationHours: Double

    init(id: UUID = UUID(), name: String, colorHex: String, durationHours: Double = 8.0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.durationHours = durationHours
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

/// Configuración de turnos para persistencia
struct OfflineShiftSettings: Codable {
    var pattern: ShiftPattern
    var allowHalfDay: Bool
}

/// Estadísticas mensuales calculadas
struct OfflineMonthlyStats {
    var totalHours: Double
    var totalShifts: Int
    var breakdown: [String: ShiftStatData]
}

/// Datos de estadísticas por tipo de turno
struct ShiftStatData {
    var hours: Double = 0.0
    var count: Int = 0
}
