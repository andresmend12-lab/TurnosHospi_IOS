import SwiftUI
import FirebaseDatabase
import FirebaseAuth

// MARK: - VISTA PRINCIPAL

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
    @State private var userSchedules: [String: [String: String]] = [:] // IDUsuario -> [Fecha: Turno]
    @State private var selectedRequestForSuggestions: ShiftChangeRequest?
    @State private var isLoadingCandidates = false
    
    // UI Dialogs
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
                        // Selector de Pestañas (Estilo claro sobre fondo oscuro)
                        Picker("", selection: $selectedTab) {
                            Text("Mis Turnos").tag(0)
                            Text("Gestión").tag(1)
                            Text("Sugerencias").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .colorScheme(.dark)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    
                    // Contenido
                    if let req = selectedRequestForSuggestions {
                        // VISTA BUSCADOR DE CANDIDATOS
                        if isLoadingCandidates {
                            VStack {
                                Spacer()
                                ProgressView("Analizando compatibilidad con reglas...")
                                    .tint(.white)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        } else {
                            FullPlantShiftsList(
                                request: req,
                                allShifts: allPlantShifts, // Lista ya filtrada por ShiftRulesEngine
                                currentUserId: currentUserId,
                                userSchedules: userSchedules, // Para la simulación visual
                                onPropose: { candidate in
                                    performProposal(myReq: req, target: candidate)
                                    selectedRequestForSuggestions = nil
                                }
                            )
                        }
                    } else {
                        switch selectedTab {
                        case 0:
                            // CALENDARIO VISUAL (Ahora con Saliente y Libre)
                            MyShiftsCalendarTab(
                                currentMonth: $currentMonth,
                                selectedDate: $selectedDate,
                                plantManager: plantManager,
                                onSelect: { shift in
                                    // Al asignar esto, se abre el sheet .sheet(item: $selectedShiftForRequest)
                                    selectedShiftForRequest = shift
                                }
                            )
                        case 1:
                            // GESTIÓN (Con historial y estados)
                            ManagementTab(
                                currentUserId: currentUserId,
                                currentUserDisplayName: plantManager.myPlantName ?? authManager.currentUserName,
                                requests: allRequests,
                                onAccept: acceptRequest,
                                onReject: rejectRequest
                            )
                        case 2:
                            // SUGERENCIAS (TARJETAS MEJORADAS)
                            SuggestionsTab(
                                myRequests: allRequests.filter {
                                    $0.requesterId == currentUserId && $0.status == .searching
                                },
                                onSeeCandidates: { req in
                                    selectedRequestForSuggestions = req
                                    loadCandidates() // Descarga masiva y filtrado
                                }
                            )
                        default: EmptyView()
                        }
                    }
                }
            }
        }
        .onAppear {
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
        // MODAL PARA CREAR SOLICITUD
        .sheet(item: $selectedShiftForRequest) { shift in
            CreateRequestView(
                shift: shift,
                plantId: plantId,
                onDismiss: { selectedShiftForRequest = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Color(red: 0.05, green: 0.05, blue: 0.1))
            .preferredColorScheme(.dark)
        }
    }
    
    func loadData() {
        if !plantId.isEmpty {
            plantManager.fetchCurrentPlant(plantId: plantId)
            plantManager.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
            loadRequests()
        }
    }
    
    // MARK: - LÓGICA DE CARGA Y FILTRADO (CON SHIFT RULES ENGINE)
    
    func loadCandidates() {
        guard let myRequest = selectedRequestForSuggestions else { return }
        
        self.allPlantShifts = []
        self.userSchedules = [:]
        self.isLoadingCandidates = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Cargar contexto histórico (7 días atrás) para reglas de racha/saliente
        guard let historyStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return }
        let startKey = "turnos-\(formatter.string(from: historyStart))"
        
        ref.child("plants/\(plantId)/turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: startKey)
            .observeSingleEvent(of: .value) { snapshot in
                
                var tempSchedules: [String: [String: String]] = [:]
                var potentialCandidates: [PlantShift] = []
                
                let staffList = plantManager.currentPlant?.allStaffList ?? []
                
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let key = child.key
                    guard key.hasPrefix("turnos-") else { continue }
                    
                    let dateStr = String(key.dropFirst(7))
                    guard let date = formatter.date(from: dateStr) else { continue }
                    
                    if let shiftsMap = child.value as? [String: Any] {
                        for (shiftName, shiftData) in shiftsMap {
                            guard let data = shiftData as? [String: Any] else { continue }
                            
                            // Procesador de listas (Enfermeros/Auxiliares)
                            func process(list: [[String: Any]], defaultRole: String) {
                                for slot in list {
                                    // Recuperar datos del slot
                                    let primaryName = slot["primary"] as? String ?? ""
                                    let halfDay = slot["halfDay"] as? Bool ?? false
                                    let secondaryName = slot["secondary"] as? String ?? ""
                                    
                                    // -- Turno Principal --
                                    if !primaryName.isEmpty && primaryName != "Sin asignar" {
                                        addShift(name: primaryName, defaultRole: defaultRole, date: date, dateStr: dateStr, shiftName: shiftName, tempSchedules: &tempSchedules, potentialCandidates: &potentialCandidates, staffList: staffList)
                                    }
                                    
                                    // -- Turno Secundario (Media jornada) --
                                    if halfDay && !secondaryName.isEmpty && secondaryName != "Sin asignar" {
                                        addShift(name: secondaryName, defaultRole: defaultRole, date: date, dateStr: dateStr, shiftName: shiftName, tempSchedules: &tempSchedules, potentialCandidates: &potentialCandidates, staffList: staffList)
                                    }
                                }
                            }
                            
                            if let nurses = data["nurses"] as? [[String: Any]] { process(list: nurses, defaultRole: "Enfermero") }
                            if let auxs = data["auxiliaries"] as? [[String: Any]] { process(list: auxs, defaultRole: "Auxiliar") }
                        }
                    }
                }
                
                // Preparar validación con ShiftRulesEngine
               // let myReqDate = formatter.date(from: myRequest.requesterShiftDate) ?? Date()
               // let myReqShift = myRequest.requesterShiftName
                let mySchedule = tempSchedules[self.currentUserId] ?? [:]
                
                // Filtrar candidatos
                let filteredShifts = potentialCandidates.filter { candidate in
                    // 1. No soy yo
                    if candidate.userId == self.currentUserId { return false }
                    
                    // 2. Roles Compatibles (definido en ShiftRulesEngine)
                    if !ShiftRulesEngine.areRolesCompatible(roleA: myRequest.requesterRole, roleB: candidate.userRole) {
                        return false
                    }
                    
                    let candidateSchedule = tempSchedules[candidate.userId] ?? [:]
                    
                    // 3. Validación Cruzada (Swap)
                    
                    // A. ¿Puede el Candidato hacer MI turno?
                    if ShiftRulesEngine.checkMatch(
                        requesterRequest: myRequest,
                        candidateRequest: ShiftChangeRequest(
                            type: .swap, status: .searching, mode: .flexible, hardnessLevel: .normal,
                            requesterId: candidate.userId, requesterName: candidate.userName, requesterRole: candidate.userRole,
                            requesterShiftDate: candidate.dateString, requesterShiftName: candidate.shiftName
                        ),
                        requesterSchedule: mySchedule,
                        candidateSchedule: candidateSchedule
                    ) == false {
                        return false
                    }
                    
                    return true
                }
                
                DispatchQueue.main.async {
                    self.userSchedules = tempSchedules
                    self.allPlantShifts = filteredShifts
                    self.isLoadingCandidates = false
                }
            }
    }
    
    // Helper para añadir turnos a las estructuras temporales
    func addShift(name: String, defaultRole: String, date: Date, dateStr: String, shiftName: String, tempSchedules: inout [String: [String: String]], potentialCandidates: inout [PlantShift], staffList: [PlantStaff]) {
        let staff = staffList.first(where: { $0.name == name })
        let chatUser = plantManager.plantUsers.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        let uid = chatUser?.id ?? staff?.id ?? name // Priorizar UID real
        let role = staff?.role ?? defaultRole
        
        // Guardar en horario global
        if tempSchedules[uid] == nil { tempSchedules[uid] = [:] }
        tempSchedules[uid]?[dateStr] = shiftName
        
        // Añadir a candidatos si es fecha futura o hoy
        if date >= Calendar.current.startOfDay(for: Date()) {
            potentialCandidates.append(PlantShift(
                userId: uid,
                userName: name,
                userRole: role,
                date: date,
                dateString: dateStr,
                shiftName: shiftName
            ))
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
        let tId = dict["targetUserId"] as? String
        let tName = dict["targetUserName"] as? String
        
        return ShiftChangeRequest(
            id: id,
            type: .swap,
            status: RequestStatus(rawValue: statusStr) ?? .searching,
            requesterId: rId,
            requesterName: rName,
            requesterRole: rRole,
            requesterShiftDate: rDate,
            requesterShiftName: rShift,
            targetUserId: tId,
            targetUserName: tName
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
    
    func acceptRequest(_ req: ShiftChangeRequest) {
        guard req.targetUserId == currentUserId else { return }
        let updates: [String: Any] = [
            "status": RequestStatus.awaitingSupervisor.rawValue
        ]
        ref.child("plants/\(plantId)/shift_requests/\(req.id)").updateChildValues(updates)
    }
    
    func rejectRequest(_ req: ShiftChangeRequest) {
        guard req.targetUserId == currentUserId else { return }
        let updates: [String: Any] = [
            "status": RequestStatus.rejected.rawValue
        ]
        ref.child("plants/\(plantId)/shift_requests/\(req.id)").updateChildValues(updates)
    }
}

// MARK: - 1. PESTAÑA GESTIÓN

struct ManagementTab: View {
    let currentUserId: String
    let currentUserDisplayName: String
    let requests: [ShiftChangeRequest]
    let onAccept: (ShiftChangeRequest) -> Void
    let onReject: (ShiftChangeRequest) -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es_ES"); return f
    }()
    
    var body: some View {
        List {
            // SECCIÓN ACTIVOS
            if !activeRequests.isEmpty {
                Section(header: Text("En curso / Próximos").foregroundColor(.white)) {
                    ForEach(activeRequests) { req in
                        let actionable = isActionable(req)
                        RequestRow(
                            req: req,
                            isHistory: false,
                            showActionButtons: actionable,
                            onAccept: actionable ? { onAccept(req) } : nil,
                            onReject: actionable ? { onReject(req) } : nil
                        )
                    }
                }
            } else if activeRequests.isEmpty && historyRequests.isEmpty {
                Text("No hay solicitudes activas").foregroundColor(.gray).listRowBackground(Color.clear)
            }
            
            // SECCIÓN HISTORIAL
            if !historyRequests.isEmpty {
                ForEach(groupedHistory.keys.sorted(by: >), id: \.self) { monthKey in
                    Section(header: Text(monthKey).foregroundColor(.gray)) {
                        ForEach(groupedHistory[monthKey]!) { req in
                            RequestRow(
                                req: req,
                                isHistory: true,
                                showActionButtons: false,
                                onAccept: nil,
                                onReject: nil
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
    }
    
    var activeRequests: [ShiftChangeRequest] {
        let todayStr = dateFormatter.string(from: Date())
        return requests.filter { req in
            return req.requesterShiftDate >= todayStr && req.status != .approved && req.status != .rejected
        }
    }
    
    var historyRequests: [ShiftChangeRequest] {
        let todayStr = dateFormatter.string(from: Date())
        return requests.filter { req in
            return req.requesterShiftDate < todayStr || req.status == .approved || req.status == .rejected
        }
    }
    
    var groupedHistory: [String: [ShiftChangeRequest]] {
        Dictionary(grouping: historyRequests) { req in
            if let date = dateFormatter.date(from: req.requesterShiftDate) {
                return monthFormatter.string(from: date).capitalized
            }
            return "Desconocido"
        }
    }
    
    private func isActionable(_ req: ShiftChangeRequest) -> Bool {
        guard req.status == .pendingPartner else { return false }
        if req.targetUserId == currentUserId { return true }
        let trimmedDisplayName = currentUserDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayName.isEmpty,
           let target = req.targetUserName?.trimmingCharacters(in: .whitespacesAndNewlines),
           target.caseInsensitiveCompare(trimmedDisplayName) == .orderedSame {
            return true
        }
        return false
    }
}

struct RequestRow: View {
    let req: ShiftChangeRequest
    let isHistory: Bool
    let showActionButtons: Bool
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(req.requesterShiftDate)
                    .font(.caption).bold().foregroundColor(.white)
                    .padding(4).background(Color.blue.opacity(0.3)).cornerRadius(4)
                Text(req.requesterShiftName).font(.headline).foregroundColor(.white)
                Spacer()
            }
            HStack {
                Image(systemName: statusIcon(req.status)).foregroundColor(statusColor(req.status))
                Text(statusText(req.status)).font(.subheadline).foregroundColor(statusColor(req.status)).bold()
            }
            if !isHistory, let targetName = req.targetUserName {
                Text("Con: \(targetName)").font(.caption).foregroundColor(.gray)
            }
            if showActionButtons {
                
                if let onAccept = onAccept, let onReject = onReject {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tú decides esta solicitud")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack {
                            Button(action: onReject) {
                                Text("Rechazar")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                            
                            Button(action: onAccept) {
                                Text("Aceptar")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.3))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.05))
    }
    
    func statusText(_ status: RequestStatus) -> String {
        switch status {
        case .draft: return "Borrador"
        case .searching: return "Buscando cambio"
        case .pendingPartner:
            return showActionButtons ? "Pendiente de tu aprobación" : "Esperando confirmación del compañero"
        case .awaitingSupervisor: return "Esperando confirmación de supervisor"
        case .approved: return "Aceptado"
        case .rejected: return "Rechazado"
        }
    }
    
    func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .searching: return .blue
        case .pendingPartner: return .orange
        case .awaitingSupervisor: return .purple
        case .approved: return .green
        case .rejected: return .red
        default: return .gray
        }
    }
    
    func statusIcon(_ status: RequestStatus) -> String {
        switch status {
        case .searching: return "magnifyingglass"
        case .pendingPartner: return "person.2.wave.2"
        case .awaitingSupervisor: return "hourglass"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        default: return "circle"
        }
    }
}

// MARK: - 2. SUGERENCIAS (TAB 2)

struct SuggestionsTab: View {
    let myRequests: [ShiftChangeRequest]
    let onSeeCandidates: (ShiftChangeRequest) -> Void
    
    var body: some View {
        ScrollView {
            if myRequests.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No tienes ofertas activas")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(myRequests) { req in
                        SuggestionCard(req: req, onAction: { onSeeCandidates(req) })
                    }
                }
                .padding()
            }
        }
    }
}

