import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Gestor de turnos para descargar los datos de Firebase
    @StateObject var shiftManager = ShiftManager()
    
    // Estado para el menú lateral y la fecha seleccionada
    @State private var showMenu = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo base
                Color.black.ignoresSafeArea()
                
                // --- CAPA 1: CONTENIDO PRINCIPAL ---
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // CABECERA (Botón Menú + Saludo)
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
                        .padding(.top, 50) // Ajuste para evitar la zona superior (notch)
                        
                        // CONTENIDO SCROLLABLE
                        ScrollView {
                            VStack(spacing: 20) {
                                
                                // --- CALENDARIO INTERACTIVO CON TURNOS ---
                                CalendarWithShiftsView(selectedDate: $selectedDate, shifts: shiftManager.userShifts)
                                
                                // --- LISTA DE TURNOS DEL DÍA SELECCIONADO ---
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Agenda del día")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    // Buscamos si hay un turno para la fecha seleccionada
                                    let shiftForDay = shiftManager.userShifts.first { shift in
                                        Calendar.current.isDate(shift.date, inSameDayAs: selectedDate)
                                    }
                                    
                                    if let shift = shiftForDay {
                                        // TARJETA DE TURNO
                                        HStack {
                                            Rectangle()
                                                .fill(shift.type.color)
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
                                                .stroke(shift.type.color.opacity(0.5), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                        
                                    } else {
                                        // MENSAJE SIN TURNOS
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
                            .padding(.bottom, 100)
                        }
                    }
                }
                // Efectos de desplazamiento al abrir el menú
                .cornerRadius(showMenu ? 30 : 0)
                .offset(x: showMenu ? 260 : 0)
                .scaleEffect(showMenu ? 0.85 : 1)
                .shadow(color: .black.opacity(0.5), radius: showMenu ? 20 : 0, x: -10, y: 0)
                .disabled(showMenu)
                .onTapGesture {
                    if showMenu { withAnimation { showMenu = false } }
                }
                
                // --- CAPA 2: MENÚ LATERAL ---
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
            // Descargar datos al entrar
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            shiftManager.fetchUserShifts()
        }
    }
    
    // Iconos para la tarjeta de turno
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde: return "sunset.fill"
        case .noche: return "moon.stars.fill"
        }
    }
}

// MARK: - CALENDARIO INTERACTIVO (Componente)
struct CalendarWithShiftsView: View {
    @Binding var selectedDate: Date
    var shifts: [Shift]
    
    let days = ["L", "M", "X", "J", "V", "S", "D"]
    
    // Obtener días del mes actual
    var daysInMonth: [Int] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: selectedDate) else { return [] }
        return Array(range)
    }
    
    // Calcular el hueco inicial (para saber qué día de la semana cae el 1)
    var firstWeekdayOfMonth: Int {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        guard let firstDay = Calendar.current.date(from: components) else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: firstDay)
        // Ajuste: Domingo es 1, queremos que Lunes sea 1.
        return weekday == 1 ? 6 : weekday - 2
    }
    
    var body: some View {
        VStack(spacing: 15) {
            
            // --- CABECERA MES Y FLECHAS ---
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                    }
                }
                .foregroundColor(.electricBlue)
            }
            .padding(.horizontal)
            
            // --- DÍAS DE LA SEMANA ---
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // --- REJILLA DE DÍAS ---
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
                
                // Espacios vacíos
                ForEach(0..<firstWeekdayOfMonth, id: \.self) { _ in
                    Text("").frame(height: 40)
                }
                
                // Días reales
                ForEach(daysInMonth, id: \.self) { day in
                    let date = getDate(for: day)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    // Buscar si hay turno este día
                    let shift = shifts.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("\(day)")
                                .foregroundColor(isSelected ? .black : .white)
                                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                                .frame(width: 30, height: 30)
                                .background(isSelected ? Color.white : Color.clear)
                                .clipShape(Circle())
                            
                            // INDICADOR DE TURNO (Punto de color)
                            if let shift = shift {
                                Circle()
                                    .fill(shift.type.color)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: shift.type.color, radius: 3)
                            } else {
                                Circle().fill(Color.clear).frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 45)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.electricBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 5)
            
            // --- FECHA SELECCIONADA EN TEXTO ---
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
    
    // Helpers internos
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
