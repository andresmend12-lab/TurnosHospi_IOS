import Foundation

class ShiftRulesEngine {
    
    // Singleton para acceso global sencillo
    static let shared = ShiftRulesEngine()
    
    private let calendar = Calendar.current
    
    // Formateador para manejar las fechas string (YYYY-MM-DD)
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "es_ES")
        return df
    }()
    
    private init() {}
    
    // MARK: - Detección de Tipos
    
    /// Detecta el tipo de turno basándose en el nombre (String).
    /// Es case-insensitive y busca palabras clave.
    func detectShiftType(from name: String) -> ShiftType {
        let lowerName = name.lowercased()
        if lowerName.contains("noche") { return .night }
        if lowerName.contains("mañana") { return .morning }
        if lowerName.contains("tarde") { return .afternoon }
        return .unknown
    }
    
    // MARK: - Reglas de Validación
    
    /// Regla del Saliente:
    /// Valida si se puede trabajar HOY basándose en el turno de AYER.
    /// Si ayer fue NOCHE, hoy es Saliente (no se trabaja).
    func isSalienteValidation(yesterdayShift: UserShift?) -> Bool {
        guard let yesterday = yesterdayShift else { return true }
        
        // Si ayer fue noche, hoy no es válido trabajar
        if detectShiftType(from: yesterday.shiftName) == .night {
            return false
        }
        
        return true
    }
    
    /// Regla de Racha:
    /// Un usuario no puede trabajar más de 6 días consecutivos.
    /// Recibe una lista de turnos ordenados por fecha.
    func validateStreak(consecutiveShifts: [UserShift]) -> Bool {
        return consecutiveShifts.count < 6
    }
    
    /// Regla de Compatibilidad de Roles:
    /// - Supervisor no participa en cambios.
    /// - Solo se pueden cambiar turnos entre el mismo rol.
    func areRolesCompatible(role1: UserRole, role2: UserRole) -> Bool {
        if role1 == .supervisor || role2 == .supervisor {
            return false
        }
        return role1 == role2
    }
    
    // MARK: - Validaciones Complejas (Coberturas)
    
    /// Comprueba si un usuario candidato puede cubrir un turno específico.
    /// - Parameters:
    ///   - candidate: Usuario que se ofrece a cubrir.
    ///   - targetDateString: Fecha del turno a cubrir (YYYY-MM-DD).
    ///   - targetShiftName: Nombre del turno a cubrir (ej: "Noche").
    ///   - candidateShifts: Historial de turnos del candidato (para chequear salientes y duplicados).
    /// - Returns: True si es legal hacer el cambio.
    func canUserCoverShift(candidate: UserProfile,
                           targetDateString: String,
                           targetShiftName: String,
                           candidateShifts: [UserShift]) -> Bool {
        
        guard let dateTarget = dateFormatter.date(from: targetDateString) else { return false }
        
        // 1. Verificar Rol
        // Nota: Esta validación suele hacerse antes, pero la reforzamos aquí si tenemos el rol del turno destino.
        // Asumimos que el turno destino requiere el mismo rol que el candidato por ahora.
        if candidate.role == .supervisor { return false }

        // 2. ¿El usuario ya trabaja ese día?
        if candidateShifts.contains(where: { $0.date == targetDateString }) {
            return false // Ya tiene turno, no puede doblar (regla simplificada)
        }
        
        // 3. Verificar Saliente (El día anterior no pudo ser Noche)
        if let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: dateTarget) {
            let yesterdayString = dateFormatter.string(from: yesterdayDate)
            if let prevShift = candidateShifts.first(where: { $0.date == yesterdayString }) {
                if detectShiftType(from: prevShift.shiftName) == .night {
                    return false // El candidato está de saliente ese día
                }
            }
        }
        
        // 4. Verificar Futuro Inmediato (Si cubro una Noche hoy, mañana no puedo trabajar)
        // Esta regla es compleja porque implica revisar si el candidato tiene turno MAÑANA.
        // Si el turno a cubrir es NOCHE:
        if detectShiftType(from: targetShiftName) == .night {
            if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: dateTarget) {
                let tomorrowString = dateFormatter.string(from: tomorrowDate)
                if candidateShifts.contains(where: { $0.date == tomorrowString }) {
                    return false // No puede coger una noche si trabaja a la mañana siguiente
                }
            }
        }
        
        return true
    }
    
    // MARK: - Helpers
    
    /// Convierte String a Date
    func date(from string: String) -> Date? {
        return dateFormatter.date(from: string)
    }
    
    /// Convierte Date a String
    func string(from date: Date) -> String {
        return dateFormatter.string(from: date)
    }
}
