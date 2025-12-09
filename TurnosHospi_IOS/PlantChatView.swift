import SwiftUI
import FirebaseDatabase

struct PlantChatView: View {
    let session: PlantChatSession
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Reutilizamos el modelo de mensajes existente
    @State private var messages: [DirectMessage] = [] // Usando tu modelo DirectMessage
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
                
                // Área de mensajes (Placeholder)
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(messages) { msg in
                            // Reutiliza tu burbuja de DirectChatView
                            DirectMessageBubble(
                                message: msg,
                                isMe: msg.senderId == authManager.user?.uid,
                                myColor: Color.electricBlue,
                                otherColor: Color(red: 0.12, green: 0.16, blue: 0.23)
                            )
                        }
                    }
                    .padding()
                }
                
                // Input Area
                HStack {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) {
                            Text("Escribe a tu planta...").foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(.electricBlue)
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
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
                // Adaptación a tu modelo DirectMessage
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
        guard !textInput.isEmpty, let uid = authManager.user?.uid else { return }
        
        let chatRef = ref.child("plant_chats").child(session.id).child("messages")
        let msgId = chatRef.childByAutoId().key ?? UUID().uuidString
        
        let msgData: [String: Any] = [
            "senderId": uid,
            "text": textInput,
            "timestamp": ServerValue.timestamp()
        ]
        
        chatRef.child(msgId).setValue(msgData)
        
        // NOTA: Aquí es donde el backend usaría session.targetFcmToken
        // para enviar la notificación push si responde una IA o experto.
        print("Mensaje enviado. Token objetivo para respuesta: \(session.targetFcmToken)")
        
        textInput = ""
    }
}
