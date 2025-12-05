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
    
    /// Clave: nombre de turno ("Mañana", "Tarde", "Noche"...)
    @Published var dailyAssignments: [String: [PlantShiftWorker]] = [:]
    
    /// Clave: fecha (startOfDay). Valor: todos los trabajadores que tienen algún turno ese día
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
                            if err == nil {
                                self.joinSuccess = true
                            }
                        }
                }
            }
    }
    
    // MARK: - Obtener Planta Actual
    func fetchCurrentPlant(plantId: String) {
        ref.child("plants").child(plantId).observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            var staffMembers: [PlantStaff] = []
            // Cargar desde "personal_de_planta"
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
    
    // MARK: - Obtener personal del día (assignments)
    //
    // Estructura real en Firebase (igual que Android):
    //
    // plants / {plantId} / turnos / turnos-YYYY-MM-DD /
    //    Mañana /
    //       nurses:      [ { halfDay, primary, secondary, primaryLabel, secondaryLabel }, ... ]
    //       auxiliaries: [ { ... }, ... ]
    //
    // Esto se traduce a:
    //  dailyAssignments["Mañana"] = [PlantShiftWorker(...), ...]
    //
    func fetchDailyStaff(plantId: String, date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let nodeName = "turnos-\(dateString)"
        
        ref.child("plants")
            .child(plantId)
            .child("turnos")
            .child(nodeName)
            .observeSingleEvent(of: .value, with: { snapshot in
                
                var newDailyAssignments: [String: [PlantShiftWorker]] = [:]
                
                // snapshot.children = nodos de turno: "Mañana", "Tarde", "Noche", "Vacaciones", etc.
                for child in snapshot.children {
                    guard let shiftSnap = child as? DataSnapshot else { continue }
                    let shiftName = shiftSnap.key
                    
                    var workersForShift: [PlantShiftWorker] = []
                    
                    // Dentro de cada turno: "nurses", "auxiliaries", etc.
                    for groupChild in shiftSnap.children {
                        guard let groupSnap = groupChild as? DataSnapshot else { continue }
                        let groupKey = groupSnap.key   // "nurses" o "auxiliaries"
                        
                        let role: String
                        switch groupKey {
                        case "nurses":
                            role = "Enfermero"
                        case "auxiliaries":
                            role = "TCAE"
                        default:
                            role = "Personal"
                        }
                        
                        // Slots: "0", "1", "2", ...
                        for slotChild in groupSnap.children {
                            guard let slotSnap = slotChild as? DataSnapshot,
                                  let slotDict = slotSnap.value as? [String: Any] else { continue }
                            
                            let primary = slotDict["primary"] as? String ?? ""
                            let secondary = slotDict["secondary"] as? String ?? ""
                            
                            // En Android, el unassignedLabel viene de stringResource(R.string.staff_unassigned_option)
                            // En tu BD, por lo que has mostrado, el valor es "Sin asignar".
                            let unassigned = "Sin asignar"
                            
                            if !primary.isEmpty && primary != unassigned {
                                let workerId = "\(groupKey)_\(slotSnap.key ?? "0")_primary"
                                workersForShift.append(
                                    PlantShiftWorker(id: workerId, name: primary, role: role)
                                )
                            }
                            
                            if !secondary.isEmpty && secondary != unassigned {
                                let workerId = "\(groupKey)_\(slotSnap.key ?? "0")_secondary"
                                workersForShift.append(
                                    PlantShiftWorker(id: workerId, name: secondary, role: role)
                                )
                            }
                        }
                    }
                    
                    if !workersForShift.isEmpty {
                        newDailyAssignments[shiftName] = workersForShift
                    }
                }
                
                DispatchQueue.main.async {
                    self.dailyAssignments = newDailyAssignments
                }
            })
    }
    
    // MARK: - Obtener asignaciones del mes (para el calendario)
    //
    // Recorremos todos los "turnos-YYYY-MM-DD" bajo plants/{plantId}/turnos,
    // filtramos las fechas que caen en el mes solicitado
    // y agregamos todos los trabajadores de todos los turnos de ese día.
    //
    func fetchMonthlyAssignments(plantId: String, month: Date) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        ref.child("plants")
            .child(plantId)
            .child("turnos")
            .observeSingleEvent(of: .value, with: { snapshot in
                
                var newMonthlyAssignments: [Date: [PlantShiftWorker]] = [:]
                
                // snapshot.children = nodos "turnos-YYYY-MM-DD"
                for child in snapshot.children {
                    guard let daySnap = child as? DataSnapshot else { continue }
                    let nodeKey = daySnap.key  // "turnos-2025-11-30"
                    
                    guard nodeKey.hasPrefix("turnos-") else { continue }
                    let dateString = String(nodeKey.dropFirst("turnos-".count))
                    guard let date = formatter.date(from: dateString) else { continue }
                    
                    // Solo fechas del mes solicitado
                    if !calendar.isDate(date, equalTo: month, toGranularity: .month) {
                        continue
                    }
                    
                    var workersForDay: [PlantShiftWorker] = []
                    
                    // daySnap.children = turnos ("Mañana", "Tarde", "Noche", "Vacaciones"...)
                    for shiftChild in daySnap.children {
                        guard let shiftSnap = shiftChild as? DataSnapshot else { continue }
                        
                        for groupChild in shiftSnap.children {
                            guard let groupSnap = groupChild as? DataSnapshot else { continue }
                            let groupKey = groupSnap.key
                            
                            let role: String
                            switch groupKey {
                            case "nurses":
                                role = "Enfermero"
                            case "auxiliaries":
                                role = "TCAE"
                            default:
                                role = "Personal"
                            }
                            
                            for slotChild in groupSnap.children {
                                guard let slotSnap = slotChild as? DataSnapshot,
                                      let slotDict = slotSnap.value as? [String: Any] else { continue }
                                
                                let primary = slotDict["primary"] as? String ?? ""
                                let secondary = slotDict["secondary"] as? String ?? ""
                                let unassigned = "Sin asignar"
                                
                                if !primary.isEmpty && primary != unassigned {
                                    let workerId = "\(groupKey)_\(slotSnap.key ?? "0")_primary"
                                    workersForDay.append(
                                        PlantShiftWorker(id: workerId, name: primary, role: role)
                                    )
                                }
                                
                                if !secondary.isEmpty && secondary != unassigned {
                                    let workerId = "\(groupKey)_\(slotSnap.key ?? "0")_secondary"
                                    workersForDay.append(
                                        PlantShiftWorker(id: workerId, name: secondary, role: role)
                                    )
                                }
                            }
                        }
                    }
                    
                    if !workersForDay.isEmpty {
                        // Evitar duplicados por id (por si acaso)
                        var uniqueById: [String: PlantShiftWorker] = [:]
                        for worker in workersForDay {
                            uniqueById[worker.id] = worker
                        }
                        
                        let startOfDay = calendar.startOfDay(for: date)
                        newMonthlyAssignments[startOfDay] = Array(uniqueById.values)
                    }
                }
                
                DispatchQueue.main.async {
                    self.monthlyAssignments = newMonthlyAssignments
                }
            })
    }
}
