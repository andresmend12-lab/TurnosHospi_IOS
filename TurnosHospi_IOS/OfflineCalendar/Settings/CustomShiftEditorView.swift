import SwiftUI

// MARK: - Editor de Turnos Personalizados

struct CustomShiftEditorView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    let editingShiftId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var shiftName = ""
    @State private var shiftDuration = "8.0"
    @State private var selectedColor = Color.green

    let availableColors: [Color] = [
        Color(hex: "22C55E"),
        Color(hex: "F97316"),
        Color(hex: "38BDF8"),
        Color(hex: "F43F5E"),
        Color(hex: "FACC15"),
        Color(hex: "8B5CF6"),
        Color(hex: "14B8A6"),
        Color(hex: "A3E635")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información del turno")) {
                    TextField("Nombre del turno", text: $shiftName)
                    TextField("Duración (horas)", text: $shiftDuration)
                        .keyboardType(.decimalPad)
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
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
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
                    .disabled(shiftName.isEmpty)
                }
            }
            .onAppear {
                if let id = editingShiftId,
                   let shift = viewModel.customShiftTypes.first(where: { $0.id == id }) {
                    shiftName = shift.name
                    shiftDuration = String(format: "%.1f", shift.durationHours)
                    selectedColor = shift.color
                }
            }
        }
    }

    func saveShift() {
        let duration = Double(shiftDuration.replacingOccurrences(of: ",", with: ".")) ?? 8.0
        let colorHex = selectedColor.toHex()

        if let id = editingShiftId {
            viewModel.updateCustomShift(id: id, name: shiftName, colorHex: colorHex, durationHours: duration)
        } else {
            viewModel.addCustomShift(name: shiftName, colorHex: colorHex, durationHours: duration)
        }

        dismiss()
    }
}
