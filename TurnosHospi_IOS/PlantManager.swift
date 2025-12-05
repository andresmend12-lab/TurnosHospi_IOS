import Foundation
import FirebaseDatabase
import FirebaseAuth

class PlantManager: ObservableObject {
    private let ref = Database.database().reference()
    
    @Published var foundPlant: HospitalPlant?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var joinSuccess: Bool = false
    
    @Published var currentPlant: HospitalPlant?
    @Published var myPlantName: String? = nil
    
    // Datos para la vista
    @Published var dailyAssignments: [String: [PlantShiftWorker]] = [:]
    
    // Diccionario con TODOS los turnos cargados (Fecha -> Trabajadores)
    @Published var monthlyAssignments: [Date: [PlantShiftWorker]] = [:]
    
    // MARK: - Buscar Planta
    func searchPlant(plantId: String, password: String) {
        self.isLoading = true
        self.errorMessage = nil
        self.foundPlant = nil
        
        ref.child("plants").child(plantId).observeSingleEvent(of: .value) { snapshot in
            self.isLoading = false
            
            guard let value = snapshot.value as? [String: Any] else {
                self.errorMessage = "No se encontró ninguna planta con ese ID."
                return
            }
            
            guard let realPassword = value["accessPassword"] as? String,
                  realPassword == password else {
                self.errorMessage = "La contraseña es incorrecta."
                return
            }
            
            var staffMembers: [PlantStaff] = []
            if let personalDict = value["personal_de_planta"] as? [String: [String: Any]] {
                for (key, data) in personalDict {
                    let staff = PlantStaff(
                        id: data["id"] as? String ?? key,
                        name: data["name"] as? String ?? "Personal",
                        role: data["role"] as? String ?? "Personal",
                        email: data["email"] as? String ?? "",
                        profileType: data["profileType"] as? String ?? ""
                    )
                    staffMembers.append(staff)
                }
            }
            
            let plant = HospitalPlant(
                id: plantId,
                name: value["name"] as? String ?? "Planta",
                hospitalName: value["hospitalName"] as? String ?? "Hospital",
                accessPassword: realPassword,
                allStaffList: staffMembers
            )
            
            DispatchQueue.main.async {
                self.foundPlant = plant
            }
        }
    }
    
