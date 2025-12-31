//
//  ErrorHandling.swift
//  TurnosHospi_IOS
//
//  Standardized error handling pattern for the application
//  Provides type-safe error handling with Result types
//

import Foundation
import SwiftUI

// MARK: - App Error Types

/// Main error enum for the application
/// Groups errors by category for better handling and user feedback
enum AppError: LocalizedError, Equatable {
    // Authentication Errors
    case authenticationFailed(reason: String)
    case userNotAuthenticated
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case accountDisabled

    // Network Errors
    case networkUnavailable
    case serverError(code: Int)
    case timeout
    case invalidResponse

    // Firebase/Database Errors
    case databaseReadFailed(path: String)
    case databaseWriteFailed(path: String)
    case permissionDenied
    case dataNotFound
    case invalidData(reason: String)

    // Validation Errors
    case validationFailed(field: String, reason: String)
    case invalidDateFormat
    case roleIncompatible
    case shiftConflict(reason: String)
    case workRuleViolation(reason: String)

    // Business Logic Errors
    case swapNotAllowed(reason: String)
    case coverageNotAvailable
    case alreadyHasShift
    case consecutiveDaysExceeded
    case nightShiftRestRequired

    // General Errors
    case unknown(message: String)
    case operationCancelled

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        // Auth
        case .authenticationFailed(let reason):
            return "Error de autenticación: \(reason)"
        case .userNotAuthenticated:
            return "Debes iniciar sesión para continuar"
        case .invalidCredentials:
            return "Email o contraseña incorrectos"
        case .emailAlreadyInUse:
            return "Este email ya está registrado"
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres"
        case .accountDisabled:
            return "Esta cuenta ha sido deshabilitada"

        // Network
        case .networkUnavailable:
            return "Sin conexión a internet. Verifica tu conexión e intenta de nuevo."
        case .serverError(let code):
            return "Error del servidor (código \(code)). Intenta más tarde."
        case .timeout:
            return "La operación tardó demasiado. Intenta de nuevo."
        case .invalidResponse:
            return "Respuesta inválida del servidor"

        // Database
        case .databaseReadFailed(let path):
            return "Error al leer datos: \(path)"
        case .databaseWriteFailed(let path):
            return "Error al guardar datos: \(path)"
        case .permissionDenied:
            return "No tienes permisos para realizar esta acción"
        case .dataNotFound:
            return "No se encontraron los datos solicitados"
        case .invalidData(let reason):
            return "Datos inválidos: \(reason)"

        // Validation
        case .validationFailed(let field, let reason):
            return "\(field): \(reason)"
        case .invalidDateFormat:
            return "Formato de fecha inválido"
        case .roleIncompatible:
            return "Los roles no son compatibles para este intercambio"
        case .shiftConflict(let reason):
            return "Conflicto de turno: \(reason)"
        case .workRuleViolation(let reason):
            return reason

        // Business Logic
        case .swapNotAllowed(let reason):
            return "Intercambio no permitido: \(reason)"
        case .coverageNotAvailable:
            return "No hay cobertura disponible para este turno"
        case .alreadyHasShift:
            return "Ya tienes un turno asignado en esta fecha"
        case .consecutiveDaysExceeded:
            return "Superarías el límite de 6 días seguidos de trabajo"
        case .nightShiftRestRequired:
            return "Después de una noche debes descansar (Saliente)"

        // General
        case .unknown(let message):
            return message.isEmpty ? "Ha ocurrido un error inesperado" : message
        case .operationCancelled:
            return "Operación cancelada"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Activa los datos móviles o conéctate a una red WiFi"
        case .timeout:
            return "Verifica tu conexión y vuelve a intentar"
        case .invalidCredentials:
            return "Revisa tu email y contraseña"
        case .permissionDenied:
            return "Contacta con tu supervisor si crees que deberías tener acceso"
        case .consecutiveDaysExceeded, .nightShiftRestRequired:
            return "Selecciona otra fecha que cumpla con la normativa laboral"
        default:
            return nil
        }
    }

    // MARK: - Error Category

    enum Category {
        case authentication
        case network
        case database
        case validation
        case businessLogic
        case general
    }

    var category: Category {
        switch self {
        case .authenticationFailed, .userNotAuthenticated, .invalidCredentials,
             .emailAlreadyInUse, .weakPassword, .accountDisabled:
            return .authentication
        case .networkUnavailable, .serverError, .timeout, .invalidResponse:
            return .network
        case .databaseReadFailed, .databaseWriteFailed, .permissionDenied,
             .dataNotFound, .invalidData:
            return .database
        case .validationFailed, .invalidDateFormat, .roleIncompatible,
             .shiftConflict, .workRuleViolation:
            return .validation
        case .swapNotAllowed, .coverageNotAvailable, .alreadyHasShift,
             .consecutiveDaysExceeded, .nightShiftRestRequired:
            return .businessLogic
        case .unknown, .operationCancelled:
            return .general
        }
    }

    /// Whether this error should be logged for debugging
    var shouldLog: Bool {
        switch self {
        case .operationCancelled:
            return false
        default:
            return true
        }
    }

    /// Whether this error is recoverable (user can retry)
    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .timeout, .serverError:
            return true
        case .operationCancelled:
            return false
        default:
            return false
        }
    }
}

