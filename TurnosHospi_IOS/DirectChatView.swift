import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    let targetUser: ChatUser
    let currentUserId: String
    let plantId: String
    
    @Environment(\.dismiss) var dismiss
    
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    @State private var initialLoadFinished = false
    
    // Referencia segura a la DB
    private var ref: DatabaseReference {
        return Database.database().reference()
    }
    
    // ID compatible con Android (orden alfabético de UIDs)
    var chatId: String {
        return generateChatId(id1: currentUserId, id2: targetUser.id)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 15) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").font(.title2).foregroundColor(.white)
                    }
                    
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 35, height: 35)
                        Text(String(targetUser.name.prefix(1)).uppercased()).font(.headline).foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(targetUser.name).font(.headline).foregroundColor(.white)
                        Text(targetUser.role).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding().background(Color.black.opacity(0.3))
                
                // Mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { msg in
                                DirectMessageBubble(message: msg, isMe: msg.senderId == currentUserId)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if initialLoadFinished { scrollToBottom(proxy, animated: true) }
                    }
                    .onAppear {
                        if !messages.isEmpty { scrollToBottom(proxy, animated: false) }
                    }
                }
                
                // Input
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) { Text("Escribe un mensaje...").foregroundColor(.gray) }
                        .padding(12).foregroundColor(.white).background(Color.white.opacity(0.1)).cornerRadius(24)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill").font(.title3)
                            .foregroundColor(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .cyan)
                            .padding(10).background(Color.white.opacity(0.05)).clipShape(Circle())
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding().background(Color.black.opacity(0.2))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            listenToMessages()
            resetMyUnreadCount()
        }
        .onDisappear {
            // Dejar de escuchar al salir
            ref.child("direct_chats").child(chatId).child("messages").removeAllObservers()
        }
    }
    
    // MARK: - Lógica Firebase
    
    func listenToMessages() {
        guard !currentUserId.isEmpty, !targetUser.id.isEmpty else { return }
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        
        chatRef.queryLimited(toLast: 50).observeSingleEvent(of: .value) { snapshot in
            var tempMessages: [DirectMessage] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    tempMessages.append(mapDictToMessage(id: child.key, dict: dict))
                }
            }
            DispatchQueue.main.async {
                self.messages = tempMessages
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.initialLoadFinished = true }
            }
            setupRealtimeListener()
        }
    }
    
    func setupRealtimeListener() {
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        chatRef.queryLimited(toLast: 1).observe(.childAdded) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return }
            let msg = mapDictToMessage(id: snapshot.key, dict: dict)
            DispatchQueue.main.async {
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                }
            }
        }
    }
    
    func mapDictToMessage(id: String, dict: [String: Any]) -> DirectMessage {
        return DirectMessage(
            id: id,
            senderId: dict["senderId"] as? String ?? "",
            text: dict["text"] as? String ?? "",
            timestamp: dict["timestamp"] as? TimeInterval ?? 0,
            read: false
        )
    }
    
    // --- ENVÍO COMPATIBLE CON ANDROID ---
    func sendMessage() {
        let trimmed = textInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !currentUserId.isEmpty else { return }
        
        let timestamp = ServerValue.timestamp()
        
        // 1. Guardar mensaje en el historial central
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        guard let msgId = chatRef.childByAutoId().key else { return }
        
        let msgData: [String: Any] = [
            "senderId": currentUserId,
            "text": trimmed,
            "timestamp": timestamp
        ]
        chatRef.child(msgId).setValue(msgData)
        
        // 2. Actualizar MI lista de chats (Leídos = 0 porque yo lo escribí)
        let myMeta: [String: Any] = [
            "lastMessage": trimmed,
            "timestamp": timestamp,
            "otherUserId": targetUser.id,
            "plantId": plantId,
            "unreadCount": 0
        ]
        ref.child("user_direct_chats").child(currentUserId).child(chatId).updateChildValues(myMeta)
        
        // 3. Actualizar SU lista de chats (Leídos + 1) - Usamos Transaction para seguridad
        ref.child("user_direct_chats").child(targetUser.id).child(chatId).runTransactionBlock { (currentData) -> TransactionResult in
            var data = currentData.value as? [String: Any] ?? [:]
            
            data["lastMessage"] = trimmed
            data["timestamp"] = timestamp
            data["otherUserId"] = self.currentUserId
            data["plantId"] = self.plantId
            data["unreadCount"] = (data["unreadCount"] as? Int ?? 0) + 1
            
            currentData.value = data
            return TransactionResult.success(withValue: currentData)
        }
        
        textInput = ""
    }
    
    func resetMyUnreadCount() {
        guard !currentUserId.isEmpty else { return }
        ref.child("user_direct_chats").child(currentUserId).child(chatId).child("unreadCount").setValue(0)
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMsg = messages.last else { return }
        if animated {
            withAnimation { proxy.scrollTo(lastMsg.id, anchor: .bottom) }
        } else {
            proxy.scrollTo(lastMsg.id, anchor: .bottom)
        }
    }
    
    func generateChatId(id1: String, id2: String) -> String {
        return id1 < id2 ? "\(id1)_\(id2)" : "\(id2)_\(id1)"
    }
}

struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    var body: some View {
        HStack(alignment: .bottom) {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .foregroundColor(isMe ? .black : .white)
                    .padding(12)
                    .background(isMe ? Color(red: 0.33, green: 0.78, blue: 0.93) : Color(red: 0.12, green: 0.16, blue: 0.23))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.timeString).font(.caption2).foregroundColor(.gray).padding(isMe ? .trailing : .leading, 4)
            }
            .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
            if !isMe { Spacer() }
        }
    }
}
