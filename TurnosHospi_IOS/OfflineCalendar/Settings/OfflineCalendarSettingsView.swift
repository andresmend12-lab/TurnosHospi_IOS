import SwiftUI

// MARK: - Vista de Configuración del Calendario Offline

struct OfflineCalendarSettingsView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomShiftEditor = false
    @State private var editingShiftId: UUID? = nil
    @State private var pendingPatternChange: ShiftPattern? = nil
    @State private var migrationAnalysis: OfflineCalendarViewModel.ShiftMigrationAnalysis? = nil
    @State private var showMigrationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tipo de Turnos")) {
                    ForEach(ShiftPattern.allCases) { pattern in
                        Button {
                            handlePatternChange(to: pattern)
                        } label: {
                            HStack {
                                Text(pattern.title)
                                    .foregroundColor(DesignColors.textPrimary)
                                Spacer()
                                if viewModel.shiftPattern == pattern {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignColors.accent)
                                }
                            }
                        }
                    }
                }

                if viewModel.shiftPattern != .custom {
                    halfDaySection
                    durationSection
                } else {
                    customShiftsSection
                }
            }
            .navigationTitle("Configuración")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCustomShiftEditor) {
                CustomShiftEditorView(viewModel: viewModel, editingShiftId: editingShiftId)
            }
            .sheet(isPresented: $showMigrationAlert) {
                if let analysis = migrationAnalysis, let pending = pendingPatternChange {
                    ShiftMigrationAlert(
                        analysis: analysis,
                        onDelete: {
                            viewModel.shiftPattern = pending
                            viewModel.removeOrphanedShifts()
                            showMigrationAlert = false
                            pendingPatternChange = nil
                            HapticManager.success()
                        },
                        onCancel: {
                            showMigrationAlert = false
                            pendingPatternChange = nil
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }

    // MARK: - Pattern Change Handler

    private func handlePatternChange(to newPattern: ShiftPattern) {
        let analysis = viewModel.analyzePatternChange(to: newPattern)

        if analysis.canAutoMigrate {
            viewModel.shiftPattern = newPattern
            HapticManager.success()
        } else {
            pendingPatternChange = newPattern
            migrationAnalysis = analysis
            showMigrationAlert = true
        }
    }

    // MARK: - Sections

    private var halfDaySection: some View {
        Section(header: Text("Opciones")) {
            Toggle("Permitir medias jornadas", isOn: $viewModel.allowHalfDay)
            Text("Al activarlo podrás asignar media jornada según corresponda.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var durationSection: some View {
        Section(header: Text("Duración de turnos (horas)")) {
            let durationKeys = getDurationKeys()
            ForEach(durationKeys, id: \.self) { key in
                DurationTextField(
                    label: key,
                    value: Binding(
                        get: { viewModel.shiftDurations[key] ?? 8.0 },
                        set: { viewModel.shiftDurations[key] = $0 }
                    )
                )
            }
            Text("Las medias jornadas usan el 50% de la duración base.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var customShiftsSection: some View {
        Section(header: Text("Turnos Personalizados")) {
            Button(action: {
                editingShiftId = nil
                showingCustomShiftEditor = true
            }) {
                Label("Agregar turno", systemImage: "plus")
            }

            ForEach(viewModel.customShiftTypes) { shift in
                HStack {
                    Circle()
                        .fill(shift.color)
                        .frame(width: DesignSpacing.md, height: DesignSpacing.md)
                    Text(shift.name)
                    Spacer()
                    Text("\(String(format: "%.1f", shift.durationHours))h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        editingShiftId = shift.id
                        showingCustomShiftEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(DesignColors.accent)
                            .padding(DesignSpacing.xs)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        viewModel.deleteCustomShift(id: shift.id)
                        HapticManager.warning()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DesignColors.error)
                            .padding(DesignSpacing.xs)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Helpers

    func getDurationKeys() -> [String] {
        switch viewModel.shiftPattern {
        case .three:
            return ["Mañana", "Tarde", "Noche", "Saliente"]
        case .two:
            return ["Día", "Noche", "Saliente"]
        case .custom:
            return []
        }
    }
}

// MARK: - TextField de Duración Mejorado

/// TextField que permite borrar completamente el campo y escribir un nuevo valor
struct DurationTextField: View {
    let label: String
    @Binding var value: Double

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    // Filtrar solo números y punto decimal
                    let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                    // Reemplazar coma por punto
                    let normalized = filtered.replacingOccurrences(of: ",", with: ".")
                    // Evitar múltiples puntos
                    let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
                    if parts.count > 2 {
                        text = String(parts[0]) + "." + String(parts[1])
                    } else if filtered != newValue {
                        text = normalized
                    }
                }
                .onChange(of: isFocused) { focused in
                    if !focused {
                        // Al perder el foco, guardar el valor
                        saveValue()
                    }
                }
                .onSubmit {
                    saveValue()
                }
            Text("h")
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Inicializar texto desde el valor
            text = formatValue(value)
        }
        .onChange(of: value) { newValue in
            // Sincronizar si el valor externo cambia
            if !isFocused {
                text = formatValue(newValue)
            }
        }
    }

    private func formatValue(_ val: Double) -> String {
        if val == floor(val) {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.1f", val)
        }
    }

    private func saveValue() {
        if text.isEmpty {
            // Si está vacío, usar valor por defecto
            value = 8.0
            text = "8"
        } else if let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) {
            // Limitar entre 0.5 y 24 horas
            let clamped = max(0.5, min(24.0, parsed))
            value = clamped
            text = formatValue(clamped)
        } else {
            // Si no se puede parsear, restaurar el valor anterior
            text = formatValue(value)
        }
        HapticManager.selection()
    }
}
