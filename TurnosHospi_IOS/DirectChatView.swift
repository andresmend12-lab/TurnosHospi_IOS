import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct DirectChatView: View {
    let chatId: String
    let otherUserId: String
    let otherUserName: String
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    
    private let ref = Database.database().reference()
    
    var currentPlantId: String { authManager.userPlantId }
    var currentUserId: String { authManager.user?.uid ?? "" }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // HEADER
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(otherUserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color(red: 0.06, green: 0.09, blue: 0.16)) // Color topBar similar
                
                // MENSAJES
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
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: messages) { _, _ in
                        scrollToBottom(proxy)
                        resetUnreadCount()
                    }
                }
                
                // INPUT BAR
                HStack(spacing: 10) {
                    TextField("Escribe un mensaje...", text: $textInput)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(24)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : Color(red: 0.33, green: 0.78, blue: 0.93))
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(Color(red: 0.06, green: 0.09, blue: 0.16))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            listenToMessages()
            resetUnreadCount()
        }
    }
    
    // MARK: - Funciones Firebase
    
    func resetUnreadCount() {
        guard !currentUserId.isEmpty else { return }
        ref.child("user_direct_chats")
            .child(currentUserId)
            .child(chatId)
            .updateChildValues(["unreadCount": 0])
    }
    
    func listenToMessages() {
        guard !currentPlantId.isEmpty else { return }
        let msgRef = ref.child("plants/\(currentPlantId)/direct_chats/\(chatId)/messages")
        
        msgRef.observe(.value) { snapshot in
            var loaded: [DirectMessage] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let text = dict["text"] as? String ?? ""
                    let sender = dict["senderId"] as? String ?? ""
                    
                    var ts: TimeInterval = 0
                    if let t = dict["timestamp"] as? TimeInterval { ts = t }
                    else if let t = dict["timestamp"] as? Int { ts = TimeInterval(t) }
                    else if let n = dict["timestamp"] as? NSNumber { ts = n.doubleValue }
                    
                    loaded.append(DirectMessage(
                        id: child.key,
                        senderId: sender,
                        text: text,
                        timestamp: ts,
                        read: false
                    ))
                }
            }
            // Ordenar mensajes cronológicamente
            self.messages = loaded.sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    func sendMessage() {
        guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let textToSend = textInput.trimmingCharacters(in: .whitespaces)
        textInput = ""
        
        let msgRef = ref.child("plants/\(currentPlantId)/direct_chats/\(chatId)/messages").childByAutoId()
        let timestamp = Date().timeIntervalSince1970 * 1000
        
        let msgData: [String: Any] = [
            "id": msgRef.key ?? UUID().uuidString,
            "senderId": currentUserId,
            "text": textToSend,
            "timestamp": timestamp,
            "read": false
        ]
        
        msgRef.setValue(msgData)
        updateChatMetadata(
            for: currentUserId,
            otherId: otherUserId,
            otherName: otherUserName,
            lastMessage: textToSend,
            timestamp: timestamp,
            incrementUnread: false
        )
        let composedName = [authManager.currentUserName, authManager.currentUserLastName]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let senderDisplayName = composedName.isEmpty ? (Auth.auth().currentUser?.email ?? "Usuario") : composedName
        updateChatMetadata(
            for: otherUserId,
            otherId: currentUserId,
            otherName: senderDisplayName.isEmpty ? "Usuario" : senderDisplayName,
            lastMessage: textToSend,
            timestamp: timestamp,
            incrementUnread: true
        )
        sendNotification(text: textToSend)
    }
    
    private func updateChatMetadata(for uid: String,
                                    otherId: String,
                                    otherName: String,
                                    lastMessage: String,
                                    timestamp: TimeInterval,
                                    incrementUnread: Bool) {
        let metaRef = ref.child("user_direct_chats").child(uid).child(chatId)
        metaRef.runTransactionBlock { currentData in
            var data = currentData.value as? [String: Any] ?? [:]
            data["chatId"] = self.chatId
            data["plantId"] = self.currentPlantId
            data["otherUserId"] = otherId
            data["otherUserName"] = otherName
            data["lastMessage"] = lastMessage
            data["timestamp"] = timestamp
            let unread = data["unreadCount"] as? Int ?? 0
            data["unreadCount"] = incrementUnread ? unread + 1 : 0
            currentData.value = data
            return TransactionResult.success(withValue: currentData)
        }
    }
    
    func sendNotification(text: String) {
        let notifRef = ref.child("notifications_queue").childByAutoId()
        let data: [String: Any] = [
            "targetUserId": otherUserId,
            "senderId": currentUserId,
            "senderName": authManager.currentUserName,
            "type": "CHAT_DIRECT",
            "message": text,
            "targetScreen": "DirectChat",
            "chatId": chatId,
            "plantId": currentPlantId,
            "timestamp": ServerValue.timestamp()
        ]
        notifRef.setValue(data)
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - Burbuja de mensaje (CRÍTICO: NO BORRAR)
struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(10)
                    .background(isMe ? Color(red: 0.33, green: 0.78, blue: 0.93) : Color(red: 0.2, green: 0.25, blue: 0.35))
                    .foregroundColor(isMe ? .black : .white)
                    .cornerRadius(12)
                
                Text(message.timeString)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isMe { Spacer() }
        }
    }
}
