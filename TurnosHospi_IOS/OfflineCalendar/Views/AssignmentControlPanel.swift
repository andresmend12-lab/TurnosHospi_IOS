import SwiftUI

// MARK: - Panel de Control de Asignación

struct AssignmentControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Namespace private var chipAnimation

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            // Header con título y badge
            panelHeader

            // Chips de turnos
            shiftChipsSection

            // Botón de guardar
            saveButton
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
                .shadow(color: DesignShadows.medium, radius: DesignShadows.cardShadowRadius, y: DesignShadows.cardShadowY)
        )
    }

    // MARK: - Subviews

    private var panelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSpacing.xxs) {
                Text("Modo Asignación")
                    .font(DesignFonts.headline)
                    .foregroundColor(DesignColors.accent)

                Text("Toca un día para asignar turno")
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textSecondary)
            }

            Spacer()

            // Badge indicador de turno seleccionado
            if !viewModel.selectedShiftToApply.isEmpty {
                Text(viewModel.selectedShiftToApply)
                    .font(DesignFonts.captionBold)
                    .padding(.horizontal, DesignSpacing.md)
                    .padding(.vertical, DesignSpacing.xs)
                    .background(
                        Capsule()
                            .fill(getShiftColorForType(viewModel.selectedShiftToApply, customShiftTypes: viewModel.customShiftTypes, themeManager: themeManager))
                    )
                    .foregroundColor(.white)
            }
        }
    }

    private var shiftChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSpacing.sm) {
                ForEach(viewModel.shiftTypes, id: \.self) { (typeName: String) in
                    ShiftChip(
                        typeName: typeName,
                        isSelected: viewModel.selectedShiftToApply == typeName,
                        color: getShiftColorForType(typeName, customShiftTypes: viewModel.customShiftTypes, themeManager: themeManager),
                        namespace: chipAnimation,
                        action: {
                            withAnimation(DesignAnimation.springBouncy) {
                                viewModel.selectedShiftToApply = typeName
                            }
                            HapticManager.selection()
                        }
                    )
                }
            }
            .padding(.vertical, DesignSpacing.xs)
        }
    }

    private var saveButton: some View {
        Button(action: {
            withAnimation(DesignAnimation.smooth) {
                viewModel.isAssignmentMode = false
            }
            HapticManager.success()
        }) {
            HStack(spacing: DesignSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                Text("Guardar y Salir")
                    .font(DesignFonts.bodyMedium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSpacing.md)
            .background(
                LinearGradient(
                    colors: [DesignColors.success, DesignColors.success.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignCornerRadius.medium)
            .shadow(color: DesignColors.success.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip de Turno

struct ShiftChip: View {
    let typeName: String
    let isSelected: Bool
    let color: Color
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(typeName)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.vertical, DesignSpacing.sm)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(color)
                                .matchedGeometryEffect(id: "selectedChip", in: namespace)
                                .shadow(color: color.opacity(0.5), radius: 6, y: 2)
                        } else {
                            Capsule()
                                .fill(color.opacity(0.25))
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                )
                .foregroundColor(isSelected ? (color.luminance < 0.45 ? .white : .black) : .white)
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
