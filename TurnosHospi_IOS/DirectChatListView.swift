import SwiftUI
import FirebaseDatabase

struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Lista de conversaciones
    @State private var conversations: [ChatConversation] = []
    @State private var isLoading = true
    
    // Para iniciar nuevo chat
    @State private var showNewChatSheet = false
    @State private var availableUsers: [ChatUser] = []
    
    // Cache de usuarios para evitar descargas repetidas
    @State private var userCache: [String: ChatUser] = [:]
    
    private var ref: DatabaseReference {
        return Database.database().reference()
    }
    
    var body: some View {
        ZStack {
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
                    Text("Mis Mensajes")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // --- LISTA ---
                if isLoading {
                    Spacer()
                    ProgressView("Cargando...").tint(.white)
                    Spacer()
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            ZStack {
                                NavigationLink(value: conversation.otherUser) {
                                    EmptyView()
                                }.opacity(0)
                                
                                ConversationRow(conversation: conversation)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteChat(chatId: conversation.chatId)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            
            // --- BOTÓN FLOTANTE ---
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showNewChatSheet = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: ChatUser.self) { user in
            if let uid = authManager.user?.uid, !uid.isEmpty {
                DirectChatView(
                    targetUser: user,
                    currentUserId: uid,
                    plantId: authManager.userPlantId
                )
            }
        }
        .sheet(isPresented: $showNewChatSheet) {
            NewChatUserSelectionView(users: availableUsers, onSelect: { user in
                showNewChatSheet = false
            })
        }
        .onAppear {
            // Cargar datos en paralelo
            loadPlantStaff()
            observeConversations()
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No tienes mensajes recientes")
                .foregroundColor(.gray)
            Button("Iniciar nuevo chat") { showNewChatSheet = true }
                .padding(.top, 10)
            Spacer()
        }
    }
    
    // MARK: - LÓGICA DE CARGA PROGRESIVA
    
    func observeConversations() {
        guard let myId = authManager.user?.uid, !myId.isEmpty else {
            isLoading = false
            return
        }
        
        // Escuchamos 'user_direct_chats' en tiempo real
        ref.child("user_direct_chats").child(myId).observe(.value) { snapshot in
            var newConversations: [ChatConversation] = []
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let otherUserId = dict["otherUserId"] as? String ?? ""
                    if otherUserId.isEmpty { continue }
                    
                    let lastMsg = dict["lastMessage"] as? String ?? ""
                    let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                    let unread = dict["unreadCount"] as? Int ?? 0
                    let chatId = child.key
                    
                    // 1. Buscamos usuario en caché (Rápido)
                    if let cachedUser = userCache[otherUserId] {
                        let conv = ChatConversation(
                            otherUser: cachedUser,
                            lastMessage: lastMsg,
                            timestamp: timestamp,
                            unreadCount: unread,
                            chatId: chatId
                        )
                        newConversations.append(conv)
                    } else {
                        // 2. Si no está, usamos placeholder y cargamos en segundo plano
                        let placeholderUser = ChatUser(
                            id: otherUserId,
                            name: "Cargando...",
                            role: "",
                            email: ""
                        )
                        let conv = ChatConversation(
                            otherUser: placeholderUser,
                            lastMessage: lastMsg,
                            timestamp: timestamp,
                            unreadCount: unread,
                            chatId: chatId
                        )
                        newConversations.append(conv)
                        
                        // Disparamos carga individual sin bloquear
                        fetchUserDetails(uid: otherUserId)
                    }
                }
            }
            
            // Actualizamos la UI inmediatamente
            DispatchQueue.main.async {
                self.conversations = newConversations.sorted(by: { $0.timestamp > $1.timestamp })
                self.isLoading = false
            }
        }
    }
    
    // Carga individual de usuarios faltantes (Asíncrona)
    func fetchUserDetails(uid: String) {
        // Primero intentamos buscar en userPlants (más rápido)
        ref.child("plants").child(authManager.userPlantId).child("userPlants").child(uid).observeSingleEvent(of: .value) { snap in
            if let dict = snap.value as? [String: Any] {
                let name = dict["staffName"] as? String ?? "Usuario"
                let role = dict["staffRole"] as? String ?? "Personal"
                let user = ChatUser(id: uid, name: name, role: role, email: "")
                updateCacheAndRefresh(user: user)
            } else {
                // Si no está en planta, buscamos en users global
                ref.child("users").child(uid).observeSingleEvent(of: .value) { userSnap in
                    if let uDict = userSnap.value as? [String: Any] {
                        let name = uDict["firstName"] as? String ?? "Usuario"
                        let role = uDict["role"] as? String ?? ""
                        let user = ChatUser(id: uid, name: name, role: role, email: "")
                        updateCacheAndRefresh(user: user)
                    }
                }
            }
        }
    }
    
    func updateCacheAndRefresh(user: ChatUser) {
        DispatchQueue.main.async {
            self.userCache[user.id] = user
            // Actualizamos la lista de conversaciones reemplazando el placeholder
            if let index = self.conversations.firstIndex(where: { $0.otherUser.id == user.id }) {
                let oldConv = self.conversations[index]
                let newConv = ChatConversation(
                    otherUser: user, // Ya con nombre real
                    lastMessage: oldConv.lastMessage,
                    timestamp: oldConv.timestamp,
                    unreadCount: oldConv.unreadCount,
                    chatId: oldConv.chatId
                )
                self.conversations[index] = newConv
            }
        }
    }
    
    func loadPlantStaff() {
        let plantId = authManager.userPlantId
        guard !plantId.isEmpty else { return }
        
        ref.child("plants").child(plantId).child("userPlants").observeSingleEvent(of: .value) { snapshot in
            var loaded: [ChatUser] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if child.key != authManager.user?.uid, let dict = child.value as? [String: Any] {
                    let name = dict["staffName"] as? String ?? "Compañero"
                    let role = dict["staffRole"] as? String ?? "Personal"
                    let user = ChatUser(id: child.key, name: name, role: role, email: "")
                    loaded.append(user)
                    // Pre-llenamos caché
                    self.userCache[child.key] = user
                }
            }
            DispatchQueue.main.async {
                self.availableUsers = loaded.sorted(by: { $0.name < $1.name })
            }
        }
    }
    
    func deleteChat(chatId: String) {
        guard let myId = authManager.user?.uid else { return }
        ref.child("user_direct_chats").child(myId).child(chatId).removeValue()
    }
}

