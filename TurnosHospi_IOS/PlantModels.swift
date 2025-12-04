import Foundation

// Representa a un trabajador dentro de la lista 'personal_de_planta'
struct PlantStaff: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let email: String
    let profileType: String
}

// Representa la planta básica para la búsqueda
struct HospitalPlant {
    let id: String
    let name: String
    let hospitalName: String
    let accessPassword: String
    let allStaffList: [PlantStaff] // <--- MODIFICADO: Lista completa de personal
    let staffScope: String
    
    // NUEVOS CAMPOS DE CONFIGURACIÓN
    let shiftDuration: String?
    let staffRequirements: [String: Int]?
    let shiftTimes: [String: [String: String]]?
}

// --- NUEVO: Representa a un trabajador en un turno específico ---
struct PlantShiftWorker: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
}
