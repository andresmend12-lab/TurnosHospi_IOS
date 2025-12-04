import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var authManager: AuthManager
    
    // Estados para controlar la navegación a las diferentes pantallas
    @State private var showJoinPlantSheet = false
    @State private var showPlantDashboard = false
    @State private var showEditProfileSheet = false
    
    var body: some View {
        ZStack {
            // Fondo degradado oscuro para el menú
            LinearGradient(colors: [Color.black, Color.deepSpace], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 30) {
                
                // --- CABECERA DEL USUARIO ---
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.currentUserName.isEmpty ? "Usuario" : authManager.currentUserName)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(authManager.userRole)
                            .font(.subheadline)
                            .foregroundColor(.neonViolet)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 50)
                .padding(.leading, 10)
                
                Divider().background(Color.white.opacity(0.3))
                
                // --- OPCIONES DEL MENÚ ---
                VStack(alignment: .leading, spacing: 25) {
                    
                    // Opción exclusiva para Supervisores
                    if authManager.userRole == "Supervisor" {
                        MenuOptionRow(icon: "plus.app.fill", text: "Crear nueva planta")
                    }
                    
                    // --- BOTÓN INTELIGENTE "MI PLANTA" ---
                    Button(action: {
                        // Verificamos si el usuario ya tiene un ID de planta guardado
                        if !authManager.userPlantId.isEmpty {
                            // CASO A: Ya tiene planta -> Abrir Dashboard
                            showPlantDashboard = true
                        } else {
                            // CASO B: No tiene planta -> Abrir Buscador para unirse
                            showJoinPlantSheet = true
                        }
                    }) {
                        MenuOptionRow(icon: "bed.double.fill", text: "Mi planta")
                    }
                    
                    // Botón Editar Perfil
                    Button(action: {
                        showEditProfileSheet = true
                    }) {
                        MenuOptionRow(icon: "person.text.rectangle.fill", text: "Editar perfil")
                    }
                    
                    // Botón Configuración
                    MenuOptionRow(icon: "gearshape.fill", text: "Configuración")
                }
                .padding(.leading, 10)
                
                Spacer()
                
                // --- BOTÓN CERRAR SESIÓN ---
                Button(action: {
                    authManager.signOut()
                    // Cerrar el menú al salir
                    withAnimation { isShowing = false }
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                        Text("Cerrar Sesión")
                            .font(.headline)
                    }
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.leading, 10)
                    .padding(.bottom, 50)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // --- GESTIÓN DE NAVEGACIÓN (HOJAS Y PANTALLAS) ---
        
        // 1. Pantalla para Unirse a Planta (Sheet)
        .sheet(isPresented: $showJoinPlantSheet) {
            JoinPlantView()
        }
        
        // 2. Pantalla Principal de la Planta (Full Screen)
        .fullScreenCover(isPresented: $showPlantDashboard) {
            PlantDashboardView()
        }
        
        // 3. Pantalla de Editar Perfil (Sheet)
        .sheet(isPresented: $showEditProfileSheet) {
            EditProfileView()
        }
    }
}

// Componente visual para las filas del menú
struct MenuOptionRow: View {
    var icon: String
    var text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 24)
                .foregroundColor(.white.opacity(0.7))
            
            Text(text)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
        }
        .contentShape(Rectangle()) // Hace pulsable toda la fila
    }
}
