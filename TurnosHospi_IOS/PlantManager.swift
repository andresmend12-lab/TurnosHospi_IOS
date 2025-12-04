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
    
    // Almacena los trabajadores del día seleccionado (para visualización y edición)
    @Published var dailyAssignments: [String: [PlantShiftWorker]] = [:]
    
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
            
            guard let realPassword = value["accessPassword"] as? String, realPassword == password else {
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
            
            let staffScope = value["staffScope"] as? String ?? "nurses_only"
            
            // Note: Shift configuration data is NOT included here, as this function is for joining/search.
            let plant = HospitalPlant(
                id: plantId,
                name: value["name"] as? String ?? "Planta",
                hospitalName: value["hospitalName"] as? String ?? "Hospital",
                accessPassword: realPassword,
                allStaffList: staffMembers, // Use full list
                staffScope: staffScope,
                shiftDuration: nil,
                staffRequirements: nil,
                shiftTimes: nil
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
        
        ref.child("plants").child(plant.id).child("userPlants").child(user.uid).setValue(userPlantData) { error, _ in
            if let error = error {
                self.isLoading = false
                self.errorMessage = "Error al unirse: \(error.localizedDescription)"
            } else {
                let userUpdates: [String: Any] = ["role": selectedStaff.role, "plantId": plant.id]
                self.ref.child("users").child(user.uid).updateChildValues(userUpdates) { err, _ in
                    self.isLoading = false
                    if err == nil { self.joinSuccess = true }
                }
            }
        }
    }
    
    // MARK: - Obtener Planta Actual (Actualizada para incluir toda la config)
    func fetchCurrentPlant(plantId: String) {
        // Escucha en tiempo real para las actualizaciones de la planta
        ref.child("plants").child(plantId).observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            var staffMembers: [PlantStaff] = []
            // Nota: Buscamos en la ruta "staffList" para obtener todos los empleados
            if let personalDict = value["staffList"] as? [String: [String: Any]] {
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
                    allStaffList: staffMembers, // <--- LISTA COMPLETA DE PERSONAL
                    staffScope: staffScope,
                    shiftDuration: shiftDuration,
                    staffRequirements: staffRequirements,
                    shiftTimes: shiftTimes
                )
                self.currentPlant = plant
            }
        }
    }
    
    // MARK: - Obtener personal del día (assignments)
    func fetchDailyStaff(plantId: String, date: Date) {
        // 1. Formatear la fecha a "YYYY-MM-DD"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let nodeName = "turnos-\(dateString)"
        
        // 2. Ruta: plants -> [ID] -> turnos -> turnos-2025-11-28
        ref.child("plants").child(plantId).child("turnos").child(nodeName).observe(.value) { snapshot in
            
            var newDailyAssignments: [String: [PlantShiftWorker]] = [:]
            
            if let shiftsDict = snapshot.value as? [String: [String: [String: Any]]] {
                
                for (shiftName, workersDict) in shiftsDict {
                    var workers: [PlantShiftWorker] = []
                    
                    for (workerId, workerData) in workersDict {
                        let name = workerData["name"] as? String ?? "Usuario"
                        let role = workerData["role"] as? String ?? "Personal"
                        
                        let worker = PlantShiftWorker(id: workerId, name: name, role: role)
                        workers.append(worker)
                    }
                    
                    newDailyAssignments[shiftName] = workers
                }
            }
            
            DispatchQueue.main.async {
                self.dailyAssignments = newDailyAssignments
            }
        }
    }
}
