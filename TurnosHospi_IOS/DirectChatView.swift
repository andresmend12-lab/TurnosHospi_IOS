import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    // Parámetros
    let targetUser: ChatUser
    let currentUserId: String
    let plantId: String // Para notificaciones o contexto
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Estado
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    @State private var isLoading = true
    
    private let ref = Database.database().reference()
    
    // Generar ID único consistente para el chat (MinID_MaxID)
    private var chatId: String {
        return currentUserId < targetUser.id
            ? "\(currentUserId)_\(targetUser.id)"
            : "\(targetUser.id)_\(currentUserId)"
    }
    
    // Colores
    let myBubbleColor = Color(red: 0.33, green: 0.78, blue: 0.93) // Cyan
    let otherBubbleColor = Color(red: 0.12, green: 0.16, blue: 0.23) // Dark Slate
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text(targetUser.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(targetUser.role)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // --- MENSAJES ---
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                DirectMessageBubble(
                                    message: msg,
                                    isMe: msg.senderId == currentUserId,
                                    myColor: myBubbleColor,
                                    otherColor: otherBubbleColor
                                )
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                // --- INPUT ---
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) {
                            Text("Mensaje para \(String(targetUser.name.prefix(10)))...").foregroundColor(.gray)
                        }
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(textInput.isEmpty ? Color.white.opacity(0.4) : myBubbleColor, lineWidth: 1)
                        )
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(textInput.isBlank ? .gray : myBubbleColor)
                            .rotationEffect(.degrees(45))
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .disabled(textInput.isBlank)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            listenToMessages()
        }
    }
    
    // MARK: - Lógica
    
    func listenToMessages() {
        // Ruta: direct_chats/{chatId}/messages
        let messagesRef = ref.child("direct_chats").child(chatId).child("messages")
        
        messagesRef.queryLimited(toLast: 100).observe(.childAdded) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                let id = dict["id"] as? String ?? snapshot.key
                let senderId = dict["senderId"] as? String ?? ""
                let text = dict["text"] as? String ?? ""
                let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                let read = dict["read"] as? Bool ?? false
                
                let msg = DirectMessage(id: id, senderId: senderId, text: text, timestamp: timestamp, read: read)
                
                DispatchQueue.main.async {
                    self.messages.append(msg)
                }
            }
        }
    }
    
    func sendMessage() {
        guard !textInput.isBlank else { return }
        
        let messagesRef = ref.child("direct_chats").child(chatId).child("messages")
        guard let msgId = messagesRef.childByAutoId().key else { return }
        
        let textToSend = textInput.trimmingCharacters(in: .whitespaces)
        let timestamp = ServerValue.timestamp()
        
        let msgData: [String: Any] = [
            "id": msgId,
            "senderId": currentUserId,
            "text": textToSend,
            "timestamp": timestamp,
            "read": false
        ]
        
        // 1. Guardar mensaje
        messagesRef.child(msgId).setValue(msgData)
        
        // 2. Notificación (Simulación)
        let myName = authManager.currentUserName // O nombre completo
        sendNotification(
            fanoutId: "DIRECT_CHAT_FANOUT_ID",
            type: "CHAT_DIRECT",
            message: "Mensaje de \(myName)",
            targetUserId: targetUser.id
        )
        
        textInput = ""
    }
    
    func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    func sendNotification(fanoutId: String, type: String, message: String, targetUserId: String) {
        // Aquí implementarías la lógica de escritura en Firebase para activar tu función Cloud
        // o tu sistema de notificaciones push.
        print("Notificación DIRECTA enviada a \(targetUserId): \(message)")
    }
}

// Burbuja Visual
struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    let myColor: Color
    let otherColor: Color
    
    var body: some View {
        HStack(alignment: .bottom) {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .foregroundColor(isMe ? .black : .white)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Text(message.timeString)
                        .font(.system(size: 10))
                        .foregroundColor(isMe ? .black.opacity(0.6) : .white.opacity(0.5))
                    
                    // Doble check simple si soy yo
                    if isMe {
                        Image(systemName: "checkmark") // Podrías cambiar a checkmark.double si implementas lectura real
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .background(isMe ? myColor : otherColor)
            .clipShape(
                RoundedCorner(
                    radius: 16,
                    corners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight]
                )
            )
            .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
            
            if !isMe { Spacer() }
        }
    }
}
