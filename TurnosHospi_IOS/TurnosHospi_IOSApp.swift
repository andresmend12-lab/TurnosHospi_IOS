import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct TurnosHospi_IOSApp: App {
    // Inicializamos el gestor de autenticación para toda la app
    @StateObject var authManager = AuthManager()
    @StateObject var themeManager = ThemeManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Configuramos Firebase al arrancar
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager) // Pasamos el gestor a las vistas hijas
                .environmentObject(themeManager)
        }
    }
}
