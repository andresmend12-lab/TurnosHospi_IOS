import Foundation
import FirebaseDatabase
import FirebaseAuth

class PlantManager: ObservableObject {
    private let ref = Database.database().reference()
    
    @Published var foundPlant: HospitalPlant?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var joinSuccess: Bool = false
    
    // Buscar planta
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
                        name: data["name"] as? String ?? "Sin nombre",
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
                staffList: staffMembers
            )
            
            DispatchQueue.main.async {
                self.foundPlant = plant
            }
        }
    }
    
    // Unirse a la planta
    func joinPlant(plant: HospitalPlant, selectedStaff: PlantStaff) {
        guard let user = Auth.auth().currentUser else { return }
        self.isLoading = true
        
        let userPlantData: [String: Any] = [
            "plantId": plant.id,
            "staffId": selectedStaff.id,
            "staffName": selectedStaff.name,
            "staffRole": selectedStaff.role
        ]
        
        // 1. Guardar en la planta
        ref.child("plants").child(plant.id).child("userPlants").child(user.uid).setValue(userPlantData) { error, _ in
            if let error = error {
                self.isLoading = false
                self.errorMessage = "Error al unirse: \(error.localizedDescription)"
            } else {
                
                // 2. ACTUALIZAR PERFIL DE USUARIO (Guardar ID de planta)
                let userUpdates: [String: Any] = [
                    "role": selectedStaff.role,
                    "plantId": plant.id
                ]
                
                self.ref.child("users").child(user.uid).updateChildValues(userUpdates) { err, _ in
                    self.isLoading = false
                    if err == nil {
                        self.joinSuccess = true
                    }
                }
            }
        }
    }
}