    // MARK: - Unirse a Planta
    func joinPlant(plant: HospitalPlant, selectedStaff: PlantStaff) {
        guard let user = Auth.auth().currentUser else { return }
        self.isLoading = true
        
        let userPlantData: [String: Any] = [
            "plantId": plant.id,
            "staffId": selectedStaff.id,
            "staffName": selectedStaff.name,
            "staffRole": selectedStaff.role
        ]
        
        ref.child("plants")
            .child(plant.id)
            .child("userPlants")
            .child(user.uid)
            .setValue(userPlantData) { error, _ in
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = "Error al unirse: \(error.localizedDescription)"
                } else {
                    let userUpdates: [String: Any] = [
                        "role": selectedStaff.role,
                        "plantId": plant.id
                    ]
                    self.ref.child("users")
                        .child(user.uid)
                        .updateChildValues(userUpdates) { err, _ in
                            self.isLoading = false
                            if err == nil { self.joinSuccess = true }
                        }
                }
            }
    }
    
    // MARK: - Obtener Planta Actual
    func fetchCurrentPlant(plantId: String) {
        ref.child("plants").child(plantId).observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            var staffMembers: [PlantStaff] = []
            if let personalDict = value["personal_de_planta"] as? [String: [String: Any]] {
                for (_, data) in personalDict {
                    let staff = PlantStaff(
                        id: data["id"] as? String ?? "",
                        name: data["name"] as? String ?? "Personal",
                        role: data["role"] as? String ?? "Personal",
                        email: data["email"] as? String ?? "",
                        profileType: data["profileType"] as? String ?? ""
                    )
                    staffMembers.append(staff)
                }
            }
            
            // Configuración
            let staffScope = value["staffScope"] as? String ?? "nurses_only"
            let shiftDuration = value["shiftDuration"] as? String
            let staffRequirements = value["staffRequirements"] as? [String: Int]
            let shiftTimes = value["shiftTimes"] as? [String: [String: String]]
            
            let plant = HospitalPlant(
                id: plantId,
                name: value["name"] as? String ?? "Planta",
                hospitalName: value["hospitalName"] as? String ?? "Hospital",
                accessPassword: "",
                allStaffList: staffMembers,
                staffScope: staffScope,
                shiftDuration: shiftDuration,
                staffRequirements: staffRequirements,
                shiftTimes: shiftTimes
            )
            
            // Identificar al usuario actual en la planta
            var identifiedName: String? = nil
            if let userPlants = value["userPlants"] as? [String: [String: Any]],
               let uid = Auth.auth().currentUser?.uid,
               let myData = userPlants[uid] {
                
                if let myStaffId = myData["staffId"] as? String,
                   let me = staffMembers.first(where: { $0.id == myStaffId }) {
                    identifiedName = me.name
                } else if let savedName = myData["staffName"] as? String {
                    identifiedName = savedName
                }
            }
            
            DispatchQueue.main.async {
                self.currentPlant = plant
                self.myPlantName = identifiedName
            }
        })
    }
    
    // MARK: - Parser Helper
    private func parseWorkersForShift(
        shiftName: String,
        shiftData: [String: Any]
    ) -> [PlantShiftWorker] {
        var workers: [PlantShiftWorker] = []
        let unassigned = "Sin asignar"
        
        func processArray(_ list: [[String: Any]], roleName: String) {
            for (index, slot) in list.enumerated() {
                let halfDay = slot["halfDay"] as? Bool ?? false
                let primary = (slot["primary"] as? String) ?? ""
                let secondary = (slot["secondary"] as? String) ?? ""
                
                if !primary.isEmpty && primary != unassigned {
                    workers.append(PlantShiftWorker(
                        id: "\(roleName)_\(shiftName)_\(index)_P",
                        name: primary,
                        role: halfDay ? "\(roleName) (media)" : roleName,
                        shiftName: shiftName
                    ))
                }
                if halfDay, !secondary.isEmpty, secondary != unassigned {
                    workers.append(PlantShiftWorker(
                        id: "\(roleName)_\(shiftName)_\(index)_S",
                        name: secondary,
                        role: "\(roleName) (media)",
                        shiftName: shiftName
                    ))
                }
            }
        }
        
        if let nurses = shiftData["nurses"] as? [[String: Any]] {
            processArray(nurses, roleName: "Enfermero")
        }
        if let auxs = shiftData["auxiliaries"] as? [[String: Any]] {
            processArray(auxs, roleName: "TCAE")
        }
        
        return workers
    }
    
    // MARK: - Fetch Diario
    func fetchDailyStaff(plantId: String, date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let nodeName = "turnos-\(dateString)"
        
        ref.child("plants").child(plantId).child("turnos").child(nodeName)
            .observe(.value) { snapshot in
                var newDailyAssignments: [String: [PlantShiftWorker]] = [:]
                
                if let shiftsDict = snapshot.value as? [String: Any] {
                    for (shiftName, value) in shiftsDict {
                        if let shiftData = value as? [String: Any] {
                            let workers = self.parseWorkersForShift(shiftName: shiftName, shiftData: shiftData)
                            if !workers.isEmpty {
                                newDailyAssignments[shiftName] = workers
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.dailyAssignments = newDailyAssignments
                }
            }
    }
    
    // MARK: - Fetch GLOBAL (Carga todos los turnos de la historia)
    // Nota: Mantenemos el parámetro 'month' por compatibilidad con las llamadas existentes,
    // pero lo ignoramos para cargar todo el calendario de golpe.
    func fetchMonthlyAssignments(plantId: String, month: Date) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Descargamos todo el nodo 'turnos'
        ref.child("plants").child(plantId).child("turnos")
            .observeSingleEvent(of: .value) { snapshot in
                
                var allAssignments: [Date: [PlantShiftWorker]] = [:]
                
                guard let allDatesDict = snapshot.value as? [String: Any] else {
                    DispatchQueue.main.async { self.monthlyAssignments = [:] }
                    return
                }
                
                for (nodeName, value) in allDatesDict {
                    // Procesamos cada fecha encontrada en la base de datos
                    guard nodeName.hasPrefix("turnos-") else { continue }
                    let dateString = String(nodeName.dropFirst("turnos-".count))
                    
                    guard let date = formatter.date(from: dateString) else { continue }
                    
                    // --- CORRECCIÓN: ELIMINADO EL FILTRO DE MES ---
                    // Antes había un guard aquí que filtraba por 'month'. Lo hemos quitado.
                    
                    guard let shiftsDict = value as? [String: Any] else { continue }
                    
                    var workersForDay: [PlantShiftWorker] = []
                    
                    for (shiftName, shiftValue) in shiftsDict {
                        if let shiftData = shiftValue as? [String: Any] {
                            workersForDay.append(contentsOf: self.parseWorkersForShift(
                                shiftName: shiftName,
                                shiftData: shiftData
                            ))
                        }
                    }
                    
                    if !workersForDay.isEmpty {
                        // Eliminar duplicados (misma persona en mismo turno)
                        var unique: [String: PlantShiftWorker] = [:]
                        for w in workersForDay {
                            let key = "\(w.name)_\(w.shiftName ?? "")"
                            unique[key] = w
                        }
                        
                        // Usamos startOfDay para que coincida con la clave del calendario
                        let startOfDay = calendar.startOfDay(for: date)
                        allAssignments[startOfDay] = Array(unique.values)
                    }
                }
                
                DispatchQueue.main.async {
                    self.monthlyAssignments = allAssignments
                }
            }
    }
}

// MARK: - Extensions
extension DateFormatter {
    func dateString(from date: Date) -> String {
        self.dateFormat = "yyyy-MM-dd"
        return self.string(from: date)
    }
}
