import SwiftUI

struct RootView: View {
    // Accedemos a los servicios inyectados
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var shiftRepository: ShiftRepository
    
    var body: some View {
        Group {
            // CORREGIDO: Usamos currentUser en lugar de userSession
            if let user = authService.currentUser {
                // Si hay usuario, vamos a la pantalla principal
                MainTabView()
                    .onAppear {
                        // Al entrar, empezamos a escuchar los datos de este usuario
                        shiftRepository.listenToUserShifts(userId: user.id)
                        // Para este ejemplo, usaremos "HospitalGeneral".
                        shiftRepository.listenToPlantRequests(plantId: "HospitalGeneral", currentUserId: user.id)
                    }
            } else {
                // Si no hay usuario, mostramos el Login
                LoginView()
            }
        }
        // CORREGIDO: Animamos en base a si hay usuario o no (Equatable)
        .animation(.easeInOut, value: authService.currentUser != nil)
    }
}
