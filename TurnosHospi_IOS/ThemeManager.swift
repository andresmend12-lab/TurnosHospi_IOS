import SwiftUI

// NOTA: Se ha eliminado 'enum ShiftType' de aquí porque ya existe en tu proyecto.

class ThemeManager: ObservableObject {
    static let shared = ThemeManager() // Singleton

    // --- Claves para UserDefaults ---
    private let kMorning = "color_morning"
    private let kMorningHalf = "color_morning_half"
    private let kAfternoon = "color_afternoon"
    private let kAfternoonHalf = "color_afternoon_half"
    private let kNight = "color_night"
    private let kSaliente = "color_saliente"
    private let kFreeDay = "color_free"
    private let kHoliday = "color_holiday"
    
    // --- Colores Publicados ---
    @Published var morningColor: Color
    @Published var morningHalfColor: Color
    @Published var afternoonColor: Color
    @Published var afternoonHalfColor: Color
    @Published var nightColor: Color
    @Published var salienteColor: Color
    @Published var freeDayColor: Color
    @Published var holidayColor: Color
    
    init() {
        // Cargar colores guardados o usar los por defecto definidos
        self.morningColor = ThemeManager.loadColor(key: kMorning) ?? Color(hex: "D97706")       // Mañana: Amarillo Oscuro
        self.morningHalfColor = ThemeManager.loadColor(key: kMorningHalf) ?? Color(hex: "FDE047") // M. Mañana: Amarillo Claro
        self.afternoonColor = ThemeManager.loadColor(key: kAfternoon) ?? Color(hex: "60A5FA")   // Tarde: Azul Claro
        self.afternoonHalfColor = ThemeManager.loadColor(key: kAfternoonHalf) ?? Color(hex: "2DD4BF") // M. Tarde: Turquesa
        self.nightColor = ThemeManager.loadColor(key: kNight) ?? Color(hex: "A855F7")           // Noche: Violeta
        
        // --- COLORES ACTUALIZADOS ---
        self.salienteColor = ThemeManager.loadColor(key: kSaliente) ?? Color(hex: "00008B")     // Saliente: Azul Oscuro
        self.freeDayColor = ThemeManager.loadColor(key: kFreeDay) ?? Color(hex: "22C55E")       // Libre: Verde
        self.holidayColor = ThemeManager.loadColor(key: kHoliday) ?? .red                       // Vacaciones: Rojo
    }
    
    // --- Lógica de Selección de Color ---
    
    // 1. Obtener color por Enum (Tipos básicos existentes en tu otro archivo)
    func color(for type: ShiftType) -> Color {
        switch type {
        case .manana: return morningColor
        case .mediaManana: return morningHalfColor
        case .tarde: return afternoonColor
        case .mediaTarde: return afternoonHalfColor
        case .noche: return nightColor
        }
    }
    
    // 2. Obtener color por Nombre (String) - Para manejar Saliente, Libre, Vacaciones y legacy
    func color(forShiftName name: String) -> Color {
        let lower = name.lowercased()
        
        // Prioridad a estados especiales
        if lower.contains("saliente") { return salienteColor }
        if lower == "libre" { return freeDayColor }
        if lower.contains("vacaciones") { return holidayColor }
        
        // Chequeo de turnos estándar
        if lower.contains("media") && (lower.contains("mañana") || lower.contains("m.")) { return morningHalfColor }
        if lower.contains("media") && (lower.contains("tarde") || lower.contains("m.")) { return afternoonHalfColor }
        if lower.contains("mañana") { return morningColor }
        if lower.contains("tarde") { return afternoonColor }
        if lower.contains("noche") { return nightColor }
        
        return .gray // Color por defecto si no coincide
    }
    
    // --- Persistencia ---
    
    func saveColors() {
        ThemeManager.saveColor(color: morningColor, key: kMorning)
        ThemeManager.saveColor(color: morningHalfColor, key: kMorningHalf)
        ThemeManager.saveColor(color: afternoonColor, key: kAfternoon)
        ThemeManager.saveColor(color: afternoonHalfColor, key: kAfternoonHalf)
        ThemeManager.saveColor(color: nightColor, key: kNight)
        ThemeManager.saveColor(color: salienteColor, key: kSaliente)
        ThemeManager.saveColor(color: freeDayColor, key: kFreeDay)
        ThemeManager.saveColor(color: holidayColor, key: kHoliday)
    }
    
    func resetDefaults() {
        morningColor = Color(hex: "D97706")
        morningHalfColor = Color(hex: "FDE047")
        afternoonColor = Color(hex: "60A5FA")
        afternoonHalfColor = Color(hex: "2DD4BF")
        nightColor = Color(hex: "A855F7")
        
        // Actualizamos los defaults también
        salienteColor = Color(hex: "00008B")
        freeDayColor = Color(hex: "22C55E")
        holidayColor = .red
        
        saveColors()
    }
    
    // --- Helpers Privados ---
    private static func loadColor(key: String) -> Color? {
        guard let hex = UserDefaults.standard.string(forKey: key) else { return nil }
        return Color(hex: hex)
    }
    
    private static func saveColor(color: Color, key: String) {
        if let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: key)
        }
    }
}

// MARK: - Extensiones Color

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
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        if components.count >= 4 { a = Float(components[3]) }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(a * 255), lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
