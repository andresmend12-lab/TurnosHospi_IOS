import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct ShiftChangeView: View {
    // Parámetros recibidos
    var plantId: String
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // Usamos PlantManager para leer la DB
    @StateObject var plantManager = PlantManager()
    
    // Estados principales
    @State private var selectedTab = 0
    @State private var allRequests: [ShiftChangeRequest] = []
    
    // Estados para el Calendario
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    
    // Búsqueda de candidatos
    @State private var allPlantShifts: [PlantShift] = []
    @State private var userSchedules: [String: [String: String]] = [:]
    @State private var selectedRequestForSuggestions: ShiftChangeRequest?
    
    // UI Dialogs
    @State private var showCreateDialog = false
    @State private var selectedShiftForRequest: MyShiftDisplay?
    
    // Firebase References
    private let ref = Database.database().reference()
    
    var currentUserId: String {
        return authManager.user?.uid ?? ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Personalizado
                    HStack {
                        if selectedRequestForSuggestions != nil {
                            Button(action: { selectedRequestForSuggestions = nil }) {
                                Image(systemName: "arrow.left").foregroundColor(.white)
                            }
                            Text("Buscador de Candidatos").font(.headline).foregroundColor(.white)
                        } else {
                            Text("Gestión de Cambios").font(.title2.bold()).foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    if selectedRequestForSuggestions == nil {
                        // Selector de Pestañas
                        Picker("", selection: $selectedTab) {
                            Text("Mis Turnos").tag(0)
                            Text("Gestión").tag(1)
                            Text("Sugerencias").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    
                    // Contenido
                    if selectedRequestForSuggestions != nil {
                        // VISTA BUSCADOR DE CANDIDATOS
                        FullPlantShiftsList(
                            request: selectedRequestForSuggestions!,
                            allShifts: allPlantShifts,
                            currentUserId: currentUserId,
                            userSchedules: userSchedules,
                            currentUserSchedule: [:], // Simplificado
                            onPropose: { candidate in
                                performProposal(myReq: selectedRequestForSuggestions!, target: candidate)
                                selectedRequestForSuggestions = nil
                            }
                        )
                    } else {
                        switch selectedTab {
                        case 0:
                            // CALENDARIO VISUAL
                            MyShiftsCalendarTab(
                                currentMonth: $currentMonth,
                                selectedDate: $selectedDate,
                                plantManager: plantManager,
                                onSelect: { shift in
                                    // Esta clausura se ejecuta SOLO al pulsar el botón "Solicitar Cambio"
                                    selectedShiftForRequest = shift
                                    showCreateDialog = true
                                }
                            )
                        case 1:
                            ManagementTab(
                                currentUserId: currentUserId,
                                requests: allRequests
                            )
                        case 2:
                            SuggestionsTab(
                                myRequests: allRequests.filter {
                                    $0.requesterId == currentUserId && $0.status == .searching
                                },
                                onSeeCandidates: { req in selectedRequestForSuggestions = req }
                            )
                        default: EmptyView()
                        }
                    }
                }
            }
        }
        .onAppear {
            // Inicializar mes actual al día 1
            let components = Calendar.current.dateComponents([.year, .month], from: Date())
            if let first = Calendar.current.date(from: components) {
                currentMonth = first
            }
            loadData()
        }
        .onChange(of: currentMonth) { newDate in
            if !plantId.isEmpty {
                plantManager.fetchMonthlyAssignments(plantId: plantId, month: newDate)
            }
        }
        .sheet(isPresented: $showCreateDialog) {
            if let shift = selectedShiftForRequest {
                CreateRequestView(shift: shift, plantId: plantId, onDismiss: { showCreateDialog = false })
                    .presentationDetents([.medium, .large])
                    // CORRECCIÓN FONDO BLANCO: Forzamos fondo oscuro y esquema oscuro en la hoja
                    .presentationBackground(Color(red: 0.05, green: 0.05, blue: 0.1))
                    .preferredColorScheme(.dark)
            }
        }
    }
    
    func loadData() {
        if !plantId.isEmpty {
            plantManager.fetchCurrentPlant(plantId: plantId)
            plantManager.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
            loadRequests()
        }
    }
    
    func loadRequests() {
        ref.child("plants/\(plantId)/shift_requests").observe(.value) { snapshot in
            var newRequests: [ShiftChangeRequest] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any],
                   let req = try? parseRequest(dict: dict, id: child.key) {
                    newRequests.append(req)
                }
            }
            self.allRequests = newRequests
        }
    }
    
    func parseRequest(dict: [String: Any], id: String) throws -> ShiftChangeRequest? {
        guard let rId = dict["requesterId"] as? String,
              let rName = dict["requesterName"] as? String,
              let rRole = dict["requesterRole"] as? String,
              let rDate = dict["requesterShiftDate"] as? String,
              let rShift = dict["requesterShiftName"] as? String else { return nil }
        
        let statusStr = dict["status"] as? String ?? "SEARCHING"
        
        return ShiftChangeRequest(
            id: id,
            type: .swap,
            status: RequestStatus(rawValue: statusStr) ?? .searching,
            requesterId: rId,
            requesterName: rName,
            requesterRole: rRole,
            requesterShiftDate: rDate,
            requesterShiftName: rShift
        )
    }
    
    func performProposal(myReq: ShiftChangeRequest, target: PlantShift) {
        let updates: [String: Any] = [
            "status": RequestStatus.pendingPartner.rawValue,
            "targetUserId": target.userId,
            "targetUserName": target.userName,
            "targetShiftDate": target.dateString,
            "targetShiftName": target.shiftName
        ]
        ref.child("plants/\(plantId)/shift_requests/\(myReq.id)").updateChildValues(updates)
    }
}

