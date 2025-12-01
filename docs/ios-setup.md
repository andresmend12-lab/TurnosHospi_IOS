# Turnoshospi para iOS

Se añadió una implementación nativa en SwiftUI lista para abrirse en Xcode como proyecto de Swift Package Manager.

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
- Los datos son mockeados para reflejar flujos de turnos, ofertas, mensajería y alertas sin depender de Firebase.
- Para conectar servicios reales (auth, notificaciones push, etc.) sustituir los view models por integraciones con Firebase o el backend deseado.
