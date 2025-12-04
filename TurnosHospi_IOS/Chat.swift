import SwiftUI

struct ChatView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("Chat", selection: $selectedTab) {
                Text("Grupal").tag(0)
                Text("Privados").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                GroupChatView()
            } else {
                DirectChatListView()
            }
        }
        .navigationTitle("Mensajes")
    }
}

struct GroupChatView: View {
    @State private var messageText = ""
    // Mock Messages
    @State private var messages: [ChatMessage] = [
        ChatMessage(id: "1", senderId: "u2", senderName: "Carlos", text: "¿Alguien me cubre el viernes?", timestamp: Date().timeIntervalSince1970 * 1000)
    ]
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { msg in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(msg.senderName).font(.caption).foregroundColor(.gray)
                            Text(msg.text)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                TextField("Escribe un mensaje...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
            }
            .padding()
        }
    }
    
    func sendMessage() {
        // Lógica de envío a Firebase
        messageText = ""
    }
}

struct DirectChatListView: View {
    var body: some View {
        List {
            Text("Laura Martínez")
            Text("Supervisor General")
        }
    }
}
