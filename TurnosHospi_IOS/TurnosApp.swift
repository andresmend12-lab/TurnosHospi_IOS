import SwiftUI

@main
struct TurnosApp: App {
    // 1. Inicializamos los objetos de estado globales.
    // Usamos @StateObject para que la App sea la "dueña" de estos datos.
    @StateObject private var authService = AuthService()
    @StateObject private var shiftRepository = ShiftRepository()
    
    var body: some Scene {
        WindowGroup {
            // 2. Lógica de enrutamiento raíz
            Group {
                if authService.isAuthenticated {
                    // Si el usuario está logueado, vamos a la app principal
                    MainTabView()
                } else {
                    // Si no, mostramos el Login
                    LoginView()
                }
            }
            // 3. Inyectamos los servicios en el entorno (Environment)
            // para que cualquier vista hija pueda acceder a ellos.
            .environmentObject(authService)
            .environmentObject(shiftRepository)
        }
    }
}
