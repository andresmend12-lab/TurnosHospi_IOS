import SwiftUI
import FirebaseDatabase
import FirebaseAuth

class PlantChatViewModel: ObservableObject {
    @Published var myPlants: [UserPlant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let ref = Database.database().reference()
    
    // 1. Cargar las plantas del usuario actual
    func fetchMyPlants() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        // Asumimos que las plantas están guardadas en el nodo 'user_plants/{userId}'
        ref.child("user_plants").child(uid).observeSingleEvent(of: .value) { snapshot in
            var loadedPlants: [UserPlant] = []
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let plant = UserPlant(
                        id: child.key,
                        nickname: dict["nickname"] as? String ?? "Sin nombre",
                        species: dict["species"] as? String ?? "Desconocida",
                        userId: uid, // Confirmamos propiedad
                        fcmToken: dict["fcmToken"] as? String ?? "", // Requisito crítico
                        imageUrl: dict["imageUrl"] as? String
                    )
                    loadedPlants.append(plant)
                }
            }
            
            DispatchQueue.main.async {
                self.myPlants = loadedPlants
                self.isLoading = false
            }
        }
    }
    
    // 2. Iniciar Chat con la planta seleccionada
    func startChatWithPlant(_ plant: UserPlant, completion: @escaping (PlantChatSession) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // ID único del chat compuesto por Usuario + Planta
        let chatId = "chat_\(uid)_\(plant.id)"
        
        // Datos de la sala de chat
        let chatMetadata: [String: Any] = [
            "id": chatId,
            "plantId": plant.id,
            "plantName": plant.nickname,
            "ownerId": uid,
            "lastActive": ServerValue.timestamp(),
            // ACTUALIZACIÓN DE TOKEN:
            // Guardamos el token de la planta en el chat para que el backend sepa a qué dispositivo notificar
            "targetDeviceToken": plant.fcmToken
        ]
        
        // Guardar/Actualizar en Firebase
        ref.child("plant_chats").child(chatId).updateChildValues(chatMetadata) { error, _ in
            if let error = error {
                self.errorMessage = "Error al iniciar chat: \(error.localizedDescription)"
                return
            }
            
            // Crear objeto de sesión y devolverlo para navegar
            let session = PlantChatSession(
                id: chatId,
                plantName: plant.nickname,
                plantId: plant.id,
                targetFcmToken: plant.fcmToken
            )
            completion(session)
        }
    }
}
