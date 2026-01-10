import SwiftUI

// MARK: - Sheet de Plantillas

struct TemplateSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShiftTemplate? = nil
    @State private var startDate = Date()
    @State private var weeksToApply = 4
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSpacing.xl) {
                    // Plantillas predefinidas
                    VStack(alignment: .leading, spacing: DesignSpacing.md) {
                        Text("Plantillas disponibles")
                            .font(DesignFonts.headline)
                            .foregroundColor(DesignColors.textPrimary)

                        ForEach(ShiftTemplate.predefined) { template in
                            TemplateRow(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id
                            ) {
                                selectedTemplate = template
                                HapticManager.selection()
                            }
                        }
                    }

                    if selectedTemplate != nil {
                        Divider()
                            .background(DesignColors.cardBackgroundLight)

                        // Opciones de aplicación
                        VStack(alignment: .leading, spacing: DesignSpacing.md) {
                            Text("Aplicar plantilla")
                                .font(DesignFonts.headline)
                                .foregroundColor(DesignColors.textPrimary)

                            // Fecha de inicio
                            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                                Text("Desde")
                                    .font(DesignFonts.bodyMedium)
                                    .foregroundColor(DesignColors.textSecondary)

                                DatePicker(
                                    "",
                                    selection: $startDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(DesignColors.accent)
                            }

                            // Semanas a aplicar
                            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                                Text("Número de semanas")
                                    .font(DesignFonts.bodyMedium)
                                    .foregroundColor(DesignColors.textSecondary)

                                Stepper("\(weeksToApply) semanas", value: $weeksToApply, in: 1...12)
                                    .tint(DesignColors.accent)
                            }

                            // Resumen
                            let endDate = Calendar.current.date(
                                byAdding: .day,
                                value: weeksToApply * 7 - 1,
                                to: startDate
                            )!

                            Text("Se aplicará desde \(formatDate(startDate)) hasta \(formatDate(endDate))")
                                .font(DesignFonts.caption)
                                .foregroundColor(DesignColors.textTertiary)
                                .padding(DesignSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignCornerRadius.small)
                                        .fill(DesignColors.accent.opacity(0.1))
                                )
                        }

                        // Botón aplicar
                        Button {
                            showConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Aplicar plantilla")
                            }
                            .font(DesignFonts.bodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSpacing.lg)
                            .background(DesignColors.accent)
                            .cornerRadius(DesignCornerRadius.medium)
                        }
                    }
                }
                .padding(DesignSpacing.xl)
            }
            .background(DesignColors.cardBackground.ignoresSafeArea())
            .navigationTitle("Plantillas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .alert("Aplicar plantilla", isPresented: $showConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Aplicar") {
                    applyTemplate()
                }
            } message: {
                Text("¿Estás seguro? Esto sobrescribirá los turnos existentes en el período seleccionado.")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func applyTemplate() {
        guard let template = selectedTemplate else { return }

        HapticManager.impact()

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        let totalDays = weeksToApply * 7
        let patternLength = template.pattern.count

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }

            let patternIndex = dayOffset % patternLength
            let templateDay = template.pattern[patternIndex]

            let key = viewModel.dateKey(for: date)

            if let shiftName = templateDay.shiftName {
                viewModel.localShifts[key] = UserShift(
                    shiftName: shiftName,
                    isHalfDay: templateDay.isHalfDay
                )
            } else {
                viewModel.localShifts.removeValue(forKey: key)
            }
        }

        viewModel.saveData()
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: ShiftTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(DesignFonts.bodyMedium)
                            .foregroundColor(DesignColors.textPrimary)

                        Text(template.description)
                            .font(DesignFonts.caption)
                            .foregroundColor(DesignColors.textTertiary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignColors.accent)
                    }
                }

                // Preview del patrón (primera semana)
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let templateDay = template.pattern.first(where: { $0.dayIndex == dayIndex })

                        Circle()
                            .fill(colorForShift(templateDay?.shiftName))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(dayLabel(dayIndex))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(isSelected ? DesignColors.accent.opacity(0.1) : DesignColors.cardBackgroundLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                            .stroke(isSelected ? DesignColors.accent : Color.clear, lineWidth: 1)
                    )
            )
        }
    }

    private func dayLabel(_ index: Int) -> String {
        ["L", "M", "X", "J", "V", "S", "D"][index]
    }

    private func colorForShift(_ shiftName: String?) -> Color {
        guard let name = shiftName else { return DesignColors.shiftFree }
        return getShiftColorForType(name, customShiftTypes: [])
    }
}
