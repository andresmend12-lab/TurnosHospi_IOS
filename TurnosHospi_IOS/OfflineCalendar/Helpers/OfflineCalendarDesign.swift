import SwiftUI

// MARK: - Sistema de Diseño para Calendario Offline

/// Constantes de diseño centralizadas
enum OfflineCalendarDesign {

    // MARK: - Colores
    enum Colors {
        static let background = Color(hex: "0F172A")
        static let cardBackground = Color(hex: "1E293B")
        static let cardBackgroundLight = Color(hex: "334155")
        static let accent = Color(hex: "54C7EC")
        static let accentSecondary = Color(hex: "38BDF8")

        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "94A3B8")
        static let textMuted = Color(hex: "64748B")

        static let success = Color(hex: "22C55E")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")
        static let noteIndicator = Color(hex: "E91E63")

        // Colores de turnos por defecto
        static let shiftMorning = Color(hex: "66BB6A")
        static let shiftAfternoon = Color(hex: "FF7043")
        static let shiftNight = Color(hex: "5C6BC0")
        static let shiftSaliente = Color(hex: "4CAF50")
        static let shiftVacation = Color(hex: "EF5350")
        static let shiftFree = Color(hex: "334155")
        static let shiftHalfMorning = Color(hex: "66BB6A")
        static let shiftHalfAfternoon = Color(hex: "FFA726")
    }

    // MARK: - Espaciados
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Radios de esquina
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 50
    }

    // MARK: - Tamaños
    enum Sizes {
        static let dayCell: CGFloat = 40
        static let dayCellLarge: CGFloat = 48
        static let noteIndicator: CGFloat = 8
        static let fabButton: CGFloat = 56
        static let chipHeight: CGFloat = 36
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
    }

    // MARK: - Fuentes
    enum Fonts {
        static let caption = Font.system(size: 10, weight: .medium)
        static let captionLarge = Font.system(size: 12, weight: .medium)
        static let body = Font.system(size: 14, weight: .regular)
        static let bodyBold = Font.system(size: 14, weight: .semibold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let title = Font.system(size: 18, weight: .bold)
        static let largeTitle = Font.system(size: 24, weight: .bold)
        static let statsNumber = Font.system(size: 42, weight: .bold)
    }

    // MARK: - Sombras
    enum Shadows {
        static let light = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let heavy = Color.black.opacity(0.3)
    }

    // MARK: - Animaciones
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
}

// MARK: - Alias para acceso rápido
typealias Design = OfflineCalendarDesign
typealias DesignColors = OfflineCalendarDesign.Colors
typealias DesignSpacing = OfflineCalendarDesign.Spacing
typealias DesignCornerRadius = OfflineCalendarDesign.CornerRadius
typealias DesignSizes = OfflineCalendarDesign.Sizes
typealias DesignFonts = OfflineCalendarDesign.Fonts
typealias DesignShadows = OfflineCalendarDesign.Shadows
