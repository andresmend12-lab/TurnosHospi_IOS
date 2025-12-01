import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var notifications: NotificationsViewModel
    @EnvironmentObject private var shifts: ShiftViewModel
    @EnvironmentObject private var chats: ChatViewModel
    @EnvironmentObject private var plantVM: PlantViewModel
    @EnvironmentObject private var groupChatVM: GroupChatViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated, let profile = auth.profile {
                if let plant = auth.plant ?? plantVM.pendingPlant {
                    MainShellView(profile: profile, plant: plant)
                } else {
                    PlantSetupView(profile: profile)
                }
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: auth.userId) { userId in
            if let userId {
                notifications.beginListening(userId: userId)
                if let plantId = auth.plant?.id {
                    shifts.startListening(plantId: plantId, userId: userId)
                    if let profile = auth.profile {
                        chats.start(plantId: plantId, user: profile)
                        groupChatVM.start(plantId: plantId, user: profile)
                    }
                }
            } else {
                notifications.stop()
                shifts.stopListening()
                chats.stop()
                groupChatVM.stop()
            }
        }
        .onChange(of: auth.plant?.id) { plantId in
            guard let plantId, let userId = auth.userId else { return }
            shifts.startListening(plantId: plantId, userId: userId)
            if let profile = auth.profile {
                chats.start(plantId: plantId, user: profile)
                groupChatVM.start(plantId: plantId, user: profile)
            }
        }
        .onChange(of: plantVM.pendingPlant?.id) { _ in
            if auth.plant == nil, let pending = plantVM.pendingPlant {
                auth.plant = pending
            }
        }
        .alert(item: Binding(
            get: { auth.errorMessage.map { AlertWrapper(message: $0) } },
            set: { _ in auth.errorMessage = nil }
        )) { wrapper in
            Alert(title: Text(wrapper.message))
        }
    }
}

private struct AlertWrapper: Identifiable { let id = UUID(); let message: String }

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
            .environmentObject(NotificationsViewModel())
            .environmentObject(ShiftViewModel())
            .environmentObject(ChatViewModel())
            .environmentObject(PlantViewModel())
            .environmentObject(GroupChatViewModel())
    }
}
