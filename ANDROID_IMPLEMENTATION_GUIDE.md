# Guía de Implementación: Calendario Offline para Android

Este documento describe la arquitectura completa del módulo de Calendario Offline de TurnosHospi iOS para su implementación en Android usando Kotlin y Jetpack Compose.

---

## 📁 Estructura de Carpetas Recomendada (Android)

```
app/src/main/java/com/turnoshospi/
├── offlinecalendar/
│   ├── data/
│   │   ├── model/
│   │   │   ├── UserShift.kt
│   │   │   ├── ShiftPattern.kt
│   │   │   ├── CustomShiftType.kt
│   │   │   ├── ShiftTemplate.kt
│   │   │   ├── OfflineShiftSettings.kt
│   │   │   └── OfflineMonthlyStats.kt
│   │   ├── repository/
│   │   │   ├── ShiftRepository.kt
│   │   │   └── TemplateRepository.kt
│   │   └── local/
│   │       └── CalendarPreferences.kt
│   ├── domain/
│   │   ├── usecase/
│   │   │   ├── CalculateStatsUseCase.kt
│   │   │   ├── ApplyTemplateUseCase.kt
│   │   │   └── MigrateShiftsUseCase.kt
│   │   └── util/
│   │       ├── ShiftNormalizer.kt
│   │       ├── DateUtils.kt
│   │       └── ShiftColorResolver.kt
│   ├── presentation/
│   │   ├── viewmodel/
│   │   │   └── OfflineCalendarViewModel.kt
│   │   ├── screen/
│   │   │   ├── OfflineCalendarScreen.kt
│   │   │   ├── StatisticsScreen.kt
│   │   │   └── SettingsScreen.kt
│   │   ├── components/
│   │   │   ├── CalendarGrid.kt
│   │   │   ├── DayCell.kt
│   │   │   ├── LegendView.kt
│   │   │   ├── CustomTabBar.kt
│   │   │   ├── AssignmentPanel.kt
│   │   │   ├── NotesPanel.kt
│   │   │   └── charts/
│   │   │       ├── ShiftPieChart.kt
│   │   │       └── ShiftBarChart.kt
│   │   └── dialog/
│   │       ├── TemplateSheet.kt
│   │       ├── TemplateEditorDialog.kt
│   │       ├── ExportSheet.kt
│   │       └── CustomShiftEditorDialog.kt
│   └── ui/
│       └── theme/
│           ├── CalendarColors.kt
│           ├── CalendarDimensions.kt
│           └── CalendarTypography.kt
```

---

## 📊 MODELOS DE DATOS (data/model/)

### 1. UserShift.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

import kotlinx.serialization.Serializable

/**
 * Representa un turno asignado a un día específico
 */
@Serializable
data class UserShift(
    val shiftName: String,
    val isHalfDay: Boolean = false
)
```

### 2. ShiftPattern.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

/**
 * Patrones de turno disponibles
 */
enum class ShiftPattern(val value: String, val title: String) {
    THREE("THREE_SHIFTS", "3 Turnos (M/T/N)"),
    TWO("TWO_SHIFTS", "2 Turnos (Día 12h / Noche 12h)"),
    CUSTOM("CUSTOM_SHIFTS", "Turnos personalizados");

    companion object {
        fun fromValue(value: String): ShiftPattern {
            return values().find { it.value == value } ?: THREE
        }
    }
}
```

### 3. CustomShiftType.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Tipo de turno personalizado creado por el usuario
 */
@Serializable
data class CustomShiftType(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val colorHex: String,
    val durationHours: Double = 8.0
)
```

### 4. ShiftTemplate.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Plantilla de turnos con duración variable (1-56 días)
 */
@Serializable
data class ShiftTemplate(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val description: String = "",
    val pattern: List<String?> = List(7) { null }  // nil = Libre
) {
    val durationDays: Int get() = pattern.size

    fun shift(dayIndex: Int): String? {
        return pattern.getOrNull(dayIndex)
    }

    companion object {
        val dayNames = listOf("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")
        val dayAbbreviations = listOf("L", "M", "X", "J", "V", "S", "D")

        fun dayName(index: Int): String {
            val weekNumber = index / 7 + 1
            val dayInWeek = index % 7
            return if (weekNumber == 1) {
                dayNames[dayInWeek]
            } else {
                "S$weekNumber ${dayNames[dayInWeek]}"
            }
        }

        fun dayAbbreviation(index: Int): String {
            return dayAbbreviations[index % 7]
        }
    }
}
```

