import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// 1. AppDelegate para manejar el ciclo de vida de las notificaciones
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configurar Firebase
        FirebaseApp.configure()
        
        // Configurar delegados de mensajería y notificaciones
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        // Solicitar permisos al usuario (Alerta, Globo, Sonido)
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Error solicitando permisos de notificación: \(error)")
                }
                print("Permiso de notificaciones: \(granted)")
            }
        )
        
        // Registrarse para notificaciones remotas en APNs
        DispatchQueue.main.async {
            application.registerForRemoteNotifications()
        }
        
        return true
    }
    
    // MARK: - MessagingDelegate (Recibir Token FCM)
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Este método se llama cada vez que el token se genera o actualiza
        print("FCM Token recibido: \(fcmToken ?? "Nulo")")
        
        if let token = fcmToken {
            // IMPORTANTE: Asegurar que la actualización del token ocurra en el hilo principal
            DispatchQueue.main.async {
                AuthManager.shared.updateFcmToken(token)
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate (Notificaciones en primer plano)
    
    // Esto permite que las notificaciones se muestren (banner/sonido) incluso con la app abierta
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // iOS 14+ usa [.banner, .badge, .sound]
        // iOS 13 y anteriores usan [.alert, .badge, .sound]
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    // Manejar cuando el usuario toca la notificación
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Aquí puedes procesar datos adicionales de la notificación
        print("Usuario tocó la notificación: \(userInfo)")
        
        completionHandler()
    }
}

@main
struct TurnosHospi_IOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Usamos la instancia compartida (Singleton) para que AppDelegate pueda acceder a ella
    @StateObject var authManager = AuthManager.shared
    @StateObject var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        }
    }
}
