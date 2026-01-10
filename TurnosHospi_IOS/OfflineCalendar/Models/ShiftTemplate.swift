import Foundation

// MARK: - Modelo de Plantilla de Turnos

struct ShiftTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var pattern: [TemplateDay]
    var rotationWeeks: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        pattern: [TemplateDay],
        rotationWeeks: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.pattern = pattern
        self.rotationWeeks = rotationWeeks
    }
}

struct TemplateDay: Codable, Equatable {
    let dayIndex: Int
    let shiftName: String?
    let isHalfDay: Bool

    init(dayIndex: Int, shiftName: String? = nil, isHalfDay: Bool = false) {
        self.dayIndex = dayIndex
        self.shiftName = shiftName
        self.isHalfDay = isHalfDay
    }
}

// MARK: - Plantillas predefinidas

extension ShiftTemplate {

    static let predefined: [ShiftTemplate] = [
        // Turno rotativo mañana/tarde
        ShiftTemplate(
            name: "Rotativo M/T",
            description: "Alterna mañana y tarde cada semana",
            pattern: [
                TemplateDay(dayIndex: 0, shiftName: "Mañana"),
                TemplateDay(dayIndex: 1, shiftName: "Mañana"),
                TemplateDay(dayIndex: 2, shiftName: "Mañana"),
                TemplateDay(dayIndex: 3, shiftName: "Mañana"),
                TemplateDay(dayIndex: 4, shiftName: "Mañana"),
                TemplateDay(dayIndex: 5),
                TemplateDay(dayIndex: 6),
                TemplateDay(dayIndex: 0, shiftName: "Tarde"),
                TemplateDay(dayIndex: 1, shiftName: "Tarde"),
                TemplateDay(dayIndex: 2, shiftName: "Tarde"),
                TemplateDay(dayIndex: 3, shiftName: "Tarde"),
                TemplateDay(dayIndex: 4, shiftName: "Tarde"),
                TemplateDay(dayIndex: 5),
                TemplateDay(dayIndex: 6),
            ],
            rotationWeeks: 2
        ),

        // Turno de noches
        ShiftTemplate(
            name: "Noches 4x3",
            description: "4 noches seguidas, 3 días libres",
            pattern: [
                TemplateDay(dayIndex: 0, shiftName: "Noche"),
                TemplateDay(dayIndex: 1, shiftName: "Noche"),
                TemplateDay(dayIndex: 2, shiftName: "Noche"),
                TemplateDay(dayIndex: 3, shiftName: "Noche"),
                TemplateDay(dayIndex: 4),
                TemplateDay(dayIndex: 5),
                TemplateDay(dayIndex: 6),
            ],
            rotationWeeks: 1
        ),

        // 12 horas
        ShiftTemplate(
            name: "12h Día/Noche",
            description: "2 días, 2 noches, 4 libres",
            pattern: [
                TemplateDay(dayIndex: 0, shiftName: "Día"),
                TemplateDay(dayIndex: 1, shiftName: "Día"),
                TemplateDay(dayIndex: 2, shiftName: "Noche"),
                TemplateDay(dayIndex: 3, shiftName: "Noche"),
                TemplateDay(dayIndex: 4),
                TemplateDay(dayIndex: 5),
                TemplateDay(dayIndex: 6),
                TemplateDay(dayIndex: 0),
            ],
            rotationWeeks: 1
        ),

        // Solo fines de semana
        ShiftTemplate(
            name: "Fines de semana",
            description: "Solo sábado y domingo",
            pattern: [
                TemplateDay(dayIndex: 0),
                TemplateDay(dayIndex: 1),
                TemplateDay(dayIndex: 2),
                TemplateDay(dayIndex: 3),
                TemplateDay(dayIndex: 4),
                TemplateDay(dayIndex: 5, shiftName: "Mañana"),
                TemplateDay(dayIndex: 6, shiftName: "Mañana"),
            ],
            rotationWeeks: 1
        ),

        // Turno partido
        ShiftTemplate(
            name: "Partido L-V",
            description: "Mañana y tarde de lunes a viernes",
            pattern: [
                TemplateDay(dayIndex: 0, shiftName: "Mañana"),
                TemplateDay(dayIndex: 1, shiftName: "Tarde"),
                TemplateDay(dayIndex: 2, shiftName: "Mañana"),
                TemplateDay(dayIndex: 3, shiftName: "Tarde"),
                TemplateDay(dayIndex: 4, shiftName: "Mañana"),
                TemplateDay(dayIndex: 5),
                TemplateDay(dayIndex: 6),
            ],
            rotationWeeks: 1
        ),
    ]
}
