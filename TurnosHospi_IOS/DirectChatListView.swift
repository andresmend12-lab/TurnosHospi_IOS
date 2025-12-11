import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    
    // Datos
    @State private var chats: [DirectChat] = []
    @State private var isLoading = true
    
    // Estados para Nuevo Chat
    @State private var showNewChatSheet = false
    @State private var navigateToNewChat = false
    @State private var tempSelectedChat: ChatRoute? // Variable temporal
    
    private let ref = Database.database().reference()
    
    var currentUserId: String { authManager.user?.uid ?? "" }
    var currentPlantId: String { authManager.userPlantId }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            // --- ENLACE INVISIBLE PARA NAVEGACIÓN PROGRAMÁTICA (NUEVO CHAT) ---
            // Usamos esto para evitar el congelamiento al cerrar el sheet.
            // Se activa cuando navigateToNewChat es true.
            NavigationLink(
                destination: destinationView(),
                isActive: $navigateToNewChat
            ) {
                EmptyView()
            }
            .hidden()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Mensajes Directos")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // MARK: - Lista
                if isLoading {
                    Spacer()
                    ProgressView("Cargando chats...").tint(.white).foregroundColor(.white)
                    Spacer()
                } else if chats.isEmpty {
                    VStack(spacing: 15) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No tienes conversaciones activas.")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(chats) { chat in
                                // MARK: - NAVEGACIÓN EXPLÍCITA (LISTA)
                                // Usamos destination directo para no depender del MainMenu
                                NavigationLink(destination: DirectChatView(
                                    chatId: chat.id,
                                    otherUserId: chat.otherUserId,
                                    otherUserName: chat.otherUserName
                                )) {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(.plain)
                                
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
            
            // Botón flotante (+)
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        if plantManager.plantUsers.isEmpty && !currentPlantId.isEmpty {
                            plantManager.fetchCurrentPlant(plantId: currentPlantId)
                        }
                        showNewChatSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color(red: 0.33, green: 0.78, blue: 0.93)) // Cyan Hospi
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 30)
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { fetchChatsDirectlyFromPlant() }
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSelectionView(
                plantManager: plantManager,
                currentUserId: currentUserId,
                onUserSelected: { user in
                    let newChatId = DirectChat.getChatId(user1: currentUserId, user2: user.id)
                    tempSelectedChat = ChatRoute(chatId: newChatId, otherUserId: user.id, otherUserName: user.name)
                    
                    showNewChatSheet = false
                    
                    // Aumentamos el retardo a 0.5s para evitar el congelamiento de UI
                    // mientras se cierra el modal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigateToNewChat = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    // Helper para construir la vista de destino de forma segura
    @ViewBuilder
    func destinationView() -> some View {
        if let route = tempSelectedChat {
            DirectChatView(
                chatId: route.chatId,
                otherUserId: route.otherUserId,
                otherUserName: route.otherUserName
            )
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Lógica Firebase
    func fetchChatsDirectlyFromPlant() {
        guard !currentUserId.isEmpty, !currentPlantId.isEmpty else { return }
        isLoading = true
        
        let chatsRef = ref.child("plants").child(currentPlantId).child("direct_chats")
        
        chatsRef.observe(.value) { snapshot in
            var loadedChats: [DirectChat] = []
            let group = DispatchGroup()
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let chatId = child.key
                if chatId.contains(currentUserId) {
                    
                    let parts = chatId.components(separatedBy: "_")
                    let otherId = (parts.first == currentUserId) ? parts.last ?? "" : parts.first ?? ""
                    if otherId.isEmpty { continue }
                    
                    group.enter()
                    
                    let messagesSnap = child.childSnapshot(forPath: "messages")
                    var lastMsgText = "Chat iniciado"
                    var lastTimestamp: TimeInterval = 0
                    
                    if let lastMsgSnap = messagesSnap.children.allObjects.last as? DataSnapshot,
                       let msgDict = lastMsgSnap.value as? [String: Any] {
                        lastMsgText = msgDict["text"] as? String ?? "Imagen"
                        if let ts = msgDict["timestamp"] as? TimeInterval { lastTimestamp = ts }
                        else if let ts = msgDict["timestamp"] as? Int { lastTimestamp = TimeInterval(ts) }
                    }
                    
                    ref.child("users").child(otherId).observeSingleEvent(of: .value) { userSnap in
                        let userVal = userSnap.value as? [String: Any]
                        let fName = userVal?["firstName"] as? String ?? ""
                        let lName = userVal?["lastName"] as? String ?? ""
                        let email = userVal?["email"] as? String ?? "Usuario"
                        
                        var displayName = "\(fName) \(lName)".trimmingCharacters(in: .whitespaces)
                        if displayName.isEmpty { displayName = email }
                        
                        let role = userVal?["role"] as? String ?? "Personal"
                        
                        let chat = DirectChat(
                            id: chatId,
                            lastMessage: lastMsgText,
                            timestamp: lastTimestamp,
                            otherUserName: displayName,
                            otherUserRole: role,
                            otherUserId: otherId
                        )
                        loadedChats.append(chat)
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.chats = loadedChats.sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
            }
        }
    }
}

struct ChatRow: View {
    let chat: DirectChat
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.8))
                    .frame(width: 50, height: 50)
                
                Text(chat.otherUserName.prefix(1).uppercased())
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.otherUserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if chat.timestamp > 0 {
                        Text(Date(timeIntervalSince1970: chat.timestamp / 1000), style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
