import SwiftUI

// MARK: - CALENDARIO COMPARTIDO
struct CalendarWithShiftsView: View {
    @Binding var selectedDate: Date
    var shifts: [Shift] // Recibe la lista de turnos desde Firebase (uso original)
    // NUEVO: Datos de asignación de personal para la planta
    var monthlyAssignments: [Date: [PlantShiftWorker]]
    
    let days = ["L", "M", "X", "J", "V", "S", "D"]
    
    // Obtener días del mes
    var daysInMonth: [Int] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: selectedDate) else { return [] }
        return Array(range)
    }
    
    // Obtener desplazamiento del primer día
    var firstWeekdayOfMonth: Int {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        guard let firstDay = Calendar.current.date(from: components) else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: firstDay)
        // Ajuste para lunes (Dom=1 -> 6, Lun=2 -> 0)
        return weekday == 1 ? 6 : weekday - 2
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Cabecera mes
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
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
            
            // Días semana
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
                
                // Espacios vacíos iniciales
                ForEach(0..<firstWeekdayOfMonth, id: \.self) { _ in
                    Text("").frame(height: 40)
                }
                
                // Días reales
                ForEach(daysInMonth, id: \.self) { day in
                    let date = getDate(for: day)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    // Obtener el inicio del día para la búsqueda en el diccionario (NUEVO)
                    let startOfDay = Calendar.current.startOfDay(for: date)
                    let workers = monthlyAssignments[startOfDay] ?? []
                    let workerCount = workers.count
                    let workerInitials = workers.prefix(2).map { $0.initial } // Tomar las iniciales de los 2 primeros
                    
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
                            
                            // Mostrar las iniciales si hay trabajadores asignados (NUEVO)
                            if workerCount > 0 {
                                HStack(spacing: 2) {
                                    ForEach(workerInitials, id: \.self) { initial in
                                        Text(initial)
                                            .font(.system(size: 8).bold())
                                            .foregroundColor(.white)
                                    }
                                    if workerCount > 2 {
                                         Text("+\(workerCount - 2)")
                                            .font(.system(size: 8).bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 10)
                                .padding(.horizontal, 2)
                                .background(Color.neonViolet.opacity(0.8)) // Usamos un color de la app
                                .cornerRadius(4)
                                
                            } else {
                                // Relleno si no hay asignaciones
                                Spacer().frame(height: 10)
                            }
                            
                        }
                        .frame(height: 45) // Ajuste de altura para acomodar el nuevo contenido
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
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }
    
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
