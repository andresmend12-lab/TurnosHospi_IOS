package com.example.turnoshospi

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.BeachAccess
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FactCheck
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DatePickerState
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.turnoshospi.ui.theme.TurnoshospiTheme
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import java.util.UUID

// Modelos de datos específicos de PlantDetailScreen
private class SlotAssignment(
    primaryName: String = "",
    secondaryName: String = "",
    hasHalfDay: Boolean = false
) {
    var primaryName by mutableStateOf(primaryName)
    var secondaryName by mutableStateOf(secondaryName)
    var hasHalfDay by mutableStateOf(hasHalfDay)
}

private data class ShiftAssignmentState(
    val nurseSlots: MutableList<SlotAssignment>,
    val auxSlots: MutableList<SlotAssignment>
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlantDetailScreen(
    plant: Plant?,
    datePickerState: DatePickerState,
    currentUserProfile: UserProfile?,
    currentMembership: PlantMembership?,
    onBack: () -> Unit,
    onAddStaff: (String, RegisteredUser, (Boolean) -> Unit) -> Unit,
    onEditStaff: (String, RegisteredUser, (Boolean) -> Unit) -> Unit,
    onOpenPlantSettings: () -> Unit,
    onOpenImportShifts: () -> Unit,
    onOpenChat: () -> Unit,
    onOpenShiftChange: () -> Unit,
    onOpenShiftMarketplace: () -> Unit,
    onOpenStatistics: () -> Unit,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit
) {
    var isMenuOpen by remember { mutableStateOf(false) }
    var showVacationDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val database = remember {
        FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
    }

    val selectedDate = datePickerState.selectedDateMillis?.let { millis ->
        Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
    }

    // --- LÓGICA DE ROLES ---
    val supervisorRoles = listOf(
        stringResource(id = R.string.role_supervisor_male),
        stringResource(id = R.string.role_supervisor_female)
    )
    val nurseRole = stringResource(id = R.string.role_nurse_generic)
    val nurseRoles = listOf(
        nurseRole,
        stringResource(id = R.string.role_nurse_male),
        stringResource(id = R.string.role_nurse_female)
    )
    val normalizedNurseRoles = remember(nurseRoles) { nurseRoles.map { it.normalizedRole() } }
    val auxRole = stringResource(id = R.string.role_aux_generic)
    val auxRoles = listOf(
        auxRole,
        stringResource(id = R.string.role_aux_male),
        stringResource(id = R.string.role_aux_female)
    )
    val normalizedAuxRoles = remember(auxRoles) { auxRoles.map { it.normalizedRole() } }
    val resolvedRole = currentMembership?.staffRole?.ifBlank { currentUserProfile?.role }
        ?: currentUserProfile?.role
    val isSupervisor = resolvedRole in supervisorRoles

    // --- ESTADOS DE DATOS ---
    val assignmentsByDate = remember(plant?.id) {
        mutableStateMapOf<String, MutableMap<String, ShiftAssignmentState>>()
    }
    val savedAssignmentsByDate = remember(plant?.id) {
        mutableStateMapOf<String, Boolean>()
    }
    val plantStaff = plant?.personal_de_planta?.values.orEmpty()
    val nurseStaff = remember(plantStaff, normalizedNurseRoles) {
        plantStaff.filter { member -> member.isNurseRole(normalizedNurseRoles) }
    }
    val auxStaff = remember(plantStaff, normalizedAuxRoles) {
        plantStaff.filter { member -> member.isAuxRole(normalizedAuxRoles) }
    }

    val nurseOptions = remember(nurseStaff) {
        nurseStaff.map { member -> member.displayName(nurseRole) }.sorted()
    }
    val auxOptions = remember(auxStaff) {
        auxStaff.map { member -> member.displayName(auxRole) }.sorted()
    }

    // --- MAPEO DE STAFF ID A USER ID (Para notificaciones) ---
    val staffIdToUserIdMap = remember { mutableStateMapOf<String, String>() }

    LaunchedEffect(plant?.id) {
        if (plant?.id != null) {
            database.reference.child("plants/${plant.id}/userPlants")
                .addListenerForSingleValueEvent(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        staffIdToUserIdMap.clear()
                        for (userSnapshot in snapshot.children) {
                            val userId = userSnapshot.key ?: continue
                            val staffId = userSnapshot.child("staffId").value as? String
                            if (staffId != null) {
                                staffIdToUserIdMap[staffId] = userId
                            }
                        }
                    }
                    override fun onCancelled(error: DatabaseError) {}
                })
        }
    }

    // --- ESTADOS DIALOGOS ---
    var showAddStaffDialog by remember { mutableStateOf(false) }
    var isSavingStaff by remember { mutableStateOf(false) }
    var showStaffListDialog by remember { mutableStateOf(false) }
    var staffName by remember { mutableStateOf("") }
    var staffRole by remember { mutableStateOf(nurseRole) }
    var addStaffError by remember { mutableStateOf<String?>(null) }

    Box(modifier = Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                // CAMBIO: Usar CenterAlignedTopAppBar en lugar de TopAppBar normal
                CenterAlignedTopAppBar(
                    title = {
                        Text(
                            text = plant?.name ?: stringResource(id = R.string.menu_my_plants),
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                        )
                    },
                    navigationIcon = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = { isMenuOpen = true }) {
                                Icon(
                                    imageVector = Icons.Default.Menu,
                                    contentDescription = stringResource(id = R.string.side_menu_title),
                                    tint = Color.White
                                )
                            }

                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        navigationIconContentColor = Color.White,
                        titleContentColor = Color.White
                    )
                )
            }
        ) { paddingValues ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .background(Color.Transparent)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(24.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF)),
                        border = BorderStroke(1.dp, Color(0x22FFFFFF))
                    ) {
                        PlantCalendar(
                            selectedDate = selectedDate,
                            onDateSelected = { newDate ->
                                datePickerState.selectedDateMillis = newDate
                                    .atStartOfDay(ZoneOffset.UTC)
                                    .toInstant()
                                    .toEpochMilli()
                            }
                        )
                    }

                    if (plant != null && selectedDate != null) {
                        val dateKey = selectedDate.toString()
                        val assignments = assignmentsByDate.getOrPut(dateKey) { mutableStateMapOf() }
                        val unassignedLabel = stringResource(id = R.string.staff_unassigned_option)

                        LaunchedEffect(plant.id, dateKey) {
                            database.reference
                                .child("plants")
                                .child(plant.id)
                                .child("turnos")
                                .child("turnos-$dateKey")
                                .addListenerForSingleValueEvent(object : ValueEventListener {
                                    override fun onDataChange(snapshot: DataSnapshot) {
                                        if (snapshot.exists()) {
                                            val loadedAssignments = mutableMapOf<String, ShiftAssignmentState>()
                                            snapshot.children.forEach { shiftSnapshot ->
                                                val shiftName = shiftSnapshot.key ?: return@forEach
                                                val nurseSlots = shiftSnapshot.child("nurses").children
                                                    .sortedBy { it.key?.toIntOrNull() ?: 0 }
                                                    .map { it.toSlotAssignment(unassignedLabel) }
                                                    .toMutableList()
                                                val auxSlots = shiftSnapshot.child("auxiliaries").children
                                                    .sortedBy { it.key?.toIntOrNull() ?: 0 }
                                                    .map { it.toSlotAssignment(unassignedLabel) }
                                                    .toMutableList()
                                                loadedAssignments[shiftName] = ShiftAssignmentState(
                                                    nurseSlots = mutableStateListOf(*nurseSlots.toTypedArray()),
                                                    auxSlots = mutableStateListOf(*auxSlots.toTypedArray())
                                                )
                                            }
                                            assignments.clear()
                                            assignments.putAll(loadedAssignments)
                                            savedAssignmentsByDate[dateKey] = true
                                        } else {
                                            savedAssignmentsByDate[dateKey] = false
                                        }
                                    }
                                    override fun onCancelled(error: DatabaseError) {
                                        savedAssignmentsByDate[dateKey] = false
                                    }
                                })
                        }

                        ShiftAssignmentsSection(
                            plant = plant,
                            assignments = assignments,
                            selectedDateLabel = formatPlantDate(selectedDate),
                            isSupervisor = isSupervisor,
                            isSavedForDate = savedAssignmentsByDate[dateKey] == true,
                            unassignedLabel = unassignedLabel,
                            nurseOptions = nurseOptions,
                            auxOptions = auxOptions,
                            onSaveAssignments = { states ->
                                saveShiftAssignments(
                                    database = database,
                                    plantId = plant.id,
                                    dateKey = dateKey,
                                    assignments = states,
                                    unassignedLabel = unassignedLabel,
                                    plantStaff = plantStaff,
                                    staffIdToUserIdMap = staffIdToUserIdMap,
                                    onSaveNotification = onSaveNotification
                                ) { success ->
                                    if (success) savedAssignmentsByDate[dateKey] = true
                                }
                            }
                        )
                    } else {
                        InfoMessage(message = stringResource(id = R.string.plant_detail_missing_data))
                    }
                }
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
                    DrawerHeader(displayName = plant?.name ?: "", welcomeStringId = R.string.side_menu_title)

                    if (isSupervisor) {
                        // OPCIONES DE SUPERVISOR
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Add, contentDescription = null, tint = Color(0xFF54C7EC), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(stringResource(id = R.string.plant_add_staff_option), color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = { isMenuOpen = false; showAddStaffDialog = true },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF54C7EC), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(stringResource(id = R.string.plant_staff_list_option), color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = { isMenuOpen = false; showStaffListDialog = true },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Settings, contentDescription = null, tint = Color.LightGray, modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Configuración de planta", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = { isMenuOpen = false; onOpenPlantSettings() },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Edit, contentDescription = null, tint = Color.LightGray, modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Importar Turnos", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = { isMenuOpen = false; onOpenImportShifts() },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )

                        // --- GESTIÓN DE CAMBIOS (SOLO SUPERVISOR) ---
                        // Reemplaza a Bolsa y Cambios para el supervisor
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.FactCheck, contentDescription = null, tint = Color(0xFFFFA726), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Gestión de Cambios", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = {
                                isMenuOpen = false
                                onOpenShiftChange() // Reutilizamos esta pantalla, que ya tiene lógica para supervisor
                            },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )


                        // --- OPCIÓN COMPARTIR PLANTA ---
                        HorizontalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.padding(vertical = 8.dp, horizontal = 12.dp))
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Share, contentDescription = null, tint = Color(0xFF54C7EC), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Invitar compañeros", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = {
                                isMenuOpen = false
                                if (plant != null) {
                                    sharePlantInvitation(context, plant.name, plant.id, plant.accessPassword)
                                }
                            },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                    }

                    HorizontalDivider(color = Color.White.copy(alpha = 0.2f), modifier = Modifier.padding(vertical = 8.dp, horizontal = 12.dp))

                    // --- OPCIÓN DE VACACIONES (Para todos) ---
                    if (currentMembership?.staffId != null) {
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.BeachAccess, contentDescription = null, tint = Color(0xFFE91E63), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Días de Vacaciones", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = { isMenuOpen = false; showVacationDialog = true },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                    }

                    // --- OPCIONES COMUNES ---

                    NavigationDrawerItem(
                        modifier = Modifier.padding(horizontal = 12.dp),
                        label = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.AutoMirrored.Filled.Chat, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(12.dp))
                                Text("Chat de grupo", color = Color.White)
                            }
                        },
                        selected = false,
                        onClick = {
                            isMenuOpen = false
                            onOpenChat()
                        },
                        colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                    )

                    // --- SI NO ES SUPERVISOR, VE LAS OPCIONES NORMALES ---
                    if (!isSupervisor) {
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.SwapHoriz, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Cambio de turnos", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = {
                                isMenuOpen = false
                                onOpenShiftChange()
                            },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )

                        // --- BOLSA DE TURNOS ---
                        NavigationDrawerItem(
                            modifier = Modifier.padding(horizontal = 12.dp),
                            label = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Assignment, null, tint = Color(0xFFFFC107), modifier = Modifier.size(20.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text("Bolsa de Turnos", color = Color.White)
                                }
                            },
                            selected = false,
                            onClick = {
                                isMenuOpen = false
                                onOpenShiftMarketplace()
                            },
                            colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                        )
                    }

                    // --- OPCIÓN ESTADÍSTICAS (Para todos) ---
                    NavigationDrawerItem(
                        modifier = Modifier.padding(horizontal = 12.dp),
                        label = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.AutoMirrored.Filled.ShowChart, null, modifier = Modifier.size(20.dp), tint = Color(0xFF54C7EC))
                                Spacer(modifier = Modifier.width(12.dp))
                                Text("Estadísticas", color = Color.White)
                            }
                        },
                        selected = false,
                        onClick = {
                            isMenuOpen = false
                            onOpenStatistics()
                        },
                        colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                    )

                    NavigationDrawerItem(
                        modifier = Modifier.padding(horizontal = 12.dp),
                        label = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(stringResource(id = R.string.back_to_menu), color = Color.White)
                            }
                        },
                        selected = false,
                        onClick = { isMenuOpen = false; onBack() },
                        colors = NavigationDrawerItemDefaults.colors(unselectedContainerColor = Color.Transparent)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }
                Box(
                    modifier = Modifier.weight(1f).fillMaxHeight().background(Color(0x80000000))
                        .clickable { isMenuOpen = false }
                )
            }
        }
    }

    if (showAddStaffDialog && plant != null) {
        AddStaffDialog(
            staffName = staffName,
            onStaffNameChange = { staffName = it },
            staffRole = staffRole,
            onStaffRoleChange = { staffRole = it },
            isSaving = isSavingStaff,
            errorMessage = addStaffError,
            onDismiss = { showAddStaffDialog = false; addStaffError = null; staffName = ""; staffRole = nurseRole },
            onConfirm = {
                if (staffName.isBlank()) {
                    addStaffError = context.getString(R.string.staff_dialog_error)
                } else {
                    isSavingStaff = true
                    addStaffError = null
                    val newStaff = RegisteredUser(UUID.randomUUID().toString(), staffName, staffRole, "", "plant_staff")
                    onAddStaff(plant.id, newStaff) { success ->
                        isSavingStaff = false
                        if (success) {
                            showAddStaffDialog = false; staffName = ""; staffRole = nurseRole
                        } else {
                            addStaffError = context.getString(R.string.staff_dialog_save_error)
                        }
                    }
                }
            }
        )
    }

    if (showStaffListDialog && plant != null) {
        StaffListDialog(
            plantName = plant.name,
            staff = plantStaff.toList(),
            isSupervisor = isSupervisor,
            onDismiss = { showStaffListDialog = false },
            onSaveEdit = { editedMember, callback -> onEditStaff(plant.id, editedMember, callback) }
        )
    }

    // --- NEW: DIALOG DE DÍAS DE VACACIONES ---
    if (showVacationDialog && plant != null && currentMembership?.staffId != null) {
        VacationDaysDialog(
            onDismiss = { showVacationDialog = false },
            onConfirm = { dates ->
                saveVacationDaysToFirebase(
                    context = context,
                    plantId = plant.id,
                    staffId = currentMembership.staffId,
                    staffName = currentMembership.staffName ?: currentUserProfile?.firstName.orEmpty(),
                    dates = dates,
                    onSaveNotification = onSaveNotification
                )
                showVacationDialog = false
            }
        )
    }
}

