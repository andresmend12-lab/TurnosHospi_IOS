import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var authManager: AuthManager
    
    // Estados de navegación
    @State private var showJoinPlantSheet = false
    @State private var showPlantDashboard = false
    @State private var showEditProfileSheet = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.deepSpace], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 30) {
                
                // Cabecera
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
                
                // Opciones
                VStack(alignment: .leading, spacing: 25) {
                    
                    if authManager.userRole == "Supervisor" {
                        MenuOptionRow(icon: "plus.app.fill", text: "Crear nueva planta")
                    }
                    
                    // --- BOTÓN INTELIGENTE "MI PLANTA" ---
                    Button(action: {
                        if !authManager.userPlantId.isEmpty {
                            showPlantDashboard = true // Ir al Dashboard
                        } else {
                            showJoinPlantSheet = true // Ir a Unirse
                        }
                    }) {
                        MenuOptionRow(icon: "bed.double.fill", text: "Mi planta")
                    }
                    
                    Button(action: { showEditProfileSheet = true }) {
                        MenuOptionRow(icon: "person.text.rectangle.fill", text: "Editar perfil")
                    }
                    
                    MenuOptionRow(icon: "gearshape.fill", text: "Configuración")
                }
                .padding(.leading, 10)
                
                Spacer()
                
                Button(action: {
                    authManager.signOut()
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
        // Modales
        .sheet(isPresented: $showJoinPlantSheet) {
            JoinPlantView()
        }
        .fullScreenCover(isPresented: $showPlantDashboard) {
            PlantDashboardView()
        }
        .sheet(isPresented: $showEditProfileSheet) {
            EditProfileView()
        }
    }
}

// Subvista fila de menú
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
        .contentShape(Rectangle())
    }
}
