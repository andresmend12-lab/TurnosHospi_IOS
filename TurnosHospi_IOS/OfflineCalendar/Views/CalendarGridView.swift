import SwiftUI

// MARK: - Vista del Grid del Calendario

struct CalendarGridView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @State private var dragOffset: CGFloat = 0

    let daysOfWeek = ["L", "M", "X", "J", "V", "S", "D"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: DesignSpacing.lg) {
            // Cabecera Mes con stats
            monthHeader

            // Días de la semana
            weekdayHeader

            // Grid de días con gesture para cambiar mes
            calendarGrid
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button(action: {
                withAnimation(DesignAnimation.smooth) {
                    viewModel.changeMonth(by: -1)
                }
                HapticManager.selection()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignColors.accent)
                    .frame(width: 44, height: 44)
                    .background(DesignColors.cardBackgroundLight.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: DesignSpacing.xxs) {
                Text(monthTitle(from: viewModel.currentMonth))
                    .font(DesignFonts.title)
                    .foregroundColor(.white)
                    .textCase(.uppercase)

                // Mini stats con animación
                let stats = viewModel.currentMonthQuickStats
                if stats.totalShifts > 0 {
                    HStack(spacing: DesignSpacing.sm) {
                        Label("\(stats.totalShifts)", systemImage: "calendar")
                        Text("·")
                        Label(String(format: "%.0fh", stats.totalHours), systemImage: "clock")
                    }
                    .font(DesignFonts.captionMedium)
                    .foregroundColor(DesignColors.textSecondary)
                    .transition(.opacity.combined(with: .scale))
                }
            }

            Spacer()

            Button(action: {
                withAnimation(DesignAnimation.smooth) {
                    viewModel.changeMonth(by: 1)
                }
                HapticManager.selection()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignColors.accent)
                    .frame(width: 44, height: 44)
                    .background(DesignColors.cardBackgroundLight.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DesignSpacing.sm)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack {
            ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(DesignFonts.captionBold)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(index >= 5 ? DesignColors.accent.opacity(0.7) : DesignColors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSpacing.xs)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: DesignSpacing.md) {
            ForEach(daysInMonth(), id: \.self) { date in
                if let date = date {
                    DayCellView(date: date, viewModel: viewModel)
                } else {
                    Color.clear
                        .frame(height: DesignSizes.dayCell)
                }
            }
        }
        .padding(.horizontal, DesignSpacing.xs)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width * 0.3
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(DesignAnimation.springBouncy) {
                        if value.translation.width > threshold {
                            viewModel.changeMonth(by: -1)
                            HapticManager.selection()
                        } else if value.translation.width < -threshold {
                            viewModel.changeMonth(by: 1)
                            HapticManager.selection()
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    // MARK: - Helpers

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
