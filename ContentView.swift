import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.user != nil {
                // Si el usuario está autenticado, vamos al Menú Principal
                MainMenuView()
            } else {
                // Si no, mostramos la pantalla de Login
                LoginView()
            }
        }
    }
}
