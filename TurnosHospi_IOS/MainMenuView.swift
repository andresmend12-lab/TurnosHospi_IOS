import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager // Inyectado para los colores
    @StateObject var plantManager = PlantManager() // Inyectado para datos de planta
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    
    // --- CALENDARIO GREGORIANO (ESPAÑOL - LUNES) ---
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 2 = Lunes
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    // MARK: - Lógica de Filtrado de Turnos
    private func getMyShiftFor(date: Date) -> ShiftType? {
        let startOfDay = calendar.startOfDay(for: date)
        
        // 1. Obtenemos asignaciones globales del día
        guard let workers = plantManager.monthlyAssignments[startOfDay] else { return nil }
        
        // 2. Buscamos mi nombre real en la planta (o el del perfil si no se ha cargado)
        let targetName = plantManager.myPlantName ?? authManager.currentUserName
        
        // 3. Buscamos coincidencia exacta
        if let myRecord = workers.first(where: { $0.name == targetName }) {
            return mapStringToShiftType(myRecord.shiftName ?? "", role: myRecord.role)
        }
        return nil
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
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    // Usamos Color(hex:) asumiendo que la extensión está en ThemeManager.swift
                    Color(hex: "0F172A").ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // HEADER
                        headerView
                        
                        // --- CONTENIDO PRINCIPAL ---
                        // AQUÍ ESTÁ EL CAMBIO: Comprobamos si hay planta
                        if authManager.userPlantId.isEmpty {
                            
                            // CASO 1: MODO OFFLINE (Tu Planilla)
                            OfflineCalendarView()
                                .transition(.opacity)
                                // Ajuste visual para que parezca una tarjeta
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .padding(.bottom, 20)
                            
                        } else {
                            
                            // CASO 2: MODO ONLINE (Tu lógica original)
                            ScrollView {
                                VStack(spacing: 20) {
                                    
                                    // CALENDARIO PROPIO
                                    calendarCard
                                    
                                    // INFO DEL DÍA
                                    dayInfoSection
                                }
                                .padding(.bottom, 100)
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
        }
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            resetCurrentMonthToFirstDay(of: selectedDate)
            loadData()
        }
        .onChange(of: selectedDate) { newDate in
            // Solo cargamos datos online si hay planta
            if !authManager.userPlantId.isEmpty {
                if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
                    resetCurrentMonthToFirstDay(of: newDate)
                    loadData()
                }
                plantManager.fetchDailyStaff(plantId: authManager.userPlantId, date: newDate)
            }
        }
        .onChange(of: authManager.userPlantId) { _ in loadData() }
    }
    
    // Asegura que currentMonth siempre sea el día 1 para evitar errores de cálculo
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
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
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
            
            VStack(alignment: .trailing) {
                // Texto dinámico según si es offline u online
                Text(authManager.userPlantId.isEmpty ? "Modo Offline" : "Bienvenido")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(authManager.currentUserName.isEmpty ? "Usuario" : authManager.currentUserName)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.top, 50)
    }
    
    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 15) {
            // Cabecera mes
            HStack {
                Text(monthYearString(for: currentMonth))
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
            
            // Nombres días semana
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
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
                // Huecos para alinear el día 1
                ForEach(0..<firstWeekdayOffset(for: currentMonth), id: \.self) { index in
                    Color.clear
                        .frame(height: 36)
                        .id("blank-\(index)")
                }
                
                // Días reales del mes
                ForEach(daysInMonth(for: currentMonth), id: \.self) { day in
                    let date = dateFor(day: day, monthBase: currentMonth)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let shift = getMyShiftFor(date: date)
                    
                    Button {
                        withAnimation { selectedDate = date }
                    } label: {
                        ZStack {
                            // Fondo coloreado SI es mi turno
                            if let s = shift {
                                themeManager.color(for: s).opacity(isSelected ? 0.9 : 0.7)
                            } else {
                                // Día libre
                                themeManager.holidayColor.opacity(isSelected ? 0.6 : 0.2)
                            }
                            
                            Text("\(day)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(height: 36)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            
            Divider().background(Color.white.opacity(0.2)).padding(.vertical, 5)
            
            // Texto informativo del día
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
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
    // MARK: - Day Info Section
    private var dayInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Agenda del día")
                .font(.title3)
                .bold()
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if let type = getMyShiftFor(date: selectedDate) {
                // Tarjeta con nuestro turno
                VStack(spacing: 12) {
                    HStack {
                        // Color dinámico del tema
                        Rectangle()
                            .fill(themeManager.color(for: type))
                            .frame(width: 5)
                            .cornerRadius(2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tu turno asignado")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        // Icono (opcional)
                        // Image(systemName: "sun.max.fill") ...
                    }
                    
                    // Compañeros en el mismo turno
                    let targetName = plantManager.myPlantName ?? authManager.currentUserName
                    
                    // Nota: Asegúrate de que ShiftType.rawValue coincida con lo que viene de DB
                    let shiftBaseName = type.rawValue
                    
                    let coworkers = (plantManager.dailyAssignments[shiftBaseName] ?? [])
                        .filter { $0.name != targetName }
                    
                    if !coworkers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compañeros en tu turno")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            ForEach(coworkers) { worker in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(worker.name.prefix(1)))
                                                .foregroundColor(.white)
                                                .bold()
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(worker.name)
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        Text(worker.role)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        Text("No hay más compañeros registrados en este turno.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(themeManager.color(for: type).opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
                
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No tienes turnos para este día")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)
            }
        }
    }
    
    // MARK: - Helpers
    
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
// FIN DEL ARCHIVO - SIN EXTENSIONES DEBAJO
