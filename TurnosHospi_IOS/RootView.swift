import SwiftUI

struct RootView: View {
    // Accedemos a los servicios inyectados
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var shiftRepository: ShiftRepository
    
    var body: some View {
        Group {
            if let user = authService.userSession {
                // Si hay usuario, vamos a la pantalla principal
                MainTabView()
                    .onAppear {
                        // Al entrar, empezamos a escuchar los datos de este usuario
                        shiftRepository.listenToUserShifts(userId: user.uid)
                        // Aquí asumimos un ID de planta fijo o guardado en el perfil del usuario.
                        // Para este ejemplo, usaremos "HospitalGeneral".
                        shiftRepository.listenToPlantRequests(plantId: "HospitalGeneral", currentUserId: user.uid)
                    }
            } else {
                // Si no hay usuario, mostramos el Login
                LoginView()
            }
        }
        .animation(.easeInOut, value: authService.userSession) // Transición suave al loguearse
    }
}
