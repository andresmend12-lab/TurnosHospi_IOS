import SwiftUI
import Combine

// MARK: - ViewModel del Calendario Offline

class OfflineCalendarViewModel: ObservableObject {

    // MARK: - Datos principales
    @Published var localShifts: [String: UserShift] = [:]
    @Published var localNotes: [String: [String]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var shiftTypes: [String] = []

    // MARK: - Configuración de turnos
    @Published var shiftPattern: ShiftPattern = .three {
        didSet { applyShiftSettingsChange() }
    }
    @Published var allowHalfDay: Bool = false {
        didSet { applyShiftSettingsChange() }
    }
    @Published var customShiftTypes: [CustomShiftType] = [] {
        didSet { applyShiftSettingsChange() }
    }
    @Published var shiftDurations: [String: Double] = [:] {
        didSet { saveShiftDurations() }
    }

    // MARK: - Estados de UI
    @Published var isAssignmentMode: Bool = false
    @Published var selectedShiftToApply: String = "Mañana"
    @Published var selectedTab: Int = 0  // 0 = Calendario, 1 = Estadísticas

    // MARK: - Gestión de notas
    @Published var isAddingNote: Bool = false
    @Published var newNoteText: String = ""
    @Published var editingNoteIndex: Int? = nil
    @Published var editingNoteText: String = ""

    // MARK: - Persistencia
    private let userDefaults = UserDefaults.standard
    private let shiftsKey = "shifts_map"
    private let notesKey = "notes_map"
    private let shiftSettingsKey = "shift_settings_map"
    private let customShiftsKey = "custom_shift_types"
    private let shiftDurationsKey = "shift_durations_map"

    // MARK: - Inicialización

    init() {
        loadShiftSettings()
        loadCustomShiftTypes()
        loadShiftDurations()
        loadStoredCalendarData()
        applyShiftSettingsChange(save: false)
    }

    // MARK: - Carga de datos

    func loadData() {
        loadStoredCalendarData()
    }

    private func loadStoredCalendarData() {
        if let shiftsData = userDefaults.data(forKey: shiftsKey),
           let decodedShifts = try? JSONDecoder().decode([String: UserShift].self, from: shiftsData) {
            localShifts = decodedShifts
        }

        if let notesData = userDefaults.data(forKey: notesKey),
           let decodedNotes = try? JSONDecoder().decode([String: [String]].self, from: notesData) {
            localNotes = decodedNotes
        }
    }

    // MARK: - Guardado de datos

    func saveData() {
        if let encodedShifts = try? JSONEncoder().encode(localShifts) {
            userDefaults.set(encodedShifts, forKey: shiftsKey)
        }
        if let encodedNotes = try? JSONEncoder().encode(localNotes) {
            userDefaults.set(encodedNotes, forKey: notesKey)
        }
    }

    // MARK: - Utilidades de fecha

    func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Manejo de interacciones

    func handleDayClick(date: Date) {
        if isAssignmentMode {
            assignShiftToDate(date)
        } else {
            selectDate(date)
        }
    }

    private func assignShiftToDate(_ date: Date) {
        let key = dateKey(for: date)

        if selectedShiftToApply == "Libre" {
            localShifts.removeValue(forKey: key)
        } else {
            let isHalf = selectedShiftToApply.lowercased().contains("media") ||
                         selectedShiftToApply.lowercased().contains("medio") ||
                         selectedShiftToApply.lowercased().contains("m.")

            var cleanName = selectedShiftToApply
            if cleanName.contains("M.") {
                cleanName = cleanName.replacingOccurrences(of: "M.", with: "Media")
            }

            localShifts[key] = UserShift(shiftName: cleanName, isHalfDay: isHalf)
        }

        saveData()
    }

    private func selectDate(_ date: Date) {
        selectedDate = date
        isAddingNote = false
        editingNoteIndex = nil
    }

    // MARK: - Gestión de notas

    func addNote() {
        guard !newNoteText.isEmpty else { return }
        let key = dateKey(for: selectedDate)
        var notes = localNotes[key] ?? []
        notes.append(newNoteText)
        localNotes[key] = notes
        saveData()
        newNoteText = ""
        isAddingNote = false
    }

    func updateNote(at index: Int) {
        guard !editingNoteText.isEmpty else { return }
        let key = dateKey(for: selectedDate)
        var notes = localNotes[key] ?? []
        if index < notes.count {
            notes[index] = editingNoteText
            localNotes[key] = notes
            saveData()
        }
        editingNoteIndex = nil
    }

    func deleteNote(at index: Int) {
        let key = dateKey(for: selectedDate)
        var notes = localNotes[key] ?? []
        if index < notes.count {
            notes.remove(at: index)
            localNotes[key] = notes
            saveData()
        }
    }

    func startEditingNote(at index: Int, currentText: String) {
        editingNoteIndex = index
        editingNoteText = currentText
        isAddingNote = false
    }

    func cancelEditingNote() {
        editingNoteIndex = nil
        editingNoteText = ""
    }

    // MARK: - Navegación de mes

    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }

