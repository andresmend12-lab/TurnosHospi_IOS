package com.example.turnoshospi

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
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
                    onOpenSettings = onOpenSettings,
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
                    .padding(end = 8.dp, bottom = 16.dp),
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
                    Icon(Icons.Default.Edit, contentDescription = "Chats")
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
    isSupervisor: Boolean = false,
    roster: Map<String, ShiftRoster> = emptyMap(),
    isLoadingRoster: Boolean = false,
    shiftColors: ShiftColors,
    onDayClick: (LocalDate, UserShift?) -> Unit,
    onOpenSettings: () -> Unit = {}
) {
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    var selectedTab by remember { mutableStateOf(0) }
    val today = remember { LocalDate.now() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF0F172A),
                        Color(0xFF1E293B).copy(alpha = 0.5f),
                        Color(0xFF0F172A)
                    )
                )
            )
            .verticalScroll(rememberScrollState())
    ) {
        // ===== HEADER: Mi Planilla =====
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp, bottom = 8.dp, start = 20.dp, end = 20.dp)
        ) {
            Text(
                text = "Mi Planilla",
                style = MaterialTheme.typography.headlineSmall,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.CenterStart)
            )
            IconButton(
                onClick = onOpenSettings,
                modifier = Modifier.align(Alignment.CenterEnd)
            ) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "Configuración",
                    tint = Color(0xFF94A3B8),
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        // ===== TABS: Calendario | Estadísticas =====
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .background(Color(0x15FFFFFF), RoundedCornerShape(12.dp))
                .padding(4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            TabButton(
                text = "Calendario",
                isSelected = selectedTab == 0,
                onClick = { selectedTab = 0 },
                modifier = Modifier.weight(1f)
            )
            TabButton(
                text = "Estadísticas",
                isSelected = selectedTab == 1,
                onClick = { selectedTab = 1 },
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // ===== NAVEGACIÓN DEL MES =====
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "${currentMonth.month.getDisplayName(TextStyle.FULL, Locale.forLanguageTag("es-ES")).replaceFirstChar { it.uppercase() }} ${currentMonth.year}",
                color = Color.White,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Row {
                IconButton(
                    onClick = { currentMonth = currentMonth.minusMonths(1) },
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color(0x15FFFFFF), CircleShape)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Mes anterior",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = { currentMonth = currentMonth.plusMonths(1) },
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color(0x15FFFFFF), CircleShape)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = "Mes siguiente",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ===== DÍAS DE LA SEMANA =====
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            val daysOfWeek = listOf("L", "M", "X", "J", "V", "S", "D")
            daysOfWeek.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier.weight(1f),
                    color = Color(0xFF64748B),
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // ===== GRID DEL CALENDARIO =====
        val firstDayOfMonth = currentMonth.atDay(1)
        val daysInMonth = currentMonth.lengthOfMonth()
        val dayOfWeekOffset = firstDayOfMonth.dayOfWeek.value - 1
        val totalCells = (daysInMonth + dayOfWeekOffset + 6) / 7 * 7

        Column(modifier = Modifier.padding(horizontal = 12.dp)) {
            for (i in 0 until totalCells step 7) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    for (j in 0 until 7) {
                        val dayIndex = i + j - dayOfWeekOffset + 1
                        if (dayIndex in 1..daysInMonth) {
                            val date = currentMonth.atDay(dayIndex)
                            val shift = shifts[date.toString()]
                            val isSelected = date == selectedDate
                            val isToday = date == today
                            val dayColor = if (isSupervisor) Color.Transparent else getDayColor(date, shifts, shiftColors)

                            CalendarDayCell(
                                day = dayIndex,
                                isSelected = isSelected,
                                isToday = isToday,
                                shiftColor = dayColor,
                                hasShift = shift != null && !isSupervisor,
                                onClick = { onDayClick(date, shift) },
                                modifier = Modifier.weight(1f)
                            )
                        } else {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // ===== LEYENDA DE COLORES =====
        if (plantId != null && !isSupervisor) {
            Spacer(modifier = Modifier.height(16.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(Color(0x0AFFFFFF), RoundedCornerShape(16.dp))
                    .padding(12.dp)
            ) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    LegendItem(color = shiftColors.morning, label = "Mañana")
                    LegendItem(color = shiftColors.afternoon, label = "Tarde")
                    LegendItem(color = shiftColors.night, label = "Noche")
                    LegendItem(color = shiftColors.saliente, label = "Saliente")
                    LegendItem(color = shiftColors.holiday, label = "Vacaciones")
                    LegendItem(color = shiftColors.free, label = "Libre")
                }
            }
        }

        // ===== DETALLE DEL DÍA SELECCIONADO =====
        AnimatedVisibility(
            visible = selectedDate != null,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            selectedDate?.let { date ->
                val formatter = DateTimeFormatter.ofPattern("d 'de' MMMM", Locale.forLanguageTag("es-ES"))
                val dateStr = date.format(formatter)

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0x15FFFFFF)),
                    border = BorderStroke(1.dp, Color(0x20FFFFFF))
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp)
                    ) {
                        if (isSupervisor) {
                            // --- VISTA SUPERVISOR ---
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        text = dateStr,
                                        style = MaterialTheme.typography.titleMedium,
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = "Agenda del día",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = Color(0xFF64748B)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            if (isLoadingRoster) {
                                Box(
                                    modifier = Modifier.fillMaxWidth(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(32.dp),
                                        color = Color(0xFF54C7EC),
                                        strokeWidth = 3.dp
                                    )
                                }
                            } else if (roster.isEmpty()) {
                                EmptyStateMessage("No hay turnos asignados")
                            } else {
                                roster.forEach { (shiftName, data) ->
                                    ShiftRosterCard(
                                        shiftName = shiftName,
                                        nurses = data.nurses,
                                        auxiliaries = data.auxiliaries
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                }
                            }
                        } else {
                            // --- VISTA NORMAL ---
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        text = dateStr,
                                        style = MaterialTheme.typography.titleMedium,
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = selectedShift?.shiftName ?: "Libre",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = Color(0xFF54C7EC)
                                    )
                                }

                                Box(
                                    modifier = Modifier
                                        .size(48.dp)
                                        .background(
                                            if (selectedShift != null)
                                                getDayColor(date, shifts, shiftColors).copy(alpha = 0.3f)
                                            else Color(0x15FFFFFF),
                                            CircleShape
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = date.dayOfMonth.toString(),
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 18.sp
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))
                            HorizontalDivider(color = Color(0x15FFFFFF))
                            Spacer(modifier = Modifier.height(16.dp))

                            if (selectedShift == null) {
                                EmptyStateMessage("No tienes turno asignado")
                            } else if (isLoadingColleagues) {
                                Box(
                                    modifier = Modifier.fillMaxWidth(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(32.dp),
                                        color = Color(0xFF54C7EC),
                                        strokeWidth = 3.dp
                                    )
                                }
                            } else if (colleagues.isEmpty()) {
                                EmptyStateMessage("Sin compañeros asignados")
                            } else {
                                Text(
                                    text = "Compañeros en servicio",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = Color(0xFF64748B),
                                    modifier = Modifier.padding(bottom = 12.dp)
                                )
                                colleagues.forEach { colleague ->
                                    ColleagueCard(colleague = colleague)
                                    Spacer(modifier = Modifier.height(8.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(80.dp))
    }
}

// ===== COMPONENTES AUXILIARES =====

@Composable
private fun TabButton(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected) Color(0xFF54C7EC) else Color.Transparent,
        animationSpec = tween(300)
    )
    val textColor by animateColorAsState(
        targetValue = if (isSelected) Color.Black else Color(0xFF94A3B8),
        animationSpec = tween(300)
    )

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = textColor,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
            fontSize = 14.sp
        )
    }
}

