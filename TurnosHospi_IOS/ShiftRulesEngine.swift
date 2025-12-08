import Foundation

class ShiftRulesEngine {
    
    // --- Enum de Dureza y Tipos ---
    enum Hardness { case night, weekend, holiday, normal }
    enum ShiftType { case morning, afternoon, night, off }
    
    // Formateador para manejar las claves del diccionario (yyyy-MM-dd)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()
    
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }
    
    // --- REGLA 0: Cálculo de Dureza ---
    static func calculateShiftHardness(date: Date, shiftName: String) -> Hardness {
        let name = shiftName.trimmingCharacters(in: .whitespaces).lowercased()
        if name.contains("noche") { return .night }
        
        let weekday = calendar.component(.weekday, from: date)
        // Domingo=1, Sábado=7
        if weekday == 1 || weekday == 7 { return .weekend }
        
        // Aquí podrías inyectar lógica para festivos si tuvieras un calendario
        // if isHoliday(date) { return .holiday }
        
        return .normal
    }
    
    private static func getShiftType(_ shiftName: String) -> ShiftType {
        let name = shiftName.trimmingCharacters(in: .whitespaces).lowercased()
        if name.contains("noche") { return .night }
        if name.contains("mañana") || name.contains("dia") || name.contains("día") { return .morning }
        if name.contains("tarde") { return .afternoon }
        return .off
    }
    
    // --- REGLA 1: Roles ---
    static func canUserParticipate(userRole: String) -> Bool {
        let normalized = userRole.trimmingCharacters(in: .whitespaces).lowercased()
        // Los supervisores no participan en intercambios básicos, enfermeros y auxiliares sí
        return !normalized.contains("supervisor") &&
               (normalized.contains("enfermer") || normalized.contains("auxiliar") || normalized.contains("tcae"))
    }
    
    static func areRolesCompatible(roleA: String, roleB: String) -> Bool {
        let rA = roleA.trimmingCharacters(in: .whitespaces).lowercased()
        let rB = roleB.trimmingCharacters(in: .whitespaces).lowercased()
        
        let isNurseA = rA.contains("enfermer")
        let isNurseB = rB.contains("enfermer")
        
        let isAuxA = rA.contains("auxiliar") || rA.contains("tcae")
        let isAuxB = rB.contains("auxiliar") || rB.contains("tcae")
        
        return (isNurseA && isNurseB) || (isAuxA && isAuxB)
    }
    
    // --- REGLA 2: Validación Laboral (Salientes, Doble turno, Racha) ---
    // Devuelve nil si es válido, o un String con el error
    // userSchedule es un diccionario [FechaString : NombreTurno]
    static func validateWorkRules(targetDate: Date, targetShiftName: String, userSchedule: [String: String]) -> String? {
        let targetString = dateFormatter.string(from: targetDate)
        let targetType = getShiftType(targetShiftName)
        
        // 1. Ya tiene turno ese día
        if userSchedule[targetString] != nil {
            return "Ya tienes un turno asignado el \(targetString)."
        }
        
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDate),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return nil }
        
        let yesterdayStr = dateFormatter.string(from: yesterday)
        let tomorrowStr = dateFormatter.string(from: tomorrow)
        
        let shiftYesterday = userSchedule[yesterdayStr].map { getShiftType($0) } ?? .off
        let shiftTomorrow = userSchedule[tomorrowStr].map { getShiftType($0) } ?? .off
        
        // 2. Regla de Saliente (Noches)
        // Ayer fue noche -> Hoy es SALIENTE (Descanso obligatorio)
        if shiftYesterday == .night {
            return "Vienes de una noche (Saliente). Debes descansar."
        }
        
        // Hoy es noche -> Mañana es SALIENTE (No puedes trabajar mañana)
        if targetType == .night && shiftTomorrow != .off {
            return "Si trabajas noche, mañana debes librar."
        }
        
        // 3. Regla de los 6 días (Max 6 seguidos)
        var simulatedSchedule = userSchedule
        simulatedSchedule[targetString] = targetShiftName
        
        if calculateConsecutiveDays(pivotDate: targetDate, schedule: simulatedSchedule) > 6 {
            return "Superarías el límite de 6 días seguidos de trabajo."
        }
        
        return nil
    }
    
    private static func calculateConsecutiveDays(pivotDate: Date, schedule: [String: String]) -> Int {
        var count = 1 // El día pivote cuenta
        
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
    
    // --- REGLA 3: Matching (Algoritmo Principal) ---
    // Verifica si "Candidate" puede hacer swap con "Requester"
    // Requiere los objetos ShiftChangeRequest (definidos en ShiftChangeModels.swift)
    static func checkMatch(
        requesterRequest: ShiftChangeRequest, // La solicitud original (A quiere soltar X)
        candidateRequest: ShiftChangeRequest, // La solicitud del candidato (B quiere soltar Y) o un objeto simulado
        requesterSchedule: [String: String],
        candidateSchedule: [String: String]
    ) -> Bool {
        
        // A. Filtro de Rol
        if !areRolesCompatible(roleA: requesterRequest.requesterRole, roleB: candidateRequest.requesterRole) {
            return false
        }
        
        // B. Verificación de Intención (Wildcard / Comodín)
        // Si offeredDates está vacía, asumimos "FLEXIBLE" (acepta cualquier fecha)
        let requesterWantsB = requesterRequest.offeredDates.isEmpty ||
                              requesterRequest.offeredDates.contains(candidateRequest.requesterShiftDate)
        
        let candidateWantsA = candidateRequest.offeredDates.isEmpty ||
                              candidateRequest.offeredDates.contains(requesterRequest.requesterShiftDate)
        
        if !requesterWantsB || !candidateWantsA {
            return false
        }
        
        // C. Validación Laboral Cruzada (Swap Puro)
        guard let dateA = dateFormatter.date(from: requesterRequest.requesterShiftDate),
              let dateB = dateFormatter.date(from: candidateRequest.requesterShiftDate) else {
            return false
        }
        
        // 1. Validar si Requester puede trabajar en FechaB (turno de Candidate)
        // Nota: Al validar, usamos el horario del Requester SIN su turno original (ya que lo va a soltar),
        // pero la función validateWorkRules asume que schedule es el estado actual.
        // Para ser precisos, deberíamos quitar el turno "X" de requesterSchedule antes de validar "Y",
        // pero validateWorkRules ya chequea "Ya tiene turno" en la fecha objetivo.
        // Si la fecha objetivo es distinta a la fecha origen, está bien. Si es la misma fecha (cambio turno mañana por tarde),
        // validateWorkRules daría error.
        
        var tempRequesterSchedule = requesterSchedule
        tempRequesterSchedule.removeValue(forKey: requesterRequest.requesterShiftDate)
        
        var tempCandidateSchedule = candidateSchedule
        tempCandidateSchedule.removeValue(forKey: candidateRequest.requesterShiftDate)
        
        let errorForRequester = validateWorkRules(targetDate: dateB, targetShiftName: candidateRequest.requesterShiftName, userSchedule: tempRequesterSchedule)
        let errorForCandidate = validateWorkRules(targetDate: dateA, targetShiftName: requesterRequest.requesterShiftName, userSchedule: tempCandidateSchedule)
        
        return errorForRequester == nil && errorForCandidate == nil
    }
}
