import SwiftUI
import FirebaseDatabase
import FirebaseAuth

/// Esta vista asume que existen los siguientes tipos en el proyecto:
/// - AuthManager (EnvironmentObject)
/// - PlantManager
/// - DirectChat (Identifiable)
/// - ChatUser
/// - ChatRoute (Hashable, para navegación con NavigationStack)
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
        return authManager.user?.uid ?? ""
    }
    
    // Planta actual
    var currentPlantId: String {
        return authManager.userPlantId
    }
    
    var body: some View {
        // No usamos NavigationStack aquí: heredamos el NavigationStack de la vista padre
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
                                NavigationLink(
                                    value: ChatRoute(
                                        chatId: chat.id,
                                        otherUserId: chat.otherUserId,
                                        otherUserName: chat.otherUserName
                                    )
                                ) {
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
        
        // MARK: - Destinos de navegación
        
        // 1. Navegación desde la lista de chats (via ChatRoute)
        .navigationDestination(for: ChatRoute.self) { route in
            DirectChatView(
                chatId: route.chatId,
                otherUserId: route.otherUserId,
                otherUserName: route.otherUserName
            )
        }
        
        // 2. Navegación programática para nuevo chat
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
                // En caso de fallo de estado, evitamos crashear
                Text("Error al abrir el chat.")
                    .foregroundColor(.white)
            }
        }
        
        // MARK: - Ciclo de vida y actualizaciones
        
        .onAppear {
            fetchChatsDirectlyFromPlant()
        }
        // Si cambia el usuario (por ejemplo al loguearse), recargamos
        .onChange(of: authManager.user?.uid) { newUid in
            if let uid = newUid, !uid.isEmpty {
                fetchChatsDirectlyFromPlant()
            }
        }
        .onDisappear {
            // Al salir de la vista, liberamos los listeners de Firebase
            if !currentPlantId.isEmpty {
                ref.child("plants")
                    .child(currentPlantId)
                    .child("direct_chats")
                    .removeAllObservers()
            }
        }
        .navigationBarHidden(true) // Usamos nuestro header custom
        
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
                    
                    // Pequeño retardo para no pelearse con la animación del sheet
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
        // Si aún no tenemos usuario o planta, esperamos
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
                
                // Solo nos interesan los chats donde participa el usuario actual
                guard chatId.contains(currentUserId) else { continue }
                
                if let dict = child.value as? [String: Any] {
                    group.enter()
                    
                    var lastMsg = dict["lastMessage"] as? String ?? ""
                    var timestamp = dict["lastTimestamp"] as? TimeInterval ?? 0
                    
                    // Fallback si no hay lastMessage: miramos el nodo messages
                    if lastMsg.isEmpty,
                       let messagesDict = dict["messages"] as? [String: [String: Any]] {
                        
                        let sortedMessages = messagesDict.values.compactMap { msgData -> (String, TimeInterval)? in
                            guard let text = msgData["text"] as? String,
                                  let time = msgData["timestamp"] as? TimeInterval else { return nil }
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
                    
                    // Obtenemos el otro participante a partir del chatId
                    let parts = chatId.components(separatedBy: "_")
                    let otherId: String
                    if parts.count == 2 {
                        otherId = (parts[0] == currentUserId) ? parts[1] : parts[0]
                    } else {
                        otherId = chatId
                            .replacingOccurrences(of: currentUserId, with: "")
                            .replacingOccurrences(of: "_", with: "")
                    }
                    
                    // Cargamos datos del otro usuario
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
                // Ordenamos por timestamp descendente (último mensaje primero)
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
            // Avatar circular con inicial
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
                        // IMPORTANTE:
                        // Si guardas el timestamp en milisegundos, divide entre 1000.
                        // Si lo guardas en segundos, elimina la división.
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
        .contentShape(Rectangle()) // Toda la fila es pulsable
    }
}
