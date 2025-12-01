import SwiftUI

@main
struct TurnoshospiApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var notifications = NotificationsViewModel()
    @StateObject private var shiftViewModel = ShiftViewModel(members: StaffMember.demoMembers)
    @StateObject private var chatViewModel = ChatViewModel(members: StaffMember.demoMembers)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(notifications)
                .environmentObject(shiftViewModel)
                .environmentObject(chatViewModel)
        }
    }
}