// --- SUBVISTAS (Igual que antes) ---

struct ConversationRow: View {
    let conversation: ChatConversation
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)).frame(width: 50, height: 50)
                Text(String(conversation.otherUser.name.prefix(1)).uppercased()).font(.headline).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser.name).font(.headline).foregroundColor(.white)
                    Spacer()
                    Text(conversation.timeString).font(.caption2).foregroundColor(conversation.unreadCount > 0 ? .green : .gray)
                }
                HStack {
                    Text(conversation.lastMessage).font(.subheadline)
                        .foregroundColor(conversation.unreadCount > 0 ? .white : .gray)
                        .fontWeight(conversation.unreadCount > 0 ? .bold : .regular)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)").font(.caption2).bold().foregroundColor(.black).padding(6).background(Color.green).clipShape(Circle())
                    }
                }
            }
        }.padding(10).background(Color.white.opacity(0.05)).cornerRadius(12)
    }
}

struct NewChatUserSelectionView: View {
    let users: [ChatUser]
    let onSelect: (ChatUser) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    var filtered: [ChatUser] {
        if searchText.isEmpty { return users }
        return users.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
                List(filtered) { user in
                    Button(action: { onSelect(user) }) {
                        HStack {
                            Text(user.name).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Buscar compañero")
                .navigationTitle("Nuevo Chat")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                }
            }
        }
    }
}
