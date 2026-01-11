import SwiftUI

// MARK: - Sheet de Plantillas

struct TemplateSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @StateObject private var templateManager = TemplateManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShiftTemplate? = nil
    @State private var startDate = Date()
    @State private var weeksToApply = 4
    @State private var showConfirmation = false
    @State private var showEditor = false
    @State private var editingTemplate: ShiftTemplate? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSpacing.xl) {
                    // Header con botón crear
                    headerSection

                    // Lista de plantillas o estado vacío
                    if templateManager.templates.isEmpty {
                        emptyStateView
                    } else {
                        templatesListSection
                    }

                    // Opciones de aplicación (si hay plantilla seleccionada)
                    if selectedTemplate != nil {
                        Divider()
                            .background(DesignColors.cardBackgroundLight)

                        applyOptionsSection
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTemplate = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                TemplateEditorSheet(
                    viewModel: viewModel,
                    templateManager: templateManager,
                    editingTemplate: editingTemplate
                )
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

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            Text("Mis Plantillas")
                .font(DesignFonts.headline)
                .foregroundColor(DesignColors.textPrimary)

            Spacer()

            Text("\(templateManager.templates.count)")
                .font(DesignFonts.captionBold)
                .foregroundColor(DesignColors.accent)
                .padding(.horizontal, DesignSpacing.sm)
                .padding(.vertical, DesignSpacing.xs)
                .background(
                    Capsule()
                        .fill(DesignColors.accent.opacity(0.2))
                )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSpacing.lg) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 50))
                .foregroundColor(DesignColors.textTertiary)

            VStack(spacing: DesignSpacing.xs) {
                Text("No tienes plantillas")
                    .font(DesignFonts.headline)
                    .foregroundColor(DesignColors.textSecondary)

                Text("Crea una plantilla para aplicar patrones de turnos fácilmente")
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Button {
                editingTemplate = nil
                showEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Crear plantilla")
                }
                .font(DesignFonts.bodyMedium)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSpacing.xl)
                .padding(.vertical, DesignSpacing.md)
                .background(DesignColors.accent)
                .cornerRadius(DesignCornerRadius.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpacing.xxxl)
    }

    private var templatesListSection: some View {
        VStack(spacing: DesignSpacing.md) {
            ForEach(templateManager.templates) { template in
                TemplateRow(
                    template: template,
                    shiftTypes: viewModel.shiftTypes,
                    customShiftTypes: viewModel.customShiftTypes,
                    isSelected: selectedTemplate?.id == template.id,
                    onSelect: {
                        withAnimation {
                            selectedTemplate = template
                        }
                        HapticManager.selection()
                    },
                    onEdit: {
                        editingTemplate = template
                        showEditor = true
                    },
                    onDelete: {
                        withAnimation {
                            if selectedTemplate?.id == template.id {
                                selectedTemplate = nil
                            }
                            templateManager.deleteTemplate(id: template.id)
                        }
                        HapticManager.warning()
                    }
                )
            }
        }
    }

    private var applyOptionsSection: some View {
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

    // MARK: - Helpers

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
        calendar.firstWeekday = 2  // Lunes = 1

        // Obtener el lunes de la semana de inicio
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)) ?? startDate

        let totalDays = weeksToApply * 7

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }

            let dayIndex = dayOffset % 7
            let shiftName = template.weekPattern[dayIndex]

            let key = viewModel.dateKey(for: date)

            if let shiftName = shiftName {
                viewModel.localShifts[key] = UserShift(
                    shiftName: shiftName,
                    isHalfDay: false
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
    let shiftTypes: [String]
    let customShiftTypes: [CustomShiftType]
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignSpacing.md) {
            // Contenido principal (tappable para seleccionar)
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name.isEmpty ? "Sin nombre" : template.name)
                                .font(DesignFonts.bodyMedium)
                                .foregroundColor(DesignColors.textPrimary)

                            if !template.description.isEmpty {
                                Text(template.description)
                                    .font(DesignFonts.caption)
                                    .foregroundColor(DesignColors.textTertiary)
                            }
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignColors.accent)
                        }
                    }

                    // Preview del patrón semanal
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let shiftName = template.weekPattern[dayIndex]

                            Circle()
                                .fill(colorForShift(shiftName))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(ShiftTemplate.dayAbbreviations[dayIndex])
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            // Botones de acción
            VStack(spacing: DesignSpacing.xs) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.accent)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.error)
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

    private func colorForShift(_ shiftName: String?) -> Color {
        guard let name = shiftName else { return DesignColors.shiftFree }
        return getShiftColorForType(name, customShiftTypes: customShiftTypes)
    }
}