// TARJETA DE SUGERENCIA MEJORADA
struct SuggestionCard: View {
    let req: ShiftChangeRequest
    let onAction: () -> Void
    
    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: req.requesterShiftDate) else { return req.requesterShiftDate }
        f.dateFormat = "EEEE, d 'de' MMMM"
        f.locale = Locale(identifier: "es_ES")
        return f.string(from: date).capitalized
    }
    
    private var shiftColor: Color {
        let n = req.requesterShiftName.lowercased()
        if n.contains("mañana") || n.contains("día") { return .yellow }
        if n.contains("tarde") { return .orange }
        if n.contains("noche") { return .indigo }
        return .blue
    }
    
    private var shiftIcon: String {
        let n = req.requesterShiftName.lowercased()
        if n.contains("mañana") || n.contains("día") { return "sun.max.fill" }
        if n.contains("tarde") { return "sunset.fill" }
        if n.contains("noche") { return "moon.stars.fill" }
        return "clock.fill"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(shiftColor).frame(width: 6)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Buscando").font(.caption).foregroundColor(.green).fontWeight(.bold).textCase(.uppercase)
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1)).cornerRadius(20)
                    Spacer()
                    Text(req.mode == .flexible ? "Flexible" : "Estricto")
                        .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.1)).foregroundColor(.white.opacity(0.8)).cornerRadius(4)
                }
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 15) {
                    ZStack { Circle().fill(shiftColor.opacity(0.2)).frame(width: 45, height: 45); Image(systemName: shiftIcon).font(.title3).foregroundColor(shiftColor) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate).font(.title3).fontWeight(.bold).foregroundColor(.white)
                        Text(req.requesterShiftName).font(.subheadline).foregroundColor(.white.opacity(0.7))
                    }
                }
                Button(action: onAction) {
                    HStack { Text("Ver Candidatos").fontWeight(.semibold); Spacer(); Image(systemName: "chevron.right") }
                    .padding(.horizontal, 16).padding(.vertical, 10).background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }.padding(.top, 5)
            }
            .padding(16)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.18))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 3. LISTA DE CANDIDATOS (CON FILTROS Y PREVIEW)

