import SwiftUI

struct NewChatSelectionView: View {
    @ObservedObject var plantManager: PlantManager
    let currentUserId: String
    // CAMBIO: Ahora devuelve un ChatUser, no un PlantStaff
    let onUserSelected: (ChatUser) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
            
            VStack {
                Text("Nuevo Mensaje")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                if plantManager.isLoading {
                    ProgressView().tint(.white)
                        .padding()
                } else if plantManager.plantUsers.isEmpty {
                    // Feedback si no hay usuarios reales unidos
                    VStack(spacing: 10) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No hay otros usuarios registrados en esta planta aún.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                } else {
                    // CAMBIO: Iteramos sobre plantUsers (Usuarios reales)
                    List(plantManager.plantUsers) { user in
                        // Filtramos para no mostrarnos a nosotros mismos
                        if user.id != currentUserId {
                            Button(action: { onUserSelected(user) }) {
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.blue).frame(width: 40, height: 40)
                                        // Inicial del nombre
                                        Text(String(user.name.prefix(1)))
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(user.name)
                                            .foregroundColor(.white)
                                            .bold()
                                        Text(user.role)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "bubble.right.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
}
