import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var shiftRepository: ShiftRepository
    @EnvironmentObject var authService: AuthService
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var showDetailsSheet = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        df.locale = Locale(identifier: "es_ES")
        return df
    }()
    
    // Grid de 7 columnas para la semana
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            VStack {
                // --- Cabecera del Mes ---
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .padding()
                    }
                    
                    Text(dateFormatter.string(from: currentMonth).capitalized)
                        .font(.title2)
                        .bold()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .padding()
                    }
                }
                .padding()
                
                // --- Días de la Semana ---
                HStack {
                    ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.gray)
                    }
                }
                
                // --- Rejilla del Calendario ---
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    shift: getShift(for: date)
                                )
                                .onTapGesture {
                                    self.selectedDate = date
                                    self.showDetailsSheet = true
                                }
                            } else {
                                // Espacio vacío para alinear el primer día
                                Text("")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Mi Calendario")
            .sheet(isPresented: $showDetailsSheet) {
                if let date = selectedDate {
                    ShiftDetailsSheet(date: date)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        // Calcular en qué día de la semana empieza (Lunes=1, pero Calendar suele usar Domingo=1 por defecto o configuración local)
        // Ajustamos para que la semana empiece en lunes (weekday 2 en gregoriano US, pero depende de locale)
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Ajuste para Lunes = 1
        firstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 2
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    func getShift(for date: Date) -> UserShift? {
        let dateString = formatDate(date)
        return shiftRepository.myShifts.first(where: { $0.date == dateString })
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Subvistas

struct DayCell: View {
    let date: Date
    let shift: UserShift?
    
    var backgroundColor: Color {
        guard let shift = shift else { return Color(.secondarySystemBackground) }
        
        // Colores según el tipo de turno
        // Usamos una lógica simple basada en el nombre del turno
        let name = shift.shiftName.lowercased()
        if name.contains("mañana") { return Color.green.opacity(0.3) }
        if name.contains("tarde") { return Color.orange.opacity(0.3) }
        if name.contains("noche") { return Color.blue.opacity(0.3) }
        return Color.gray.opacity(0.3)
    }
    
    var textColor: Color {
        guard let shift = shift else { return .primary }
        let name = shift.shiftName.lowercased()
        if name.contains("mañana") { return .green }
        if name.contains("tarde") { return .orange }
        if name.contains("noche") { return .blue }
        return .gray
    }
    
    var body: some View {
        VStack {
            Text("\(Calendar.current.component(.day, from: date))")
                .fontWeight(shift != nil ? .bold : .regular)
            
            Circle()
                .fill(textColor)
                .frame(width: 6, height: 6)
                .opacity(shift != nil ? 1 : 0)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

struct ShiftDetailsSheet: View {
    let date: Date
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    // Formateador local para mostrar la fecha en el título
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(dateString.capitalized)
                    .font(.headline)
                    .padding()
                
                if authService.currentUser?.role == .supervisor {
                    // Vista de Supervisor: Mostrar todo el personal
                    SupervisorDailyView()
                } else {
                    // Vista de Staff: Mostrar mi turno y compañeros
                    StaffDailyView()
                }
                
                Spacer()
            }
            .navigationTitle("Detalles del Día")
            .navigationBarItems(trailing: Button("Cerrar") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Placeholder para la vista de detalles del supervisor
struct SupervisorDailyView: View {
    var body: some View {
        List {
            Section(header: Text("Turno Mañana")) {
                Text("Juan Pérez (Enfermero)")
                Text("Ana Gómez (Auxiliar)")
            }
            Section(header: Text("Turno Tarde")) {
                Text("Carlos Ruiz (Enfermero)")
            }
            Section(header: Text("Turno Noche")) {
                Text("María López (Enfermero)")
            }
        }
    }
}

// Placeholder para la vista de detalles del staff
struct StaffDailyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                Text("Compañeros de turno:")
                    .font(.title3)
                    .bold()
            }
            .padding(.horizontal)
            
            List {
                Text("Laura Martínez")
                Text("Pedro Sánchez")
            }
            .listStyle(.plain)
        }
    }
}
