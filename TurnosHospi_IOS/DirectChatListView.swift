import SwiftUI
import FirebaseDatabase
import FirebaseAuth

/// Esta vista asume que existen los siguientes tipos en el proyecto:
/// - AuthManager (EnvironmentObject)
/// - PlantManager
/// - DirectChat (Identifiable)
/// - ChatUser
struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject var plantManager = PlantManager()
    
    // Datos
    @State private var chats: [DirectChat] = []
    @State private var isLoading = true
    
    // Estados para Nuevo Chat
    @State private var showNewChatSheet = false
    @State private var selectedChatId: String? = nil
    @State private var selectedOtherUser: ChatUser? = nil
    @State private var navigateToNewChat = false
    
    // Firebase
    private let ref = Database.database().reference()
    
    // Usuario actual
    var currentUserId: String {
        authManager.user?.uid ?? ""
    }
    
    // Planta actual
    var currentPlantId: String {
        authManager.userPlantId
    }
    
    var body: some View {
        // No usamos NavigationStack aquí: heredamos el NavigationStack del padre
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
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
                    // Icono invisible para centrar el título
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // MARK: - Lista / Estados de carga
                if isLoading {
                    Spacer()
                    ProgressView("Cargando chats...")
                        .tint(.white)
                        .foregroundColor(.white)
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
                                // Navegación clásica → siempre funciona dentro de un NavigationStack
                                NavigationLink {
                                    DirectChatView(
                                        chatId: chat.id,
                                        otherUserId: chat.otherUserId,
                                        otherUserName: chat.otherUserName
                                    )
                                } label: {
                                    ChatRow(chat: chat)
                                }
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
            
            // MARK: - Botón flotante (+) para nuevo chat
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        // Cargar usuarios de la planta si no los tenemos aún
                        if plantManager.plantUsers.isEmpty && !currentPlantId.isEmpty {
                            plantManager.fetchCurrentPlant(plantId: currentPlantId)
                        }
                        showNewChatSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 30)
                    Spacer()
                }
            }
        }
        
        // MARK: - Navegación programática solo para nuevo chat
        .navigationDestination(isPresented: $navigateToNewChat) {
            if let userId = selectedOtherUser?.id,
               let userName = selectedOtherUser?.name,
               let chatId = selectedChatId {
                DirectChatView(
                    chatId: chatId,
                    otherUserId: userId,
                    otherUserName: userName
                )
            } else {
                Text("Error al abrir el chat.")
                    .foregroundColor(.white)
            }
        }
        
        // MARK: - Ciclo de vida y actualizaciones
        
        .onAppear {
            fetchChatsDirectlyFromPlant()
        }
        .onChange(of: authManager.user?.uid) { newUid in
            if let uid = newUid, !uid.isEmpty {
                fetchChatsDirectlyFromPlant()
            }
        }
        .onDisappear {
            if !currentPlantId.isEmpty {
                ref.child("plants")
                    .child(currentPlantId)
                    .child("direct_chats")
                    .removeAllObservers()
            }
        }
        .navigationBarHidden(true)
        
        // MARK: - Sheet de selección de usuario para nuevo chat
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSelectionView(
                plantManager: plantManager,
                currentUserId: currentUserId,
                onUserSelected: { user in
                    let newChatId = DirectChat.getChatId(user1: currentUserId, user2: user.id)
                    selectedChatId = newChatId
                    selectedOtherUser = user
                    showNewChatSheet = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigateToNewChat = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Lógica de carga de chats
    
    func fetchChatsDirectlyFromPlant() {
        guard !currentUserId.isEmpty, !currentPlantId.isEmpty else {
            return
        }
        
        isLoading = true
        
        let chatsRef = ref
            .child("plants")
            .child(currentPlantId)
            .child("direct_chats")
        
        chatsRef.observe(.value) { snapshot in
            var loadedChats: [DirectChat] = []
            let group = DispatchGroup()
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let chatId = child.key
                let parts = chatId.components(separatedBy: "_")
                
                // Solo chats donde participa el usuario actual
                guard parts.contains(currentUserId) else { continue }
                
                if let dict = child.value as? [String: Any] {
                    group.enter()
                    
                    // 1) lastMessage
                    var lastMsg = dict["lastMessage"] as? String ?? ""
                    
                    // 2) lastTimestamp
                    var timestamp: TimeInterval = 0
                    if let rawTs = dict["lastTimestamp"] {
                        if let t = rawTs as? TimeInterval {
                            timestamp = t
                        } else if let t = rawTs as? Double {
                            timestamp = t
                        } else if let t = rawTs as? Int {
                            timestamp = TimeInterval(t)
                        } else if let n = rawTs as? NSNumber {
                            timestamp = n.doubleValue
                        }
                    }
                    
                    // Fallback si no hay lastMessage: miramos messages
                    if lastMsg.isEmpty,
                       let messagesDict = dict["messages"] as? [String: [String: Any]] {
                        
                        let sortedMessages = messagesDict.values.compactMap { msgData -> (String, TimeInterval)? in
                            guard let text = msgData["text"] as? String else { return nil }
                            
                            let rawTs = msgData["timestamp"]
                            let time: TimeInterval
                            if let t = rawTs as? TimeInterval {
                                time = t
                            } else if let t = rawTs as? Double {
                                time = t
                            } else if let t = rawTs as? Int {
                                time = TimeInterval(t)
                            } else if let n = rawTs as? NSNumber {
                                time = n.doubleValue
                            } else {
                                return nil
                            }
                            
                            return (text, time)
                        }
                        .sorted { $0.1 < $1.1 }
                        
                        if let last = sortedMessages.last {
                            lastMsg = last.0
                            timestamp = last.1
                        }
                    }
                    
                    if lastMsg.isEmpty {
                        lastMsg = "Chat iniciado"
                    }
                    
                    // Otro participante
                    let otherId: String
                    if parts.count == 2 {
                        otherId = (parts[0] == currentUserId) ? parts[1] : parts[0]
                    } else {
                        otherId = chatId
                            .replacingOccurrences(of: currentUserId, with: "")
                            .replacingOccurrences(of: "_", with: "")
                    }
                    
                    // Datos del otro usuario
                    self.ref.child("users").child(otherId).observeSingleEvent(of: .value) { userSnap in
                        let userVal = userSnap.value as? [String: Any]
                        let firstName = userVal?["firstName"] as? String ?? "Usuario"
                        let lastName = userVal?["lastName"] as? String ?? ""
                        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                        let role = userVal?["role"] as? String ?? ""
                        let finalName = fullName.isEmpty ? "Usuario" : fullName
                        
                        let chat = DirectChat(
                            id: chatId,
                            participants: parts,
                            lastMessage: lastMsg,
                            timestamp: timestamp,
                            otherUserName: finalName,
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

// MARK: - Fila visual de cada chat

struct ChatRow: View {
    let chat: DirectChat
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                let initial = chat.otherUserName.isEmpty ? "?" : String(chat.otherUserName.prefix(1))
                Text(initial)
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
                        Text(
                            Date(timeIntervalSince1970: chat.timestamp / 1000)
                                .formatted(date: .omitted, time: .shortened)
                        )
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                }
                
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding()
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        .contentShape(Rectangle())
    }
}
