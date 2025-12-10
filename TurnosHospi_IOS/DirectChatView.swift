import SwiftUI
import FirebaseDatabase

struct DirectChatView: View {
    let targetUser: ChatUser
    let currentUserId: String
    let plantId: String
    
    @Environment(\.dismiss) var dismiss
    
    // Estados
    @State private var messages: [DirectMessage] = []
    @State private var textInput: String = ""
    @State private var initialLoadFinished = false // Para controlar el scroll
    
    // Referencia Database
    private let ref = Database.database().reference()
    
    var chatId: String {
        return generateChatId(id1: currentUserId, id2: targetUser.id)
    }
    
    var body: some View {
        ZStack {
            // Fondo oscuro
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack(spacing: 15) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.3))
                            .frame(width: 35, height: 35)
                        Text(String(targetUser.name.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(targetUser.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(targetUser.role)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // --- AREA DE MENSAJES ---
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
                    // Optimizamos el scroll: Solo animamos si NO es la carga inicial masiva
                    .onChange(of: messages.count) { _ in
                        if initialLoadFinished {
                            scrollToBottom(proxy, animated: true)
                        }
                    }
                    // Scroll inicial forzado al aparecer
                    .onAppear {
                        if !messages.isEmpty {
                            scrollToBottom(proxy, animated: false)
                        }
                    }
                }
                
                // --- AREA DE TEXTO ---
                HStack(spacing: 10) {
                    TextField("", text: $textInput)
                        .placeholder(when: textInput.isEmpty) {
                            Text("Escribe un mensaje...").foregroundColor(.gray)
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
        .onDisappear {
            // Limpieza básica: Quitamos observers al salir para liberar memoria
            ref.child("direct_chats").child(chatId).child("messages").removeAllObservers()
        }
    }
    
    // --- LÓGICA OPTIMIZADA ---
    
    func listenToMessages() {
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        
        // 1. CARGA INICIAL MASIVA (Evita el freeze)
        // Pedimos los datos UNA SOLA VEZ (.value) en lugar de evento por evento
        chatRef.queryLimited(toLast: 50).observeSingleEvent(of: .value) { snapshot in
            var tempMessages: [DirectMessage] = []
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    let msg = mapDictToMessage(id: child.key, dict: dict)
                    tempMessages.append(msg)
                }
            }
            
            // Actualizamos la UI una sola vez
            DispatchQueue.main.async {
                self.messages = tempMessages
                self.initialLoadFinished = true // Permitimos animaciones futuras
                
                // Esperamos un pelín a que se dibuje para hacer el scroll inicial
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Buscamos el último ID para scroll directo sin animación
                    if let lastId = tempMessages.last?.id {
                        // Usamos NotificationCenter o simplemente confiamos en que el usuario ya verá lo último
                        // Aquí no tenemos acceso directo al proxy, pero al setear 'messages', SwiftUI redibuja.
                    }
                }
            }
            
            // 2. ESCUCHAR NUEVOS (En tiempo real)
            // Iniciamos el listener para mensajes que lleguen DESPUÉS de ahora
            setupRealtimeListener()
        }
    }
    
    func setupRealtimeListener() {
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        
        // Escuchamos solo nuevos añadidos
        chatRef.queryLimited(toLast: 1).observe(.childAdded) { snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return }
            let msg = mapDictToMessage(id: snapshot.key, dict: dict)
            
            DispatchQueue.main.async {
                // Evitamos duplicados que ya vinieron en la carga inicial
                if !self.messages.contains(where: { $0.id == msg.id }) {
                    self.messages.append(msg)
                    // El .onChange se encargará del scroll animado
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
    
    func sendMessage() {
        let trimmed = textInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let chatRef = ref.child("direct_chats").child(chatId).child("messages")
        let msgId = chatRef.childByAutoId().key ?? UUID().uuidString
        
        let msgData: [String: Any] = [
            "senderId": currentUserId,
            "text": trimmed,
            "timestamp": ServerValue.timestamp()
        ]
        
        chatRef.child(msgId).setValue(msgData)
        textInput = ""
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMsg = messages.last else { return }
        
        if animated {
            withAnimation {
                proxy.scrollTo(lastMsg.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMsg.id, anchor: .bottom)
        }
    }
    
    func generateChatId(id1: String, id2: String) -> String {
        return id1 < id2 ? "\(id1)_\(id2)" : "\(id2)_\(id1)"
    }
}

// MARK: - Componentes Auxiliares
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
                
                Text(message.timeString)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(isMe ? .trailing : .leading, 4)
            }
            .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
            
            if !isMe { Spacer() }
        }
    }
}
