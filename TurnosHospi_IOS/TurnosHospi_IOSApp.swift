import SwiftUI
import FirebaseCore
import FirebaseMessaging // Añadido para gestionar notificaciones si las usas

// 1. Creamos un AppDelegate para inicializar Firebase lo antes posible
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configuración segura de Firebase
        FirebaseApp.configure()
        return true
    }
}

@main
struct TurnosHospi_IOSApp: App {
    // 2. Conectamos el AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // AuthManager se iniciará DESPUÉS de que el AppDelegate configure Firebase
    @StateObject var authManager = AuthManager()
    @StateObject var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
}
