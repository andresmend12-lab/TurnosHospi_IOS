import Foundation
import FirebaseDatabase
import FirebaseAuth

class PlantManager: ObservableObject {
    private let ref = Database.database().reference()
    
    @Published var foundPlant: HospitalPlant?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var joinSuccess: Bool = false
    
    // PASO 1: Buscar la planta por ID y verificar contraseña
    func searchPlant(plantId: String, password: String) {
        self.isLoading = true
        self.errorMessage = nil
        self.foundPlant = nil
        
        // Buscamos en el nodo 'plants' -> 'ID'
        ref.child("plants").child(plantId).observeSingleEvent(of: .value) { snapshot in
            self.isLoading = false
            
            guard let value = snapshot.value as? [String: Any] else {
                self.errorMessage = "No se encontró ninguna planta con ese ID."
                return
            }
            
            // Verificamos la contraseña
            guard let realPassword = value["accessPassword"] as? String, realPassword == password else {
                self.errorMessage = "La contraseña es incorrecta."
                return
            }
            
            // Parseamos (procesamos) la lista del personal
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
            
            // Creamos el objeto planta localmente con el personal cargado
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
    
    // PASO 2: Unirse a la planta seleccionando un personal
    func joinPlant(plant: HospitalPlant, selectedStaff: PlantStaff) {
        guard let user = Auth.auth().currentUser else { return }
        self.isLoading = true
        
        // Estructura que me pediste para 'userPlants'
        let userPlantData: [String: Any] = [
            "plantId": plant.id,
            "staffId": selectedStaff.id,
            "staffName": selectedStaff.name,
            "staffRole": selectedStaff.role
        ]
        
        // Guardamos en: userPlants -> UID_DEL_USUARIO -> Datos
        ref.child("userPlants").child(user.uid).setValue(userPlantData) { error, _ in
            self.isLoading = false
            if let error = error {
                self.errorMessage = "Error al unirse: \(error.localizedDescription)"
            } else {
                self.joinSuccess = true // Esto disparará el cierre de la vista
                
                // Opcional: Actualizar el perfil del usuario en 'users' para indicar que ya tiene planta
                self.ref.child("users").child(user.uid).updateChildValues(["role": selectedStaff.role])
            }
        }
    }
}