// MARK: - CALENDARIO

struct MyShiftsCalendarTab: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    @ObservedObject var plantManager: PlantManager
    let onSelect: (MyShiftDisplay) -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                
                // --- Cabecera de Mes ---
                HStack {
                    Text(monthYearString(for: currentMonth).capitalized)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                        Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // --- Cabecera Días Semana ---
                HStack {
                    ForEach(weekDays, id: \.self) { day in
                        Text(day)
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // --- Rejilla Días ---
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    
                    ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                        Color.clear.frame(height: 36)
                    }
                    
                    ForEach(daysInMonth, id: \.self) { day in
                        let date = dateFor(day: day)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        
                        let myShiftWorker = getMyShiftWorker(for: date)
                        let shiftType = myShiftWorker != nil ? mapStringToShiftType(myShiftWorker?.shiftName ?? "", role: myShiftWorker?.role ?? "") : nil
                        
                        Button {
                            // SOLO selecciona fecha, NO abre ventana
                            withAnimation {
                                selectedDate = date
                            }
                        } label: {
                            ZStack {
                                if let type = shiftType {
                                    themeManager.color(for: type)
                                        .opacity(isSelected ? 1.0 : 0.8)
                                } else {
                                    Color.white.opacity(0.05)
                                }
                                
                                Text("\(day)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(height: 36)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                
                // --- Detalle Inferior ---
                if let worker = getMyShiftWorker(for: selectedDate), let sName = worker.shiftName {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Turno seleccionado:")
                                .font(.caption).foregroundColor(.gray)
                            Text(sName)
                                .font(.headline).foregroundColor(.white)
                        }
                        Spacer()
                        
                        // ESTE BOTÓN ABRE LA VENTANA
                        Button("Solicitar Cambio") {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let display = MyShiftDisplay(
                                dateString: formatter.string(from: selectedDate),
                                shiftName: sName,
                                fullDate: selectedDate,
                                fullDateString: formatter.string(from: selectedDate)
                            )
                            onSelect(display)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.2, green: 0.4, blue: 1.0)) // Electric Blue
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.top, 10)
                } else {
                    Text("Selecciona un día con turno para gestionar cambios.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
            }
            .padding()
        }
    }
    
    private func getMyShiftWorker(for date: Date) -> PlantShiftWorker? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let workers = plantManager.monthlyAssignments[startOfDay] else { return nil }
        let targetName = plantManager.myPlantName ?? authManager.currentUserName
        return workers.first(where: { $0.name == targetName })
    }
    
    private func mapStringToShiftType(_ name: String, role: String) -> ShiftType? {
        let lowerName = name.lowercased()
        let isHalf = role.localizedCaseInsensitiveContains("media")
        
        if lowerName.contains("mañana") || lowerName.contains("dia") || lowerName.contains("día") { return isHalf ? .mediaManana : .manana }
        if lowerName.contains("tarde") { return isHalf ? .mediaTarde : .tarde }
        if lowerName.contains("noche") { return .noche }
        return nil
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday + 5) % 7
    }
    
    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? Date()
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            let components = calendar.dateComponents([.year, .month], from: newDate)
            if let first = calendar.date(from: components) {
                currentMonth = first
            }
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - VENTANA DE CREACIÓN (GLASS DARK CORREGIDA)

struct CreateRequestView: View {
    let shift: MyShiftDisplay
    let plantId: String
    let onDismiss: () -> Void
    @State private var mode: RequestMode = .flexible
    
