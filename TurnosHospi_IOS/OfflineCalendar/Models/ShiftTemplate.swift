import Foundation

// MARK: - Modelo de Plantilla de Turnos Personalizable

struct ShiftTemplate: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var weekPattern: [String?]  // Array de 7 elementos: [Lunes, Martes, ..., Domingo]
                                 // nil = Libre, String = nombre del turno

    init(
        id: UUID = UUID(),
        name: String = "",
        description: String = "",
        weekPattern: [String?] = Array(repeating: nil, count: 7)
    ) {
        self.id = id
        self.name = name
        self.description = description
        // Asegurar que siempre tenga 7 elementos
        self.weekPattern = weekPattern.count == 7 ? weekPattern : Array(repeating: nil, count: 7)
    }

    // Helper para obtener el turno de un día específico
    func shift(for dayIndex: Int) -> String? {
        guard dayIndex >= 0 && dayIndex < 7 else { return nil }
        return weekPattern[dayIndex]
    }

    // Helper para establecer el turno de un día específico
    mutating func setShift(_ shiftName: String?, for dayIndex: Int) {
        guard dayIndex >= 0 && dayIndex < 7 else { return }
        weekPattern[dayIndex] = shiftName
    }

    // Nombres de los días
    static let dayNames = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    static let dayAbbreviations = ["L", "M", "X", "J", "V", "S", "D"]
}

// MARK: - Gestor de Plantillas (Persistencia)

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()

    @Published var templates: [ShiftTemplate] = []

    private let userDefaultsKey = "user_shift_templates_v3"
    private let migrationKey = "templates_migrated_v3"

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
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: "shiftTemplates")
        UserDefaults.standard.removeObject(forKey: "templates")

        // Marcar como migrado
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()

        print("✅ Plantillas migradas v3: datos antiguos eliminados")
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
