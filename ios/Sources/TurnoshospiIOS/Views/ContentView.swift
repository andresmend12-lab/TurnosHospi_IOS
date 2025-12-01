import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated, let profile = auth.profile, let plant = auth.plant {
                MainShellView(profile: profile, plant: plant)
            } else {
                LoginView()
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
            .environmentObject(ShiftViewModel(members: StaffMember.demoMembers))
            .environmentObject(ChatViewModel(members: StaffMember.demoMembers))
    }
}
