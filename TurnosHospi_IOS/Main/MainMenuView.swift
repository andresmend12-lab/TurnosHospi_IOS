import SwiftUI

struct MainMenuView: View {
    var userEmail: String
    var userProfile: UserProfile?
    var userPlant: Plant? // Definir modelo Plant según necesidad
    var shiftColors: ShiftColors
    
    // Actions
    var onSignOut: () -> Void
    var onOpenSettings: () -> Void
    var onOpenDirectChats: () -> Void
    var onOpenPlant: () -> Void
    var onCreatePlant: () -> Void
    
    // State para Drawer y Calendario
    @State private var isMenuOpen = false
    @State private var currentMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var selectedShiftName: String? = nil
    
    // Mock Data para turnos (se conectará con Firebase luego)
    @State var shifts: [String: String] = [:] // "yyyy-MM-dd": "ShiftName"
    
    var displayName: String {
        userProfile?.firstName ?? userEmail
    }
    
    var body: some View {
        ZStack {
            // --- CONTENIDO PRINCIPAL ---
            VStack {
                // Header Personalizado
                HStack {
                    Button(action: { withAnimation { isMenuOpen.toggle() } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Hola, \(displayName)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Notificaciones (Mock)
                    Image(systemName: "bell.fill")
                        .foregroundColor(.white)
                }
                .padding()
                .padding(.top, 40) // Safe Area Top aproximado
                
                // CALENDARIO
                ScrollView {
                    VStack(spacing: 20) {
                        CustomCalendarView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            shifts: shifts,
                            colors: shiftColors
                        )
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(24)
                        
                        // Detalle del día seleccionado
                        if let date = selectedDate {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Detalle del día \(formatDate(date))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Turno: \(getShiftForDate(date) ?? "Libre")")
                                    .foregroundColor(Color(hex: "54C7EC"))
                                
                                // Aquí iría la lista de compañeros (Colleagues)
                                Text("Sin compañeros asignados (Demo)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(hex: "0F172A").ignoresSafeArea()) // Fondo oscuro global
            
            // --- DRAWER MENU (CAPA SUPERIOR) ---
            if isMenuOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { isMenuOpen = false } }
                
                HStack {
                    VStack(alignment: .leading, spacing: 20) {
                        // Drawer Header
                        HStack {
                            Image(systemName: "cross.case.fill") // Logo placeholder
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                            Text("TurnosHospi")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 50)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        // Menu Items
                        Group {
                            DrawerItem(icon: "building.2", text: "Mis Plantas", action: onOpenPlant)
                            if userProfile?.role.contains("Supervisor") == true {
                                DrawerItem(icon: "plus.circle", text: "Crear Planta", action: onCreatePlant)
                            }
                            DrawerItem(icon: "gearshape", text: "Configuración", action: onOpenSettings)
                        }
                        
                        Spacer()
                        
                        DrawerItem(icon: "arrow.right.square", text: "Cerrar Sesión", color: .red, action: onSignOut)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                    .frame(width: 280)
                    .background(Color(hex: "1E293B"))
                    .offset(x: 0)
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
            
            // Floating Action Button (Chat)
            if !isMenuOpen {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: onOpenDirectChats) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(hex: "54C7EC"))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d 'de' MMMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
    
    func getShiftForDate(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return shifts[key]
    }
}

// Subvista del ítem de menú
struct DrawerItem: View {
    var icon: String
    var text: String
    var color: Color = .white
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(text)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.vertical, 8)
        }
    }
}

// Subvista del Calendario Grid
struct CustomCalendarView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date?
    var shifts: [String: String]
    var colors: ShiftColors
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        df.locale = Locale(identifier: "es_ES")
        return df
    }()
    
    var body: some View {
        VStack {
            // Navegación Mes
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left").foregroundColor(.white)
                }
                Spacer()
                Text(dateFormatter.string(from: currentMonth).capitalized)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right").foregroundColor(.white)
                }
            }
            .padding(.bottom)
            
            // Días de la semana
            HStack {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid de Días
            let days = daysInMonth()
            let offset = firstDayWeekday()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Espacios vacíos iniciales (offset - 1 porque Calendar empieza en Domingo=1, queremos Lunes=1)
                ForEach(0..<((offset + 5) % 7), id: \.self) { _ in
                    Text("").frame(height: 40)
                }
                
                ForEach(days, id: \.self) { date in
                    let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                    let shiftName = getShiftName(for: date)
                    let bgColor = getColorForShift(shiftName)
                    
                    Text("\(calendar.component(.day, from: date))")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(bgColor)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                }
            }
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    func firstDayWeekday() -> Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return 0 }
        return calendar.component(.weekday, from: startOfMonth)
    }
    
    func getShiftName(for date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return shifts[formatter.string(from: date)]
    }
    
    func getColorForShift(_ name: String?) -> Color {
        guard let name = name?.lowercased() else { return colors.free }
        if name.contains("noche") { return colors.night }
        if name.contains("mañana") {
            return name.contains("media") ? colors.morningHalf : colors.morning
        }
        if name.contains("tarde") {
            return name.contains("media") ? colors.afternoonHalf : colors.afternoon
        }
        if name.contains("vacaciones") { return colors.holiday }
        return colors.morning // Default
    }
}

// Modelo dummy para Plant si no está definido
struct Plant: Codable {
    var id: String
    var name: String
}
