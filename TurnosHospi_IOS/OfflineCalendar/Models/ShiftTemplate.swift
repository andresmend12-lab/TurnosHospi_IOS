import Foundation

// MARK: - Modelo de Plantilla de Turnos Personalizable

struct ShiftTemplate: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var pattern: [String?]  // Array de N elementos (duración variable)
                            // nil = Libre, String = nombre del turno

    // Duración en días del patrón
    var durationDays: Int {
        return pattern.count
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        description: String = "",
        pattern: [String?] = Array(repeating: nil, count: 7)
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.pattern = pattern.isEmpty ? Array(repeating: nil, count: 7) : pattern
    }

    // Helper para obtener el turno de un día específico
    func shift(for dayIndex: Int) -> String? {
        guard dayIndex >= 0 && dayIndex < pattern.count else { return nil }
        return pattern[dayIndex]
    }

    // Helper para establecer el turno de un día específico
    mutating func setShift(_ shiftName: String?, for dayIndex: Int) {
        guard dayIndex >= 0 && dayIndex < pattern.count else { return }
        pattern[dayIndex] = shiftName
    }

    // Añadir un día al patrón
    mutating func addDay(_ shiftName: String? = nil) {
        pattern.append(shiftName)
    }

    // Eliminar el último día del patrón
    mutating func removeLastDay() {
        guard pattern.count > 1 else { return }
        pattern.removeLast()
    }

    // Cambiar la duración del patrón
    mutating func setDuration(_ days: Int) {
        guard days >= 1 else { return }
        if days > pattern.count {
            // Añadir días
            pattern.append(contentsOf: Array(repeating: nil, count: days - pattern.count))
        } else if days < pattern.count {
            // Quitar días
            pattern = Array(pattern.prefix(days))
        }
    }

    // Nombres de los días (para mostrar en UI)
    static func dayName(for index: Int) -> String {
        let dayNames = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
        let weekNumber = index / 7 + 1
        let dayInWeek = index % 7

        if weekNumber == 1 {
            return dayNames[dayInWeek]
        } else {
            return "S\(weekNumber) \(dayNames[dayInWeek])"
        }
    }

    static func dayAbbreviation(for index: Int) -> String {
        let abbrevs = ["L", "M", "X", "J", "V", "S", "D"]
        return abbrevs[index % 7]
    }

    // Para compatibilidad
    static let dayNames = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    static let dayAbbreviations = ["L", "M", "X", "J", "V", "S", "D"]
}

// MARK: - Gestor de Plantillas (Persistencia)

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()

    @Published var templates: [ShiftTemplate] = []

    private let userDefaultsKey = "user_shift_templates_v4"
    private let migrationKey = "templates_migrated_v4"

    private init() {
        migrateIfNeeded()
        loadTemplates()
    }

    // MARK: - Migración (limpiar plantillas antiguas)

    private func migrateIfNeeded() {
        // Si ya se migró, no hacer nada
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }

        // Limpiar cualquier dato antiguo de plantillas (todas las versiones anteriores)
        UserDefaults.standard.removeObject(forKey: "user_shift_templates")
        UserDefaults.standard.removeObject(forKey: "user_shift_templates_v2")
        UserDefaults.standard.removeObject(forKey: "user_shift_templates_v3")
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: "shiftTemplates")
        UserDefaults.standard.removeObject(forKey: "templates")

        // Marcar como migrado
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()

        print("✅ Plantillas migradas v4: datos antiguos eliminados")
    }

    // MARK: - Cargar plantillas

    func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ShiftTemplate].self, from: data) else {
            templates = []
            return
        }
        templates = decoded
    }

    // MARK: - Guardar plantillas

    private func saveTemplates() {
        guard let encoded = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }

    // MARK: - CRUD Operations

    func addTemplate(_ template: ShiftTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: ShiftTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }

    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
    }
}
