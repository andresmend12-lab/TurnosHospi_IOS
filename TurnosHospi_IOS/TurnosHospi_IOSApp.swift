import SwiftUI
import FirebaseCore

@main
struct TurnosHospi_IOSApp: App {
    // Inicializamos el gestor de autenticación para toda la app
    @StateObject var authManager = AuthManager()
    @StateObject var themeManager = ThemeManager()
    
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
