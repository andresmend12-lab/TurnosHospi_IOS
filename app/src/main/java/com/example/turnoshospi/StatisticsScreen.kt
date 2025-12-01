package com.example.turnoshospi

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.time.Duration
import java.time.LocalDate
import java.time.LocalTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatisticsScreen(
    plant: Plant?,
    currentUserEmail: String?,
    currentUserName: String?, // Nombre usado en los turnos
    isSupervisor: Boolean, // NUEVO PARÁMETRO: Indica si el usuario actual es supervisor
    allMemberships: List<PlantMembership>, // NUEVO PARÁMETRO: Lista de todo el personal de la planta
    onBack: () -> Unit
) {
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    // Estadísticas personales para el usuario seleccionado (o para sí mismo si no es supervisor)
    var personalStats by remember { mutableStateOf<MonthlyStats?>(null) }
    // Estadísticas agregadas para todo el personal (solo para la vista inicial del supervisor)
    var allStaffStats by remember { mutableStateOf<List<StaffMonthlyStats>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    // Nombre del miembro del personal seleccionado para la vista personalizada
    var selectedStaffName by remember { mutableStateOf<String?>(null) }

    // Determinar los nombres del personal para calcular (usado en la vista general del supervisor)
    val staffNamesForPlant = remember(allMemberships) {
        allMemberships.mapNotNull { it.staffName }.distinct()
    }

    // Determinar el nombre objetivo para el cálculo de estadísticas personales
    val targetNameForCalculation = selectedStaffName ?: currentUserName ?: ""

    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")

    // El LaunchedEffect se ejecuta cuando cambian las variables clave
    LaunchedEffect(plant, currentMonth, targetNameForCalculation, isSupervisor, selectedStaffName) {
        if (plant == null || (!isSupervisor && targetNameForCalculation.isBlank())) {
            isLoading = false
            return@LaunchedEffect
        }

        isLoading = true
        val startStr = "turnos-${currentMonth.atDay(1)}"
        val endStr = "turnos-${currentMonth.atEndOfMonth()}"

        // Reiniciar contenedores de estadísticas
        personalStats = null
        if (selectedStaffName == null) {
            allStaffStats = emptyList() // Limpiar solo si estamos en la vista general o de usuario
        }


        database.getReference("plants/${plant.id}/turnos")
            .orderByKey()
            .startAt(startStr)
            .endAt(endStr)
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {

                    if (isSupervisor && selectedStaffName == null) {
                        // Supervisor: Vista General (calcular para todo el personal)
                        val results = mutableListOf<StaffMonthlyStats>()
                        for (staffName in staffNamesForPlant) {
                            // Reutilizar la lógica existente para calcular las estadísticas de cada miembro
                            val stats = calculateStatsForMonth(snapshot, plant.shiftTimes, staffName)
                            if (stats.totalHours > 0.0) { // Mostrar solo personal con horas registradas
                                results.add(StaffMonthlyStats(staffName, stats.totalHours, stats.totalShifts))
                            }
                        }
                        // Ordenado de más a menos horas trabajadas (REQ. USUARIO)
                        allStaffStats = results.sortedByDescending { it.totalHours }
                        personalStats = null

                    } else {
                        // Usuario Regular O Supervisor: Vista Personal (selectedStaffName no es null)
                        val name = selectedStaffName ?: currentUserName
                        if (name != null) {
                            // Usamos el nombre del usuario seleccionado o el nombre del usuario logeado
                            personalStats = calculateStatsForMonth(snapshot, plant.shiftTimes, name)
                        } else {
                            personalStats = null
                        }
                        allStaffStats = emptyList() // Limpiar estadísticas generales si se está viendo personal
                    }

                    isLoading = false
                }

                override fun onCancelled(error: DatabaseError) {
                    isLoading = false
                }
            })
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(
                    text = if (isSupervisor && selectedStaffName != null) "Estadísticas de ${selectedStaffName}" else "Estadísticas",
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                ) },
                navigationIcon = {
                    IconButton(onClick = {
                        if (isSupervisor && selectedStaffName != null) {
                            // Si es supervisor y hay un usuario seleccionado, volvemos a la vista general
                            selectedStaffName = null
                        } else {
                            // En cualquier otro caso, volvemos a la pantalla anterior
                            onBack()
                        }
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Volver", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Selector de Mes
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF1E293B), RoundedCornerShape(12.dp))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { currentMonth = currentMonth.minusMonths(1); selectedStaffName = null }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
                }
                Text(
                    text = "${currentMonth.month.getDisplayName(TextStyle.FULL, Locale("es", "ES")).uppercase()} ${currentMonth.year}",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
                IconButton(onClick = { currentMonth = currentMonth.plusMonths(1); selectedStaffName = null }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Color.White)
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            if (isLoading) {
                CircularProgressIndicator(color = Color(0xFF54C7EC))
            } else if (isSupervisor && selectedStaffName == null) {
                // --- Supervisor Vista General de Personal ---
                SupervisorGeneralStats(
                    allStaffStats = allStaffStats,
                    onStaffSelected = { name -> selectedStaffName = name },
                )
            } else {
                // --- Vista Personal (Usuario Regular O Supervisor con usuario seleccionado) ---
                PersonalStatsView(
                    stats = personalStats,
                    targetName = selectedStaffName ?: currentUserName ?: "Personal",
                    isSupervisorViewing = isSupervisor && selectedStaffName != null
                )
            }
        }
    }
}

