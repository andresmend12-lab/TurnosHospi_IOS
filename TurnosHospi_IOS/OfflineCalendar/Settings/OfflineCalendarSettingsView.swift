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
                    Picker("Patrón", selection: Binding(
                        get: { viewModel.shiftPattern },
                        set: { newPattern in
                            handlePatternChange(to: newPattern)
                        }
                    )) {
                        ForEach(ShiftPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }
                    .pickerStyle(.inline)
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
                HStack {
                    Text(key)
                    Spacer()
                    TextField("Horas", value: Binding(
                        get: { viewModel.shiftDurations[key] ?? 0.0 },
                        set: { viewModel.shiftDurations[key] = $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                }
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
                    Button(action: {
                        editingShiftId = shift.id
                        showingCustomShiftEditor = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    Button(action: {
                        viewModel.deleteCustomShift(id: shift.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(DesignColors.error)
                    }
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