// MARK: - Result Type Extensions

/// Type alias for common result patterns
typealias AppResult<T> = Result<T, AppError>
typealias VoidResult = Result<Void, AppError>

extension Result where Failure == AppError {

    /// Map Firebase/String errors to AppError
    static func from(error: Error?, path: String = "") -> VoidResult {
        if let error = error {
            return .failure(AppError.from(error, path: path))
        }
        return .success(())
    }

    /// Check if result is successful
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    /// Get the error if failed
    var error: AppError? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }

    /// Get the success value or nil
    var successValue: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
}

// MARK: - Error Conversion

extension AppError {

    /// Convert generic Error to AppError
    static func from(_ error: Error, path: String = "") -> AppError {
        let nsError = error as NSError

        // Firebase Auth errors
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17008: return .invalidCredentials
            case 17009: return .invalidCredentials
            case 17007: return .emailAlreadyInUse
            case 17026: return .weakPassword
            case 17005: return .accountDisabled
            case 17020: return .networkUnavailable
            default: return .authenticationFailed(reason: error.localizedDescription)
            }
        }

        // Firebase Database errors
        if nsError.domain == "com.firebase.database" {
            switch nsError.code {
            case -3: return .permissionDenied
            case -24: return .networkUnavailable
            default:
                if path.isEmpty {
                    return .unknown(message: error.localizedDescription)
                }
                return .databaseReadFailed(path: path)
            }
        }

        // URL/Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCancelled:
                return .operationCancelled
            default:
                return .networkUnavailable
            }
        }

        return .unknown(message: error.localizedDescription)
    }
}

// MARK: - Async/Await Support

extension AppError {

    /// Wrap a throwing async operation with AppError handling
    static func wrap<T>(_ operation: () async throws -> T) async -> AppResult<T> {
        do {
            let result = try await operation()
            return .success(result)
        } catch let error as AppError {
            return .failure(error)
        } catch {
            return .failure(.from(error))
        }
    }
}

// MARK: - Error Logging

struct ErrorLogger {

    static func log(_ error: AppError, context: String = "", file: String = #file, line: Int = #line) {
        guard error.shouldLog else { return }

        let fileName = (file as NSString).lastPathComponent
        let categoryEmoji: String

        switch error.category {
        case .authentication: categoryEmoji = "🔐"
        case .network: categoryEmoji = "🌐"
        case .database: categoryEmoji = "💾"
        case .validation: categoryEmoji = "⚠️"
        case .businessLogic: categoryEmoji = "📋"
        case .general: categoryEmoji = "❌"
        }

        let contextInfo = context.isEmpty ? "" : " [\(context)]"
        print("\(categoryEmoji) ERROR\(contextInfo) at \(fileName):\(line) - \(error.localizedDescription)")

        if let suggestion = error.recoverySuggestion {
            print("   💡 Suggestion: \(suggestion)")
        }
    }
}

// MARK: - SwiftUI Alert Support

extension AppError {

    /// Create an alert from this error
    var alertTitle: String {
        switch category {
        case .authentication: return "Error de Autenticación"
        case .network: return "Error de Conexión"
        case .database: return "Error de Datos"
        case .validation: return "Datos Inválidos"
        case .businessLogic: return "Acción No Permitida"
        case .general: return "Error"
        }
    }

    /// Icon for displaying in UI
    var icon: String {
        switch category {
        case .authentication: return "lock.shield.fill"
        case .network: return "wifi.slash"
        case .database: return "externaldrive.badge.exclamationmark"
        case .validation: return "exclamationmark.triangle.fill"
        case .businessLogic: return "hand.raised.fill"
        case .general: return "xmark.circle.fill"
        }
    }

    /// Color for displaying in UI
    var color: Color {
        switch category {
        case .authentication: return .orange
        case .network: return .gray
        case .database: return .purple
        case .validation: return .yellow
        case .businessLogic: return .red
        case .general: return .red
        }
    }
}

// MARK: - Error Alert View Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                error?.alertTitle ?? "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil; onDismiss?() } }
                ),
                actions: {
                    Button("Aceptar", role: .cancel) {
                        error = nil
                        onDismiss?()
                    }

                    if let error = error, error.isRecoverable {
                        Button("Reintentar") {
                            self.error = nil
                            // Caller should handle retry
                        }
                    }
                },
                message: {
                    if let error = error {
                        VStack {
                            Text(error.localizedDescription)
                            if let suggestion = error.recoverySuggestion {
                                Text(suggestion)
                                    .font(.caption)
                            }
                        }
                    }
                }
            )
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onDismiss: onDismiss))
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let error: AppError
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .foregroundColor(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.alertTitle)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title2)
            }
        }
        .padding()
        .background(error.color.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Loading State with Error

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(AppError)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: AppError? {
        if case .failure(let error) = self { return error }
        return nil
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
