import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct ShiftMarketplaceView: View {
    var plantId: String
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    // --- Data States ---
    @State private var rawRequests: [ShiftChangeRequest] = []
    @State private var balances: [String: Int] = [:]
    @State private var transactions: [FavorTransaction] = []
    @State private var staffNames: [String: String] = [:] // ID -> Name
    
    // My Schedule for validation
    @State private var myShiftsMap: [String: String] = [:] // "yyyy-MM-dd" -> ShiftName
    
    // Loading States
    @State private var isLoadingRequests = true
    @State private var isLoadingSchedule = true
    
    // Preview States
    @State private var selectedRequestForPreview: ShiftChangeRequest?
    @State private var requesterScheduleForPreview: [String: String] = [:]
    @State private var isLoadingPreview = false
    
    private let ref = Database.database().reference()
    
    var currentUserId: String {
        return authManager.user?.uid ?? ""
    }
    
    // --- Filtered Requests (Rules Engine) ---
    var filteredRequests: [ShiftChangeRequest] {
        if isLoadingSchedule { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return rawRequests.filter { req in
            // 1. Role Compatibility
            if !ShiftRulesEngine.areRolesCompatible(roleA: authManager.userRole, roleB: req.requesterRole) {
                return false
            }
            
            // 2. Work Rules (Can I cover this shift?)
            guard let date = formatter.date(from: req.requesterShiftDate) else { return false }
            
            let validationError = ShiftRulesEngine.validateWorkRules(
                targetDate: date,
                targetShiftName: req.requesterShiftName,
                userSchedule: myShiftsMap
            )
            
            return validationError == nil
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Bolsa de Turnos")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // --- SECTION 1: BALANCES ---
                        if !balances.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Balances de Turnos") // CAMBIO APLICADO
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "54C7EC")) // Cyan
                                    .padding(.horizontal)
                                
                                ScrollView(.vertical) {
                                    VStack(spacing: 10) {
                                        ForEach(balances.sorted(by: { $0.value > $1.value }), id: \.key) { userId, score in
                                            let name = resolveName(userId)
                                            let history = getHistoryWith(partnerId: userId)
                                            BalanceCard(partnerName: name, score: score, history: history, currentUserId: currentUserId)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(height: 200) // Limit height
                                
                                Divider().background(Color.white.opacity(0.1)).padding(.vertical)
                            }
                        }
                        
                        // --- SECTION 2: AVAILABLE SHIFTS ---
                        VStack(alignment: .leading) {
                            Text("Turnos Disponibles")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            Text("Turnos que puedes cubrir según las reglas.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            if isLoadingRequests || isLoadingSchedule {
                                ProgressView()
                                    .tint(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else if filteredRequests.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "tray")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("No hay turnos disponibles para ti.")
                                        .foregroundColor(.gray)
                                    if !rawRequests.isEmpty {
                                        Text("(\(rawRequests.count - filteredRequests.count) ocultos por incompatibilidad)")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(filteredRequests) { req in
                                    let balance = balances[req.requesterId] ?? 0
                                    MarketplaceItem(
                                        req: req,
                                        balance: balance,
                                        onPreview: {
                                            selectedRequestForPreview = req
                                            fetchRequesterSchedule(userId: req.requesterId, dateStr: req.requesterShiftDate)
                                        },
                                        onAccept: {
                                            selectedRequestForPreview = req
                                            fetchRequesterSchedule(userId: req.requesterId, dateStr: req.requesterShiftDate)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            listenToRequests()
            listenToBalances()
            listenToTransactions()
            listenToMySchedule()
            fetchStaffNames()
        }
        .sheet(item: $selectedRequestForPreview) { req in
            CoveragePreviewView(
                request: req,
                mySchedule: myShiftsMap,
                requesterSchedule: requesterScheduleForPreview,
                isLoading: isLoadingPreview,
                onConfirm: {
                    performCoverage(req)
                    selectedRequestForPreview = nil
                },
                onCancel: { selectedRequestForPreview = nil }
            )
            .presentationDetents([.fraction(0.9)])
            .presentationBackground(Color(red: 0.05, green: 0.05, blue: 0.1))
            .preferredColorScheme(.dark)
        }
    }
    
    // --- HELPERS ---
    
    func resolveName(_ uid: String) -> String {
        return staffNames[uid] ?? "Usuario"
    }
    
    func getHistoryWith(partnerId: String) -> [FavorTransaction] {
        return transactions.filter {
            ($0.covererId == currentUserId && $0.requesterId == partnerId) ||
            ($0.requesterId == currentUserId && $0.covererId == partnerId)
        }
    }
    
    // --- FIREBASE LISTENERS ---
    
    func listenToRequests() {
        ref.child("plants/\(plantId)/shift_requests")
            .queryOrdered(byChild: "status")
            .queryEqual(toValue: "SEARCHING")
            .observe(.value) { snapshot in
                var list: [ShiftChangeRequest] = []
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    if let dict = child.value as? [String: Any],
                       let req = try? parseRequest(dict: dict, id: child.key) {
                        if req.requesterId != currentUserId {
                            list.append(req)
                        }
                    }
                }
                self.rawRequests = list
                self.isLoadingRequests = false
            }
    }
    
    func listenToBalances() {
        ref.child("plants/\(plantId)/balances/\(currentUserId)").observe(.value) { snapshot in
            var newBalances: [String: Int] = [:]
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let score = child.value as? Int {
                    newBalances[child.key] = score
                }
            }
            self.balances = newBalances
        }
    }
    
    func listenToTransactions() {
        ref.child("plants/\(plantId)/transactions").queryLimited(toLast: 50).observe(.value) { snapshot in
            var list: [FavorTransaction] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any],
                   let t = try? parseTransaction(dict: dict, id: child.key) {
                    list.append(t)
                }
            }
            self.transactions = list.filter { $0.covererId == currentUserId || $0.requesterId == currentUserId }
                .sorted(by: { $0.timestamp > $1.timestamp })
        }
    }
    
    func listenToMySchedule() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        ref.child("plants/\(plantId)/turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: "turnos-\(today)")
            .queryLimited(toFirst: 60)
            .observe(.value) { snapshot in
                var schedule: [String: String] = [:]
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let key = child.key
                    let dateStr = key.replacingOccurrences(of: "turnos-", with: "")
                    
                    if let shifts = child.value as? [String: Any] {
                        for (shiftName, data) in shifts {
                            if let dataDict = data as? [String: Any] {
                                if isUserInShift(data: dataDict, userName: authManager.currentUserName) {
                                    schedule[dateStr] = shiftName
                                }
                            }
                        }
                    }
                }
                self.myShiftsMap = schedule
                self.isLoadingSchedule = false
            }
    }
    
    func fetchStaffNames() {
        ref.child("plants/\(plantId)/personal_de_planta").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let name = child.childSnapshot(forPath: "name").value as? String {
                    self.staffNames[child.key] = name
                    if let internalId = child.childSnapshot(forPath: "id").value as? String {
                        self.staffNames[internalId] = name
                    }
                }
            }
        }
        ref.child("plants/\(plantId)/userPlants").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let uid = child.key
                if let name = child.childSnapshot(forPath: "staffName").value as? String {
                    self.staffNames[uid] = name
                }
            }
        }
    }
    
    func fetchRequesterSchedule(userId: String, dateStr: String) {
        isLoadingPreview = true
        requesterScheduleForPreview = [:]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { isLoadingPreview = false; return }
        
        let start = Calendar.current.date(byAdding: .day, value: -7, to: date)!
        let startStr = "turnos-" + formatter.string(from: start)
        
        let reqName = resolveName(userId)
        
        ref.child("plants/\(plantId)/turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: startStr)
            .queryLimited(toFirst: 15)
            .observeSingleEvent(of: .value) { snapshot in
                var schedule: [String: String] = [:]
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    let key = child.key
                    let dStr = key.replacingOccurrences(of: "turnos-", with: "")
                    
                    if let shifts = child.value as? [String: Any] {
                        for (shiftName, data) in shifts {
                            if let dataDict = data as? [String: Any] {
                                if isUserInShift(data: dataDict, userName: reqName) {
                                    schedule[dStr] = shiftName
                                }
                            }
                        }
                    }
                }
                self.requesterScheduleForPreview = schedule
                self.isLoadingPreview = false
            }
    }
    
    func isUserInShift(data: [String: Any], userName: String) -> Bool {
        func checkList(_ list: [[String: Any]]) -> Bool {
            for slot in list {
                let p = slot["primary"] as? String
                let s = slot["secondary"] as? String
                if p == userName || s == userName { return true }
            }
            return false
        }
        if let nurses = data["nurses"] as? [[String: Any]] { if checkList(nurses) { return true } }
        if let auxs = data["auxiliaries"] as? [[String: Any]] { if checkList(auxs) { return true } }
        return false
    }
    
    func parseRequest(dict: [String: Any], id: String) throws -> ShiftChangeRequest? {
        guard let rId = dict["requesterId"] as? String,
              let rName = dict["requesterName"] as? String,
              let rDate = dict["requesterShiftDate"] as? String,
              let rShift = dict["requesterShiftName"] as? String else { return nil }
        
        return ShiftChangeRequest(
            id: id,
            type: .coverage,
            status: RequestStatus(rawValue: dict["status"] as? String ?? "") ?? .searching,
            requesterId: rId,
            requesterName: rName,
            requesterRole: dict["requesterRole"] as? String ?? "",
            requesterShiftDate: rDate,
            requesterShiftName: rShift
        )
    }
    
    func parseTransaction(dict: [String: Any], id: String) throws -> FavorTransaction? {
        return FavorTransaction(
            id: id,
            covererId: dict["covererId"] as? String ?? "",
            covererName: dict["covererName"] as? String ?? "",
            requesterId: dict["requesterId"] as? String ?? "",
            requesterName: dict["requesterName"] as? String ?? "",
            date: dict["date"] as? String ?? "",
            shiftName: dict["shiftName"] as? String ?? "",
            timestamp: dict["timestamp"] as? TimeInterval ?? 0
        )
    }
    
    // --- ACTION: PERFORM COVERAGE (TRANSACTION CORREGIDA) ---
    
    func performCoverage(_ req: ShiftChangeRequest) {
        let covererId = currentUserId
        let covererName = authManager.currentUserName
        
        let dateKey = "turnos-\(req.requesterShiftDate)"
        let shiftRef = ref.child("plants/\(plantId)/turnos/\(dateKey)/\(req.requesterShiftName)")
        
        shiftRef.observeSingleEvent(of: .value) { snapshot in
            guard let val = snapshot.value as? [String: Any] else { return }
            
            var pathFound: String? = nil
            var indexFound: Int? = nil
            var fieldToUpdate: String? = nil
            
            func search(key: String) {
                if let list = val[key] as? [[String: Any]] {
                    for (i, slot) in list.enumerated() {
                        if slot["primary"] as? String == req.requesterName {
                            pathFound = key; indexFound = i; fieldToUpdate = "primary"
                        } else if slot["secondary"] as? String == req.requesterName {
                            pathFound = key; indexFound = i; fieldToUpdate = "secondary"
                        }
                    }
                }
            }
            
            search(key: "nurses")
            if pathFound == nil { search(key: "auxiliaries") }
            
            guard let group = pathFound, let idx = indexFound, let field = fieldToUpdate else { return }
            
            let balancesRef = ref.child("plants/\(plantId)/balances")
            
            balancesRef.runTransactionBlock({ (currentData) -> TransactionResult in
                var data = currentData.value as? [String: Any] ?? [:]
                
                // CASTING SEGURO PARA EVITAR REINICIOS A 0
                // 1. Coverer -> Requester (+1)
                var covererData = data[covererId] as? [String: Any] ?? [:]
                let oldScoreMe = (covererData[req.requesterId] as? NSNumber)?.intValue ?? 0
                covererData[req.requesterId] = oldScoreMe + 1 // +1 porque hago un favor
                data[covererId] = covererData
                
                // 2. Requester -> Coverer (-1)
                var requesterData = data[req.requesterId] as? [String: Any] ?? [:]
                let oldScoreHim = (requesterData[covererId] as? NSNumber)?.intValue ?? 0
                requesterData[covererId] = oldScoreHim - 1 // -1 porque recibo un favor
                data[req.requesterId] = requesterData
                
                currentData.value = data
                return TransactionResult.success(withValue: currentData)
            }) { (error, committed, _) in
                if committed {
                    var updates: [String: Any] = [:]
                    updates["plants/\(plantId)/turnos/\(dateKey)/\(req.requesterShiftName)/\(group)/\(idx)/\(field)"] = covererName
                    updates["plants/\(plantId)/shift_requests/\(req.id)/status"] = "APPROVED"
                    updates["plants/\(plantId)/shift_requests/\(req.id)/targetUserId"] = covererId
                    updates["plants/\(plantId)/transactions/\(UUID().uuidString)"] = [
                        "covererId": covererId,
                        "covererName": covererName,
                        "requesterId": req.requesterId,
                        "requesterName": req.requesterName,
                        "date": req.requesterShiftDate,
                        "shiftName": req.requesterShiftName,
                        "timestamp": ServerValue.timestamp()
                    ]
                    ref.updateChildValues(updates)
                }
            }
        }
    }
}

