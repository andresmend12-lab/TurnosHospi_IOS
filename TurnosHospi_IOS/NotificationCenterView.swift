import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var notificationManager: NotificationCenterManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.11, green: 0.13, blue: 0.22),
                        Color(red: 0.05, green: 0.07, blue: 0.12),
                        Color(red: 0.08, green: 0.06, blue: 0.15)
                    ]),
                    center: .center
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        headerStats
                        
                        if notificationManager.unreadCount == 0 {
                            EmptyStateView()
                                .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(notificationManager.notifications) { item in
                                    NotificationRow(item: item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Centro de notificaciones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Vaciar") {
                        notificationManager.clearAll()
                    }
                    .disabled(notificationManager.unreadCount == 0)
                }
            }
            .toolbarBackground(Color.black.opacity(0.3), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private var headerStats: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tus avisos")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Text(notificationManager.unreadCount == 0 ? "Nada pendiente" : "\(notificationManager.unreadCount) pendientes")
                    .font(.title.bold())
                    .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct NotificationRow: View {
    let item: NotificationItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.message)
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))
            Text("No tienes notificaciones")
                .font(.title3.bold())
                .foregroundColor(.white.opacity(0.8))
            Text("Cuando ocurra algo importante lo verás aquí.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
