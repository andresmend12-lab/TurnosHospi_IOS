import SwiftUI

// MARK: - Vista de Celda del Día

struct DayCellView: View {
    let date: Date
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
    }

    var body: some View {
        let dateKey = viewModel.dateKey(for: date)
        let effectiveShift = viewModel.getEffectiveShift(for: date)
        let hasNotes = !(viewModel.localNotes[dateKey]?.isEmpty ?? true)
        let bgColor = getBackgroundColor(effectiveShift: effectiveShift)

        ZStack(alignment: .topTrailing) {
            // Día con fondo
            Text("\(Calendar.current.component(.day, from: date))")
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(getTextColor(effectiveShift: effectiveShift))
                .frame(width: DesignSizes.dayCell, height: DesignSizes.dayCell)
                .background(
                    ZStack {
                        // Fondo del turno
                        Circle().fill(bgColor)

                        // Anillo de "Hoy"
                        if isToday {
                            Circle()
                                .stroke(DesignColors.accent, lineWidth: 2)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                // Indicador visual de saliente automático (borde punteado)
                .overlay(
                    Group {
                        if effectiveShift?.isAutomatic == true {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                                )
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                )

            // Indicador de notas (esquina superior derecha)
            if hasNotes {
                Circle()
                    .fill(DesignColors.noteIndicator)
                    .frame(width: DesignSizes.noteIndicator, height: DesignSizes.noteIndicator)
                    .offset(x: 2, y: -2)
                    .shadow(color: DesignColors.noteIndicator.opacity(0.5), radius: 2)
            }
        }
        .onTapGesture {
            viewModel.handleDayClick(date: date)
        }
    }

    // MARK: - Helpers

    private func getBackgroundColor(effectiveShift: (name: String, isAutomatic: Bool)?) -> Color {
        guard let shift = effectiveShift else {
            return Color.clear
        }

        return getShiftColorForType(
            shift.name,
            customShiftTypes: viewModel.customShiftTypes,
            themeManager: themeManager
        )
    }

    private func getTextColor(effectiveShift: (name: String, isAutomatic: Bool)?) -> Color {
        guard let shift = effectiveShift else {
            return .white
        }

        let bgColor = getShiftColorForType(
            shift.name,
            customShiftTypes: viewModel.customShiftTypes,
            themeManager: themeManager
        )

        // Usar color oscuro si el fondo es claro
        return bgColor.luminance > 0.5 ? .black : .white
    }
}
