import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationCenterManager
    @StateObject var plantManager = PlantManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showOfflineSettings = false
    
    // Estado para abrir chats
    @State private var showDirectChats = false
    @State private var showNotificationCenter = false
    @State private var pendingChatRoute: ChatRoute?
    @State private var lastKnownAssignments: [String: String] = [:]
    @State private var assignmentsInitialized = false
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    private func getMyShiftFor(date: Date) -> ShiftType? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let workers = plantManager.monthlyAssignments[startOfDay] else { return nil }
        let targetName = plantManager.myPlantName ?? authManager.currentUserName
        if let myRecord = workers.first(where: { $0.name == targetName }) {
            return mapStringToShiftType(myRecord.shiftName ?? "", role: myRecord.role)
        }
        return nil
    }
    
    private func isSaliente(date: Date) -> Bool {
        guard let prevDate = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        return getMyShiftFor(date: prevDate) == .noche
    }
    
    private func mapStringToShiftType(_ name: String, role: String) -> ShiftType? {
        let lowerName = name.lowercased()
        let isHalf = role.localizedCaseInsensitiveContains("media")
        
        if lowerName.contains("mañana") || lowerName.contains("dia") || lowerName.contains("día") {
            return isHalf ? .mediaManana : .manana
        }
        if lowerName.contains("tarde") {
            return isHalf ? .mediaTarde : .tarde
        }
        if lowerName.contains("noche") {
            return .noche
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    // Fondo
                    Color(red: 0.05, green: 0.09, blue: 0.16).ignoresSafeArea() // Color hex "0F172A" aprox
                    
                    VStack(spacing: 20) {
                        headerView
                        
                        if authManager.userPlantId.isEmpty {
                            OfflineCalendarView(showSettings: $showOfflineSettings)
                                .transition(.opacity)
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .padding(.bottom, 20)
                        } else {
                            ScrollView {
                                VStack(spacing: 20) {
                                    calendarCard
                                    dayInfoSection
                                }
                                .padding(.bottom, 100)
                            }
                        }
                    }
                    
                    if !authManager.userPlantId.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: { showDirectChats = true }) {
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
                                .padding(.trailing, 25)
                                .padding(.bottom, 30)
                            }
                        }
                    }
                }
                .cornerRadius(showMenu ? 30 : 0)
                .offset(x: showMenu ? 260 : 0)
                .scaleEffect(showMenu ? 0.85 : 1)
                .shadow(color: .black.opacity(0.5), radius: showMenu ? 20 : 0, x: -10, y: 0)
                .disabled(showMenu)
                .onTapGesture {
                    if showMenu { withAnimation { showMenu = false } }
                }
                
                if showMenu {
                    SideMenuView(isShowing: $showMenu)
                        .frame(width: 260)
                        .transition(.move(edge: .leading))
                        .offset(x: -UIScreen.main.bounds.width / 2 + 130)
                        .zIndex(2)
                }
            }
            // 1. Navegación a la lista de chats
            .navigationDestination(isPresented: $showDirectChats) {
                DirectChatListView(pendingRoute: $pendingChatRoute)
            }
            // 2. NUEVO: Manejador global para rutas de chat (ESTO ARREGLA EL PROBLEMA)
            .navigationDestination(for: ChatRoute.self) { route in
                DirectChatView(
                    chatId: route.chatId,
                    otherUserId: route.otherUserId,
                    otherUserName: route.otherUserName
                )
            }
        }
        .sheet(isPresented: $showNotificationCenter) {
            NotificationCenterView()
        }
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            refreshNotificationContext()
            assignmentsInitialized = false
            lastKnownAssignments = [:]
            resetCurrentMonthToFirstDay(of: selectedDate)
            loadData()
        }
        .onChange(of: selectedDate) { newDate in
            if !authManager.userPlantId.isEmpty {
                if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                    resetCurrentMonthToFirstDay(of: newDate)
                    loadData()
                }
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: newDate)
            }
        }
        .onChange(of: authManager.userPlantId) { newValue in
            if newValue.isEmpty {
                assignmentsInitialized = false
                lastKnownAssignments = [:]
            } else {
                loadData()
                showOfflineSettings = false
            }
            refreshNotificationContext()
        }
        .onChange(of: plantManager.monthlyAssignments) { _ in
            detectShiftNotifications()
        }
        .onChange(of: authManager.user?.uid ?? "") { newValue in
            if newValue.isEmpty {
                assignmentsInitialized = false
                lastKnownAssignments = [:]
            } else {
                assignmentsInitialized = false
                lastKnownAssignments = [:]
                detectShiftNotifications()
            }
            refreshNotificationContext()
        }
        .onChange(of: authManager.userRole) { _ in
            refreshNotificationContext()
        }
        .onChange(of: authManager.pendingNavigation) { _ in
            if let payload = authManager.consumePendingNavigation() {
                handleDeepLink(payload)
            }
        }
    }
    
    func resetCurrentMonthToFirstDay(of date: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        if let firstOfMonth = calendar.date(from: components) {
            currentMonth = firstOfMonth
        }
    }
    
    func loadData() {
        let pid = authManager.userPlantId
        guard !pid.isEmpty else { return }
        plantManager.fetchCurrentPlant(plantId: pid)
        plantManager.fetchMonthlyAssignments(plantId: pid, month: currentMonth)
        plantManager.fetchDailyStaff(plantId: pid, date: selectedDate)
    }
    
    private func detectShiftNotifications() {
        guard !authManager.userPlantId.isEmpty else {
            assignmentsInitialized = false
            lastKnownAssignments = [:]
            return
        }
        let currentMap = currentMyAssignmentsMap()
        guard !currentMap.isEmpty else { return }
        
        if !assignmentsInitialized {
            lastKnownAssignments = currentMap
            assignmentsInitialized = true
            return
        }
        
        let keys = Set(lastKnownAssignments.keys).union(currentMap.keys)
        for key in keys {
            let oldValue = lastKnownAssignments[key]
            let newValue = currentMap[key]
            if oldValue == newValue { continue }
            let readableDate = readableDateString(from: key)
            
            if let newValue = newValue, oldValue == nil {
                notificationManager.addScheduleNotification(message: "Se te asignó el turno \(newValue) para el \(readableDate).")
            } else if let oldValue = oldValue, newValue == nil {
                notificationManager.addScheduleNotification(message: "Se eliminó tu turno \(oldValue) del \(readableDate).")
            } else if let oldValue = oldValue, let newValue = newValue {
                notificationManager.addScheduleNotification(message: "Tu turno del \(readableDate) cambió de \(oldValue) a \(newValue).")
            }
        }
        lastKnownAssignments = currentMap
    }
    
    private func currentMyAssignmentsMap() -> [String: String] {
        var map: [String: String] = [:]
        let myName = plantManager.myPlantName ?? authManager.currentUserName
        guard !myName.isEmpty else { return map }
        
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        
        for (date, workers) in plantManager.monthlyAssignments {
            if let worker = workers.first(where: { $0.name == myName }) {
                let shift = (worker.shiftName?.isEmpty == false) ? (worker.shiftName ?? "Turno asignado") : "Turno asignado"
                map[keyFormatter.string(from: date)] = shift
            }
        }
        return map
    }
    
    private func readableDateString(from key: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        input.locale = Locale(identifier: "es_ES")
        guard let date = input.date(from: key) else { return key }
        let output = DateFormatter()
        output.locale = Locale(identifier: "es_ES")
        output.dateFormat = "EEEE d 'de' MMMM"
        return output.string(from: date).capitalized
    }
    
    private func refreshNotificationContext() {
        let userId = authManager.user?.uid
        let plantId = authManager.userPlantId.isEmpty ? nil : authManager.userPlantId
        let isSupervisor = authManager.userRole == "Supervisor"
        notificationManager.updateContext(userId: userId, plantId: plantId, isSupervisor: isSupervisor)
    }
    
    private func handleDeepLink(_ payload: [String: String]) {
        guard let screen = payload["screen"] else { return }
        switch screen {
        case "DirectChat":
            guard let chatId = payload["chatId"] ?? payload["argument"],
                  !chatId.isEmpty else { break }
            let otherId = payload["otherUserId"] ?? payload["argument"] ?? ""
            guard !otherId.isEmpty else { break }
            let otherName = payload["otherUserName"] ?? "Compañero"
            pendingChatRoute = ChatRoute(chatId: chatId, otherUserId: otherId, otherUserName: otherName)
            showDirectChats = true
        case "NotificationCenter":
            showNotificationCenter = true
        case "GroupChat":
            showNotificationCenter = true
        case "ShiftChangeScreen", "ShiftMarketplaceScreen":
            showNotificationCenter = true
        default:
            showNotificationCenter = true
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showMenu.toggle()
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Bienvenido")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(authManager.currentUserName.isEmpty ? "Usuario" : authManager.currentUserName)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
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
        .padding(.top, 20)
    }
    
    private var calendarCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text(monthYearString(for: currentMonth))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                    Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day).font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(0..<firstWeekdayOffset(for: currentMonth), id: \.self) { index in
                    Color.clear.frame(height: 36).id("blank-\(index)")
                }
                ForEach(daysInMonth(for: currentMonth), id: \.self) { day in
                    let date = dateFor(day: day, monthBase: currentMonth)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let shift = getMyShiftFor(date: date)
                    
                    Button {
                        withAnimation { selectedDate = date }
                    } label: {
                        ZStack {
                            if let s = shift {
                                themeManager.color(for: s).opacity(isSelected ? 0.9 : 0.7)
                            } else if isSaliente(date: date) {
                                themeManager.salienteColor.opacity(isSelected ? 0.9 : 0.7)
                            } else {
                                themeManager.freeDayColor.opacity(isSelected ? 0.6 : 0.2)
                            }
                            Text("\(day)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(height: 36)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.white : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundColor(.blue).font(.title3)
                Text(selectedDate.formatted(date: .long, time: .omitted)).font(.headline).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
    private var dayInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Agenda del día").font(.title3).bold().foregroundColor(.white).padding(.horizontal)
            if let type = getMyShiftFor(date: selectedDate) {
                VStack(spacing: 12) {
                    HStack {
                        Rectangle().fill(themeManager.color(for: type)).frame(width: 5).cornerRadius(2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.rawValue).font(.headline).foregroundColor(.white)
                            Text("Tu turno asignado").font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    let targetName = plantManager.myPlantName ?? authManager.currentUserName
                    let shiftBaseName = type.rawValue
                    let coworkers = (plantManager.dailyAssignments[shiftBaseName] ?? []).filter { $0.name != targetName }
                    if !coworkers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compañeros en tu turno").font(.subheadline.bold()).foregroundColor(.white)
                            ForEach(coworkers) { worker in
                                HStack(spacing: 12) {
                                    Circle().fill(Color.white.opacity(0.15)).frame(width: 32, height: 32).overlay(Text(String(worker.name.prefix(1))).foregroundColor(.white).bold())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name).foregroundColor(.white).font(.subheadline)
                                        Text(worker.role).foregroundColor(.gray).font(.caption)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        Text("No hay más compañeros registrados en este turno.").font(.caption).foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(themeManager.color(for: type).opacity(0.5), lineWidth: 1))
                .padding(.horizontal)
            } else if isSaliente(date: selectedDate) {
                HStack {
                    Rectangle().fill(themeManager.salienteColor).frame(width: 5).cornerRadius(2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saliente").font(.headline).foregroundColor(.white)
                        Text("Descanso post-nocturno").font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "moon.zzz.fill").foregroundColor(themeManager.salienteColor).font(.title2)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(themeManager.salienteColor.opacity(0.5), lineWidth: 1))
                .padding(.horizontal)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.largeTitle).foregroundColor(themeManager.freeDayColor)
                        Text("Día Libre").font(.headline).foregroundColor(.white)
                        Text("Disfruta de tu descanso").foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)
                .background(Color.white.opacity(0.02))
                .cornerRadius(15)
                .padding(.horizontal)
            }
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    private func firstWeekdayOffset(for monthDate: Date) -> Int {
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday + 5) % 7
    }
    
    private func daysInMonth(for monthDate: Date) -> [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        return Array(range)
    }
    
    private func dateFor(day: Int, monthBase: Date) -> Date {
        var comp = calendar.dateComponents([.year, .month], from: monthBase)
        comp.day = day
        return calendar.date(from: comp) ?? monthBase
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            resetCurrentMonthToFirstDay(of: newDate)
            loadData()
        }
    }
}
