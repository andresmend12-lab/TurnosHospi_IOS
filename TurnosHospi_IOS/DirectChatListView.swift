import SwiftUI
import FirebaseDatabase

struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Gestor de planta para obtener nombres y roles
    @StateObject var plantManager = PlantManager()
    
    // --- ESTADOS ---
    @State private var activeChatPartners: [ChatUser] = [] // Historial de chats
    @State private var isLoading = true
    
    // Estados para navegación
    @State private var showNewChatSheet = false
    @State private var selectedUserForNavigation: ChatUser? // Usuario elegido en el modal
    @State private var navigateToNewChat = false // Trigger para activar navegación
    
    private let ref = Database.database().reference()
    
    var currentUserId: String {
        return authManager.user?.uid ?? ""
    }
    
    var body: some View {
        ZStack {
            // Fondo
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Chats Directos")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // --- LISTA DE HISTORIAL ---
                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if activeChatPartners.isEmpty {
                    // Estado Vacío
                    VStack(spacing: 15) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No tienes chats recientes")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Pulsa el botón + para iniciar uno")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Lista de chats abiertos
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(activeChatPartners) { user in
                                NavigationLink(destination: DirectChatView(
                                    targetUser: user,
                                    currentUserId: currentUserId,
                                    plantId: authManager.userPlantId
                                )) {
                                    ChatHistoryRow(user: user)
                                }
                                .buttonStyle(.plain) // Evita el efecto de selección azul por defecto
                            }
                        }
                        .padding()
                    }
                }
            }
            
            // --- BOTÓN FLOTANTE (+) ---
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showNewChatSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(18)
                            .background(Color(red: 0.2, green: 0.4, blue: 1.0)) // Electric Blue
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 4)
                    }
                    .padding(.trailing, 25)
                    .padding(.bottom, 30)
                }
            }
        }
        // --- NAVEGACIÓN PROGRAMÁTICA (Desde el botón +) ---
        .navigationDestination(isPresented: $navigateToNewChat) {
            if let user = selectedUserForNavigation {
                DirectChatView(
                    targetUser: user,
                    currentUserId: currentUserId,
                    plantId: authManager.userPlantId
                )
            }
        }
        // --- MODAL NUEVO CHAT ---
        .sheet(isPresented: $showNewChatSheet) {
            NewChatUserListView(
                plantManager: plantManager,
                currentUserId: currentUserId,
                onSelectUser: { user in
                    // 1. Cerrar el modal
                    showNewChatSheet = false
                    // 2. Preparar y ejecutar navegación con un pequeño retraso para suavidad
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.selectedUserForNavigation = user
                        self.navigateToNewChat = true
                    }
                }
            )
        }
        .onAppear {
            if !authManager.userPlantId.isEmpty {
                // Cargar datos de planta si no están listos
                plantManager.fetchCurrentPlant(plantId: authManager.userPlantId)
                fetchChatHistory()
            }
        }
    }
    
    // --- LÓGICA DE HISTORIAL ---
    func fetchChatHistory() {
        isLoading = true
        
        ref.child("direct_chats").observeSingleEvent(of: .value) { snapshot in
            var partnerIds = Set<String>()
            
            // 1. Buscar claves que contengan mi UID (formato: uid1_uid2)
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let chatKey = child.key
                if chatKey.contains(currentUserId) {
                    let parts = chatKey.components(separatedBy: "_")
                    if parts.count == 2 {
                        let otherId = (parts[0] == currentUserId) ? parts[1] : parts[0]
                        partnerIds.insert(otherId)
                    }
                }
            }
            
            // 2. Esperar a que PlantManager tenga los usuarios cargados para resolver nombres
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Filtramos de la lista completa de usuarios aquellos con los que tenemos chat
                let historyUsers = self.plantManager.plantUsers.filter { partnerIds.contains($0.id) }
                self.activeChatPartners = historyUsers
                self.isLoading = false
            }
        }
    }
}

// MARK: - Componente Fila de Historial
struct ChatHistoryRow: View {
    let user: ChatUser
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar con inicial
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
                    .frame(width: 55, height: 55)
                
                Text(String(user.name.prefix(1)).uppercased())
                    .font(.title3.bold())
                    .foregroundColor(Color(red: 0.33, green: 0.8, blue: 0.95))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text(user.role)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Vista Modal: Selección de Usuario para Nuevo Chat
struct NewChatUserListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var plantManager: PlantManager
    var currentUserId: String
    var onSelectUser: (ChatUser) -> Void
    
    // Lista filtrada: todos menos yo
    var availableUsers: [ChatUser] {
        return plantManager.plantUsers.filter { $0.id != currentUserId }
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header Modal
                HStack {
                    Text("Nuevo Chat")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                if availableUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.slash.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No se encontró personal disponible.")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(availableUsers) { user in
                        Button(action: {
                            onSelectUser(user)
                        }) {
                            HStack(spacing: 15) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.blue)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(user.role)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
}
