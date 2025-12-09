import SwiftUI

struct PlantSelectionSheet: View {
    @ObservedObject var viewModel: PlantChatViewModel
    var onSelect: (UserPlant) -> Void
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Iniciar chat con...")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.myPlants.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No tienes plantas registradas")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    List(viewModel.myPlants) { plant in
                        Button(action: { onSelect(plant) }) {
                            HStack(spacing: 15) {
                                // Avatar de planta
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    if let url = plant.imageUrl, let _ = URL(string: url) {
                                        // Aquí iría tu AsyncImage si tienes URL
                                        Image(systemName: "leaf.fill").foregroundColor(.green)
                                    } else {
                                        Image(systemName: "leaf.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plant.nickname)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(plant.species)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "message.fill")
                                    .foregroundColor(.electricBlue)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                Spacer()
            }
        }
    }
}