    private let ref = Database.database().reference()
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            // Fondo oscuro base (aunque presentationBackground ayuda, esto asegura el tono)
            Color.black.opacity(0.8).ignoresSafeArea()
            
            // Decoración
            VStack {
                Circle().fill(Color(red: 0.2, green: 0.4, blue: 1.0)).frame(width: 200).blur(radius: 80).offset(x: -100, y: -150).opacity(0.3)
                Spacer()
                Circle().fill(Color(red: 0.6, green: 0.2, blue: 0.9)).frame(width: 200).blur(radius: 80).offset(x: 100, y: 150).opacity(0.3)
            }
            .ignoresSafeArea()
            
            // Contenido Principal
            VStack(spacing: 25) {
                
                // Título
                VStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    Text("Ofrecer Turno")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 10)
                
                Divider().background(Color.white.opacity(0.3))
                
                // Información del Turno
                VStack(alignment: .leading, spacing: 10) {
                    Text("Estás ofreciendo:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(shift.dateString)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "clock")
                            .foregroundColor(.purple)
                        Text(shift.shiftName)
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                // Configuración
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modo de cambio")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Modo", selection: $mode) {
                        Text("Flexible (Cualquier cambio)").tag(RequestMode.flexible)
                        Text("Estricto (Mismo rol/horario)").tag(RequestMode.strict)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .colorScheme(.dark) // Forza controles oscuros
                }
                
                Spacer()
                
                // Botones de Acción
                HStack(spacing: 15) {
                    Button(action: onDismiss) {
                        Text("Cancelar")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    Button(action: createRequest) {
                        Text("Publicar Oferta")
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(15)
                    }
                }
            }
            .padding(25)
        }
    }
    
    func createRequest() {
        guard let user = authManager.user else { return }
        
        let newReq = ShiftChangeRequest(
            type: .swap,
            status: .searching,
            mode: mode,
            hardnessLevel: .normal,
            requesterId: user.uid,
            requesterName: authManager.currentUserName,
            requesterRole: authManager.userRole,
            requesterShiftDate: shift.dateString,
            requesterShiftName: shift.shiftName
        )
        
        let reqData: [String: Any] = [
            "type": newReq.type.rawValue,
            "status": newReq.status.rawValue,
            "mode": newReq.mode.rawValue,
            "hardnessLevel": newReq.hardnessLevel.rawValue,
            "requesterId": newReq.requesterId,
            "requesterName": newReq.requesterName,
            "requesterRole": newReq.requesterRole,
            "requesterShiftDate": newReq.requesterShiftDate,
            "requesterShiftName": newReq.requesterShiftName,
            "timestamp": ServerValue.timestamp()
        ]
        
        ref.child("plants/\(plantId)/shift_requests").childByAutoId().setValue(reqData) { error, _ in
            if error == nil {
                onDismiss()
            }
        }
    }
}

// MARK: - TABS SECUNDARIAS

struct ManagementTab: View {
    let currentUserId: String
    let requests: [ShiftChangeRequest]
    
    var body: some View {
        List {
            ForEach(requests) { req in
                VStack(alignment: .leading) {
                    Text(req.requesterShiftName).font(.headline).foregroundColor(.white)
                    Text("Estado: \(req.status.rawValue)")
                        .foregroundColor(statusColor(req.status))
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .approved: return .green
        case .searching: return .blue
        case .pendingPartner: return .orange
        default: return .gray
        }
    }
}

struct SuggestionsTab: View {
    let myRequests: [ShiftChangeRequest]
    let onSeeCandidates: (ShiftChangeRequest) -> Void
    
    var body: some View {
        ScrollView {
            ForEach(myRequests) { req in
                VStack(alignment: .leading) {
                    Text("Ofreces: \(req.requesterShiftDate)").bold().foregroundColor(.white)
                    Button("Ver Candidatos") { onSeeCandidates(req) }
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
}

struct FullPlantShiftsList: View {
    let request: ShiftChangeRequest
    let allShifts: [PlantShift]
    let currentUserId: String
    let userSchedules: [String: [String: String]]
    let currentUserSchedule: [String: String]
    let onPropose: (PlantShift) -> Void
    
    var filteredShifts: [PlantShift] {
        // En un entorno real, aquí se aplica ShiftRulesEngine
        return allShifts.filter { $0.userId != currentUserId }
    }
    
    var body: some View {
        VStack {
            if filteredShifts.isEmpty {
                Spacer()
                Text("No se encontraron candidatos compatibles.")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            } else {
                List(filteredShifts) { shift in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shift.userName)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(shift.dateString) • \(shift.shiftName)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { onPropose(shift) }) {
                            Text("Elegir")
                                .bold()
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