### 5. OfflineShiftSettings.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

import kotlinx.serialization.Serializable

/**
 * Configuración de turnos para persistencia
 */
@Serializable
data class OfflineShiftSettings(
    val pattern: ShiftPattern = ShiftPattern.THREE,
    val allowHalfDay: Boolean = false
)
```

### 6. OfflineMonthlyStats.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.model

/**
 * Estadísticas mensuales calculadas
 */
data class OfflineMonthlyStats(
    val totalHours: Double = 0.0,
    val totalShifts: Int = 0,
    val breakdown: Map<String, ShiftStatData> = emptyMap()
)

data class ShiftStatData(
    val hours: Double = 0.0,
    val count: Int = 0
)
```

---

## 💾 PERSISTENCIA (data/local/)

### CalendarPreferences.kt
```kotlin
package com.turnoshospi.offlinecalendar.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "calendar_prefs")

class CalendarPreferences(private val context: Context) {

    companion object {
        private val SHIFTS_KEY = stringPreferencesKey("shifts_map")
        private val NOTES_KEY = stringPreferencesKey("notes_map")
        private val SETTINGS_KEY = stringPreferencesKey("shift_settings")
        private val CUSTOM_SHIFTS_KEY = stringPreferencesKey("custom_shift_types")
        private val TEMPLATES_KEY = stringPreferencesKey("shift_templates_v4")
        private val DURATIONS_KEY = stringPreferencesKey("shift_durations")
    }

    private val json = Json { ignoreUnknownKeys = true }

    // Turnos
    val shiftsFlow: Flow<Map<String, UserShift>> = context.dataStore.data.map { prefs ->
        prefs[SHIFTS_KEY]?.let {
            json.decodeFromString(it)
        } ?: emptyMap()
    }

    suspend fun saveShifts(shifts: Map<String, UserShift>) {
        context.dataStore.edit { prefs ->
            prefs[SHIFTS_KEY] = json.encodeToString(shifts)
        }
    }

    // Notas
    val notesFlow: Flow<Map<String, List<String>>> = context.dataStore.data.map { prefs ->
        prefs[NOTES_KEY]?.let {
            json.decodeFromString(it)
        } ?: emptyMap()
    }

    suspend fun saveNotes(notes: Map<String, List<String>>) {
        context.dataStore.edit { prefs ->
            prefs[NOTES_KEY] = json.encodeToString(notes)
        }
    }

    // Plantillas
    val templatesFlow: Flow<List<ShiftTemplate>> = context.dataStore.data.map { prefs ->
        prefs[TEMPLATES_KEY]?.let {
            json.decodeFromString(it)
        } ?: emptyList()
    }

    suspend fun saveTemplates(templates: List<ShiftTemplate>) {
        context.dataStore.edit { prefs ->
            prefs[TEMPLATES_KEY] = json.encodeToString(templates)
        }
    }

    // Configuración
    val settingsFlow: Flow<OfflineShiftSettings> = context.dataStore.data.map { prefs ->
        prefs[SETTINGS_KEY]?.let {
            json.decodeFromString(it)
        } ?: OfflineShiftSettings()
    }

    suspend fun saveSettings(settings: OfflineShiftSettings) {
        context.dataStore.edit { prefs ->
            prefs[SETTINGS_KEY] = json.encodeToString(settings)
        }
    }

    // Turnos personalizados
    val customShiftsFlow: Flow<List<CustomShiftType>> = context.dataStore.data.map { prefs ->
        prefs[CUSTOM_SHIFTS_KEY]?.let {
            json.decodeFromString(it)
        } ?: emptyList()
    }

    suspend fun saveCustomShifts(customShifts: List<CustomShiftType>) {
        context.dataStore.edit { prefs ->
            prefs[CUSTOM_SHIFTS_KEY] = json.encodeToString(customShifts)
        }
    }
}
```

---

## 🔧 UTILIDADES (domain/util/)

