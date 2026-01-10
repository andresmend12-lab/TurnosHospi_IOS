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

    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    var body: some View {
        let dateKey = viewModel.dateKey(for: date)
        let effectiveShift = viewModel.getEffectiveShift(for: date)
        let hasNotes = !(viewModel.localNotes[dateKey]?.isEmpty ?? true)
        let bgColor = getBackgroundColor(effectiveShift: effectiveShift)

        ZStack {
            // Fondo principal del día
            dayCellBackground(bgColor: bgColor, effectiveShift: effectiveShift)

            // Número del día
            Text("\(Calendar.current.component(.day, from: date))")
                .font(isToday ? DesignFonts.dayNumberLarge : DesignFonts.dayNumber)
                .foregroundColor(getTextColor(effectiveShift: effectiveShift))
                .shadow(color: effectiveShift != nil ? .black.opacity(0.3) : .clear, radius: 1, y: 1)

            // Indicadores
            VStack {
                HStack {
                    Spacer()
                    // Indicador de notas (esquina superior derecha)
                    if hasNotes {
                        noteIndicator
                    }
                }
                Spacer()
                HStack {
                    // Indicador de media jornada (esquina inferior izquierda)
                    if let shift = viewModel.localShifts[dateKey], shift.isHalfDay {
                        halfDayIndicator
                    }
                    Spacer()
                }
            }
            .padding(DesignSpacing.xxs)
        }
        .frame(width: DesignSizes.dayCell, height: DesignSizes.dayCell)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(DesignAnimation.quick) {
                viewModel.handleDayClick(date: date)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(DesignAnimation.springBouncy, value: isSelected)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func dayCellBackground(bgColor: Color, effectiveShift: (name: String, isAutomatic: Bool)?) -> some View {
        ZStack {
            // Fondo base con gradiente si tiene turno
            if effectiveShift != nil {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [bgColor, bgColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: bgColor.opacity(0.4), radius: 4, y: 2)
            } else {
                Circle()
                    .fill(isWeekend ? DesignColors.cardBackgroundLight.opacity(0.3) : Color.clear)
            }

            // Anillo de "Hoy" con glow
            if isToday {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [DesignColors.accent, DesignColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: DesignSizes.todayRing
                    )
                    .shadow(color: DesignColors.accent.opacity(0.5), radius: 4)
            }

            // Anillo de selección
            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            }

            // Indicador visual de saliente automático (borde punteado)
            if effectiveShift?.isAutomatic == true {
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var noteIndicator: some View {
        Circle()
            .fill(DesignColors.noteIndicator)
            .frame(width: DesignSizes.noteIndicator, height: DesignSizes.noteIndicator)
            .shadow(color: DesignColors.noteIndicator.opacity(0.6), radius: 3)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
    }

    private var halfDayIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(DesignColors.halfDayIndicator)
            .frame(width: 8, height: DesignSizes.halfDayIndicator)
            .shadow(color: DesignColors.halfDayIndicator.opacity(0.5), radius: 2)
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
            return isWeekend ? DesignColors.textSecondary : .white
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
