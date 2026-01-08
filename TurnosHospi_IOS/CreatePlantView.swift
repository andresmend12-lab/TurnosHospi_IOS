import SwiftUI
import FirebaseDatabase
import FirebaseAuth // Necesario para obtener el UID del usuario actual

struct CreatePlantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager // Acceso a los datos del supervisor
    
    // --- DATOS GENERALES ---
    @State private var plantName: String = ""
    @State private var unitType: String = ""
    @State private var hospitalName: String = ""
    @State private var accessPassword: String = "" // Generada automáticamente
    
    // --- CONFIGURACIÓN DE TURNOS ---
    enum ShiftDuration: String, CaseIterable {
        case eightHours = "8 Horas"
        case twelveHours = "12 Horas"
    }
    @State private var selectedDuration: ShiftDuration = .eightHours
    @State private var allowHalfDay: Bool = false
    
    // Horarios 8h
    @State private var morningStart = defaultTime(8)
    @State private var morningEnd = defaultTime(15)
    @State private var afternoonStart = defaultTime(15)
    @State private var afternoonEnd = defaultTime(22)
    @State private var nightStart = defaultTime(22)
    @State private var nightEnd = defaultTime(8)
    
    // Horarios 12h
    @State private var day12Start = defaultTime(8)
    @State private var day12End = defaultTime(20)
    @State private var night12Start = defaultTime(20)
    @State private var night12End = defaultTime(8)
    
    // --- PERSONAL ---
    enum StaffType: String, CaseIterable {
        case nursesOnly = "Solo Enfermeros"
        case nursesAndAux = "Enfermeros y Auxiliares"
        
        var dbValue: String {
            switch self {
            case .nursesOnly: return "nurses_only"
            case .nursesAndAux: return "nurses_and_aux"
            }
        }
    }
    @State private var selectedStaffType: StaffType = .nursesOnly
    
    // --- REQUERIMIENTOS MÍNIMOS ---
    @State private var minStaffRequirements: [String: Int] = [
        "Mañana": 1, "Tarde": 1, "Noche": 1, "Día": 1
    ]
    
    // --- ESTADO DE CARGA ---
    @State private var isLoading = false
    
    // --- VALIDACIÓN ---
    var isValid: Bool {
        return !plantName.isEmpty &&
               !unitType.isEmpty &&
               !hospitalName.isEmpty &&
               !accessPassword.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Fondo
            Color.deepSpace.ignoresSafeArea()
            
            // Decoración
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 300).blur(radius: 90).offset(x: -120, y: -300).opacity(0.4)
                Circle().fill(Color.neonViolet).frame(width: 300).blur(radius: 90).offset(x: 120, y: 100).opacity(0.4)
            }
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // Cabecera
                    HStack {
                        Text("Nueva Planta")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.top)
                    
                    // 1. DATOS GENERALES
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeader(title: "Datos Generales", icon: "building.2.fill")
                        
                        GlassTextField(icon: "cross.case.fill", placeholder: "Nombre de la Planta", text: $plantName)
                        GlassTextField(icon: "bed.double.fill", placeholder: "Tipo de Unidad", text: $unitType)
                        GlassTextField(icon: "building.columns.fill", placeholder: "Nombre del Hospital", text: $hospitalName)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    // 2. CONFIGURACIÓN DE TURNOS
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeader(title: "Configuración de Turnos", icon: "clock.fill")
                        
                        // Selector 8h vs 12h
                        VStack(alignment: .leading) {
                            Text("Duración de Turnos")
                                .font(.caption).foregroundColor(.gray)
                            Picker("Duración", selection: $selectedDuration) {
                                ForEach(ShiftDuration.allCases, id: \.self) { duration in
                                    Text(duration.rawValue).tag(duration)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorScheme(.dark)
                        }
                        
                        // Toggle Media Jornada
                        Toggle(isOn: $allowHalfDay) {
                            Text("Permitir turnos de media jornada")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .tint(Color.neonViolet)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        // Selectores de hora
                        if selectedDuration == .eightHours {
                            TimeRangePicker(label: "Mañana", start: $morningStart, end: $morningEnd, color: .yellow)
                            TimeRangePicker(label: "Tarde", start: $afternoonStart, end: $afternoonEnd, color: .orange)
                            TimeRangePicker(label: "Noche", start: $nightStart, end: $nightEnd, color: .blue)
                        } else {
                            TimeRangePicker(label: "Turno de Día", start: $day12Start, end: $day12End, color: .yellow)
                            TimeRangePicker(label: "Turno de Noche", start: $night12Start, end: $night12End, color: .blue)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    // 3. PERSONAL
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeader(title: "Personal de la Planta", icon: "person.3.fill")
                        
                        HStack {
                            ForEach(StaffType.allCases, id: \.self) { type in
                                Button(action: { selectedStaffType = type }) {
                                    HStack {
                                        Image(systemName: type == selectedStaffType ? "checkmark.circle.fill" : "circle")
                                        Text(type.rawValue)
                                            .font(.caption)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(type == selectedStaffType ? Color.neonViolet.opacity(0.3) : Color.white.opacity(0.05))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(type == selectedStaffType ? Color.neonViolet : Color.clear, lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    // 4. REQUERIMIENTOS MÍNIMOS
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeader(title: "Requerimiento Mínimo (Pers.)", icon: "person.bust.fill")
                        
                        if selectedDuration == .eightHours {
                            StaffStepper(label: "Mín. Mañana", value: binding(for: "Mañana"))
                            StaffStepper(label: "Mín. Tarde", value: binding(for: "Tarde"))
                            StaffStepper(label: "Mín. Noche", value: binding(for: "Noche"))
                        } else {
                            StaffStepper(label: "Mín. Turno Día", value: binding(for: "Día"))
                            StaffStepper(label: "Mín. Turno Noche", value: binding(for: "Noche12"))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    // BOTÓN CREAR
                    Button(action: createPlant) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Crear Planta")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid
                                            ? LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: isValid ? .neonViolet.opacity(0.5) : .clear, radius: 10, x: 0, y: 5)
                        }
                    }
                    .disabled(!isValid || isLoading)
                    .opacity(isValid ? 1.0 : 0.6)
                    .padding(.bottom, 40)
                    
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            if accessPassword.isEmpty {
                generateRandomPassword()
            }
        }
    }
    
    // --- LÓGICA Y HELPERS ---
    
    func generateRandomPassword() {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        accessPassword = String((0..<6).compactMap { _ in chars.randomElement() })
    }
    
    private func binding(for key: String) -> Binding<Int> {
        return Binding(
            get: { self.minStaffRequirements[key] ?? 1 },
            set: { self.minStaffRequirements[key] = $0 }
        )
    }
    
    static func defaultTime(_ hour: Int) -> Date {
        return Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
    }
    
    func createPlant() {
        // Validación extra de usuario
        guard let user = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        let ref = Database.database().reference()
        
        // 1. Generar ID
        guard let plantRef = ref.child("plants").childByAutoId().key else { return }
        let plantId = plantRef
        
        // Formato de hora
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        // Preparar turnos y requerimientos
        var shiftTimes: [String: [String: String]] = [:]
        var finalRequirements: [String: Int] = [:]
        
        if selectedDuration == .eightHours {
            shiftTimes["Mañana"] = ["start": timeFormatter.string(from: morningStart), "end": timeFormatter.string(from: morningEnd)]
            shiftTimes["Tarde"] = ["start": timeFormatter.string(from: afternoonStart), "end": timeFormatter.string(from: afternoonEnd)]
            shiftTimes["Noche"] = ["start": timeFormatter.string(from: nightStart), "end": timeFormatter.string(from: nightEnd)]
            
            finalRequirements["Mañana"] = minStaffRequirements["Mañana"]
            finalRequirements["Tarde"] = minStaffRequirements["Tarde"]
            finalRequirements["Noche"] = minStaffRequirements["Noche"]
        } else {
            shiftTimes["Día"] = ["start": timeFormatter.string(from: day12Start), "end": timeFormatter.string(from: day12End)]
            shiftTimes["Noche"] = ["start": timeFormatter.string(from: night12Start), "end": timeFormatter.string(from: night12End)]
            
            finalRequirements["Día"] = minStaffRequirements["Día"]
            finalRequirements["Noche"] = minStaffRequirements["Noche12"]
        }
        
        // Datos del supervisor para añadir a la planta
        let supervisorData: [String: Any] = [
            "plantId": plantId,
            "staffName": authManager.currentUserName,
            "staffRole": authManager.userRole, // Debería ser "Supervisor"
            "joinedAt": ServerValue.timestamp()
        ]
        
        // Objeto Planta completo
        let plantData: [String: Any] = [
            "id": plantId,
            "name": plantName,
            "hospitalName": hospitalName,
            "unitType": unitType,
            "accessPassword": accessPassword,
            "shiftDuration": selectedDuration.rawValue.lowercased(),
            "allowHalfDay": allowHalfDay,
            "staffScope": selectedStaffType.dbValue,
            "createdAt": ServerValue.timestamp(),
            "shiftTimes": shiftTimes,
            "staffRequirements": finalRequirements,
            // Aquí añadimos al supervisor directamente
            "userPlants": [
                user.uid: supervisorData
            ]
        ]
        
        // 2. Guardar Planta en Firebase
        ref.child("plants").child(plantId).setValue(plantData) { error, _ in
            if let error = error {
                AppLogger.error("Error creando planta: \(error.localizedDescription)")
                isLoading = false
            } else {

                // 3. Actualizar el perfil del usuario (Supervisor) para vincularlo a esta planta
                let userUpdates: [String: Any] = [
                    "plantId": plantId,
                    "role": authManager.userRole // Reconfirmamos rol por si acaso
                ]

                ref.child("users").child(user.uid).updateChildValues(userUpdates) { err, _ in
                    isLoading = false
                    if err == nil {
                        // 4. Actualizar estado local para que la UI responda inmediatamente
                        DispatchQueue.main.async {
                            authManager.userPlantId = plantId
                            AppLogger.plant("Planta creada y supervisor asignado con éxito.")
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Componentes Auxiliares

struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.electricBlue)
            Text(title).font(.headline).foregroundColor(.white.opacity(0.9))
        }
    }
}

struct TimeRangePicker: View {
    let label: String
    @Binding var start: Date
    @Binding var end: Date
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.subheadline).bold().foregroundColor(.white)
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Inicio").font(.caption2).foregroundColor(.gray)
                    DatePicker("", selection: $start, displayedComponents: .hourAndMinute)
                        .labelsHidden().colorScheme(.dark)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundColor(.gray)
                Spacer()
                VStack(alignment: .leading) {
                    Text("Fin").font(.caption2).foregroundColor(.gray)
                    DatePicker("", selection: $end, displayedComponents: .hourAndMinute)
                        .labelsHidden().colorScheme(.dark)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.2))
            .cornerRadius(10)
        }
    }
}

struct StaffStepper: View {
    let label: String
    @Binding var value: Int
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            HStack {
                Button(action: { if value > 0 { value -= 1 } }) {
                    Image(systemName: "minus.circle.fill").foregroundColor(.gray)
                }
                Text("\(value)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(width: 30)
                    .multilineTextAlignment(.center)
                Button(action: { value += 1 }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.electricBlue)
                }
            }
        }
    }
}