### ShiftNormalizer.kt
```kotlin
package com.turnoshospi.offlinecalendar.domain.util

/**
 * Normaliza el nombre de un turno a su forma canónica
 */
object ShiftNormalizer {

    fun normalize(raw: String): String {
        val trimmed = raw.trim()
        val lower = trimmed.lowercase()

        return when (lower) {
            "mañana", "manana", "morning", "am" -> "Mañana"
            "tarde", "afternoon", "pm" -> "Tarde"
            "noche", "night", "night shift" -> "Noche"
            "saliente", "post-night", "post night", "postnight" -> "Saliente"
            "día", "dia", "day" -> "Día"
            "media mañana", "media manana", "half morning", "m. mañana", "m. manana" -> "Media Mañana"
            "media tarde", "half afternoon", "m. tarde" -> "Media Tarde"
            "medio día", "medio dia", "half day" -> "Medio Día"
            "vacaciones", "vacation", "holiday" -> "Vacaciones"
            "libre", "off", "free" -> "Libre"
            else -> trimmed
        }
    }
}
```

### DateUtils.kt
```kotlin
package com.turnoshospi.offlinecalendar.domain.util

import java.text.SimpleDateFormat
import java.util.*

object DateUtils {

    private val dateKeyFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

    fun dateKey(date: Date): String {
        return dateKeyFormat.format(date)
    }

    fun dateFromKey(key: String): Date? {
        return try {
            dateKeyFormat.parse(key)
        } catch (e: Exception) {
            null
        }
    }

    fun formatDisplayDate(date: Date, pattern: String = "d 'de' MMMM"): String {
        val formatter = SimpleDateFormat(pattern, Locale("es", "ES"))
        return formatter.format(date).replaceFirstChar { it.uppercase() }
    }

    fun monthTitle(date: Date): String {
        val formatter = SimpleDateFormat("MMMM yyyy", Locale("es", "ES"))
        return formatter.format(date)
    }

    fun getDaysInMonth(date: Date): List<Date> {
        val calendar = Calendar.getInstance()
        calendar.time = date
        calendar.set(Calendar.DAY_OF_MONTH, 1)

        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        val days = mutableListOf<Date>()

        for (i in 0 until daysInMonth) {
            days.add(calendar.time)
            calendar.add(Calendar.DAY_OF_MONTH, 1)
        }

        return days
    }

    fun getFirstDayOfWeek(date: Date): Int {
        val calendar = Calendar.getInstance()
        calendar.time = date
        calendar.set(Calendar.DAY_OF_MONTH, 1)
        // Ajustar para que Lunes = 0
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        return if (dayOfWeek == Calendar.SUNDAY) 6 else dayOfWeek - 2
    }
}
```

### ShiftColorResolver.kt
```kotlin
package com.turnoshospi.offlinecalendar.domain.util

import androidx.compose.ui.graphics.Color
import com.turnoshospi.offlinecalendar.data.model.CustomShiftType
import com.turnoshospi.offlinecalendar.ui.theme.CalendarColors

object ShiftColorResolver {

    fun getColor(
        shiftType: String,
        customShiftTypes: List<CustomShiftType> = emptyList()
    ): Color {
        // 1. Buscar en turnos personalizados
        customShiftTypes.find {
            it.name.equals(shiftType, ignoreCase = true)
        }?.let {
            return Color(android.graphics.Color.parseColor(it.colorHex))
        }

        // 2. Colores por defecto
        val normalized = ShiftNormalizer.normalize(shiftType).lowercase()

        return when (normalized) {
            "mañana", "día" -> CalendarColors.shiftMorning
            "media mañana", "m. mañana", "medio día" -> CalendarColors.shiftHalfMorning
            "tarde" -> CalendarColors.shiftAfternoon
            "media tarde", "m. tarde" -> CalendarColors.shiftHalfAfternoon
            "noche" -> CalendarColors.shiftNight
            "saliente" -> CalendarColors.shiftSaliente
            "vacaciones" -> CalendarColors.shiftVacation
            "libre" -> CalendarColors.shiftFree
            else -> CalendarColors.shiftFree
        }
    }
}
```

---

## 🎨 TEMA (ui/theme/)

