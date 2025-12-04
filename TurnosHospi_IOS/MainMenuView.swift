import SwiftUI

struct MainMenuView: View {
    // Accedemos al AuthManager para leer el nombre del usuario y cerrar sesión
    @EnvironmentObject var authManager: AuthManager
    
    // Estado para el calendario
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- FONDO DEEP SPACE ---
                Color.deepSpace.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // --- CABECERA ---
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            // Lógica del Saludo: Muestra el nombre si existe, o solo "Bienvenido"
                            if authManager.currentUserName.isEmpty {
                                Text("Bienvenido")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text("Bienvenido, \(authManager.currentUserName)")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text("Tus Turnos")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Botón de Cerrar Sesión
                        Button(action: {
                            authManager.signOut()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundColor(.red.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // --- CALENDARIO ESTILO GLASS ---
                    VStack {
                        DatePicker("Seleccionar Fecha", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .colorScheme(.dark) // Fuerza tema oscuro para que se vea bien sobre el fondo
                            .accentColor(.neonViolet)
                            .padding()
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // --- LISTA DE EVENTOS (Ejemplo visual) ---
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Eventos para \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Tarjeta de ejemplo de turno
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
                                
                                Image(systemName: "clock")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.1), lineWidth: 0.5))
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            }
        }
        // Al aparecer la pantalla, intentamos descargar el nombre si aún no lo tenemos
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
        }
    }
}

// Preview para ver cómo queda en Xcode
struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        // Inyectamos un AuthManager de prueba
        MainMenuView()
            .environmentObject(AuthManager())
    }
}
