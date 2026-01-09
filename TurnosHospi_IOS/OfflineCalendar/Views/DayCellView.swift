import SwiftUI

// MARK: - Vista de Celda del Día

struct DayCellView: View {
    let date: Date
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let dateKey = viewModel.dateKey(for: date)
        let shift = viewModel.localShifts[dateKey]
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let hasNotes = !(viewModel.localNotes[dateKey]?.isEmpty ?? true)

        let bgColor = getBackgroundColor(shift: shift, date: date)

        ZStack(alignment: .top) {
            Text("\(Calendar.current.component(.day, from: date))")
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: DesignSizes.dayCell, height: DesignSizes.dayCell)
                .background(Circle().fill(bgColor))
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )

            if hasNotes {
                Circle()
                    .fill(DesignColors.noteIndicator)
                    .frame(width: DesignSizes.noteIndicator, height: DesignSizes.noteIndicator)
                    .offset(y: 2)
            }
        }
        .onTapGesture {
            viewModel.handleDayClick(date: date)
        }
    }

    func getBackgroundColor(shift: UserShift?, date: Date) -> Color {
        if let shift = shift {
            return getShiftColorForType(shift.shiftName, customShiftTypes: viewModel.customShiftTypes)
        } else {
            // Detectar "Saliente"
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
               let prevShift = viewModel.localShifts[viewModel.dateKey(for: yesterday)],
               normalizeShiftType(prevShift.shiftName) == "Noche" {
                return themeManager.salienteColor
            }
            return Color.clear
        }
    }
}
