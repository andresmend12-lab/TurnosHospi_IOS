import SwiftUI

struct CreatePlantView: View {
    @Environment(\.dismiss) var dismiss
    
    // --- DATOS GENERALES ---
    @State private var plantName: String = ""
    @State private var unitType: String = ""
    @State private var hospitalName: String = ""
    
    // --- CONFIGURACIÓN DE TURNOS ---
    enum ShiftDuration: String, CaseIterable {
        case eightHours = "8 Horas (Mañana, Tarde, Noche)"
        case twelveHours = "12 Horas (Día, Noche)"
    }
    @State private var selectedDuration: ShiftDuration = .eightHours
    
    // Horarios 8h
    @State private var morningStart = Calendar.current.date(from: DateComponents(hour: 8))!
    @State private var morningEnd = Calendar.current.date(from: DateComponents(hour: 15))!
    @State private var afternoonStart = Calendar.current.date(from: DateComponents(hour: 15))!
    @State private var afternoonEnd = Calendar.current.date(from: DateComponents(hour: 22))!
    @State private var nightStart = Calendar.current.date(from: DateComponents(hour: 22))!
    @State private var nightEnd = Calendar.current.date(from: DateComponents(hour: 8))!
    
    // Horarios 12h
    @State private var day12Start = Calendar.current.date(from: DateComponents(hour: 8))!
    @State private var day12End = Calendar.current.date(from: DateComponents(hour: 20))!
    @State private var night12Start = Calendar.current.date(from: DateComponents(hour: 20))!
    @State private var night12End = Calendar.current.date(from: DateComponents(hour: 8))!
    
    // --- PERSONAL ---
    enum StaffType: String, CaseIterable {
        case nursesOnly = "Solo Enfermeros"
        case nursesAndAux = "Enfermeros y Auxiliares"
    }
    @State private var selectedStaffType: StaffType = .nursesOnly
    
    // --- REQUERIMIENTOS MÍNIMOS ---
    // Diccionario para guardar el número de personas por turno
    @State private var minStaffRequirements: [String: Int] = [
        "Mañana": 1, "Tarde": 1, "Noche": 1, "Día": 1
    ]
    
    var body: some View {
        ZStack {
            // Fondo
            Color.deepSpace.ignoresSafeArea()
            
            // Decoración de fondo
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
                        
                        GlassTextField(icon: "cross.case.fill", placeholder: "Nombre de la Planta (ej: UCI 1)", text: $plantName)
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
                            .colorScheme(.dark) // Para que se vea bien en fondo oscuro
                        }
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        // Lógica condicional para los selectores de hora
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
                                    }
                                    .padding(10)
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
                        Text("Crear Planta")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(15)
                            .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 40)
                    
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Helper para binding seguro al diccionario
    private func binding(for key: String) -> Binding<Int> {
        return Binding(
            get: { self.minStaffRequirements[key] ?? 1 },
            set: { self.minStaffRequirements[key] = $0 }
        )
    }
    
    func createPlant() {
        // Aquí iría la lógica para guardar en Firebase usando PlantManager
        print("Creando planta: \(plantName) - \(selectedDuration.rawValue)")
        dismiss()
    }
}

// MARK: - Componentes Auxiliares para el diseño
struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.electricBlue)
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
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
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundColor(.gray)
                Spacer()
                VStack(alignment: .leading) {
                    Text("Fin").font(.caption2).foregroundColor(.gray)
                    DatePicker("", selection: $end, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
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
            Text(label)
                .foregroundColor(.white)
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
