import SwiftUI

// MARK: - Modelos de Datos

struct UserShift: Codable, Equatable {
    let shiftName: String
    let isHalfDay: Bool
}

enum ShiftPattern: String, Codable, CaseIterable, Identifiable {
    case three = "THREE_SHIFTS"    // Mañana, Tarde, Noche
    case two = "TWO_SHIFTS"        // Día (12h), Noche (12h)
    case custom = "CUSTOM_SHIFTS"  // Turnos personalizados

    var id: String { rawValue }

    var title: String {
        switch self {
        case .three: return "3 Turnos (M/T/N)"
        case .two: return "2 Turnos (Día 12h / Noche 12h)"
        case .custom: return "Turnos personalizados"
        }
    }
}

struct CustomShiftType: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let colorHex: String  // Color en formato hex
    let durationHours: Double

    init(id: UUID = UUID(), name: String, colorHex: String, durationHours: Double = 8.0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.durationHours = durationHours
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

struct OfflineShiftSettings: Codable {
    var pattern: ShiftPattern
    var allowHalfDay: Bool
}

struct OfflineMonthlyStats {
    var totalHours: Double
    var totalShifts: Int
    var breakdown: [String: ShiftStatData]
}

struct ShiftStatData {
    var hours: Double = 0.0
    var count: Int = 0
}

// MARK: - ViewModel

class OfflineCalendarViewModel: ObservableObject {
    @Published var localShifts: [String: UserShift] = [:]
    @Published var localNotes: [String: [String]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var shiftTypes: [String] = []

    // Configuración avanzada
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

    // Estados de UI
    @Published var isAssignmentMode: Bool = false
    @Published var selectedShiftToApply: String = "Mañana"
    @Published var selectedTab: Int = 0  // 0 = Calendario, 1 = Estadísticas

    // Gestión de notas
    @Published var isAddingNote: Bool = false
    @Published var newNoteText: String = ""
    @Published var editingNoteIndex: Int? = nil
    @Published var editingNoteText: String = ""

    private let userDefaults = UserDefaults.standard
    private let shiftsKey = "shifts_map"
    private let notesKey = "notes_map"
    private let shiftSettingsKey = "shift_settings_map"
    private let customShiftsKey = "custom_shift_types"
    private let shiftDurationsKey = "shift_durations_map"

    init() {
        loadShiftSettings()
        loadCustomShiftTypes()
        loadShiftDurations()
        loadStoredCalendarData()
        applyShiftSettingsChange(save: false)
    }

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

    func saveData() {
        if let encodedShifts = try? JSONEncoder().encode(localShifts) {
            userDefaults.set(encodedShifts, forKey: shiftsKey)
        }
        if let encodedNotes = try? JSONEncoder().encode(localNotes) {
            userDefaults.set(encodedNotes, forKey: notesKey)
        }
    }

    func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func handleDayClick(date: Date) {
        if isAssignmentMode {
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
        } else {
            selectedDate = date
            isAddingNote = false
            editingNoteIndex = nil
        }
    }

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

    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }

    var legendItems: [String] {
        shiftTypes
    }

    // MARK: - Configuración de Turnos

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
                    return CustomShiftType(id: shift.id, name: shift.name, colorHex: shift.colorHex, durationHours: 8.0)
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

    func addCustomShift(name: String, colorHex: String, durationHours: Double) {
        let newShift = CustomShiftType(name: name, colorHex: colorHex, durationHours: durationHours)
        customShiftTypes.append(newShift)
        saveCustomShiftTypes()
    }

    func updateCustomShift(id: UUID, name: String, colorHex: String, durationHours: Double) {
        if let index = customShiftTypes.firstIndex(where: { $0.id == id }) {
            customShiftTypes[index] = CustomShiftType(id: id, name: name, colorHex: colorHex, durationHours: durationHours)
            saveCustomShiftTypes()
        }
    }

    func deleteCustomShift(id: UUID) {
        customShiftTypes.removeAll { $0.id == id }
        saveCustomShiftTypes()
    }

    private func applyShiftSettingsChange(save: Bool = true) {
        var types: [String] = []

        switch shiftPattern {
        case .three:
            types.append("Mañana")
            types.append("Tarde")
            types.append("Noche")
            types.append("Saliente")
            if allowHalfDay {
                types.append("M. Mañana")
                types.append("M. Tarde")
            }
        case .two:
            types.append("Día")
            types.append("Noche")
            types.append("Saliente")
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
        return calculateOfflineStatsForMonth(month: month, shifts: localShifts, customShiftTypes: customShiftTypes, shiftDurations: shiftDurations)
    }
}

// MARK: - Vista Principal

struct OfflineCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Binding var showSettings: Bool
    @State private var showConfigDialog = false

    init(showSettings: Binding<Bool> = .constant(false)) {
        _showSettings = showSettings
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F172A").edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // TABS
                    Picker("Vista", selection: $viewModel.selectedTab) {
                        Text("Calendario").tag(0)
                        Text("Estadísticas").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color(hex: "0F172A"))

                    if viewModel.selectedTab == 0 {
                        // TAB CALENDARIO
                        calendarTabView
                    } else {
                        // TAB ESTADÍSTICAS
                        StatisticsTabView(viewModel: viewModel)
                    }
                }
            }
            .navigationBarTitle("Mi Planilla", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.loadData()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConfigDialog) {
            OfflineCalendarSettingsView(viewModel: viewModel)
        }
    }

    var calendarTabView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // --- CALENDARIO + AJUSTES ---
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        CalendarGridView(viewModel: viewModel)
                            .padding(.horizontal)

                        if !viewModel.isAssignmentMode {
                            LegendView(items: viewModel.legendItems, viewModel: viewModel)
                                .padding(.vertical, 6)
                        }
                    }

                    if !viewModel.isAssignmentMode {
                        Button(action: { showConfigDialog = true }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.black)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 24)
                        .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                // --- PANEL INFERIOR ---
                Group {
                    if viewModel.isAssignmentMode {
                        AssignmentControlPanel(viewModel: viewModel)
                    } else {
                        NotesControlPanel(viewModel: viewModel)
                    }
                }
                .background(Color(hex: "1E293B"))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: -4)
            }

            // Botón Flotante (FAB) - Solo visible cuando NO está en modo asignación
            if !viewModel.isAssignmentMode {
                Button(action: {
                    viewModel.isAssignmentMode = true
                }) {
                    Image(systemName: "pencil")
                        .font(.title2)
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color(hex: "54C7EC"))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 220)
            }
        }
    }
}

