func fetchChatsDirectlyFromPlant() {
    guard !currentUserId.isEmpty, !currentPlantId.isEmpty else {
        // Mejor seguir mostrando loading si aún no tenemos usuario/planta
        return
    }
    
    let chatsRef = ref.child("plants").child(currentPlantId).child("direct_chats")
    
    chatsRef.observe(.value) { snapshot in
        var loadedChats: [DirectChat] = []
        let group = DispatchGroup()
        
        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            let chatId = child.key
            
            guard chatId.contains(currentUserId) else { continue }
            
            if let dict = child.value as? [String: Any] {
                group.enter()
                
                var lastMsg = dict["lastMessage"] as? String ?? ""
                var timestamp = dict["lastTimestamp"] as? TimeInterval ?? 0
                
                if lastMsg.isEmpty,
                   let messagesDict = dict["messages"] as? [String: [String: Any]] {
                    let sortedMessages = messagesDict.values.compactMap { msgData -> (String, TimeInterval)? in
                        guard let text = msgData["text"] as? String,
                              let time = msgData["timestamp"] as? TimeInterval else { return nil }
                        return (text, time)
                    }.sorted { $0.1 < $1.1 }
                    
                    if let last = sortedMessages.last {
                        lastMsg = last.0
                        timestamp = last.1
                    }
                }
                
                if lastMsg.isEmpty { lastMsg = "Chat iniciado" }
                
                let parts = chatId.components(separatedBy: "_")
                let otherId: String
                if parts.count == 2 {
                    otherId = (parts[0] == currentUserId) ? parts[1] : parts[0]
                } else {
                    otherId = chatId
                        .replacingOccurrences(of: currentUserId, with: "")
                        .replacingOccurrences(of: "_", with: "")
                }
                
                self.ref.child("users").child(otherId).observeSingleEvent(of: .value) { userSnap in
                    let userVal = userSnap.value as? [String: Any]
                    let firstName = userVal?["firstName"] as? String ?? "Usuario"
                    let lastName = userVal?["lastName"] as? String ?? ""
                    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    let role = userVal?["role"] as? String ?? ""
                    let finalName = fullName.isEmpty ? "Usuario" : fullName
                    
                    let chat = DirectChat(
                        id: chatId,
                        participants: parts,
                        lastMessage: lastMsg,
                        timestamp: timestamp,
                        otherUserName: finalName,
                        otherUserRole: role,
                        otherUserId: otherId
                    )
                    loadedChats.append(chat)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.chats = loadedChats.sorted { $0.timestamp > $1.timestamp }
            self.isLoading = false
        }
    }
}
