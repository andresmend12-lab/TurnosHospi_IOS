import SwiftUI

// MARK: - Editor de Turnos Personalizados

struct CustomShiftEditorView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    let editingShiftId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var shiftName = ""
    @State private var shiftDuration = "8.0"
    @State private var selectedColor = Color.green

    // Estados de validación
    @State private var nameError: String? = nil
    @State private var durationError: String? = nil

    let availableColors: [Color] = [
        Color(hex: "22C55E"), Color(hex: "F97316"),
        Color(hex: "38BDF8"), Color(hex: "F43F5E"),
        Color(hex: "FACC15"), Color(hex: "8B5CF6"),
        Color(hex: "14B8A6"), Color(hex: "A3E635")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información del turno")) {
                    // Campo nombre con validación
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Nombre del turno", text: $shiftName)
                            .onChange(of: shiftName) { _, _ in validateName() }

                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(DesignColors.error)
                        }
                    }

                    // Campo duración con validación
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Duración", text: $shiftDuration)
                                .keyboardType(.decimalPad)
                                .onChange(of: shiftDuration) { _, _ in validateDuration() }

                            Text("horas")
                                .foregroundColor(DesignColors.textSecondary)
                        }

                        if let error = durationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(DesignColors.error)
                        }
                    }

                    // Info adicional
                    Text("La duración debe ser entre 0.5 y 24 horas")
                        .font(.footnote)
                        .foregroundColor(DesignColors.textMuted)
                }

                Section(header: Text("Color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DesignSpacing.lg) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .shadow(color: selectedColor == color ? color.opacity(0.5) : .clear, radius: 4)
                                .onTapGesture {
                                    selectedColor = color
                                    HapticManager.selection()
                                }
                        }
                    }
                    .padding(.vertical, DesignSpacing.sm)
                }

                // Preview del turno
                Section(header: Text("Vista previa")) {
                    HStack {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading) {
                            Text(shiftName.isEmpty ? "Nombre del turno" : shiftName)
                                .fontWeight(.medium)
                            Text(formatDuration())
                                .font(.caption)
                                .foregroundColor(DesignColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, DesignSpacing.sm)
                }
            }
            .navigationTitle(editingShiftId == nil ? "Nuevo Turno" : "Editar Turno")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveShift()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    // MARK: - Validación

    private var isFormValid: Bool {
        return nameError == nil &&
               durationError == nil &&
               !shiftName.trimmingCharacters(in: .whitespaces).isEmpty &&
               parsedDuration != nil
    }

    private var parsedDuration: Double? {
        let cleaned = shiftDuration.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value >= 0.5, value <= 24 else {
            return nil
        }
        return value
    }

    private func validateName() {
        let trimmed = shiftName.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            nameError = nil // No mostrar error mientras escribe
            return
        }

        if trimmed.count < 2 {
            nameError = "El nombre debe tener al menos 2 caracteres"
            return
        }

        if trimmed.count > 20 {
            nameError = "El nombre no puede tener más de 20 caracteres"
            return
        }

        // Verificar duplicados
        let isDuplicate = viewModel.customShiftTypes.contains { shift in
            shift.name.lowercased() == trimmed.lowercased() && shift.id != editingShiftId
        }

        if isDuplicate {
            nameError = "Ya existe un turno con este nombre"
            return
        }

        // Verificar nombres reservados
        let reservedNames = ["mañana", "tarde", "noche", "saliente", "día", "libre", "vacaciones"]
        if reservedNames.contains(trimmed.lowercased()) {
            nameError = "Este nombre está reservado"
            return
        }

        nameError = nil
    }

    private func validateDuration() {
        let cleaned = shiftDuration.replacingOccurrences(of: ",", with: ".")

        if cleaned.isEmpty {
            durationError = nil
            return
        }

        guard let value = Double(cleaned) else {
            durationError = "Introduce un número válido"
            return
        }

        if value < 0.5 {
            durationError = "Mínimo 0.5 horas (30 minutos)"
            return
        }

        if value > 24 {
            durationError = "Máximo 24 horas"
            return
        }

        durationError = nil
    }

    private func formatDuration() -> String {
        guard let duration = parsedDuration else {
            return "-- horas"
        }

        if duration == floor(duration) {
            return "\(Int(duration)) horas"
        }
        return String(format: "%.1f horas", duration)
    }

    // MARK: - Carga y guardado

    private func loadExistingData() {
        if let id = editingShiftId,
           let shift = viewModel.customShiftTypes.first(where: { $0.id == id }) {
            shiftName = shift.name
            shiftDuration = String(format: "%.1f", shift.durationHours)
            selectedColor = shift.color
        }
    }

    private func saveShift() {
        guard let duration = parsedDuration else { return }

        let trimmedName = shiftName.trimmingCharacters(in: .whitespaces)
        let colorHex = selectedColor.toHex()

        if let id = editingShiftId {
            viewModel.updateCustomShift(id: id, name: trimmedName, colorHex: colorHex, durationHours: duration)
        } else {
            viewModel.addCustomShift(name: trimmedName, colorHex: colorHex, durationHours: duration)
        }

        dismiss()
    }
}
