import SwiftUI
import FirebaseDatabase // Necesario para guardar las asignaciones

// MARK: - PLANT DASHBOARD VIEW
struct PlantDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Managers
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager()
    
    @State private var isMenuOpen = false
    @State private var selectedOption: String = "Calendario"
    @State private var selectedDate = Date()
    
    // Helper para obtener el staffScope de forma segura
    var staffScope: String {
        return plantManager.currentPlant?.staffScope ?? "nurses_only"
    }
    
    // Helper: Roles a tener en cuenta para la asignación
    var availableRoles: [String] {
        var roles = ["Enfermero"]
        if staffScope == "nurses_and_aux" {
            roles.append("TCAE") // Auxiliar
        }
        return roles
    }
    
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
                    VStack(spacing: 20) {
                        
                        // Título de la sección
                        HStack {
                            Text(selectedOption)
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Lógica de Vistas
                        Group {
                            let plantId = authManager.userPlantId
                            
                            switch selectedOption {
                            case "Calendario":
                                ScrollView {
                                    VStack(spacing: 20) {
                                        // 1. CALENDARIO
                                        CalendarWithShiftsView(selectedDate: $selectedDate, shifts: shiftManager.userShifts)
                                            .onChange(of: selectedDate) { newDate in
                                                if !plantId.isEmpty {
                                                    plantManager.fetchDailyStaff(plantId: plantId, date: newDate)
                                                }
                                            }
                                        
                                        // NUEVO: Menú de Asignación de Turnos para Supervisor
                                        if authManager.userRole == "Supervisor" {
                                            if let plant = plantManager.currentPlant,
                                               plant.shiftTimes != nil,
                                               plant.staffRequirements != nil {
                                                ShiftAssignmentView(
                                                    plant: plant,
                                                    selectedDate: $selectedDate,
                                                    plantManager: plantManager,
                                                    availableRoles: availableRoles
                                                )
                                            } else {
                                                Text("Cargando configuración de la planta...")
                                                    .foregroundColor(.gray)
                                                    .padding(.top, 20)
                                            }
                                        } else {
                                            // 2. LISTA DE PERSONAL DEL DÍA (para roles que no son Supervisor)
                                            DailyStaffContent(selectedDate: $selectedDate, plantManager: plantManager)
                                                .padding(.bottom, 100)
                                        }
                                    }
                                }

                            case "Lista de personal":
                                if !plantId.isEmpty && !staffScope.isEmpty {
                                    StaffListView(plantId: plantId, staffScope: staffScope)
                                        .padding(.horizontal)
                                } else {
                                    Text("Cargando lista de personal...").foregroundColor(.gray).padding(.top, 50)
                                    Spacer()
                                }

                            default:
                                ScrollView {
                                    PlantPlaceholderView(iconName: getIconForOption(selectedOption), title: selectedOption)
                                        .padding(.top, 50)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                PlantMenuDrawer(
                    isMenuOpen: $isMenuOpen,
                    selectedOption: $selectedOption,
                    onLogout: { dismiss() }
                )
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            shiftManager.fetchUserShifts()
            if !authManager.userPlantId.isEmpty {
                // Cargar los detalles de la planta y la lista de staff completa
                plantManager.fetchCurrentPlant(plantId: authManager.userPlantId)
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: selectedDate)
            }
        }
    }
    
    // ... (existing getIconForOption function)
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

// MARK: - NUEVAS VISTAS PARA ASIGNACIÓN DE TURNOS
struct ShiftAssignmentView: View {
    let plant: HospitalPlant
    @Binding var selectedDate: Date
    @ObservedObject var plantManager: PlantManager
    let availableRoles: [String]
    
    // Lista de turnos a mostrar
    var shiftNames: [String] {
        return plant.shiftTimes?.keys.sorted() ?? []
    }
    
    // Lista completa de staff para el Picker (incluye 'Ninguno')
    var assignableStaff: [PlantStaff?] {
        // Incluir una opción "Ninguno" (nil) para desasignar
        var list: [PlantStaff?] = [nil]
        // Añadir solo Enfermero y TCAE a la lista de asignables (excluyendo Supervisor)
        let filteredStaff = plant.allStaffList.filter { $0.role != "Supervisor" }
        list.append(contentsOf: filteredStaff.map { $0 })
        return list
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Asignar Personal - \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                ForEach(shiftNames, id: \.self) { shiftName in
                    // Asignación solo para turno completo (Mañana/Tarde/Noche o Día/Noche)
                    if shiftName.contains("Mañana") || shiftName.contains("Tarde") || shiftName.contains("Noche") || shiftName.contains("Día") {
                        ShiftAssignmentRow(
                            shiftName: shiftName,
                            plant: plant,
                            selectedDate: $selectedDate,
                            assignableStaff: assignableStaff,
                            dailyAssignments: plantManager.dailyAssignments,
                            availableRoles: availableRoles
                        )
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal)
            
            Spacer().frame(height: 50)
        }
    }
}

// Subvista para cada turno (Mañana/Tarde/Noche)
struct ShiftAssignmentRow: View {
    let shiftName: String
    let plant: HospitalPlant
    @Binding var selectedDate: Date
    let assignableStaff: [PlantStaff?]
    let dailyAssignments: [String: [PlantShiftWorker]]
    let availableRoles: [String]
    
    // Función de guardado simplificada (sobrescribe todo el turno para este slot)
    func handleAssignment(worker: PlantStaff?, forSlotIndex index: Int) {
        
        let dbRef = Database.database().reference()
        
        // 1. Obtener la lista actual de PlantStaff
        var currentWorkers = dailyAssignments[shiftName]?
            .compactMap { worker in
                plant.allStaffList.first(where: { $0.id == worker.id })
            } ?? []
        
        // El número de slots es el requisito mínimo
        let totalSlots = plant.staffRequirements?[shiftName] ?? 0

        if let newStaff = worker {
            // ASIGNAR/RE-ASIGNAR
            
            // Si el nuevo trabajador ya está en la lista, lo quitamos para re-insertarlo o ignorar
            currentWorkers.removeAll(where: { $0.id == newStaff.id })
            
            // Insertar el nuevo trabajador en el "slot" (índice)
            // Si el índice es mayor que el array, se añade al final (lo cual es aceptable para simular el siguiente slot disponible)
            if currentWorkers.indices.contains(index) {
                currentWorkers.insert(newStaff, at: index)
                currentWorkers.remove(at: index + 1) // Remove the old worker at the same index
            } else if currentWorkers.count < totalSlots {
                currentWorkers.append(newStaff) // Añadir al final si hay espacio
            }
            
        } else {
            // DESASIGNAR (quitar el worker del slot si existe)
            if currentWorkers.indices.contains(index) {
                // Como no sabemos el ID del worker a desasignar directamente del Picker,
                // eliminamos el elemento en el índice (slot)
                currentWorkers.remove(at: index)
            }
        }
        
        // 2. Guardar la lista COMPLETA de trabajadores en Firebase
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        
        let shiftPath = dbRef.child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateString)")
            .child(shiftName)
        
        var firebaseUpdates: [String: Any] = [:]
        
        if !currentWorkers.isEmpty {
            for worker in currentWorkers {
                firebaseUpdates[worker.id] = [
                    "name": worker.name,
                    "role": worker.role
                ]
            }
            shiftPath.setValue(firebaseUpdates)
        } else {
            shiftPath.removeValue()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(shiftName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(plant.shiftTimes?[shiftName]?["start"] ?? "-")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("-")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(plant.shiftTimes?[shiftName]?["end"] ?? "-")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 5)
            
            VStack(spacing: 10) {
                // Crear un slot por cada requisito mínimo
                ForEach(0..<(plant.staffRequirements?[shiftName] ?? 0), id: \.self) { index in
                    StaffSlotPicker(
                        index: index,
                        shiftName: shiftName,
                        plant: plant,
                        assignableStaff: assignableStaff,
                        dailyAssignments: dailyAssignments,
                        onAssign: { worker in
                            handleAssignment(worker: worker, forSlotIndex: index)
                        }
                    )
                }
            }
        }
    }
}

// Picker de selección de personal
struct StaffSlotPicker: View {
    let index: Int
    let shiftName: String
    let plant: HospitalPlant
    let assignableStaff: [PlantStaff?]
    let dailyAssignments: [String: [PlantShiftWorker]]
    let onAssign: (PlantStaff?) -> Void
    
    // Estado local para el Picker (inicializado con el trabajador asignado)
    @State private var selectedStaff: PlantStaff? = nil

    init(index: Int, shiftName: String, plant: HospitalPlant, assignableStaff: [PlantStaff?], dailyAssignments: [String: [PlantShiftWorker]], onAssign: @escaping (PlantStaff?) -> Void) {
        self.index = index
        self.shiftName = shiftName
        self.plant = plant
        self.assignableStaff = assignableStaff
        self.dailyAssignments = dailyAssignments
        self.onAssign = onAssign
        
        // Obtener el trabajador asignado al slot
        let assignedList = dailyAssignments[shiftName]?.compactMap { worker in
            plant.allStaffList.first(where: { $0.id == worker.id })
        } ?? []
        
        // Intentar inicializar el estado
        if assignedList.indices.contains(index) {
            _selectedStaff = State(initialValue: assignedList[index])
        } else {
            _selectedStaff = State(initialValue: nil)
        }
    }
    
    // Define el rol esperado en este slot (simplificado a un solo tipo de slot)
    var expectedRole: String {
        // En una implementación real, se usaría una matriz de requisitos por rol.
        // Aquí, simplemente distinguimos si la planta tiene Auxiliares.
        return plant.staffScope == "nurses_only" ? "Enfermero" : "Personal"
    }

    var body: some View {
        HStack {
            // Título del slot (simplificado)
            Text("Slot \(index + 1) (\(expectedRole))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Picker
            Menu {
                // Opción para desasignar
                Button("Ninguno") {
                    selectedStaff = nil
                    onAssign(nil)
                }
                
                // Opciones de personal
                ForEach(assignableStaff.compactMap { $0 }, id: \.id) { staff in
                    // Mostrar solo personal que NO esté ya asignado en otro slot (excepto el mismo)
                    // Nota: Esta comprobación es limitada y requiere que el estado se refresque rápido.
                    
                    Button("\(staff.name) (\(staff.role))") {
                        selectedStaff = staff
                        onAssign(staff)
                    }
                }
            } label: {
                HStack {
                    Text(selectedStaff?.name ?? "Asignar...")
                        .foregroundColor(.electricBlue)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}


// MARK: - EXTENSIONES Y OTRAS SUBVISTAS (Mantienen la funcionalidad existente)

// Extensión para simplificar el formato de fecha (necesario en ShiftAssignmentView)
extension DateFormatter {
    func dateString(from date: Date) -> String {
        self.dateFormat = "yyyy-MM-dd"
        return self.string(from: date)
    }
}

// ... (rest of the supporting structs: DailyShiftSection, DailyStaffContent, PlantMenuDrawer, PlantMenuRow, PlantPlaceholderView)

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

// Helper para el contenido de la sección de Calendario/Personal del día
struct DailyStaffContent: View {
    @Binding var selectedDate: Date
    @ObservedObject var plantManager: PlantManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Equipo en turno - \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.top, 10)
            
            if plantManager.dailyAssignments.isEmpty {
                Text("No hay registros de personal para este día.")
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            } else {
                // Mostramos los turnos en orden
                let turnosOrdenados = ["Mañana", "Media mañana", "Tarde", "Media tarde", "Noche"]
                
                ForEach(turnosOrdenados, id: \.self) { turno in
                    if let workers = plantManager.dailyAssignments[turno], !workers.isEmpty {
                        DailyShiftSection(title: turno, workers: workers)
                    }
                }
                
                // Turnos extra que no estén en la lista ordenada
                ForEach(plantManager.dailyAssignments.keys.sorted().filter { !turnosOrdenados.contains($0) }, id: \.self) { turno in
                    if let workers = plantManager.dailyAssignments[turno] {
                        DailyShiftSection(title: turno, workers: workers)
                    }
                }
            }
        }
    }
}

// Helper para el contenido visual de la fila (extraído de PlantMenuDrawer)
struct PlantMenuRowContent: View {
    let title: String; let icon: String; let isSelected: Bool
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.system(size: 18)).frame(width: 30).foregroundColor(isSelected ? Color(red: 0.7, green: 0.5, blue: 1.0) : .white.opacity(0.7));
            Text(title).font(.subheadline).foregroundColor(isSelected ? .white : .white.opacity(0.7)).bold(isSelected); Spacer()
        }
        .padding(.vertical, 12).padding(.horizontal, 10).background(isSelected ? Color.white.opacity(0.1) : Color.clear).cornerRadius(10)
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
            PlantMenuRowContent(title: title, icon: icon, isSelected: selected == title)
        }
        .buttonStyle(.plain)
    }
}

// Helper: Placeholder renombrado
struct PlantPlaceholderView: View {
    let iconName: String; let title: String
    var body: some View {
        VStack(spacing: 20) { Spacer(); Image(systemName: iconName).font(.system(size: 60)).foregroundColor(.white.opacity(0.3)); Text("Sección: \(title)").font(.title2).foregroundColor(.white.opacity(0.5)); Spacer() }.frame(height: 300)
    }
}
