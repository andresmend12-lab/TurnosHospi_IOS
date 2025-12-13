import SwiftUI
import FirebaseDatabase

// MARK: - Modelo de Mensaje
struct ChatMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: TimeInterval // Firebase usa Long (milisegundos) usualmente
    
    // Helper para formatear la hora
    var timeString: String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

// MARK: - Vista Principal
struct GroupChatView: View {
    var plantId: String
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    // Referencias y Estado
    private let ref = Database.database().reference()
    @State private var messages: [ChatMessage] = []
    @State private var textInput: String = ""
    @State private var isLoading = true
    
    // Colores del tema (basados en tu código Android y iOS)
    let myBubbleColor = Color(red: 0.33, green: 0.78, blue: 0.93) // #54C7EC (Cyan)
    let otherBubbleColor = Color(red: 0.12, green: 0.16, blue: 0.23) // #1E293B (Dark Slate)
    let backgroundColor = Color(red: 0.1, green: 0.1, blue: 0.18) // Fondo App
    
    var currentUserId: String {
        return authManager.user?.uid ?? ""
    }
    
    var body: some View {
        ZStack {
            // Fondo
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("Chat de Grupo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Elemento invisible para equilibrar el botón de atrás
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // --- LISTA DE MENSAJES ---
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                MessageBubbleRow(
                                    message: msg,
                                    isMe: msg.senderId == currentUserId,
                                    myColor: myBubbleColor,
                                    otherColor: otherBubbleColor
                                )
                                .id(msg.id) // Para el autoscroll
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                // --- BARRA DE ENTRADA ---
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) {
                            Text("Escribe un mensaje...").foregroundColor(.gray)
                        }
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.1)) // 0x22000000 en Android
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
        .onAppear {
            listenToMessages()
        }
    }
    
    // MARK: - Lógica Firebase
    
    func listenToMessages() {
        let chatRef = ref.child("plants").child(plantId).child("chat")
        
        // Escuchar nuevos mensajes (childAdded es más eficiente para chats que value)
        chatRef.queryLimited(toLast: 100).observe(.childAdded) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                let id = dict["id"] as? String ?? snapshot.key
                let senderId = dict["senderId"] as? String ?? ""
                let senderName = dict["senderName"] as? String ?? "Usuario"
                let text = dict["text"] as? String ?? ""
                let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                
                let msg = ChatMessage(id: id, senderId: senderId, senderName: senderName, text: text, timestamp: timestamp)
                
                // Añadir y ordenar (aunque childAdded suele venir en orden)
                DispatchQueue.main.async {
                    self.messages.append(msg)
                    self.isLoading = false
                }
            }
        }
    }
    
    func sendMessage() {
        guard !textInput.isBlank else { return }
        
        let chatRef = ref.child("plants").child(plantId).child("chat")
        guard let msgId = chatRef.childByAutoId().key else { return }
        
        // Usar nombre del AuthManager o fallback
        let name = authManager.currentUserName.isEmpty ? "Usuario" : "\(authManager.currentUserName) \(authManager.currentUserLastName)".trimmingCharacters(in: .whitespaces)
        let textToSend = textInput.trimmingCharacters(in: .whitespaces)
        let timestamp = ServerValue.timestamp()
        
        let msgData: [String: Any] = [
            "id": msgId,
            "senderId": currentUserId,
            "senderName": name,
            "text": textToSend,
            "timestamp": timestamp
        ]
        
        // 1. Guardar mensaje
        chatRef.child(msgId).setValue(msgData)
        
        // 2. Notificación (Replicando lógica Android)
        let notificationMsg = "Nuevo mensaje de \(name)..."
        sendNotification(
            fanoutId: "GROUP_CHAT_FANOUT_ID",
            type: "CHAT_GROUP",
            message: notificationMsg,
            screen: "GroupChat",
            plantId: plantId
        )
        
        // Limpiar
        textInput = ""
    }
    
    // MARK: - Lógica de Notificación (Simulación Android)
    func sendNotification(fanoutId: String, type: String, message: String, screen: String, plantId: String) {
        // En Android llamabas a 'onSaveNotification'. En iOS, si no tienes una Cloud Function escuchando 'chat',
        // puedes escribir un registro de notificación aquí.
        
        // Ejemplo: Escribir en una cola de notificaciones si tu backend lo soporta
        /*
        let notifRef = ref.child("notifications_queue").childByAutoId()
        let notifData: [String: Any] = [
            "plantId": plantId,
            "senderId": currentUserId,
            "type": type,
            "message": message,
            "targetScreen": screen,
            "timestamp": ServerValue.timestamp()
        ]
        notifRef.setValue(notifData)
        */
        
        print("Notificación enviada (Lógica pendiente de backend): \(message)")
    }
    
    // Helper autoscroll
    func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Componente de Burbuja
struct MessageBubbleRow: View {
    let message: ChatMessage
    let isMe: Bool
    let myColor: Color
    let otherColor: Color
    
    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
            // Nombre del remitente (solo si no soy yo)
            if !isMe {
                Text(message.senderName)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.leading, 12)
            }
            
            // Burbuja
            HStack {
                if isMe { Spacer() }
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .foregroundColor(isMe ? .black : .white)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true) // Multilinea
                    
                    Text(message.timeString)
                        .font(.system(size: 10))
                        .foregroundColor(isMe ? .black.opacity(0.6) : .white.opacity(0.5))
                }
                .padding(12)
                .background(isMe ? myColor : otherColor)
                // Forma de burbuja (redondeada con una "punta" sutil)
                .clipShape(
                    RoundedCorner(
                        radius: 16,
                        corners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight]
                    )
                )
                .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading) // Ancho máximo como en Android
                
                if !isMe { Spacer() }
            }
        }
    }
}

// Helper para detectar string vacía
extension String {
    var isBlank: Bool {
        return allSatisfy({ $0.isWhitespace })
    }
}
