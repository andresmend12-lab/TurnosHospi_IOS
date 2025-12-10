import Foundation

// Modelo de un mensaje individual (Historial)
struct DirectMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var text: String
    var timestamp: TimeInterval
    var read: Bool = false
    
    var timeString: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

// Modelo de usuario
struct ChatUser: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let role: String
    let email: String
}

// --- NUEVO: Modelo para la Lista de Chats (Compatible con Android) ---
struct ChatConversation: Identifiable {
    var id: String { otherUser.id } // La ID visual es el otro usuario
    let otherUser: ChatUser
    let lastMessage: String
    let timestamp: TimeInterval
    let unreadCount: Int
    let chatId: String
    
    // Formato de hora inteligente (Hora hoy, Fecha otros días)
    var timeString: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Ayer'"
        } else {
            formatter.dateFormat = "dd/MM/yy"
        }
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}
