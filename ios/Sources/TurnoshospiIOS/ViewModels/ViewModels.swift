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
    @Published var myShifts: [Shift] = []
    @Published var marketplaceRequests: [ShiftChangeRequest] = []

    private let service = FirebaseService.shared
    private var shiftRef: DatabaseReference?
    private var shiftHandle: DatabaseHandle?
    private var requestRef: DatabaseReference?
    private var requestHandle: DatabaseHandle?
    private var memberLookup: [String: UserProfile] = [:]

    func startListening(plantId: String, userId: String) {
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        let result = service.listenToUserShifts(plantId: plantId, userId: userId) { [weak self] shifts in
            Task { @MainActor in
                self?.myShifts = shifts.isEmpty ? Shift.demoForWeek : shifts
            }
        }
        shiftRef = result.0
        shiftHandle = result.1
        startMarketplace(plantId: plantId, userId: userId)
        Task { [weak self] in
            self?.memberLookup = await self?.service.fetchPlantMembers(plantId: plantId) ?? [:]
        }
    }

    func stopListening() {
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        service.detachListener(ref: requestRef, handle: requestHandle)
        shiftRef = nil
        shiftHandle = nil
        requestRef = nil
        requestHandle = nil
        myShifts = []
        marketplaceRequests = []
    }

    func startMarketplace(plantId: String, userId: String) {
        service.detachListener(ref: requestRef, handle: requestHandle)
        let result = service.listenToShiftRequests(plantId: plantId, currentUserId: userId) { [weak self] requests in
            Task { @MainActor in
                self?.marketplaceRequests = requests
            }
        }
        requestRef = result.0
        requestHandle = result.1
    }

    func respond(to request: ShiftChangeRequest, with shift: Shift?, profile: UserProfile, plantId: String) {
        service.respondToShiftRequest(plantId: plantId, request: request, responder: profile, selectedShift: shift)
    }

    func resolveName(for id: String) -> String {
        memberLookup[id]?.name ?? id
    }
}

final class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var messages: [ChatMessage] = []
    @Published var availableContacts: [UserProfile] = []
    @Published var activeChatId: String?

    private let service = FirebaseService.shared
    private var chatRef: DatabaseReference?
    private var chatHandle: DatabaseHandle?
    private var messagesRef: DatabaseReference?
    private var messagesHandle: DatabaseHandle?
    private var memberLookup: [String: UserProfile] = [:]
    private var plantId: String?
    private var user: UserProfile?

    func start(plantId: String, user: UserProfile) {
        self.plantId = plantId
        self.user = user
        Task { [weak self] in
            guard let self else { return }
            let members = await service.fetchPlantMembers(plantId: plantId)
            await MainActor.run {
                self.memberLookup = members
                self.availableContacts = members.values.filter { $0.id != user.id }.sorted { $0.name < $1.name }
            }
        }
        bindChats(plantId: plantId, userId: user.id)
    }

    func stop() {
        service.detachListener(ref: chatRef, handle: chatHandle)
        service.detachListener(ref: messagesRef, handle: messagesHandle)
        chatRef = nil
        chatHandle = nil
        messagesRef = nil
        messagesHandle = nil
        threads = []
        messages = []
        activeChatId = nil
        plantId = nil
        user = nil
        availableContacts = []
    }

    private func bindChats(plantId: String, userId: String) {
        service.detachListener(ref: chatRef, handle: chatHandle)
        let result = service.listenToDirectChats(plantId: plantId, currentUserId: userId) { [weak self] threads in
            Task { @MainActor in
                self?.threads = threads.map { thread in
                    var namedThread = thread
                    if let other = self?.memberLookup[thread.otherUserId] {
                        namedThread.otherUserName = other.name
                    }
                    return namedThread
                }
            }
        }
        chatRef = result.0
        chatHandle = result.1
    }

    func selectChat(with otherUserId: String) {
        guard let plantId, let user else { return }
        let chatId = service.ensureChatId(currentUserId: user.id, otherUserId: otherUserId)
        activeChatId = chatId
        service.detachListener(ref: messagesRef, handle: messagesHandle)
        let result = service.listenToMessages(plantId: plantId, chatId: chatId, currentUserId: user.id) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages
            }
        }
        messagesRef = result.0
        messagesHandle = result.1
    }

    func sendMessage(_ text: String) {
        guard let plantId, let chatId = activeChatId, let user, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        service.sendMessage(plantId: plantId, chatId: chatId, user: user, text: text)
    }

    func displayName(for thread: ChatThread) -> String {
        memberLookup[thread.otherUserId]?.name ?? thread.otherUserName
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
