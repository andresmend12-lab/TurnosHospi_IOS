# TurnosHospi iOS

Aplicación iOS para gestión de turnos hospitalarios.

## Requisitos

- Xcode 15.0+
- iOS 17.0+
- Cuenta de Firebase

## Configuración del Proyecto

### 1. Configuración de Firebase

Este proyecto utiliza Firebase para autenticación y base de datos en tiempo real. El archivo de configuración `GoogleService-Info.plist` contiene claves sensibles y **no está incluido en el repositorio** por seguridad.

#### Pasos para configurar Firebase:

1. **Accede a la consola de Firebase**
   - Ve a [Firebase Console](https://console.firebase.google.com/)
   - Selecciona tu proyecto o crea uno nuevo

2. **Registra la aplicación iOS**
   - En la configuración del proyecto, haz clic en "Agregar app" > iOS
   - Ingresa el Bundle ID de la aplicación
   - Descarga el archivo `GoogleService-Info.plist`

3. **Añade el archivo al proyecto**
   - Copia el archivo `GoogleService-Info.plist` descargado a la raíz del proyecto
   - En Xcode, arrastra el archivo al navegador del proyecto
   - Asegúrate de marcar "Copy items if needed" y seleccionar el target correcto

4. **Verifica la configuración**
   - El archivo debe estar en la raíz del proyecto junto a `GoogleService-Info.plist.example`
   - Compila el proyecto para verificar que Firebase se inicializa correctamente

#### Estructura del archivo de configuración

Consulta `GoogleService-Info.plist.example` como referencia de la estructura requerida. Los valores que debes obtener de Firebase Console son:

| Clave | Descripción |
|-------|-------------|
| `API_KEY` | Clave de API de Firebase |
| `GCM_SENDER_ID` | ID del remitente para Cloud Messaging |
| `BUNDLE_ID` | Bundle identifier de tu app |
| `PROJECT_ID` | ID del proyecto en Firebase |
| `GOOGLE_APP_ID` | ID de la aplicación en Firebase |
| `DATABASE_URL` | URL de Realtime Database |

### 2. Instalación de Dependencias

#### Con Swift Package Manager (recomendado)

Las dependencias se resuelven automáticamente al abrir el proyecto en Xcode.

#### Con CocoaPods

```bash
pod install
```

Luego abre el archivo `.xcworkspace` en lugar del `.xcodeproj`.

## Compilación

1. Abre `TurnosHospi.xcodeproj` (o `.xcworkspace` si usas CocoaPods)
2. Selecciona el simulador o dispositivo destino
3. Presiona `Cmd + R` para compilar y ejecutar

### 3. Configuración de Firebase Functions (Opcional pero recomendado)

Las Firebase Cloud Functions son necesarias para las notificaciones push y validaciones del lado del servidor.

#### Instalación de Functions:

1. **Instalar dependencias**
   ```bash
   cd functions
   npm install
   ```

2. **Desplegar a Firebase**
   ```bash
   npm run deploy
   ```

Para más información, consulta `functions/README.md`.

## Seguridad

- **NUNCA** subas `GoogleService-Info.plist` al repositorio
- El archivo está incluido en `.gitignore` para prevenir commits accidentales
- Usa `GoogleService-Info.plist.example` como plantilla de referencia
- Las Firebase Functions implementan validación del lado del servidor para prevenir modificaciones no autorizadas