// -----------------------------------------------------------------------------
// LÓGICA DE COMPARTIR PLANTA
// -----------------------------------------------------------------------------
private fun sharePlantInvitation(context: Context, plantName: String, plantId: String, accessCode: String) {
    val message = """
        ¡Hola! Únete a la planta "$plantName" en Turnoshospi.
        
        ID de Planta: $plantId
        Código de acceso: $accessCode
        
        Descarga la app y únete desde el menú principal.
    """.trimIndent()

    val sendIntent: Intent = Intent().apply {
        action = Intent.ACTION_SEND
        putExtra(Intent.EXTRA_TEXT, message)
        type = "text/plain"
    }

    val shareIntent = Intent.createChooser(sendIntent, "Invitar compañeros vía:")
    context.startActivity(shareIntent)
}

// -----------------------------------------------------------------------------
// LÓGICA DE PERSISTENCIA DE ASIGNACIÓN DE TURNOS CON NOTIFICACIONES
// -----------------------------------------------------------------------------
private fun saveShiftAssignments(
    database: FirebaseDatabase,
    plantId: String,
    dateKey: String,
    assignments: Map<String, ShiftAssignmentState>,
    unassignedLabel: String,
    plantStaff: Collection<RegisteredUser>,
    staffIdToUserIdMap: Map<String, String>,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit,
    onComplete: (Boolean) -> Unit
) {
    val turnosRef = database.reference.child("plants/$plantId/turnos/turnos-$dateKey")

    // 1. LEER DATOS ANTIGUOS PARA COMPARAR
    turnosRef.addListenerForSingleValueEvent(object : ValueEventListener {
        override fun onDataChange(snapshot: DataSnapshot) {
            val oldNames = mutableSetOf<String>()
            if (snapshot.exists()) {
                snapshot.children.forEach { shiftSnapshot ->
                    // Enfermeros
                    shiftSnapshot.child("nurses").children.forEach { slot ->
                        val p = slot.child("primary").value as? String
                        val s = slot.child("secondary").value as? String
                        if (!p.isNullOrBlank() && p != unassignedLabel) oldNames.add(p)
                        if (!s.isNullOrBlank() && s != unassignedLabel) oldNames.add(s)
                    }
                    // Auxiliares
                    shiftSnapshot.child("auxiliaries").children.forEach { slot ->
                        val p = slot.child("primary").value as? String
                        val s = slot.child("secondary").value as? String
                        if (!p.isNullOrBlank() && p != unassignedLabel) oldNames.add(p)
                        if (!s.isNullOrBlank() && s != unassignedLabel) oldNames.add(s)
                    }
                }
            }

            // 2. PREPARAR DATOS NUEVOS
            val newNames = mutableSetOf<String>()
            val payload = assignments.mapValues { (_, state) ->
                val nurseList = state.nurseSlots.mapIndexed { i, s ->
                    val map = s.toFirebaseMap(unassignedLabel, "enfermero${i + 1}")
                    if (s.primaryName.isNotBlank() && s.primaryName != unassignedLabel) newNames.add(s.primaryName)
                    if (s.hasHalfDay && s.secondaryName.isNotBlank() && s.secondaryName != unassignedLabel) newNames.add(s.secondaryName)
                    map
                }
                val auxList = state.auxSlots.mapIndexed { i, s ->
                    val map = s.toFirebaseMap(unassignedLabel, "auxiliar${i + 1}")
                    if (s.primaryName.isNotBlank() && s.primaryName != unassignedLabel) newNames.add(s.primaryName)
                    if (s.hasHalfDay && s.secondaryName.isNotBlank() && s.secondaryName != unassignedLabel) newNames.add(s.secondaryName)
                    map
                }
                mapOf("nurses" to nurseList, "auxiliaries" to auxList)
            }

            // 3. GUARDAR
            turnosRef.setValue(payload).addOnSuccessListener {
                onComplete(true)

                // 4. NOTIFICACIONES
                val staffIdMap = plantStaff.associateBy { it.name }

                // A. Desasignados (Estaban antes y ahora no)
                val unassignedStaff = oldNames - newNames
                unassignedStaff.forEach { name ->
                    val staffId = staffIdMap[name]?.id
                    val userId = staffId?.let { staffIdToUserIdMap[it] }
                    if (userId != null) {
                        onSaveNotification(userId, "SHIFT_UNASSIGNED", "Se te ha desasignado del turno el $dateKey.", AppScreen.MainMenu.name, dateKey, {})
                    }
                }

                // B. Asignados/Actualizados (Están ahora)
                newNames.forEach { name ->
                    val staffId = staffIdMap[name]?.id
                    val userId = staffId?.let { staffIdToUserIdMap[it] }
                    if (userId != null) {
                        onSaveNotification(userId, "SHIFT_ASSIGNED_STAFF", "Tu turno para el $dateKey ha sido actualizado por el supervisor.", AppScreen.MainMenu.name, dateKey, {})
                    }
                }

            }.addOnFailureListener { onComplete(false) }
        }

        override fun onCancelled(error: DatabaseError) {
            onComplete(false)
        }
    })
}

