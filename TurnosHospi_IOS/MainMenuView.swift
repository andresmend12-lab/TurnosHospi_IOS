import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var shiftManager = ShiftManager()
    @StateObject var plantManager = PlantManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // HEADER
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
                        
                        // CONTENIDO
                        ScrollView {
                            VStack(spacing: 20) {
                                
                                // CALENDARIO PROPIO MAIN MENU
                                MainMenuCalendarView(
                                    selectedDate: $selectedDate,
                                    userShifts: shiftManager.userShifts
                                )
                                
                                // INFO DEL DÍA
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Agenda del día")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    let shiftForDay = shiftForSelectedDate()
                                    
                                    if let shift = shiftForDay {
                                        // TARJETA DEL TURNO DEL USUARIO
                                        HStack {
                                            Rectangle()
                                                .fill(shiftColor(for: shift.type))
                                                .frame(width: 5)
                                                .cornerRadius(2)
                                            
                                            VStack(alignment: .leading) {
                                                Text(shift.type.rawValue)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text("Turno asignado")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: getIconForShift(shift.type))
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.title2)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(shiftColor(for: shift.type).opacity(0.5), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                        
                                        // COMPAÑEROS EN EL MISMO TURNO
                                        let coworkers = coworkersInSameShift(as: shift)
                                        
                                        if !coworkers.isEmpty {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text("Compañeros en tu turno")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                
                                                ForEach(coworkers) { worker in
                                                    HStack(spacing: 12) {
                                                        Circle()
                                                            .fill(Color.white.opacity(0.1))
                                                            .frame(width: 32, height: 32)
                                                            .overlay(
                                                                Text(String(worker.name.prefix(1)))
                                                                    .font(.subheadline.bold())
                                                                    .foregroundColor(.white)
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
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.04))
                                                    .cornerRadius(10)
                                                }
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(15)
                                            .padding(.horizontal)
                                        } else {
                                            // Si no hay más personal, mostramos un mensajito discreto
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("No hay compañeros registrados en tu turno para este día.")
                                                    .foregroundColor(.gray)
                                                    .font(.footnote)
                                            }
                                            .padding(.horizontal)
                                        }
                                        
                                    } else {
                                        // NO TRABAJAS ESTE DÍA
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 10) {
                                                Image(systemName: "calendar.badge.checkmark")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.green.opacity(0.6))
                                                Text("Hoy no tienes turno 🎉")
                                                    .foregroundColor(.green.opacity(0.8))
                                                    .font(.headline)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 30)
                                    }
                                }
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
            shiftManager.fetchUserShifts()
            
            // Cargar staff del día seleccionado si el usuario trabaja ese día
            if let plantId = plantIdIfAny(),
               shiftForSelectedDate() != nil {
                plantManager.fetchDailyStaff(plantId: plantId, date: selectedDate)
            }
        }
        .onChange(of: selectedDate) { newDate in
            // Cada vez que cambia el día, si trabajas, traemos quién más trabaja
            if let plantId = plantIdIfAny(),
               shiftForSelectedDate(on: newDate) != nil {
                plantManager.fetchDailyStaff(plantId: plantId, date: newDate)
            } else {
                // Si no trabajas ese día, vaciamos las asignaciones
                plantManager.dailyAssignments = [:]
            }
        }
    }
    
    // MARK: - Helpers de dominio
    
    private func plantIdIfAny() -> String? {
        let id = authManager.userPlantId
        return id.isEmpty ? nil : id
    }
    
    private func shiftForSelectedDate(on date: Date? = nil) -> Shift? {
        let targetDate = date ?? selectedDate
        return shiftManager.userShifts.first { shift in
            Calendar.current.isDate(shift.date, inSameDayAs: targetDate)
        }
    }
    
    /// Nombre de turno en Firebase equivalente al ShiftType de la app
    private func firebaseShiftName(for type: ShiftType) -> String {
        switch type {
        case .manana:       return "Mañana"
        case .mediaManana:  return "Media mañana"
        case .tarde:        return "Tarde"
        case .mediaTarde:   return "Media tarde"
        case .noche:        return "Noche"
        }
    }
    
    /// Color del turno (si existe `shift.type.color` usamos ese, si no hacemos un mapping manual)
    private func shiftColor(for type: ShiftType) -> Color {
        // Si en tu modelo tienes `type.color`, descomenta esta línea y quita el switch:
        // return type.color
        
        switch type {
        case .manana, .mediaManana:
            return Color.yellow
        case .tarde, .mediaTarde:
            return Color.orange
        case .noche:
            return Color.blue
        }
    }
    
    /// Devuelve los compañeros que están en el mismo turno que el usuario para el `selectedDate`
    private func coworkersInSameShift(as shift: Shift) -> [PlantShiftWorker] {
        let shiftKey = firebaseShiftName(for: shift.type)
        guard let workers = plantManager.dailyAssignments[shiftKey] else {
            return []
        }
        // Si quieres excluir al propio usuario por nombre:
        // return workers.filter { $0.name != authManager.currentUserName }
        return workers
    }
    
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde:   return "sunset.fill"
        case .noche:                return "moon.stars.fill"
        }
    }
}

// MARK: - Calendario específico para MainMenu

struct MainMenuCalendarView: View {
    @Binding var selectedDate: Date
    var userShifts: [Shift]
    
    private let daysSymbols = ["L", "M", "X", "J", "V", "S", "D"]
    
    // Días del mes actual (basado en selectedDate)
    private var daysInMonth: [Int] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate) else {
            return []
        }
        return Array(range)
    }
    
    // Offset del primer día para cuadrar con lunes
    private var firstWeekdayOffset: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay) // 1=Domingo, 2=Lunes...
        return weekday == 1 ? 6 : weekday - 2  // Lunes=0, Domingo=6
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Cabecera de mes
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
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
                .foregroundColor(.electricBlue)
            }
            .padding(.horizontal)
            
            // Cabecera de días de la semana
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
                // Huecos iniciales
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 40)
                }
                
                // Días reales
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dateFor(day: day)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let (isWorkingDay, backgroundColor) = dayStatus(for: date)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(backgroundColor.opacity(isWorkingDay ? 0.8 : 0.25))
                            
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                            
                            Text("\(day)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            // Información de fecha seleccionada
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.electricBlue)
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
        var components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        components.day = day
        return Calendar.current.date(from: components) ?? selectedDate
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    /// Devuelve si el usuario trabaja ese día y el color de fondo apropiado.
    /// - Si trabaja -> color según tipo de turno
    /// - Si no trabaja -> verde
    private func dayStatus(for date: Date) -> (Bool, Color) {
        if let shift = userShifts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            // Color por tipo de turno
            let color: Color
            switch shift.type {
            case .manana, .mediaManana:
                color = .yellow
            case .tarde, .mediaTarde:
                color = .orange
            case .noche:
                color = .blue
            }
            return (true, color)
        } else {
            // Día libre → verde
            return (false, .green)
        }
    }
}
