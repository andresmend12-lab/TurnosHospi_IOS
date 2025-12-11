import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    // ID del chat: siempre en formato uid1_uid2 (ordenado alfabéticamente)
    let chatId: String
    let otherUserId: String
    let otherUserName: String
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    
    private let ref = Database.database().reference()
    
    var currentPlantId: String {
        authManager.userPlantId
    }
    
    var currentUserId: String? {
        authManager.user?.uid
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
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
                    // Icono invisible para centrar
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // MARK: - Lista de mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { msg in
                                DirectMessageBubble(
                                    message: msg,
                                    isMe: msg.senderId == currentUserId
                                )
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { _ in
                        scrollToBottom(proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                }
                
                // MARK: - Input
                HStack(spacing: 10) {
                    TextField("Escribe...", text: $textInput)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(
                                textInput.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .gray
                                : .blue
                            )
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
        .onDisappear {
            removeMessagesObserver()
        }
    }
    
    // MARK: - Firebase: escucha de mensajes
    
    func listenToMessages() {
        guard !currentPlantId.isEmpty else { return }
        
        let msgRef = ref
            .child("plants")
            .child(currentPlantId)
            .child("direct_chats")
            .child(chatId)
            .child("messages")
        
        // Ordenamos por timestamp y limitamos a los últimos 50
        msgRef
            .queryOrdered(byChild: "timestamp")
            .queryLimited(toLast: 50)
            .observe(.childAdded) { snapshot in
                guard let dict = snapshot.value as? [String: Any] else { return }
                
                let senderId = dict["senderId"] as? String ?? ""
                let text = dict["text"] as? String ?? ""
                let read = dict["read"] as? Bool ?? false
                
                // Manejo robusto de timestamp (Double/Int/NSNumber)
                let rawTimestamp = dict["timestamp"]
                let ts: TimeInterval
                if let t = rawTimestamp as? TimeInterval {
                    ts = t
                } else if let t = rawTimestamp as? Double {
                    ts = t
                } else if let t = rawTimestamp as? Int {
                    ts = TimeInterval(t)
                } else if let n = rawTimestamp as? NSNumber {
                    ts = n.doubleValue
                } else {
                    ts = 0
                }
                
                let msg = DirectMessage(
                    id: snapshot.key,
                    senderId: senderId,
                    text: text,
                    timestamp: ts,
                    read: read
                )
                
                DispatchQueue.main.async {
                    self.messages.append(msg)
                    self.messages.sort { $0.timestamp < $1.timestamp }
                }
            }
    }
    
    func removeMessagesObserver() {
        guard !currentPlantId.isEmpty else { return }
        
        let msgRef = ref
            .child("plants")
            .child(currentPlantId)
            .child("direct_chats")
            .child(chatId)
            .child("messages")
        
        msgRef.removeAllObservers()
    }
    
    // MARK: - Envío de mensajes
    
    func sendMessage() {
        guard
            let myId = currentUserId,
            !textInput.trimmingCharacters(in: .whitespaces).isEmpty,
            !currentPlantId.isEmpty
        else { return }
        
        let textToSend = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        textInput = "" // Limpiar UI inmediatamente
        
        let chatRootRef = ref
            .child("plants")
            .child(currentPlantId)
            .child("direct_chats")
            .child(chatId)
        
        let msgRef = chatRootRef.child("messages").childByAutoId()
        
        let msgId = msgRef.key ?? UUID().uuidString
        let timestamp = ServerValue.timestamp()
        
        let msgData: [String: Any] = [
            "id": msgId,
            "senderId": myId,
            "text": textToSend,
            "timestamp": timestamp, // ms desde Epoch
            "read": false
        ]
        
        // 1. Guardar mensaje
        msgRef.setValue(msgData)
        
        // 2. Actualizar último mensaje (para la lista)
        chatRootRef.updateChildValues([
            "lastMessage": textToSend,
            "lastTimestamp": timestamp
        ])
        
        // 3. Registrar chat en el índice de usuarios
        // user_chats/{uid}/{chatId} = true
        ref.child("user_chats").child(myId).child(chatId).setValue(true)
        ref.child("user_chats").child(otherUserId).child(chatId).setValue(true)
        
        // 4. NUEVO: Enviar Notificación al otro usuario (Escribir en la cola)
        let myName = authManager.currentUserName
        let notificationMsg = "Mensaje de \(myName): \(textToSend)"
        
        sendDirectNotification(
            targetUserId: otherUserId, // IMPORTANTE: ID del destinatario
            message: notificationMsg,
            chatId: chatId
        )
    }
    
    // MARK: - Helper Notificación Directa
    func sendDirectNotification(targetUserId: String, message: String, chatId: String) {
        // Escribimos en 'notifications_queue' para que el Cloud Function lo procese
        let notifRef = ref.child("notifications_queue").childByAutoId()
        
        let notifData: [String: Any] = [
            "targetUserId": targetUserId, // El backend usará esto para buscar el fcmToken del usuario
            "senderId": currentUserId ?? "",
            "senderName": authManager.currentUserName,
            "type": "CHAT_DIRECT",
            "message": message,
            "targetScreen": "DirectChat",
            "chatId": chatId, // Para abrir el chat correcto al tocar la notificación
            "plantId": currentPlantId,
            "timestamp": ServerValue.timestamp()
        ]
        
        notifRef.setValue(notifData) { error, _ in
            if error == nil {
                print("Notificación encolada correctamente para \(targetUserId)")
            } else {
                print("Error encolando notificación: \(error?.localizedDescription ?? "Desconocido")")
            }
        }
    }
    
    // MARK: - Scroll
    
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Burbuja de mensaje

struct DirectMessageBubble: View {
    let message: DirectMessage
    let isMe: Bool
    
    var body: some View {
        HStack {
            if isMe { Spacer() }
            
            VStack(
                alignment: isMe ? .trailing : .leading,
                spacing: 2
            ) {
                Text(message.text)
                    .padding(10)
                    .background(
                        isMe
                        ? Color(red: 0.2, green: 0.4, blue: 1.0)
                        : Color.white.opacity(0.1)
                    )
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
