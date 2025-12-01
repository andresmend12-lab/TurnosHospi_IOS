package com.example.turnoshospi

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePickerState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.turnoshospi.ui.theme.ShiftColors
import com.example.turnoshospi.ui.theme.TurnoshospiTheme
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// Modelo de datos para la vista de supervisor (solo lectura)
data class ShiftRoster(
    val nurses: List<String>,
    val auxiliaries: List<String>
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainMenuScreen(
    modifier: Modifier = Modifier,
    userEmail: String,
    profile: UserProfile?,
    isLoadingProfile: Boolean,
    userPlant: Plant?,
    plantMembership: PlantMembership?,
    datePickerState: DatePickerState,
    shiftColors: ShiftColors,
    onCreatePlant: () -> Unit,
    onEditProfile: () -> Unit,
    onOpenPlant: () -> Unit,
    onOpenSettings: () -> Unit,
    onListenToShifts: (String, String, (Map<String, UserShift>) -> Unit) -> Unit,
    onFetchColleagues: (String, String, String, (List<Colleague>) -> Unit) -> Unit,
    onSignOut: () -> Unit,
    onOpenDirectChats: () -> Unit,
    unreadChatCount: Int = 0,
    unreadNotificationsCount: Int,
    onOpenNotifications: () -> Unit
) {
    var isMenuOpen by remember { mutableStateOf(false) }
    var userShifts by remember { mutableStateOf<Map<String, UserShift>>(emptyMap()) }

    var selectedDate by remember { mutableStateOf<LocalDate?>(null) }
    var selectedShift by remember { mutableStateOf<UserShift?>(null) }
    var colleaguesList by remember { mutableStateOf<List<Colleague>>(emptyList()) }
    var isLoadingColleagues by remember { mutableStateOf(false) }

    // Estados para la vista de Supervisor
    val database = remember { FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/") }
    var selectedDateRoster by remember { mutableStateOf<Map<String, ShiftRoster>>(emptyMap()) }
    var isLoadingRoster by remember { mutableStateOf(false) }
    val unassignedLabel = stringResource(id = R.string.staff_unassigned_option)

    LaunchedEffect(userPlant, plantMembership) {
        if (userPlant != null && plantMembership?.staffId != null) {
            onListenToShifts(userPlant.id, plantMembership.staffId) { shifts ->
                userShifts = shifts
            }
        }
    }

    val loadingName = stringResource(id = R.string.loading_profile)
    val displayName = when {
        !profile?.firstName.isNullOrBlank() -> profile?.firstName.orEmpty()
        isLoadingProfile -> loadingName
        !profile?.email.isNullOrBlank() -> profile?.email.orEmpty()
        else -> userEmail
    }

    val welcomeStringId = remember(profile?.gender) {
        if (profile?.gender == "female") R.string.main_menu_welcome_female else R.string.main_menu_welcome_male
    }

    val supervisorMale = stringResource(id = R.string.role_supervisor_male)
    val supervisorFemale = stringResource(id = R.string.role_supervisor_female)
    val showCreatePlant = profile?.role == supervisorMale || profile?.role == supervisorFemale
    val isSupervisor = showCreatePlant // Reutilizamos la lógica de rol

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Transparent)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(vertical = 12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp, bottom = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                // MENÚ LATERAL (IZQUIERDA)
                IconButton(
                    modifier = Modifier.align(Alignment.CenterStart),
                    onClick = { isMenuOpen = true }
                ) {
                    Icon(
                        imageVector = Icons.Default.Menu,
                        contentDescription = stringResource(id = R.string.side_menu_title),
                        tint = Color.White
                    )
                }

                // TÍTULO BIENVENIDA (CENTRO)
                Crossfade(targetState = displayName, animationSpec = tween(durationMillis = 600)) { name ->
                    Text(
                        text = stringResource(id = welcomeStringId, name),
                        modifier = Modifier.padding(horizontal = 56.dp),
                        style = MaterialTheme.typography.titleLarge,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.Bold
                    )
                }

                // NOTIFICACIONES GENERALES (DERECHA)
                IconButton(
                    modifier = Modifier.align(Alignment.CenterEnd),
                    onClick = onOpenNotifications
                ) {
                    BadgedBox(
                        badge = {
                            if (unreadNotificationsCount > 0) {
                                Badge(
                                    containerColor = Color(0xFFE91E63), // Color rojizo/rosa para destacar
                                    contentColor = Color.White
                                ) {
                                    Text(
                                        text = if (unreadNotificationsCount > 99) "99+" else unreadNotificationsCount.toString(),
                                        style = MaterialTheme.typography.labelSmall
                                    )
                                }
                            }
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.Notifications,
                            contentDescription = "Notificaciones",
                            tint = Color.White
                        )
                    }
                }
            }

            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(bottom = 16.dp),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF)),
                border = BorderStroke(1.dp, Color(0x22FFFFFF))
            ) {
                CustomCalendar(
                    shifts = userShifts,
                    plantId = userPlant?.id,
                    selectedDate = selectedDate,
                    selectedShift = selectedShift,
                    colleagues = colleaguesList,
                    isLoadingColleagues = isLoadingColleagues,
                    isSupervisor = isSupervisor,
                    roster = selectedDateRoster,
                    isLoadingRoster = isLoadingRoster,
                    shiftColors = shiftColors,
                    onDayClick = { date, shift ->
                        selectedDate = date
                        selectedShift = shift

                        // Limpiar estados anteriores
                        colleaguesList = emptyList()
                        selectedDateRoster = emptyMap()

                        if (isSupervisor && userPlant != null) {
                            // Lógica de Supervisor: Cargar todo el calendario del día
                            isLoadingRoster = true
                            val dateKey = date.toString()
                            database.reference.child("plants/${userPlant.id}/turnos/turnos-$dateKey")
                                .addListenerForSingleValueEvent(object : ValueEventListener {
                                    override fun onDataChange(snapshot: DataSnapshot) {
                                        val newRoster = mutableMapOf<String, ShiftRoster>()
                                        if (snapshot.exists()) {
                                            snapshot.children.forEach { shiftSnap ->
                                                val shiftName = shiftSnap.key ?: return@forEach

                                                // Función helper para parsear slots
                                                fun parseSlots(nodeName: String): List<String> {
                                                    return shiftSnap.child(nodeName).children.mapNotNull { slot ->
                                                        val p = slot.child("primary").value as? String
                                                        val s = slot.child("secondary").value as? String
                                                        val h = slot.child("halfDay").value as? Boolean == true

                                                        if (!p.isNullOrBlank() && p != unassignedLabel) {
                                                            if (h) "$p / ${if(!s.isNullOrBlank() && s != unassignedLabel) s else "LIBRE"}" else p
                                                        } else null
                                                    }
                                                }

                                                val nurses = parseSlots("nurses")
                                                val auxs = parseSlots("auxiliaries")

                                                if (nurses.isNotEmpty() || auxs.isNotEmpty()) {
                                                    newRoster[shiftName] = ShiftRoster(nurses, auxs)
                                                }
                                            }
                                        }
                                        // Ordenar visualmente (Mañana < Tarde < Noche)
                                        val order = listOf("Mañana", "Tarde", "Noche", "Dia", "Día")
                                        val sortedMap = newRoster.entries.sortedBy { (k, _) ->
                                            val idx = order.indexOfFirst { k.contains(it, true) }
                                            if (idx == -1) 99 else idx
                                        }.associate { it.key to it.value }

                                        selectedDateRoster = sortedMap
                                        isLoadingRoster = false
                                    }

                                    override fun onCancelled(error: DatabaseError) {
                                        isLoadingRoster = false
                                    }
                                })

                        } else if (userPlant != null && shift != null) {
                            // Lógica normal: Cargar compañeros del turno propio
                            isLoadingColleagues = true
                            onFetchColleagues(userPlant.id, date.toString(), shift.shiftName) { colleagues ->
                                colleaguesList = colleagues
                                isLoadingColleagues = false
                            }
                        } else {
                            // No hay turno y no es supervisor (o no hay planta)
                            isLoadingColleagues = false
                            isLoadingRoster = false
                        }
                    }
                )
            }
        }

        // --- MENU LATERAL (DRAWER) ---
        AnimatedVisibility(
            visible = isMenuOpen,
            enter = slideInHorizontally { -it } + fadeIn(),
            exit = slideOutHorizontally { -it } + fadeOut()
        ) {
            Row(modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .width(280.dp)
                        .fillMaxHeight()
                        .background(Color(0xFF0F172A), RoundedCornerShape(topEnd = 24.dp, bottomEnd = 24.dp))
                        .padding(vertical = 16.dp)
                ) {
                    DrawerHeader(displayName = displayName, welcomeStringId = welcomeStringId)
                    if (showCreatePlant) {
                        DrawerMenuItem(
                            label = stringResource(id = R.string.menu_create_plant),
                            description = stringResource(id = R.string.menu_create_plant_desc),
                            onClick = { isMenuOpen = false; onCreatePlant() }
                        )
                    }
                    DrawerMenuItem(
                        label = stringResource(id = R.string.menu_my_plants),
                        description = stringResource(id = R.string.menu_my_plants_desc),
                        onClick = { isMenuOpen = false; onOpenPlant() }
                    )
                    DrawerMenuItem(
                        label = stringResource(id = R.string.edit_profile),
                        description = stringResource(id = R.string.edit_profile),
                        onClick = { isMenuOpen = false; onEditProfile() }
                    )
                    DrawerMenuItem(
                        label = stringResource(id = R.string.menu_settings),
                        description = stringResource(id = R.string.menu_settings_desc),
                        onClick = { isMenuOpen = false; onOpenSettings() }
                    )
                    NavigationDrawerItem(
                        modifier = Modifier.padding(horizontal = 12.dp),
                        label = { Text(text = stringResource(id = R.string.sign_out), color = Color(0xFFFFB4AB)) },
                        selected = false,
                        onClick = { isMenuOpen = false; onSignOut() },
                        colors = NavigationDrawerItemDefaults.colors(
                            unselectedContainerColor = Color.Transparent,
                            unselectedTextColor = Color(0xFFFFB4AB)
                        )
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(Color(0x80000000))
                        .clickable { isMenuOpen = false }
                )
            }
        }

        // --- BOTÓN FLOTANTE PARA CHAT (ABAJO A LA DERECHA) ---
        // Solo visible si el usuario pertenece a una planta y el menú no está abierto
        if (userPlant != null && !isMenuOpen) {
            FloatingActionButton(
                onClick = onOpenDirectChats,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(horizontal= 20.dp,vertical = 40.dp),
                containerColor = Color(0xFF54C7EC),
                contentColor = Color.White,
                shape = CircleShape
            ) {
                // Mostramos badge si hay mensajes no leídos
                BadgedBox(
                    badge = {
                        if (unreadChatCount > 0) {
                            Badge(
                                containerColor = Color.Red,
                                contentColor = Color.White
                            ) {
                                Text(
                                    text = if (unreadChatCount > 99) "99+" else unreadChatCount.toString()
                                )
                            }
                        }
                    }
                ) {
                    Icon(Icons.Default.Chat, contentDescription = "Chats")
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CustomCalendar(
    shifts: Map<String, UserShift>,
    plantId: String?,
    selectedDate: LocalDate?,
    selectedShift: UserShift?,
    colleagues: List<Colleague>,
    isLoadingColleagues: Boolean,
    // Parametros para Supervisor
    isSupervisor: Boolean = false,
    roster: Map<String, ShiftRoster> = emptyMap(),
    isLoadingRoster: Boolean = false,
    shiftColors: ShiftColors,
    onDayClick: (LocalDate, UserShift?) -> Unit
) {
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F172A))
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { currentMonth = currentMonth.minusMonths(1) }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Mes anterior", tint = Color.White)
            }
            Text(
                text = "${currentMonth.month.getDisplayName(TextStyle.FULL, Locale.forLanguageTag("es-ES")).uppercase()} ${currentMonth.year}",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = { currentMonth = currentMonth.plusMonths(1) }) {
                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Mes siguiente", tint = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Row(modifier = Modifier.fillMaxWidth()) {
            val daysOfWeek = listOf("L", "M", "X", "J", "V", "S", "D")
            daysOfWeek.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier.weight(1f),
                    color = Color.Gray,
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        val firstDayOfMonth = currentMonth.atDay(1)
        val daysInMonth = currentMonth.lengthOfMonth()
        val dayOfWeekOffset = firstDayOfMonth.dayOfWeek.value - 1
        val totalCells = (daysInMonth + dayOfWeekOffset + 6) / 7 * 7

        Column {
            for (i in 0 until totalCells step 7) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (j in 0 until 7) {
                        val dayIndex = i + j - dayOfWeekOffset + 1
                        if (dayIndex in 1..daysInMonth) {
                            val date = currentMonth.atDay(dayIndex)
                            val dateKey = date.toString()
                            val shift = shifts[dateKey]

                            // CAMBIO: Usamos getDayColor pasando shiftColors
                            val color = if (isSupervisor) Color.Transparent else getDayColor(date, shifts, shiftColors)

                            val isSelected = date == selectedDate

                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .height(48.dp)
                                    .padding(2.dp)
                                    .background(
                                        color = color,
                                        shape = CircleShape
                                    )
                                    .border(
                                        width = if(isSelected) 2.dp else 0.dp,
                                        color = if(isSelected) Color.White else Color.Transparent,
                                        shape = CircleShape
                                    )
                                    .clickable {
                                        onDayClick(date, shift)
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = dayIndex.toString(),
                                    color = Color.White,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        } else {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
            }
        }

        // CAMBIO: Ocultamos leyenda si es supervisor, ya que no ve colores
        if (plantId != null && !isSupervisor) {
            Spacer(modifier = Modifier.height(20.dp))
            HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
            Spacer(modifier = Modifier.height(12.dp))

            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                maxItemsInEachRow = 4
            ) {
                val legendItems = listOf(
                    Triple(shiftColors.free, "Libre", null),
                    Triple(shiftColors.morning, "Mañana", null),
                    Triple(shiftColors.morningHalf, "M. Mañana", null),
                    Triple(shiftColors.afternoon, "Tarde", null),
                    Triple(shiftColors.afternoonHalf, "M. Tarde", null),
                    Triple(shiftColors.night, "Noche", null),
                    Triple(shiftColors.saliente, "Saliente", null),
                    Triple(shiftColors.holiday, "Vacaciones", null)
                )

                legendItems.forEach { (color, text, _) ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 6.dp)
                    ) {
                        Box(modifier = Modifier.size(10.dp).background(color, CircleShape))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(text = text, color = Color(0xFFCCCCCC), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }

        if (selectedDate != null) {
            Spacer(modifier = Modifier.height(24.dp))
            HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
            Spacer(modifier = Modifier.height(16.dp))

            val formatter = DateTimeFormatter.ofPattern("d 'de' MMMM", Locale.forLanguageTag("es-ES"))
            val dateStr = selectedDate.format(formatter)

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (isSupervisor) {
                    // --- VISTA DE SUPERVISOR (Detalle completo del día) ---
                    Text(
                        text = "Agenda del día: $dateStr",
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    if (isLoadingRoster) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(32.dp),
                            color = Color(0xFF54C7EC)
                        )
                    } else if (roster.isEmpty()) {
                        Text(
                            text = "No hay turnos asignados para este día.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.Gray
                        )
                    } else {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            roster.forEach { (shiftName, data) ->
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(Color(0x22FFFFFF), RoundedCornerShape(12.dp))
                                        .padding(12.dp)
                                ) {
                                    Text(
                                        text = shiftName,
                                        style = MaterialTheme.typography.titleSmall,
                                        color = Color(0xFF54C7EC),
                                        fontWeight = FontWeight.Bold
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    if (data.nurses.isNotEmpty()) {
                                        Text("Enfermeros:", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
                                        data.nurses.forEach {
                                            Text("• $it", color = Color.White, style = MaterialTheme.typography.bodySmall)
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                    }
                                    if (data.auxiliaries.isNotEmpty()) {
                                        Text("Auxiliares:", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
                                        data.auxiliaries.forEach {
                                            Text("• $it", color = Color.White, style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                }
                            }
                        }
                    }

                } else {
                    // --- VISTA NORMAL (Turno propio y compañeros) ---
                    Text(
                        text = "Turno: ${selectedShift?.shiftName ?: "Libre"}",
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = dateStr,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF54C7EC)
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    if (selectedShift == null) {
                        Text(
                            text = "No tienes turno asignado este día.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.Gray
                        )
                    } else if (isLoadingColleagues) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(32.dp),
                            color = Color(0xFF54C7EC)
                        )
                    } else {
                        if (colleagues.isEmpty()) {
                            Text(
                                text = "No se encontraron compañeros para este turno.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = Color.Gray
                            )
                        } else {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "Compañeros en servicio:",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color.Gray,
                                    modifier = Modifier.align(Alignment.Start)
                                )

                                colleagues.forEach { colleague ->
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .background(Color(0x22FFFFFF), RoundedCornerShape(8.dp))
                                            .padding(12.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Person,
                                            contentDescription = null,
                                            tint = Color(0xFF54C7EC),
                                            modifier = Modifier.size(20.dp)
                                        )
                                        Spacer(modifier = Modifier.width(12.dp))
                                        Column {
                                            Text(
                                                text = colleague.name,
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = Color.White,
                                                fontWeight = FontWeight.Medium
                                            )
                                            Text(
                                                text = colleague.role,
                                                style = MaterialTheme.typography.bodySmall,
                                                color = Color.Gray
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fun getDayColor(date: LocalDate, shifts: Map<String, UserShift>, colors: ShiftColors): Color {
    val dateKey = date.toString()
    val shift = shifts[dateKey]

    if (shift != null) {
        val type = shift.shiftName.lowercase()
        return when {
            type.contains("vacaciones") -> colors.holiday
            type.contains("noche") -> colors.night
            type.contains("media") && (type.contains("mañana") || type.contains("dia")) -> colors.morningHalf
            type.contains("mañana") || type.contains("día") -> colors.morning
            type.contains("media") && type.contains("tarde") -> colors.afternoonHalf
            type.contains("tarde") -> colors.afternoon
            else -> colors.morning
        }
    }

    val yesterdayKey = date.minusDays(1).toString()
    val yesterdayShift = shifts[yesterdayKey]
    if (yesterdayShift != null && yesterdayShift.shiftName.lowercase().contains("noche")) {
        return colors.saliente
    }

    return colors.free
}

@Composable
fun DrawerHeader(displayName: String, welcomeStringId: Int) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Image(
            painter = painterResource(id = R.mipmap.ic_logo_hospi_foreground),
            contentDescription = stringResource(id = R.string.app_name),
            modifier = Modifier.size(48.dp)
        )
        Crossfade(
            targetState = displayName,
            animationSpec = tween(durationMillis = 600)
        ) { name ->
            Text(
                text = stringResource(id = welcomeStringId, name),
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xCCFFFFFF)
            )
        }
    }
    HorizontalDivider(color = Color(0x22FFFFFF))
}

@Composable
fun DrawerMenuItem(label: String, description: String, onClick: () -> Unit) {
    NavigationDrawerItem(
        modifier = Modifier.padding(horizontal = 12.dp),
        label = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(text = label, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(
                    text = description,
                    color = Color(0xCCFFFFFF),
                    style = MaterialTheme.typography.bodySmall
                )
            }
        },
        selected = false,
        onClick = onClick,
        colors = NavigationDrawerItemDefaults.colors(
            unselectedContainerColor = Color.Transparent,
            unselectedTextColor = Color.White
        )
    )
}

@Preview(showBackground = true, backgroundColor = 0xFF0F172A)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainMenuScreenPreview() {
    TurnoshospiTheme {
        val previewDateState = rememberDatePickerState(initialSelectedDateMillis = System.currentTimeMillis())
        MainMenuScreen(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF0F172A)),
            userEmail = "demo@example.com",
            profile = UserProfile(
                firstName = "Ana",
                lastName = "Martínez",
                role = "Supervisora",
                email = "demo@example.com"
            ),
            isLoadingProfile = false,
            userPlant = null,
            plantMembership = null,
            datePickerState = previewDateState,
            shiftColors = ShiftColors(), // Mock colors
            onCreatePlant = {},
            onEditProfile = {},
            onOpenPlant = {},
            onOpenSettings = {},
            onListenToShifts = { _, _, _ -> },
            onFetchColleagues = { _, _, _, _ -> },
            onSignOut = {},
            onOpenDirectChats = {},
            unreadChatCount = 3,
            unreadNotificationsCount = 5,
            onOpenNotifications = {}
        )
    }
}