// MARK: - LEYENDA

struct LegendView: View {
    let items: [String]
    @ObservedObject var viewModel: OfflineCalendarViewModel

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForShiftName(item))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                    Text(item)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    func colorForShiftName(_ name: String) -> Color {
        return getShiftColorForType(name, customShiftTypes: viewModel.customShiftTypes)
    }
}

// MARK: - TAB DE ESTADÍSTICAS

struct StatisticsTabView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @State private var currentMonth = Date()

    var stats: OfflineMonthlyStats {
        viewModel.calculateStats(for: currentMonth)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Selector de mes
                HStack {
                    Button(action: {
                        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                            currentMonth = newDate
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(monthTitle(from: currentMonth))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .textCase(.uppercase)

                    Spacer()

                    Button(action: {
                        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
                            currentMonth = newDate
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color(hex: "1E293B"))
                .cornerRadius(12)

                if stats.totalShifts == 0 || stats.totalHours == 0.0 {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Sin estadísticas para este mes")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                } else {
                    // Card principal con total de horas
                    VStack(spacing: 8) {
                        Text("Horas trabajadas")
                            .font(.caption)
                            .foregroundColor(Color(hex: "54C7EC"))

                        Text(String(format: "%.1f h", stats.totalHours))
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(stats.totalShifts) turnos")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(hex: "0F172A"))
                    .cornerRadius(16)

                    // Detalle por turno
                    if !stats.breakdown.isEmpty {
                        Text("Detalle por turno")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(stats.breakdown.sorted(by: { $0.value.hours > $1.value.hours }), id: \.key) { shiftName, data in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(shiftName)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                    Text("\(data.count) turnos")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Text(String(format: "%.1f h", data.hours))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "54C7EC"))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(hex: "0F172A"))
    }

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Subvistas Calendario

struct CalendarGridView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    let daysOfWeek = ["L", "M", "X", "J", "V", "S", "D"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack {
            // Cabecera Mes
            HStack {
                Button(action: { viewModel.changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left").foregroundColor(.white)
                }
                Spacer()
                Text(monthTitle(from: viewModel.currentMonth))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { viewModel.changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right").foregroundColor(.white)
                }
            }
            .padding(.bottom, 16)

            // Días Semana
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                        .fontWeight(.bold)
                }
            }
            .padding(.bottom, 8)

            // Grid Días
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, viewModel: viewModel)
                    } else {
                        Text("").frame(height: 40)
                    }
                }
            }
        }
    }

    func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func daysInMonth() -> [Date?] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2 // Lunes como primer día de la semana

        guard let range = calendar.range(of: .day, in: .month, for: viewModel.currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.currentMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // weekday: 1=Domingo, 2=Lunes, 3=Martes, 4=Miércoles, 5=Jueves, 6=Viernes, 7=Sábado
        // Queremos: Lunes=0, Martes=1, Miércoles=2, Jueves=3, Viernes=4, Sábado=5, Domingo=6
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
}

