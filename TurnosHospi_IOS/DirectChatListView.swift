import SwiftUI

struct DirectChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Estado para la búsqueda y lista de usuarios
    @State private var searchText = ""
    @State private var users: [ChatUser] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo oscuro (Deep Space)
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // --- Header ---
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("Chats Directos")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        // Icono fantasma para equilibrar el título
                        Image(systemName: "arrow.left").font(.title2).opacity(0)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    
                    // --- Buscador ---
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Buscar usuario...", text: $searchText)
                            .foregroundColor(.white)
                            .colorScheme(.dark) // Teclado oscuro
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding()
                    
                    // --- Lista de Usuarios ---
                    if isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if filteredUsers.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "person.slash.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No se encontraron usuarios")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredUsers) { user in
                                    // CORRECCIÓN: Ahora ChatUser es Hashable, por lo que esto funciona
                                    NavigationLink(value: user) {
                                        UserChatRow(user: user)
                                    }
                                    .buttonStyle(.plain) // Evita que se ponga azul al pulsar
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            // CORRECCIÓN: ChatUser es Hashable y pasamos los parámetros que DirectChatView necesita
            .navigationDestination(for: ChatUser.self) { user in
                DirectChatView(
                    targetUser: user,
                    currentUserId: authManager.user?.uid ?? "",
                    plantId: authManager.userPlantId
                )
            }
            .onAppear {
                fetchUsers()
            }
        }
    }
    
    // Filtro de búsqueda
    var filteredUsers: [ChatUser] {
        if searchText.isEmpty { return users }
        return users.filter {
            // CORRECCIÓN: Usamos 'name' en lugar de 'username'
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Carga de usuarios
    func fetchUsers() {
        // Ejemplo de lógica de carga
        /*
        isLoading = true
        let ref = Database.database().reference().child("users")
        ref.observeSingleEvent(of: .value) { snapshot in
            var loadedUsers: [ChatUser] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                // Parsear ChatUser...
            }
            self.users = loadedUsers.filter { $0.id != authManager.user?.uid }
            self.isLoading = false
        }
        */
    }
}

// Subvista para la fila de usuario
struct UserChatRow: View {
    let user: ChatUser
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar con iniciales
            Circle()
                .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .top, endPoint: .bottom))
                .frame(width: 50, height: 50)
                .overlay(
                    // CORRECCIÓN: Usamos 'name'
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // CORRECCIÓN: Usamos 'name'
                Text(user.name)
                    .font(.headline)
                    .foregroundColor(.white)
                // CORRECCIÓN: Ahora 'email' existe en el modelo
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
