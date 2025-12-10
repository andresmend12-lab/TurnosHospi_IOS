import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    let targetUser: ChatUser
    let currentUserId: String
    let plantId: String // Asegúrate de que esto se pase correctamente
    
    @Environment(\.dismiss) var dismiss
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    
    // Generación de ID consistente con Android
    var chatId: String {
        return currentUserId < targetUser.id ? "\(currentUserId)_\(targetUser.id)" : "\(targetUser.id)_\(currentUserId)"
    }
    
    private var ref: DatabaseReference {
        return Database.database().reference()
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
                    Text(targetUser.name).font(.headline).foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
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
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onAppear {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                
                // Input
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) { Text("Escribe un mensaje...").foregroundColor(.gray) }
                        .padding(12).foregroundColor(.white).background(Color.white.opacity(0.1)).cornerRadius(24)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill").font(.title3).foregroundColor(Color(hex: "54C7EC")).padding(10)
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding().background(Color.black.opacity(0.2))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            listenToMessages()
            resetUnreadCount()
        }
    }
    
    // MARK: - Firebase Logic
    
    func listenToMessages() {
        // CORRECCIÓN: Ruta idéntica a Android
        let chatRef = ref.child("plants").child(plantId).child("direct_chats").child(chatId).child("messages")
        
        chatRef.observe(.value) { snapshot in
            var newMsgs: [DirectMessage] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let msg = DirectMessage(
                        id: child.key,
                        senderId: dict["senderId"] as? String ?? "",
                        text: dict["text"] as? String ?? "",
                        timestamp: dict["timestamp"] as? TimeInterval ?? 0,
                        read: false
                    )
                    newMsgs.append(msg)
                }
            }
            DispatchQueue.main.async { self.messages = newMsgs }
        }
    }
    
    func resetUnreadCount() {
        ref.child("user_direct_chats").child(currentUserId).child(chatId).child("unreadCount").setValue(0)
    }
    
    func sendMessage() {
        let trimmed = textInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let timestamp = ServerValue.timestamp()
        
        // 1. Guardar mensaje (Ruta de Planta)
        let messagesRef = ref.child("plants").child(plantId).child("direct_chats").child(chatId).child("messages")
        guard let key = messagesRef.childByAutoId().key else { return }
        
        let msgData: [String: Any] = [
            "id": key,
            "senderId": currentUserId,
            "text": trimmed,
            "timestamp": timestamp
        ]
        messagesRef.child(key).setValue(msgData)
        
        // 2. Actualizar mi lista
        let myMeta: [String: Any] = [
            "lastMessage": trimmed,
            "timestamp": timestamp,
            "otherUserId": targetUser.id,
            "plantId": plantId,
            "unreadCount": 0
        ]
        ref.child("user_direct_chats").child(currentUserId).child(chatId).updateChildValues(myMeta)
        
        // 3. Actualizar la lista del OTRO usuario (Transacción segura)
        let otherUserRef = ref.child("user_direct_chats").child(targetUser.id).child(chatId)
        otherUserRef.runTransactionBlock { (currentData) -> TransactionResult in
            var data = currentData.value as? [String: Any] ?? [:]
            
            data["lastMessage"] = trimmed
            data["timestamp"] = timestamp
            data["otherUserId"] = self.currentUserId
            data["plantId"] = self.plantId
            
            let currentUnread = data["unreadCount"] as? Int ?? 0
            data["unreadCount"] = currentUnread + 1
            
            currentData.value = data
            return TransactionResult.success(withValue: currentData)
        }
        
        textInput = ""
    }
}

// Burbuja simple
struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    var body: some View {
        HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .foregroundColor(isMe ? .black : .white)
                    .padding(12)
                    .background(isMe ? Color(hex: "54C7EC") : Color(hex: "334155"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(message.timeString).font(.caption2).foregroundColor(.gray)
            }
            .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
            if !isMe { Spacer() }
        }
    }
}
