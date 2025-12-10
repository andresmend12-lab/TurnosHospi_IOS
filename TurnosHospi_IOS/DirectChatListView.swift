import SwiftUI
import FirebaseDatabase

struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Estados de datos
    @State private var conversations: [ChatConversation] = []
    @State private var isLoading = true
    
    // Estados para nuevo chat
    @State private var showNewChatSheet = false
    @State private var availableUsers: [ChatUser] = []
    
    // Estado para navegación programática (Nuevo Chat)
    @State private var selectedNewUser: ChatUser?
    
    // Cache de usuarios
    @State private var userCache: [String: ChatUser] = [:]
    
    private var ref: DatabaseReference {
        return Database.database().reference()
    }
    
    var body: some View {
        // NO usamos NavigationStack aquí porque ya venimos de uno en MainMenuView
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
                                // Navegación invisible al pulsar la fila
                                NavigationLink(value: conversation.otherUser) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
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
                    Button(action: {
                        loadAvailableUsers()
                        showNewChatSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(.black)
                            .padding(16)
                            .background(Color(red: 0.33, green: 0.78, blue: 0.93)) // Cyan
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        
        // --- DESTINOS DE NAVEGACIÓN ---
        // Se registran en el stack del padre (MainMenuView)
        
        // 1. Al pulsar en la lista
        .navigationDestination(for: ChatUser.self) { user in
            DirectChatView(
                targetUser: user,
                currentUserId: authManager.user?.uid ?? "",
                plantId: authManager.userPlantId
            )
        }
        
        // 2. Al crear nuevo chat
        .navigationDestination(isPresented: Binding<Bool>(
            get: { selectedNewUser != nil },
            set: { if !$0 { selectedNewUser = nil } }
        )) {
            if let user = selectedNewUser {
                DirectChatView(
                    targetUser: user,
                    currentUserId: authManager.user?.uid ?? "",
                    plantId: authManager.userPlantId
                )
            }
        }
        
        .sheet(isPresented: $showNewChatSheet) {
            NewChatUserSelectionView(users: availableUsers) { user in
                showNewChatSheet = false
                // Delay para evitar conflictos de animación
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    selectedNewUser = user
                }
            }
        }
        .onAppear {
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
            Spacer()
        }
    }
    
    // MARK: - LÓGICA DE DATOS SEGURA (FIX CRASH)
    
    func observeConversations() {
        guard let myId = authManager.user?.uid, !myId.isEmpty else { return }
        
        // Usamos Value Listener para refrescar la lista completa de forma segura
        ref.child("user_direct_chats").child(myId).observe(.value) { snapshot in
            
            // 1. Extraer datos crudos en segundo plano (Raw Data)
            var rawData: [(chatId: String, otherId: String, msg: String, time: TimeInterval, unread: Int)] = []
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let otherUserId = dict["otherUserId"] as? String ?? ""
                    if !otherUserId.isEmpty {
                        let lastMsg = dict["lastMessage"] as? String ?? ""
                        let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                        let unread = dict["unreadCount"] as? Int ?? 0
                        rawData.append((child.key, otherUserId, lastMsg, timestamp, unread))
                    }
                }
            }
            
            // 2. Procesar en Hilo Principal para acceder a @State (userCache)
            DispatchQueue.main.async {
                var newConversations: [ChatConversation] = []
                var missingUsers: Set<String> = []
                
                for item in rawData {
                    if let user = self.userCache[item.otherId] {
                        // Usuario ya en caché
                        let conv = ChatConversation(
                            otherUser: user,
                            lastMessage: item.msg,
                            timestamp: item.time,
                            unreadCount: item.unread,
                            chatId: item.chatId
                        )
                        newConversations.append(conv)
                    } else {
                        // Usuario falta, usamos placeholder y marcamos para cargar
                        let placeholder = ChatUser(id: item.otherId, name: "Cargando...", role: "", email: "")
                        let conv = ChatConversation(
                            otherUser: placeholder,
                            lastMessage: item.msg,
                            timestamp: item.time,
                            unreadCount: item.unread,
                            chatId: item.chatId
                        )
                        newConversations.append(conv)
                        missingUsers.insert(item.otherId)
                    }
                }
                
                // Actualizamos la UI
                self.conversations = newConversations.sorted(by: { $0.timestamp > $1.timestamp })
                self.isLoading = false
                
                // 3. Cargar usuarios faltantes
                for uid in missingUsers {
                    self.fetchUserDetails(uid: uid)
                }
            }
        }
    }
    
    func fetchUserDetails(uid: String) {
        let plantId = authManager.userPlantId
        
        // Buscar en la planta
        ref.child("plants").child(plantId).child("userPlants").child(uid).observeSingleEvent(of: .value) { snap in
            var userFound: ChatUser?
            
            if let dict = snap.value as? [String: Any] {
                let name = dict["staffName"] as? String ?? "Usuario"
                let role = dict["staffRole"] as? String ?? "Personal"
                userFound = ChatUser(id: uid, name: name, role: role, email: "")
            } else {
                // Fallback global
                self.ref.child("users").child(uid).observeSingleEvent(of: .value) { userSnap in
                    let dict = userSnap.value as? [String: Any] ?? [:]
                    let name = dict["firstName"] as? String ?? "Usuario"
                    let role = dict["role"] as? String ?? ""
                    let finalUser = ChatUser(id: uid, name: name, role: role, email: "")
                    
                    // Actualizar caché en Main Thread
                    DispatchQueue.main.async {
                        self.userCache[uid] = finalUser
                        // Forzar refresco ligero de la lista
                        self.refreshListWithCache()
                    }
                }
                return
            }
            
            if let user = userFound {
                DispatchQueue.main.async {
                    self.userCache[uid] = user
                    self.refreshListWithCache()
                }
            }
        }
    }
    
    // Actualiza la lista actual con los nombres nuevos sin recargar de Firebase
    func refreshListWithCache() {
        var updatedList = self.conversations
        for (index, conv) in updatedList.enumerated() {
            if let cached = self.userCache[conv.otherUser.id], conv.otherUser.name == "Cargando..." {
                updatedList[index] = ChatConversation(
                    otherUser: cached,
                    lastMessage: conv.lastMessage,
                    timestamp: conv.timestamp,
                    unreadCount: conv.unreadCount,
                    chatId: conv.chatId
                )
            }
        }
        self.conversations = updatedList
    }
    
    func loadAvailableUsers() {
        let plantId = authManager.userPlantId
        guard !plantId.isEmpty else { return }
        
        ref.child("plants").child(plantId).child("userPlants").observeSingleEvent(of: .value) { snapshot in
            var loaded: [ChatUser] = []
            let myId = authManager.user?.uid ?? ""
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if child.key != myId, let dict = child.value as? [String: Any] {
                    let name = dict["staffName"] as? String ?? "Compañero"
                    let role = dict["staffRole"] as? String ?? "Personal"
                    loaded.append(ChatUser(id: child.key, name: name, role: role, email: ""))
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

// Subvistas
struct ConversationRow: View {
    let conversation: ChatConversation
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(Color(hex: "A855F7")).frame(width: 50, height: 50)
                Text(String(conversation.otherUser.name.prefix(1)).uppercased())
                    .font(.headline).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser.name).font(.headline).foregroundColor(.white)
                    Spacer()
                    Text(conversation.timeString).font(.caption2).foregroundColor(.gray)
                }
                HStack {
                    Text(conversation.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2).bold().foregroundColor(.white)
                            .padding(6).background(Color.red).clipShape(Circle())
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NewChatUserSelectionView: View {
    let users: [ChatUser]
    let onSelect: (ChatUser) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                if users.isEmpty {
                    Text("No se encontraron usuarios").foregroundColor(.gray)
                } else {
                    List(users) { user in
                        Button(action: { onSelect(user) }) {
                            HStack {
                                ZStack {
                                    Circle().fill(Color(hex: "54C7EC")).frame(width: 40, height: 40)
                                    Text(String(user.name.prefix(1)).uppercased()).bold().foregroundColor(.black)
                                }
                                VStack(alignment: .leading) {
                                    Text(user.name).foregroundColor(.white).bold()
                                    Text(user.role).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Nuevo Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }
}