// ==============================================================================
// COMPOSABLES DE VISTA
// ==============================================================================

@Composable
fun SupervisorGeneralStats(
    allStaffStats: List<StaffMonthlyStats>,
    onStaffSelected: (String) -> Unit
) {
    if (allStaffStats.isEmpty()) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(top = 40.dp)) {
            Icon(Icons.Default.BarChart, null, tint = Color.Gray, modifier = Modifier.size(64.dp))
            Spacer(modifier = Modifier.height(16.dp))
            Text("No hay horas registradas para ningún personal este mes.", color = Color.Gray, textAlign = TextAlign.Center)
        }
        return
    }

    Text(
        "Horas Totales del Personal (General)",
        color = Color.White,
        fontWeight = FontWeight.Bold,
        fontSize = 20.sp,
        modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
    )

    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        // La lista ya está ordenada por horas de más a menos en el LaunchedEffect
        items(allStaffStats) { stats ->
            StaffStatRow(stats, onStaffSelected)
        }
    }
}

@Composable
fun StaffStatRow(stats: StaffMonthlyStats, onStaffSelected: (String) -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onStaffSelected(stats.staffName) },
        colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(stats.staffName, color = Color.White, fontWeight = FontWeight.Bold)
                Text("${stats.totalShifts} turnos", color = Color.Gray, fontSize = 12.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = String.format("%.1f h", stats.totalHours),
                    color = Color(0xFF54C7EC),
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp
                )
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = "Ver estadísticas de ${stats.staffName}",
                    tint = Color.Gray,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
fun PersonalStatsView(
    stats: MonthlyStats?,
    targetName: String,
    isSupervisorViewing: Boolean,
) {
    // Si es la vista personal del supervisor, mostramos un encabezado.
    if (isSupervisorViewing) {
        Text(
            "Desglose de Estadísticas",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )
    }

    if (stats == null || stats.totalHours == 0.0) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(top = 40.dp)) {
            Icon(Icons.Default.BarChart, null, tint = Color.Gray, modifier = Modifier.size(64.dp))
            Spacer(modifier = Modifier.height(16.dp))
            Text("No hay horas registradas este mes para $targetName.", color = Color.Gray, textAlign = TextAlign.Center)
        }
    } else {
        // Tarjeta Principal (Total)
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF0F172A)),
            border = BorderStroke(1.dp, Color(0xFF54C7EC))
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("Total Horas Trabajadas", color = Color(0xFF54C7EC), fontSize = 14.sp)
                Text(
                    text = String.format("%.1f h", stats.totalHours),
                    color = Color.White,
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold
                )
                Text("${stats.totalShifts} turnos realizados", color = Color.Gray)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            "Desglose por Turno",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth().wrapContentWidth(Alignment.Start)
        )
        Spacer(modifier = Modifier.height(12.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(stats.breakdown.entries.toList().sortedByDescending { it.value.hours }) { (shiftName, data) ->
                StatRow(shiftName, data)
            }
        }
    }
}

