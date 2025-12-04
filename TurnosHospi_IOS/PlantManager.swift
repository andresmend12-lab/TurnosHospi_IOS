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
    
    // Almacena los trabajadores del día seleccionado (Agrupados por turno: "Mañana" -> [Persona1, Persona2])
    @Published var dailyStaff: [String: [PlantShiftWorker]] = [:]
    
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
            
            let plant = HospitalPlant(
                id: plantId,
                name: value["name"] as? String ?? "Planta",
                hospitalName: value["hospitalName"] as? String ?? "Hospital",
                accessPassword: realPassword,
                staffList: staffMembers,
                staffScope: staffScope
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
    
    // MARK: - Obtener Planta Actual
    func fetchCurrentPlant(plantId: String) {
        ref.child("plants").child(plantId).observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                let staffScope = value["staffScope"] as? String ?? "nurses_only"
                
                let plant = HospitalPlant(
                    id: plantId,
                    name: value["name"] as? String ?? "Planta",
                    hospitalName: value["hospitalName"] as? String ?? "Hospital",
                    accessPassword: "",
                    staffList: [],
                    staffScope: staffScope
                )
                self.currentPlant = plant
            }
        }
    }
    
    // MARK: - NUEVO: Obtener personal del día
    func fetchDailyStaff(plantId: String, date: Date) {
        // 1. Formatear la fecha a "YYYY-MM-DD"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let nodeName = "turnos-\(dateString)"
        
        // 2. Ruta: plants -> [ID] -> turnos -> turnos-2025-11-28
        ref.child("plants").child(plantId).child("turnos").child(nodeName).observe(.value) { snapshot in
            
            var newDailyStaff: [String: [PlantShiftWorker]] = [:]
            
            // Estructura esperada:
            // "Mañana": { "uid1": {name: "Pepe", role: "Enfermero"}, ... }
            // "Tarde": { ... }
            
            if let shiftsDict = snapshot.value as? [String: [String: [String: Any]]] {
                
                for (shiftName, workersDict) in shiftsDict {
                    var workers: [PlantShiftWorker] = []
                    
                    for (workerId, workerData) in workersDict {
                        let name = workerData["name"] as? String ?? "Usuario"
                        let role = workerData["role"] as? String ?? "Personal"
                        
                        let worker = PlantShiftWorker(id: workerId, name: name, role: role)
                        workers.append(worker)
                    }
                    
                    newDailyStaff[shiftName] = workers
                }
            }
            
            DispatchQueue.main.async {
                self.dailyStaff = newDailyStaff
            }
        }
    }
}
