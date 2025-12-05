import SwiftUI
import FirebaseDatabase

// MARK: - MODELOS LOCALES PARA LA ASIGNACIÓN (iOS, análogo a Android)

struct SlotAssignment: Identifiable, Equatable {
    let id = UUID()
    var primaryName: String = ""
    var secondaryName: String = ""
    var hasHalfDay: Bool = false
}

struct ShiftAssignmentState: Equatable {
    var nurseSlots: [SlotAssignment] = []
    var auxSlots: [SlotAssignment] = []
}

// MARK: - PLANT DASHBOARD VIEW

struct PlantDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager()
    
    @State private var isMenuOpen = false
    @State private var selectedOption: String = "Calendario"
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    // Estado local de asignaciones para el día seleccionado (como en Android)
    @State private var currentAssignments: [String: ShiftAssignmentState] = [:]
    @State private var isLoadingAssignments = false
    @State private var isAssignmentsLoaded = false
    @State private var isSavingAssignments = false
    @State private var saveStatusMessage: String?
    
    var staffScope: String {
        plantManager.currentPlant?.staffScope ?? "nurses_only"
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
                        
                        HStack {
                            Text(selectedOption)
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        Group {
                            let plantId = authManager.userPlantId
                            
                            switch selectedOption {
                            case "Calendario":
                                ScrollView {
                                    VStack(spacing: 20) {
                                        
                                        // CALENDARIO
                                        CalendarWithShiftsView(
                                            selectedDate: $selectedDate,
                                            shifts: shiftManager.userShifts,
                                            monthlyAssignments: plantManager.monthlyAssignments
                                        )
                                        .onChange(of: selectedDate) { newDate in
                                            let calendar = Calendar.current
                                            
                                            if !plantId.isEmpty {
                                                plantManager.fetchDailyStaff(plantId: plantId, date: newDate)
                                            }
                                            
                                            if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                                                currentMonth = newDate
                                                if !plantId.isEmpty {
                                                    plantManager.fetchMonthlyAssignments(plantId: plantId, month: newDate)
                                                }
                                            }
                                            
                                            // Cargar asignaciones detalladas para el supervisor (como Android)
                                            loadAssignmentsForSelectedDate()
                                        }
                                        
                                        // CONTENIDO BAJO EL CALENDARIO
                                        if authManager.userRole == "Supervisor",
                                           let plant = plantManager.currentPlant,
                                           !plantId.isEmpty {
                                            
                                            SupervisorAssignmentsSection(
                                                plant: plant,
                                                assignments: $currentAssignments,
                                                selectedDate: selectedDate,
                                                isLoading: isLoadingAssignments,
                                                isSaving: isSavingAssignments,
                                                statusMessage: saveStatusMessage,
                                                onSave: {
                                                    saveAssignmentsForSelectedDate(plant: plant, plantId: plantId)
                                                }
                                            )
                                            .padding(.bottom, 40)
                                            
                                        } else {
                                            // Vista para personal no supervisor: listado del equipo en turno
                                            DailyStaffContent(
                                                selectedDate: $selectedDate,
                                                plantManager: plantManager
                                            )
                                            .padding(.bottom, 80)
                                        }
                                    }
                                }
                                
                            case "Lista de personal":
                                if !plantId.isEmpty && !staffScope.isEmpty {
                                    StaffListView(plantId: plantId, staffScope: staffScope)
                                        .padding(.horizontal)
                                } else {
                                    Text("Cargando lista de personal...")
                                        .foregroundColor(.gray)
                                        .padding(.top, 50)
                                    Spacer()
                                }
                                
                            default:
                                ScrollView {
                                    PlantPlaceholderView(
                                        iconName: getIconForOption(selectedOption),
                                        title: selectedOption
                                    )
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
                        .onTapGesture {
                            withAnimation { isMenuOpen = false }
                        }
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
                let plantId = authManager.userPlantId
                plantManager.fetchCurrentPlant(plantId: plantId)
                plantManager.fetchDailyStaff(plantId: plantId, date: selectedDate)
                currentMonth = selectedDate
                plantManager.fetchMonthlyAssignments(plantId: plantId, month: selectedDate)
            }
            if authManager.userRole == "Supervisor" {
                loadAssignmentsForSelectedDate()
            }
        }
        .onChange(of: selectedDate) { _ in
            if authManager.userRole == "Supervisor" {
                loadAssignmentsForSelectedDate()
            }
        }
    }
    
    // MARK: - Helpers de lógica
    
    private func loadAssignmentsForSelectedDate() {
        guard authManager.userRole == "Supervisor",
              let plant = plantManager.currentPlant else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        
        isLoadingAssignments = true
        isAssignmentsLoaded = false
        saveStatusMessage = nil
        
        let dbRef = Database.database().reference()
        let dayRef = dbRef
            .child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateKey)")
        
        dayRef.observeSingleEvent(of: .value) { snapshot in
            var result: [String: ShiftAssignmentState] = [:]
            let unassigned = "Sin asignar"
            
            if snapshot.exists() {
                for child in snapshot.children {
                    guard let shiftSnap = child as? DataSnapshot else { continue }
                    let shiftName = shiftSnap.key
                    
                    // NURSES
                    var nurseSlots: [SlotAssignment] = []
                    let nursesSnap = shiftSnap.childSnapshot(forPath: "nurses")
                    let nurseChildren = (nursesSnap.children.allObjects as? [DataSnapshot])?
                        .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) } ?? []
                    
                    for slotSnap in nurseChildren {
                        if let dict = slotSnap.value as? [String: Any] {
                            let halfDay = dict["halfDay"] as? Bool ?? false
                            let primary = (dict["primary"] as? String ?? "")
                            let secondary = (dict["secondary"] as? String ?? "")
                            let slot = SlotAssignment(
                                primaryName: primary == unassigned ? "" : primary,
                                secondaryName: secondary == unassigned ? "" : secondary,
                                hasHalfDay: halfDay
                            )
                            nurseSlots.append(slot)
                        }
                    }
                    
                    // AUXILIARIES
                    var auxSlots: [SlotAssignment] = []
                    let auxSnap = shiftSnap.childSnapshot(forPath: "auxiliaries")
                    let auxChildren = (auxSnap.children.allObjects as? [DataSnapshot])?
                        .sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) } ?? []
                    
                    for slotSnap in auxChildren {
                        if let dict = slotSnap.value as? [String: Any] {
                            let halfDay = dict["halfDay"] as? Bool ?? false
                            let primary = (dict["primary"] as? String ?? "")
                            let secondary = (dict["secondary"] as? String ?? "")
                            let slot = SlotAssignment(
                                primaryName: primary == unassigned ? "" : primary,
                                secondaryName: secondary == unassigned ? "" : secondary,
                                hasHalfDay: halfDay
                            )
                            auxSlots.append(slot)
                        }
                    }
                    
                    result[shiftName] = ShiftAssignmentState(
                        nurseSlots: nurseSlots,
                        auxSlots: auxSlots
                    )
                }
            }
            
            // Asegurar que todos los turnos definidos en la planta aparecen
            if let shiftTimes = plant.shiftTimes {
                for shiftName in shiftTimes.keys {
                    if result[shiftName] == nil {
                        let required = plant.staffRequirements?[shiftName] ?? 1
                        let nurseSlots = Array(repeating: SlotAssignment(), count: max(1, required))
                        let auxSlots: [SlotAssignment] =
                            plant.staffScope == "nurses_and_aux"
                            ? Array(repeating: SlotAssignment(), count: required)
                            : []
                        result[shiftName] = ShiftAssignmentState(
                            nurseSlots: nurseSlots,
                            auxSlots: auxSlots
                        )
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.currentAssignments = result
                self.isLoadingAssignments = false
                self.isAssignmentsLoaded = true
            }
        }
    }
    
    private func saveAssignmentsForSelectedDate(plant: HospitalPlant, plantId: String) {
        guard authManager.userRole == "Supervisor" else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        let dbRef = Database.database().reference()
        let dayRef = dbRef
            .child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateKey)")
        
        let unassigned = "Sin asignar"
        var payload: [String: Any] = [:]
        
        for (shiftName, state) in currentAssignments {
            var nursesArray: [[String: Any]] = []
            for (index, slot) in state.nurseSlots.enumerated() {
                nursesArray.append(slot.toFirebaseMap(unassigned: unassigned,
                                                      base: "enfermero\(index + 1)"))
            }
            
            var auxArray: [[String: Any]] = []
            for (index, slot) in state.auxSlots.enumerated() {
                auxArray.append(slot.toFirebaseMap(unassigned: unassigned,
                                                   base: "auxiliar\(index + 1)"))
            }
            
            payload[shiftName] = [
                "nurses": nursesArray,
                "auxiliaries": auxArray
            ]
        }
        
        isSavingAssignments = true
        saveStatusMessage = nil
        
        dayRef.setValue(payload) { error, _ in
            DispatchQueue.main.async {
                self.isSavingAssignments = false
                if let error = error {
                    self.saveStatusMessage = "Error al guardar: \(error.localizedDescription)"
                } else {
                    self.saveStatusMessage = "Cambios guardados"
                    // Refrescar vistas de solo lectura
                    self.plantManager.fetchDailyStaff(plantId: plantId, date: self.selectedDate)
                    self.plantManager.fetchMonthlyAssignments(plantId: plantId, month: self.selectedDate)
                }
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

// MARK: - EXTENSIÓN SlotAssignment (a Firebase)

extension SlotAssignment {
    func toFirebaseMap(unassigned: String, base: String) -> [String: Any] {
        let primaryValue = primaryName.isEmpty ? unassigned : primaryName
        let secondaryValue: String
        let secondaryLabel: String
        
        if hasHalfDay {
            secondaryValue = secondaryName.isEmpty ? unassigned : secondaryName
            secondaryLabel = "\(base) media jornada"
        } else {
            secondaryValue = ""
            secondaryLabel = ""
        }
        
        return [
            "halfDay": hasHalfDay,
            "primary": primaryValue,
            "secondary": secondaryValue,
            "primaryLabel": base,
            "secondaryLabel": secondaryLabel
        ]
    }
}

// MARK: - VISTA SUPERVISOR (editor tipo Android)

struct SupervisorAssignmentsSection: View {
    let plant: HospitalPlant
    @Binding var assignments: [String: ShiftAssignmentState]
    let selectedDate: Date
    let isLoading: Bool
    let isSaving: Bool
    let statusMessage: String?
    let onSave: () -> Void
    
    var nurseOptions: [String] {
        plant.allStaffList
            .filter { $0.role.lowercased().contains("enfermer") }
            .map { $0.name }
            .sorted()
    }
    
    var auxOptions: [String] {
        plant.allStaffList
            .filter {
                let r = $0.role.lowercased()
                return r.contains("aux") || r.contains("tcae")
            }
            .map { $0.name }
            .sorted()
    }
    
    var orderedShiftNames: [String] {
        let preferred = ["Mañana", "Media mañana", "Tarde", "Media tarde", "Noche", "Día", "Turno de Día", "Turno de Noche"]
        let keys = Array(plant.shiftTimes?.keys ?? [])
        let sorted = keys.sorted {
            (preferred.firstIndex(of: $0) ?? 999) < (preferred.firstIndex(of: $1) ?? 999)
        }
        return sorted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Equipo en turno - \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.top, 8)
            
            if isLoading {
                Text("Cargando asignaciones...")
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal)
            }
            
            ForEach(orderedShiftNames, id: \.self) { shiftName in
                let timing = plant.shiftTimes?[shiftName]
                let stateBinding = Binding<ShiftAssignmentState>(
                    get: { assignments[shiftName] ?? ShiftAssignmentState() },
                    set: { assignments[shiftName] = $0 }
                )
                
                SupervisorShiftRow(
                    shiftName: shiftName,
                    timing: timing,
                    state: stateBinding,
                    allowAux: plant.staffScope == "nurses_and_aux",
                    nurseOptions: nurseOptions,
                    auxOptions: auxOptions
                )
                .padding(.horizontal)
            }
            
            if let status = statusMessage {
                Text(status)
                    .foregroundColor(status.contains("Error") ? .red : .green)
                    .font(.footnote)
                    .padding(.horizontal)
            }
            
            Button(action: onSave) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isSaving ? "Guardando..." : "Guardar cambios")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .disabled(isSaving)
            .background(isSaving ? Color.gray : Color(red: 0.33, green: 0.8, blue: 0.95))
            .foregroundColor(.black)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

struct SupervisorShiftRow: View {
    let shiftName: String
    let timing: [String: String]?
    @Binding var state: ShiftAssignmentState
    let allowAux: Bool
    let nurseOptions: [String]
    let auxOptions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(shiftName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text((timing?["start"] ?? "--") + " - " + (timing?["end"] ?? "--"))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Enfermería
            VStack(alignment: .leading, spacing: 8) {
                Text("Enfermería")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.9))
                
                if state.nurseSlots.isEmpty {
                    state.nurseSlots = [SlotAssignment()]
                }
                
                ForEach(Array(state.nurseSlots.enumerated()), id: \.element.id) { index, slot in
                    SlotAssignmentEditorRow(
                        label: "Enfermero \(index + 1)",
                        slot: Binding(
                            get: { state.nurseSlots[index] },
                            set: { state.nurseSlots[index] = $0 }
                        ),
                        options: nurseOptions
                    )
                }
            }
            
            // Auxiliares
            if allowAux {
                Divider().background(Color.white.opacity(0.2))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auxiliares")
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.9))
                    
                    if state.auxSlots.isEmpty {
                        state.auxSlots = [SlotAssignment()]
                    }
                    
                    ForEach(Array(state.auxSlots.enumerated()), id: \.element.id) { index, slot in
                        SlotAssignmentEditorRow(
                            label: "TCAE \(index + 1)",
                            slot: Binding(
                                get: { state.auxSlots[index] },
                                set: { state.auxSlots[index] = $0 }
                            ),
                            options: auxOptions
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct SlotAssignmentEditorRow: View {
    let label: String
    @Binding var slot: SlotAssignment
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Toggle("Media jornada", isOn: $slot.hasHalfDay)
                    .labelsHidden()
            }
            
            StaffPickerField(
                title: "Turno completo",
                selectedName: $slot.primaryName,
                options: options
            )
            
            if slot.hasHalfDay {
                StaffPickerField(
                    title: "Media jornada",
                    selectedName: $slot.secondaryName,
                    options: options
                )
            }
        }
    }
}