### CalendarColors.kt
```kotlin
package com.turnoshospi.offlinecalendar.ui.theme

import androidx.compose.ui.graphics.Color

object CalendarColors {
    // Fondos
    val background = Color(0xFF0F172A)
    val backgroundElevated = Color(0xFF131C2E)
    val cardBackground = Color(0xFF1E293B)
    val cardBackgroundLight = Color(0xFF334155)

    // Acentos
    val accent = Color(0xFF54C7EC)
    val accentSecondary = Color(0xFFA78BFA)

    // Texto
    val textPrimary = Color.White
    val textSecondary = Color(0xFF94A3B8)
    val textTertiary = Color(0xFF64748B)

    // Estados
    val success = Color(0xFF10B981)
    val warning = Color(0xFFF59E0B)
    val error = Color(0xFFEF4444)

    // Turnos
    val shiftMorning = Color(0xFF66BB6A)       // Verde
    val shiftAfternoon = Color(0xFFFF7043)     // Naranja
    val shiftNight = Color(0xFF5C6BC0)         // Índigo
    val shiftSaliente = Color(0xFF4CAF50)      // Verde claro
    val shiftVacation = Color(0xFFEF5350)      // Rojo
    val shiftFree = Color(0xFF334155)          // Gris
    val shiftHalfMorning = Color(0xFF66BB6A)   // Verde (media)
    val shiftHalfAfternoon = Color(0xFFFFA726) // Naranja claro

    // Indicadores
    val todayRing = Color(0xFF54C7EC)
    val noteIndicator = Color(0xFFFCD34D)
    val halfDayIndicator = Color(0xFFA78BFA)

    // Bordes
    val border = Color(0xFF334155)
}
```

### CalendarDimensions.kt
```kotlin
package com.turnoshospi.offlinecalendar.ui.theme

import androidx.compose.ui.unit.dp

object CalendarDimensions {
    // Espaciado
    val spacingXxs = 2.dp
    val spacingXs = 4.dp
    val spacingSm = 8.dp
    val spacingMd = 12.dp
    val spacingLg = 16.dp
    val spacingXl = 20.dp
    val spacingXxl = 24.dp
    val spacingXxxl = 32.dp

    // Radio de esquinas
    val cornerSmall = 6.dp
    val cornerMedium = 10.dp
    val cornerLarge = 16.dp
    val cornerXl = 20.dp

    // Tamaños
    val dayCell = 44.dp
    val dayCellCompact = 38.dp
    val dayCellLarge = 48.dp
    val noteIndicator = 6.dp
    val halfDayIndicator = 5.dp
    val todayRing = 3.dp
    val tabBarHeight = 70.dp
    val fabButton = 56.dp
}
```

---

## 🧠 VIEWMODEL (presentation/viewmodel/)

