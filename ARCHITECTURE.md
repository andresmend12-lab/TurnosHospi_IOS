# TurnosHospi iOS - Documentación Técnica

## 📋 Descripción General

TurnosHospi es una aplicación de gestión de turnos para personal sanitario desarrollada en **Swift** con **SwiftUI** y **Firebase** como backend.

### Características Principales
- 📅 Calendario de turnos con visualización mensual
- 🔄 Sistema de intercambio de turnos entre compañeros
- 💬 Chat directo y grupal
- 🔔 Notificaciones push en tiempo real
- 📊 Estadísticas de turnos trabajados
- 🏖️ Gestión de días de vacaciones
- 👥 Gestión de personal (supervisores)

---

## 🏗️ Arquitectura

### Patrón Arquitectónico
La aplicación utiliza un patrón **MVVM-ish** con **ObservableObject** y **Singletons** para la gestión de estado global.

```
┌─────────────────────────────────────────┐
│           UI Layer (SwiftUI)             │
│  Views: LoginView, PlantDashboardView    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      State Management Layer              │
│  Managers: AuthManager, PlantManager     │
│            ThemeManager, VacationManager │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Business Logic Layer                │
│  ShiftRulesEngine (validation rules)     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Data Layer (Firebase)               │
│  Realtime Database, Auth, FCM            │
└─────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```
TurnosHospi_IOS/
├── TurnosHospi_IOS/
│   ├── TurnosHospi_IOSApp.swift     # Entry point
│   ├── ContentView.swift             # Root navigation
│   │
│   ├── Core/
│   │   └── ErrorHandling.swift       # Error types and handling
│   │
│   ├── Components/
│   │   ├── PlantDashboardComponents.swift
│   │   └── ShiftChangeComponents.swift
│   │
│   ├── Managers/
│   │   ├── AuthManager.swift         # Authentication & user state
│   │   ├── PlantManager.swift        # Plant data & shifts
│   │   ├── ThemeManager.swift        # Color themes
│   │   ├── VacationManager.swift     # Vacation tracking
│   │   ├── ShiftManager.swift        # User shifts
│   │   └── NotificationCenterManager.swift
│   │
│   ├── Models/
│   │   ├── ShiftChangeModels.swift   # Request/Response models
│   │   ├── PlantModels.swift         # Plant & staff models
│   │   ├── DirectChatModels.swift    # Chat models
│   │   └── Shift.swift               # Shift type definitions
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   └── SignUpView.swift
│   │   │
│   │   ├── Main/
│   │   │   ├── MainMenuView.swift
│   │   │   ├── PlantDashboardView.swift
│   │   │   └── SideMenuView.swift
│   │   │
│   │   ├── Shifts/
│   │   │   ├── ShiftChangeView.swift
│   │   │   ├── ShiftMarketplaceView.swift
│   │   │   └── OfflineCalendarView.swift
│   │   │
│   │   ├── Chat/
│   │   │   ├── DirectChatView.swift
│   │   │   ├── DirectChatListView.swift
│   │   │   └── GroupChatView.swift
│   │   │
│   │   ├── Plant/
│   │   │   ├── CreatePlantView.swift
│   │   │   ├── JoinPlantView.swift
│   │   │   ├── ImportShiftsView.swift
│   │   │   └── StaffListView.swift
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── VacationDaysView.swift
│   │       └── StatisticsView.swift
│   │
│   └── Engine/
│       └── ShiftRulesEngine.swift    # Business rules validation
│
├── TurnosHospi_IOSTests/
│   ├── ShiftRulesEngineTests.swift
│   ├── ShiftChangeModelsTests.swift
│   └── ErrorHandlingTests.swift
│
└── Assets.xcassets/
```

---

## 🔧 Componentes Principales

### Managers (Estado Global)

#### AuthManager
- **Singleton**: `AuthManager.shared`
- Gestiona autenticación con Firebase Auth
- Almacena datos del usuario (nombre, rol, plantId)
- Gestiona tokens FCM para notificaciones push
- Rastrea mensajes no leídos

#### PlantManager
- Gestiona datos de la planta/hospital
- Obtiene asignaciones mensuales de turnos
- Gestiona lista de personal
- Importación de turnos desde CSV

#### ThemeManager
- **Singleton**: `ThemeManager.shared`
- Personalización de colores por tipo de turno
- Persistencia en UserDefaults

#### VacationManager
- Rastrea días de vacaciones en tiempo real
- Listeners de Firebase para actualizaciones

### ShiftRulesEngine (Motor de Reglas)

Motor de validación de reglas laborales. Implementa:

1. **Regla 0 - Dureza del turno**
   - `.night`: Turnos nocturnos
   - `.weekend`: Fines de semana
   - `.holiday`: Festivos
   - `.normal`: Días laborables normales

2. **Regla 1 - Compatibilidad de Roles**
   - Enfermeros ↔ Enfermeros: ✅
   - Auxiliares/TCAE ↔ Auxiliares/TCAE: ✅
   - Enfermeros ↔ Auxiliares: ❌

3. **Regla 2 - Reglas Laborales**
   - Máximo 6 días consecutivos
   - Descanso obligatorio después de noche (Saliente)
   - No doble turno en el mismo día

4. **Regla 3 - Matching de Intercambios**
   - Validación cruzada de ambas partes
   - Verificación de intención (fechas ofrecidas)

---

## 🔥 Firebase - Estructura de Datos

```
/users
  /{uid}
    - firstName, lastName, email, role
    - plantId, fcmToken, createdAt

