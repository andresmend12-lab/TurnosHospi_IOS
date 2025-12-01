import Foundation
import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var profile: UserProfile? = .demo
    @Published var plant: Plant? = .demo
    @Published var isAuthenticated: Bool = true
    @Published var errorMessage: String?

    func login(email: String, password: String) {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Completa correo y contraseña"
            return
        }
        withAnimation {
            isAuthenticated = true
            profile = .demo
        }
    }

    func signOut() {
        withAnimation {
            isAuthenticated = false
            profile = nil
        }
    }
}

final class ShiftViewModel: ObservableObject {
    @Published var myShifts: [Shift]
    @Published var offers: [ShiftOffer]

    init(members: [StaffMember]) {
        self.myShifts = members.first?.shifts ?? []
        self.offers = members.compactMap { member in
            guard let offered = member.shifts.first else { return nil }
            return ShiftOffer(
                id: UUID(),
                owner: member,
                offeredShift: offered,
                desiredShiftName: "Nocturno",
                extraNotes: "Busco cambio por turno nocturno"
            )
        }
    }

    func requestChange(for shift: Shift, with peer: StaffMember) {
        offers.append(
            ShiftOffer(
                id: UUID(),
                owner: peer,
                offeredShift: shift,
                desiredShiftName: "Diurno",
                extraNotes: "Cambio rápido"
            )
        )
    }
}

final class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread]

    init(members: [StaffMember]) {
        let me = members[1]
        let other = members[0]
        let now = Date()
        let messages = [
            ChatMessage(id: UUID(), sender: me, text: "Confirmas turno de mañana?", date: now, isMine: true),
            ChatMessage(id: UUID(), sender: other, text: "Sí, quedamos en entregar 19:00", date: now, isMine: false)
        ]
        threads = [
            ChatThread(
                id: UUID(),
                participants: [me, other],
                lastMessage: messages.last?.text ?? "",
                unreadCount: 2,
                messages: messages
            ),
            ChatThread(
                id: UUID(),
                participants: members,
                lastMessage: "Se actualizó el protocolo de triage",
                unreadCount: 0,
                messages: messages
            )
        ]
    }
}

final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NotificationItem]

    init() {
        notifications = [
            NotificationItem(
                id: UUID(),
                title: "Cambio de turno confirmado",
                message: "María aceptó tu cambio del viernes",
                date: Date(),
                kind: .shift,
                isRead: false
            ),
            NotificationItem(
                id: UUID(),
                title: "Nuevo mensaje",
                message: "Pediatría Norte compartió un archivo",
                date: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!,
                kind: .chat,
                isRead: true
            ),
            NotificationItem(
                id: UUID(),
                title: "Revisión semanal",
                message: "3 turnos pendientes por cubrir",
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                kind: .system,
                isRead: true
            )
        ]
    }

    func markAsRead(_ notification: NotificationItem) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
    }
}
