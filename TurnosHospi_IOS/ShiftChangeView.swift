import SwiftUI

// MARK: - VISTA PRINCIPAL

struct ShiftChangeView: View {
    // MARK: - Properties

    /// ViewModel que maneja toda la lógica de negocio
    @StateObject private var viewModel: ShiftChangeViewModel

    /// PlantManager para datos del calendario
    @StateObject private var plantManager = PlantManager()

    /// Environment Objects
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager

    /// ID de la planta
    private let plantId: String

    // MARK: - UI State

    @State private var selectedTab = 0
    @State private var currentMonth: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()
    @State private var selectedDate = Date()
    @State private var selectedShiftForRequest: MyShiftDisplay?
    @State private var selectedRequestForSuggestions: ShiftChangeRequest?

    // MARK: - Computed Properties

    private var isSupervisor: Bool {
        authManager.userRole.lowercased().contains("supervisor")
    }

    private var currentUserId: String {
        authManager.user?.uid ?? ""
    }

    private var currentUserDisplayName: String {
        plantManager.myPlantName ?? authManager.currentUserName
    }

    // MARK: - Init

    init(plantId: String) {
        self.plantId = plantId
        _viewModel = StateObject(wrappedValue: ShiftChangeViewModel(plantId: plantId))
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    if selectedRequestForSuggestions == nil && !isSupervisor {
                        tabPicker
                    }

                    contentView
                }
            }
        }
        .onAppear(perform: onViewAppear)
        .onChange(of: currentMonth) { newDate in
            if !plantId.isEmpty {
                plantManager.fetchMonthlyAssignments(plantId: plantId, month: newDate)
            }
        }
        .sheet(item: $selectedShiftForRequest) { shift in
            CreateRequestView(
                shift: shift,
                viewModel: viewModel,
                onDismiss: { selectedShiftForRequest = nil }
            )
            .environmentObject(authManager)
            .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .preferredColorScheme(ColorScheme.dark)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearMessages() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - View Components

    private var headerView: some View {
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
    }

    private var tabPicker: some View {
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

    @ViewBuilder
    private var contentView: some View {
        if let req = selectedRequestForSuggestions {
            candidatesView(for: req)
        } else if isSupervisor {
            supervisorManagementView
        } else {
            regularUserTabView
        }
    }

    @ViewBuilder
    private func candidatesView(for request: ShiftChangeRequest) -> some View {
        if viewModel.isLoadingCandidates {
            VStack {
                Spacer()
                ProgressView("Analizando compatibilidad con reglas...")
                    .tint(.white)
                    .foregroundColor(.white)
                Spacer()
            }
        } else {
            FullPlantShiftsList(
                request: request,
                allShifts: viewModel.candidateShifts,
                currentUserId: currentUserId,
                userSchedules: viewModel.userSchedules,
                onPropose: { candidate in
                    viewModel.performProposal(for: request, with: candidate)
                    selectedRequestForSuggestions = nil
                }
            )
        }
    }

    private var supervisorManagementView: some View {
        ManagementTab(
            currentUserId: currentUserId,
            currentUserDisplayName: currentUserDisplayName,
            requests: viewModel.requests,
            isSupervisor: true,
            supervisorRequests: viewModel.supervisorPendingRequests,
            onAccept: { viewModel.acceptRequest($0) },
            onReject: { viewModel.rejectRequest($0) },
            onApproveBySupervisor: { viewModel.approveSwapBySupervisor($0) },
            onRejectBySupervisor: { viewModel.rejectAsSupervisor($0) }
        )
    }

    @ViewBuilder
    private var regularUserTabView: some View {
        switch selectedTab {
        case 0:
            MyShiftsCalendarTab(
                currentMonth: $currentMonth,
                selectedDate: $selectedDate,
                plantManager: plantManager,
                onSelect: { shift in
                    selectedShiftForRequest = shift
                }
            )
        case 1:
            ManagementTab(
                currentUserId: currentUserId,
                currentUserDisplayName: currentUserDisplayName,
                requests: viewModel.requests,
                isSupervisor: false,
                supervisorRequests: viewModel.supervisorPendingRequests,
                onAccept: { viewModel.acceptRequest($0) },
                onReject: { viewModel.rejectRequest($0) },
                onApproveBySupervisor: { viewModel.approveSwapBySupervisor($0) },
                onRejectBySupervisor: { viewModel.rejectAsSupervisor($0) }
            )
        case 2:
            SuggestionsTab(
                myRequests: viewModel.mySearchingRequests,
                onSeeCandidates: { req in
                    selectedRequestForSuggestions = req
                    viewModel.loadCandidates(for: req)
                }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func onViewAppear() {
        if !plantId.isEmpty {
            plantManager.fetchCurrentPlant(plantId: plantId)
            plantManager.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
            viewModel.plantManager = plantManager
        }
    }
}

// MARK: - 1. PESTAÑA GESTIÓN

struct ManagementTab: View {
    let currentUserId: String
    let currentUserDisplayName: String
    let requests: [ShiftChangeRequest]
    let isSupervisor: Bool
    let supervisorRequests: [ShiftChangeRequest]
    let onAccept: (ShiftChangeRequest) -> Void
    let onReject: (ShiftChangeRequest) -> Void
    let onApproveBySupervisor: (ShiftChangeRequest) -> Void
    let onRejectBySupervisor: (ShiftChangeRequest) -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = Locale(identifier: "es_ES"); return f
    }()

    var body: some View {
        List {
            if isSupervisor && !supervisorRequests.isEmpty {
                Section(header: Text("Pendientes de supervisor").foregroundColor(.white)) {
                    ForEach(supervisorRequests) { req in
                        RequestRow(
                            req: req,
                            isHistory: false,
                            showActionButtons: false,
                            onAccept: nil,
                            onReject: nil,
                            showSupervisorActions: true,
                            onSupervisorApprove: { onApproveBySupervisor(req) },
                            onSupervisorReject: { onRejectBySupervisor(req) }
                        )
                    }
                }
            }

            if !activeRequests.isEmpty {
                Section(header: Text("En curso / Próximos").foregroundColor(.white)) {
                    ForEach(activeRequests) { req in
                        let actionable = isActionable(req)
                        RequestRow(
                            req: req,
                            isHistory: false,
                            showActionButtons: actionable,
                            onAccept: actionable ? { onAccept(req) } : nil,
                            onReject: actionable ? { onReject(req) } : nil,
                            showSupervisorActions: false,
                            onSupervisorApprove: nil,
                            onSupervisorReject: nil
                        )
                    }
                }
            } else if activeRequests.isEmpty && historyRequests.isEmpty {
                Text("No hay solicitudes activas").foregroundColor(.gray).listRowBackground(Color.clear)
            }

            if !historyRequests.isEmpty {
                ForEach(groupedHistory.keys.sorted(by: >), id: \.self) { monthKey in
                    Section(header: Text(monthKey).foregroundColor(.gray)) {
                        ForEach(groupedHistory[monthKey]!) { req in
                            RequestRow(
                                req: req,
                                isHistory: true,
                                showActionButtons: false,
                                onAccept: nil,
                                onReject: nil,
                                showSupervisorActions: false,
                                onSupervisorApprove: nil,
                                onSupervisorReject: nil
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

// MARK: - Request Row

struct RequestRow: View {
    let req: ShiftChangeRequest
    let isHistory: Bool
    let showActionButtons: Bool
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?
    let showSupervisorActions: Bool
    let onSupervisorApprove: (() -> Void)?
    let onSupervisorReject: (() -> Void)?

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

            if showSupervisorActions,
               let approve = onSupervisorApprove,
               let reject = onSupervisorReject {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Revisión de supervisor")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    HStack {
                        Button(action: reject) {
                            Text("Rechazar")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)

                        Button(action: approve) {
                            Text("Aprobar")
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

// MARK: - Suggestion Card

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

// MARK: - 3. LISTA DE CANDIDATOS

struct FullPlantShiftsList: View {
    let request: ShiftChangeRequest
    let allShifts: [PlantShift]
    let currentUserId: String
    let userSchedules: [String: [String: String]]
    let onPropose: (PlantShift) -> Void

    @State private var filterName: String = ""
    @State private var filterShift: String = ""
    @State private var filterDate: Date = Date()
    @State private var useDateFilter: Bool = false
    @State private var selectedCandidateForPreview: PlantShift?

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
            filterPanel
            Divider().background(Color.white.opacity(0.1))
            candidatesList
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
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
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .preferredColorScheme(.dark)
        }
    }

    private var filterPanel: some View {
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

            HStack(spacing: 10) {
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
    }

    @ViewBuilder
    private var candidatesList: some View {
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
}

// MARK: - 4. PREVIEW

struct ShiftSwapPreviewView: View {
    let request: ShiftChangeRequest
    let candidate: PlantShift
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

// MARK: - 5. ROW SIMULACIÓN

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

// MARK: - 6. CALENDARIO

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
                monthHeader
                weekDaysHeader
                calendarGrid
                selectedDayDetail
            }
            .padding()
        }
    }

    private var monthHeader: some View {
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
    }

    private var weekDaysHeader: some View {
        HStack {
            ForEach(weekDays, id: \.self) { day in
                Text(day).font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        let offset = firstWeekdayOffset
        let days = daysInMonth

        return LazyVGrid(columns: columns, spacing: 8) {
            // Espacios vacíos antes del primer día del mes
            ForEach(0..<offset, id: \.self) { index in
                Color.clear
                    .frame(height: 36)
                    .id("empty_\(index)")
            }

            // Días del mes
            ForEach(days, id: \.self) { day in
                let date = dateFor(day: day)
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

                let worker = getMyShiftWorker(for: date)
                let type = worker != nil ? mapStringToShiftType(worker!.shiftName ?? "", role: worker!.role) : nil
                let isVacationDay = vacationManager.isVacation(date)

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
                        Text("\(day)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .id("day_\(day)")
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var selectedDayDetail: some View {
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

    private func isSaliente(date: Date) -> Bool {
        guard let prevDate = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        if let worker = getMyShiftWorker(for: prevDate) {
            let type = mapStringToShiftType(worker.shiftName ?? "", role: worker.role)
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
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        return Array(range)
    }

    private var firstWeekdayOffset: Int {
        // Asegurar que estamos calculando desde el primer día del mes
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDayOfMonth = calendar.date(from: components) else { return 0 }

        // Obtener el día de la semana (1=Domingo, 2=Lunes, ..., 7=Sábado)
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Convertir a offset para calendario que comienza en Lunes
        // Lunes (2) -> 0, Martes (3) -> 1, ..., Domingo (1) -> 6
        let offset = (weekday + 5) % 7

        return offset
    }

    private func dateFor(day: Int) -> Date {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        var dateComponents = components
        dateComponents.day = day
        return calendar.date(from: dateComponents) ?? currentMonth
    }

    private func changeMonth(by v: Int) {
        if let n = calendar.date(byAdding: .month, value: v, to: currentMonth) {
            let components = calendar.dateComponents([.year, .month], from: n)
            if let firstDayOfNewMonth = calendar.date(from: components) {
                currentMonth = firstDayOfNewMonth
            }
        }
    }

    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}

// MARK: - 7. CREATE REQUEST

struct CreateRequestView: View {
    let shift: MyShiftDisplay
    @ObservedObject var viewModel: ShiftChangeViewModel
    let onDismiss: () -> Void

    @State private var mode: RequestMode = .flexible
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

    private func createRequest() {
        viewModel.createRequest(
            shiftDate: shift.dateString,
            shiftName: shift.shiftName,
            requesterName: authManager.currentUserName,
            requesterRole: authManager.userRole,
            mode: mode
        ) { success, _ in
            if success {
                onDismiss()
            }
        }
    }
}