// MARK: - UI COMPONENTS

struct BalanceCard: View {
    let partnerName: String
    let score: Int
    let history: [FavorTransaction]
    let currentUserId: String
    @State private var isExpanded = false
    
    var isPositive: Bool { score > 0 }
    var color: Color { isPositive ? .green : .pink }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 32, height: 32)
                        .overlay(Text(partnerName.prefix(1)).foregroundColor(.white).bold())
                    VStack(alignment: .leading) {
                        Text(partnerName).foregroundColor(.white).bold()
                        // TEXTO CORREGIDO Y VALOR ABSOLUTO
                        Text(isPositive ? "Te debe \(score) turnos" : "Le debes \(abs(score)) turnos")
                            .font(.caption).foregroundColor(color)
                    }
                    Spacer()
                    Text(isPositive ? "+\(score)" : "\(score)").font(.title3.bold()).foregroundColor(color)
                    Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 180 : 0)).foregroundColor(.gray)
                }.padding()
            }
            .background(isPositive ? Color.green.opacity(0.05) : Color.pink.opacity(0.05))
            
            if isExpanded {
                Divider().background(Color.white.opacity(0.1))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Historial reciente").font(.caption).foregroundColor(.gray).padding(.bottom, 4)
                    if history.isEmpty {
                        Text("No hay movimientos recientes.").font(.caption).italic().foregroundColor(.gray)
                    } else {
                        ForEach(history) { t in
                            let iCovered = t.covererId == currentUserId
                            HStack(alignment: .top) {
                                Image(systemName: iCovered ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundColor(iCovered ? .green : .orange).font(.caption)
                                VStack(alignment: .leading) {
                                    Text(iCovered ? "Cubriste su turno" : "Cubrió tu turno").font(.caption).bold().foregroundColor(.white)
                                    Text("\(t.shiftName) - \(t.date)").font(.caption2).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }.padding().background(Color.black.opacity(0.2))
            }
        }
        .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct MarketplaceItem: View {
    let req: ShiftChangeRequest
    let balance: Int
    let onPreview: () -> Void
    let onAccept: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.blue).frame(width: 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Solicitud de \(req.requesterName)").font(.subheadline).foregroundColor(.white)
                        if balance != 0 {
                            // TEXTO CORREGIDO Y VALOR ABSOLUTO
                            Text(balance > 0 ? "Te debe \(balance) turnos" : "Le debes \(abs(balance)) turnos")
                                .font(.caption2).foregroundColor(balance > 0 ? .green : .pink)
                        }
                    }
                    Spacer()
                    Text(req.requesterShiftName).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
                Text(formatDate(req.requesterShiftDate)).font(.title3.bold()).foregroundColor(Color(hex: "54C7EC"))
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 12) {
                    Button(action: onAccept) {
                        HStack { Image(systemName: "checkmark"); Text("Cubrir") }.fontWeight(.bold).frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.green).foregroundColor(.white).cornerRadius(8)
                    }
                    Button(action: onPreview) {
                        Image(systemName: "eye.fill").padding().background(Color.white.opacity(0.1)).foregroundColor(Color(hex: "54C7EC")).clipShape(Circle())
                    }
                }
            }.padding(16).background(Color.white.opacity(0.05))
        }.cornerRadius(12)
    }
    
    func formatDate(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: dateStr) {
            f.dateFormat = "EEEE d MMM"; f.locale = Locale(identifier: "es_ES"); return f.string(from: d).capitalized
        }
        return dateStr
    }
}