@Composable
fun StatRow(shiftName: String, data: ShiftStatData) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(shiftName, color = Color.White, fontWeight = FontWeight.Bold)
                Text("${data.count} turnos", color = Color.Gray, fontSize = 12.sp)
            }
            Text(
                text = String.format("%.1f h", data.hours),
                color = Color(0xFF54C7EC),
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp
            )
        }
    }
}

// ==============================================================================
// DATA CLASSES Y LÓGICA DE CÁLCULO (LÓGICA RESTAURADA A LA VERSIÓN ORIGINAL)
// ==============================================================================

data class MonthlyStats(
    val totalHours: Double,
    val totalShifts: Int,
    val breakdown: Map<String, ShiftStatData>
)

data class ShiftStatData(
    var hours: Double = 0.0,
    var count: Int = 0
)

// NUEVA DATA CLASS para la vista general del supervisor
data class StaffMonthlyStats(
    val staffName: String,
    val totalHours: Double,
    val totalShifts: Int
)

fun calculateStatsForMonth(
    snapshot: DataSnapshot,
    shiftTimes: Map<String, ShiftTime>,
    userName: String
): MonthlyStats {
    var totalH = 0.0
    var totalS = 0
    val breakdown = mutableMapOf<String, ShiftStatData>()

    snapshot.children.forEach { daySnapshot ->
        daySnapshot.children.forEach { shiftSnapshot ->
            val shiftName = shiftSnapshot.key ?: return@forEach
            val shiftTime = shiftTimes[shiftName]

            if (shiftTime != null) {
                // Se llama a la función calculateDuration original (solo dos parámetros)
                val duration = calculateDuration(shiftTime.start, shiftTime.end)
                var worked = false
                var halfDay = false

                // Revisar Enfermeros (Lógica restaurada)
                shiftSnapshot.child("nurses").children.forEach { slot ->
                    val p = slot.child("primary").value as? String
                    val s = slot.child("secondary").value as? String
                    val h = slot.child("halfDay").value as? Boolean == true

                    if (p == userName) { worked = true; halfDay = h }
                    else if (h && s == userName) { worked = true; halfDay = true }
                }

                // Revisar Auxiliares (Lógica restaurada)
                if (!worked) {
                    shiftSnapshot.child("auxiliaries").children.forEach { slot ->
                        val p = slot.child("primary").value as? String
                        val s = slot.child("secondary").value as? String
                        val h = slot.child("halfDay").value as? Boolean == true

                        if (p == userName) { worked = true; halfDay = h }
                        else if (h && s == userName) { worked = true; halfDay = true }
                    }
                }

                if (worked) {
                    val hoursToAdd = if (halfDay) duration / 2.0 else duration
                    totalH += hoursToAdd
                    totalS += 1

                    val stat = breakdown.getOrPut(shiftName) { ShiftStatData() }
                    stat.hours += hoursToAdd
                    stat.count += 1
                }
            }
        }
    }

    return MonthlyStats(totalH, totalS, breakdown)
}

fun calculateDuration(start: String, end: String): Double { // Función restaurada
    if (start.isBlank() || end.isBlank()) return 0.0
    try {
        val startTime = LocalTime.parse(start)
        val endTime = LocalTime.parse(end)
        var hours = Duration.between(startTime, endTime).toMinutes() / 60.0
        if (hours < 0) hours += 24.0 // Turno nocturno que cruza medianoche
        return hours
    } catch (e: Exception) {
        return 0.0
    }
}