// -----------------------------------------------------------------------------
// LÓGICA DE PERSISTENCIA DE VACACIONES
// -----------------------------------------------------------------------------

private fun saveVacationDaysToFirebase(
    context: Context,
    plantId: String,
    staffId: String,
    staffName: String,
    dates: List<String>,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit
) {
    if (dates.isEmpty()) {
        Toast.makeText(context, "No se seleccionó ninguna fecha.", Toast.LENGTH_SHORT).show()
        return
    }

    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
    val updates = mutableMapOf<String, Any?>()

    val vacationAssignment = mapOf(
        "nurses" to listOf(mapOf(
            "halfDay" to false,
            "primary" to staffName,
            "secondary" to "",
            "primaryLabel" to "Vacaciones",
            "secondaryLabel" to ""
        )),
        "auxiliaries" to emptyList<Any>()
    )

    dates.forEach { dateKey ->
        updates["plants/$plantId/turnos/turnos-$dateKey/Vacaciones"] = vacationAssignment
    }

    database.reference.updateChildren(updates)
        .addOnSuccessListener {
            Toast.makeText(context, "Días de vacaciones guardados.", Toast.LENGTH_LONG).show()
            dates.forEach { dateKey ->
                onSaveNotification(
                    FirebaseAuth.getInstance().currentUser?.uid ?: "",
                    "VACATION_SAVED",
                    "Tu día de vacaciones del $dateKey ha sido registrado.",
                    AppScreen.MainMenu.name,
                    dateKey,
                    {}
                )
            }
        }
        .addOnFailureListener {
            Toast.makeText(context, "Error al guardar vacaciones: ${it.message}", Toast.LENGTH_LONG).show()
        }
}

