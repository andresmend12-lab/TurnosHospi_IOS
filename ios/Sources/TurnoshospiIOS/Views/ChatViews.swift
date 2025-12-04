import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var chatVM: ChatViewModel

    var body: some View {
        NavigationStack {
            List {
                if !chatVM.availableContacts.isEmpty {
                    Section("Contactos disponibles") {
                        ForEach(chatVM.availableContacts) { contact in
                            Button {
                                chatVM.selectChat(with: contact.id)
                            } label: {
                                HStack {
                                    Image(systemName: contact.avatarSystemName)
                                    VStack(alignment: .leading) {
                                        Text(contact.name).font(.headline)
                                        Text(contact.role).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section("Chats activos") {
                    ForEach(chatVM.threads) { thread in
                        NavigationLink {
                            ChatThreadView(thread: thread)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "bubble.right.fill"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chatVM.displayName(for: thread))
                                        .font(.headline)
                                    Text(thread.lastMessage.isEmpty ? "Sin mensajes" : thread.lastMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if thread.unreadCount > 0 {
                                    Text("\(thread.unreadCount)")
                                        .padding(6)
                                        .background(.blue, in: Circle())
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Mensajes")
        }
    }
}

struct ChatThreadView: View {
    let thread: ChatThread
    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var composerText = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(chatVM.messages) { message in
                    HStack {
                        if message.isMine { Spacer() }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.senderName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(message.text)
                                .padding(10)
                                .background(message.isMine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if !message.isMine { Spacer() }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
            HStack {
                TextField("Escribe un mensaje", text: $composerText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let message = composerText
                    chatVM.sendMessage(message)
                    composerText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(composerText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(chatVM.displayName(for: thread))
        .onAppear {
            chatVM.selectChat(with: thread.otherUserId)
        }
    }
}

struct GroupChatView: View {
    @EnvironmentObject private var groupChatVM: GroupChatViewModel
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(groupChatVM.messages) { message in
                            HStack {
                                if message.isMine { Spacer() }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.senderName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(message.text)
                                        .padding(10)
                                        .background(message.isMine ? Color.blue.opacity(0.25) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                }
                                if !message.isMine { Spacer() }
                            }
                        }
                    }
                    .padding()
                }
                HStack {
                    TextField("Mensaje a la planta", text: $groupChatVM.text)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        groupChatVM.send()
                    } label: { Image(systemName: "paperplane.fill") }
                    .disabled(groupChatVM.text.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Chat de planta")
            .onAppear {
                if let plantId = auth.plant?.id, let profile = auth.profile {
                    groupChatVM.start(plantId: plantId, user: profile)
                }
            }
            .onDisappear { groupChatVM.stop() }
        }
    }
}
