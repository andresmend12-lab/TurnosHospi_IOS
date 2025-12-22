import SwiftUI

// MARK: - Modelos de Datos

struct UserShift: Codable, Equatable {
    let shiftName: String
    let isHalfDay: Bool
}

enum ShiftPattern: String, Codable, CaseIterable, Identifiable {
    case two
    case three
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .two: return "2 turnos"
        case .three: return "3 turnos"
        }
    }
}

struct OfflineShiftSettings: Codable {
    var pattern: ShiftPattern
    var allowHalfDay: Bool
}

// MARK: - ViewModel

class OfflineCalendarViewModel: ObservableObject {
    @Published var localShifts: [String: UserShift] = [:]
    @Published var localNotes: [String: [String]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var shiftTypes: [String] = []
    @Published var shiftPattern: ShiftPattern = .three {
        didSet { applyShiftSettingsChange() }
    }
    @Published var allowHalfDay: Bool = true {
        didSet { applyShiftSettingsChange() }
    }
    
    // Estados de UI
    @Published var isAssignmentMode: Bool = false
    @Published var selectedShiftToApply: String = "Mañana"
    
    // Gestión de notas
    @Published var isAddingNote: Bool = false
    @Published var newNoteText: String = ""
    @Published var editingNoteIndex: Int? = nil
    @Published var editingNoteText: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let shiftsKey = "shifts_map"
    private let notesKey = "notes_map"
    private let shiftSettingsKey = "shift_settings_map"
    
    init() {
        loadShiftSettings()
        loadStoredCalendarData()
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
                let isHalf = selectedShiftToApply.lowercased().contains("m.")
                let cleanName = isHalf ? selectedShiftToApply.replacingOccurrences(of: "M.", with: "Media") : selectedShiftToApply
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
    
    private func loadShiftSettings() {
        if let settingsData = userDefaults.data(forKey: shiftSettingsKey),
           let decodedSettings = try? JSONDecoder().decode(OfflineShiftSettings.self, from: settingsData) {
            shiftPattern = decodedSettings.pattern
            allowHalfDay = decodedSettings.allowHalfDay
        }
        applyShiftSettingsChange(save: false)
    }
    
    private func saveShiftSettings() {
        let settings = OfflineShiftSettings(pattern: shiftPattern, allowHalfDay: allowHalfDay)
        if let encodedSettings = try? JSONEncoder().encode(settings) {
            userDefaults.set(encodedSettings, forKey: shiftSettingsKey)
        }
    }
    
    private func applyShiftSettingsChange(save: Bool = true) {
        var types: [String] = []
        
        types.append("Mañana")
        if shiftPattern == .three {
            types.append("Tarde")
        }
        types.append("Noche")
        
        if allowHalfDay {
            types.append("M. Mañana")
            if shiftPattern == .three {
                types.append("M. Tarde")
            }
        }
        
        types.append(contentsOf: ["Saliente", "Vacaciones", "Libre"])
        
        shiftTypes = types
        
        if !shiftTypes.contains(selectedShiftToApply) {
            selectedShiftToApply = shiftTypes.first ?? "Libre"
        }
        
        if save {
            saveShiftSettings()
        }
    }
}

// MARK: - Vista Principal

struct OfflineCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Binding var showSettings: Bool
    
    init(showSettings: Binding<Bool> = .constant(false)) {
        _showSettings = showSettings
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F172A").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // --- CALENDARIO + AJUSTES ---
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 0) {
                            CalendarGridView(viewModel: viewModel)
                                .padding(.top)
                                .padding(.horizontal)
                            
                            LegendView(items: viewModel.legendItems)
                                .padding(.vertical, 10)
                        }
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.black)
                                .padding(8)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, -4)
                        .padding(.top, 0)
                    }
                    
                    // --- PANEL INFERIOR ---
                    VStack {
                        Spacer()
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
                
                // Botón Flotante (FAB)
                if !viewModel.isAssignmentMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
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
                            .padding(.trailing, 10)
                            .padding(.bottom, 140)
                        }
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
        .sheet(isPresented: $showSettings) {
            OfflineCalendarSettingsView(viewModel: viewModel)
        }
    }
}

// MARK: - LEYENDA

struct LegendView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let items: [String]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(themeManager.color(forShiftName: item))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                    Text(item)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: viewModel.currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
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
        
        var bgColor: Color = .clear
        
        if let shift = shift {
            if let type = mapToShiftType(shift.shiftName) {
                bgColor = themeManager.color(for: type)
            } else if shift.shiftName.lowercased().contains("saliente") {
                bgColor = Color.green.opacity(0.5)
            } else if shift.shiftName.lowercased().contains("vacaciones") {
                bgColor = Color.red.opacity(0.5)
            } else {
                bgColor = Color.gray.opacity(0.3)
            }
        } else {
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
               let prevShift = viewModel.localShifts[viewModel.dateKey(for: yesterday)],
               prevShift.shiftName.lowercased().contains("noche") {
                bgColor = Color.green.opacity(0.5)
            }
        }
        
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
    
    private func mapToShiftType(_ name: String) -> ShiftType? {
        let lower = name.lowercased()
        if lower.contains("media") && (lower.contains("mañana") || lower.contains("día")) { return .mediaManana }
        if lower.contains("media") && lower.contains("tarde") { return .mediaTarde }
        if lower.contains("mañana") || lower.contains("día") { return .manana }
        if lower.contains("tarde") { return .tarde }
        if lower.contains("noche") { return .noche }
        return nil
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
                    ForEach(viewModel.shiftTypes, id: \.self) { typeName in
                        let isSelected = viewModel.selectedShiftToApply == typeName
                        
                        Button(action: { viewModel.selectedShiftToApply = typeName }) {
                            Text(typeName)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color(hex: "54C7EC") : getButtonColor(for: typeName).opacity(0.6))
                                .foregroundColor(isSelected ? .black : .white)
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
        if typeName == "Libre" {
            return Color(hex: "334155")
        }
        
        if let type = mapToShiftType(typeName) {
            return themeManager.color(for: type)
        } else if typeName.lowercased().contains("saliente") {
            return Color.green.opacity(0.5)
        } else if typeName.lowercased().contains("vacaciones") {
            return Color.red.opacity(0.5)
        }
        
        return Color(hex: "334155")
    }
    
    private func mapToShiftType(_ name: String) -> ShiftType? {
        let lower = name.lowercased()
        if lower.contains("m.") && lower.contains("mañana") { return .mediaManana }
        if lower.contains("m.") && lower.contains("tarde") { return .mediaTarde }
        if lower == "mañana" { return .manana }
        if lower == "tarde" { return .tarde }
        if lower == "noche" { return .noche }
        return nil
    }
}

struct NotesControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cabecera Día
            HStack {
                VStack(alignment: .leading) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    let key = viewModel.dateKey(for: viewModel.selectedDate)
                    Text(viewModel.localShifts[key]?.shiftName ?? "Libre")
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
            .frame(maxHeight: 250)
            
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

struct OfflineCalendarSettingsView: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Turnos diarios")) {
                    Picker("Cantidad de turnos", selection: $viewModel.shiftPattern) {
                        ForEach(ShiftPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Define si manejas dos turnos (día/noche) o tres turnos (mañana/tarde/noche).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Medias jornadas")) {
                    Toggle("Permitir medias jornadas", isOn: $viewModel.allowHalfDay)
                    Text("Al activarlo podrás asignar M. Mañana o M. Tarde según corresponda.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Configuración")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
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
