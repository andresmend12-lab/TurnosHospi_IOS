import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var notificationsVM: NotificationsViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(notificationsVM.notifications) { notification in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: notification.kind))
                            .foregroundStyle(color(for: notification.kind))
                            .padding(8)
                            .background(color(for: notification.kind).opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title).font(.headline)
                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(notification.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !notification.isRead {
                            Circle().fill(Color.blue).frame(width: 10, height: 10)
                        }
                    }
                    .swipeActions {
                        Button("Leído") {
                            notificationsVM.markAsRead(notification)
                        }.tint(.blue)
                        Button(role: .destructive) {
                            notificationsVM.delete(notification)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Alertas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !notificationsVM.notifications.isEmpty {
                        Button("Limpiar") { notificationsVM.deleteAll() }
                    }
                }
            }
        }
    }

    private func icon(for kind: NotificationItem.Kind) -> String {
        switch kind {
        case .chat: return "message.fill"
        case .shift: return "calendar.badge.exclamationmark"
        case .system: return "bell.fill"
        case .generic: return "bell"
        }
    }

    private func color(for kind: NotificationItem.Kind) -> Color {
        switch kind {
        case .chat: return .blue
        case .shift: return .orange
        case .system: return .green
        case .generic: return .gray
        }
    }
}
