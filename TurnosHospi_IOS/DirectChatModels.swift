import Foundation

// MARK: - Usuario para el Chat
struct ChatUser: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let role: String
    let email: String
}

// MARK: - Ruta de Navegación (ESTABLE)
struct ChatRoute: Hashable {
    let chatId: String
    let otherUserId: String
    let otherUserName: String
    
    // IMPORTANTE: Definimos la igualdad solo por ID.
    // Esto evita que la pantalla se cierre si el nombre se actualiza un segundo después.
    static func == (lhs: ChatRoute, rhs: ChatRoute) -> Bool {
        return lhs.chatId == rhs.chatId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(chatId)
    }
}

extension ChatRoute: Identifiable {
    var id: String { chatId }
}

// MARK: - Modelo de Chat (Resumen para la lista)
struct DirectChat: Identifiable, Codable, Hashable {
    let id: String
    // Datos calculados dinámicamente
    var lastMessage: String
    var timestamp: TimeInterval
    
    // Datos del otro usuario
    var otherUserName: String
    var otherUserRole: String
    var otherUserId: String
    
    // Helper ID único: Orden alfabético estricto (Igual que en Android)
    static func getChatId(user1: String, user2: String) -> String {
        return user1 < user2 ? "\(user1)_\(user2)" : "\(user2)_\(user1)"
    }
}

// MARK: - Modelo de Mensaje
struct DirectMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: TimeInterval
    let read: Bool
    
    var timeString: String {
        // Android guarda milisegundos, iOS TimeInterval es segundos.
        // Convertimos dividiendo por 1000.
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}