struct FullPlantShiftsList: View {
    let request: ShiftChangeRequest
    let allShifts: [PlantShift]
    let currentUserId: String
    let userSchedules: [String: [String: String]]
    let onPropose: (PlantShift) -> Void
    
    // Filtros UI
    @State private var filterName: String = ""
    @State private var filterShift: String = ""
    @State private var filterDate: Date = Date()
    @State private var useDateFilter: Bool = false
    
    // Estado para abrir Preview
    @State private var selectedCandidateForPreview: PlantShift?
    
    // Listas calculadas dinámicamente para los menús
    var uniqueNames: [String] {
        Array(Set(allShifts.map { $0.userName })).sorted()
    }
    
    var uniqueShifts: [String] {
        Array(Set(allShifts.map { $0.shiftName })).sorted()
    }
    
    var filteredShifts: [PlantShift] {
        return allShifts.filter { shift in
            if shift.userId == currentUserId { return false }
            if !filterName.isEmpty { if shift.userName != filterName { return false } }
            if !filterShift.isEmpty { if shift.shiftName != filterShift { return false } }
            if useDateFilter {
                let calendar = Calendar.current
                if !calendar.isDate(shift.date, inSameDayAs: filterDate) { return false }
            }
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel de Filtros
            VStack(spacing: 12) {
                HStack {
                    Text("Filtrar candidatos").font(.caption).foregroundColor(.gray).textCase(.uppercase)
                    Spacer()
                    if !filterName.isEmpty || !filterShift.isEmpty || useDateFilter {
                        Button("Limpiar") {
                            withAnimation { filterName = ""; filterShift = ""; useDateFilter = false; filterDate = Date() }
                        }.font(.caption).foregroundColor(.blue)
                    }
                }
                
                // Selectores Desplegables (Menus)
                HStack(spacing: 10) {
                    // MENU NOMBRE
                    Menu {
                        Button("Todos") { filterName = "" }
                        ForEach(uniqueNames, id: \.self) { name in
                            Button(name) { filterName = name }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.magnifyingglass").foregroundColor(.gray)
                            Text(filterName.isEmpty ? "Persona..." : filterName)
                                .foregroundColor(filterName.isEmpty ? .gray : .white)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // MENU TURNO
                    Menu {
                        Button("Todos") { filterShift = "" }
                        ForEach(uniqueShifts, id: \.self) { shift in
                            Button(shift) { filterShift = shift }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock").foregroundColor(.gray)
                            Text(filterShift.isEmpty ? "Turno..." : filterShift)
                                .foregroundColor(filterShift.isEmpty ? .gray : .white)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                HStack {
                    Toggle(isOn: $useDateFilter) {
                        HStack {
                            Image(systemName: "calendar").foregroundColor(useDateFilter ? .white : .gray)
                            Text("Fecha específica").font(.subheadline).foregroundColor(useDateFilter ? .white : .gray)
                        }
                    }.tint(.blue).fixedSize()
                    Spacer()
                    if useDateFilter {
                        DatePicker("", selection: $filterDate, displayedComponents: .date)
                            .labelsHidden().colorScheme(.dark)
                    }
                }
            }
            .padding().background(Color.black.opacity(0.2))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Lista
            if filteredShifts.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.gray.opacity(0.5))
                    Text("No se encontraron candidatos").foregroundColor(.gray)
                    Text("Prueba a ajustar los filtros.").font(.caption).foregroundColor(.gray.opacity(0.7))
                }.padding()
                Spacer()
            } else {
                List(filteredShifts) { shift in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shift.userName).font(.headline).foregroundColor(.white)
                            HStack {
                                Image(systemName: "calendar").font(.caption).foregroundColor(.gray)
                                Text("\(shift.dateString) • \(shift.shiftName)")
                                    .font(.subheadline)
                                    .foregroundColor(useDateFilter ? .green : .gray)
                            }
                        }
                        Spacer()
                        // Botón abre Preview
                        Button(action: { selectedCandidateForPreview = shift }) {
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
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        // SHEET PREVIEW
        .sheet(item: $selectedCandidateForPreview) { candidate in
            ShiftSwapPreviewView(
                request: request,
                candidate: candidate,
                userSchedules: userSchedules,
                currentUserId: currentUserId,
                onConfirm: {
                    onPropose(candidate)
                    selectedCandidateForPreview = nil
                }
            )
            .presentationDetents([.fraction(0.8), .large])
            .presentationBackground(Color(red: 0.05, green: 0.05, blue: 0.1))
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 4. PREVIEW

struct ShiftSwapPreviewView: View {
    let request: ShiftChangeRequest // Mi oferta
    let candidate: PlantShift       // Su turno
    let userSchedules: [String: [String: String]]
    let currentUserId: String
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    private var dateA: Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: request.requesterShiftDate) ?? Date()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Simulación del Cambio").font(.title2.bold()).foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray) }
            }.padding()
            
            ScrollView {
                VStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📅 Tu fecha: \(request.requesterShiftDate)").font(.headline).foregroundColor(.blue).padding(.horizontal)
                        
                        SimulatedScheduleRow(
                            title: "Tú (Resultado)", centerDate: dateA, originalSchedule: userSchedules[currentUserId] ?? [:],
                            removeDateStr: request.requesterShiftDate, addDateStr: nil, addShiftName: nil
                        )
                        SimulatedScheduleRow(
                            title: "\(candidate.userName) (Resultado)", centerDate: dateA, originalSchedule: userSchedules[candidate.userId] ?? [:],
                            removeDateStr: nil, addDateStr: request.requesterShiftDate, addShiftName: request.requesterShiftName
                        )
                    }
                    .padding(.vertical).background(Color.white.opacity(0.03)).cornerRadius(12)
                    
                    if request.requesterShiftDate != candidate.dateString {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📅 Su fecha: \(candidate.dateString)").font(.headline).foregroundColor(.purple).padding(.horizontal)
                            
                            SimulatedScheduleRow(
                                title: "Tú (Resultado)", centerDate: candidate.date, originalSchedule: userSchedules[currentUserId] ?? [:],
                                removeDateStr: nil, addDateStr: candidate.dateString, addShiftName: candidate.shiftName
                            )
                            SimulatedScheduleRow(
                                title: "\(candidate.userName) (Resultado)", centerDate: candidate.date, originalSchedule: userSchedules[candidate.userId] ?? [:],
                                removeDateStr: candidate.dateString, addDateStr: nil, addShiftName: nil
                            )
                        }
                        .padding(.vertical).background(Color.white.opacity(0.03)).cornerRadius(12)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundColor(.gray)
                        Text("Se muestran 5 días antes y después para verificar descansos.").font(.caption).foregroundColor(.gray)
                    }.padding(.horizontal)
                }.padding()
            }
            Button(action: onConfirm) {
                Text("Confirmar Propuesta").bold().frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
            }.padding()
        }
    }
}

