import SwiftUI

// MARK: - Modelos de Datos

struct UserShift: Codable, Equatable {
    let shiftName: String
    let isHalfDay: Bool
}

struct ShiftColors {
    // Puedes ajustar estos colores a los de tu Assets.xcassets
    static let morning = Color.blue.opacity(0.7)
    static let afternoon = Color.orange.opacity(0.7)
    static let night = Color.purple.opacity(0.7)
    static let saliente = Color.green.opacity(0.7) // Color específico para Saliente
    static let holiday = Color.red.opacity(0.7)
    static let free = Color.clear
    static let morningHalf = Color.blue.opacity(0.4)
    static let afternoonHalf = Color.orange.opacity(0.4)
    
    static func color(for shiftName: String) -> Color {
        let name = shiftName.lowercased()
        if name.contains("vacaciones") { return holiday }
        if name.contains("noche") { return night }
        if name.contains("media") && (name.contains("mañana") || name.contains("día")) { return morningHalf }
        if name.contains("mañana") || name.contains("día") { return morning }
        if name.contains("media") && name.contains("tarde") { return afternoonHalf }
        if name.contains("tarde") { return afternoon }
        if name.contains("saliente") { return saliente }
        return morning
    }
}

// MARK: - ViewModel

class OfflineCalendarViewModel: ObservableObject {
    @Published var localShifts: [String: UserShift] = [:]
    @Published var localNotes: [String: [String]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    
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
    
    let shiftTypes = ["Mañana", "Tarde", "Noche", "Saliente", "M. Mañana", "M. Tarde", "Vacaciones", "Libre"]
    
    init() {
        loadData()
    }
    
    func loadData() {
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
            // Resetear estados de notas al cambiar de día
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
    
    // Helpers para calendario
    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
}

// MARK: - Vista Principal

struct OfflineCalendarView: View {
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F172A").edgesIgnoringSafeArea(.all) // Fondo oscuro
                
                VStack(spacing: 0) {
                    // --- CALENDARIO ---
                    CalendarGridView(viewModel: viewModel)
                        .padding()
                    
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
                
                // Botón Flotante (FAB) para entrar en modo edición
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
                            .padding(.trailing, 24)
                            .padding(.bottom, 220) // Ajustar según altura del panel inferior
                        }
                    }
                }
            }
            .navigationBarTitle("Mi Planilla", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
            })
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Subvistas

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
                        Text("").frame(height: 40) // Espaciador
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
        // Ajustar para que Lunes sea 0 (domingo es 1 en Calendar)
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
    
    var body: some View {
        let dateKey = viewModel.dateKey(for: date)
        let shift = viewModel.localShifts[dateKey]
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let hasNotes = !(viewModel.localNotes[dateKey]?.isEmpty ?? true)
        
        // Calcular color del turno o Saliente automático
        var bgColor: Color = .clear
        if let shift = shift {
            bgColor = ShiftColors.color(for: shift.shiftName)
        } else {
            // Lógica Saliente automático (día después de noche)
            if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
               let prevShift = viewModel.localShifts[viewModel.dateKey(for: yesterday)],
               prevShift.shiftName.lowercased().contains("noche") {
                bgColor = ShiftColors.saliente
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
                    .fill(Color(hex: "E91E63")) // Punto rojo
                    .frame(width: 8, height: 8)
                    .offset(y: 2)
            }
        }
        .onTapGesture {
            viewModel.handleDayClick(date: date)
        }
    }
}

// MARK: - Paneles de Control

struct AssignmentControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Modo Asignación")
                .font(.headline)
                .foregroundColor(Color(hex: "54C7EC"))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.shiftTypes, id: \.self) { type in
                        let isSelected = viewModel.selectedShiftToApply == type
                        Button(action: { viewModel.selectedShiftToApply = type }) {
                            Text(type)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color(hex: "54C7EC") : Color(hex: "334155"))
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
            
            // Lista de Notas
            let key = viewModel.dateKey(for: viewModel.selectedDate)
            let notes = viewModel.localNotes[key] ?? []
            
            if notes.isEmpty && !viewModel.isAddingNote {
                Text("No hay notas. Pulsa + para crear una.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                if viewModel.editingNoteIndex == index {
                    // Edición
                    HStack {
                        TextField("", text: $viewModel.editingNoteText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .colorScheme(.light)
                        
                        Button(action: { viewModel.updateNote(at: index) }) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                        Button(action: { viewModel.editingNoteIndex = nil }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        }
                    }
                } else {
                    // Visualización
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
            
            // Añadir Nueva Nota
            if viewModel.isAddingNote {
                HStack {
                    TextField("Escribe aquí...", text: $viewModel.newNoteText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .colorScheme(.light)
                    
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
        // Altura mínima para que no salte mucho al añadir cosas
        .frame(minHeight: 200, alignment: .top)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Extensiones Útiles

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
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
