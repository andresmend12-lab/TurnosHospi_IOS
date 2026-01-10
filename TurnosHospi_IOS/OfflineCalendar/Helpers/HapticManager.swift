import UIKit

// MARK: - Gestor de Haptic Feedback

enum HapticManager {

    /// Feedback ligero para selección
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Feedback de impacto para acciones
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    /// Feedback de notificación
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Feedback para asignación de turno
    static func shiftAssigned() {
        impact(.light)
    }

    /// Feedback para eliminación
    static func deleted() {
        notification(.warning)
    }

    /// Feedback para guardado exitoso
    static func success() {
        notification(.success)
    }

    /// Feedback para error
    static func error() {
        notification(.error)
    }

    /// Feedback para advertencia
    static func warning() {
        notification(.warning)
    }
}
