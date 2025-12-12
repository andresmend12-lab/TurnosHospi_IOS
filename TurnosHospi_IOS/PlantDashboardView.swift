import SwiftUI
import FirebaseDatabase

// MARK: - Modelos locales para edición de turnos (iOS)

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
    @EnvironmentObject var notificationManager: NotificationCenterManager
    @EnvironmentObject var vacationManager: VacationManager
    
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager()
    
    @State private var isMenuOpen = false
    @State private var selectedOption: String = "Calendario"
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showImportShiftsSheet = false
    @State private var showStatisticsSheet = false
    @State private var showNotificationCenter = false
    
    // --- NUEVO: Estado para mostrar chat directo ---
    @State private var showDirectChats = false
    
    // Estado de edición para supervisor
    @State private var supervisorAssignments: [String: ShiftAssignmentState] = [:]
    @State private var isLoadingSupervisorAssignments = false
    @State private var isSupervisorAssignmentsLoaded = false
    @State private var isSavingSupervisorAssignments = false
    @State private var supervisorStatusMessage: String?
    
    // Helper para obtener el staffScope de forma segura
    var staffScope: String {
        plantManager.currentPlant?.staffScope ?? "nurses_only"
    }
    
    // Calendario robusto (Español / Lunes)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        
                        // HEADER
                        HStack(spacing: 14) {
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
                            
                            Button(action: { showNotificationCenter = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "bell.fill")
                                                .foregroundColor(.white)
                                        )
                                    
                                    if notificationManager.unreadCount > 0 {
                                        Text(notificationManager.unreadCount > 99 ? "99+" : "\(notificationManager.unreadCount)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .padding(.top, 60)
                        .background(Color.black.opacity(0.3))
                        
                        // CONTENIDO
                        VStack(spacing: 20) {
                            
                            // Título de la sección (Ocultar para vistas que tienen su propio header)
                            if !["Cambio de turnos", "Gestión de cambios", "Bolsa de Turnos"].contains(selectedOption) {
                                HStack {
                                    Text(selectedOption)
                                        .font(.largeTitle.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 20)
                            }
                            
                            Group {
                                let plantId = authManager.userPlantId
                                
                                switch selectedOption {
                                case "Chat de grupo":
                                    // Pasamos el plantId del usuario
                                    GroupChatView(plantId: authManager.userPlantId)
                                    
                                case "Calendario":
                                    ScrollView {
                                        VStack(spacing: 20) {
                                            
                                            // CALENDARIO PROPIO DE LA PLANTA
                                            PlantDashboardCalendarView(
                                                selectedDate: $selectedDate,
                                                currentMonth: $currentMonth,
                                                monthlyAssignments: plantManager.monthlyAssignments,
                                                vacationDays: vacationManager.vacationDays
                                            )
                                            .onChange(of: selectedDate) { newDate in
                                                // Recarga mes si cambia
                                                if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                                                    resetCurrentMonthToFirstDay(of: newDate)
                                                    if !plantId.isEmpty {
                                                        plantManager.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
                                                    }
                                                }
                                                
                                                // Recarga día
                                                if !plantId.isEmpty {
                                                    plantManager.fetchDailyStaff(plantId: plantId, date: newDate)
                                                }
                                                
                                                if authManager.userRole == "Supervisor" {
                                                    loadSupervisorAssignments()
                                                }
                                            }
                                            
                                            // CONTENIDO BAJO EL CALENDARIO
                                            if authManager.userRole == "Supervisor",
                                               let plant = plantManager.currentPlant,
                                               !plantId.isEmpty {
                                                
                                                SupervisorAssignmentsSection(
                                                    plant: plant,
                                                    assignments: $supervisorAssignments,
                                                    selectedDate: selectedDate,
                                                    isLoading: isLoadingSupervisorAssignments,
                                                    isSaving: isSavingSupervisorAssignments,
                                                    statusMessage: supervisorStatusMessage,
                                                    onSave: {
                                                        saveSupervisorAssignments(plant: plant, plantId: plantId)
                                                    }
                                                )
                                                .padding(.bottom, 40)
                                                
                                            } else {
                                                DailyStaffContent(
                                                    selectedDate: $selectedDate,
                                                    plantManager: plantManager
                                                )
                                                .padding(.bottom, 80)
                                            }
                                        }
                                    }
                                    
                                case "Días de vacaciones":
                                    VacationDaysView(plantId: plantId)
                                    
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
                                    
                                // --- NUEVOS CASOS AÑADIDOS ---
                                case "Cambio de turnos", "Gestión de cambios":
                                    ShiftChangeView(plantId: plantId)
                                    
                                case "Bolsa de Turnos":
                                    ShiftMarketplaceView(plantId: plantId)
                                    
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
                    
                    // --- BOTÓN FLOTANTE CHAT (INFERIOR DERECHA) ---
                    // Se muestra siempre o solo en la vista Calendario, según prefieras.
                    // Aquí lo muestro siempre que el usuario tenga planta.
                    VStack {
                        Spacer()
                        HStack {
                            Spacer() // Empuja a la derecha
                            
                            Button(action: {
                                showDirectChats = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(Color(red: 0.2, green: 0.4, blue: 1.0))
                                        .frame(width: 56, height: 56)
                                        .overlay(
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        )
                                    
                                    if authManager.totalUnreadChats > 0 {
                                        Text(authManager.totalUnreadChats > 99 ? "99+" : "\(authManager.totalUnreadChats)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: -6, y: -6)
                                    }
                                }
                                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 4)
                            }
                            .padding(.trailing, 25) // Margen derecho
                            .padding(.bottom, 30)   // Margen inferior
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
                        onLogout: { dismiss() },
                        onImportShifts: { showImportShiftsSheet = true },
                        onOpenStatistics: { showStatisticsSheet = true }
                    )
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            // --- Navegación a DirectChatListView ---
            .navigationDestination(isPresented: $showDirectChats) {
                DirectChatListView()
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showImportShiftsSheet) {
                ImportShiftsView()
            }
            .sheet(isPresented: $showStatisticsSheet) {
                if !authManager.userPlantId.isEmpty {
                    StatisticsView(
                        plantId: authManager.userPlantId,
                        isSupervisor: authManager.userRole == "Supervisor"
                    )
                }
            }
            
            .onAppear {
                notificationManager.updateContext(
                    userId: authManager.user?.uid,
                    plantId: authManager.userPlantId.isEmpty ? nil : authManager.userPlantId,
                    isSupervisor: authManager.userRole == "Supervisor"
                )
                
                if !authManager.userPlantId.isEmpty {
                    let plantId = authManager.userPlantId
                    plantManager.fetchCurrentPlant(plantId: plantId)
                    
                    // Asegurar mes correcto al día 1
                    resetCurrentMonthToFirstDay(of: selectedDate)
                    
                    plantManager.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
                    plantManager.fetchDailyStaff(plantId: plantId, date: selectedDate)
                }
                
                if authManager.userRole == "Supervisor" {
                    loadSupervisorAssignments()
                }
                
                updateVacationContext()
            }
            .onChange(of: authManager.userPlantId) { _ in
                updateVacationContext()
            }
            .onChange(of: authManager.user?.uid ?? "") { _ in
                updateVacationContext()
            }
        }
    }
    
    func resetCurrentMonthToFirstDay(of date: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        if let firstOfMonth = calendar.date(from: components) {
            currentMonth = firstOfMonth
        }
    }
    
    private func updateVacationContext() {
        let userId = authManager.user?.uid
        let plantId = authManager.userPlantId
        vacationManager.updateContext(
            userId: userId,
            plantId: plantId.isEmpty ? nil : plantId
        )
    }
    
    // MARK: - Lógica Supervisor
    
    private func loadSupervisorAssignments() {
        guard authManager.userRole == "Supervisor",
              let plant = plantManager.currentPlant else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)
        
        isLoadingSupervisorAssignments = true
        isSupervisorAssignmentsLoaded = false
        supervisorStatusMessage = nil
        
        let dbRef = Database.database().reference()
        let dayRef = dbRef
            .child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateKey)")
        
        dayRef.observeSingleEvent(of: .value) { snapshot in
            var result: [String: ShiftAssignmentState] = [:]
            let unassigned = "Sin asignar"
            
            if let shiftsDict = snapshot.value as? [String: Any] {
                for (shiftName, shiftValue) in shiftsDict {
                    guard let shiftData = shiftValue as? [String: Any] else { continue }
                    
                    // NURSES
                    var nurseSlots: [SlotAssignment] = []
                    if let nursesArray = shiftData["nurses"] as? [[String: Any]] {
                        for dict in nursesArray {
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
                    if let auxArray = shiftData["auxiliaries"] as? [[String: Any]] {
                        for dict in auxArray {
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
            
            // Asegurar que todos los turnos definidos en la planta aparecen, aunque vacíos
            if let shiftTimes = plant.shiftTimes {
                for shiftName in shiftTimes.keys {
                    if result[shiftName] == nil {
                        let required = plant.staffRequirements?[shiftName] ?? 0
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
                self.supervisorAssignments = result
                self.isLoadingSupervisorAssignments = false
                self.isSupervisorAssignmentsLoaded = true
            }
        }
    }
    
    private func saveSupervisorAssignments(plant: HospitalPlant, plantId: String) {
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
        
        for (shiftName, state) in supervisorAssignments {
            var nursesArray: [[String: Any]] = []
            for (index, slot) in state.nurseSlots.enumerated() {
                nursesArray.append(
                    slot.toFirebaseMap(unassigned: unassigned, base: "enfermero\(index + 1)")
                )
            }
            
            var auxArray: [[String: Any]] = []
            for (index, slot) in state.auxSlots.enumerated() {
                auxArray.append(
                    slot.toFirebaseMap(unassigned: unassigned, base: "auxiliar\(index + 1)")
                )
            }
            
            payload[shiftName] = [
                "nurses": nursesArray,
                "auxiliaries": auxArray
            ]
        }
        
        isSavingSupervisorAssignments = true
        supervisorStatusMessage = nil
        
        dayRef.setValue(payload) { error, _ in
            DispatchQueue.main.async {
                self.isSavingSupervisorAssignments = false
                if let error = error {
                    self.supervisorStatusMessage = "Error al guardar: \(error.localizedDescription)"
                } else {
                    self.supervisorStatusMessage = "Cambios guardados"
                    // Refrescar vistas de solo lectura / calendario
                    self.plantManager.fetchDailyStaff(plantId: plantId, date: self.selectedDate)
                    self.plantManager.fetchMonthlyAssignments(plantId: plantId, month: self.selectedDate)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
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

// MARK: - Extensión SlotAssignment → mapa Firebase

extension SlotAssignment {
    func toFirebaseMap(unassigned: String, base: String) -> [String: Any] {
        let primaryValue = primaryName.isEmpty ? unassigned : primaryName
        let secondaryValue = hasHalfDay ? (secondaryName.isEmpty ? unassigned : secondaryName) : ""
        let secondaryLabel = hasHalfDay ? "\(base) media jornada" : ""
        return ["halfDay": hasHalfDay, "primary": primaryValue, "secondary": secondaryValue, "primaryLabel": base, "secondaryLabel": secondaryLabel]
    }
}

// MARK: - Calendario específico para PlantDashboard (sin iniciales)

struct PlantDashboardCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    var monthlyAssignments: [Date: [PlantShiftWorker]]
    var vacationDays: Set<Date> = []
    
    private let daysSymbols = ["L", "M", "X", "J", "V", "S", "D"]
    
    // Calendario robusto
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        // Domingo=1 -> 6, Lunes=2 -> 0...
        return (weekday + 5) % 7
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Cabecera de mes
            HStack {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            // Cabecera días semana
            HStack {
                ForEach(daysSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Rejilla de días
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                // Huecos iniciales - ID ÚNICO CORRECTO
                ForEach(0..<firstWeekdayOffset, id: \.self) { index in
                    Color.clear
                        .frame(height: 40)
                        .id("dash-blank-\(index)")
                }
                
                // Días reales
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dateFor(day: day)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let startOfDay = calendar.startOfDay(for: date)
                    let hasAssignments = (monthlyAssignments[startOfDay]?.isEmpty == false)
                    let isVacationDay = vacationDays.contains(startOfDay)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isVacationDay ? Color.red.opacity(0.25) : Color.white.opacity(0.05))
                                
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.blue.opacity(0.7) : Color.clear, lineWidth: 2)
                                
                                Text("\(day)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if isVacationDay {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "sun.max.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red.opacity(0.9))
                                        }
                                        Spacer()
                                    }
                                    .padding(4)
                                }
                            }
                            .frame(height: 32)
                            
                            if isVacationDay {
                                Text("VAC")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(4)
                            } else if hasAssignments {
                                Circle()
                                    .fill(Color(red: 0.33, green: 0.8, blue: 0.95))
                                    .frame(width: 6, height: 6)
                            } else {
                                Spacer().frame(height: 6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(selectedDate.formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Helpers calendario
    
    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? currentMonth
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            let comps = calendar.dateComponents([.year, .month], from: newDate)
            if let firstOfMonth = calendar.date(from: comps) {
                currentMonth = firstOfMonth
            }
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}

// MARK: - Vista Supervisor (editor tipo Android, bajo calendario)

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
        let preferred = [
            "Mañana",
            "Media mañana",
            "Tarde",
            "Media tarde",
            "Noche",
            "Día",
            "Turno de Día",
            "Turno de Noche"
        ]
        
        let existingKeys = Set(plant.shiftTimes?.keys ?? [:].keys)
        let orderedExisting = preferred.filter { existingKeys.contains($0) }
        let extra = existingKeys.subtracting(orderedExisting).sorted()
        
        return orderedExisting + extra
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
                    get: {
                        assignments[shiftName] ?? ShiftAssignmentState()
                    },
                    set: { newValue in
                        assignments[shiftName] = newValue
                    }
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
                    .foregroundColor(status.localizedCaseInsensitiveContains("error") ? .red : .green)
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
    
    private var startText: String {
        timing?["start"] ?? "--"
    }
    
    private var endText: String {
        timing?["end"] ?? "--"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(shiftName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(startText) - \(endText)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Enfermería
            VStack(alignment: .leading, spacing: 8) {
                Text("Enfermería")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.9))
                
                ForEach(state.nurseSlots.indices, id: \.self) { index in
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
                    
                    ForEach(state.auxSlots.indices, id: \.self) { index in
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

// MARK: - Vistas de lista diaria (no supervisor)

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

// MARK: - Drawer y componentes auxiliares

struct PlantMenuRowContent: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 30)
                .foregroundColor(isSelected ? Color(red: 0.7, green: 0.5, blue: 1.0) : .white.opacity(0.7))
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
    var onImportShifts: (() -> Void)? = nil
    var onOpenStatistics: (() -> Void)? = nil // Callback para estadísticas

    let menuBackground = Color(red: 26/255, green: 26/255, blue: 46/255)

    var body: some View {
        ZStack {
            menuBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                // Header del menú lateral
                HStack(spacing: 15) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom))
                        .frame(width: 50, height: 50)
                        .overlay(Text(String(authManager.currentUserName.prefix(1))).bold().foregroundColor(.white))
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
                        // Opción Calendario (siempre visible)
                        PlantMenuRow(title: "Calendario", icon: "calendar", selected: $selectedOption) { close() }
                        Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)

                        if authManager.userRole == "Supervisor" {
                            // --- MENÚ SUPERVISOR ---
                            Group {
                                Text("ADMINISTRACIÓN")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.gray)
                                    .padding(.leading, 10)

                                PlantMenuRow(title: "Lista de personal", icon: "person.3.fill", selected: $selectedOption) { close() }
                                PlantMenuRow(title: "Configuración de la planta", icon: "gearshape.2.fill", selected: $selectedOption) { close() }
                                
                                // Botón Importar Turnos
                                Button(action: { close(); onImportShifts?() }) {
                                    PlantMenuRowContent(title: "Importar turnos", icon: "square.and.arrow.down", isSelected: false)
                                }.buttonStyle(.plain)

                                PlantMenuRow(title: "Gestión de cambios", icon: "arrow.triangle.2.circlepath", selected: $selectedOption) { close() }
                            }
                            
                            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
                            
                            Group {
                                Text("PERSONAL")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.gray)
                                    .padding(.leading, 10)
                                
                                // Botón Estadísticas (Supervisor)
                                Button(action: { close(); onOpenStatistics?() }) {
                                    PlantMenuRowContent(title: "Estadísticas", icon: "chart.bar.xaxis", isSelected: false)
                                }.buttonStyle(.plain)
                            }

                        } else {
                            // --- MENÚ PERSONAL REGULAR ---
                            Text("PERSONAL")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.gray)
                                .padding(.leading, 10)

                            PlantMenuRow(title: "Días de vacaciones", icon: "sun.max.fill", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Chat de grupo", icon: "bubble.left.and.bubble.right.fill", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Cambio de turnos", icon: "arrow.triangle.2.circlepath", selected: $selectedOption) { close() }
                            PlantMenuRow(title: "Bolsa de Turnos", icon: "briefcase.fill", selected: $selectedOption) { close() }
                            
                            // Botón Estadísticas (Personal)
                            Button(action: { close(); onOpenStatistics?() }) {
                                PlantMenuRowContent(title: "Estadísticas", icon: "chart.bar.xaxis", isSelected: false)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // Botón Cerrar Sesión / Volver
                Button(action: onLogout) {
                    HStack {
                        Image(systemName: "arrow.left.circle.fill")
                        Text("Volver al menú principal").bold()
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
            PlantMenuRowContent(
                title: title,
                icon: icon,
                isSelected: selected == title
            )
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
