import SwiftUI
import FirebaseCore
import FirebaseMessaging

// 1. Mantenemos el AppDelegate para notificaciones u otras configuraciones futuras,
// pero QUITAMOS la configuración de Firebase de aquí.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // FirebaseApp.configure() -> SE HA MOVIDO AL INIT DE LA APP
        return true
    }
}

@main
struct TurnosHospi_IOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 2. Quitamos la inicialización directa (= AuthManager())
    @StateObject var authManager: AuthManager
    
    // ThemeManager no depende de Firebase, puede quedarse igual
    @StateObject var themeManager = ThemeManager()
    
    // 3. Usamos el init para garantizar el orden de ejecución
    init() {
        // A) Configurar Firebase antes que nada
        FirebaseApp.configure()
        
        // B) Inicializar AuthManager ahora que Firebase ya está listo
        _authManager = StateObject(wrappedValue: AuthManager())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
}
