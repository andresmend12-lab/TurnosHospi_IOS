import Foundation
import FirebaseDatabase
import FirebaseAuth

class PlantManager: ObservableObject {
    private let ref = Database.database().reference()
    
    private var dailyAssignmentsRef: DatabaseReference?
    private var dailyAssignmentsHandle: DatabaseHandle?
    private var monthlyAssignmentsRef: DatabaseReference?
    private var monthlyAssignmentsHandle: DatabaseHandle?
    
    @Published var foundPlant: HospitalPlant?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var joinSuccess: Bool = false
    
    @Published var currentPlant: HospitalPlant?
    @Published var myPlantName: String? = nil
    
    // NUEVO: Lista de usuarios registrados en la planta (con UID real) para el chat
    @Published var plantUsers: [ChatUser] = []
    
    // Datos para la vista
    @Published var dailyAssignments: [String: [PlantShiftWorker]] = [:]
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
            
            // --- NUEVO: Procesar usuarios registrados (userPlants) ---
            var loadedChatUsers: [ChatUser] = []
            var identifiedName: String? = nil
            let currentUid = Auth.auth().currentUser?.uid
            
            if let userPlants = value["userPlants"] as? [String: [String: Any]] {
                for (uid, userData) in userPlants {
                    // Identificarme a mí mismo para el nombre en la app
                    if uid == currentUid {
                        if let myStaffId = userData["staffId"] as? String,
                           let me = staffMembers.first(where: { $0.id == myStaffId }) {
                            identifiedName = me.name
                        } else if let savedName = userData["staffName"] as? String {
                            identifiedName = savedName
                        }
                    }
                    
                    // Crear ChatUser para la lista de contactos
                    // Usamos el UID como ID para el chat
                    let staffId = userData["staffId"] as? String
                    
                    // Intentamos obtener datos frescos de la lista de personal si es posible
                    let linkedStaff = staffMembers.first(where: { $0.id == staffId })
                    
                    let name = linkedStaff?.name ?? (userData["staffName"] as? String ?? "Usuario")
                    let role = linkedStaff?.role ?? (userData["staffRole"] as? String ?? "Personal")
                    let email = linkedStaff?.email ?? ""
                    
                    let chatUser = ChatUser(id: uid, name: name, role: role, email: email)
                    loadedChatUsers.append(chatUser)
                }
            }
            
            DispatchQueue.main.async {
                self.currentPlant = plant
                self.myPlantName = identifiedName
                self.plantUsers = loadedChatUsers // <--- Actualizamos la lista filtrada
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
        
        if let handle = dailyAssignmentsHandle {
            dailyAssignmentsRef?.removeObserver(withHandle: handle)
            dailyAssignmentsHandle = nil
        }
        
        let nodeRef = ref.child("plants").child(plantId).child("turnos").child("turnos-\(dateString)")
        dailyAssignmentsRef = nodeRef
        
        dailyAssignmentsHandle = nodeRef.observe(.value) { snapshot in
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
    
    // MARK: - Fetch GLOBAL (Sin filtrar por mes)
    func fetchMonthlyAssignments(plantId: String, month: Date) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let handle = monthlyAssignmentsHandle {
            monthlyAssignmentsRef?.removeObserver(withHandle: handle)
            monthlyAssignmentsHandle = nil
        }
        
        let nodeRef = ref.child("plants").child(plantId).child("turnos")
        monthlyAssignmentsRef = nodeRef
        
        monthlyAssignmentsHandle = nodeRef.observe(.value) { snapshot in
            var allAssignments: [Date: [PlantShiftWorker]] = [:]
            
            guard let allDatesDict = snapshot.value as? [String: Any] else {
                DispatchQueue.main.async { self.monthlyAssignments = [:] }
                return
            }
            
            for (nodeName, value) in allDatesDict {
                guard nodeName.hasPrefix("turnos-") else { continue }
                let dateString = String(nodeName.dropFirst("turnos-".count))
                
                guard let date = formatter.date(from: dateString) else { continue }
                
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
                    var unique: [String: PlantShiftWorker] = [:]
                    for w in workersForDay {
                        let key = "\(w.name)_\(w.shiftName ?? "")"
                        unique[key] = w
                    }
                    
                    let startOfDay = calendar.startOfDay(for: date)
                    allAssignments[startOfDay] = Array(unique.values)
                }
            }
            
            DispatchQueue.main.async {
                self.monthlyAssignments = allAssignments
            }
        }
    }
    