### OfflineCalendarViewModel.kt
```kotlin
package com.turnoshospi.offlinecalendar.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.turnoshospi.offlinecalendar.data.local.CalendarPreferences
import com.turnoshospi.offlinecalendar.data.model.*
import com.turnoshospi.offlinecalendar.domain.util.DateUtils
import com.turnoshospi.offlinecalendar.domain.util.ShiftNormalizer
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.*

class OfflineCalendarViewModel(
    private val preferences: CalendarPreferences
) : ViewModel() {

    // Estados principales
    private val _shifts = MutableStateFlow<Map<String, UserShift>>(emptyMap())
    val shifts: StateFlow<Map<String, UserShift>> = _shifts.asStateFlow()

    private val _notes = MutableStateFlow<Map<String, List<String>>>(emptyMap())
    val notes: StateFlow<Map<String, List<String>>> = _notes.asStateFlow()

    private val _selectedDate = MutableStateFlow(Date())
    val selectedDate: StateFlow<Date> = _selectedDate.asStateFlow()

    private val _currentMonth = MutableStateFlow(Date())
    val currentMonth: StateFlow<Date> = _currentMonth.asStateFlow()

    // Configuración
    private val _settings = MutableStateFlow(OfflineShiftSettings())
    val settings: StateFlow<OfflineShiftSettings> = _settings.asStateFlow()

    private val _customShiftTypes = MutableStateFlow<List<CustomShiftType>>(emptyList())
    val customShiftTypes: StateFlow<List<CustomShiftType>> = _customShiftTypes.asStateFlow()

    private val _templates = MutableStateFlow<List<ShiftTemplate>>(emptyList())
    val templates: StateFlow<List<ShiftTemplate>> = _templates.asStateFlow()

    // Estados de UI
    private val _isAssignmentMode = MutableStateFlow(false)
    val isAssignmentMode: StateFlow<Boolean> = _isAssignmentMode.asStateFlow()

    private val _selectedShiftToApply = MutableStateFlow("Mañana")
    val selectedShiftToApply: StateFlow<String> = _selectedShiftToApply.asStateFlow()

    // Tipos de turno disponibles
    val shiftTypes: StateFlow<List<String>> = combine(
        _settings,
        _customShiftTypes
    ) { settings, customTypes ->
        buildShiftTypes(settings, customTypes)
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            preferences.shiftsFlow.collect { _shifts.value = it }
        }
        viewModelScope.launch {
            preferences.notesFlow.collect { _notes.value = it }
        }
        viewModelScope.launch {
            preferences.settingsFlow.collect { _settings.value = it }
        }
        viewModelScope.launch {
            preferences.customShiftsFlow.collect { _customShiftTypes.value = it }
        }
        viewModelScope.launch {
            preferences.templatesFlow.collect { _templates.value = it }
        }
    }

    private fun buildShiftTypes(
        settings: OfflineShiftSettings,
        customTypes: List<CustomShiftType>
    ): List<String> {
        val types = mutableListOf<String>()

        when (settings.pattern) {
            ShiftPattern.THREE -> {
                types.addAll(listOf("Mañana", "Tarde", "Noche", "Saliente"))
                if (settings.allowHalfDay) {
                    types.addAll(listOf("M. Mañana", "M. Tarde"))
                }
            }
            ShiftPattern.TWO -> {
                types.addAll(listOf("Día", "Noche", "Saliente"))
                if (settings.allowHalfDay) {
                    types.add("Medio Día")
                }
            }
            ShiftPattern.CUSTOM -> {
                types.addAll(customTypes.map { it.name })
            }
        }

        types.addAll(listOf("Vacaciones", "Libre"))
        return types
    }

    // Acciones
    fun handleDayClick(date: Date) {
        if (_isAssignmentMode.value) {
            assignShiftToDate(date)
        } else {
            _selectedDate.value = date
        }
    }

    private fun assignShiftToDate(date: Date) {
        val key = DateUtils.dateKey(date)
        val currentShifts = _shifts.value.toMutableMap()

        if (_selectedShiftToApply.value == "Libre") {
            currentShifts.remove(key)
        } else {
            currentShifts[key] = UserShift(
                shiftName = _selectedShiftToApply.value,
                isHalfDay = false
            )
        }

        _shifts.value = currentShifts
        viewModelScope.launch {
            preferences.saveShifts(currentShifts)
        }
    }

    fun setAssignmentMode(enabled: Boolean) {
        _isAssignmentMode.value = enabled
    }

    fun setSelectedShift(shift: String) {
        _selectedShiftToApply.value = shift
    }

    fun changeMonth(delta: Int) {
        val calendar = Calendar.getInstance()
        calendar.time = _currentMonth.value
        calendar.add(Calendar.MONTH, delta)
        _currentMonth.value = calendar.time
    }

    // Detección de Saliente automático
    fun shouldShowSaliente(date: Date): Boolean {
        val key = DateUtils.dateKey(date)
        if (_shifts.value.containsKey(key)) return false

        val calendar = Calendar.getInstance()
        calendar.time = date
        calendar.add(Calendar.DAY_OF_MONTH, -1)
        val yesterdayKey = DateUtils.dateKey(calendar.time)

        val yesterdayShift = _shifts.value[yesterdayKey] ?: return false
        return ShiftNormalizer.normalize(yesterdayShift.shiftName) == "Noche"
    }

    // Aplicar plantilla
    fun applyTemplate(template: ShiftTemplate, startDate: Date, repetitions: Int) {
        val calendar = Calendar.getInstance()
        calendar.time = startDate

        val patternLength = template.durationDays
        val totalDays = patternLength * repetitions
        val currentShifts = _shifts.value.toMutableMap()

        for (dayOffset in 0 until totalDays) {
            val date = calendar.time
            val key = DateUtils.dateKey(date)
            val patternIndex = dayOffset % patternLength
            val shiftName = template.pattern.getOrNull(patternIndex)

            if (shiftName != null) {
                currentShifts[key] = UserShift(shiftName = shiftName, isHalfDay = false)
            } else {
                currentShifts.remove(key)
            }

            calendar.add(Calendar.DAY_OF_MONTH, 1)
        }

        _shifts.value = currentShifts
        viewModelScope.launch {
            preferences.saveShifts(currentShifts)
        }
    }

    // Gestión de notas
    fun addNote(text: String) {
        val key = DateUtils.dateKey(_selectedDate.value)
        val currentNotes = _notes.value.toMutableMap()
        val dayNotes = currentNotes[key]?.toMutableList() ?: mutableListOf()
        dayNotes.add(text)
        currentNotes[key] = dayNotes
        _notes.value = currentNotes

        viewModelScope.launch {
            preferences.saveNotes(currentNotes)
        }
    }

    fun deleteNote(index: Int) {
        val key = DateUtils.dateKey(_selectedDate.value)
        val currentNotes = _notes.value.toMutableMap()
        val dayNotes = currentNotes[key]?.toMutableList() ?: return

        if (index < dayNotes.size) {
            dayNotes.removeAt(index)
            if (dayNotes.isEmpty()) {
                currentNotes.remove(key)
            } else {
                currentNotes[key] = dayNotes
            }
            _notes.value = currentNotes

            viewModelScope.launch {
                preferences.saveNotes(currentNotes)
            }
        }
    }

    // Estadísticas
    fun calculateStats(month: Date): OfflineMonthlyStats {
        val calendar = Calendar.getInstance()
        calendar.time = month
        val targetMonth = calendar.get(Calendar.MONTH)
        val targetYear = calendar.get(Calendar.YEAR)

        var totalHours = 0.0
        var totalShifts = 0
        val breakdown = mutableMapOf<String, ShiftStatData>()

        _shifts.value.forEach { (dateKey, shift) ->
            val date = DateUtils.dateFromKey(dateKey) ?: return@forEach
            calendar.time = date

            if (calendar.get(Calendar.MONTH) == targetMonth &&
                calendar.get(Calendar.YEAR) == targetYear) {

                val hours = getShiftDuration(shift)
                if (hours > 0) {
                    totalHours += hours
                    totalShifts++

                    val key = ShiftNormalizer.normalize(shift.shiftName)
                    val current = breakdown[key] ?: ShiftStatData()
                    breakdown[key] = ShiftStatData(
                        hours = current.hours + hours,
                        count = current.count + 1
                    )
                }
            }
        }

        return OfflineMonthlyStats(
            totalHours = totalHours,
            totalShifts = totalShifts,
            breakdown = breakdown
        )
    }

    private fun getShiftDuration(shift: UserShift): Double {
        // Buscar en turnos personalizados
        _customShiftTypes.value.find {
            it.name.equals(shift.shiftName, ignoreCase = true)
        }?.let {
            return if (shift.isHalfDay) it.durationHours / 2 else it.durationHours
        }

        // Duraciones por defecto
        val baseDuration = when (ShiftNormalizer.normalize(shift.shiftName)) {
            "Mañana", "Tarde", "Noche" -> 8.0
            "Día" -> 12.0
            "Media Mañana", "Media Tarde", "Medio Día" -> 4.0
            else -> 0.0
        }

        return if (shift.isHalfDay) baseDuration / 2 else baseDuration
    }
}
```

