import Foundation

class ShiftRulesEngine {
    
    enum ShiftType { case morning, afternoon, night, off }
    
    // Formateador estático para consistencia
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    // --- REGLA 0: Cálculo de Dureza ---
    static func calculateShiftHardness(date: Date, shiftName: String) -> ShiftHardness {
        let name = shiftName.trimmingCharacters(in: .whitespaces).lowercased()
        if name.contains("noche") { return .night }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return .weekend } // 1=Domingo, 7=Sábado
        
        return .normal
    }
    
    private static func getShiftType(_ shiftName: String) -> ShiftType {
        let name = shiftName.lowercased()
        if name.contains("noche") { return .night }
        if name.contains("mañana") { return .morning }
        if name.contains("tarde") { return .afternoon }
        return .off
    }
    
    // --- REGLA 1: Roles ---
    static func areRolesCompatible(roleA: String, roleB: String) -> Bool {
        let rA = roleA.trimmingCharacters(in: .whitespaces).lowercased()
        let rB = roleB.trimmingCharacters(in: .whitespaces).lowercased()
        return (rA.contains("enfermer") && rB.contains("enfermer")) ||
               (rA.contains("auxiliar") && rB.contains("auxiliar"))
    }
    
    // --- REGLA 2: Validación Laboral ---
    // Devuelve nil si es válido, o String con el error
    static func validateWorkRules(targetDate: Date, targetShiftName: String, userSchedule: [String: String]) -> String? {
        let targetString = dateFormatter.string(from: targetDate)
        let targetType = getShiftType(targetShiftName)
        
        // 1. Ya tiene turno
        if userSchedule[targetString] != nil {
            return "Ya tienes un turno asignado el \(targetString)."
        }
        
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDate),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return nil }
        
        let yesterdayStr = dateFormatter.string(from: yesterday)
        let tomorrowStr = dateFormatter.string(from: tomorrow)
        
        let shiftYesterday = userSchedule[yesterdayStr].map { getShiftType($0) } ?? .off
        let shiftTomorrow = userSchedule[tomorrowStr].map { getShiftType($0) } ?? .off
        
        // Regla Saliente
        if shiftYesterday == .night {
            return "Vienes de una noche (Saliente). Debes descansar."
        }
        if targetType == .night && shiftTomorrow != .off {
            return "Si trabajas noche, mañana debes librar."
        }
        
        // Regla 6 días
        var simulatedSchedule = userSchedule
        simulatedSchedule[targetString] = targetShiftName
        if calculateConsecutiveDays(pivotDate: targetDate, schedule: simulatedSchedule) > 6 {
            return "Superarías el límite de 6 días seguidos."
        }
        
        return nil
    }
    
    private static func calculateConsecutiveDays(pivotDate: Date, schedule: [String: String]) -> Int {
        var count = 1
        let calendar = Calendar.current
        
        // Hacia atrás
        var current = calendar.date(byAdding: .day, value: -1, to: pivotDate)!
        while schedule[dateFormatter.string(from: current)] != nil {
            count += 1
            current = calendar.date(byAdding: .day, value: -1, to: current)!
        }
        
        // Hacia adelante
        current = calendar.date(byAdding: .day, value: 1, to: pivotDate)!
        while schedule[dateFormatter.string(from: current)] != nil {
            count += 1
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return count
    }
}
