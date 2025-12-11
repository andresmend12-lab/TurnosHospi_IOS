import Foundation

// MARK: - Usuario para el Chat
struct ChatUser: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let role: String
    let email: String
}

// MARK: - Ruta de Navegación (ESTABLE)
// Usamos esto para NavigationStack. No incluye lastMessage ni timestamp
// para que no cambie al llegar mensajes nuevos.
struct ChatRoute: Hashable {
    let chatId: String
    let otherUserId: String
    let otherUserName: String
}

// MARK: - Modelo de Chat (DATOS + UI AUXILIAR)
struct DirectChat: Identifiable, Codable, Hashable {
    let id: String
    let participants: [String]
    let lastMessage: String
    let timestamp: TimeInterval
    
    // Datos auxiliares solo para la UI (NO se guardan en Firebase)
    var otherUserName: String = ""
    var otherUserRole: String = ""
    var otherUserId: String = ""
    
    // Helper ID único: uid1_uid2 (ordenados)
    static func getChatId(user1: String, user2: String) -> String {
        return [user1, user2].sorted().joined(separator: "_")
    }
    
    // Solo persistimos los campos "de datos"
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case lastMessage
        case timestamp
    }
}

// MARK: - Modelo de Mensaje
struct DirectMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: TimeInterval   // esperado en milisegundos desde Epoch
    let read: Bool
    
    var timeString: String {
        // timestamp viene en ms → dividimos entre 1000
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
