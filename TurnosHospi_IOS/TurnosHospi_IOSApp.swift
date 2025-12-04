import SwiftUI
import FirebaseCore

// 1. Configurador de AppDelegate para inicializar Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct TurnosHospi_IOSApp: App {
    // 2. Conectar el AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 3. Crear las instancias únicas de nuestros servicios
    @StateObject var authService = AuthService()
    @StateObject var shiftRepository = ShiftRepository()
    
    var body: some Scene {
        WindowGroup {
            // 4. Lógica de enrutamiento raíz
            // Usamos RootView para decidir si mostrar Login o Main
            RootView()
                .environmentObject(authService)
                .environmentObject(shiftRepository)
        }
    }
}
