import SwiftUI

// MARK: - Vista del Grid del Calendario

struct CalendarGridView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel

    let daysOfWeek = ["L", "M", "X", "J", "V", "S", "D"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack {
            // Cabecera Mes
            HStack {
                Button(action: { viewModel.changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
                Spacer()
                Text(monthTitle(from: viewModel.currentMonth))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { viewModel.changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, DesignSpacing.lg)

            // Días Semana
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                        .fontWeight(.bold)
                }
            }
            .padding(.bottom, DesignSpacing.sm)

            // Grid Días
            LazyVGrid(columns: columns, spacing: DesignSpacing.md) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCellView(date: date, viewModel: viewModel)
                    } else {
                        Text("").frame(height: DesignSizes.dayCell)
                    }
                }
            }
        }
    }

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func daysInMonth() -> [Date?] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2 // Lunes como primer día de la semana

        guard let range = calendar.range(of: .day, in: .month, for: viewModel.currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.currentMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // weekday: 1=Domingo, 2=Lunes, 3=Martes, 4=Miércoles, 5=Jueves, 6=Viernes, 7=Sábado
        // Queremos: Lunes=0, Martes=1, Miércoles=2, Jueves=3, Viernes=4, Sábado=5, Domingo=6
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
}
