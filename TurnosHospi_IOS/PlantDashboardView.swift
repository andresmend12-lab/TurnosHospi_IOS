import SwiftUI

struct PlantDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Managers
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager() // <--- Necesario para descargar los turnos de la planta
    
    @State private var isMenuOpen = false
    @State private var selectedOption: String = "Calendario"
    @State private var selectedDate = Date()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // HEADER
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isMenuOpen.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                        .zIndex(100)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Mi Planta")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text(authManager.userRole)
                                .font(.caption)
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .padding(.top, 60)
                    .background(Color.black.opacity(0.3))
                    
                    // CONTENIDO
                    ScrollView {
                        VStack(spacing: 20) {
                            HStack {
                                Text(selectedOption)
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            if selectedOption == "Calendario" {
                                // 1. CALENDARIO
                                CalendarWithShiftsView(selectedDate: $selectedDate, shifts: shiftManager.userShifts)
                                    .onChange(of: selectedDate) { newDate in
                                        // Cuando cambia la fecha, cargamos el personal de ese día
                                        if !authManager.userPlantId.isEmpty {
                                            plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: newDate)
                                        }
                                    }
                                
                                // 2. LISTA DE PERSONAL DEL DÍA (NUEVO)
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Equipo en turno - \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .padding(.top, 10)
                                    
                                    if plantManager.dailyStaff.isEmpty {
                                        Text("No hay registros de personal para este día.")
                                            .foregroundColor(.gray)
                                            .italic()
                                            .padding(.horizontal)
                                            .padding(.bottom, 20)
                                    } else {
                                        // Mostramos los turnos en orden
                                        let turnosOrdenados = ["Mañana", "Media mañana", "Tarde", "Media tarde", "Noche"]
                                        
                                        ForEach(turnosOrdenados, id: \.self) { turno in
                                            if let workers = plantManager.dailyStaff[turno], !workers.isEmpty {
                                                DailyShiftSection(title: turno, workers: workers)
                                            }
                                        }
                                        
                                        // Turnos extra que no estén en la lista ordenada
                                        ForEach(plantManager.dailyStaff.keys.sorted().filter { !turnosOrdenados.contains($0) }, id: \.self) { turno in
                                            if let workers = plantManager.dailyStaff[turno] {
                                                DailyShiftSection(title: turno, workers: workers)
                                            }
                                        }
                                    }
                                }
                                
                            } else {
                                PlantPlaceholderView(iconName: getIconForOption(selectedOption), title: selectedOption)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                
                if isMenuOpen {
                    Color.white.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { isMenuOpen = false } }
                }
            }
            .cornerRadius(isMenuOpen ? 30 : 0)
            .offset(x: isMenuOpen ? 280 : 0, y: isMenuOpen ? 40 : 0)
            .scaleEffect(isMenuOpen ? 0.9 : 1)
            .shadow(color: .black.opacity(0.5), radius: 20, x: -10, y: 0)
            .ignoresSafeArea()
            .disabled(isMenuOpen)
            
            if isMenuOpen {
                PlantMenuDrawer(isMenuOpen: $isMenuOpen, selectedOption: $selectedOption, onLogout: {
                    dismiss()
                })
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            shiftManager.fetchUserShifts()
            // Cargar personal del día de hoy al entrar
            if !authManager.userPlantId.isEmpty {
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: selectedDate)
            }
        }
    }
    
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

// MARK: - SUBVISTA PARA CADA BLOQUE DE TURNO
struct DailyShiftSection: View {
    let title: String
    let workers: [PlantShiftWorker]
    
    var colorForShift: Color {
        switch title {
        case "Mañana": return .yellow
        case "Tarde": return .orange
        case "Noche": return .blue
        default: return .white
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(colorForShift).frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorForShift)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal)
            
            ForEach(workers) { worker in
                HStack(spacing: 15) {
                    // Inicial
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 35, height: 35)
                        .overlay(Text(String(worker.name.prefix(1))).bold().foregroundColor(.white))
                    
                    VStack(alignment: .leading) {
                        Text(worker.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(worker.role)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 10)
    }
}

// MARK: - COMPONENTES AUXILIARES (Drawer, Placeholder)
struct PlantMenuDrawer: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isMenuOpen: Bool
    @Binding var selectedOption: String
    var onLogout: () -> Void
    
    let menuBackground = Color(red: 26/255, green: 26/255, blue: 46/255)
    
    var body: some View {
        ZStack {
            menuBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 15) {
                    Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)).frame(width: 50, height: 50).overlay(Text(String(authManager.currentUserName.prefix(1))).bold().foregroundColor(.white))
                    VStack(alignment: .leading) { Text(authManager.currentUserName).font(.headline).foregroundColor(.white); Text(authManager.userRole).font(.caption).foregroundColor(.gray) }
                }.padding(.top, 60).padding(.bottom, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        PlantMenuRow(title: "Calendario", icon: "calendar", selected: $selectedOption) { close() }
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
                        
                        if authManager.userRole == "Supervisor" {
                            Group {
                                Text("ADMINISTRACIÓN").font(.caption2).bold().foregroundColor(.gray).padding(.leading, 10)
                                PlantMenuRow(title: "Añadir personal", icon: "person.badge.plus", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Lista de personal", icon: "person.3.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Configuración de la planta", icon: "gearshape.2.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Importar turnos", icon: "square.and.arrow.down", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Gestión de cambios", icon: "arrow.triangle.2.circlepath", selected: $selectedOption) { close() }
                            }
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
                            Group {
                                Text("PERSONAL").font(.caption2).bold().foregroundColor(.gray).padding(.leading, 10)
                                PlantMenuRow(title: "Estadísticas", icon: "chart.bar.xaxis", selected: $selectedOption) { close() }
                            }
                        } else {
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
                Button(action: onLogout) { HStack { Image(systemName: "arrow.left.circle.fill"); Text("Volver al menú principal").bold() }.foregroundColor(.red.opacity(0.9)).padding().frame(maxWidth: .infinity, alignment: .leading) }.padding(.bottom, 30)
            }.padding(.horizontal).frame(maxWidth: 280, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    func close() { withAnimation { isMenuOpen = false } }
}

struct PlantMenuRow: View {
    let title: String; let icon: String; @Binding var selected: String; let action: () -> Void
    var body: some View {
        Button(action: { selected = title; action() }) {
            HStack(spacing: 15) { Image(systemName: icon).font(.system(size: 18)).frame(width: 30).foregroundColor(selected == title ? Color(red: 0.7, green: 0.5, blue: 1.0) : .white.opacity(0.7)); Text(title).font(.subheadline).foregroundColor(selected == title ? .white : .white.opacity(0.7)).bold(selected == title); Spacer() }
            .padding(.vertical, 12).padding(.horizontal, 10).background(selected == title ? Color.white.opacity(0.1) : Color.clear).cornerRadius(10)
        }
    }
}

// Helper: Placeholder renombrado
struct PlantPlaceholderView: View {
    let iconName: String; let title: String
    var body: some View {
        VStack(spacing: 20) { Spacer(); Image(systemName: iconName).font(.system(size: 60)).foregroundColor(.white.opacity(0.3)); Text("Sección: \(title)").font(.title2).foregroundColor(.white.opacity(0.5)); Spacer() }.frame(height: 300)
    }
}
