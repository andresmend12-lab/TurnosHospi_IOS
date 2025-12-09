import Foundation

struct DirectMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var text: String
    var timestamp: TimeInterval
    var read: Bool = false
    
    // Helper para la hora
    var timeString: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

// Modelo simple para mostrar usuarios en la lista
// CORRECCIÓN: Añadido Hashable, Codable y el campo email
struct ChatUser: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let role: String
    let email: String
}