---

## 🖼️ COMPONENTES UI (presentation/components/)

### DayCell.kt (Composable)
```kotlin
package com.turnoshospi.offlinecalendar.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.turnoshospi.offlinecalendar.data.model.CustomShiftType
import com.turnoshospi.offlinecalendar.data.model.UserShift
import com.turnoshospi.offlinecalendar.domain.util.ShiftColorResolver
import com.turnoshospi.offlinecalendar.ui.theme.CalendarColors
import com.turnoshospi.offlinecalendar.ui.theme.CalendarDimensions
import java.util.*

@Composable
fun DayCell(
    date: Date,
    dayNumber: Int,
    shift: UserShift?,
    hasNotes: Boolean,
    isToday: Boolean,
    isSelected: Boolean,
    isCurrentMonth: Boolean,
    isSalienteAuto: Boolean,
    customShiftTypes: List<CustomShiftType>,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val backgroundColor = when {
        shift != null -> ShiftColorResolver.getColor(shift.shiftName, customShiftTypes)
        isSalienteAuto -> CalendarColors.shiftSaliente.copy(alpha = 0.6f)
        else -> Color.Transparent
    }

    val textColor = if (!isCurrentMonth) {
        CalendarColors.textTertiary
    } else if (shift != null || isSalienteAuto) {
        Color.White
    } else {
        CalendarColors.textPrimary
    }

    Box(
        modifier = modifier
            .size(CalendarDimensions.dayCell)
            .clip(CircleShape)
            .background(backgroundColor)
            .then(
                if (isToday) {
                    Modifier.border(
                        width = CalendarDimensions.todayRing,
                        color = CalendarColors.todayRing,
                        shape = CircleShape
                    )
                } else if (isSelected) {
                    Modifier.border(
                        width = 2.dp,
                        color = CalendarColors.accent,
                        shape = CircleShape
                    )
                } else {
                    Modifier
                }
            )
            .clickable(enabled = isCurrentMonth) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = dayNumber.toString(),
                color = textColor,
                fontSize = 15.sp,
                fontWeight = if (isToday) FontWeight.Bold else FontWeight.SemiBold
            )

            // Indicador de nota
            if (hasNotes) {
                Box(
                    modifier = Modifier
                        .size(CalendarDimensions.noteIndicator)
                        .clip(CircleShape)
                        .background(CalendarColors.noteIndicator)
                )
            }

            // Indicador de media jornada
            if (shift?.isHalfDay == true) {
                Box(
                    modifier = Modifier
                        .size(CalendarDimensions.halfDayIndicator)
                        .clip(CircleShape)
                        .background(CalendarColors.halfDayIndicator)
                )
            }
        }
    }
}
```

