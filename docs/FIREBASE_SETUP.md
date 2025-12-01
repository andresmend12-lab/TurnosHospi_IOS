# Configuración detallada de Firebase para TurnosHospi

Sigue estos pasos en la consola de Firebase antes de probar el registro o el inicio de sesión en la app.

## 1. Proyecto y archivo de configuración
1. En la consola de Firebase, abre el proyecto **Turnoshospi (turnoshospi-f4870)**.
2. Descarga el archivo **`google-services.json`** desde *Configuración del proyecto ▸ Tus apps ▸ TurnosHospi (Android)*.
3. Coloca `google-services.json` dentro del módulo `app/` y sincroniza Gradle.

## 2. Huellas SHA y builds
1. En *Configuración del proyecto ▸ Tus apps ▸ TurnosHospi*, añade las huellas **SHA-1 y SHA-256** de tus builds (debug y release) para que la autenticación funcione.
2. Si generas nuevas claves, vuelve a agregar las huellas y descarga de nuevo `google-services.json`.

## 3. Authentication (correo y contraseña)
1. Ve a **Authentication ▸ Métodos de inicio de sesión**.
2. Activa **Email/Password (Correo/Contraseña)** y guarda los cambios.
3. Si aparece `ERROR_OPERATION_NOT_ALLOWED` o mensajes de proveedor deshabilitado, verifica que el proveedor siga habilitado.

## 4. Firestore
1. Abre **Firestore Database ▸ Reglas**.
2. Para pruebas, usa reglas que permitan a usuarios autenticados leer/escribir:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
3. Publica las reglas. Ajusta a reglas más estrictas antes de producción.

## 5. Realtime Database
1. Abre **Realtime Database ▸ Reglas**.
2. Asegúrate de tener la URL `https://turnoshospi-f4870-default-rtdb.firebaseio.com/`.
3. Las reglas deben ir dentro de un objeto raíz `{"rules": { ... }}`. Por ejemplo, para permitir lectura/escritura sólo al dueño de cada nodo en `/users/{uid}`:
   ```json
   {
     "rules": {
       "users": {
         "$uid": {
           ".read": "$uid === auth.uid",
           ".write": "$uid === auth.uid"
         }
       }
     }
   }
   ```
   Si necesitas una prueba rápida con reglas totalmente abiertas, la consola acepta el formato compacto `{"rules": {".read": true, ".write": true}}`, pero recuerda revertirlo para no exponer datos.
4. Publica las reglas. Revisa el panel de *Usage* si aparecen errores de límite.

## 6. Conectividad y dispositivo
1. Usa un dispositivo/emulador con fecha y hora correctas y conexión a Internet.
2. Si usas emulador de Google Play, inicia sesión en Google Play Services si se solicita.

## 7. Depuración de errores comunes en la app
- **"No se pudo crear la cuenta"**: suele indicar proveedor de Email/Contraseña deshabilitado o correo ya registrado.
- **"Revisa las reglas de Realtime Database y los permisos de escritura"**: verifica las reglas del paso 5.
- **"Debes iniciar sesión para continuar"**: inicia sesión nuevamente; la sesión puede haber expirado.
- Revisa **Logcat** para detalles de `FirebaseAuthException` y `DatabaseException`.

Con estos pasos completados, la app podrá crear cuentas, guardar perfiles en Firestore y sincronizar `/users/{uid}` en Realtime Database.
