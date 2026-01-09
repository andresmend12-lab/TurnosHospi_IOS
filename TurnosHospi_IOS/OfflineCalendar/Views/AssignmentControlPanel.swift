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
                        let chipColor = getShiftColorForType(typeName, customShiftTypes: viewModel.customShiftTypes)

                        Button(action: { viewModel.selectedShiftToApply = typeName }) {
                            Text(typeName)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, DesignSpacing.lg)
                                .padding(.vertical, DesignSpacing.sm)
                                .background(isSelected ? chipColor : getButtonColor(for: typeName).opacity(0.6))
                                .foregroundColor(isSelected ? (chipColor.luminance < 0.45 ? .white : .black) : .white)
                                .cornerRadius(DesignCornerRadius.pill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignCornerRadius.pill)
                                        .stroke(DesignColors.accent, lineWidth: isSelected ? 0 : 1)
                                )
                        }
                    }
                }
            }

            Button(action: { viewModel.isAssignmentMode = false }) {
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

    private func getButtonColor(for typeName: String) -> Color {
        return getShiftColorForType(typeName, customShiftTypes: viewModel.customShiftTypes)
    }
}