struct StaffPickerField: View {
    let title: String
    @Binding var selectedName: String
    let options: [String]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Menu {
                Button("Sin asignar") {
                    selectedName = ""
                }
                
                ForEach(options, id: \.self) { name in
                    Button(name) {
                        selectedName = name
                    }
                }
            } label: {
                HStack {
                    Text(selectedName.isEmpty ? "Sin asignar" : selectedName)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - SUBVISTAS EXISTENTES (DailyStaff, Drawer, etc.)

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
                Circle()
                    .fill(colorForShift)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorForShift)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal)
            
            ForEach(workers) { worker in
                HStack(spacing: 15) {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 35, height: 35)
                        .overlay(
                            Text(String(worker.name.prefix(1)))
                                .bold()
                                .foregroundColor(.white)
                        )
                    
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
                let turnosOrdenados = [
                    "Mañana",
                    "Media mañana",
                    "Tarde",
                    "Media tarde",
                    "Noche",
                    "Día",
                    "Turno de Día",
                    "Turno de Noche"
                ]
                
                ForEach(turnosOrdenados, id: \.self) { turno in
                    if let workers = plantManager.dailyAssignments[turno], !workers.isEmpty {
                        DailyShiftSection(title: turno, workers: workers)
                    }
                }
                
                ForEach(
                    plantManager.dailyAssignments.keys.sorted().filter { !turnosOrdenados.contains($0) },
                    id: \.self
                ) { turno in
                    if let workers = plantManager.dailyAssignments[turno] {
                        DailyShiftSection(title: turno, workers: workers)
                    }
                }
            }
        }
    }
}