@Composable
private fun CalendarDayCell(
    day: Int,
    isSelected: Boolean,
    isToday: Boolean,
    shiftColor: Color,
    hasShift: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.1f else 1f,
        animationSpec = spring()
    )

    val backgroundColor by animateColorAsState(
        targetValue = when {
            isSelected -> Color(0xFF54C7EC)
            hasShift -> shiftColor
            else -> Color.Transparent
        },
        animationSpec = tween(200)
    )

    Box(
        modifier = modifier
            .padding(3.dp)
            .aspectRatio(1f)
            .scale(scale)
            .clip(RoundedCornerShape(12.dp))
            .background(backgroundColor)
            .then(
                if (isToday && !isSelected) {
                    Modifier.border(2.dp, Color(0xFF54C7EC), RoundedCornerShape(12.dp))
                } else Modifier
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = day.toString(),
            color = when {
                isSelected -> Color.Black
                isToday -> Color(0xFF54C7EC)
                else -> Color.White
            },
            fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
            fontSize = 14.sp
        )
    }
}

@Composable
private fun LegendItem(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(horizontal = 4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .background(color, RoundedCornerShape(4.dp))
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = label,
            color = Color(0xFF94A3B8),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun EmptyStateMessage(message: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF64748B)
        )
    }
}

@Composable
private fun ColleagueCard(colleague: Colleague) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0x10FFFFFF), RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(Color(0xFF54C7EC).copy(alpha = 0.2f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                tint = Color(0xFF54C7EC),
                modifier = Modifier.size(20.dp)
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Text(
                text = colleague.name,
                color = Color.White,
                fontWeight = FontWeight.Medium,
                fontSize = 14.sp
            )
            Text(
                text = colleague.role,
                color = Color(0xFF64748B),
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun ShiftRosterCard(
    shiftName: String,
    nurses: List<String>,
    auxiliaries: List<String>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0x10FFFFFF), RoundedCornerShape(12.dp))
            .padding(12.dp)
    ) {
        Text(
            text = shiftName,
            style = MaterialTheme.typography.titleSmall,
            color = Color(0xFF54C7EC),
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))

        if (nurses.isNotEmpty()) {
            Text(
                text = "Enfermeros",
                color = Color(0xFF64748B),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium
            )
            nurses.forEach { name ->
                Text(
                    text = "• $name",
                    color = Color.White,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 8.dp, top = 2.dp)
                )
            }
        }

        if (auxiliaries.isNotEmpty()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = "Auxiliares",
                color = Color(0xFF64748B),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium
            )
            auxiliaries.forEach { name ->
                Text(
                    text = "• $name",
                    color = Color.White,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 8.dp, top = 2.dp)
                )
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