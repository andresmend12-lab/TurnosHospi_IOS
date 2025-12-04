import Foundation

struct DirectMessage: Identifiable, Codable {
    var id: String = ""
    var senderId: String = ""
    var text: String = ""
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var read: Bool = false
}

struct ChatUserSummary: Identifiable {
    var id: String { userId } // Conformance to Identifiable
    let userId: String
    let name: String
    let role: String
    var hasUnread: Bool = false
}

struct ActiveChatSummary: Identifiable {
    var id: String { chatId }
    let chatId: String
    let otherUserId: String
    let otherUserName: String
    let lastMessage: String
    let timestamp: Int64
}
