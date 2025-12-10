import Foundation

// Modelo de un mensaje individual (Igual que en Android)
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

// Modelo de usuario para la lista
struct ChatUser: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let role: String
    let email: String
}

// Modelo para la lista de conversaciones recientes
struct ChatConversation: Identifiable {
    var id: String { otherUser.id }
    let otherUser: ChatUser
    let lastMessage: String
    let timestamp: TimeInterval
    let unreadCount: Int
    let chatId: String
    
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
