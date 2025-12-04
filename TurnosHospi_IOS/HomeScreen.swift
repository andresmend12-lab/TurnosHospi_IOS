import SwiftUI
import FirebaseDatabase // CORREGIDO: Usamos Realtime Database

struct HomeScreen: View {
    @EnvironmentObject var authService: AuthService
    
    // Estado para el calendario
    @State private var currentMonth: Date = Date()
    @State private var shifts: [String: String] = [:]
    
    // Configuración del calendario
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()
    
    var body: some View {
        NavigationView { // Usamos NavigationView para mayor compatibilidad
            VStack(spacing: 20) {
                
                // --- 1. SECCIÓN CALENDARIO ---
                VStack {
                    // Cabecera del mes con flechas
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .padding()
                        }
                        
                        Text(dateFormatter.string(from: currentMonth).capitalized)
                            .font(.title2)
                            .bold()
                            .frame(maxWidth: .infinity)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .padding()
                        }
                    }
                    
                    // Días de la semana
                    HStack {
                        ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Rejilla de días
                    let days = daysInMonth()
                    // Usamos columnas fijas para evitar errores de layout
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        // Espacios vacíos al inicio del mes
                        ForEach(0..<startingSpaces(), id: \.self) { _ in
                            Text("")
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Los días del mes
                        ForEach(days, id: \.self) { date in
                            let dayNumber = calendar.component(.day, from: date)
                            let shiftType = getShiftForDate(date)
                            
                            VStack {
                                Text("\(dayNumber)")
                                    .font(.body)
                                    .foregroundColor(shiftType != nil ? .white : .primary)
                            }
                            .frame(width: 35, height: 35)
                            .background(getShiftColor(shiftType)) // Colorear turno
                            .clipShape(Circle())
                            .onTapGesture {
                                print("Tocado día \(dayNumber)")
                            }
                        }
                    }
                }
                .padding()
                // Color de fondo adaptable (blanco en modo claro, oscuro en modo oscuro)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)

                Spacer()
                
                // --- 2. SECCIÓN BOTONES DE ACCIÓN ---
                VStack(spacing: 15) {
                    
                    // Botón MI PLANTA
                    NavigationLink(destination: PlantDetailView()) { // Vinculado a tu vista existente
                        HStack {
                            Image(systemName: "building.2.fill")
                            Text("Mi Planta")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    
                    // Botón COLOREAR TURNOS
                    NavigationLink(destination: Text("Pantalla de Colorear Turnos")) {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                            Text("Colorear Turnos")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                    }
                    
                    // Botón CERRAR SESIÓN
                    Button(action: {
                        authService.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Cerrar Sesión")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
            }
            .navigationTitle("TurnosHospi")
            .navigationBarTitleDisplayMode(.inline)
            // --- 3. BARRA SUPERIOR (Perfil y Configuración) ---
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: Text("Vista de Perfil")) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) { // Vinculado a tu vista existente
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                fetchShifts()
            }
        }
    }
    
    // MARK: - Lógica del Calendario
    
    func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
            fetchShifts()
        }
    }
    
    func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }
    
    func startingSpaces() -> Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else { return 0 }
        let weekDay = calendar.component(.weekday, from: firstDay)
        // Ajuste para Lunes = primer día de la semana
        // Domingo(1) -> 6, Lunes(2) -> 0, Martes(3) -> 1...
        let spaces = weekDay - 2
        return spaces < 0 ? 6 : spaces
    }
    
    // MARK: - Lógica de Datos
    
    func fetchShifts() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        // Simulación:
        self.shifts = [
            today: "M"
        ]
    }
    
    func getShiftForDate(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return shifts[key]
    }
    
    func getShiftColor(_ type: String?) -> Color {
        guard let type = type else { return Color.clear }
        switch type {
        case "M": return Color.orange
        case "T": return Color.blue
        case "N": return Color.purple
        case "L": return Color.green
        default: return Color.gray
        }
    }
}

// CORREGIDO: Sintaxis antigua para Xcode 14
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
            .environmentObject(AuthService()) // Creamos una instancia nueva para la preview
    }
}
