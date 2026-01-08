# Firebase Cloud Functions - TurnosHospi iOS

Este directorio contiene las Firebase Cloud Functions necesarias para el backend de la aplicación TurnosHospi iOS.

## Funciones Implementadas

### 1. `sendNotification`
**Motor central de notificaciones push**
- **Trigger**: `/user_notifications/{userId}/{notificationId}` onCreate
- **Función**: Envía notificaciones push FCM cuando se crea una nueva notificación en la base de datos
- **Soporte**: iOS (APNs) y Android

### 2. `sendChatNotification`
**Notificaciones de mensajes de chat**
- **Trigger**: `/plants/{plantId}/direct_chats/{chatId}/messages/{messageId}` onCreate
- **Función**: Envía notificaciones de mensajes directos y actualiza contadores de no leídos
- **Características**: Agrupación de notificaciones por chatId

### 3. `notifySupervisorOnPending`
**Notificaciones de aprobación de turno**
- **Trigger**: `/plants/{plantId}/shift_requests/{requestId}` onUpdate
- **Función**: Notifica a supervisores cuando un cambio de turno requiere aprobación
- **Estados**: AWAITING_SUPERVISOR

### 4. `notifyUsersOnStatusChange`
**Notificaciones de cambios de estado**
- **Trigger**: `/plants/{plantId}/shift_requests/{requestId}` onUpdate
- **Función**: Notifica a usuarios cuando se aprueba o rechaza un cambio de turno
- **Estados**: APPROVED, REJECTED

### 5. `notifyTargetOnProposal`
**Notificaciones de propuesta de intercambio**
- **Trigger**: `/plants/{plantId}/shift_requests/{requestId}` onUpdate
- **Función**: Notifica al usuario objetivo cuando recibe una propuesta de intercambio
- **Estados**: PENDING_PARTNER

### 6. `validateShiftRequestStatus`
**Validación de seguridad para solicitudes**
- **Trigger**: `/plants/{plantId}/shift_requests/{requestId}/status` onUpdate
- **Función**: Valida que solo supervisores puedan aprobar/rechazar solicitudes
- **Seguridad**: Revierte cambios no autorizados y registra eventos de seguridad

### 7. `validateShiftWrite`
**Validación de seguridad para turnos**
- **Trigger**: `/plants/{plantId}/turnos/{dateKey}/{shiftName}` onWrite
- **Función**: Valida que solo supervisores puedan modificar turnos
- **Seguridad**: Revierte cambios no autorizados con auditoría completa

### 8. `logSecurityEvent`
**Registro de eventos de seguridad**
- **Función auxiliar**: Registra eventos de seguridad en `/security_logs`
- **Uso**: Auditoría de intentos de acceso no autorizado

## Instalación

1. **Instalar Node.js 22**
   ```bash
   # Verifica la versión
   node --version  # Debe ser v22.x.x
   ```

2. **Instalar dependencias**
   ```bash
   cd functions
   npm install
   ```

3. **Configurar Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

4. **Inicializar proyecto Firebase**
   ```bash
   # En el directorio raíz del proyecto
   firebase init functions
   ```

## Desarrollo

### Ejecutar en local (emulador)
```bash
cd functions
npm run serve
```

### Ejecutar shell interactivo
```bash
cd functions
npm run shell
```

### Ver logs
```bash
npm run logs
```

## Despliegue

### Desplegar todas las funciones
```bash
cd functions
npm run deploy
```

### Desplegar una función específica
```bash
firebase deploy --only functions:sendNotification
```

### Desplegar múltiples funciones
```bash
firebase deploy --only functions:sendNotification,functions:sendChatNotification
```

## Estructura del Proyecto

```
functions/
├── index.js          # Todas las Cloud Functions
├── package.json      # Dependencias y scripts
├── node_modules/     # Dependencias (gitignored)
└── README.md         # Este archivo
```

## Requisitos

- Node.js 22 (especificado en package.json)
- Firebase Admin SDK 13.6.0+
- Firebase Functions 7.0.0+

## Seguridad

Las funciones implementan validación del lado del servidor para:
- ✅ Prevenir modificaciones no autorizadas de turnos
- ✅ Validar permisos de supervisor para aprobaciones
- ✅ Registrar eventos de seguridad
- ✅ Revertir cambios no autorizados automáticamente

## Notas Importantes

1. **iOS APNs**: Las notificaciones push en iOS requieren configuración adicional:
   - Certificado APNs en Firebase Console
   - Configuración de capabilities en Xcode (Push Notifications)
   - Token FCM registrado en la base de datos

2. **Permisos**: Asegúrate de que las reglas de seguridad de Firebase Database permitan a las funciones leer/escribir datos necesarios.

3. **Costos**: Firebase Functions tiene un tier gratuito limitado. Revisa el uso en Firebase Console.

4. **Logs**: Usa `firebase functions:log` para depurar problemas en producción.

## Troubleshooting

### Error: "Firebase not configured"
- Verifica que `firebase.json` existe en el directorio raíz
- Ejecuta `firebase init functions` si es necesario

### Error: "Deployment failed"
- Verifica que tienes permisos de despliegue en el proyecto Firebase
- Confirma que estás logueado: `firebase login`

### Notificaciones no llegan
- Verifica que el token FCM está almacenado en `/users/{userId}/fcmToken`
- Revisa los logs: `npm run logs`
- Confirma que la configuración APNs está correcta en Firebase Console

## Soporte

Para más información sobre Firebase Cloud Functions:
- [Documentación oficial](https://firebase.google.com/docs/functions)
- [Guía de Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
