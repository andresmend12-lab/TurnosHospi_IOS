import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo espacial estático para el menú
                Color.deepSpace.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Cabecera con saludo y Logout
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Hola, Doctor")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Tus Turnos")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Botón de Salir
                        Button(action: {
                            authManager.signOut()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundColor(.red.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    // --- CALENDARIO ESTILO GLASS ---
                    VStack {
                        DatePicker("Seleccionar Fecha", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .colorScheme(.dark) // Fuerza modo oscuro para que combine
                            .accentColor(.neonViolet) // Color de selección
                            .padding()
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal)
                    
                    // --- LISTA DE EVENTOS (Placeholder) ---
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Eventos para \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundColor(.gray)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Tarjeta de ejemplo
                            HStack {
                                Rectangle()
                                    .fill(Color.electricBlue)
                                    .frame(width: 4)
                                    .cornerRadius(2)
                                
                                VStack(alignment: .leading) {
                                    Text("Guardia en Urgencias")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("20:00 - 08:00")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}