struct DayCell: View {
    let date: Date
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let dateKey = viewModel.dateKey(for: date)
        let shift = viewModel.localShifts[dateKey]
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let hasNotes = !(viewModel.localNotes[dateKey]?.isEmpty ?? true)

        let bgColor = getBackgroundColor(shift: shift, date: date)

        return ZStack(alignment: .top) {
            Text("\(Calendar.current.component(.day, from: date))")
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(bgColor))
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )

            if hasNotes {
                Circle()
                    .fill(Color(hex: "E91E63"))
                    .frame(width: 8, height: 8)
                    .offset(y: 2)
            }
        }
        .onTapGesture {
            viewModel.handleDayClick(date: date)
        }
    }

    func getBackgroundColor(shift: UserShift?, date: Date) -> Color {
        if let shift = shift {
            return getShiftColorForType(shift.shiftName, customShiftTypes: viewModel.customShiftTypes)
        } else {
            // Detectar "Saliente"
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
               let prevShift = viewModel.localShifts[viewModel.dateKey(for: yesterday)],
               normalizeShiftType(prevShift.shiftName) == "Noche" {
                return themeManager.salienteColor
            }
            return Color.clear
        }
    }
}

// MARK: - Paneles de Control

struct AssignmentControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Modo Asignación")
                .font(.headline)
                .foregroundColor(Color(hex: "54C7EC"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.shiftTypes, id: \.self) { (typeName: String) in
                        let isSelected = viewModel.selectedShiftToApply == typeName
                        let chipColor = getShiftColorForType(typeName, customShiftTypes: viewModel.customShiftTypes)

                        Button(action: { viewModel.selectedShiftToApply = typeName }) {
                            Text(typeName)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? chipColor : getButtonColor(for: typeName).opacity(0.6))
                                .foregroundColor(isSelected ? (chipColor.luminance < 0.45 ? .white : .black) : .white)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(hex: "54C7EC"), lineWidth: isSelected ? 0 : 1)
                                )
                        }
                    }
                }
            }

            Button(action: { viewModel.isAssignmentMode = false }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Guardar y Salir")
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
        }
        .padding(16)
    }

    private func getButtonColor(for typeName: String) -> Color {
        return getShiftColorForType(typeName, customShiftTypes: viewModel.customShiftTypes)
    }
}