// -----------------------------------------------------------------------------
// DIÁLOGOS Y COMPONENTES AUXILIARES
// -----------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VacationDaysDialog(
    onDismiss: () -> Unit,
    onConfirm: (List<String>) -> Unit
) {
    val offeredDates = remember { mutableStateListOf<String>() }
    var showDatePicker by remember { mutableStateOf(false) }
    val initialDate = LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    val datePickerState = rememberDatePickerState(initialSelectedDateMillis = initialDate)
    val context = LocalContext.current

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val date = Instant.ofEpochMilli(millis).atZone(ZoneId.of("UTC")).toLocalDate()
                        val dateStr = date.toString()
                        if (date.isBefore(LocalDate.now())) {
                            Toast.makeText(context, "No puedes seleccionar días pasados.", Toast.LENGTH_SHORT).show()
                            return@TextButton
                        }
                        if (dateStr !in offeredDates) {
                            offeredDates.add(dateStr)
                            offeredDates.sortBy { it }
                        }
                    }
                    showDatePicker = false
                }) { Text("Añadir") }
            },
            dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("Cancelar") } }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Seleccionar Días de Vacaciones") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Selecciona los días que estarás de vacaciones:", color = Color.White)
                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), color = Color.White.copy(0.1f))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (offeredDates.isEmpty()) {
                        Text("No se han seleccionado días.", color = Color.Gray)
                    } else {
                        offeredDates.forEach { date ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.fillMaxWidth().background(Color(0x22FFFFFF), RoundedCornerShape(4.dp)).padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text(date, color = Color.White, modifier = Modifier.weight(1f))
                                Icon(Icons.Default.Close, "Eliminar", tint = Color(0xFFFFB4AB), modifier = Modifier.clickable { offeredDates.remove(date) }.size(16.dp))
                            }
                        }
                    }
                }
                OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.Add, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Añadir día")
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(offeredDates.toList()) },
                enabled = offeredDates.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE91E63), contentColor = Color.White)
            ) {
                Text("Confirmar (${offeredDates.size} días)")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
        containerColor = Color(0xFF0F172A),
        titleContentColor = Color.White,
        textContentColor = Color.White
    )
}