// MARK: - Template Editor Sheet

struct TemplateEditorSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @ObservedObject var templateManager: TemplateManager
    @Environment(\.dismiss) private var dismiss

    let editingTemplate: ShiftTemplate?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var weekPattern: [String?] = Array(repeating: nil, count: 7)

    private var isEditing: Bool { editingTemplate != nil }

    private var availableShifts: [String] {
        // Filtrar solo los turnos principales (sin "Libre" que se representa como nil)
        viewModel.shiftTypes.filter { $0 != "Libre" }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Información básica
                Section(header: Text("Información")) {
                    TextField("Nombre de la plantilla", text: $name)

                    TextField("Descripción (opcional)", text: $description)
                }

                // Patrón semanal
                Section(header: Text("Patrón semanal")) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        HStack {
                            Text(ShiftTemplate.dayNames[dayIndex])
                                .frame(width: 100, alignment: .leading)

                            Spacer()

                            Picker("", selection: Binding(
                                get: { weekPattern[dayIndex] ?? "" },
                                set: { weekPattern[dayIndex] = $0.isEmpty ? nil : $0 }
                            )) {
                                Text("Libre").tag("")
                                ForEach(availableShifts, id: \.self) { shift in
                                    HStack {
                                        Circle()
                                            .fill(getShiftColorForType(shift, customShiftTypes: viewModel.customShiftTypes))
                                            .frame(width: 10, height: 10)
                                        Text(shift)
                                    }
                                    .tag(shift)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                // Preview
                Section(header: Text("Vista previa")) {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        Text(name.isEmpty ? "Sin nombre" : name)
                            .font(.headline)

                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(colorForShift(weekPattern[dayIndex]))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text(ShiftTemplate.dayAbbreviations[dayIndex])
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )

                                    Text(abbreviateShift(weekPattern[dayIndex]))
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, DesignSpacing.sm)
                }

                // Acciones rápidas
                Section(header: Text("Acciones rápidas")) {
                    Button("Poner todos Libre") {
                        weekPattern = Array(repeating: nil, count: 7)
                        HapticManager.selection()
                    }

                    if let firstShift = availableShifts.first {
                        Button("Poner L-V como \(firstShift)") {
                            for i in 0..<5 {
                                weekPattern[i] = firstShift
                            }
                            weekPattern[5] = nil
                            weekPattern[6] = nil
                            HapticManager.selection()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Plantilla" : "Nueva Plantilla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveTemplate()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let template = editingTemplate {
                    name = template.name
                    description = template.description
                    weekPattern = template.weekPattern
                }
            }
        }
    }

    private func colorForShift(_ shiftName: String?) -> Color {
        guard let name = shiftName else { return DesignColors.shiftFree }
        return getShiftColorForType(name, customShiftTypes: viewModel.customShiftTypes)
    }

    private func abbreviateShift(_ shiftName: String?) -> String {
        guard let name = shiftName else { return "-" }
        // Abreviar a 3 caracteres
        return String(name.prefix(3))
    }

    private func saveTemplate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = editingTemplate {
            // Actualizar existente
            var updated = existing
            updated.name = trimmedName
            updated.description = description.trimmingCharacters(in: .whitespaces)
            updated.weekPattern = weekPattern
            templateManager.updateTemplate(updated)
        } else {
            // Crear nueva
            let newTemplate = ShiftTemplate(
                name: trimmedName,
                description: description.trimmingCharacters(in: .whitespaces),
                weekPattern: weekPattern
            )
            templateManager.addTemplate(newTemplate)
        }

        HapticManager.success()
        dismiss()
    }
}
