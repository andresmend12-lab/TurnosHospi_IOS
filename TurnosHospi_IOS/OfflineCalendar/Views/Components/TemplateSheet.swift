import SwiftUI

// MARK: - Sheet de Plantillas

struct TemplateSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @ObservedObject private var templateManager = TemplateManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShiftTemplate? = nil
    @State private var startDate = Date()
    @State private var repetitions = 4  // Número de veces que se repite el patrón
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

            // Info de la plantilla
            if let template = selectedTemplate {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(DesignColors.accent)
                    Text("Duración del patrón: \(template.durationDays) días")
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textSecondary)
                }
            }

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

            // Repeticiones del patrón
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text("Repetir el patrón")
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(DesignColors.textSecondary)

                Stepper("\(repetitions) veces", value: $repetitions, in: 1...52)
                    .tint(DesignColors.accent)
            }

            // Resumen
            if let template = selectedTemplate {
                let totalDays = template.durationDays * repetitions
                let endDate = Calendar.current.date(
                    byAdding: .day,
                    value: totalDays - 1,
                    to: startDate
                )!

                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text("Se aplicará:")
                        .font(DesignFonts.captionBold)
                        .foregroundColor(DesignColors.textSecondary)

                    Text("• Patrón de \(template.durationDays) días × \(repetitions) = \(totalDays) días")
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textTertiary)

                    Text("• Desde \(formatDate(startDate)) hasta \(formatDate(endDate))")
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textTertiary)
                }
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

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func applyTemplate() {
        guard let template = selectedTemplate else { return }

        HapticManager.impact()

        let calendar = Calendar.current
        let patternLength = template.durationDays
        let totalDays = patternLength * repetitions

        print("🔄 Aplicando plantilla '\(template.name)':")
        print("   - Patrón de \(patternLength) días")
        print("   - Repeticiones: \(repetitions)")
        print("   - Total días: \(totalDays)")
        print("   - Fecha inicio: \(startDate)")

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                print("   ⚠️ Error calculando fecha para offset \(dayOffset)")
                continue
            }

            let patternIndex = dayOffset % patternLength
            let shiftName = template.pattern[patternIndex]

            let key = viewModel.dateKey(for: date)

            if let shiftName = shiftName {
                viewModel.localShifts[key] = UserShift(
                    shiftName: shiftName,
                    isHalfDay: false
                )
                print("   ✓ Día \(dayOffset + 1): \(key) = \(shiftName)")
            } else {
                viewModel.localShifts.removeValue(forKey: key)
                print("   ✓ Día \(dayOffset + 1): \(key) = Libre")
            }
        }

        viewModel.saveData()
        print("✅ Plantilla aplicada correctamente")

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

                            HStack(spacing: DesignSpacing.xs) {
                                if !template.description.isEmpty {
                                    Text(template.description)
                                        .font(DesignFonts.caption)
                                        .foregroundColor(DesignColors.textTertiary)
                                }

                                Text("(\(template.durationDays) días)")
                                    .font(DesignFonts.caption)
                                    .foregroundColor(DesignColors.accent)
                            }
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignColors.accent)
                        }
                    }

                    // Preview del patrón (mostrar máximo 14 días, con scroll si hay más)
                    patternPreview
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

    @ViewBuilder
    private var patternPreview: some View {
        let displayDays = min(template.durationDays, 14)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(0..<template.durationDays, id: \.self) { dayIndex in
                    let shiftName = template.pattern[dayIndex]

                    VStack(spacing: 2) {
                        Circle()
                            .fill(colorForShift(shiftName))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(ShiftTemplate.dayAbbreviation(for: dayIndex))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        if dayIndex % 7 == 0 && dayIndex > 0 {
                            Rectangle()
                                .fill(DesignColors.accent.opacity(0.5))
                                .frame(width: 22, height: 2)
                        }
                    }
                }

                if template.durationDays > 14 {
                    Text("+\(template.durationDays - 14)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignColors.textTertiary)
                }
            }
        }
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
    @State private var pattern: [String?] = Array(repeating: nil, count: 7)

    private var isEditing: Bool { editingTemplate != nil }

    private var availableShifts: [String] {
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

                // Duración del patrón
                Section(header: Text("Duración del patrón")) {
                    Stepper("\(pattern.count) días", value: Binding(
                        get: { pattern.count },
                        set: { newValue in
                            let clampedValue = max(1, min(56, newValue))  // 1-56 días (8 semanas max)
                            if clampedValue > pattern.count {
                                pattern.append(contentsOf: Array(repeating: nil, count: clampedValue - pattern.count))
                            } else if clampedValue < pattern.count {
                                pattern = Array(pattern.prefix(clampedValue))
                            }
                        }
                    ), in: 1...56)

                    // Botones rápidos de duración
                    HStack(spacing: DesignSpacing.sm) {
                        ForEach([7, 14, 21, 28], id: \.self) { days in
                            Button("\(days)d") {
                                setDuration(days)
                                HapticManager.selection()
                            }
                            .buttonStyle(.bordered)
                            .tint(pattern.count == days ? DesignColors.accent : .secondary)
                        }
                    }
                }

                // Patrón de turnos
                Section(header: Text("Patrón de turnos (\(pattern.count) días)")) {
                    ForEach(0..<pattern.count, id: \.self) { dayIndex in
                        HStack {
                            // Indicador de semana
                            if dayIndex % 7 == 0 {
                                Text("S\(dayIndex / 7 + 1)")
                                    .font(.caption)
                                    .foregroundColor(DesignColors.accent)
                                    .frame(width: 25)
                            } else {
                                Color.clear.frame(width: 25)
                            }

                            Text(ShiftTemplate.dayName(for: dayIndex))
                                .frame(width: 90, alignment: .leading)

                            Spacer()

                            Picker("", selection: Binding(
                                get: { pattern[dayIndex] ?? "" },
                                set: { pattern[dayIndex] = $0.isEmpty ? nil : $0 }
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

                        Text("\(pattern.count) días de duración")
                            .font(.caption)
                            .foregroundColor(DesignColors.accent)

                        // Mostrar por semanas
                        let weeksCount = (pattern.count + 6) / 7
                        ForEach(0..<weeksCount, id: \.self) { weekIndex in
                            VStack(alignment: .leading, spacing: 2) {
                                if weeksCount > 1 {
                                    Text("Semana \(weekIndex + 1)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 6) {
                                    ForEach(0..<7, id: \.self) { dayInWeek in
                                        let dayIndex = weekIndex * 7 + dayInWeek
                                        if dayIndex < pattern.count {
                                            VStack(spacing: 2) {
                                                Circle()
                                                    .fill(colorForShift(pattern[dayIndex]))
                                                    .frame(width: 28, height: 28)
                                                    .overlay(
                                                        Text(ShiftTemplate.dayAbbreviation(for: dayIndex))
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )

                                                Text(abbreviateShift(pattern[dayIndex]))
                                                    .font(.system(size: 7))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, DesignSpacing.sm)
                }

                // Acciones rápidas
                Section(header: Text("Acciones rápidas")) {
                    Button("Poner todos Libre") {
                        pattern = Array(repeating: nil, count: pattern.count)
                        HapticManager.selection()
                    }

                    if let firstShift = availableShifts.first {
                        Button("Poner L-V como \(firstShift)") {
                            for i in 0..<pattern.count {
                                let dayInWeek = i % 7
                                if dayInWeek < 5 {  // Lunes a Viernes
                                    pattern[i] = firstShift
                                } else {
                                    pattern[i] = nil
                                }
                            }
                            HapticManager.selection()
                        }
                    }

                    Button("Copiar primera semana al resto") {
                        guard pattern.count > 7 else { return }
                        let firstWeek = Array(pattern.prefix(7))
                        for i in 7..<pattern.count {
                            pattern[i] = firstWeek[i % 7]
                        }
                        HapticManager.selection()
                    }
                    .disabled(pattern.count <= 7)
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
                    pattern = template.pattern
                }
            }
        }
    }

    private func setDuration(_ days: Int) {
        if days > pattern.count {
            pattern.append(contentsOf: Array(repeating: nil, count: days - pattern.count))
        } else if days < pattern.count {
            pattern = Array(pattern.prefix(days))
        }
    }

    private func colorForShift(_ shiftName: String?) -> Color {
        guard let name = shiftName else { return DesignColors.shiftFree }
        return getShiftColorForType(name, customShiftTypes: viewModel.customShiftTypes)
    }

    private func abbreviateShift(_ shiftName: String?) -> String {
        guard let name = shiftName else { return "-" }
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
            updated.pattern = pattern
            templateManager.updateTemplate(updated)
        } else {
            // Crear nueva
            let newTemplate = ShiftTemplate(
                name: trimmedName,
                description: description.trimmingCharacters(in: .whitespaces),
                pattern: pattern
            )
            templateManager.addTemplate(newTemplate)
        }

        HapticManager.success()
        dismiss()
    }
}
