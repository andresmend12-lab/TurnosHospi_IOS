# Reporte de Archivos Duplicados

## Resumen

El proyecto tiene archivos Swift duplicados en dos ubicaciones:
- **Raíz**: `/TurnosHospi_IOS/*.swift` (36 archivos)
- **Subdirectorio**: `/TurnosHospi_IOS/TurnosHospi_IOS/*.swift` (37 archivos)

## Estado de Duplicados

### Archivos Idénticos (19)
Estos archivos son exactamente iguales en ambas ubicaciones:

| Archivo | Tamaño |
|---------|--------|
| AddEditStaffView.swift | 4,804 bytes |
| ContentView.swift | 429 bytes |
| CreatePlantView.swift | 17,933 bytes |
| DirectChatModels.swift | 1,934 bytes |
| DirectChatView.swift | 9,179 bytes |
| EditProfilesView.swift | 7,168 bytes |
| JoinPlantView.swift | 8,450 bytes |
| NewChatSelectionView.swift | 3,192 bytes |
| PlantManager.swift | 19,209 bytes |
| PlantModels.swift | 2,061 bytes |
| SettingsView.swift | 4,482 bytes |
| Shift.swift | 892 bytes |
| ShiftManager.swift | 1,760 bytes |
| ShiftMarketplaceView.swift | 28,948 bytes |
| ShiftRulesEngine.swift | 8,449 bytes |
| SignUpView.swift | 7,205 bytes |
| ThemeManager.swift | 6,550 bytes |
| VacationDaysView.swift | 8,100 bytes |
| VacationManager.swift | 3,861 bytes |

### Archivos Diferentes (17)
Estos archivos tienen contenido diferente entre ubicaciones:

| Archivo | Raíz | Subdirectorio | Recomendación |
|---------|------|---------------|---------------|
| AuthManager.swift | 7,979 B | **8,630 B** | Usar subdirectorio |
| DirectChatListView.swift | 11,000 B | **14,465 B** | Usar subdirectorio |
| Extensions.swift | 1,070 B | **1,151 B** | Usar subdirectorio |
| GroupChatView.swift | **10,588 B** | 9,703 B | Revisar ambos |
| ImportShiftsView.swift | 10,532 B | **11,059 B** | Usar subdirectorio |
| LoginView.swift | 6,293 B | **6,298 B** | Usar subdirectorio |
| MainMenuView.swift | 22,762 B | **24,132 B** | Usar subdirectorio |
| NotificationCenterManager.swift | **9,745 B** | 4,372 B | Revisar ambos |
| NotificationCenterView.swift | 8,018 B | **8,569 B** | Usar subdirectorio |
| OfflineCalendarView.swift | **26,967 B** | 26,647 B | Revisar ambos |
| PlantDashboardView.swift | 55,201 B | **65,065 B** | Usar subdirectorio |
| ShiftChangeModels.swift | 3,433 B | **3,553 B** | Usar subdirectorio |
| ShiftChangeView.swift | 56,762 B | **71,082 B** | Usar subdirectorio |
| SideMenuView.swift | 4,744 B | **4,883 B** | Usar subdirectorio |
| StaffListView.swift | 5,866 B | **8,586 B** | Usar subdirectorio |
| StatisticsView.swift | 17,861 B | **18,388 B** | Usar subdirectorio |
| TurnosHospi_IOSApp.swift | 4,033 B | **4,271 B** | Usar subdirectorio |

### Archivos Solo en Subdirectorio (1)
| Archivo | Tamaño |
|---------|--------|
| NotificationAPI.swift | 2,862 bytes |

## Recomendación

**Mantener solo el subdirectorio `/TurnosHospi_IOS/TurnosHospi_IOS/`** como fuente autoritativa.

### Pasos para Limpieza

1. **Verificar el proyecto Xcode**: Abrir `TurnosHospi_IOS.xcodeproj` y confirmar qué archivos están referenciados
2. **Hacer backup** de los archivos de la raíz antes de eliminar
3. **Eliminar duplicados** de la raíz:

```bash
# Backup primero
mkdir -p ~/TurnosHospi_backup
cp /path/to/TurnosHospi_IOS/*.swift ~/TurnosHospi_backup/

# Eliminar archivos de la raíz (después de verificar)
rm /path/to/TurnosHospi_IOS/*.swift
```

4. **Verificar build** después de la limpieza

## Archivos a Revisar Manualmente

Los siguientes archivos tienen la versión de la raíz más grande que la del subdirectorio, lo que podría indicar contenido adicional:

1. **GroupChatView.swift** - Raíz tiene ~900 bytes más
2. **NotificationCenterManager.swift** - Raíz tiene ~5,300 bytes más
3. **OfflineCalendarView.swift** - Raíz tiene ~300 bytes más

Estos archivos deben compararse manualmente para asegurarse de no perder funcionalidad.

---

*Generado automáticamente - Diciembre 2024*
