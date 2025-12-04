import Foundation

// MARK: - Enums de Usuario
enum UserRole: String, Codable, CaseIterable {
    case supervisor = "Supervisor"
    case enfermero = "Enfermero"
    case auxiliar = "Auxiliar"
}

// MARK: - Modelos de Usuario
struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    var fcmToken: String?
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

// Relación Usuario-Planta
struct PlantMembership: Codable {
    let plantId: String
    let userId: String
    let staffId: String // ID interno o número de colegiado
    let staffName: String
    let staffRole: UserRole
}
