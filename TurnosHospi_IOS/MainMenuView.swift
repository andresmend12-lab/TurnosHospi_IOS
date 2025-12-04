import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Inyectamos el gestor de turnos
    @StateObject var shiftManager = ShiftManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // --- HEADER ---
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
                        .padding(.top, 10)
                        
                        // --- CONTENIDO ---
                        ScrollView {
                            VStack(spacing: 20) {
                                
                                // CALENDARIO DE TURNOS
                                // Le pasamos los turnos descargados
                                CalendarWithShiftsView(selectedDate: $selectedDate, shifts: shiftManager.userShifts)
                                
                                // --- INFORMACIÓN DEL DÍA SELECCIONADO ---
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Turnos para el \(selectedDate.formatted(.dateTime.day().month()))")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    // Buscar turno para el día seleccionado
                                    let shiftForDay = shiftManager.userShifts.first { shift in
                                        Calendar.current.isDate(shift.date, inSameDayAs: selectedDate)
                                    }
                                    
                                    if let shift = shiftForDay {
                                        // TARJETA DE TURNO (Si hay turno ese día)
                                        HStack {
                                            Rectangle()
                                                .fill(shift.type.color) // Color dinámico según el turno
                                                .frame(width: 5)
                                                .cornerRadius(2)
                                            
                                            VStack(alignment: .leading) {
                                                Text(shift.type.rawValue) // "Mañana", "Noche", etc.
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text("Hospital La Princesa") // Ejemplo
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
                                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(shift.type.color.opacity(0.5), lineWidth: 1))
                                        .padding(.horizontal)
                                        
                                    } else {
                                        // SI NO HAY TURNO
                                        Text("No tienes turnos asignados para este día.")
                                            .foregroundColor(.gray)
                                            .padding(.horizontal)
                                            .padding(.bottom, 20)
                                        
                                        // Botón temporal para probar (BORRAR LUEGO)
                                        Button("Añadir turno de prueba hoy") {
                                            let components = Calendar.current.dateComponents([.day, .month, .year], from: selectedDate)
                                            shiftManager.createTestShift(day: components.day!, month: components.month!, year: components.year!, type: .manana)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        
                        Spacer()
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
                
                // Menú Lateral
                if showMenu {
                    SideMenuView(isShowing: $showMenu)
                        .frame(width: 260)
                        .transition(.move(edge: .leading))
                        .offset(x: -UIScreen.main.bounds.width / 2 + 130)
                }
            }
        }
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            // CARGAR TURNOS AL ENTRAR
            shiftManager.fetchUserShifts()
        }
    }
    
    // Iconos según el turno
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde: return "sunset.fill"
        case .noche: return "moon.stars.fill"
        }
    }
}

// --- CALENDARIO PERSONALIZADO QUE PINTA LOS TURNOS ---
struct CalendarWithShiftsView: View {
    @Binding var selectedDate: Date
    var shifts: [Shift] // Recibe la lista de turnos
    
    let days = ["L", "M", "X", "J", "V", "S", "D"]
    
    // Cálculos para el mes actual
    var daysInMonth: [Int] {
        let range = Calendar.current.range(of: .day, in: .month, for: selectedDate)!
        return Array(range)
    }
    
    // Obtener el primer día de la semana del mes (para dejar huecos vacíos al principio)
    var firstWeekdayOfMonth: Int {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        let firstDayOfMonth = Calendar.current.date(from: components)!
        // Ajuste: Calendar devuelve 1 para Domingo, queremos 1 para Lunes.
        let weekday = Calendar.current.component(.weekday, from: firstDayOfMonth)
        // Convertir: Dom(1)->7, Lun(2)->1, Mar(3)->2...
        return weekday == 1 ? 6 : weekday - 2
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Cabecera mes (Nombre mes)
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                Spacer()
                // Flechas para cambiar de mes
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                    Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
                }
                .foregroundColor(.electricBlue)
            }
            .padding(.horizontal)
            
            // Días de la semana
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Rejilla de días
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                
                // Huecos vacíos antes del día 1
                ForEach(0..<firstWeekdayOfMonth, id: \.self) { _ in
                    Text("").frame(height: 40)
                }
                
                // Días del mes
                ForEach(daysInMonth, id: \.self) { day in
                    let date = getDate(for: day)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    // BUSCAR TURNO PARA ESTE DÍA
                    let shift = shifts.first { shift in
                        Calendar.current.isDate(shift.date, inSameDayAs: date)
                    }
                    
                    Button(action: {
                        withAnimation { selectedDate = date }
                    }) {
                        VStack(spacing: 4) {
                            Text("\(day)")
                                .foregroundColor(isSelected ? .black : .white)
                                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                .frame(width: 30, height: 30)
                                .background(isSelected ? Color.white : Color.clear)
                                .clipShape(Circle())
                            
                            // PUNTO DE COLOR DEL TURNO
                            if let shift = shift {
                                Circle()
                                    .fill(shift.type.color) // Color del turno
                                    .frame(width: 6, height: 6)
                                    .shadow(color: shift.type.color, radius: 2)
                            } else {
                                // Espacio vacío para mantener alineación
                                Circle().fill(Color.clear).frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
    // Helpers de fecha
    func getDate(for day: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
    
    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}
