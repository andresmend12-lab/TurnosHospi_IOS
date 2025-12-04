import Foundation

struct PlantMembership: Codable {
    var plantId: String = ""
    var userId: String = ""
    var staffId: String? = nil
    var staffName: String? = nil
    var staffRole: String? = nil
}
