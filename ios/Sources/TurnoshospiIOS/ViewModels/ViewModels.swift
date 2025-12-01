import Foundation
import SwiftUI
import FirebaseDatabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var plant: Plant?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = FirebaseService.shared

    var userId: String? { profile?.id }

    init() {
        service.configureIfNeeded()
    }

    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completa correo y contraseña"
            return
        }
        isLoading = true

        Task {
            do {
                let user = try await service.signIn(email: email, password: password)
                let loadedProfile = try await service.loadUserProfile(userId: user.uid)
                let resolvedProfile = loadedProfile ?? UserProfile(
                    id: user.uid,
                    firstName: user.displayName ?? "",
                    lastName: "",
                    role: "",
                    gender: "",
                    email: user.email ?? email,
                    plantId: nil,
                    avatarSystemName: "person.crop.circle.fill",
                    specialty: "",
                    createdAt: nil,
                    updatedAt: nil
                )
                let plant = try await service.loadPlant(for: user.uid) ?? .demo
                await MainActor.run {
                    self.profile = resolvedProfile.replacing(id: user.uid)
                    self.plant = plant
                    self.isAuthenticated = true
                    self.errorMessage = nil
                }
                service.refreshMessagingToken()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAuthenticated = false
                }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    func register(firstName: String, lastName: String, email: String, role: StaffRole, gender: String, password: String, specialty: String) {
        isLoading = true
        let draft = UserProfile(
            id: UUID().uuidString,
            firstName: firstName,
            lastName: lastName,
            role: role.rawValue,
            gender: gender,
            email: email,
            plantId: nil,
            avatarSystemName: "person.crop.circle.fill",
            specialty: specialty,
            createdAt: nil,
            updatedAt: nil
        )

        Task {
            do {
                let user = try await service.createAccount(profile: draft, password: password)
                let storedProfile = try await service.loadUserProfile(userId: user.uid) ?? draft.replacing(id: user.uid)
                await MainActor.run {
                    self.profile = storedProfile.replacing(id: user.uid)
                    self.isAuthenticated = true
                    self.errorMessage = nil
                }
                service.refreshMessagingToken()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isLoading = false }
        }
    }

    func signOut() {
        do {
            try service.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        profile = nil
        plant = nil
        isAuthenticated = false
    }
}

final class ShiftViewModel: ObservableObject {
    @Published var myShifts: [Shift]
    @Published var offers: [ShiftOffer]

    private let service = FirebaseService.shared
    private var shiftRef: DatabaseReference?
    private var shiftHandle: DatabaseHandle?

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

    func startListening(plantId: String, userId: String) {
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        let result = service.listenToUserShifts(plantId: plantId, userId: userId) { [weak self] shifts in
            Task { @MainActor in
                self?.myShifts = shifts.isEmpty ? Shift.demoForWeek : shifts
            }
        }
        shiftRef = result.0
        shiftHandle = result.1
    }

    func stopListening() {
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        shiftRef = nil
        shiftHandle = nil
        myShifts = []
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
    @Published var notifications: [NotificationItem] = []
    private let service = FirebaseService.shared
    private var userId: String?

    func beginListening(userId: String) {
        guard self.userId != userId else { return }
        self.userId = userId
        service.listenToNotifications(userId: userId) { [weak self] items in
            Task { @MainActor in
                self?.notifications = items
            }
        }
    }

    func stop() {
        userId = nil
        notifications = []
        service.stopListeningNotifications()
    }

    func markAsRead(_ notification: NotificationItem) {
        guard let userId else { return }
        service.markNotificationAsRead(userId: userId, notificationId: notification.id)
    }

    func delete(_ notification: NotificationItem) {
        guard let userId else { return }
        service.deleteNotification(userId: userId, notificationId: notification.id)
    }

    func deleteAll() {
        guard let userId else { return }
        service.clearNotifications(userId: userId)
    }
}

private extension UserProfile {
    func replacing(id: String) -> UserProfile {
        UserProfile(
            id: id,
            firstName: firstName,
            lastName: lastName,
            role: role,
            gender: gender,
            email: email,
            plantId: plantId,
            avatarSystemName: avatarSystemName,
            specialty: specialty,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
