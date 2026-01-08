import Foundation
import os.log

/// Logger para la aplicación - Solo imprime en DEBUG
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.shiftmanager"

    private static let authLog = OSLog(subsystem: subsystem, category: "Auth")
    private static let plantLog = OSLog(subsystem: subsystem, category: "Plant")
    private static let notificationLog = OSLog(subsystem: subsystem, category: "Notification")
    private static let generalLog = OSLog(subsystem: subsystem, category: "General")

    /// Log de autenticación
    static func auth(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: authLog, type: .debug, message)
        #endif
    }

    /// Log de plantas
    static func plant(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: plantLog, type: .debug, message)
        #endif
    }

    /// Log de notificaciones
    static func notification(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: notificationLog, type: .debug, message)
        #endif
    }

    /// Log general
    static func debug(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: generalLog, type: .debug, message)
        #endif
    }

    /// Log de error (siempre se registra para diagnóstico)
    static func error(_ message: String) {
        os_log("%{public}@", log: generalLog, type: .error, message)
    }
}
