import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var notificationManager: NotificationCenterManager
    
    // Color de fondo consistente con DirectChatListView y otros
    let backgroundColor = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    var body: some View {
        ZStack {
            // 1. Fondo Oscuro Global
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Header Personalizado (Estilo consistente)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Notificaciones")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Botón de Vaciar (Papelera)
                    Button(action: {
                        withAnimation {
                            notificationManager.clearAll()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(notificationManager.notifications.isEmpty ? .gray : .red)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .disabled(notificationManager.notifications.isEmpty)
                }
                .padding()
                .background(Color.black.opacity(0.3)) // Fondo del header
                
                // 3. Contenido Scrollable
                ScrollView {
                    VStack(spacing: 18) {
                        // Resumen superior
                        headerStats
                        
                        if notificationManager.notifications.isEmpty {
                            EmptyStateView()
                                .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(notificationManager.notifications) { item in
                                    Button {
                                        if !item.read {
                                            notificationManager.markAsRead(item)
                                        }
                                        // Aquí podrías añadir lógica de navegación si item.targetScreen existe
                                    } label: {
                                        NotificationRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                notificationManager.delete(item)
                                            }
                                        } label: {
                                            Label("Eliminar", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // Tarjeta de estadísticas (Estilo ajustado)
    private var headerStats: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tus avisos")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Text(notificationManager.unreadCount == 0 ? "Todo al día" : "\(notificationManager.unreadCount) pendientes")
                    .font(.title2.bold())
                    // Gradiente de texto consistente con Login/Menu
                    .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 50)
                    .opacity(0.2)
                
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Fila de Notificación (Estilo Glassmorphism Oscuro)
struct NotificationRow: View {
    let item: NotificationItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Indicador de leído/no leído
            Circle()
                .fill(item.read ? Color.gray.opacity(0.3) : Color(red: 0.33, green: 0.78, blue: 0.93)) // Cyan Hospi
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(item.read ? .white.opacity(0.7) : .white)
                    Spacer()
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(item.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05)) // Fondo sutil
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1) // Borde fino
        )
    }
}

// Vista Vacía (Estilo minimalista oscuro)
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.2))
            
            VStack(spacing: 8) {
                Text("Sin notificaciones")
                    .font(.title3.bold())
                    .foregroundColor(.white.opacity(0.8))
                Text("Te avisaremos cuando ocurra algo importante en tu planta.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}
