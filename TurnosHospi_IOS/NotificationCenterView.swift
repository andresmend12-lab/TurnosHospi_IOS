import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var notificationManager: NotificationCenterManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.15),
                        Color(red: 0.03, green: 0.03, blue: 0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                List {
                    if notificationManager.unreadCount == 0 {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.6))
                            Text("No tienes notificaciones")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.headline)
                            Text("Cuando ocurra algo importante lo verás aquí.")
                                .foregroundColor(.white.opacity(0.4))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(notificationManager.notifications) { item in
                            NotificationRow(item: item)
                                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: notificationManager.removeNotifications)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal)
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
    }
}
