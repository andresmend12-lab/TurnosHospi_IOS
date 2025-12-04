import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 1. Pestaña Principal (La nueva que acabamos de crear)
            HomeScreen()
                .tabItem {
                    Label("Principal", systemImage: "house.fill")
                }
            
            // 2. Otras pestañas (Mercado, Estadísticas, etc.)
            Text("Mercado") // Tu vista de MarketView
                .tabItem {
                    Label("Mercado", systemImage: "cart")
                }
                
            Text("Estadísticas") // Tu vista de StatisticsView
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar")
                }
        }
    }
}