    // MARK: - Leyenda

    var legendItems: [String] {
        shiftTypes
    }

    // MARK: - Configuración de turnos

    private func loadShiftSettings() {
        if let settingsData = userDefaults.data(forKey: shiftSettingsKey),
           let decodedSettings = try? JSONDecoder().decode(OfflineShiftSettings.self, from: settingsData) {
            shiftPattern = decodedSettings.pattern
            allowHalfDay = decodedSettings.allowHalfDay
        }
    }

    private func saveShiftSettings() {
        let settings = OfflineShiftSettings(pattern: shiftPattern, allowHalfDay: allowHalfDay)
        if let encodedSettings = try? JSONEncoder().encode(settings) {
            userDefaults.set(encodedSettings, forKey: shiftSettingsKey)
        }
    }

    private func loadCustomShiftTypes() {
        if let data = userDefaults.data(forKey: customShiftsKey),
           let decoded = try? JSONDecoder().decode([CustomShiftType].self, from: data) {
            customShiftTypes = decoded.map { shift in
                if shift.durationHours <= 0.0 {
                    return CustomShiftType(
                        id: shift.id,
                        name: shift.name,
                        colorHex: shift.colorHex,
                        durationHours: 8.0
                    )
                }
                return shift
            }
        }
    }

    private func saveCustomShiftTypes() {
        if let encoded = try? JSONEncoder().encode(customShiftTypes) {
            userDefaults.set(encoded, forKey: customShiftsKey)
        }
    }

    private func loadShiftDurations() {
        if let data = userDefaults.data(forKey: shiftDurationsKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            shiftDurations = decoded
        }
        shiftDurations = withDefaultShiftDurations(shiftDurations, pattern: shiftPattern)
    }

    private func saveShiftDurations() {
        if let encoded = try? JSONEncoder().encode(shiftDurations) {
            userDefaults.set(encoded, forKey: shiftDurationsKey)
        }
    }

    // MARK: - Gestión de turnos personalizados

    func addCustomShift(name: String, colorHex: String, durationHours: Double) {
        let newShift = CustomShiftType(name: name, colorHex: colorHex, durationHours: durationHours)
        customShiftTypes.append(newShift)
        saveCustomShiftTypes()
    }

    func updateCustomShift(id: UUID, name: String, colorHex: String, durationHours: Double) {
        if let index = customShiftTypes.firstIndex(where: { $0.id == id }) {
            customShiftTypes[index] = CustomShiftType(
                id: id,
                name: name,
                colorHex: colorHex,
                durationHours: durationHours
            )
            saveCustomShiftTypes()
        }
    }

    func deleteCustomShift(id: UUID) {
        customShiftTypes.removeAll { $0.id == id }
        saveCustomShiftTypes()
    }

    // MARK: - Aplicación de configuración

    private func applyShiftSettingsChange(save: Bool = true) {
        var types: [String] = []

        switch shiftPattern {
        case .three:
            types.append(contentsOf: ["Mañana", "Tarde", "Noche", "Saliente"])
            if allowHalfDay {
                types.append(contentsOf: ["M. Mañana", "M. Tarde"])
            }
        case .two:
            types.append(contentsOf: ["Día", "Noche", "Saliente"])
            if allowHalfDay {
                types.append("Medio Día")
            }
        case .custom:
            types.append(contentsOf: customShiftTypes.map { $0.name })
        }

        types.append(contentsOf: ["Vacaciones", "Libre"])
        shiftTypes = types

        if !shiftTypes.contains(selectedShiftToApply) {
            selectedShiftToApply = shiftTypes.first ?? "Libre"
        }

        shiftDurations = withDefaultShiftDurations(shiftDurations, pattern: shiftPattern)

        if save {
            saveShiftSettings()
        }
    }

    // MARK: - Estadísticas

    func calculateStats(for month: Date) -> OfflineMonthlyStats {
        return calculateOfflineStatsForMonth(
            month: month,
            shifts: localShifts,
            customShiftTypes: customShiftTypes,
            shiftDurations: shiftDurations
        )
    }
}
