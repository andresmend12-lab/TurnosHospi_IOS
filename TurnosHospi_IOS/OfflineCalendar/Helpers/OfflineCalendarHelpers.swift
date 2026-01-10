import SwiftUI

// MARK: - Funciones Auxiliares para Calendario Offline

/// Normaliza el nombre de un turno a su forma canónica
func normalizeShiftType(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    switch lower {
    case "mañana", "manana", "morning", "am":
        return "Mañana"
    case "tarde", "afternoon", "pm":
        return "Tarde"
    case "noche", "night", "night shift":
        return "Noche"
    case "saliente", "post-night", "post night", "postnight":
        return "Saliente"
    case "día", "dia", "day":
        return "Día"
    case "media mañana", "media manana", "half morning", "m. mañana", "m. manana":
        return "Media Mañana"
    case "media tarde", "half afternoon", "m. tarde":
        return "Media Tarde"
    case "medio día", "medio dia", "half day":
        return "Medio Día"
    case "vacaciones", "vacation", "holiday":
        return "Vacaciones"
    case "libre", "off", "free":
        return "Libre"
    default:
        return trimmed
    }
}

/// Obtiene el color correspondiente a un tipo de turno
/// Prioridad: 1) Turnos personalizados, 2) ThemeManager, 3) Colores por defecto
func getShiftColorForType(
    _ type: String,
    customShiftTypes: [CustomShiftType],
    themeManager: ThemeManager? = nil
) -> Color {
    // 1. Primero buscar en turnos personalizados
    if let custom = customShiftTypes.first(where: { $0.name.lowercased() == type.lowercased() }) {
        return custom.color
    }

    let normalized = normalizeShiftType(type).lowercased()

    // 2. Si hay ThemeManager, usar sus colores
    if let theme = themeManager {
        switch normalized {
        case "mañana", "día":
            return theme.morningColor
        case "media mañana", "m. mañana", "medio día":
            return theme.morningHalfColor
        case "tarde":
            return theme.afternoonColor
        case "media tarde", "m. tarde":
            return theme.afternoonHalfColor
        case "noche":
            return theme.nightColor
        case "saliente":
            return theme.salienteColor
        case "libre":
            return theme.freeDayColor
        case "vacaciones":
            return theme.holidayColor
        default:
            break
        }
    }

    // 3. Colores por defecto (fallback)
    switch normalized {
    case "vacaciones":
        return DesignColors.shiftVacation
    case "saliente":
        return DesignColors.shiftSaliente
    case "noche":
        return DesignColors.shiftNight
    case "media tarde", "m. tarde":
        return DesignColors.shiftHalfAfternoon
    case "media mañana", "m. mañana", "medio día":
        return DesignColors.shiftHalfMorning
    case "tarde":
        return DesignColors.shiftAfternoon
    case "mañana", "día":
        return DesignColors.shiftMorning
    case "libre":
        return DesignColors.shiftFree
    default:
        return DesignColors.shiftFree
    }
}

/// Retorna las duraciones por defecto según el patrón
func defaultShiftDurations(pattern: ShiftPattern) -> [String: Double] {
    switch pattern {
    case .three:
        return [
            "Mañana": 8.0,
            "Tarde": 8.0,
            "Noche": 8.0,
            "Saliente": 0.0
        ]
    case .two:
        return [
            "Día": 12.0,
            "Noche": 12.0,
            "Saliente": 0.0
        ]
    case .custom:
        return ["Saliente": 0.0]
    }
}

/// Combina duraciones actuales con los valores por defecto
func withDefaultShiftDurations(_ current: [String: Double], pattern: ShiftPattern) -> [String: Double] {
    let defaults = defaultShiftDurations(pattern: pattern)
    var updated = current
    for (key, value) in defaults {
        if updated[key] == nil {
            updated[key] = value
        }
    }
    return updated
}

/// Calcula estadísticas para un mes específico
func calculateOfflineStatsForMonth(
    month: Date,
    shifts: [String: UserShift],
    customShiftTypes: [CustomShiftType],
    shiftDurations: [String: Double]
) -> OfflineMonthlyStats {
    var totalHours = 0.0
    var totalShifts = 0
    var breakdown: [String: ShiftStatData] = [:]

    let calendar = Calendar.current
    let targetMonth = calendar.component(.month, from: month)
    let targetYear = calendar.component(.year, from: month)

    for (dateKey, shift) in shifts {
        guard let date = dateFromString(dateKey) else { continue }
        let shiftMonth = calendar.component(.month, from: date)
        let shiftYear = calendar.component(.year, from: date)

        if shiftMonth != targetMonth || shiftYear != targetYear {
            continue
        }

        let hours = getShiftDurationHours(
            shift: shift,
            shiftDurations: shiftDurations,
            customShiftTypes: customShiftTypes
        )

        if hours <= 0.0 {
            continue
        }

        totalHours += hours
        totalShifts += 1

        let key = normalizeShiftType(shift.shiftName)
        if breakdown[key] == nil {
            breakdown[key] = ShiftStatData()
        }
        breakdown[key]!.hours += hours
        breakdown[key]!.count += 1
    }

    return OfflineMonthlyStats(
        totalHours: totalHours,
        totalShifts: totalShifts,
        breakdown: breakdown
    )
}

/// Obtiene la duración en horas de un turno
func getShiftDurationHours(
    shift: UserShift,
    shiftDurations: [String: Double],
    customShiftTypes: [CustomShiftType]
) -> Double {
    // Buscar en turnos personalizados
    if let custom = customShiftTypes.first(where: { $0.name.lowercased() == shift.shiftName.lowercased() }) {
        return shift.isHalfDay ? custom.durationHours / 2.0 : custom.durationHours
    }

    let baseName = baseShiftNameForDuration(shift.shiftName)
    let baseDuration = shiftDurations[baseName] ?? 0.0

    return shift.isHalfDay ? baseDuration / 2.0 : baseDuration
}

/// Obtiene el nombre base de un turno para buscar su duración
func baseShiftNameForDuration(_ shiftName: String) -> String {
    let normalized = normalizeShiftType(shiftName)
    switch normalized {
    case "Media Mañana":
        return "Mañana"
    case "Media Tarde":
        return "Tarde"
    case "Medio Día":
        return "Día"
    default:
        return normalized
    }
}

/// Convierte un string de fecha a Date
func dateFromString(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
}

/// Formatea una fecha para mostrar
func formatDisplayDate(_ date: Date, format: String = "d 'de' MMMM") -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = format
    return formatter.string(from: date).capitalized
}

/// Obtiene el título del mes
func monthTitle(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
}
