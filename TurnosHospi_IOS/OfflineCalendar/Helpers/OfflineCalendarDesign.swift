import SwiftUI

// MARK: - Sistema de Diseño del Calendario Offline

enum OfflineCalendarDesign {

    // MARK: - Colores
    enum Colors {
        // Fondos
        static let background = Color(hex: "0F172A")
        static let backgroundElevated = Color(hex: "131C2E")
        static let cardBackground = Color(hex: "1E293B")
        static let cardBackgroundLight = Color(hex: "334155")

        // Acentos
        static let accent = Color(hex: "54C7EC")
        static let accentSecondary = Color(hex: "A78BFA")

        // Texto
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "94A3B8")
        static let textTertiary = Color(hex: "64748B")

        // Estados
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")

        // Turnos (fallback sin ThemeManager)
        static let morning = Color(hex: "FBBF24")      // Amarillo/Oro
        static let afternoon = Color(hex: "F97316")    // Naranja
        static let night = Color(hex: "6366F1")        // Índigo/Púrpura
        static let saliente = Color(hex: "22D3EE")     // Cyan

        // Colores de turnos heredados (compatibilidad)
        static let shiftMorning = Color(hex: "66BB6A")
        static let shiftAfternoon = Color(hex: "FF7043")
        static let shiftNight = Color(hex: "5C6BC0")
        static let shiftSaliente = Color(hex: "4CAF50")
        static let shiftVacation = Color(hex: "EF5350")
        static let shiftFree = Color(hex: "334155")
        static let shiftHalfMorning = Color(hex: "66BB6A")
        static let shiftHalfAfternoon = Color(hex: "FFA726")

        // Indicadores
        static let todayRing = Color(hex: "54C7EC")
        static let noteIndicator = Color(hex: "FCD34D")
        static let halfDayIndicator = Color(hex: "A78BFA")

        // Bordes y separadores
        static let border = Color(hex: "334155")
        static let separator = Color(hex: "1E293B")

        // Glassmorphism
        static let glassBackground = Color.white.opacity(0.05)
        static let glassBorder = Color.white.opacity(0.1)
    }

    // MARK: - Gradientes
    enum Gradients {
        static let backgroundMain = LinearGradient(
            colors: [Colors.background, Colors.backgroundElevated],
            startPoint: .top,
            endPoint: .bottom
        )

        static let cardElevated = LinearGradient(
            colors: [Colors.cardBackground, Colors.cardBackground.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGlow = LinearGradient(
            colors: [Colors.accent, Colors.accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let morningGradient = LinearGradient(
            colors: [Colors.morning, Colors.morning.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let afternoonGradient = LinearGradient(
            colors: [Colors.afternoon, Colors.afternoon.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let nightGradient = LinearGradient(
            colors: [Colors.night, Colors.night.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let salienteGradient = LinearGradient(
            colors: [Colors.saliente, Colors.saliente.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let successGradient = LinearGradient(
            colors: [Colors.success, Colors.success.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let tabBarBackground = LinearGradient(
            colors: [Colors.cardBackground, Colors.cardBackground.opacity(0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Espaciado
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Radio de Esquinas
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 50
        static let circle: CGFloat = 100
    }

    // MARK: - Tamaños
    enum Sizes {
        static let dayCell: CGFloat = 44
        static let dayCellCompact: CGFloat = 38
        static let dayCellLarge: CGFloat = 48
        static let noteIndicator: CGFloat = 6
        static let noteIndicatorLarge: CGFloat = 8
        static let halfDayIndicator: CGFloat = 5
        static let todayRing: CGFloat = 3
        static let todayRingOuter: CGFloat = 4
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let tabBarHeight: CGFloat = 70
        static let tabBarIcon: CGFloat = 26
        static let tabBarIconSelected: CGFloat = 28
        static let chipHeight: CGFloat = 36
        static let buttonHeight: CGFloat = 50
        static let cardMinHeight: CGFloat = 100
        static let legendExpandedHeight: CGFloat = 120
        static let legendCollapsedHeight: CGFloat = 60
        static let fabButton: CGFloat = 56
    }

    // MARK: - Fuentes
    enum Fonts {
        static let title = Font.system(size: 22, weight: .bold)
        static let titleLarge = Font.system(size: 28, weight: .bold)
        static let largeTitle = Font.system(size: 24, weight: .bold)
        static let headline = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let bodyBold = Font.system(size: 14, weight: .semibold)
        static let caption = Font.system(size: 12, weight: .regular)
        static let captionMedium = Font.system(size: 12, weight: .medium)
        static let captionBold = Font.system(size: 12, weight: .bold)
        static let captionLarge = Font.system(size: 12, weight: .medium)
        static let dayNumber = Font.system(size: 15, weight: .semibold)
        static let dayNumberLarge = Font.system(size: 17, weight: .bold)
        static let statValue = Font.system(size: 32, weight: .bold)
        static let statLabel = Font.system(size: 13, weight: .medium)
        static let tabLabel = Font.system(size: 11, weight: .medium)
        static let statsNumber = Font.system(size: 42, weight: .bold)
    }

    // MARK: - Sombras
    enum Shadows {
        static let light = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let heavy = Color.black.opacity(0.35)
        static let colored = Colors.accent.opacity(0.3)
        static let glow = Colors.accent.opacity(0.4)

        // Configuraciones de sombra
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowY: CGFloat = 4
        static let buttonShadowRadius: CGFloat = 12
        static let buttonShadowY: CGFloat = 6
        static let glowRadius: CGFloat = 15
    }

    // MARK: - Animaciones
    enum Animation {
        static let quick: SwiftUI.Animation = .easeOut(duration: 0.15)
        static let fast: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let normal: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let smooth: SwiftUI.Animation = .easeInOut(duration: 0.35)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.4)
        static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.7)
        static let springBouncy: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.6)
        static let springGentle: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.8)

        // Duraciones
        static let durationQuick: Double = 0.15
        static let durationStandard: Double = 0.25
        static let durationSmooth: Double = 0.35
    }

    // MARK: - Opacidades
    enum Opacity {
        static let disabled: Double = 0.5
        static let subtle: Double = 0.3
        static let medium: Double = 0.6
        static let high: Double = 0.8
        static let pressed: Double = 0.7
    }
}

// MARK: - Type Aliases para acceso rápido

typealias Design = OfflineCalendarDesign
typealias DesignColors = OfflineCalendarDesign.Colors
typealias DesignGradients = OfflineCalendarDesign.Gradients
typealias DesignSpacing = OfflineCalendarDesign.Spacing
typealias DesignCornerRadius = OfflineCalendarDesign.CornerRadius
typealias DesignSizes = OfflineCalendarDesign.Sizes
typealias DesignFonts = OfflineCalendarDesign.Fonts
typealias DesignShadows = OfflineCalendarDesign.Shadows
typealias DesignAnimation = OfflineCalendarDesign.Animation
typealias DesignOpacity = OfflineCalendarDesign.Opacity

// Aliases cortos
typealias DC = OfflineCalendarDesign.Colors
typealias DG = OfflineCalendarDesign.Gradients
typealias DS = OfflineCalendarDesign.Spacing
typealias DR = OfflineCalendarDesign.CornerRadius
typealias DSizes = OfflineCalendarDesign.Sizes
typealias DF = OfflineCalendarDesign.Fonts
typealias DShadows = OfflineCalendarDesign.Shadows
typealias DAnim = OfflineCalendarDesign.Animation
