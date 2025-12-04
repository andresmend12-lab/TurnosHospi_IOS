import SwiftUI

struct PlantDetailView: View {
    let plant: Plant
    var onBack: () -> Void
    var onOpenSettings: () -> Void
    
    // Grid layout
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left").foregroundColor(.white)
                    }
                    Spacer()
                    Text(plant.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill").foregroundColor(.white)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Panel de Control")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            DashboardCard(icon: "arrow.triangle.2.circlepath", title: "Cambios de Turno", color: Color(hex: "7C3AED")) {
                                // Navegar a ShiftChange
                            }
                            
                            DashboardCard(icon: "cart.fill", title: "Mercado de Turnos", color: Color(hex: "F59E0B")) {
                                // Navegar a Marketplace
                            }
                            
                            DashboardCard(icon: "chart.bar.fill", title: "Estadísticas", color: Color(hex: "10B981")) {
                                // Navegar a Estadísticas
                            }
                            
                            DashboardCard(icon: "person.2.wave.2.fill", title: "Chat de Grupo", color: Color(hex: "EC4899")) {
                                // Navegar a Chat
                            }
                        }
                        .padding(.horizontal)
                        
                        // Lista de Personal (Simplificada)
                        Text("Personal de Planta")
                            .font(.title3).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        VStack(spacing: 8) {
                            // Mock items
                            StaffRow(name: "Ana Martínez", role: "Supervisora")
                            StaffRow(name: "Carlos Ruiz", role: "Enfermero")
                            StaffRow(name: "Laura Gómez", role: "Auxiliar")
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// Componentes UI auxiliares
struct DashboardCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: icon).foregroundColor(color))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct StaffRow: View {
    let name: String
    let role: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.gray)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(name).foregroundColor(.white)
                Text(role).font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}
