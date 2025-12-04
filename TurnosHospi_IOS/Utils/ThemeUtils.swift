import SwiftUI

// Estructura para gestionar los colores de los turnos (igual que en Android)
struct ShiftColors {
    var morning: Color = Color(hex: "4CAF50")      // Verde
    var morningHalf: Color = Color(hex: "8BC34A")  // Verde claro
    var afternoon: Color = Color(hex: "FF9800")    // Naranja
    var afternoonHalf: Color = Color(hex: "FFC107")// Ámbar
    var night: Color = Color(hex: "F44336")        // Rojo
    var saliente: Color = Color(hex: "9E9E9E")     // Gris
    var free: Color = Color.clear                  // Transparente/Borde
    var holiday: Color = Color(hex: "9C27B0")      // Púrpura
}

// Extensión para usar Hex Colors en SwiftUI
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
}

// Modificador para campos de texto con estilo "Outlined" similar a Android
struct OutlinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}