// --- PREVIEW MODAL (Coverage) ---

struct CoveragePreviewView: View {
    let request: ShiftChangeRequest
    let mySchedule: [String: String]
    let requesterSchedule: [String: String]
    let isLoading: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var date: Date { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: request.requesterShiftDate) ?? Date() }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simulación de Cobertura").font(.title2.bold()).foregroundColor(.white).padding(.top)
            if isLoading {
                Spacer(); ProgressView("Cargando horarios...").tint(.white).foregroundColor(.white); Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 30) {
                        SimulatedScheduleRow(title: "Tú (Asumes el turno)", centerDate: date, originalSchedule: mySchedule, removeDateStr: nil, addDateStr: request.requesterShiftDate, addShiftName: request.requesterShiftName)
                            .padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                        SimulatedScheduleRow(title: "\(request.requesterName) (Se libra del turno)", centerDate: date, originalSchedule: requesterSchedule, removeDateStr: request.requesterShiftDate, addDateStr: nil, addShiftName: nil)
                            .padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                        HStack { Image(systemName: "info.circle").foregroundColor(.gray); Text("Verifica que no rompes reglas de descanso.").font(.caption).foregroundColor(.gray) }
                    }.padding()
                }
                HStack(spacing: 16) {
                    Button(action: onCancel) { Text("Cancelar").foregroundColor(.gray).frame(maxWidth: .infinity).padding() }
                    Button(action: onConfirm) { Text("Confirmar").bold().foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.green).cornerRadius(12) }
                }.padding()
            }
        }
    }
}
