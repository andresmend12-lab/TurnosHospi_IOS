import SwiftUI

// MARK: - Gráfico de Barras Comparativo

struct ShiftBarChart: View {
    let currentMonth: OfflineMonthlyStats
    let previousMonth: OfflineMonthlyStats
    let currentMonthName: String
    let previousMonthName: String
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            // Título
            Text("Comparativa mensual")
                .font(DesignFonts.headline)
                .foregroundColor(DesignColors.textPrimary)

            // Leyenda
            HStack(spacing: DesignSpacing.lg) {
                LegendDot(color: DesignColors.accent, label: currentMonthName)
                LegendDot(color: DesignColors.accentSecondary.opacity(0.5), label: previousMonthName)
            }

            // Barras comparativas
            VStack(spacing: DesignSpacing.lg) {
                ComparisonBar(
                    label: "Horas",
                    currentValue: currentMonth.totalHours,
                    previousValue: previousMonth.totalHours,
                    format: "%.0f h",
                    animate: animate
                )

                ComparisonBar(
                    label: "Turnos",
                    currentValue: Double(currentMonth.totalShifts),
                    previousValue: Double(previousMonth.totalShifts),
                    format: "%.0f",
                    animate: animate
                )

                // Promedio de horas por turno
                let currentAvg = currentMonth.totalShifts > 0 ?
                    currentMonth.totalHours / Double(currentMonth.totalShifts) : 0
                let previousAvg = previousMonth.totalShifts > 0 ?
                    previousMonth.totalHours / Double(previousMonth.totalShifts) : 0

                ComparisonBar(
                    label: "Promedio/turno",
                    currentValue: currentAvg,
                    previousValue: previousAvg,
                    format: "%.1f h",
                    animate: animate
                )
            }

            // Indicador de cambio
            if currentMonth.totalHours > 0 || previousMonth.totalHours > 0 {
                changeIndicator
            }
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignColors.cardBackground)
        )
    }

    private var changeIndicator: some View {
        let change = previousMonth.totalHours > 0 ?
            ((currentMonth.totalHours - previousMonth.totalHours) / previousMonth.totalHours) * 100 : 0

        let isPositive = change >= 0

        return HStack(spacing: DesignSpacing.sm) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 14, weight: .bold))

            Text(String(format: "%+.1f%% vs mes anterior", change))
                .font(DesignFonts.bodyMedium)
        }
        .foregroundColor(isPositive ? DesignColors.success : DesignColors.error)
        .padding(DesignSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                .fill((isPositive ? DesignColors.success : DesignColors.error).opacity(0.1))
        )
    }
}

// MARK: - Legend Dot

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: DesignSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(DesignFonts.caption)
                .foregroundColor(DesignColors.textSecondary)
        }
    }
}

// MARK: - Comparison Bar

struct ComparisonBar: View {
    let label: String
    let currentValue: Double
    let previousValue: Double
    let format: String
    let animate: Bool

    private var maxValue: Double {
        max(currentValue, previousValue, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            HStack {
                Text(label)
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(DesignColors.textSecondary)

                Spacer()

                Text(String(format: format, currentValue))
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(DesignColors.textPrimary)
            }

            // Barras
            GeometryReader { geometry in
                VStack(spacing: 4) {
                    // Barra actual
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignColors.accent)
                            .frame(
                                width: animate ? geometry.size.width * CGFloat(currentValue / maxValue) : 0,
                                height: 12
                            )
                        Spacer(minLength: 0)
                    }

                    // Barra anterior
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignColors.accentSecondary.opacity(0.4))
                            .frame(
                                width: animate ? geometry.size.width * CGFloat(previousValue / maxValue) : 0,
                                height: 8
                            )
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 24)
            .animation(DesignAnimation.smooth, value: animate)
        }
    }
}
