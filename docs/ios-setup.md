# Turnoshospi para iOS

Se añadió una implementación nativa en SwiftUI lista para abrirse en Xcode como proyecto de Swift Package Manager y conectada a Firebase (Auth, Realtime Database y Cloud Messaging) para mantener la paridad funcional con Android.

## Abrir en Xcode
1. Abrir Xcode 15 o superior.
2. Menú **File > Open** y seleccionar la carpeta `ios` de este repositorio.
3. Elegir el esquema **Turnoshospi** y un destino iOS (simulador o dispositivo).
4. Ejecutar con **⌘R**.

## Estructura
- `Package.swift`: declara el producto `iOSApplication` con ícono, permisos y recursos.
- `Sources/TurnoshospiIOS`: modelo, view models y vistas SwiftUI que replican las pantallas principales de Android (login, turnos, marketplace, chat, notificaciones y perfil).
- `Resources/Assets.xcassets`: placeholder de ícono y colores.
- `Resources/LaunchScreen.storyboard`: pantalla de lanzamiento con el ícono.

## Notas
- Incluye integración con Firebase para autenticación por correo, consultas a Realtime Database (`users`, `plants`, `user_notifications`, `userPlants/<uid>/shifts`) y registro de tokens FCM en `users/<uid>/fcmToken`.
- Reemplaza `ios/Resources/GoogleService-Info.plist` con el archivo real generado desde la consola de Firebase para el bundle `com.example.turnoshospi`.
- Habilita notificaciones push en el proyecto (Signing & Capabilities) y valida que el esquema tenga los permisos de notificaciones ya declarados en `Package.swift`.
- Los view models activan listeners en tiempo real tras el login; para probar sin backend se puede usar el `Plant.demo` y los turnos de ejemplo.