// -----------------------------------------------------------------------------
// IMPORTACIÓN DE CSV
// -----------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportShiftsScreen(
    plant: Plant? = null,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var isImporting by remember { mutableStateOf(false) }
    var importStatus by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            if (plant == null) {
                importStatus = "Error: No se ha cargado la información de la planta."
                isError = true
                return@let
            }
            isImporting = true
            importStatus = "Procesando archivo..."
            isError = false

            processCsvImport(context, it, plant) { success, message ->
                isImporting = false
                isError = !success
                importStatus = message
                if (success) {
                    Toast.makeText(context, "Turnos importados correctamente", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Importar Turnos", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        },
        containerColor = Color.Transparent
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0x22FFFFFF)),
                border = BorderStroke(1.dp, Color(0x33FFFFFF))
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Text("Opciones de importación", style = MaterialTheme.typography.titleMedium, color = Color.White)

                    Button(
                        onClick = { copyTemplateToDownloads(context) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black)
                    ) {
                        Text("Descargar plantilla")
                    }

                    HorizontalDivider(color = Color.White.copy(alpha = 0.1f))

                    Button(
                        onClick = {
                            importStatus = null
                            launcher.launch("text/*")
                        },
                        enabled = !isImporting,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black)
                    ) {
                        Text(if (isImporting) "Importando..." else "Importar turnos")
                    }

                    if (importStatus != null) {
                        Text(
                            text = importStatus.orEmpty(),
                            color = if (isError) Color(0xFFFFB4AB) else Color(0xFF4CAF50),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}

private fun processCsvImport(
    context: Context,
    uri: Uri,
    plant: Plant,
    onResult: (Boolean, String) -> Unit
) {
    try {
        val inputStream = context.contentResolver.openInputStream(uri)
        val reader = BufferedReader(InputStreamReader(inputStream))
        val lines = reader.readLines()
        reader.close()

        if (lines.isEmpty()) {
            onResult(false, "El archivo está vacío.")
            return
        }

        val updatesByDate = mutableMapOf<String, MutableMap<String, ShiftAssignmentState>>()
        val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
        val staffNames = plant.personal_de_planta.values.map { it.name.trim().lowercase() }.toSet()
        val validShifts = plant.shiftTimes.keys

        for ((index, line) in lines.drop(1).withIndex()) {
            if (line.isBlank()) continue
            val rowNum = index + 2
            val cols = line.split(",").map { it.trim() }

            if (cols.size < 4) {
                onResult(false, "Error en fila $rowNum: Formato incorrecto. Faltan columnas.")
                return
            }

            val dateStr = cols[0]
            val shiftName = cols[1]
            val role = cols[2]
            val primaryName = cols[3]
            val isHalfDay = if (cols.size > 4) cols[4].equals("Sí", ignoreCase = true) || cols[4].equals("Si", ignoreCase = true) || cols[4].equals("True", ignoreCase = true) else false
            val secondaryName = if (cols.size > 5) cols[5] else ""

            try {
                LocalDate.parse(dateStr)
            } catch (e: Exception) {
                onResult(false, "Error en fila $rowNum: Fecha inválida ($dateStr). Usa AAAA-MM-DD.")
                return
            }

            if (shiftName !in validShifts) {
                onResult(false, "Error en fila $rowNum: El turno '$shiftName' no existe en esta planta.")
                return
            }

            val isNurse = role.contains("Enfermero", ignoreCase = true)
            val isAux = role.contains("Auxiliar", ignoreCase = true)
            if (!isNurse && !isAux) {
                onResult(false, "Error en fila $rowNum: Rol '$role' desconocido. Usa 'Enfermero' o 'Auxiliar'.")
                return
            }

            if (primaryName.isNotBlank() && primaryName.lowercase() !in staffNames) {
                onResult(false, "Error en fila $rowNum: '$primaryName' no está registrado en el personal de la planta.")
                return
            }
            if (isHalfDay && secondaryName.isNotBlank() && secondaryName.lowercase() !in staffNames) {
                onResult(false, "Error en fila $rowNum: '$secondaryName' no está registrado en el personal de la planta.")
                return
            }

            val dateAssignments = updatesByDate.getOrPut(dateStr) { mutableMapOf() }
            val shiftState = dateAssignments.getOrPut(shiftName) {
                ShiftAssignmentState(mutableListOf(), mutableListOf())
            }

            val slot = SlotAssignment(primaryName, secondaryName, isHalfDay)
            if (isNurse) {
                shiftState.nurseSlots.add(slot)
            } else {
                shiftState.auxSlots.add(slot)
            }
        }

        val updates = mutableMapOf<String, Any>()
        updatesByDate.forEach { (dateKey, shiftsMap) ->
            val datePayload = shiftsMap.mapValues { (_, state) ->
                mapOf(
                    "nurses" to state.nurseSlots.mapIndexed { i, slot ->
                        slot.toFirebaseMap("Sin asignar", "enfermero${i + 1}")
                    },
                    "auxiliaries" to state.auxSlots.mapIndexed { i, slot ->
                        slot.toFirebaseMap("Sin asignar", "auxiliar${i + 1}")
                    }
                )
            }
            updates["plants/${plant.id}/turnos/turnos-$dateKey"] = datePayload
        }

        database.reference.updateChildren(updates)
            .addOnSuccessListener { onResult(true, "Importación completada con éxito.") }
            .addOnFailureListener { onResult(false, "Error al guardar en base de datos: ${it.message}") }

    } catch (e: Exception) {
        e.printStackTrace()
        onResult(false, "Error al leer el archivo: ${e.message}")
    }
}

private fun copyTemplateToDownloads(context: Context) {
    val fileName = "plantilla_importacion_turnos.csv"
    try {
        val inputStream = context.assets.open(fileName)
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val outFile = File(downloadsDir, fileName)
        FileOutputStream(outFile).use { output -> inputStream.copyTo(output) }
        Toast.makeText(context, "Plantilla guardada en Descargas", Toast.LENGTH_LONG).show()
    } catch (e: Exception) {
        e.printStackTrace()
        Toast.makeText(context, "Error al guardar: ${e.message}", Toast.LENGTH_SHORT).show()
    }
}

// -----------------------------------------------------------------------------
// COMPONENTES EXISTENTES Y HELPERS
// -----------------------------------------------------------------------------

@Composable
fun PlantCalendar(selectedDate: LocalDate?, onDateSelected: (LocalDate) -> Unit) {
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF0F172A), RoundedCornerShape(24.dp))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { currentMonth = currentMonth.minusMonths(1) }) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Anterior", tint = Color.White)
            }
            Text(
                text = "${currentMonth.month.getDisplayName(TextStyle.FULL, Locale.forLanguageTag("es-ES")).uppercase()} ${currentMonth.year}",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            IconButton(onClick = { currentMonth = currentMonth.plusMonths(1) }) {
                Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "Siguiente", tint = Color.White)
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
        Row(modifier = Modifier.fillMaxWidth()) {
            listOf("L", "M", "X", "J", "V", "S", "D").forEach { day ->
                Text(text = day, modifier = Modifier.weight(1f), color = Color.Gray, textAlign = TextAlign.Center, fontWeight = FontWeight.Bold)
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        val firstDay = currentMonth.atDay(1)
        val daysInMonth = currentMonth.lengthOfMonth()
        val offset = firstDay.dayOfWeek.value - 1
        val totalCells = (daysInMonth + offset + 6) / 7 * 7
        Column {
            for (i in 0 until totalCells step 7) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (j in 0 until 7) {
                        val dayIndex = i + j - offset + 1
                        if (dayIndex in 1..daysInMonth) {
                            val date = currentMonth.atDay(dayIndex)
                            val isSelected = date == selectedDate
                            Box(
                                modifier = Modifier
                                    .weight(1f).height(48.dp).padding(2.dp)
                                    .background(if (isSelected) Color(0xFF54C7EC) else Color.Transparent, CircleShape)
                                    .border(if (isSelected) 0.dp else 1.dp, if (isSelected) Color.White.copy(alpha = 0.1f) else Color.White.copy(alpha = 0.1f), CircleShape)
                                    .clickable { onDateSelected(date) },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(text = dayIndex.toString(), color = if (isSelected) Color.Black else Color.White, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                            }
                        } else {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
            }
        }
    }
}

@Composable
private fun InfoMessage(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
        border = BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text(text = message, color = Color.White, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

fun formatPlantDate(date: LocalDate): String {
    return date.format(DateTimeFormatter.ofPattern("d 'de' MMMM yyyy"))
}

@Composable
private fun StaffListDialog(
    plantName: String,
    staff: List<RegisteredUser>,
    isSupervisor: Boolean,
    onDismiss: () -> Unit,
    onSaveEdit: (RegisteredUser, (Boolean) -> Unit) -> Unit
) {
    val sortedStaff = remember(staff) { staff.sortedBy { it.name.lowercase() } }
    var memberInEdition by remember { mutableStateOf<RegisteredUser?>(null) }

    if (memberInEdition != null) {
        val member = memberInEdition!!
        var editName by remember { mutableStateOf(member.name) }
        var editRole by remember { mutableStateOf(member.role) }
        var isSaving by remember { mutableStateOf(false) }
        var editError by remember { mutableStateOf<String?>(null) }

        AddStaffDialog(
            staffName = editName, onStaffNameChange = { editName = it },
            staffRole = editRole, onStaffRoleChange = { editRole = it },
            isSaving = isSaving, errorMessage = editError,
            title = stringResource(id = R.string.edit_profile),
            confirmButtonText = stringResource(id = R.string.register_button),
            onDismiss = { memberInEdition = null },
            onConfirm = {
                if (editName.isBlank()) { editError = "El nombre es obligatorio" }
                else {
                    isSaving = true
                    onSaveEdit(member.copy(name = editName, role = editRole)) { if (it) memberInEdition = null else editError = "Error" }
                }
            }
        )
    } else {
        AlertDialog(
            onDismissRequest = onDismiss,
            confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(id = R.string.close_label)) } },
            title = { Text(stringResource(id = R.string.staff_list_dialog_title, plantName)) },
            text = {
                Column(modifier = Modifier.fillMaxWidth().height(350.dp).verticalScroll(rememberScrollState())) {
                    if (sortedStaff.isEmpty()) Text(stringResource(id = R.string.staff_list_dialog_empty))
                    else sortedStaff.forEach { member ->
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(member.name, style = MaterialTheme.typography.bodyLarge, color = Color.White)
                                Text(member.role, style = MaterialTheme.typography.bodyMedium, color = Color.White.copy(alpha = 0.7f))
                            }
                            if (isSupervisor) IconButton(onClick = { memberInEdition = member }) { Icon(Icons.Default.Edit, null, tint = Color(0xFF54C7EC)) }
                        }
                        HorizontalDivider(color = Color.White.copy(alpha = 0.2f))
                    }
                }
            },
            containerColor = Color(0xEE0B1021), titleContentColor = Color.White, textContentColor = Color.White
        )
    }
}

