import Foundation

// --- Enum de Dureza y Tipos ---
enum Hardness: String, Codable {
    case night = "NIGHT"
    case weekend = "WEEKEND"
    case holiday = "HOLIDAY"
    case normal = "NORMAL"
}

enum ShiftType {
    case morning, afternoon, night, off
}

// --- Clase Singleton para el Engine ---
class ShiftRulesEngine {
    
    static let shared = ShiftRulesEngine()
    private init() {} // Constructor privado para Singleton
    
    // --- Modelos Auxiliares ---
    struct DebtEntry {
        let debtorId: String
        let creditorId: String
        let hardness: Hardness
        let amount: Int
    }
    
    // --- REGLA 0: Cálculo de Dureza ---
    func calculateShiftHardness(date: Date, shiftName: String) -> Hardness {
        let name = shiftName.trimmingCharacters(in: .whitespaces).lowercased()
        if name.contains("noche") { return .night }
        
        // Calendario Gregoriano
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // En Calendar.current: Domingo = 1, Sábado = 7
        if weekday == 1 || weekday == 7 { return .weekend }
        
        // TODO: Inyectar lógica de festivos aquí si es necesario
        // if isHoliday(date) { return .holiday }
        
        return .normal
    }
    
    private func getShiftType(_ shiftName: String) -> ShiftType {
        let name = shiftName.lowercased()
        if name.contains("noche") { return .night }
        if name.contains("mañana") { return .morning }
        if name.contains("tarde") { return .afternoon }
        return .off
    }
    
    // --- REGLA 1: Roles ---
    func canUserParticipate(userRole: String) -> Bool {
        let normalized = userRole.trimmingCharacters(in: .whitespaces).lowercased()
        return !normalized.contains("supervisor") &&
               (normalized.contains("enfermer") || normalized.contains("auxiliar"))
    }
    
    func areRolesCompatible(roleA: String, roleB: String) -> Bool {
        let rA = roleA.trimmingCharacters(in: .whitespaces).lowercased()
        let rB = roleB.trimmingCharacters(in: .whitespaces).lowercased()
        
        return (rA.contains("enfermer") && rB.contains("enfermer")) ||
               (rA.contains("auxiliar") && rB.contains("auxiliar"))
    }
    
    // --- REGLA 2: Validación Laboral ---
    // Devuelve nil si es válido, o un String con el error
    // userSchedule debe ser un diccionario [Date: String] normalizado (sin hora)
    func validateWorkRules(targetDate: Date, targetShiftName: String, userSchedule: [Date: String]) -> String? {
        let targetType = getShiftType(targetShiftName)
        
        // Normalizamos la fecha target (inicio del día) para buscar en el diccionario
        let calendar = Calendar.current
        let targetStartOfDay = calendar.startOfDay(for: targetDate)
        
        // 1. Ya tiene turno ese día
        if userSchedule[targetStartOfDay] != nil {
            return "Ya tienes un turno asignado el \(formatDate(targetDate))."
        }
        
        // 2. Regla de Saliente (Noches)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: targetStartOfDay),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetStartOfDay) else {
            return "Error calculando fechas."
        }
        
        let shiftYesterdayName = userSchedule[yesterday] ?? ""
        let shiftTomorrowName = userSchedule[tomorrow] ?? ""
        
        let shiftYesterday = getShiftType(shiftYesterdayName)
        let shiftTomorrow = getShiftType(shiftTomorrowName) // Si no existe es OFF
        
        // Ayer fue noche -> Hoy es SALIENTE
        if shiftYesterday == .night {
            return "Vienes de una noche (Saliente). Debes descansar."
        }
        
        // Hoy es noche -> Mañana es SALIENTE
        if targetType == .night && shiftTomorrow != .off {
            return "Si trabajas noche, mañana debes librar."
        }
        
        // 3. Regla de los 6 días
        var simulatedSchedule = userSchedule
        simulatedSchedule[targetStartOfDay] = targetShiftName
        
        if calculateConsecutiveDays(pivotDate: targetStartOfDay, schedule: simulatedSchedule) > 6 {
            return "Superarías el límite de 6 días seguidos de trabajo."
        }
        
        return nil
    }
    
    private func calculateConsecutiveDays(pivotDate: Date, schedule: [Date: String]) -> Int {
        var count = 1
        let calendar = Calendar.current
        
        // Hacia atrás
        var current = calendar.date(byAdding: .day, value: -1, to: pivotDate)!
        while schedule[current] != nil {
            count += 1
            current = calendar.date(byAdding: .day, value: -1, to: current)!
        }
        
        // Hacia adelante
        current = calendar.date(byAdding: .day, value: 1, to: pivotDate)!
        while schedule[current] != nil {
            count += 1
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return count
    }
    
    // --- REGLA 3: Matching ---
    func checkMatch(
        requesterRequest: ShiftChangeRequest,
        candidateRequest: ShiftChangeRequest,
        requesterSchedule: [Date: String],
        candidateSchedule: [Date: String]
    ) -> Bool {
        // A. Filtro de Rol
        if !areRolesCompatible(roleA: requesterRequest.requesterRole, roleB: candidateRequest.requesterRole) {
            return false
        }
        
        // B. Verificación de Intención
        let requesterWantsB = requesterRequest.offeredDates.isEmpty ||
                              requesterRequest.offeredDates.contains(candidateRequest.requesterShiftDate)
        
        let candidateWantsA = candidateRequest.offeredDates.isEmpty ||
                              candidateRequest.offeredDates.contains(requesterRequest.requesterShiftDate)
        
        if !requesterWantsB || !candidateWantsA { return false }
        
        // C. Validación Laboral Cruzada
        // Parsear fechas de String (ISO) a Date
        guard let dateA = parseDate(requesterRequest.requesterShiftDate),
              let dateB = parseDate(candidateRequest.requesterShiftDate) else {
            return false
        }
        
        // Validar Requester trabajando en FechaB
        let errorForRequester = validateWorkRules(targetDate: dateB, targetShiftName: candidateRequest.requesterShiftName, userSchedule: requesterSchedule)
        
        // Validar Candidate trabajando en FechaA
        let errorForCandidate = validateWorkRules(targetDate: dateA, targetShiftName: requesterRequest.requesterShiftName, userSchedule: candidateSchedule)
        
        return errorForRequester == nil && errorForCandidate == nil
    }
    
    // --- Helpers de Fecha ---
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
