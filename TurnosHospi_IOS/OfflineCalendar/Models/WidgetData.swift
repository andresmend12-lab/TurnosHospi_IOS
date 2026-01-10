import Foundation

// MARK: - Datos para Widget

struct CalendarWidgetData: Codable {
    let todayShift: String?
    let tomorrowShift: String?
    let weekStats: WeekStats
    let lastUpdated: Date

    struct WeekStats: Codable {
        let totalShifts: Int
        let totalHours: Double
        let remainingShifts: Int
    }
}

// MARK: - Extensión del ViewModel para Widget

extension OfflineCalendarViewModel {

    /// Genera datos para el widget
    func generateWidgetData() -> CalendarWidgetData {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let todayKey = dateKey(for: today)
        let tomorrowKey = dateKey(for: tomorrow)

        let todayShift = localShifts[todayKey]?.shiftName ??
            (shouldShowSaliente(for: today) ? "Saliente" : nil)
        let tomorrowShift = localShifts[tomorrowKey]?.shiftName ??
            (shouldShowSaliente(for: tomorrow) ? "Saliente" : nil)

        // Calcular stats de la semana actual
        let weekStats = calculateCurrentWeekStats()

        return CalendarWidgetData(
            todayShift: todayShift,
            tomorrowShift: tomorrowShift,
            weekStats: weekStats,
            lastUpdated: Date()
        )
    }

    private func calculateCurrentWeekStats() -> CalendarWidgetData.WeekStats {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return CalendarWidgetData.WeekStats(totalShifts: 0, totalHours: 0, remainingShifts: 0)
        }

        var totalShifts = 0
        var totalHours = 0.0
        var remainingShifts = 0

        var currentDate = weekInterval.start
        while currentDate < weekInterval.end {
            let key = dateKey(for: currentDate)
            if let shift = localShifts[key] {
                totalShifts += 1
                totalHours += getShiftDurationHours(
                    shift: shift,
                    shiftDurations: shiftDurations,
                    customShiftTypes: customShiftTypes
                )

                if currentDate > today {
                    remainingShifts += 1
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return CalendarWidgetData.WeekStats(
            totalShifts: totalShifts,
            totalHours: totalHours,
            remainingShifts: remainingShifts
        )
    }

    /// Guarda datos para el widget en App Group
    func saveWidgetData() {
        let widgetData = generateWidgetData()

        if let encoded = try? JSONEncoder().encode(widgetData),
           let sharedDefaults = UserDefaults(suiteName: "group.com.turnoshospi.shared") {
            sharedDefaults.set(encoded, forKey: "widget_calendar_data")
        }
    }
}
