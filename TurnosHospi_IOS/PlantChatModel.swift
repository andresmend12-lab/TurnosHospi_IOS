import Foundation

// Representa a la planta (ej: "Mi Monstera")
// Requisito: Tiene asociado un userid y un fcmToken
struct UserPlant: Identifiable, Codable, Hashable {
    let id: String
    let nickname: String
    let species: String
    let userId: String      // ID del dueño (vinculación requerida)
    let fcmToken: String    // Token para notificaciones push a esta planta
    let imageUrl: String?
}

// Representa la sesión de chat activa para navegar
struct PlantChatSession: Identifiable, Hashable {
    let id: String // ID del chat (ej: chat_user123_plant456)
    let plantName: String
    let plantId: String
    let targetFcmToken: String // El token se pasa a la sesión
}