@Composable
private fun ShiftAssignmentsSection(
    plant: Plant, assignments: MutableMap<String, ShiftAssignmentState>, selectedDateLabel: String,
    isSupervisor: Boolean, isSavedForDate: Boolean, unassignedLabel: String,
    nurseOptions: List<String>, auxOptions: List<String>, onSaveAssignments: (Map<String, ShiftAssignmentState>) -> Unit
) {
    val allowAux = plant.staffScope.normalizedRole() == stringResource(id = R.string.staff_scope_with_aux).normalizedRole() ||
            plant.staffScope.contains("aux", ignoreCase = true) || auxOptions.isNotEmpty()

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(id = R.string.plant_shifts_for_date, selectedDateLabel), color = Color.White, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)

        val preferredOrder = if (plant.shiftDuration == stringResource(id = R.string.shift_duration_8h))
            listOf(stringResource(id = R.string.shift_morning), stringResource(id = R.string.shift_afternoon), stringResource(id = R.string.shift_night))
        else listOf(stringResource(id = R.string.shift_day), stringResource(id = R.string.shift_night))

        val orderedShifts = (preferredOrder.mapNotNull { k -> plant.shiftTimes[k]?.let { k to it } } + plant.shiftTimes.filterKeys { it !in preferredOrder }.toList()).ifEmpty { plant.shiftTimes.toList() }

        orderedShifts.forEach { (shiftName, timing) ->
            val nurseReq = plant.staffRequirements[shiftName] ?: 0
            val auxReq = if (allowAux) (plant.staffRequirements[shiftName] ?: 0).coerceAtLeast(1) else 0
            val state = assignments.getOrPut(shiftName) { ShiftAssignmentState(mutableStateListOf(), mutableStateListOf()) }
            ensureSlotSize(state.nurseSlots, nurseReq.coerceAtLeast(1))
            if (auxReq > 0) ensureSlotSize(state.auxSlots, auxReq) else state.auxSlots.clear()

            Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color(0x22000000)), border = BorderStroke(1.dp, Color(0x22FFFFFF))) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(id = R.string.plant_shift_item, shiftName, timing.start.ifEmpty { "--" }, timing.end.ifEmpty { "--" }), color = Color.White, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(stringResource(id = R.string.plant_staff_requirement_item, shiftName, nurseReq), color = Color(0xCCFFFFFF), style = MaterialTheme.typography.bodySmall)

                    state.nurseSlots.forEachIndexed { i, slot ->
                        val label = if (slot.hasHalfDay) stringResource(id = R.string.nurse_half_day_label) else stringResource(id = R.string.nurse_label, i + 1)
                        if (isSupervisor) EditableAssignmentRow(label, slot, nurseOptions, stringResource(id = R.string.nurse_half_day_label))
                        else ReadOnlyAssignmentRow(label, stringResource(id = R.string.nurse_half_day_label), slot, unassignedLabel)
                    }
                    if (allowAux) {
                        HorizontalDivider(color = Color(0x22FFFFFF))
                        state.auxSlots.forEachIndexed { i, slot ->
                            val label = if (slot.hasHalfDay) stringResource(id = R.string.aux_half_day_label) else stringResource(id = R.string.aux_label, i + 1)
                            if (isSupervisor) EditableAssignmentRow(label, slot, auxOptions, stringResource(id = R.string.aux_half_day_label))
                            else ReadOnlyAssignmentRow(label, stringResource(id = R.string.aux_half_day_label), slot, unassignedLabel)
                        }
                    }
                }
            }
        }
        if (isSupervisor) {
            Button(onClick = { onSaveAssignments(assignments) }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black)) {
                Text(if (isSavedForDate) stringResource(id = R.string.edit_assignments_action) else stringResource(id = R.string.save_assignments_action))
            }
        }
    }
}

