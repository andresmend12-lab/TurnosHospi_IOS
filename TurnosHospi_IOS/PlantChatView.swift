import SwiftUI
import FirebaseDatabase

struct PlantChatView: View {
    let session: PlantChatSession
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Usamos el modelo DirectMessage (compartido con el chat directo)
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    
    // Referencia
    private let ref = Database.database().reference()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack {
                        Text(session.plantName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("En línea")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // Área de mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) { // Ajustado espaciado para coincidir con el estilo nuevo
                            ForEach(messages) { msg in
                                // CORRECCIÓN: Eliminados parámetros de color 'myColor' y 'otherColor'
                                DirectMessageBubble(
                                    message: msg,
                                    isMe: msg.senderId == authManager.user?.uid
                                )
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { _ in scrollToBottom(proxy) }
                    .onAppear { scrollToBottom(proxy) }
                }
                
                // Input Area
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) {
                            Text("Escribe a tu planta...").foregroundColor(.gray)
                        }
                        .padding(12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(24)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(textInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .cyan)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
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
    
    func listenToMessages() {
        let chatRef = ref.child("plant_chats").child(session.id).child("messages")
        
        chatRef.queryLimited(toLast: 50).observe(.childAdded) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                // Adaptación al modelo DirectMessage
                let msg = DirectMessage(
                    id: snapshot.key,
                    senderId: dict["senderId"] as? String ?? "",
                    text: dict["text"] as? String ?? "",
                    timestamp: dict["timestamp"] as? TimeInterval ?? 0,
                    read: false
                )
                DispatchQueue.main.async {
                    self.messages.append(msg)
                }
            }
        }
    }
    
    func sendMessage() {
        guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty,
              let uid = authManager.user?.uid else { return }
        
        let chatRef = ref.child("plant_chats").child(session.id).child("messages")
        let msgId = chatRef.childByAutoId().key ?? UUID().uuidString
        
        let msgData: [String: Any] = [
            "senderId": uid,
            "text": textInput.trimmingCharacters(in: .whitespaces),
            "timestamp": ServerValue.timestamp()
        ]
        
        chatRef.child(msgId).setValue(msgData)
        
        // Aquí el backend usaría session.targetFcmToken para notificar
        print("Mensaje enviado. Token objetivo: \(session.targetFcmToken)")
        
        textInput = ""
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
