import SwiftUI

// MARK: - Gráfico de Pastel para Distribución de Turnos

struct ShiftPieChart: View {
    let data: [String: ShiftStatData]
    let customShiftTypes: [CustomShiftType]
    @EnvironmentObject var themeManager: ThemeManager
    let animate: Bool

    @State private var selectedSlice: String? = nil

    private var sortedData: [(key: String, value: ShiftStatData, color: Color)] {
        data.map { item in
            (
                key: item.key,
                value: item.value,
                color: getShiftColorForType(item.key, customShiftTypes: customShiftTypes, themeManager: themeManager)
            )
        }
        .sorted { $0.value.hours > $1.value.hours }
    }

    private var totalHours: Double {
        data.values.reduce(0) { $0 + $1.hours }
    }

    var body: some View {
        VStack(spacing: DesignSpacing.lg) {
            // Título
            HStack {
                Text("Distribución de turnos")
                    .font(DesignFonts.headline)
                    .foregroundColor(DesignColors.textPrimary)
                Spacer()
            }

            HStack(spacing: DesignSpacing.xl) {
                // Gráfico
                ZStack {
                    // Slices del pie
                    ForEach(Array(sortedData.enumerated()), id: \.element.key) { index, item in
                        PieSlice(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            color: item.color,
                            isSelected: selectedSlice == item.key,
                            animate: animate
                        )
                        .onTapGesture {
                            withAnimation(DesignAnimation.spring) {
                                selectedSlice = selectedSlice == item.key ? nil : item.key
                            }
                            HapticManager.selection()
                        }
                    }

                    // Centro con info
                    VStack(spacing: DesignSpacing.xs) {
                        if let selected = selectedSlice,
                           let item = data[selected] {
                            Text(selected)
                                .font(DesignFonts.captionBold)
                                .foregroundColor(DesignColors.textPrimary)

                            Text(String(format: "%.1fh", item.hours))
                                .font(DesignFonts.headline)
                                .foregroundColor(DesignColors.accent)

                            Text("\(item.count) turnos")
                                .font(DesignFonts.caption)
                                .foregroundColor(DesignColors.textTertiary)
                        } else {
                            Text("Total")
                                .font(DesignFonts.caption)
                                .foregroundColor(DesignColors.textTertiary)

                            Text(String(format: "%.0fh", totalHours))
                                .font(DesignFonts.title)
                                .foregroundColor(DesignColors.textPrimary)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(DesignColors.cardBackground)
                    )
                }
                .frame(width: 160, height: 160)

                // Leyenda
                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    ForEach(sortedData.prefix(5), id: \.key) { item in
                        HStack(spacing: DesignSpacing.sm) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)

                            Text(item.key)
                                .font(DesignFonts.caption)
                                .foregroundColor(
                                    selectedSlice == item.key ? DesignColors.textPrimary : DesignColors.textSecondary
                                )
                                .lineLimit(1)

                            Spacer()

                            Text("\(Int(percentage(for: item.value)))%")
                                .font(DesignFonts.captionBold)
                                .foregroundColor(DesignColors.textTertiary)
                        }
                        .padding(.vertical, DesignSpacing.xs)
                        .padding(.horizontal, DesignSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignCornerRadius.small)
                                .fill(selectedSlice == item.key ? DesignColors.cardBackgroundLight : Color.clear)
                        )
                        .onTapGesture {
                            withAnimation(DesignAnimation.spring) {
                                selectedSlice = selectedSlice == item.key ? nil : item.key
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignColors.cardBackground)
        )
    }

    // MARK: - Helpers

    private func startAngle(for index: Int) -> Angle {
        let precedingHours = sortedData.prefix(index).reduce(0) { $0 + $1.value.hours }
        return Angle(degrees: (precedingHours / totalHours) * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let includingHours = sortedData.prefix(index + 1).reduce(0) { $0 + $1.value.hours }
        return Angle(degrees: (includingHours / totalHours) * 360 - 90)
    }

    private func percentage(for item: ShiftStatData) -> Double {
        guard totalHours > 0 else { return 0 }
        return (item.hours / totalHours) * 100
    }
}

// MARK: - Pie Slice

struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let isSelected: Bool
    let animate: Bool

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let innerRadius = radius * 0.55

            Path { path in
                path.move(to: CGPoint(
                    x: center.x + innerRadius * CGFloat(cos(startAngle.radians)),
                    y: center.y + innerRadius * CGFloat(sin(startAngle.radians))
                ))

                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )

                path.addLine(to: CGPoint(
                    x: center.x + radius * CGFloat(cos(endAngle.radians)),
                    y: center.y + radius * CGFloat(sin(endAngle.radians))
                ))

                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: endAngle,
                    endAngle: startAngle,
                    clockwise: true
                )

                path.closeSubpath()
            }
            .fill(color)
            .scaleEffect(isSelected ? 1.08 : (animate ? 1.0 : 0.5))
            .opacity(animate ? 1 : 0)
            .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 8)
            .animation(DesignAnimation.springBouncy, value: animate)
            .animation(DesignAnimation.spring, value: isSelected)
        }
    }
}
