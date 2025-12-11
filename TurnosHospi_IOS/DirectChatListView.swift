import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct DirectChatListView: View {
    @Binding var pendingRoute: ChatRoute?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    init(pendingRoute: Binding<ChatRoute?> = .constant(nil)) {
        _pendingRoute = pendingRoute
    }
    
    // Datos
    @State private var chats: [DirectChat] = []
    @State private var isLoading = true
    
    // Estados para Nuevo Chat
    @State private var showNewChatSheet = false
    @State private var activeChatRoute: ChatRoute?
    
    @State private var userChatsRef: DatabaseReference?
    @State private var chatsObserverHandle: DatabaseHandle?
    
    private let ref = Database.database().reference()
    
    var currentUserId: String { authManager.user?.uid ?? "" }
    var currentPlantId: String { authManager.userPlantId }
    
    var body: some View {
        NavigationStack {
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
                                    Button {
                                    activeChatRoute = ChatRoute(
                                            chatId: chat.id,
                                            otherUserId: chat.otherUserId,
                                            otherUserName: chat.otherUserName
                                        )
                                    } label: {
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
                                .background(Color(red: 0.33, green: 0.78, blue: 0.93))
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
            .onAppear {
                attachChatsListenerIfNeeded()
                consumePendingRoute()
            }
            .onDisappear { detachChatsListener() }
            .onChange(of: pendingRoute) { _ in
                consumePendingRoute()
            }
            .sheet(isPresented: $showNewChatSheet) {
                NewChatSelectionView(
                    plantManager: plantManager,
                    currentUserId: currentUserId,
                    onUserSelected: { user in
                        let newChatId = DirectChat.getChatId(user1: currentUserId, user2: user.id)
                        let route = ChatRoute(chatId: newChatId, otherUserId: user.id, otherUserName: user.name)
                        
                        showNewChatSheet = false
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeChatRoute = route
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(item: $activeChatRoute) { route in
                ChatDestination(route: route)
            }
        }
    }
    
    // MARK: - Lógica Firebase
    private func attachChatsListenerIfNeeded() {
        guard chatsObserverHandle == nil, !currentUserId.isEmpty else { return }
        isLoading = true
        
        let userRef = ref.child("user_direct_chats").child(currentUserId)
        userChatsRef = userRef
        
        chatsObserverHandle = userRef.observe(.value) { snapshot in
            var pendingChats: [DirectChat] = []
            let group = DispatchGroup()
            let appendQueue = DispatchQueue(label: "directChatList.append")
            
            if snapshot.childrenCount == 0 {
                DispatchQueue.main.async {
                    self.chats = []
                    self.isLoading = false
                }
                return
            }
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let value = child.value as? [String: Any] else { continue }
                let chatId = child.key
                let otherId = value["otherUserId"] as? String ?? ""
                var otherName = value["otherUserName"] as? String ?? ""
                let lastMessage = value["lastMessage"] as? String ?? "Chat iniciado"
                let timestamp = value["timestamp"] as? TimeInterval ?? 0
                let unreadCount = value["unreadCount"] as? Int ?? 0
                
                group.enter()
                
                func appendChat(with name: String) {
                    appendQueue.async {
                        pendingChats.append(DirectChat(
                            id: chatId,
                            lastMessage: lastMessage,
                            timestamp: timestamp,
                            unreadCount: unreadCount,
                            otherUserName: name.isEmpty ? "Usuario" : name,
                            otherUserId: otherId
                        ))
                        group.leave()
                    }
                }
                
                if otherName.isEmpty, !otherId.isEmpty {
                    ref.child("users").child(otherId).observeSingleEvent(of: .value) { snap in
                        if let data = snap.value as? [String: Any] {
                            let fName = data["firstName"] as? String ?? ""
                            let lName = data["lastName"] as? String ?? ""
                            let email = data["email"] as? String ?? "Usuario"
                            otherName = "\(fName) \(lName)".trimmingCharacters(in: .whitespaces)
                            if otherName.isEmpty { otherName = email }
                            userRef.child(chatId).child("otherUserName").setValue(otherName)
                        }
                        appendChat(with: otherName)
                    }
                } else {
                    appendChat(with: otherName)
                }
            }
            
            group.notify(queue: .main) {
                self.chats = pendingChats.sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
            }
        }
    }
    
    private func detachChatsListener() {
        if let handle = chatsObserverHandle {
            userChatsRef?.removeObserver(withHandle: handle)
        }
        chatsObserverHandle = nil
        userChatsRef = nil
    }

    private func consumePendingRoute() {
        guard let route = pendingRoute else { return }
        activeChatRoute = route
        DispatchQueue.main.async {
            pendingRoute = nil
        }
    }
}

private struct ChatDestination: View {
    let route: ChatRoute?
    
    var body: some View {
        if let route = route {
            DirectChatView(
                chatId: route.chatId,
                otherUserId: route.otherUserId,
                otherUserName: route.otherUserName
            )
        } else {
            EmptyView()
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
                HStack(spacing: 8) {
                    Text(chat.otherUserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if chat.timestamp > 0 {
                        Text(Date(timeIntervalSince1970: chat.timestamp / 1000), style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if chat.unreadCount > 0 {
                        Text(chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
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
