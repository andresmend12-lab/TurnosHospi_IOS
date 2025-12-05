import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private let weekDays = ["L", "M", "X", "J", "V", "S", "D"]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // HEADER
                        headerView
                        
                        // CONTENIDO
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
                .cornerRadius(showMenu ? 30 : 0)
                .offset(x: showMenu ? 260 : 0)
                .scaleEffect(showMenu ? 0.85 : 1)
                .shadow(color: .black.opacity(0.5),
                        radius: showMenu ? 20 : 0,
                        x: -10,
                        y: 0)
                .disabled(showMenu)
                .onTapGesture {
                    if showMenu {
                        withAnimation { showMenu = false }
                    }
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
            shiftManager.fetchUserShifts()
            currentMonth = selectedDate
            loadDailyStaffIfPossible(for: selectedDate)
        }
        .onChange(of: selectedDate) { newDate in
            // Cada vez que cambias de día, recargamos con la planta actual
            loadDailyStaffIfPossible(for: newDate)
        }
        .onChange(of: authManager.userPlantId) { _ in
            // Si se actualiza la planta del usuario, recargamos
            loadDailyStaffIfPossible(for: selectedDate)
        }
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
                Text("Bienvenido")
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
                // Huecos iniciales
                ForEach(0..<firstWeekdayOffset(for: currentMonth), id: \.self) { _ in
                    Color.clear
                        .frame(height: 36)
                }
                
                // Días reales del mes
                ForEach(daysInMonth(for: currentMonth), id: \.self) { day in
                    let date = dateFor(day: day, monthBase: currentMonth)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let shiftForDay = userShift(on: date)
                    
                    Button {
                        withAnimation {
                            selectedDate = date
                        }
                    } label: {
                        ZStack {
                            // Fondo según si trabajas o no
                            if let shift = shiftForDay {
                                shift.type.color.opacity(isSelected ? 0.8 : 0.5)
                            } else {
                                // Día sin turno: verde
                                Color.green.opacity(isSelected ? 0.7 : 0.3)
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
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
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
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
            
            let shiftForDay = userShift(on: selectedDate)
            
            if let shift = shiftForDay {
                // Tarjeta con nuestro turno
                VStack(spacing: 12) {
                    HStack {
                        Rectangle()
                            .fill(shift.type.color)
                            .frame(width: 5)
                            .cornerRadius(2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shift.type.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tu turno asignado")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Image(systemName: getIconForShift(shift.type))
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title2)
                    }
                    
                    // Compañeros en el mismo turno
                    let shiftName = shiftName(for: shift.type)
                    let coworkers = plantManager.dailyAssignments[shiftName] ?? []
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
                        Text("No hay más personal registrado en tu turno para este día.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(shift.type.color.opacity(0.5), lineWidth: 1)
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
    
    // MARK: - Helpers calendario
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
    
    private func firstWeekdayOffset(for monthDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        // Domingo=1 -> 6, Lunes=2 -> 0
        return weekday == 1 ? 6 : weekday - 2
    }
    
    private func daysInMonth(for monthDate: Date) -> [Int] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else { return [] }
        return Array(range)
    }
    
    private func dateFor(day: Int, monthBase: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: monthBase)
        components.day = day
        return Calendar.current.date(from: components) ?? monthBase
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            // Si el selectedDate no pertenece al nuevo mes, lo movemos al día 1 del nuevo mes
            let cal = Calendar.current
            if !cal.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                if let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: newMonth)) {
                    selectedDate = firstDay
                }
            }
        }
    }
    
    // MARK: - Helpers turnos
    
    private func userShift(on date: Date) -> Shift? {
        shiftManager.userShifts.first { shift in
            Calendar.current.isDate(shift.date, inSameDayAs: date)
        }
    }
    
    private func shiftName(for type: ShiftType) -> String {
        switch type {
        case .manana:      return "Mañana"
        case .mediaManana: return "Media mañana"
        case .tarde:       return "Tarde"
        case .mediaTarde:  return "Media tarde"
        case .noche:       return "Noche"
        }
    }
    
    private func loadDailyStaffIfPossible(for date: Date) {
        let plantId = authManager.userPlantId
        guard !plantId.isEmpty else { return }
        plantManager.fetchDailyStaff(plantId: plantId, date: date)
    }
    
    // Ya la tenías
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde:   return "sunset.fill"
        case .noche:                return "moon.stars.fill"
        }
    }
}