struct NotesControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabecera Día
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    let key = viewModel.dateKey(for: viewModel.selectedDate)
                    Text(viewModel.localShifts[key]?.shiftName ?? "Libre")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            Divider().background(Color.gray)

            // Sección Notas
            HStack {
                Text("Anotaciones")
                    .font(.headline)
                    .foregroundColor(Color(hex: "54C7EC"))
                Spacer()
                if !viewModel.isAddingNote && viewModel.editingNoteIndex == nil {
                    Button(action: {
                        viewModel.isAddingNote = true
                        viewModel.newNoteText = ""
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    let key = viewModel.dateKey(for: viewModel.selectedDate)
                    let notes = viewModel.localNotes[key] ?? []

                    if notes.isEmpty && !viewModel.isAddingNote {
                        Text("No hay notas. Pulsa + para crear una.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        if viewModel.editingNoteIndex == index {
                            HStack {
                                NoteTextField(text: $viewModel.editingNoteText, placeholder: "Editar nota")

                                Button(action: { viewModel.updateNote(at: index) }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                                Button(action: { viewModel.editingNoteIndex = nil }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                }
                            }
                        } else {
                            HStack {
                                Text(note)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(hex: "334155"))
                                    .cornerRadius(8)
                                Spacer()
                                Button(action: {
                                    viewModel.editingNoteIndex = index
                                    viewModel.editingNoteText = note
                                    viewModel.isAddingNote = false
                                }) {
                                    Image(systemName: "pencil").foregroundColor(Color(hex: "54C7EC"))
                                }
                                Button(action: { viewModel.deleteNote(at: index) }) {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 120)

            if viewModel.isAddingNote {
                HStack {
                    NoteTextField(text: $viewModel.newNoteText, placeholder: "Escribe aquí...")
                    Button(action: { viewModel.addNote() }) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    }
                    Button(action: { viewModel.isAddingNote = false }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(minHeight: 200, alignment: .top)
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date).capitalized
    }
}

private struct NoteTextField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .foregroundColor(.black)
    }
}

// MARK: - Configuración Avanzada

struct OfflineCalendarSettingsView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomShiftEditor = false
    @State private var editingShiftId: UUID? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tipo de Turnos")) {
                    Picker("Patrón", selection: $viewModel.shiftPattern) {
                        ForEach(ShiftPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if viewModel.shiftPattern != .custom {
                    Section(header: Text("Opciones")) {
                        Toggle("Permitir medias jornadas", isOn: $viewModel.allowHalfDay)
                        Text("Al activarlo podrás asignar media jornada según corresponda.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

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
                } else {
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
                                    .frame(width: 12, height: 12)
                                Text(shift.name)
                                Spacer()
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
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
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
        }
    }

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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
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
                    .padding(.vertical, 8)
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

// MARK: - Funciones Auxiliares

func normalizeShiftType(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    switch lower {
    case "mañana", "manana", "morning", "am":
        return "Mañana"
    case "tarde", "afternoon", "pm":
        return "Tarde"
    case "noche", "night", "night shift":
        return "Noche"
    case "saliente", "post-night", "post night", "postnight":
        return "Saliente"
    case "día", "dia", "day":
        return "Día"
    case "media mañana", "media manana", "half morning", "m. mañana", "m. manana":
        return "Media Mañana"
    case "media tarde", "half afternoon", "m. tarde":
        return "Media Tarde"
    case "medio día", "medio dia", "half day":
        return "Medio Día"
    case "vacaciones", "vacation", "holiday":
        return "Vacaciones"
    case "libre", "off", "free":
        return "Libre"
    default:
        return trimmed
    }
}

func getShiftColorForType(_ type: String, customShiftTypes: [CustomShiftType]) -> Color {
    // Primero buscar en turnos personalizados
    if let custom = customShiftTypes.first(where: { $0.name.lowercased() == type.lowercased() }) {
        return custom.color
    }

    let normalized = normalizeShiftType(type).lowercased()

    switch normalized {
    case "vacaciones":
        return Color(hex: "EF5350")
    case "saliente":
        return Color(hex: "4CAF50")
    case "noche":
        return Color(hex: "5C6BC0")
    case "media tarde", "m. tarde":
        return Color(hex: "FFA726")
    case "media mañana", "m. mañana", "medio día":
        return Color(hex: "66BB6A")
    case "tarde":
        return Color(hex: "FF7043")
    case "mañana", "día":
        return Color(hex: "66BB6A")
    case "libre":
        return Color(hex: "334155")
    default:
        return Color(hex: "334155")
    }
}

func defaultShiftDurations(pattern: ShiftPattern) -> [String: Double] {
    switch pattern {
    case .three:
        return [
            "Mañana": 8.0,
            "Tarde": 8.0,
            "Noche": 8.0,
            "Saliente": 0.0
        ]
    case .two:
        return [
            "Día": 12.0,
            "Noche": 12.0,
            "Saliente": 0.0
        ]
    case .custom:
        return ["Saliente": 0.0]
    }
}

func withDefaultShiftDurations(_ current: [String: Double], pattern: ShiftPattern) -> [String: Double] {
    let defaults = defaultShiftDurations(pattern: pattern)
    var updated = current
    for (key, value) in defaults {
        if updated[key] == nil {
            updated[key] = value
        }
    }
    return updated
}

// MARK: - Cálculo de Estadísticas

func calculateOfflineStatsForMonth(month: Date, shifts: [String: UserShift], customShiftTypes: [CustomShiftType], shiftDurations: [String: Double]) -> OfflineMonthlyStats {
    var totalHours = 0.0
    var totalShifts = 0
    var breakdown: [String: ShiftStatData] = [:]

    let calendar = Calendar.current
    let targetMonth = calendar.component(.month, from: month)
    let targetYear = calendar.component(.year, from: month)

    for (dateKey, shift) in shifts {
        guard let date = dateFromString(dateKey) else { continue }
        let shiftMonth = calendar.component(.month, from: date)
        let shiftYear = calendar.component(.year, from: date)

        if shiftMonth != targetMonth || shiftYear != targetYear {
            continue
        }

        let hours = getShiftDurationHours(shift: shift, shiftDurations: shiftDurations, customShiftTypes: customShiftTypes)
        if hours <= 0.0 {
            continue
        }

        totalHours += hours
        totalShifts += 1

        let key = normalizeShiftType(shift.shiftName)
        if breakdown[key] == nil {
            breakdown[key] = ShiftStatData()
        }
        breakdown[key]!.hours += hours
        breakdown[key]!.count += 1
    }

    return OfflineMonthlyStats(totalHours: totalHours, totalShifts: totalShifts, breakdown: breakdown)
}

func getShiftDurationHours(shift: UserShift, shiftDurations: [String: Double], customShiftTypes: [CustomShiftType]) -> Double {
    // Buscar en turnos personalizados
    if let custom = customShiftTypes.first(where: { $0.name.lowercased() == shift.shiftName.lowercased() }) {
        return shift.isHalfDay ? custom.durationHours / 2.0 : custom.durationHours
    }

    let baseName = baseShiftNameForDuration(shift.shiftName)
    let baseDuration = shiftDurations[baseName] ?? 0.0

    return shift.isHalfDay ? baseDuration / 2.0 : baseDuration
}

func baseShiftNameForDuration(_ shiftName: String) -> String {
    let normalized = normalizeShiftType(shiftName)
    switch normalized {
    case "Media Mañana":
        return "Mañana"
    case "Media Tarde":
        return "Tarde"
    case "Medio Día":
        return "Día"
    default:
        return normalized
    }
}

func dateFromString(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dateString)
}

// MARK: - Extensiones Útiles

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }

    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
}
