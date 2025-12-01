import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var chatVM: ChatViewModel

    var body: some View {
        NavigationStack {
            List(chatVM.threads) { thread in
                NavigationLink {
                    ChatThreadView(thread: thread)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "bubble.right.fill"))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.participants.map { $0.name }.joined(separator: ", "))
                                .font(.headline)
                            Text(thread.lastMessage)
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
            .navigationTitle("Mensajes")
        }
    }
}

struct ChatThreadView: View {
    let thread: ChatThread
    @State private var composerText = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(thread.messages) { message in
                    HStack {
                        if message.isMine { Spacer() }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.sender.name)
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
                    composerText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(composerText.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat")
    }
}
