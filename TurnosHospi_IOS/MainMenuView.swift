import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var plantManager = PlantManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    
    // --- CALENDARIO ROBUSTO (Forzado a Gregoriano / Español) ---
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 2 = Lunes
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }
    
    // MARK: - LÓGICA DE FILTRADO
    private func getMyShiftFor(date: Date) -> ShiftType? {
        // Usamos nuestro calendario configurado
        let startOfDay = calendar.startOfDay(for: date)
        
        guard let workers = plantManager.monthlyAssignments[startOfDay] else { return nil }
        
        let targetName = plantManager.myPlantName ?? authManager.currentUserName
        
        if let myRecord = workers.first(where: { $0.name == targetName }) {
            return mapStringToShiftType(myRecord.shiftName ?? "")
        }
        return nil
    }
    
    private func mapStringToShiftType(_ name: String) -> ShiftType? {
        let lower = name.lowercased()
        if lower.contains("media") {
            if lower.contains("mañana") || lower.contains("dia") { return .mediaManana }
            if lower.contains("tarde") { return .mediaTarde }
        }
        if lower.contains("mañana") || lower.contains("día") { return .manana }
        if lower.contains("tarde") { return .tarde }
        if lower.contains("noche") { return .noche }
        return nil
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        headerView
                        ScrollView {
                            VStack(spacing: 20) {
                                calendarCard
                                dayInfoSection
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
                .cornerRadius(showMenu ? 30 : 0)
                .offset(x: showMenu ? 260 : 0)
                .scaleEffect(showMenu ? 0.85 : 1)
                .shadow(color: .black.opacity(0.5), radius: showMenu ? 20 : 0, x: -10, y: 0)
                .disabled(showMenu)
                .onTapGesture { if showMenu { withAnimation { showMenu = false } } }
                
                if showMenu {
                    SideMenuView(isShowing: $showMenu)
                        .frame(width: 260)
                        .transition(.move(edge: .leading))
                        .offset(x: -UIScreen.main.bounds.width / 2 + 130)
                        .zIndex(2)
                }
            }
        }
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            currentMonth = selectedDate
            loadData()
        }
        .onChange(of: selectedDate) { newDate in
            if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                currentMonth = newDate
                loadData()
            }
            if !authManager.userPlantId.isEmpty {
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: newDate)
            }
        }
        .onChange(of: authManager.userPlantId) { _ in loadData() }
    }
    
    func loadData() {
        let pid = authManager.userPlantId
        guard !pid.isEmpty else { return }
        plantManager.fetchCurrentPlant(plantId: pid)
        plantManager.fetchMonthlyAssignments(plantId: pid, month: currentMonth)
        plantManager.fetchDailyStaff(plantId: pid, date: selectedDate)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showMenu.toggle() } }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title).foregroundColor(.white)
                    .padding(10).background(Color.white.opacity(0.1)).clipShape(Circle())
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Bienvenido").font(.caption).foregroundColor(.white.opacity(0.6))
                Text(authManager.currentUserName).font(.headline).bold().foregroundColor(.white)
            }
        }
        .padding(.horizontal).padding(.top, 50)
    }
    
    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text(monthYearString(for: currentMonth))
                    .font(.title3.bold()).foregroundColor(.white).textCase(.uppercase)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                    Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
                }.foregroundColor(.blue)
            }.padding(.horizontal)
            
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day).font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                // Huecos iniciales
                ForEach(0..<firstWeekdayOffset(for: currentMonth), id: \.self) { _ in Color.clear.frame(height: 36) }
                
                // Días reales
                ForEach(daysInMonth(for: currentMonth), id: \.self) { day in
                    let date = dateFor(day: day, monthBase: currentMonth)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let shift = getMyShiftFor(date: date)
                    
                    Button { withAnimation { selectedDate = date } } label: {
                        ZStack {
                            if let s = shift {
                                themeManager.color(for: s).opacity(isSelected ? 0.9 : 0.7)
                            } else {
                                themeManager.holidayColor.opacity(isSelected ? 0.6 : 0.2)
                            }
                            Text("\(day)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(height: 36).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? .white : .clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 4)
            
            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
            
            HStack {
                Image(systemName: "calendar.badge.clock").foregroundColor(.blue).font(.title3)
                Text(selectedDate.formatted(date: .long, time: .omitted)).font(.headline).foregroundColor(.white)
                Spacer()
            }.padding(.horizontal).padding(.bottom, 5)
        }
        .padding().background(.ultraThinMaterial).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
    // MARK: - Day Info Section
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
                        Image(systemName: getIconForShift(type)).foregroundColor(.white.opacity(0.7)).font(.title2)
                    }
                    
                    let targetName = plantManager.myPlantName ?? authManager.currentUserName
                    let shiftString = shiftName(for: type)
                    let coworkers = (plantManager.dailyAssignments[shiftString] ?? [])
                        .filter { $0.name != targetName }
                    
                    if !coworkers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compañeros en tu turno").font(.subheadline.bold()).foregroundColor(.white)
                            ForEach(coworkers) { worker in
                                HStack(spacing: 12) {
                                    Circle().fill(Color.white.opacity(0.15)).frame(width: 32, height: 32)
                                        .overlay(Text(String(worker.name.prefix(1))).foregroundColor(.white).bold())
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
                .padding().background(Color.white.opacity(0.05)).cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(themeManager.color(for: type).opacity(0.5), lineWidth: 1))
                .padding(.horizontal)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle).foregroundColor(.gray.opacity(0.5))
                        Text("No tienes turnos para este día").foregroundColor(.gray)
                    }
                    Spacer()
                }.padding(.vertical, 30)
            }
        }
    }
    
    // MARK: - Helpers Corregidos
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
    
    // Cálculo de offset corregido para Lunes=0, Domingo=6 independientemente de la región del móvil
    private func firstWeekdayOffset(for monthDate: Date) -> Int {
        guard let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) else { return 0 }
        
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // weekday: 1=Domingo ... 7=Sábado en calendario Gregoriano estándar
        // Queremos: Lunes(2)->0, Martes(3)->1, ..., Domingo(1)->6
        return (weekday + 5) % 7
    }
    
    private func daysInMonth(for monthDate: Date) -> [Int] {
        guard let r = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        return Array(r)
    }
    
    private func dateFor(day: Int, monthBase: Date) -> Date {
        var comp = calendar.dateComponents([.year, .month], from: monthBase); comp.day = day
        return calendar.date(from: comp) ?? monthBase
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            // Aseguramos que currentMonth sea el día 1 para evitar errores en meses de diferente duración
            let components = calendar.dateComponents([.year, .month], from: newDate)
            if let firstOfMonth = calendar.date(from: components) {
                currentMonth = firstOfMonth
                loadData()
            }
        }
    }
    
    private func shiftName(for type: ShiftType) -> String { return type.rawValue }
    
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde:   return "sunset.fill"
        case .noche:                return "moon.stars.fill"
        }
    }
    
    private func loadDailyStaffIfPossible(for date: Date) {
        let plantId = authManager.userPlantId
        guard !plantId.isEmpty else { return }
        plantManager.fetchDailyStaff(plantId: plantId, date: date)
    }
}
