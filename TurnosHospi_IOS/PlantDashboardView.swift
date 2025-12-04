import SwiftUI

struct PlantDashboardView: View {
    // Para volver al menú principal
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Estado para controlar el menú lateral
    @State private var isMenuOpen = false
    @State private var selectedOption: String = "Calendario"
    
    var body: some View {
        ZStack {
            // Fondo base
            Color.black.ignoresSafeArea()
            
            // --- CAPA 1: CONTENIDO DEL DASHBOARD ---
            ZStack {
                Color.deepSpace.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isMenuOpen.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Mi Planta")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text(authManager.userRole)
                                .font(.caption)
                                .foregroundColor(.neonViolet)
                        }
                        .padding(.trailing)
                    }
                    .background(Color.black.opacity(0.3))
                    
                    // CONTENIDO DINÁMICO
                    ScrollView {
                        VStack(spacing: 20) {
                            HStack {
                                Text(selectedOption)
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Mostramos la vista correspondiente según la opción
                            if selectedOption == "Calendario" {
                                CalendarPreviewView()
                            } else {
                                PlaceholderView(iconName: getIconForOption(selectedOption), title: selectedOption)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            // Efectos al abrir el menú
            .cornerRadius(isMenuOpen ? 30 : 0)
            .offset(x: isMenuOpen ? 280 : 0, y: isMenuOpen ? 40 : 0)
            .scaleEffect(isMenuOpen ? 0.9 : 1)
            .shadow(color: .black.opacity(0.5), radius: 20, x: -10, y: 0)
            .ignoresSafeArea()
            .onTapGesture {
                if isMenuOpen {
                    withAnimation { isMenuOpen = false }
                }
            }
            .disabled(isMenuOpen)
            
            // --- CAPA 2: MENÚ LATERAL ---
            if isMenuOpen {
                PlantMenuDrawer(isMenuOpen: $isMenuOpen, selectedOption: $selectedOption, onLogout: {
                    dismiss()
                })
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
    }
    
    // Iconos para el título
    func getIconForOption(_ option: String) -> String {
        switch option {
        case "Añadir personal": return "person.badge.plus"
        case "Lista de personal": return "person.3.fill"
        case "Configuración de la planta": return "gearshape.2.fill"
        case "Importar turnos": return "square.and.arrow.down"
        case "Gestión de cambios": return "arrow.triangle.2.circlepath"
        case "Invitar compañeros": return "envelope.fill"
        case "Días de vacaciones": return "sun.max.fill"
        case "Chat de grupo": return "bubble.left.and.bubble.right.fill"
        case "Estadísticas": return "chart.bar.xaxis"
        case "Cambio de turnos": return "arrow.triangle.2.circlepath"
        case "Bolsa de Turnos": return "briefcase.fill"
        default: return "calendar"
        }
    }
}

// MARK: - MENÚ LATERAL (DRAWER)
struct PlantMenuDrawer: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isMenuOpen: Bool
    @Binding var selectedOption: String
    var onLogout: () -> Void
    
    // Color de fondo del menú (Azul muy oscuro)
    let menuBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        ZStack {
            menuBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                
                // Perfil Resumido
                HStack(spacing: 15) {
                    Circle()
                        .fill(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(authManager.currentUserName.prefix(1)))
                                .bold()
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(authManager.currentUserName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(authManager.userRole)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 50)
                .padding(.bottom, 20)
                
                // Opciones
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        
                        PlantMenuRow(title: "Calendario", icon: "calendar", selected: $selectedOption) { close() }
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
                        
                        if authManager.userRole == "Supervisor" {
                            // --- SUPERVISOR ---
                            Group {
                                Text("ADMINISTRACIÓN").font(.caption2).bold().foregroundColor(.gray).padding(.leading, 10)
                                
                                PlantMenuRow(title: "Añadir personal", icon: "person.badge.plus", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Lista de personal", icon: "person.3.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Configuración de la planta", icon: "gearshape.2.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Importar turnos", icon: "square.and.arrow.down", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Gestión de cambios", icon: "arrow.triangle.2.circlepath", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Invitar compañeros", icon: "envelope.fill", selected: $selectedOption) { close() }
                            }
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
                            
                            Group {
                                Text("PERSONAL").font(.caption2).bold().foregroundColor(.gray).padding(.leading, 10)
                                PlantMenuRow(title: "Días de vacaciones", icon: "sun.max.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Chat de grupo", icon: "bubble.left.and.bubble.right.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Estadísticas", icon: "chart.bar.xaxis", selected: $selectedOption) { close() }
                            }
                            
                        } else {
                            // --- PERSONAL ---
                            Text("PERSONAL").font(.caption2).bold().foregroundColor(.gray).padding(.leading, 10)
                            
                            PlantMenuRow(title: "Días de vacaciones", icon: "sun.max.fill", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Chat de grupo", icon: "bubble.left.and.bubble.right.fill", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Cambio de turnos", icon: "arrow.triangle.2.circlepath", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Bolsa de Turnos", icon: "briefcase.fill", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Estadísticas", icon: "chart.bar.xaxis", selected: $selectedOption) { close() }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onLogout) {
                    HStack {
                        Image(systemName: "arrow.left.circle.fill")
                        Text("Volver al menú principal")
                            .bold()
                    }
                    .foregroundColor(.red.opacity(0.9))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal)
            .frame(maxWidth: 280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    func close() {
        withAnimation { isMenuOpen = false }
    }
}

// Fila del menú
struct PlantMenuRow: View {
    let title: String
    let icon: String
    @Binding var selected: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            selected = title
            action()
        }) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 30)
                    .foregroundColor(selected == title ? .neonViolet : .white.opacity(0.7))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(selected == title ? .white : .white.opacity(0.7))
                    .bold(selected == title)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(selected == title ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
    }
}

// Calendario Visual
struct CalendarPreviewView: View {
    let days = ["L", "M", "X", "J", "V", "S", "D"]
    let dates = Array(1...31)
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Diciembre 2025")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                HStack {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.electricBlue)
            }
            .padding(.horizontal)
            
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                ForEach(dates, id: \.self) { date in
                    let isToday = date == 4
                    VStack {
                        Text("\(date)")
                            .foregroundColor(isToday ? .black : .white)
                            .font(.system(size: 14))
                            .frame(width: 30, height: 30)
                            .background(isToday ? Color.white : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(height: 40)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
}

// Placeholder
struct PlaceholderView: View {
    let iconName: String
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Sección: \(title)")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            
            Text("Esta funcionalidad está en desarrollo.")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(height: 300)
    }
}