// MARK: - 5. ROW SIMULACIÓN (CORREGIDA)

struct SimulatedScheduleRow: View {
    let title: String
    let centerDate: Date
    let originalSchedule: [String: String]
    let removeDateStr: String?
    let addDateStr: String?
    let addShiftName: String?
    
    @EnvironmentObject var themeManager: ThemeManager
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold()).foregroundColor(.white.opacity(0.8)).padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(-5...5, id: \.self) { offset in
                        let date = calendar.date(byAdding: .day, value: offset, to: centerDate) ?? centerDate
                        let dateStr = dateFormatter.string(from: date)
                        let isCenter = (offset == 0)
                        
                        let shiftName: String = {
                            if dateStr == removeDateStr { return "Libre" }
                            if dateStr == addDateStr { return addShiftName ?? "Libre" }
                            return originalSchedule[dateStr] ?? "Libre"
                        }()
                        
                        let isLibre = (shiftName == "Libre")
                        let cellColor = isLibre ? themeManager.freeDayColor : themeManager.color(forShiftName: shiftName)
                        let displayText = isLibre ? "L" : String(shiftName.prefix(1))
                        
                        DayCell(
                            dayNum: calendar.component(.day, from: date),
                            text: displayText,
                            isCenter: isCenter,
                            color: cellColor
                        )
                    }
                }.padding(.horizontal)
            }
        }
    }
    
    struct DayCell: View {
        let dayNum: Int
        let text: String
        let isCenter: Bool
        let color: Color
        
        var body: some View {
            VStack(spacing: 2) {
                Text("\(dayNum)")
                    .font(.caption2)
                    .foregroundColor(isCenter ? .white : .gray)
                    .fontWeight(isCenter ? .bold : .regular)
                
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(text)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: isCenter ? 2 : 0)
                    )
            }
            .frame(width: 30)
        }
    }
}