/plants
  /{plantId}
    - name, hospitalName, accessPassword
    - staffScope, shiftTimes, staffRequirements
    /personal_de_planta/{staffId}
      - name, role, email, profileType
    /userPlants/{uid}
      - staffId, joinedAt
    /turnos/turnos-{YYYY-MM-DD}
      /{ShiftName}
        - nurses: [{primary, secondary, halfDay}]
        - auxiliaries: [{primary, secondary, halfDay}]
    /shift_requests/{requestId}
      - type, status, mode, hardnessLevel
      - requesterId, requesterName, requesterRole
      - requesterShiftDate, requesterShiftName
      - targetUserId, targetUserName
      - targetShiftDate, targetShiftName
    /vacations/{userId}/{date}
    /group_chat_messages/{messageId}

/user_direct_chats/{userId}/{chatId}
  - lastMessage, timestamp, unreadCount

/direct_messages/{chatId}/{messageId}
  - senderId, text, timestamp, read

/notifications_queue
  - Push notification queue for Cloud Functions
```

---

## 🧪 Testing

### Tests Implementados

#### ShiftRulesEngineTests (30+ casos)
- Cálculo de dureza de turnos
- Participación y compatibilidad de roles
- Validación de reglas laborales
- Algoritmo de matching
- Tests de rendimiento

#### ShiftChangeModelsTests
- Conformidad Codable
- Inicialización por defecto
- Propiedades computadas

#### ErrorHandlingTests
- Categorías de errores
- Conversión de errores
- Estados de carga

### Ejecutar Tests
```bash
# Unit tests
xcodebuild test -scheme TurnosHospi_IOS -destination 'platform=iOS Simulator,name=iPhone 15'

# O desde Xcode: Cmd + U
```

---

## 🎨 Sistema de Errores

### Categorías de Error

```swift
enum AppError: LocalizedError {
    // Autenticación
    case authenticationFailed(reason: String)
    case userNotAuthenticated
    case invalidCredentials

    // Red
    case networkUnavailable
    case serverError(code: Int)
    case timeout

    // Base de Datos
    case databaseReadFailed(path: String)
    case permissionDenied
    case dataNotFound

    // Validación
    case validationFailed(field: String, reason: String)
    case roleIncompatible
    case shiftConflict(reason: String)

    // Lógica de Negocio
    case swapNotAllowed(reason: String)
    case consecutiveDaysExceeded
    case nightShiftRestRequired
}
```

### Uso

```swift
// En ViewModels/Managers
func loadData() async -> AppResult<[Shift]> {
    do {
        let shifts = try await fetchShifts()
        return .success(shifts)
    } catch {
        return .failure(.from(error))
    }
}

// En Views
.errorAlert($viewModel.error)
```

---

## 📱 Estados de Solicitud de Cambio

```
┌──────────┐    ┌───────────┐    ┌─────────────────┐
│  DRAFT   │ -> │ SEARCHING │ -> │ PENDING_PARTNER │
└──────────┘    └───────────┘    └────────┬────────┘
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    │                                           │
                    ▼                                           ▼
        ┌───────────────────────┐                      ┌──────────┐
        │ AWAITING_SUPERVISOR   │                      │ REJECTED │
        └───────────┬───────────┘                      └──────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
  ┌──────────┐           ┌──────────┐
  │ APPROVED │           │ REJECTED │
  └──────────┘           └──────────┘
```

---

## 🚀 Próximos Pasos Recomendados

### Prioridad Alta
1. [ ] Implementar persistencia offline con Core Data
2. [ ] Añadir retry logic para operaciones Firebase
3. [ ] Migrar vistas grandes a ViewModels dedicados

### Prioridad Media
4. [ ] Sistema de vacaciones inteligente
5. [ ] Analytics y reportes mensuales
6. [ ] Internacionalización (multi-idioma)

### Prioridad Baja
7. [ ] Gamificación (logros, puntos)
8. [ ] Predicción de necesidades con ML
9. [ ] Integración con calendarios externos

---

## 📝 Convenciones de Código

### Nomenclatura
- **Views**: `NombreView.swift`
- **Managers**: `NombreManager.swift`
- **Models**: `NombreModels.swift`
- **Components**: Dentro de carpeta `Components/`

### Comentarios
```swift
// MARK: - Section Name
// TODO: Pendiente de implementar
// FIXME: Bug conocido
```

### Estado
```swift
@State private var localState: String = ""
@StateObject var manager = Manager()
@EnvironmentObject var authManager: AuthManager
```

---

## 🔐 Seguridad

### Firebase Rules (Recomendadas)
```json
{
  "rules": {
    "plants": {
      "$plantId": {
        ".read": "auth != null && (
          root.child('plants/' + $plantId + '/userPlants/' + auth.uid).exists()
        )",
        ".write": "auth != null &&
          root.child('plants/' + $plantId + '/userPlants/' + auth.uid + '/role').val() == 'Supervisor'"
      }
    }
  }
}
```

### Tokens FCM
- Almacenados en Firebase bajo `/users/{uid}/fcmToken`
- Actualizados automáticamente al iniciar sesión
- Opcional: Eliminar al cerrar sesión

---

## 📞 Soporte

Para reportar bugs o sugerir mejoras:
- Crear un Issue en el repositorio
- Contactar al equipo de desarrollo

---

*Última actualización: Diciembre 2024*
