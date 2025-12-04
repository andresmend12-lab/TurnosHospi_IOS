import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Estado para controlar la visibilidad del menú
    @State private var showMenu = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- CAPA 1: FONDO GENERAL ---
                Color.black.ignoresSafeArea() // Fondo base detrás de todo
                
                // --- CAPA 2: CONTENIDO PRINCIPAL (Dashboard) ---
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // CABECERA: Botón Menú + Bienvenida
                        HStack {
                            // Botón Hamburguesa
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showMenu.toggle()
                                }
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            // Texto de Bienvenida (Alineado a la derecha)
                            VStack(alignment: .trailing) {
                                Text("Bienvenido")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                Text(authManager.currentUserName.isEmpty ? "Usuario" : authManager.currentUserName)
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // CONTENIDO: Calendario y Turnos
                        ScrollView {
                            VStack(spacing: 20) {
                                // Calendario
                                VStack {
                                    DatePicker("Calendario", selection: $selectedDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .colorScheme(.dark)
                                        .accentColor(.neonViolet)
                                        .padding()
                                }
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal)
                                
                                // Lista de Turnos
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Tus Turnos")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    // Tarjeta de ejemplo
                                    HStack {
                                        Rectangle()
                                            .fill(Color.electricBlue)
                                            .frame(width: 4)
                                            .cornerRadius(2)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Guardia Nocturna")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("22:00 - 08:00")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Image(systemName: "moon.stars.fill")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(15)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        
                        Spacer()
                    }
                }
                // EFECTOS DE ANIMACIÓN AL ABRIR EL MENÚ
                .cornerRadius(showMenu ? 30 : 0) // Bordes redondeados al encogerse
                .offset(x: showMenu ? 260 : 0) // Se desplaza a la derecha
                .scaleEffect(showMenu ? 0.85 : 1) // Se hace más pequeño
                .shadow(color: .black.opacity(0.5), radius: showMenu ? 20 : 0, x: -10, y: 0) // Sombra para profundidad
                .disabled(showMenu) // No se puede tocar el calendario si el menú está abierto
                .onTapGesture {
                    // Si tocas el dashboard cuando el menú está abierto, se cierra
                    if showMenu {
                        withAnimation { showMenu = false }
                    }
                }
                
                // --- CAPA 3: MENÚ LATERAL ---
                if showMenu {
                    SideMenuView(isShowing: $showMenu)
                        .frame(width: 260) // Ancho del menú
                        .transition(.move(edge: .leading)) // Aparece desde la izquierda
                        .offset(x: -UIScreen.main.bounds.width / 2 + 130) // Posición fija a la izquierda
                        .zIndex(0) // Se queda "detrás" visualmente, aunque el efecto ZStack lo pone encima si no usáramos el offset de la capa 2.
                }
            }
        }
        .onAppear {
            // Cargar datos si faltan
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
        }
    }
}