// MARK: - 6. CALENDARIO MEJORADO (SALIENTE + LIBRE)

struct MyShiftsCalendarTab: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    @ObservedObject var plantManager: PlantManager
    let onSelect: (MyShiftDisplay) -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vacationManager: VacationManager
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "es_ES")
        return c
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Header Mes
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
                
                // Días semana
                HStack {
                    ForEach(weekDays, id: \.self) { day in
                        Text(day).font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity)
                    }
                }
                
                // Rejilla
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(0..<firstWeekdayOffset, id: \.self) { _ in Color.clear.frame(height: 36) }
                    
                    ForEach(daysInMonth, id: \.self) { day in
                                            let date = dateFor(day: day)
                                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                            
                                            let worker = getMyShiftWorker(for: date)
                                            let type = worker != nil ? mapStringToShiftType(worker!.shiftName ?? "", role: worker!.role) : nil
                                            let isVacationDay = vacationManager.isVacation(date)
                                            
                                            // CORRECCIÓN: Calculamos el color en una variable 'let' usando una clausura.
                                            // Esto evita que el ViewBuilder confunda la lógica con Vistas.
                                            let displayColor: Color = {
                                                if isVacationDay {
                                                    return Color.red
                                                }
                                                if let t = type {
                                                    return themeManager.color(for: t)
                                                } else if isSaliente(date: date) {
                                                    return themeManager.salienteColor
                                                } else {
                                                    return themeManager.freeDayColor
                                                }
                                            }()
                        
                        Button {
                            withAnimation { selectedDate = date }
                        } label: {
                            ZStack {
                                displayColor.opacity(isSelected ? 1.0 : 0.8)
                                Text("\(day)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                if isVacationDay {
                                    VStack {
                                        Spacer()
                                        Text("VAC")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.bottom, 4)
                                    }
                                }
                            }
                            .frame(height: 36)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.white : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                
                // Detalle del día seleccionado
                if let worker = getMyShiftWorker(for: selectedDate), let sName = worker.shiftName {
                    let isVacationSelected = vacationManager.isVacation(selectedDate)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Turno seleccionado:").font(.caption).foregroundColor(.gray)
                            Text(sName).font(.headline).foregroundColor(.white)
                        }
                        Spacer()
                        if isVacationSelected {
                            Label("Vacaciones", systemImage: "sun.max.fill")
                                .font(.caption.bold())
                                .foregroundColor(.red.opacity(0.9))
                        } else {
                            Button("Solicitar Cambio") {
                                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                                onSelect(MyShiftDisplay(
                                    dateString: f.string(from: selectedDate),
                                    shiftName: sName,
                                    fullDate: selectedDate,
                                    fullDateString: f.string(from: selectedDate)
                                ))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.2, green: 0.4, blue: 1.0))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.top, 10)
                    
                    if isVacationSelected {
                        Text("Los días de vacaciones están bloqueados y no permiten solicitar cambios de turno.")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 4)
                    }
                } else {
                    Text("Día libre o sin turno asignado.").font(.caption).foregroundColor(.gray).padding(.top, 20)
                }
            }
            .padding()
        }
    }
    
    // Función auxiliar para detectar si ayer fue noche
    private func isSaliente(date: Date) -> Bool {
        // Obtenemos el día anterior
        guard let prevDate = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        // Verificamos si hubo turno ayer
        if let worker = getMyShiftWorker(for: prevDate) {
            let type = mapStringToShiftType(worker.shiftName ?? "", role: worker.role)
            // Si el turno de ayer fue Noche, hoy es saliente
            return type == .noche
        }
        return false
    }
    
    private func getMyShiftWorker(for date: Date) -> PlantShiftWorker? {
        let start = calendar.startOfDay(for: date)
        return plantManager.monthlyAssignments[start]?.first(where: {
            $0.name == (plantManager.myPlantName ?? authManager.currentUserName)
        })
    }
    
    private func mapStringToShiftType(_ name: String, role: String) -> ShiftType? {
        let l = name.lowercased()
        let h = role.localizedCaseInsensitiveContains("media")
        if l.contains("mañana") || l.contains("dia") || l.contains("día") { return h ? .mediaManana : .manana }
        if l.contains("tarde") { return h ? .mediaTarde : .tarde }
        if l.contains("noche") { return .noche }
        return nil
    }
    
    private var daysInMonth: [Int] {
        return Array(calendar.range(of: .day, in: .month, for: currentMonth)!)
    }
    
    private var firstWeekdayOffset: Int {
        let c = calendar.dateComponents([.year, .month], from: currentMonth)
        let d = calendar.date(from: c)!
        return (calendar.component(.weekday, from: d) + 5) % 7
    }
    
    private func dateFor(day: Int) -> Date {
        var c = calendar.dateComponents([.year, .month], from: currentMonth)
        c.day = day
        return calendar.date(from: c)!
    }
    
    private func changeMonth(by v: Int) {
        if let n = calendar.date(byAdding: .month, value: v, to: currentMonth) {
            let c = calendar.dateComponents([.year, .month], from: n)
            currentMonth = calendar.date(from: c)!
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}

// MARK: - 7. CREATE REQUEST (Mantenida con estilos)

struct CreateRequestView: View {
    let shift: MyShiftDisplay
    let plantId: String
    let onDismiss: () -> Void
    @State private var mode: RequestMode = .flexible
    private let ref = Database.database().reference()
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 25) {
                VStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Ofrecer Turno")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading) {
                    Text("Estás ofreciendo:").font(.caption).foregroundColor(.gray)
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.blue)
                        Text(shift.dateString).bold().foregroundColor(.white)
                        Spacer()
                        Image(systemName: "clock").foregroundColor(.purple)
                        Text(shift.shiftName).bold().foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modo de cambio").font(.caption).foregroundColor(.gray)
                    Picker("Modo", selection: $mode) {
                        Text("Flexible (Cualquier cambio)").tag(RequestMode.flexible)
                        Text("Estricto (Mismo rol/horario)").tag(RequestMode.strict)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .colorScheme(.dark)
                }
                
                Spacer()
                
                HStack(spacing: 15) {
                    Button(action: onDismiss) {
                        Text("Cancelar")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    Button(action: createRequest) {
                        Text("Publicar")
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
            .background(Color(red: 0.1, green: 0.1, blue: 0.15))
            .cornerRadius(20)
            .padding()
        }
    }
    
    func createRequest() {
        guard let user = authManager.user else { return }
        let id = UUID().uuidString
        let data: [String: Any] = [
            "type": "SWAP",
            "status": "SEARCHING",
            "mode": mode.rawValue,
            "hardnessLevel": "NORMAL",
            "requesterId": user.uid,
            "requesterName": authManager.currentUserName,
            "requesterRole": authManager.userRole,
            "requesterShiftDate": shift.dateString,
            "requesterShiftName": shift.shiftName,
            "timestamp": ServerValue.timestamp()
        ]
        
        ref.child("plants/\(plantId)/shift_requests/\(id)").setValue(data) { error, _ in
            if error == nil {
                onDismiss()
            }
        }
    }
}
