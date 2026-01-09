import SwiftUI

// MARK: - Panel de Control de Asignación

struct AssignmentControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            Text("Modo Asignación")
                .font(.headline)
                .foregroundColor(DesignColors.accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.md) {
                    ForEach(viewModel.shiftTypes, id: \.self) { (typeName: String) in
                        let isSelected = viewModel.selectedShiftToApply == typeName
                        let chipColor = getShiftColorForType(
                            typeName,
                            customShiftTypes: viewModel.customShiftTypes,
                            themeManager: themeManager
                        )

                        Button(action: {
                            viewModel.selectedShiftToApply = typeName
                            HapticManager.selection()
                        }) {
                            Text(typeName)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, DesignSpacing.lg)
                                .padding(.vertical, DesignSpacing.sm)
                                .background(isSelected ? chipColor : chipColor.opacity(0.3))
                                .foregroundColor(isSelected ? (chipColor.luminance < 0.45 ? .white : .black) : .white)
                                .cornerRadius(DesignCornerRadius.pill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignCornerRadius.pill)
                                        .stroke(isSelected ? Color.clear : DesignColors.accent.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            Button(action: {
                viewModel.isAssignmentMode = false
                HapticManager.success()
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Guardar y Salir")
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignColors.success)
                .cornerRadius(DesignCornerRadius.medium)
            }
        }
        .padding(DesignSpacing.lg)
    }
}
