import SwiftUI

// MARK: - Vista del Tab de Estadísticas

struct StatisticsTabView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @State private var currentMonth = Date()

    var stats: OfflineMonthlyStats {
        viewModel.calculateStats(for: currentMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.lg) {
                // Selector de mes
                monthSelector

                if stats.totalShifts == 0 || stats.totalHours == 0.0 {
                    emptyStateView
                } else {
                    statsContent
                }
            }
            .padding()
        }
        .background(DesignColors.background)
    }

    // MARK: - Subviews

    private var monthSelector: some View {
        HStack {
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                    currentMonth = newDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
            }

            Spacer()

            Text(monthTitle(from: currentMonth))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .textCase(.uppercase)

            Spacer()

            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
                    currentMonth = newDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(DesignColors.cardBackground)
        .cornerRadius(DesignCornerRadius.medium)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSpacing.md) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Sin estadísticas para este mes")
                .foregroundColor(.gray)
        }
        .padding(.top, 40)
    }

    private var statsContent: some View {
        VStack(spacing: DesignSpacing.lg) {
            // Card principal con total de horas
            totalHoursCard

            // Detalle por turno
            if !stats.breakdown.isEmpty {
                breakdownSection
            }
        }
    }

    private var totalHoursCard: some View {
        VStack(spacing: DesignSpacing.sm) {
            Text("Horas trabajadas")
                .font(.caption)
                .foregroundColor(DesignColors.accent)

            Text(String(format: "%.1f h", stats.totalHours))
                .font(DesignFonts.statsNumber)
                .foregroundColor(.white)

            Text("\(stats.totalShifts) turnos")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSpacing.xxl)
        .background(DesignColors.background)
        .cornerRadius(DesignCornerRadius.large)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text("Detalle por turno")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignSpacing.sm)

            ForEach(stats.breakdown.sorted(by: { $0.value.hours > $1.value.hours }), id: \.key) { shiftName, data in
                shiftBreakdownRow(shiftName: shiftName, data: data)
            }
        }
    }

    private func shiftBreakdownRow(shiftName: String, data: ShiftStatData) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shiftName)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                Text("\(data.count) turnos")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(String(format: "%.1f h", data.hours))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DesignColors.accent)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(DesignCornerRadius.small)
    }

    // MARK: - Helpers

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