// Drawer y resto de helpers igual que ya tenías

struct PlantMenuRowContent: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 30)
                .foregroundColor(
                    isSelected
                    ? Color(red: 0.7, green: 0.5, blue: 1.0)
                    : .white.opacity(0.7)
                )
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .bold(isSelected)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(10)
    }
}

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
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
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
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        PlantMenuRow(
                            title: "Calendario",
                            icon: "calendar",
                            selected: $selectedOption
                        ) { close() }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 5)
                        
                        if authManager.userRole == "Supervisor" {
                            Group {
                                Text("ADMINISTRACIÓN")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.gray)
                                    .padding(.leading, 10)
                                
                                PlantMenuRow(
                                    title: "Lista de personal",
                                    icon: "person.3.fill",
                                    selected: $selectedOption
                                ) { close() }
                                
                                PlantMenuRow(
                                    title: "Configuración de la planta",
                                    icon: "gearshape.2.fill",
                                    selected: $selectedOption
                                ) { close() }
                                
                                PlantMenuRow(
                                    title: "Importar turnos",
                                    icon: "square.and.arrow.down",
                                    selected: $selectedOption
                                ) { close() }
                                
                                PlantMenuRow(
                                    title: "Gestión de cambios",
                                    icon: "arrow.triangle.2.circlepath",
                                    selected: $selectedOption
                                ) { close() }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 5)
                            
                            Group {
                                Text("PERSONAL")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.gray)
                                    .padding(.leading, 10)
                                
                                PlantMenuRow(
                                    title: "Estadísticas",
                                    icon: "chart.bar.xaxis",
                                    selected: $selectedOption
                                ) { close() }
                            }
                        } else {
                            Text("PERSONAL")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.gray)
                                .padding(.leading, 10)
                            
                            PlantMenuRow(
                                title: "Días de vacaciones",
                                icon: "sun.max.fill",
                                selected: $selectedOption
                            ) { close() }
                            
                            PlantMenuRow(
                                title: "Chat de grupo",
                                icon: "bubble.left.and.bubble.right.fill",
                                selected: $selectedOption
                            ) { close() }
                            
                            PlantMenuRow(
                                title: "Cambio de turnos",
                                icon: "arrow.triangle.2.circlepath",
                                selected: $selectedOption
                            ) { close() }
                            
                            PlantMenuRow(
                                title: "Bolsa de Turnos",
                                icon: "briefcase.fill",
                                selected: $selectedOption
                            ) { close() }
                            
                            PlantMenuRow(
                                title: "Estadísticas",
                                icon: "chart.bar.xaxis",
                                selected: $selectedOption
                            ) { close() }
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
            PlantMenuRowContent(title: title, icon: icon, isSelected: selected == title)
        }
        .buttonStyle(.plain)
    }
}

struct PlantPlaceholderView: View {
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
            Spacer()
        }
        .frame(height: 300)
    }
}
