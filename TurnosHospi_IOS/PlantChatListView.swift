import SwiftUI

struct PlantChatListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var viewModel = PlantChatViewModel()
    
    // Estados para modales y navegación
    @State private var showPlantSelector = false
    @State private var navigationPath = NavigationPath() // Para iOS 16+ NavigationStack
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Fondo oscuro (coherente con tu app)
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("Chats con Plantas")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "arrow.left").font(.title2).opacity(0)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    
                    // Lista de chats existentes (Placeholder)
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Tus conversaciones aparecerán aquí.")
                                .foregroundColor(.gray)
                                .padding(.top, 50)
                        }
                    }
                }
                
                // --- BOTÓN FLOTANTE (+) ---
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.fetchMyPlants() // Cargar datos al pulsar
                            showPlantSelector = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Circle())
                                .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            // Navegación programática al chat
            .navigationDestination(for: PlantChatSession.self) { session in
                PlantChatView(session: session)
            }
            // Modal de selección
            .sheet(isPresented: $showPlantSelector) {
                PlantSelectionSheet(viewModel: viewModel) { selectedPlant in
                    showPlantSelector = false
                    // Iniciar chat y navegar
                    viewModel.startChatWithPlant(selectedPlant) { session in
                        // Pequeño delay para dejar cerrar el sheet
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navigationPath.append(session)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}