@Composable
private fun EditableAssignmentRow(label: String, slot: SlotAssignment, options: List<String>, halfDayLabel: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Switch(checked = slot.hasHalfDay, onCheckedChange = { slot.hasHalfDay = it; if (!it) slot.secondaryName = "" }, modifier = Modifier.width(52.dp))
            StaffDropdownField(modifier = Modifier.weight(1f), label = label, selectedValue = slot.primaryName, options = options, enabled = true, onOptionSelected = { slot.primaryName = it }, includeUnassigned = true)
        }
        if (slot.hasHalfDay) {
            StaffDropdownField(modifier = Modifier.fillMaxWidth().padding(start = 60.dp), label = halfDayLabel, selectedValue = slot.secondaryName, options = options, enabled = true, onOptionSelected = { slot.secondaryName = it }, includeUnassigned = true)
        }
    }
}

private fun ensureSlotSize(list: MutableList<SlotAssignment>, expected: Int) {
    while (list.size < expected) list.add(SlotAssignment())
    if (list.size > expected) repeat(list.size - expected) { list.removeLastOrNull() }
}

private fun SlotAssignment.toFirebaseMap(unassigned: String, base: String) = mapOf(
    "halfDay" to hasHalfDay,
    "primary" to primaryName.ifBlank { unassigned },
    "secondary" to if (hasHalfDay) secondaryName.ifBlank { unassigned } else "",
    "primaryLabel" to base,
    "secondaryLabel" to if (hasHalfDay) "$base media jornada" else ""
)