    // MARK: - IMPORTACIÓN CSV MATRICIAL
    func processMatrixCSVImport(csvContent: String, plant: HospitalPlant, completion: @escaping (Bool, String) -> Void) {
        let rows = csvContent.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        guard rows.count > 1 else {
            completion(false, "El archivo está vacío o no tiene cabeceras.")
            return
        }
        
        let headerRow = rows[0].components(separatedBy: ",")
        var dateMap: [Int: String] = [:]
        
        for i in 1..<headerRow.count {
            let dateStr = headerRow[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !dateStr.isEmpty {
                if let normalizedDate = normalizeDate(dateStr) {
                    dateMap[i] = normalizedDate
                }
            }
        }
        
        if dateMap.isEmpty {
            completion(false, "No se encontraron fechas válidas en la primera fila (formato esperado: yyyy-MM-dd).")
            return
        }
        
        var staffRoleMap: [String: String] = [:]
        for staff in plant.allStaffList {
            let normalizedName = staff.name.trimmingCharacters(in: .whitespaces).lowercased()
            staffRoleMap[normalizedName] = staff.role
        }
        
        var updatesByDate: [String: [String: (nurses: [String], auxs: [String])]] = [:]
        
        for rowIndex in 1..<rows.count {
            let rowStr = rows[rowIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if rowStr.isEmpty { continue }
            
            let cols = rowStr.components(separatedBy: ",")
            if cols.isEmpty { continue }
            
            let rawName = cols[0].trimmingCharacters(in: .whitespaces)
            if rawName.isEmpty { continue }
            
            guard let role = staffRoleMap[rawName.lowercased()] else {
                AppLogger.debug("Aviso: \(rawName) no encontrado en personal de planta. Se ignora.")
                continue
            }
            
            let isNurse = role.lowercased().contains("enfermer")
            let isAux = role.lowercased().contains("auxiliar") || role.lowercased().contains("tcae")
            
            if !isNurse && !isAux { continue }
            
            for (colIndex, dateKey) in dateMap {
                if colIndex >= cols.count { break }
                
                let shiftValue = cols[colIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if shiftValue.isEmpty || shiftValue.lowercased() == "libre" { continue }
                
                let shiftName = shiftValue.prefix(1).uppercased() + shiftValue.dropFirst().lowercased()
                
                if updatesByDate[dateKey] == nil { updatesByDate[dateKey] = [:] }
                if updatesByDate[dateKey]![shiftName] == nil {
                    updatesByDate[dateKey]![shiftName] = (nurses: [], auxs: [])
                }
                
                if isNurse {
                    updatesByDate[dateKey]![shiftName]?.nurses.append(rawName)
                } else {
                    updatesByDate[dateKey]![shiftName]?.auxs.append(rawName)
                }
            }
        }
        
        if updatesByDate.isEmpty {
            completion(false, "No se encontraron asignaciones válidas para importar.")
            return
        }
        
        var firebaseUpdates: [String: Any] = [:]
        
        for (dateKey, shiftsMap) in updatesByDate {
            for (shiftName, lists) in shiftsMap {
                let path = "plants/\(plant.id)/turnos/turnos-\(dateKey)/\(shiftName)"
                
                var nursesArray: [[String: Any]] = []
                for (i, name) in lists.nurses.enumerated() {
                    nursesArray.append([
                        "halfDay": false,
                        "primary": name,
                        "secondary": "",
                        "primaryLabel": "enfermero\(i+1)",
                        "secondaryLabel": ""
                    ])
                }
                
                var auxArray: [[String: Any]] = []
                for (i, name) in lists.auxs.enumerated() {
                    auxArray.append([
                        "halfDay": false,
                        "primary": name,
                        "secondary": "",
                        "primaryLabel": "auxiliar\(i+1)",
                        "secondaryLabel": ""
                    ])
                }
                
                if !nursesArray.isEmpty {
                    firebaseUpdates["\(path)/nurses"] = nursesArray
                }
                if !auxArray.isEmpty {
                    firebaseUpdates["\(path)/auxiliaries"] = auxArray
                }
            }
        }
        
        ref.updateChildValues(firebaseUpdates) { error, _ in
            if let error = error {
                completion(false, "Error al guardar en BD: \(error.localizedDescription)")
            } else {
                completion(true, "Importación completada con éxito.")
            }
        }
    }
    
    private func normalizeDate(_ dateStr: String) -> String? {
        let inputFormats = ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "d/M/yyyy"]
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        
        for format in inputFormats {
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = format
            inputFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = inputFormatter.date(from: dateStr) {
                return outputFormatter.string(from: date)
            }
        }
        return nil
    }
}
