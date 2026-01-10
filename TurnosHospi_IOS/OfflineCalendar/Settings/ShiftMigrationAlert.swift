import SwiftUI

// MARK: - Alerta de Migración de Turnos

struct ShiftMigrationAlert: View {
    let analysis: OfflineCalendarViewModel.ShiftMigrationAnalysis
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: DesignSpacing.lg) {
            // Icono de advertencia
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignColors.warning)

            Text("Turnos incompatibles")
                .font(DesignFonts.title)
                .foregroundColor(DesignColors.textPrimary)

            Text("Al cambiar el patrón de turnos, \(analysis.totalOrphaned) asignación(es) quedarán sin tipo válido:")
                .font(DesignFonts.body)
                .foregroundColor(DesignColors.textSecondary)
                .multilineTextAlignment(.center)

            // Lista de turnos afectados
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                ForEach(Array(analysis.orphanedShifts.keys.sorted()), id: \.self) { shiftName in
                    HStack {
                        Circle()
                            .fill(DesignColors.warning)
                            .frame(width: 8, height: 8)
                        Text("\(shiftName): \(analysis.orphanedShifts[shiftName] ?? 0) día(s)")
                            .font(DesignFonts.body)
                            .foregroundColor(DesignColors.textPrimary)
                    }
                }
            }
            .padding()
            .background(DesignColors.cardBackgroundLight)
            .cornerRadius(DesignCornerRadius.medium)

            // Opciones
            VStack(spacing: DesignSpacing.md) {
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Eliminar turnos incompatibles")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignColors.error)
                    .foregroundColor(.white)
                    .cornerRadius(DesignCornerRadius.medium)
                }

                Button(action: onCancel) {
                    Text("Cancelar cambio")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignColors.cardBackgroundLight)
                        .foregroundColor(DesignColors.textPrimary)
                        .cornerRadius(DesignCornerRadius.medium)
                }
            }
        }
        .padding(DesignSpacing.xxl)
        .background(DesignColors.cardBackground)
        .cornerRadius(DesignCornerRadius.large)
        .shadow(color: DesignShadows.heavy, radius: 20)
    }
}
