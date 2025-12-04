import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var shiftRepository: ShiftRepository
    
    // Selección de pestaña por defecto
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Pestaña 1: Mi Calendario
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendario")
                }
                .tag(0)
            
            // Pestaña 2: Solicitar Cambio
            ShiftChangeView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Cambiar")
                }
                .tag(1)
            
            // Pestaña 3: Bolsa de Turnos
            ShiftMarketplaceView()
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Bolsa")
                }
                .tag(2)
            
            // Pestaña 4: Ajustes y Perfil
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Perfil")
                }
                .tag(3)
        }
        // Cargar datos al aparecer la vista principal
        
        .accentColor(.blue) // Color de acento global para la app
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(ShiftRepository())
            .environmentObject(AuthService())
    }
}
