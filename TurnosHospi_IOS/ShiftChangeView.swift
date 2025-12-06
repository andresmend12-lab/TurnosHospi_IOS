import SwiftUI
import FirebaseDatabase

struct ShiftChangeView: View {
    // Parámetros recibidos (inyectados o del entorno)
    var plantId: String = "plant1" // Ejemplo
    @EnvironmentObject var authManager: AuthManager // Asumiendo que tienes AuthManager
    
    // Estados
    @State private var selectedTab = 0
    @State private var myShiftsList: [MyShiftDisplay] = []
    @State private var myShiftsMap: [String: String] = [:] // "yyyy-MM-dd" -> ShiftName
    @State private var allRequests: [ShiftChangeRequest] = []
    
    // Búsqueda de candidatos
    @State private var allPlantShifts: [PlantShift] = []
    @State private var userSchedules: [String: [String: String]] = [:] // UserId -> [DateStr: Shift]
    @State private var selectedRequestForSuggestions: ShiftChangeRequest?
    
    // UI Dialogs
    @State private var showCreateDialog = false
    @State private var selectedShiftForRequest: MyShiftDisplay?
    
    // Firebase References
    private let ref = Database.database().reference()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea() // Fondo oscuro
                
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
                        // VISTA BUSCADOR
                        FullPlantShiftsList(
                            request: selectedRequestForSuggestions!,
                            allShifts: allPlantShifts,
                            currentUserId: authManager.currentUserId,
                            userSchedules: userSchedules,
                            currentUserSchedule: myShiftsMap,
                            onPropose: { candidate in
                                performProposal(myReq: selectedRequestForSuggestions!, target: candidate)
                                selectedRequestForSuggestions = nil
                            }
                        )
                    } else {
                        switch selectedTab {
                        case 0:
                            MyShiftsCalendarTab(shifts: myShiftsList) { shift in
                                selectedShiftForRequest = shift
                                showCreateDialog = true
                            }
                        case 1:
                            ManagementTab(
                                currentUserId: authManager.currentUserId,
                                requests: allRequests
                            )
                        case 2:
                            SuggestionsTab(
                                myRequests: allRequests.filter {
                                    $0.requesterId == authManager.currentUserId && $0.status == .searching
                                },
                                onSeeCandidates: { req in selectedRequestForSuggestions = req }
                            )
                        default: EmptyView()
                        }
                    }
                }
            }
        }
        .onAppear { loadData() }
        .sheet(isPresented: $showCreateDialog) {
            if let shift = selectedShiftForRequest {
                CreateRequestView(shift: shift, plantId: plantId, onDismiss: { showCreateDialog = false })
            }
        }
    }
    
    func loadData() {
        // Cargar mis turnos y turnos de planta (Simplificado para el ejemplo)
        // Aquí implementarías la lógica de Firebase similar a Android:
        // 1. observe(.value) en `plants/ID/turnos`
        // 2. parsear y llenar `myShiftsMap` y `allPlantShifts`
        // 3. observe(.value) en `plants/ID/shift_requests` -> `allRequests`
        
        // Mock rápido para visualización
        // ...
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

// --- SUBVISTAS ---

struct MyShiftsCalendarTab: View {
    let shifts: [MyShiftDisplay]
    let onSelect: (MyShiftDisplay) -> Void
    
    var body: some View {
        ScrollView {
            // Aquí iría tu calendario personalizado. Usamos lista simple por brevedad.
            ForEach(shifts) { shift in
                HStack {
                    Text(shift.dateString).foregroundColor(.white)
                    Spacer()
                    Text(shift.shiftName).bold().foregroundColor(.blue)
                    Button("Cambiar") { onSelect(shift) }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

struct ManagementTab: View {
    let currentUserId: String
    let requests: [ShiftChangeRequest]
    
    var body: some View {
        List {
            ForEach(requests) { req in
                // Lógica de visualización igual a Android (Open, Pending, History)
                VStack(alignment: .leading) {
                    Text(req.requesterShiftName).font(.headline)
                    Text("Estado: \(req.status.rawValue)")
                        .foregroundColor(statusColor(req.status))
                }
            }
        }
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

struct CreateRequestView: View {
    let shift: MyShiftDisplay
    let plantId: String
    let onDismiss: () -> Void
    @State private var mode: RequestMode = .flexible
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Ofrecer Turno").font(.title2)
            Text("\(shift.dateString) - \(shift.shiftName)")
            
            Picker("Modo", selection: $mode) {
                Text("Flexible").tag(RequestMode.flexible)
                Text("Estricto").tag(RequestMode.strict)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Publicar") {
                // Guardar en Firebase
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Lógica de filtrado compleja (FullPlantShiftsList) traducida de Android
struct FullPlantShiftsList: View {
    let request: ShiftChangeRequest
    let allShifts: [PlantShift]
    let currentUserId: String
    let userSchedules: [String: [String: String]]
    let currentUserSchedule: [String: String]
    let onPropose: (PlantShift) -> Void
    
    var filteredShifts: [PlantShift] {
        let formatter = ShiftRulesEngine.dateFormatter
        let myDate = formatter.date(from: request.requesterShiftDate)!
        
        // Simular mi horario SIN el turno que ofrezco
        var mySimulatedSchedule = currentUserSchedule
        mySimulatedSchedule.removeValue(forKey: request.requesterShiftDate)
        
        return allShifts.filter { shift in
            // 1. Compatibilidad básica
            if shift.userId == currentUserId { return false }
            if !ShiftRulesEngine.areRolesCompatible(roleA: request.requesterRole, roleB: shift.userRole) { return false }
            if shift.date < Date() { return false }
            
            // 2. Validación Cruzada (Engine)
            // ¿Puedo yo hacer su turno?
            if ShiftRulesEngine.validateWorkRules(targetDate: shift.date, targetShiftName: shift.shiftName, userSchedule: mySimulatedSchedule) != nil {
                return false
            }
            
            // ¿Puede él hacer mi turno?
            var hisSchedule = userSchedules[shift.userId] ?? [:]
            hisSchedule.removeValue(forKey: shift.dateString)
            
            if ShiftRulesEngine.validateWorkRules(targetDate: myDate, targetShiftName: request.requesterShiftName, userSchedule: hisSchedule) != nil {
                return false
            }
            
            return true
        }
    }
    
    var body: some View {
        List(filteredShifts) { shift in
            HStack {
                VStack(alignment: .leading) {
                    Text(shift.userName).bold()
                    Text("\(shift.dateString) - \(shift.shiftName)")
                }
                Spacer()
                Button("Elegir") { onPropose(shift) }
            }
        }
    }
}
