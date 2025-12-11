import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    var chatId: String // Ahora siempre debe venir un ID generado (uid1_uid2)
    var otherUserId: String
    var otherUserName: String
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    
    private let ref = Database.database().reference()
    
    var currentPlantId: String {
        return authManager.userPlantId
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left").font(.title2).foregroundColor(.white)
                    }
                    Spacer()
                    Text(otherUserName).font(.headline).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // Mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { msg in
                                // AQUÍ SE USA DIRECTMESSAGEBUBBLE
                                DirectMessageBubble(message: msg, isMe: msg.senderId == authManager.user?.uid)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { _ in scrollToBottom(proxy) }
                    .onAppear { scrollToBottom(proxy) }
                }
                
                // Input
                HStack(spacing: 10) {
                    TextField("Escribe...", text: $textInput)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                    }
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            listenToMessages()
        }
    }
    
    // MARK: - Firebase Logic
    
    func listenToMessages() {
        guard !currentPlantId.isEmpty else { return }
        
        // Ruta: plants/{plantId}/direct_chats/{chatId}/messages
        let msgRef = ref.child("plants").child(currentPlantId).child("direct_chats").child(chatId).child("messages")
        
        msgRef.queryLimited(toLast: 50).observe(.childAdded) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                let msg = DirectMessage(
                    id: snapshot.key,
                    senderId: dict["senderId"] as? String ?? "",
                    text: dict["text"] as? String ?? "",
                    timestamp: dict["timestamp"] as? TimeInterval ?? 0,
                    read: dict["read"] as? Bool ?? false
                )
                DispatchQueue.main.async {
                    self.messages.append(msg)
                }
            }
        }
    }
    
    func sendMessage() {
        guard let myId = authManager.user?.uid,
              !textInput.trimmingCharacters(in: .whitespaces).isEmpty,
              !currentPlantId.isEmpty else { return }
        
        let textToSend = textInput
        textInput = "" // Limpiar UI inmediatamente
        
        // 1. Guardar mensaje en: plants/{plantId}/direct_chats/{chatId}/messages
        let chatRootRef = ref.child("plants").child(currentPlantId).child("direct_chats").child(chatId)
        let msgRef = chatRootRef.child("messages").childByAutoId()
        
        let msgData: [String: Any] = [
            "id": msgRef.key ?? UUID().uuidString,
            "senderId": myId,
            "text": textToSend,
            "timestamp": ServerValue.timestamp(),
            "read": false
        ]
        
        msgRef.setValue(msgData)
        
        // 2. Actualizar último mensaje (para la lista)
        chatRootRef.updateChildValues([
            "lastMessage": textToSend,
            "lastTimestamp": ServerValue.timestamp()
        ])
        
        // 3. Registrar chat en el índice de ambos usuarios (para que aparezca en la lista)
        // Ruta: user_chats/{uid}/{chatId} = true
        ref.child("user_chats").child(myId).child(chatId).setValue(true)
        ref.child("user_chats").child(otherUserId).child(chatId).setValue(true)
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - COMPONENTE BURBUJA (AÑADIDO AQUÍ PARA SOLUCIONAR EL ERROR)
struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(10)
                    .background(isMe ? Color(red: 0.2, green: 0.4, blue: 1.0) : Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                
                Text(message.timeString)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isMe { Spacer() }
        }
    }
}
