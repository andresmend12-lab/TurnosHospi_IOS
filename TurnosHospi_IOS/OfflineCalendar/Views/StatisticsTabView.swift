import SwiftUI

// MARK: - Vista del Tab de Estadísticas

struct StatisticsTabView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentMonth = Date()
    @State private var animateStats = false
    @State private var selectedBreakdownItem: String? = nil

    var stats: OfflineMonthlyStats {
        viewModel.calculateStats(for: currentMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.xl) {
                // Selector de mes
                monthSelector

                if stats.totalShifts == 0 || stats.totalHours == 0.0 {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    statsContent
                        .transition(.opacity)
                }
            }
            .padding(DesignSpacing.lg)
        }
        .background(DesignGradients.backgroundMain.ignoresSafeArea())
        .onAppear {
            withAnimation(DesignAnimation.smooth.delay(0.2)) {
                animateStats = true
            }
        }
        .onChange(of: currentMonth) { _ in
            animateStats = false
            withAnimation(DesignAnimation.smooth.delay(0.1)) {
                animateStats = true
            }
        }
    }

    // MARK: - Subviews

    private var monthSelector: some View {
        HStack {
            Button(action: {
                withAnimation(DesignAnimation.smooth) {
                    if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                        currentMonth = newDate
                    }
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

            Text(monthTitle(from: currentMonth))
                .font(DesignFonts.title)
                .foregroundColor(.white)
                .textCase(.uppercase)

            Spacer()

            Button(action: {
                withAnimation(DesignAnimation.smooth) {
                    if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
                        currentMonth = newDate
                    }
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
        .padding(DesignSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSpacing.lg) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(DesignColors.textTertiary)

            VStack(spacing: DesignSpacing.xs) {
                Text("Sin estadísticas")
                    .font(DesignFonts.headline)
                    .foregroundColor(DesignColors.textSecondary)

                Text("No hay turnos registrados este mes")
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpacing.xxxl)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
        )
    }

    private var statsContent: some View {
        VStack(spacing: DesignSpacing.lg) {
            // Cards principales
            HStack(spacing: DesignSpacing.md) {
                mainStatCard(
                    title: "Horas",
                    value: String(format: "%.0f", animateStats ? stats.totalHours : 0),
                    subtitle: "trabajadas",
                    icon: "clock.fill",
                    color: DesignColors.accent
                )

                mainStatCard(
                    title: "Turnos",
                    value: animateStats ? "\(stats.totalShifts)" : "0",
                    subtitle: "completados",
                    icon: "calendar.badge.checkmark",
                    color: DesignColors.success
                )
            }

            // Detalle por turno
            if !stats.breakdown.isEmpty {
                breakdownSection
            }
        }
    }

    private func mainStatCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(DesignFonts.captionMedium)
                    .foregroundColor(DesignColors.textSecondary)
            }

            Text(value)
                .font(DesignFonts.statValue)
                .foregroundColor(.white)
                .contentTransition(.numericText())

            Text(subtitle)
                .font(DesignFonts.caption)
                .foregroundColor(DesignColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.15), radius: 10, y: 5)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Detalle por turno")
                .font(DesignFonts.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSpacing.sm)

            VStack(spacing: DesignSpacing.sm) {
                ForEach(stats.breakdown.sorted(by: { $0.value.hours > $1.value.hours }), id: \.key) { shiftName, data in
                    shiftBreakdownRow(shiftName: shiftName, data: data)
                }
            }
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
        )
    }

    private func shiftBreakdownRow(shiftName: String, data: ShiftStatData) -> some View {
        let color = getShiftColorForType(shiftName, customShiftTypes: viewModel.customShiftTypes, themeManager: themeManager)
        let isSelected = selectedBreakdownItem == shiftName
        let percentage = stats.totalHours > 0 ? (data.hours / stats.totalHours) * 100 : 0

        return Button(action: {
            withAnimation(DesignAnimation.springBouncy) {
                selectedBreakdownItem = isSelected ? nil : shiftName
            }
            HapticManager.selection()
        }) {
            VStack(spacing: DesignSpacing.sm) {
                HStack {
                    // Indicador de color
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .shadow(color: color.opacity(0.5), radius: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(shiftName)
                            .font(DesignFonts.bodyMedium)
                            .foregroundColor(.white)

                        Text("\(data.count) turno\(data.count == 1 ? "" : "s")")
                            .font(DesignFonts.caption)
                            .foregroundColor(DesignColors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1fh", animateStats ? data.hours : 0))
                            .font(DesignFonts.headline)
                            .foregroundColor(color)
                            .contentTransition(.numericText())

                        Text(String(format: "%.0f%%", percentage))
                            .font(DesignFonts.caption)
                            .foregroundColor(DesignColors.textSecondary)
                    }
                }

                // Barra de progreso
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignColors.cardBackgroundLight)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: animateStats ? geometry.size.width * (percentage / 100) : 0, height: 6)
                            .animation(DesignAnimation.smooth.delay(0.1), value: animateStats)
                    }
                }
                .frame(height: 6)
            }
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(isSelected ? color.opacity(0.1) : DesignColors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                            .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
