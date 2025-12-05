import Foundation

// Representa a un trabajador dentro de la lista 'personal_de-planta'
struct PlantStaff: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let email: String
    let profileType: String
}

// Representa la planta básica
struct HospitalPlant {
    let id: String
    let name: String
    let hospitalName: String
    let accessPassword: String
    let allStaffList: [PlantStaff]
    
    // Campos de configuración
    let staffScope: String?
    let shiftDuration: String?
    let staffRequirements: [String: Int]?
    let shiftTimes: [String: [String: String]]?
    
    // Inicializador simplificado (JoinPlantView)
    init(id: String, name: String, hospitalName: String, accessPassword: String, allStaffList: [PlantStaff]) {
        self.id = id
        self.name = name
        self.hospitalName = hospitalName
        self.accessPassword = accessPassword
        self.allStaffList = allStaffList
        self.staffScope = nil
        self.shiftDuration = nil
        self.staffRequirements = nil
        self.shiftTimes = nil
    }
    
    // Inicializador completo (Fetch)
    init(id: String, name: String, hospitalName: String, accessPassword: String, allStaffList: [PlantStaff], staffScope: String?, shiftDuration: String?, staffRequirements: [String: Int]?, shiftTimes: [String: [String: String]]?) {
        self.id = id
        self.name = name
        self.hospitalName = hospitalName
        self.accessPassword = accessPassword
        self.allStaffList = allStaffList
        self.staffScope = staffScope
        self.shiftDuration = shiftDuration
        self.staffRequirements = staffRequirements
        self.shiftTimes = shiftTimes
    }
}

// Representa a un trabajador en un turno específico (Calendario)
struct PlantShiftWorker: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    var shiftName: String? = nil // <--- IMPORTANTE: Para saber el color del turno
    
    var initial: String {
        return String(name.prefix(1))
    }
}