private fun DataSnapshot.toSlotAssignment(unassigned: String): SlotAssignment {
    val h = child("halfDay").value as? Boolean ?: false
    val p = (child("primary").value as? String).orEmpty()
    val s = (child("secondary").value as? String).orEmpty()
    return SlotAssignment(if (p == unassigned) "" else p, if (s == unassigned) "" else s, h)
}

private fun String.normalizedRole() = trim().lowercase()
private fun RegisteredUser.displayName(def: String) = name.ifBlank { email.ifBlank { role.ifBlank { def } } }
private fun RegisteredUser.isNurseRole(roles: List<String>) = role.normalizedRole() in roles || role.normalizedRole().contains("enfermer")
private fun RegisteredUser.isAuxRole(roles: List<String>) = role.normalizedRole() in roles || role.normalizedRole().contains("auxiliar")

@Composable
private fun ReadOnlyAssignmentRow(label: String, halfDayLabel: String, slot: SlotAssignment, unassigned: String) {
    Column {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = Color(0xCCFFFFFF), fontWeight = FontWeight.SemiBold)
        Text(slot.primaryName.ifBlank { unassigned }, style = MaterialTheme.typography.bodyLarge, color = Color.White)
        if (slot.hasHalfDay) {
            Text(halfDayLabel, style = MaterialTheme.typography.bodyMedium, color = Color(0xCCFFFFFF), fontWeight = FontWeight.SemiBold)
            Text(slot.secondaryName.ifBlank { unassigned }, style = MaterialTheme.typography.bodyLarge, color = Color.White)
        }
    }
}

@Composable
private fun AddStaffDialog(
    staffName: String,
    onStaffNameChange: (String) -> Unit,
    staffRole: String,
    onStaffRoleChange: (String) -> Unit,
    isSaving: Boolean,
    errorMessage: String?,
    title: String = stringResource(id = R.string.staff_dialog_title),
    confirmButtonText: String = stringResource(id = R.string.staff_dialog_save_action),
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    val roles = listOf(stringResource(id = R.string.role_nurse_generic), stringResource(id = R.string.role_aux_generic))
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { Button(onClick = onConfirm, enabled = !isSaving, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B))) { Text(confirmButtonText, color = Color.White) } },
        dismissButton = { TextButton(onClick = onDismiss, enabled = !isSaving) { Text(stringResource(id = R.string.cancel_label)) } },
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(value = staffName, onValueChange = onStaffNameChange, label = { Text(stringResource(id = R.string.staff_dialog_name_label)) }, colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White, focusedBorderColor = Color(0xFF54C7EC), unfocusedBorderColor = Color(0x66FFFFFF)))
                Text(stringResource(id = R.string.staff_dialog_role_label), color = Color.White)
                roles.forEach { role ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = staffRole == role, onClick = { onStaffRoleChange(role) }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF54C7EC), unselectedColor = Color.White))
                        Text(role, color = Color.White)
                    }
                }
                if (errorMessage != null) Text(errorMessage, color = MaterialTheme.colorScheme.error)
            }
        },
        containerColor = Color(0xEE0B1021), titleContentColor = Color.White, textContentColor = Color.White
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StaffDropdownField(modifier: Modifier = Modifier, label: String, selectedValue: String, options: List<String>, enabled: Boolean, onOptionSelected: (String) -> Unit, includeUnassigned: Boolean = false) {
    var expanded by remember { mutableStateOf(false) }
    val unassigned = stringResource(id = R.string.staff_unassigned_option)
    val display = selectedValue.ifBlank { if (includeUnassigned) unassigned else "" }
    val menuOptions = if (includeUnassigned) listOf(unassigned) + options else options
    Box(modifier = modifier) {
        OutlinedTextField(
            value = display, onValueChange = {}, readOnly = true, enabled = enabled, label = { Text(label) },
            trailingIcon = { IconButton(onClick = { if (enabled) expanded = !expanded }) { Icon(Icons.Filled.ArrowDropDown, null, Modifier.rotate(if (expanded) 180f else 0f) ) } },
            modifier = Modifier.fillMaxWidth().clickable(enabled = enabled, indication = null, interactionSource = remember { MutableInteractionSource() }) { expanded = !expanded },
            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White, focusedBorderColor = Color(0xFF54C7EC), unfocusedBorderColor = Color(0x66FFFFFF))
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, modifier = Modifier.fillMaxWidth(), containerColor = Color(0xF00B1021)) {
            menuOptions.forEach { op -> DropdownMenuItem(text = { Text(op, color = Color.White) }, onClick = { onOptionSelected(if (op == unassigned) "" else op); expanded = false }) }
        }
    }
}