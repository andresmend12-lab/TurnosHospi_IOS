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
    @Published var vacations: [VacationRecord] = []
    @Published var suggestions: [Suggestion] = []
    @Published var stats: ShiftStats = .init(totalHours: 0, nightCount: 0, halfDays: 0, vacations: 0, swapsCompleted: 0, suggestionsSent: 0)
    @Published var validationMessage: String?

    private let service = FirebaseService.shared
    private var shiftRef: DatabaseReference?
    private var shiftHandle: DatabaseHandle?
    private var requestRef: DatabaseReference?
    private var requestHandle: DatabaseHandle?
    private var vacationRef: DatabaseReference?
    private var vacationHandle: DatabaseHandle?
    private var suggestionRef: DatabaseReference?
    private var suggestionHandle: DatabaseHandle?
    private var memberLookup: [String: UserProfile] = [:]
    private var currentUserId: String?

    func startListening(plantId: String, userId: String) {
        currentUserId = userId
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        let result = service.listenToUserShifts(plantId: plantId, userId: userId) { [weak self] shifts in
            Task { @MainActor in
                self?.myShifts = shifts.isEmpty ? Shift.demoForWeek : shifts
                self?.recomputeStats()
            }
        }
        shiftRef = result.0
        shiftHandle = result.1
        startMarketplace(plantId: plantId, userId: userId)
        startVacations(plantId: plantId, userId: userId)
        startSuggestions(userId: userId)
        Task { [weak self] in
            self?.memberLookup = await self?.service.fetchPlantMembers(plantId: plantId) ?? [:]
        }
    }

    func stopListening() {
        service.detachListener(ref: shiftRef, handle: shiftHandle)
        service.detachListener(ref: requestRef, handle: requestHandle)
        service.detachListener(ref: vacationRef, handle: vacationHandle)
        service.detachListener(ref: suggestionRef, handle: suggestionHandle)
        shiftRef = nil
        shiftHandle = nil
        requestRef = nil
        requestHandle = nil
        vacationRef = nil
        vacationHandle = nil
        suggestionRef = nil
        suggestionHandle = nil
        myShifts = []
        marketplaceRequests = []
        vacations = []
        suggestions = []
        stats = .init(totalHours: 0, nightCount: 0, halfDays: 0, vacations: 0, swapsCompleted: 0, suggestionsSent: 0)
        validationMessage = nil
    }

    func startMarketplace(plantId: String, userId: String) {
        service.detachListener(ref: requestRef, handle: requestHandle)
        let result = service.listenToShiftRequests(plantId: plantId, currentUserId: userId) { [weak self] requests in
            Task { @MainActor in
                self?.marketplaceRequests = requests
                self?.recomputeStats()
            }
        }
        requestRef = result.0
        requestHandle = result.1
    }

    func respond(to request: ShiftChangeRequest, with shift: Shift?, profile: UserProfile, plantId: String) {
        Task {
            guard ShiftRulesEngine.canUserParticipate(userRole: profile.role) else {
                await MainActor.run { self.validationMessage = "Tu rol no puede participar en cambios." }
                return
            }

            let responderSchedule = ShiftRulesEngine.buildSchedule(from: myShifts)
            let requesterSchedule = await service.fetchUserSchedule(plantId: plantId, userId: request.requesterId)

            if let error = ShiftRulesEngine.validateWorkRules(
                targetDate: request.requesterShiftDate,
                targetShiftName: request.requesterShiftName,
                userSchedule: responderSchedule
            ) {
                await MainActor.run { self.validationMessage = error }
                return
            }

            if let swapShift = shift {
                let candidate = ShiftChangeRequest(
                    id: UUID().uuidString,
                    type: .swap,
                    status: .searching,
                    mode: .flexible,
                    requesterId: profile.id,
                    requesterName: profile.name,
                    requesterRole: profile.role,
                    requesterShiftDate: swapShift.date,
                    requesterShiftName: swapShift.name,
                    offeredDates: [swapShift.date],
                    targetUserId: request.requesterId,
                    targetUserName: request.requesterName,
                    targetShiftDate: request.requesterShiftDate,
                    targetShiftName: request.requesterShiftName,
                    timestamp: Date()
                )

                guard ShiftRulesEngine.checkMatch(
                    requesterRequest: request,
                    candidateRequest: candidate,
                    requesterSchedule: requesterSchedule,
                    candidateSchedule: responderSchedule
                ) else {
                    await MainActor.run { self.validationMessage = "El intercambio no cumple las reglas laborales." }
                    return
                }
            }

            service.respondToShiftRequest(plantId: plantId, request: request, responder: profile, selectedShift: shift)
            await MainActor.run { self.validationMessage = nil }
        }
    }

    func resolveName(for id: String) -> String {
        memberLookup[id]?.name ?? id
    }

    private func startVacations(plantId: String, userId: String) {
        service.detachListener(ref: vacationRef, handle: vacationHandle)
        let result = service.listenToVacations(plantId: plantId, userId: userId) { [weak self] records in
            Task { @MainActor in
                self?.vacations = records
                self?.recomputeStats()
            }
        }
        vacationRef = result.0
        vacationHandle = result.1
    }

    private func startSuggestions(userId: String) {
        service.detachListener(ref: suggestionRef, handle: suggestionHandle)
        let result = service.listenToSuggestions(userId: userId) { [weak self] suggestions in
            Task { @MainActor in
                self?.suggestions = suggestions
                self?.recomputeStats()
            }
        }
        suggestionRef = result.0
        suggestionHandle = result.1
    }

    private func recomputeStats() {
        let completedSwaps = myShifts.filter { $0.status == .swapped }.count
        stats = service.buildStats(from: myShifts, vacations: vacations, suggestions: suggestions, completedSwaps: completedSwaps)
    }

    func submitSuggestion(text: String) {
        guard let currentUserId else { return }
        Task { await service.submitSuggestion(userId: currentUserId, message: text) }
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

final class PlantViewModel: ObservableObject {
    @Published var pendingPlant: Plant?
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let service = FirebaseService.shared

    func createPlant(name: String, code: String, description: String, user: UserProfile) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let plant = try await service.createPlant(name: name, code: code, description: description, creator: user)
            await MainActor.run { self.pendingPlant = plant }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    func joinPlant(code: String, userId: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let plant = try await service.joinPlant(code: code, userId: userId)
            await MainActor.run { self.pendingPlant = plant }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}

final class GroupChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var text: String = ""

    private let service = FirebaseService.shared
    private var chatRef: DatabaseReference?
    private var chatHandle: DatabaseHandle?
    private var plantId: String?
    private var user: UserProfile?

    func start(plantId: String, user: UserProfile) {
        self.plantId = plantId
        self.user = user
        service.detachListener(ref: chatRef, handle: chatHandle)
        let result = service.listenToGroupChat(plantId: plantId, currentUserId: user.id) { [weak self] items in
            Task { @MainActor in
                self?.messages = items
            }
        }
        chatRef = result.0
        chatHandle = result.1
    }

    func stop() {
        service.detachListener(ref: chatRef, handle: chatHandle)
        chatRef = nil
        chatHandle = nil
        messages = []
        plantId = nil
    }

    func send() {
        guard let plantId, let user else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        service.sendGroupMessage(plantId: plantId, user: user, text: trimmed)
        text = ""
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
