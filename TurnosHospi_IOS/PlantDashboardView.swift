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
                                        // MODIFICADO: Ahora pasa monthlyAssignments
                                        CalendarWithShiftsView(
                                            selectedDate: $selectedDate,
                                            shifts: shiftManager.userShifts,
                                            monthlyAssignments: plantManager.monthlyAssignments
                                        )
                                        .onChange(of: selectedDate) { newDate in
                                            if !plantId.isEmpty {
                                                // Cargar staff del día seleccionado para la lista de abajo
                                                plantManager.fetchDailyStaff(plantId: plantId, date: newDate)
                                            }
                                            // NUEVO: Recargar el calendario si el mes cambia
                                            if !Calendar.current.isDate(newDate, equalTo: selectedDate, toGranularity: .month) {
                                                if !plantId.isEmpty {
                                                    plantManager.fetchMonthlyAssignments(plantId: plantId, month: newDate)
                                                }
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
                // Cargar el staff del día seleccionado
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: selectedDate)
                // NUEVO: Cargar el staff del mes para el calendario
                plantManager.fetchMonthlyAssignments(plantId: authManager.userPlantId, month: selectedDate)
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

// ------------------------------------------------------------------------------------------------------------------

// MARK: - NUEVAS VISTAS PARA ASIGNACIÓN DE TURNOS
struct ShiftAssignmentView: View {
    let plant: HospitalPlant
    @Binding var selectedDate: Date
    @ObservedObject var plantManager: PlantManager
    let availableRoles: [String]
    
    // MODIFICADO: Lista de turnos a mostrar en orden preferido (Mañana, Tarde, Noche)
    var orderedShiftNames: [String] {
        let preferredOrder = ["Mañana", "Media mañana", "Tarde", "Media tarde", "Noche", "Día"]
        
        // Se obtiene el Set<String> de claves del diccionario, asegurando un tipo compatible
        let existingKeys = Set(plant.shiftTimes?.keys ?? [String: [String: String]]().keys)
        
        // 1. Filtrar el orden preferido por las claves que realmente existen
        let filteredList = preferredOrder.filter { existingKeys.contains($0) }
        
        // 2. Añadir cualquier clave que exista pero no esté en el orden preferido (turnos custom)
        let customKeys = existingKeys.filter { !filteredList.contains($0) }
        
        // Conversión a Array para la concatenación.
        let finalOrder = filteredList + Array(customKeys)

        return finalOrder
    }
    
    // Lista completa de staff para el Picker (incluye 'Ninguno')
    var assignableStaff: [PlantStaff?] {
        // Incluir una opción "Ninguno" (nil) para desasignar
        var list: [PlantStaff?] = [nil]
        // Añadir solo Enfermero y TCAE a la lista de asignables (excluyendo Supervisor, que no debe ser asignado)
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
                // MODIFICADO: Usar orderedShiftNames para forzar el orden M-T-N
                ForEach(orderedShiftNames, id: \.self) { shiftName in
                    // Asignación solo para turno completo (Mañana/Tarde/Noche o Día/Noche)
                    if shiftName.contains("Mañana") || shiftName.contains("Tarde") || shiftName.contains("Noche") || shiftName.contains("Día") {
                        ShiftAssignmentRow(
                            shiftName: shiftName,
                            plant: plant,
                            selectedDate: $selectedDate,
                            plantManager: plantManager,
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
    @ObservedObject var plantManager: PlantManager
    let assignableStaff: [PlantStaff?]
    let dailyAssignments: [String: [PlantShiftWorker]] // <--- PROPIEDAD REQUERIDA
    let availableRoles: [String]
    
    // MODIFICADO: Lógica de guardado simplificada (sobrescribe todo el turno para este slot)
    func handleAssignment(worker: PlantStaff?, forSlotIndex index: Int) {
        
        let dbRef = Database.database().reference()
        
        // 1. Obtener la lista local de PlantShiftWorker para este turno (copia)
        var currentWorkers = dailyAssignments[shiftName] ?? []
        
        // 2. Obtener el número total de slots (requisito mínimo)
        let totalSlots = plant.staffRequirements?[shiftName] ?? 0
        
        // Asegurar que la lista no exceda el límite (aunque debería ser manejado por la UI)
        if currentWorkers.count > totalSlots {
            currentWorkers = Array(currentWorkers.prefix(totalSlots))
        }
        
        // Convert PlantStaff to PlantShiftWorker for consistent array storage
        let newWorkerShift: PlantShiftWorker? = worker.map { PlantShiftWorker(id: $0.id, name: $0.name, role: $0.role) }
        
        if let newStaff = newWorkerShift {
            // ASIGNAR/RE-ASIGNAR
            
            // 2a. Remover el nuevo trabajador si ya estaba en la lista para evitar duplicados.
            currentWorkers.removeAll(where: { $0.id == newStaff.id })
            
            // 2b. Insertar en el slot, asegurando que se respete el índice.
            
            // Rellenamos con un trabajador temporal "VACÍO" si es necesario para alcanzar el índice
            while currentWorkers.count < index {
                // Usamos un ID único temporal que será filtrado al guardar
                currentWorkers.append(PlantShiftWorker(id: UUID().uuidString, name: "VACÍO", role: "VACÍO"))
            }
            
            // Si el índice existe (porque lo rellenamos o ya existía)
            if currentWorkers.indices.contains(index) {
                // Reemplazar el elemento en el slot (puede ser un "VACÍO" o un trabajador)
                currentWorkers[index] = newStaff
            } else if currentWorkers.count == index {
                // Si el índice es exactamente el siguiente (y hay espacio)
                currentWorkers.append(newStaff)
            }
            
            // Aseguramos que solo haya 'totalSlots' elementos
            if currentWorkers.count > totalSlots {
                currentWorkers = Array(currentWorkers.prefix(totalSlots))
            }
            
        } else {
            // DESASIGNAR (worker es nil)
            // Si el slot contenía un trabajador real, lo quitamos por su ID.
            if currentWorkers.indices.contains(index) {
                let workerToRemove = currentWorkers[index]
                currentWorkers.removeAll(where: { $0.id == workerToRemove.id })
            }
        }
        
        // 3. Preparar el objeto para guardar el turno COMPLETO en Firebase (sobreescribir)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        
        let shiftPath = dbRef.child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateString)")
            .child(shiftName)
        
        var firebaseUpdates: [String: Any] = [:]
        
        // Filtrar elementos 'VACÍO' o no asignados que hayan podido colarse
        let finalWorkersToSave = currentWorkers.filter { $0.role != "VACÍO" && $0.name != "VACÍO" }
        
        if !finalWorkersToSave.isEmpty {
            for worker in finalWorkersToSave {
                // Convertimos la lista de vuelta al formato de diccionario de Firebase (ID como Key)
                firebaseUpdates[worker.id] = [
                    "name": worker.name,
                    "role": worker.role
                ]
            }
            // Sobreescribir el nodo completo del turno
            shiftPath.setValue(firebaseUpdates)
        } else {
            // Eliminar el turno si la lista queda vacía
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

// MODIFICADO: Picker de selección de personal (ahora usa una propiedad calculada en lugar de @State)
struct StaffSlotPicker: View {
    let index: Int
    let shiftName: String
    let plant: HospitalPlant
    let assignableStaff: [PlantStaff?]
    let dailyAssignments: [String: [PlantShiftWorker]]
    let onAssign: (PlantStaff?) -> Void
    
    // Nueva propiedad calculada para el personal seleccionado en este slot
    var selectedStaff: PlantStaff? {
        // 1. Obtener los trabajadores asignados
        let assignedWorkers = dailyAssignments[shiftName] ?? []
        
        // 2. Mapear los PlantShiftWorker a PlantStaff (con los detalles completos)
        let assignedList = assignedWorkers.compactMap { worker in
            plant.allStaffList.first(where: { $0.id == worker.id })
        }
        
        // 3. Devolver el trabajador en el índice (slot) si existe
        return assignedList.indices.contains(index) ? assignedList[index] : nil
    }

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
                    onAssign(nil)
                }
                
                // Opciones de personal
                ForEach(assignableStaff.compactMap { $0 }, id: \.id) { staff in
                    Button("\(staff.name) (\(staff.role))") {
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
// ------------------------------------------------------------------------------------------------------------------

// MARK: - EXTENSIONES Y OTRAS SUBVISTAS (Mantienen la funcionalidad existente)

// Extensión para simplificar el formato de fecha (necesario en ShiftAssignmentView)
extension DateFormatter {
    func dateString(from date: Date) -> String {
        self.dateFormat = "yyyy-MM-dd"
        return self.string(from: date)
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
        case "Día", "Turno de Día": return .yellow
        case "Turno de Noche": return .blue
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
                let turnosOrdenados = ["Mañana", "Media mañana", "Tarde", "Media tarde", "Noche", "Día", "Turno de Día", "Turno de Noche"]
                
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

struct PlantPlaceholderView: View {
    let iconName: String; let title: String
    var body: some View {
        VStack(spacing: 20) { Spacer(); Image(systemName: iconName).font(.system(size: 60)).foregroundColor(.white.opacity(0.3)); Text("Sección: \(title)").font(.title2).foregroundColor(.white.opacity(0.5)); Spacer() }.frame(height: 300)
    }
}
