import SwiftUI

// Enum para controlar las pantallas principales de navegación
enum AppScreen: Hashable {
    case mainMenu
    case createPlant
    case plantCreated
    case myPlant
    case plantDetail(Plant) // Pasamos el objeto Plant
    case settings
    case plantSettings(Plant)
    case directChatList
    // Los añadiremos en el siguiente paso:
    // case groupChat, shiftChange, shiftMarketplace, statistics
}

struct ContentView: View {
    // Estado de Autenticación (Simulado por ahora)
    @State private var isLoggedIn = false
    @State private var showRegistration = false
    @State private var currentUserEmail = ""
    
    // Estado de Navegación
    @State private var navigationPath = NavigationPath()
    
    // Datos Globales
    @State private var shiftColors = ShiftColors()
    @State private var userPlant: Plant? = nil // Aquí se cargaría la planta del usuario
    
    var body: some View {
        if !isLoggedIn {
            // --- FLUJO DE AUTENTICACIÓN ---
            ZStack {
                // Fondo Animado / Gradiente
                LinearGradient(colors: [Color(hex: "0B1021"), Color(hex: "0F172A")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                if showRegistration {
                    CreateAccountView(
                        onBack: { withAnimation { showRegistration = false } },
                        onCreate: { profile, password, completion in
                            // TODO: Conectar con Firebase Auth y Database
                            print("Registrando: \(profile.email)")
                            currentUserEmail = profile.email
                            completion(true)
                            withAnimation { isLoggedIn = true }
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else {
                    LoginView(
                        email: $currentUserEmail,
                        onLogin: { email, password, completion in
                            // TODO: Conectar con Firebase Auth
                            print("Login: \(email)")
                            completion(true)
                            withAnimation { isLoggedIn = true }
                        },
                        onCreateAccount: { withAnimation { showRegistration = true } },
                        onForgotPassword: { email, completion in
                            print("Reset password: \(email)")
                            completion(true)
                        }
                    )
                    .transition(.opacity)
                }
            }
        } else {
            // --- FLUJO PRINCIPAL (APP) ---
            NavigationStack(path: $navigationPath) {
                MainMenuView(
                    userEmail: currentUserEmail,
                    userProfile: nil, // Cargar perfil real
                    userPlant: userPlant,
                    shiftColors: shiftColors,
                    onSignOut: { withAnimation { isLoggedIn = false; navigationPath = NavigationPath() } },
                    onOpenSettings: { navigationPath.append(AppScreen.settings) },
                    onOpenDirectChats: { navigationPath.append(AppScreen.directChatList) },
                    onOpenPlant: {
                        if let plant = userPlant {
                            navigationPath.append(AppScreen.plantDetail(plant))
                        } else {
                            navigationPath.append(AppScreen.myPlant)
                        }
                    },
                    onCreatePlant: { navigationPath.append(AppScreen.createPlant) }
                )
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .createPlant:
                        Text("Pantalla Crear Planta (Pendiente)") // Placeholder
                    case .plantCreated:
                        Text("Planta Creada Exitosamente")
                    case .myPlant:
                        MyPlantView(
                            plant: userPlant,
                            onBack: { navigationPath.removeLast() },
                            onJoinPlant: { code, completion in
                                // Lógica de unirse
                                completion(true, nil)
                            }
                        )
                    case .plantDetail(let plant):
                        PlantDetailView(
                            plant: plant,
                            onBack: { navigationPath.removeLast() },
                            onOpenSettings: { navigationPath.append(AppScreen.plantSettings(plant)) }
                        )
                    case .settings:
                        SettingsView(
                            currentColors: $shiftColors,
                            onBack: { navigationPath.removeLast() },
                            onDeleteAccount: { isLoggedIn = false }
                        )
                    case .plantSettings(let plant):
                        Text("Configuración de Planta: \(plant.name)")
                    case .directChatList:
                        Text("Lista de Chats (Pendiente)")
                    default:
                        Text("Pantalla en construcción")
                    }
                }
            }
            .accentColor(.white) // Color de flecha de retorno global
        }
    }
}