---

## 📋 RESUMEN DE ARCHIVOS iOS → Android

| iOS (Swift) | Android (Kotlin) |
|-------------|------------------|
| `OfflineCalendarModels.swift` | `UserShift.kt`, `ShiftPattern.kt`, `CustomShiftType.kt` |
| `ShiftTemplate.swift` | `ShiftTemplate.kt` |
| `OfflineCalendarViewModel.swift` | `OfflineCalendarViewModel.kt` |
| `OfflineCalendarHelpers.swift` | `ShiftNormalizer.kt`, `DateUtils.kt`, `ShiftColorResolver.kt` |
| `OfflineCalendarDesign.swift` | `CalendarColors.kt`, `CalendarDimensions.kt` |
| `HapticManager.swift` | Android Vibrator Service / HapticFeedback |
| `TemplateSheet.swift` | `TemplateSheet.kt` (BottomSheet) |
| `CalendarGridView.swift` | `CalendarGrid.kt` |
| `DayCellView.swift` | `DayCell.kt` |
| `CustomTabBar.swift` | Material3 NavigationBar |
| UserDefaults | DataStore Preferences |
| `@StateObject` / `@ObservedObject` | `StateFlow` / `collectAsState()` |

---

## 🔑 CLAVES DE PERSISTENCIA

```kotlin
object PreferenceKeys {
    const val SHIFTS_MAP = "shifts_map"
    const val NOTES_MAP = "notes_map"
    const val SHIFT_SETTINGS = "shift_settings_map"
    const val CUSTOM_SHIFTS = "custom_shift_types"
    const val SHIFT_DURATIONS = "shift_durations_map"
    const val TEMPLATES = "shift_templates_v4"
}
```

---

## 📱 DEPENDENCIAS GRADLE

```kotlin
// build.gradle.kts (Module)
dependencies {
    // Jetpack Compose
    implementation("androidx.compose.ui:ui:1.5.4")
    implementation("androidx.compose.material3:material3:1.1.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.6.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.6.2")

    // DataStore
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")

    // Charts (opcional)
    implementation("com.github.PhilJay:MPAndroidChart:v3.1.0")
    // o usar Compose Charts
    implementation("io.github.bytebeats:compose-charts:0.1.2")

    // Calendar (opcional)
    implementation("com.kizitonwose.calendar:compose:2.4.0")
}
```

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

- [ ] Crear estructura de carpetas
- [ ] Implementar modelos de datos
- [ ] Configurar DataStore para persistencia
- [ ] Implementar ViewModel
- [ ] Crear componentes UI básicos (DayCell, CalendarGrid)
- [ ] Implementar sistema de colores y tema
- [ ] Crear pantalla principal del calendario
- [ ] Implementar modo asignación de turnos
- [ ] Implementar gestión de notas
- [ ] Crear pantalla de estadísticas con gráficos
- [ ] Implementar plantillas (crear, editar, aplicar)
- [ ] Implementar exportación
- [ ] Añadir haptic feedback
- [ ] Testing

---

*Documento generado automáticamente desde TurnosHospi iOS*
*Fecha: Enero 2026*
