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
    
    // Almacena los trabajadores del día seleccionado (para visualización)
    @Published var dailyAssignments: [String: [PlantShiftWorker]] = [:]
    
    // Almacena los trabajadores del mes (para la vista de calendario)
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
            
            DispatchQueue.main.async {
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
                self.currentPlant = plant
            }
        })
    }
    
    // MARK: - Helper: parsear un turno (Mañana/Tarde/Noche...) al modelo PlantShiftWorker
    private func parseWorkersForShift(
        shiftName: String,
        shiftData: [String: Any]
    ) -> [PlantShiftWorker] {
        var workers: [PlantShiftWorker] = []
        let unassigned = "Sin asignar"
        
        // NURSES
        if let nursesArray = shiftData["nurses"] as? [[String: Any]] {
            for (index, slot) in nursesArray.enumerated() {
                let halfDay = slot["halfDay"] as? Bool ?? false
                let primary = (slot["primary"] as? String) ?? ""
                let secondary = (slot["secondary"] as? String) ?? ""
                
                if !primary.isEmpty && primary != unassigned {
                    workers.append(
                        PlantShiftWorker(
                            id: "nurse_\(shiftName)_\(index)_P",
                            name: primary,
                            role: halfDay ? "Enfermero (media jornada)" : "Enfermero"
                        )
                    )
                }
                
                if halfDay,
                   !secondary.isEmpty,
                   secondary != unassigned {
                    workers.append(
                        PlantShiftWorker(
                            id: "nurse_\(shiftName)_\(index)_S",
                            name: secondary,
                            role: "Enfermero (media jornada)"
                        )
                    )
                }
            }
        }
        
        // AUXILIARIES / TCAE
        if let auxArray = shiftData["auxiliaries"] as? [[String: Any]] {
            for (index, slot) in auxArray.enumerated() {
                let halfDay = slot["halfDay"] as? Bool ?? false
                let primary = (slot["primary"] as? String) ?? ""
                let secondary = (slot["secondary"] as? String) ?? ""
                
                if !primary.isEmpty && primary != unassigned {
                    workers.append(
                        PlantShiftWorker(
                            id: "aux_\(shiftName)_\(index)_P",
                            name: primary,
                            role: halfDay ? "TCAE (media jornada)" : "TCAE"
                        )
                    )
                }
                
                if halfDay,
                   !secondary.isEmpty,
                   secondary != unassigned {
                    workers.append(
                        PlantShiftWorker(
                            id: "aux_\(shiftName)_\(index)_S",
                            name: secondary,
                            role: "TCAE (media jornada)"
                        )
                    )
                }
            }
        }
        
        return workers
    }
    
    // MARK: - Obtener personal del día (assignments) – LECTURA FORMATO ANDROID
    func fetchDailyStaff(plantId: String, date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let nodeName = "turnos-\(dateString)"
        
        ref.child("plants")
            .child(plantId)
            .child("turnos")
            .child(nodeName)
            .observe(.value, with: { snapshot in
                
                var newDailyAssignments: [String: [PlantShiftWorker]] = [:]
                
                guard let shiftsDict = snapshot.value as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.dailyAssignments = [:]
                    }
                    return
                }
                
                for (shiftName, value) in shiftsDict {
                    guard let shiftData = value as? [String: Any] else { continue }
                    
                    let workers = self.parseWorkersForShift(
                        shiftName: shiftName,
                        shiftData: shiftData
                    )
                    
                    if !workers.isEmpty {
                        newDailyAssignments[shiftName] = workers
                    }
                }
                
                DispatchQueue.main.async {
                    self.dailyAssignments = newDailyAssignments
                }
            })
    }
    
    // MARK: - Obtener asignaciones del mes (para el calendario) – LECTURA FORMATO ANDROID
    func fetchMonthlyAssignments(plantId: String, month: Date) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Observamos todos los turnos y filtramos por mes en cliente
        ref.child("plants")
            .child(plantId)
            .child("turnos")
            .observeSingleEvent(of: .value, with: { snapshot in
                
                var newMonthlyAssignments: [Date: [PlantShiftWorker]] = [:]
                
                guard let allDatesDict = snapshot.value as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.monthlyAssignments = [:]
                    }
                    return
                }
                
                for (nodeName, value) in allDatesDict {
                    // nodeName = "turnos-2025-11-30"
                    guard nodeName.hasPrefix("turnos-") else { continue }
                    let dateString = String(nodeName.dropFirst("turnos-".count))
                    
                    guard let date = formatter.date(from: dateString) else { continue }
                    
                    // Solo fechas del mismo mes y año que `month`
                    guard calendar.isDate(date, equalTo: month, toGranularity: .month) else {
                        continue
                    }
                    
                    guard let shiftsDict = value as? [String: Any] else { continue }
                    
                    var workersForDay: [PlantShiftWorker] = []
                    
                    for (shiftName, shiftValue) in shiftsDict {
                        guard let shiftData = shiftValue as? [String: Any] else { continue }
                        let shiftWorkers = self.parseWorkersForShift(
                            shiftName: shiftName,
                            shiftData: shiftData
                        )
                        workersForDay.append(contentsOf: shiftWorkers)
                    }
                    
                    if !workersForDay.isEmpty {
                        // Eliminar duplicados por (name + role)
                        var unique: [String: PlantShiftWorker] = [:]
                        for w in workersForDay {
                            let key = "\(w.name)_\(w.role)"
                            unique[key] = w
                        }
                        let startOfDay = calendar.startOfDay(for: date)
                        newMonthlyAssignments[startOfDay] = Array(unique.values)
                    }
                }
                
                DispatchQueue.main.async {
                    self.monthlyAssignments = newMonthlyAssignments
                }
            })
    }
}

// MARK: - Extensión para formato de fecha (ya la tenías, la mantengo por compatibilidad)
extension DateFormatter {
    func dateString(from date: Date) -> String {
        self.dateFormat = "yyyy-MM-dd"
        return self.string(from: date)
    }
}
