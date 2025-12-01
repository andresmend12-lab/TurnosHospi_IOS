import Foundation

struct UserProfile: Identifiable, Equatable, Codable {
    let id: String
    var firstName: String
    var lastName: String
    var role: String
    var gender: String
    var email: String
    var plantId: String?
    var avatarSystemName: String
    var specialty: String
    var createdAt: Date?
    var updatedAt: Date?

    var name: String { [firstName, lastName].joined(separator: " ").trimmingCharacters(in: .whitespaces) }
    var displayRole: String { role.isEmpty ? "Profesional" : role }
    var staffRole: StaffRole? { StaffRole(rawValue: role) }

    static let demo = UserProfile(
        id: "demo-user",
        firstName: "Dra.",
        lastName: "María Díaz",
        role: "Médico",
        gender: "F",
        email: "maria.diaz@hospi.cl",
        plantId: "demo-plant",
        avatarSystemName: "person.crop.circle.fill",
        specialty: "UTI",
        createdAt: nil,
        updatedAt: nil
    )
}

enum StaffRole: String, CaseIterable, Identifiable, Codable {
    case doctor = "Médico"
    case nurse = "Enfermera"
    case technician = "TENS"
    case admin = "Administrativo"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .doctor: return "stethoscope"
        case .nurse: return "cross.case"
        case .technician: return "bandage"
        case .admin: return "clipboard"
        }
    }
}

struct Plant: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var code: String
    var description: String
    var members: [StaffMember]
    var staffRequirements: [String: Int]
    var shiftTimes: [String: ShiftTime]

    static let demo = Plant(
        id: "demo-plant",
        name: "Planta Pediatría Norte",
        code: "PEDI-NORTE",
        description: "Equipo multidisciplinario con 24 camas y urgencia 24/7",
        members: StaffMember.demoMembers,
        staffRequirements: [:],
        shiftTimes: [:]
    )
}

struct ShiftTime: Codable, Equatable {
    var start: String
    var end: String
}

struct StaffMember: Identifiable, Equatable {
    let id: UUID
    var name: String
    var role: StaffRole
    var shifts: [Shift]

    static let demoMembers: [StaffMember] = [
        StaffMember(
            id: UUID(uuidString: "f977252e-89c7-4a62-8517-53a834a41f2b")!,
            name: "Dr. Juan Pérez",
            role: .doctor,
            shifts: Shift.demoForWeek
        ),
        StaffMember(
            id: UUID(uuidString: "5d2cf582-e1c0-4680-8de8-7af06c6b7ff7")!,
            name: "Dra. María Díaz",
            role: .doctor,
            shifts: Shift.demoForWeek
        ),
        StaffMember(
            id: UUID(uuidString: "0ab5e3dd-3430-4494-b4ee-5897d0645d52")!,
            name: "Enf. Carolina Soto",
            role: .nurse,
            shifts: Shift.demoForWeek
        )
    ]
}

struct Shift: Identifiable, Equatable, Hashable {
    enum Status: String, CaseIterable, Identifiable, Codable {
        case assigned = "Asignado"
        case offered = "En intercambio"
        case swapped = "Cambiado"
        case unavailable = "No disponible"

        var id: String { rawValue }
        var color: String {
            switch self {
            case .assigned: return "systemGreen"
            case .offered: return "systemOrange"
            case .swapped: return "systemBlue"
            case .unavailable: return "systemGray"
            }
        }
    }

    let id: UUID
    var date: Date
    var name: String
    var location: String
    var status: Status
    var isNight: Bool
    var notes: String

    static func demo(date: Date, name: String, status: Status, isNight: Bool = false) -> Shift {
        Shift(
            id: UUID(),
            date: date,
            name: name,
            location: "Pabellón A",
            status: status,
            isNight: isNight,
            notes: isNight ? "Entrega a las 08:00" : "Entrega 19:00"
        )
    }

    static var demoForWeek: [Shift] {
        let calendar = Calendar.current
        let now = Date()
        return [
            demo(date: now, name: "Diurno", status: .assigned),
            demo(date: calendar.date(byAdding: .day, value: 1, to: now)!, name: "Nocturno", status: .assigned, isNight: true),
            demo(date: calendar.date(byAdding: .day, value: 3, to: now)!, name: "Diurno", status: .offered),
            demo(date: calendar.date(byAdding: .day, value: 4, to: now)!, name: "Nocturno", status: .swapped, isNight: true)
        ]
    }
}

struct ShiftOffer: Identifiable, Equatable {
    let id: UUID
    var owner: StaffMember
    var offeredShift: Shift
    var desiredShiftName: String
    var extraNotes: String
}

struct NotificationItem: Identifiable, Equatable {
    enum Kind: String { case system, shift, chat, generic }

    let id: String
    var type: String
    var title: String
    var message: String
    var date: Date
    var kind: Kind
    var isRead: Bool
    var targetScreen: String?
    var targetId: String?
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var sender: StaffMember
    var text: String
    var date: Date
    var isMine: Bool
}

struct ChatThread: Identifiable, Equatable {
    let id: UUID
    var participants: [StaffMember]
    var lastMessage: String
    var unreadCount: Int
    var messages: [ChatMessage]
}
