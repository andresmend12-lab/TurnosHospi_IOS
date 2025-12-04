import SwiftUI

struct MainShellView: View {
    let profile: UserProfile
    let plant: Plant
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var shiftVM: ShiftViewModel
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var notificationsVM: NotificationsViewModel

    var body: some View {
        TabView {
            ShiftDashboardView(profile: profile)
                .tabItem { Label("Mis turnos", systemImage: "calendar") }
            MarketplaceView(plant: plant)
                .tabItem { Label("Cambios", systemImage: "arrow.2.squarepath") }
            ChatListView()
                .tabItem { Label("Mensajes", systemImage: "bubble.left.and.bubble.right") }
            GroupChatView()
                .tabItem { Label("Planta", systemImage: "person.3.sequence") }
            StatsView()
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.xaxis") }
            NotificationsView()
                .tabItem { Label("Alertas", systemImage: "bell") }
            ProfileView(profile: profile, plant: plant)
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .environmentObject(auth)
        .environmentObject(shiftVM)
        .environmentObject(chatVM)
        .environmentObject(notificationsVM)
    }
}
