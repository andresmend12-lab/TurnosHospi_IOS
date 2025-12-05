import SwiftUI

class ThemeManager: ObservableObject {
    // Claves para guardar en UserDefaults
    private let kMorning = "color_morning"
    private let kMorningHalf = "color_morning_half"
    private let kAfternoon = "color_afternoon"
    private let kAfternoonHalf = "color_afternoon_half"
    private let kNight = "color_night"
    private let kHoliday = "color_holiday"
    
    // Colores publicados (la vista se actualizará al cambiarlos)
    @Published var morningColor: Color
    @Published var morningHalfColor: Color
    @Published var afternoonColor: Color
    @Published var afternoonHalfColor: Color
    @Published var nightColor: Color
    @Published var holidayColor: Color
    
    init() {
        // Cargar colores guardados o usar los por defecto
        self.morningColor = ThemeManager.loadColor(key: kMorning) ?? .yellow
        self.morningHalfColor = ThemeManager.loadColor(key: kMorningHalf) ?? Color(red: 1.0, green: 0.9, blue: 0.6)
        self.afternoonColor = ThemeManager.loadColor(key: kAfternoon) ?? .orange
        self.afternoonHalfColor = ThemeManager.loadColor(key: kAfternoonHalf) ?? Color(red: 1.0, green: 0.6, blue: 0.4)
        self.nightColor = ThemeManager.loadColor(key: kNight) ?? Color(red: 0.3, green: 0.3, blue: 1.0)
        self.holidayColor = ThemeManager.loadColor(key: kHoliday) ?? .green
    }
    
    // Función para obtener color según el tipo de turno
    func color(for type: ShiftType) -> Color {
        switch type {
        case .manana: return morningColor
        case .mediaManana: return morningHalfColor
        case .tarde: return afternoonColor
        case .mediaTarde: return afternoonHalfColor
        case .noche: return nightColor
        }
    }
    
    // Guardar colores
    func saveColors() {
        ThemeManager.saveColor(color: morningColor, key: kMorning)
        ThemeManager.saveColor(color: morningHalfColor, key: kMorningHalf)
        ThemeManager.saveColor(color: afternoonColor, key: kAfternoon)
        ThemeManager.saveColor(color: afternoonHalfColor, key: kAfternoonHalf)
        ThemeManager.saveColor(color: nightColor, key: kNight)
        ThemeManager.saveColor(color: holidayColor, key: kHoliday)
    }
    
    func resetDefaults() {
        morningColor = .yellow
        morningHalfColor = Color(red: 1.0, green: 0.9, blue: 0.6)
        afternoonColor = .orange
        afternoonHalfColor = Color(red: 1.0, green: 0.6, blue: 0.4)
        nightColor = Color(red: 0.3, green: 0.3, blue: 1.0)
        holidayColor = .green
        saveColors()
    }
    
    // --- Helpers de persistencia (Color -> String Hex) ---
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

// Extensiones para convertir Color <-> Hex String
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
