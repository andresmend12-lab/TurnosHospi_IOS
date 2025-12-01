package com.example.turnoshospi

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.ThumbDown
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.DialogProperties
import com.example.turnoshospi.ui.theme.ShiftColors
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.UUID

// ============================================================================================
// PANTALLA PRINCIPAL: ShiftChangeScreen
// ============================================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShiftChangeScreen(
    plantId: String,
    currentUser: UserProfile?,
    currentUserId: String,
    shiftColors: ShiftColors,
    onBack: () -> Unit,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Mis Turnos", "Gestión de Cambios", "Sugerencias")

    val context = LocalContext.current
    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")

    // --- ESTADOS DE DATOS ---
    val myShiftsMap = remember { mutableStateMapOf<LocalDate, String>() }
    val myShiftsList = remember { mutableStateListOf<MyShiftDisplay>() }
    val allRequests = remember { mutableStateListOf<ShiftChangeRequest>() }

    // Datos para el buscador ("Sugerencias")
    val plantStaffMap = remember { mutableStateMapOf<String, RegisteredUser>() }
    val staffNameMap = remember { mutableStateMapOf<String, String>() }
    val allPlantShifts = remember { mutableStateListOf<PlantShift>() }
    val userSchedules = remember { mutableStateMapOf<String, MutableMap<LocalDate, String>>() }

    var isLoading by remember { mutableStateOf(true) }

    // --- ESTADOS DE NAVEGACIÓN INTERNA ---
    var selectedRequestForSuggestions by remember { mutableStateOf<ShiftChangeRequest?>(null) }

    // --- DIÁLOGOS ---
    var showCreateDialog by remember { mutableStateOf(false) }
    var selectedShiftForRequest by remember { mutableStateOf<MyShiftDisplay?>(null) }

    // --- IDENTIDAD ---
    val isSupervisor = remember(currentUser) {
        currentUser?.role?.contains("Supervisor", ignoreCase = true) == true
    }
    // Nombre completo para comparaciones de "Fallback" (si el ID es UNREGISTERED)
    val currentUserName = remember(currentUser) {
        if (currentUser != null) "${currentUser.firstName} ${currentUser.lastName}".trim() else ""
    }

    // ========================================================================================
    // CARGA DE DATOS (Secuencial para evitar Race Conditions con IDs)
    // ========================================================================================
    LaunchedEffect(plantId, currentUser) {
        if (currentUser == null) return@LaunchedEffect
        val myName = "${currentUser.firstName} ${currentUser.lastName}".trim()

        // 1. CARGAR PERSONAL (Mapeo Nombre -> ID)
        database.getReference("plants/$plantId/personal_de_planta").get().addOnSuccessListener { snap ->
            plantStaffMap.clear()
            staffNameMap.clear()
            snap.children.forEach { child ->
                val u = child.getValue(RegisteredUser::class.java)
                if (u != null) {
                    plantStaffMap[child.key!!] = u
                    if (u.name.isNotBlank()) {
                        staffNameMap[u.name.trim().lowercase()] = child.key!!
                    }
                }
            }

            // 2. CARGAR TURNOS (Una vez tenemos el mapa de personal)
            // Cargamos un poco antes para tener contexto en la preview (15 días antes)
            val startDate = LocalDate.now().minusDays(15)
            val startKey = "turnos-$startDate"

            database.getReference("plants/$plantId/turnos")
                .orderByKey()
                .startAt(startKey)
                .limitToFirst(90) // Cargar 3 meses aprox
                .addValueEventListener(object : ValueEventListener {
                    override fun onDataChange(snapshot: DataSnapshot) {
                        myShiftsMap.clear()
                        myShiftsList.clear()
                        allPlantShifts.clear()
                        userSchedules.clear()

                        snapshot.children.forEach { dateSnapshot ->
                            val dateKey = dateSnapshot.key?.removePrefix("turnos-") ?: return@forEach
                            try {
                                val date = LocalDate.parse(dateKey)
                                dateSnapshot.children.forEach { shiftSnap ->
                                    val shiftNameOriginal = shiftSnap.key ?: ""

                                    // Función auxiliar para procesar cada slot (Enfermeros/Auxiliares)
                                    fun processSlot(slot: DataSnapshot, rolePrefix: String) {
                                        val name = slot.child("primary").value.toString()
                                        val secondaryName = slot.child("secondary").value.toString()
                                        val isHalfDay = slot.child("halfDay").value as? Boolean == true

                                        val displayShiftName = if (isHalfDay) "Media $shiftNameOriginal" else shiftNameOriginal

                                        // -> Procesar Primary
                                        if (name.isNotBlank() && name != "null" && !name.equals("sin asignar", ignoreCase = true)) {
                                            // INTENTAR OBTENER ID REAL
                                            val uid = staffNameMap[name.trim().lowercase()]
                                            val finalId = uid ?: "UNREGISTERED_$name"
                                            val role = if (plantStaffMap[finalId] != null) plantStaffMap[finalId]!!.role else rolePrefix

                                            // Guardar en Schedule Global
                                            if (!userSchedules.containsKey(finalId)) {
                                                userSchedules[finalId] = mutableMapOf()
                                            }
                                            userSchedules[finalId]!![date] = displayShiftName

                                            // Añadir a lista general
                                            allPlantShifts.add(PlantShift(finalId, name, role, date, displayShiftName))

                                            // Si es MI turno
                                            if (name.equals(myName, true)) {
                                                myShiftsMap[date] = displayShiftName
                                                if (!date.isBefore(LocalDate.now())) {
                                                    myShiftsList.add(MyShiftDisplay(dateKey, displayShiftName, date))
                                                }
                                            }
                                        }

                                        // -> Procesar Secondary
                                        if (secondaryName.isNotBlank() && secondaryName != "null" && !secondaryName.equals("sin asignar", ignoreCase = true)) {
                                            val uid = staffNameMap[secondaryName.trim().lowercase()]
                                            val finalId = uid ?: "UNREGISTERED_$secondaryName"
                                            val role = if (plantStaffMap[finalId] != null) plantStaffMap[finalId]!!.role else rolePrefix

                                            if (!userSchedules.containsKey(finalId)) {
                                                userSchedules[finalId] = mutableMapOf()
                                            }
                                            userSchedules[finalId]!![date] = displayShiftName

                                            allPlantShifts.add(PlantShift(finalId, secondaryName, role, date, displayShiftName))

                                            if (secondaryName.equals(myName, true)) {
                                                myShiftsMap[date] = displayShiftName
                                                if (!date.isBefore(LocalDate.now())) {
                                                    myShiftsList.add(MyShiftDisplay(dateKey, displayShiftName, date))
                                                }
                                            }
                                        }
                                    }

                                    shiftSnap.child("nurses").children.forEach { processSlot(it, "Enfermero/a") }
                                    shiftSnap.child("auxiliaries").children.forEach { processSlot(it, "Auxiliar") }
                                }
                            } catch (_: Exception) {}
                        }
                        // Ordenar listas
                        myShiftsList.sortBy { it.fullDate }
                        allPlantShifts.sortBy { it.date }
                        isLoading = false
                    }
                    override fun onCancelled(error: DatabaseError) { isLoading = false }
                })
        }

        // 3. CARGAR SOLICITUDES (Independiente)
        database.getReference("plants/$plantId/shift_requests")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    allRequests.clear()
                    snapshot.children.mapNotNull { it.getValue(ShiftChangeRequest::class.java) }
                        .filter {
                            it.status != RequestStatus.DRAFT // Solo cargar activas o historial
                        }
                        .forEach { allRequests.add(it) }
                }
                override fun onCancelled(error: DatabaseError) {}
            })
    }

    // Manejo del botón atrás nativo
    BackHandler(enabled = selectedRequestForSuggestions != null) {
        selectedRequestForSuggestions = null
    }

    // ========================================================================================
    // UI PRINCIPAL
    // ========================================================================================
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    if (selectedRequestForSuggestions != null)
                        Text("Buscador de Candidatos", color = Color.White, fontWeight = FontWeight.Bold)
                    else
                        Text("Gestión de Cambios", color = Color.White, fontWeight = FontWeight.Bold)
                },
                navigationIcon = {
                    IconButton(onClick = {
                        if (selectedRequestForSuggestions != null) selectedRequestForSuggestions = null
                        else onBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Volver", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier
            .fillMaxSize()
            .padding(paddingValues)) {

            // TABS (Solo si no soy Supervisor)
            if (selectedRequestForSuggestions == null && !isSupervisor) {
                TabRow(
                    selectedTabIndex = selectedTab,
                    containerColor = Color.Transparent,
                    contentColor = Color.White,
                    indicator = { tabPositions ->
                        TabRowDefaults.SecondaryIndicator(Modifier.tabIndicatorOffset(tabPositions[selectedTab]), color = Color(0xFF54C7EC))
                    }
                ) {
                    tabs.forEachIndexed { index, title ->
                        Tab(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            text = { Text(title, fontWeight = if (selectedTab == index) FontWeight.Bold else FontWeight.Normal, fontSize = 13.sp) }
                        )
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }

            Box(modifier = Modifier.fillMaxSize()) {
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF54C7EC))
                } else {
                    if (selectedRequestForSuggestions != null) {
                        // -----------------------------------------------------------
                        // VISTA: BUSCADOR DE CANDIDATOS (Para una solicitud específica)
                        // -----------------------------------------------------------
                        FullPlantShiftsList(
                            request = selectedRequestForSuggestions!!,
                            allShifts = allPlantShifts,
                            currentUserId = currentUserId,
                            userSchedules = userSchedules,
                            currentUserSchedule = myShiftsMap,
                            shiftColors = shiftColors, // Pasamos colores
                            onProposeSwap = { candidateShift ->
                                performDirectProposal(database, plantId, selectedRequestForSuggestions!!, candidateShift, onSaveNotification)
                                selectedRequestForSuggestions = null
                                Toast.makeText(context, "Solicitud enviada. Esperando aceptación del compañero.", Toast.LENGTH_LONG).show()
                            }
                        )
                    } else if (isSupervisor) {
                        // -----------------------------------------------------------
                        // VISTA: SUPERVISOR (Gestión Total)
                        // -----------------------------------------------------------
                        val supervisorRequests = allRequests.filter { it.status == RequestStatus.AWAITING_SUPERVISOR }
                        val myPersonalRequests = allRequests.filter {
                            (it.requesterId == currentUserId || it.requesterName.equals(currentUserName, ignoreCase = true)) &&
                                    it.status == RequestStatus.SEARCHING
                        }

                        ShiftManagementTab(
                            currentUserId = currentUserId,
                            currentUserName = currentUserName,
                            isSupervisor = isSupervisor,
                            userSchedules = userSchedules,
                            mySchedule = myShiftsMap,
                            openRequests = myPersonalRequests,
                            peerPendingRequests = emptyList(),
                            historyRequests = allRequests.filter { it.status == RequestStatus.APPROVED }, // Ocultar rechazados aquí también
                            supervisorRequests = supervisorRequests,
                            shiftColors = shiftColors, // Pasamos colores
                            onDeleteRequest = { req ->
                                deleteShiftRequest(database, plantId, req.id)
                                Toast.makeText(context, "Solicitud borrada", Toast.LENGTH_SHORT).show()
                            },
                            onAcceptByPartner = { },
                            onRejectByPartner = { },
                            onApproveBySupervisor = { req ->
                                approveSwapBySupervisor(database, plantId, req, {
                                    onSaveNotification(req.requesterId, "SHIFT_APPROVED", "Cambio aprobado por supervisor.", "ShiftChangeScreen", req.id, {})
                                    if (req.targetUserId != null && !req.targetUserId.startsWith("UNREGISTERED")) {
                                        onSaveNotification(req.targetUserId, "SHIFT_APPROVED", "Cambio aprobado por supervisor.", "ShiftChangeScreen", req.id, {})
                                    }
                                    Toast.makeText(context, "Cambio ejecutado y aprobado.", Toast.LENGTH_SHORT).show()
                                }, { err ->
                                    Toast.makeText(context, "Error: $err", Toast.LENGTH_SHORT).show()
                                })
                            },
                            onRejectBySupervisor = { req ->
                                updateRequestStatus(database, plantId, req.id, RequestStatus.REJECTED)
                                onSaveNotification(req.requesterId, "SHIFT_REJECTED", "El supervisor rechazó el cambio.", "ShiftChangeScreen", req.id, {})
                            }
                        )
                    } else {
                        // -----------------------------------------------------------
                        // VISTA: USUARIO NORMAL (Tabs)
                        // -----------------------------------------------------------
                        when (selectedTab) {
                            0 -> MyShiftsCalendarTab(
                                shifts = myShiftsList,
                                shiftColors = shiftColors, // Pasamos colores
                                onSelectShiftForChange = { shift ->
                                    selectedShiftForRequest = shift
                                    showCreateDialog = true
                                }
                            )
                            1 -> {
                                // --- LÓGICA DE FILTRADO (LAS 3 LISTAS) ---

                                // 1. Mis Búsquedas (Iniciadas por mí, estado SEARCHING)
                                val openRequests = allRequests.filter {
                                    val isMe = it.requesterId == currentUserId || it.requesterName.equals(currentUserName, ignoreCase = true)
                                    isMe && it.status == RequestStatus.SEARCHING
                                }

                                // 2. En Proceso (Pendientes Compañero O Pendientes Supervisor)
                                val peerPendingRequests = allRequests.filter {
                                    val isRequester = it.requesterId == currentUserId || it.requesterName.equals(currentUserName, ignoreCase = true)
                                    val isTarget = it.targetUserId == currentUserId || it.targetUserName.equals(currentUserName, ignoreCase = true)
                                    val relevantStatus = it.status == RequestStatus.PENDING_PARTNER || it.status == RequestStatus.AWAITING_SUPERVISOR

                                    relevantStatus && (isRequester || isTarget)
                                }

                                // 3. Historial (SOLO COMPLETADOS/APROBADOS) - Rechazados se ocultan
                                val historyRequests = allRequests.filter {
                                    val isRequester = it.requesterId == currentUserId || it.requesterName.equals(currentUserName, ignoreCase = true)
                                    val isTarget = it.targetUserId == currentUserId || it.targetUserName.equals(currentUserName, ignoreCase = true)

                                    (isRequester || isTarget) && (it.status == RequestStatus.APPROVED)
                                }

                                ShiftManagementTab(
                                    currentUserId = currentUserId,
                                    currentUserName = currentUserName,
                                    isSupervisor = isSupervisor,
                                    userSchedules = userSchedules,
                                    mySchedule = myShiftsMap,
                                    openRequests = openRequests,
                                    peerPendingRequests = peerPendingRequests,
                                    historyRequests = historyRequests,
                                    supervisorRequests = emptyList(),
                                    shiftColors = shiftColors, // Pasamos colores
                                    onDeleteRequest = { req ->
                                        deleteShiftRequest(database, plantId, req.id)
                                        Toast.makeText(context, "Solicitud borrada", Toast.LENGTH_SHORT).show()
                                    },
                                    onAcceptByPartner = { req ->
                                        updateRequestStatus(database, plantId, req.id, RequestStatus.AWAITING_SUPERVISOR)
                                        onSaveNotification(
                                            req.requesterId,
                                            "SHIFT_UPDATE",
                                            "Tu compañero ha aceptado el cambio. Pendiente de Supervisor.",
                                            "ShiftChangeScreen",
                                            req.id, {}
                                        )
                                    },
                                    onRejectByPartner = { req ->
                                        deleteShiftRequest(database, plantId, req.id)
                                        // Notificar solo si soy el destinatario rechazando (no si soy el solicitante cancelando)
                                        if (req.targetUserId == currentUserId || req.targetUserName.equals(currentUserName, ignoreCase = true)) {
                                            onSaveNotification(
                                                req.requesterId,
                                                "SHIFT_REJECTED",
                                                "El compañero rechazó el cambio.",
                                                "ShiftChangeScreen",
                                                req.id, {}
                                            )
                                        }
                                    },
                                    onApproveBySupervisor = { },
                                    onRejectBySupervisor = { }
                                )
                            }
                            2 -> MyRequestsForSuggestionsTab(
                                myRequests = allRequests.filter {
                                    (it.requesterId == currentUserId || it.requesterName.equals(currentUserName, ignoreCase = true)) &&
                                            it.status == RequestStatus.SEARCHING
                                },
                                onSeeCandidates = { req ->
                                    selectedRequestForSuggestions = req
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // Dialog para crear solicitud desde el calendario
    if (showCreateDialog && selectedShiftForRequest != null) {
        val shift = selectedShiftForRequest!!
        CreateShiftRequestDialog(
            shift = shift,
            onDismiss = { showCreateDialog = false },
            onConfirm = { offeredDates, mode ->
                val reqId = database.getReference("plants/$plantId/shift_requests").push().key ?: UUID.randomUUID().toString()
                val hardness = ShiftRulesEngine.calculateShiftHardness(shift.fullDate, shift.shiftName)

                val newRequest = ShiftChangeRequest(
                    id = reqId,
                    type = RequestType.SWAP,
                    status = RequestStatus.SEARCHING,
                    mode = mode,
                    hardnessLevel = hardness,
                    requesterId = currentUserId,
                    requesterName = "${currentUser?.firstName} ${currentUser?.lastName}",
                    requesterRole = currentUser?.role ?: "",
                    requesterShiftDate = shift.date,
                    requesterShiftName = shift.shiftName,
                    offeredDates = offeredDates
                )

                database.getReference("plants/$plantId/shift_requests/$reqId").setValue(newRequest)
                Toast.makeText(context, "Solicitud creada. Ve a 'Sugerencias' para buscar candidatos.", Toast.LENGTH_LONG).show()
                showCreateDialog = false
                selectedTab = 2 // Ir a sugerencias
            }
        )
    }
}

// ============================================================================================
// COMPONENTE: LISTA DE GESTIÓN (Las 3 Listas)
// ============================================================================================

@Composable
fun ShiftManagementTab(
    currentUserId: String,
    currentUserName: String,
    isSupervisor: Boolean,
    userSchedules: Map<String, Map<LocalDate, String>>,
    mySchedule: Map<LocalDate, String>,
    openRequests: List<ShiftChangeRequest>,
    peerPendingRequests: List<ShiftChangeRequest>,
    historyRequests: List<ShiftChangeRequest>,
    supervisorRequests: List<ShiftChangeRequest>,
    shiftColors: ShiftColors,
    onDeleteRequest: (ShiftChangeRequest) -> Unit,
    onAcceptByPartner: (ShiftChangeRequest) -> Unit,
    onRejectByPartner: (ShiftChangeRequest) -> Unit,
    onApproveBySupervisor: (ShiftChangeRequest) -> Unit,
    onRejectBySupervisor: (ShiftChangeRequest) -> Unit
) {
    // Estado para mostrar preview desde las tarjetas de gestión
    var previewReq by remember { mutableStateOf<ShiftChangeRequest?>(null) }
    var isPreviewSupervisorMode by remember { mutableStateOf(false) }

    LazyColumn(verticalArrangement = Arrangement.spacedBy(24.dp), contentPadding = PaddingValues(16.dp)) {

        // 1. SUPERVISOR (Prioridad Máxima)
        if (isSupervisor && supervisorRequests.isNotEmpty()) {
            item { Text("Pendientes de Aprobación (Supervisor)", color = Color(0xFFE91E63), fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            items(supervisorRequests) { req ->
                Card(colors = CardDefaults.cardColors(containerColor = Color(0x22E91E63))) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Confirmación de Cambio", color = Color.White, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.height(4.dp))
                        Text("${req.requesterName} (${req.requesterShiftDate})", color = Color(0xCCFFFFFF), fontSize = 13.sp)
                        Icon(Icons.Default.SwapHoriz, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        Text("${req.targetUserName} (${req.targetShiftDate})", color = Color(0xCCFFFFFF), fontSize = 13.sp)

                        Spacer(Modifier.height(12.dp))

                        // BOTÓN DE PREVIEW SUPERVISOR
                        Button(
                            onClick = {
                                previewReq = req
                                isPreviewSupervisorMode = true
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B)),
                            modifier = Modifier.fillMaxWidth().height(35.dp),
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Icon(Icons.Default.Visibility, null, modifier = Modifier.size(16.dp), tint = Color(0xFF54C7EC))
                            Spacer(Modifier.width(8.dp))
                            Text("Ver Simulación", color = Color(0xFF54C7EC), fontSize = 12.sp)
                        }

                        Spacer(Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                            TextButton(onClick = { onRejectBySupervisor(req) }) { Text("Rechazar", color = Color(0xFFFFB4AB)) }
                            Button(onClick = { onApproveBySupervisor(req) }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50))) { Text("Aprobar Cambio") }
                        }
                    }
                }
            }
        }

        // 2. EN PROCESO (ACCIÓN REQUERIDA O ESPERANDO)
        if (peerPendingRequests.isNotEmpty()) {
            item { Text("En Proceso", color = Color(0xFFFFA000), fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            items(peerPendingRequests) { req ->
                // Determinar si soy el destino por ID o por NOMBRE
                val amITarget = req.targetUserId == currentUserId || req.targetUserName.equals(currentUserName, ignoreCase = true)
                val isAwaitingSupervisor = req.status == RequestStatus.AWAITING_SUPERVISOR

                // Color logic
                val containerColor = when {
                    isAwaitingSupervisor -> Color(0x22E91E63) // Rosa/Morado para espera de supervisor
                    amITarget -> Color(0x224CAF50) // Verde si me toca responder
                    else -> Color(0x22FFA000) // Naranja si estoy esperando
                }

                Card(colors = CardDefaults.cardColors(containerColor = containerColor)) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (isAwaitingSupervisor) {
                                Icon(Icons.Default.Info, null, tint = Color(0xFFE91E63), modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("PENDIENTE DE APROBACIÓN DE SUPERVISOR", color = Color(0xFFE91E63), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            } else if (amITarget) {
                                Icon(Icons.Default.Info, null, tint = Color(0xFF4CAF50), modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("¡TE HAN PROPUESTO UN CAMBIO!", color = Color(0xFF4CAF50), fontWeight = FontWeight.ExtraBold, fontSize = 12.sp)
                            } else {
                                Icon(Icons.Default.Refresh, null, tint = Color(0xFFFFA000), modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("ESPERANDO RESPUESTA DE ${req.targetUserName?.uppercase() ?: "COMPAÑERO"}", color = Color(0xFFFFA000), fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            }
                        }
                        Spacer(Modifier.height(12.dp))

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("Origen", color = Color.Gray, fontSize = 10.sp)
                                Text(req.requesterName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text(req.requesterShiftDate, color = Color(0xCCFFFFFF), fontSize = 12.sp)
                            }
                            Icon(Icons.Default.SwapHoriz, null, tint = Color.White, modifier = Modifier.padding(horizontal = 8.dp))
                            Column(Modifier.weight(1f)) {
                                Text("Destino", color = Color.Gray, fontSize = 10.sp)
                                Text(req.targetUserName ?: "?", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text(req.targetShiftDate ?: "?", color = Color(0xCCFFFFFF), fontSize = 12.sp)
                            }
                        }

                        // BOTÓN PREVIEW PARA COMPAÑERO QUE DEBE ACEPTAR
                        if (amITarget && !isAwaitingSupervisor) {
                            Spacer(Modifier.height(12.dp))
                            Button(
                                onClick = {
                                    previewReq = req
                                    isPreviewSupervisorMode = false
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B)),
                                modifier = Modifier.fillMaxWidth().height(35.dp),
                                contentPadding = PaddingValues(0.dp)
                            ) {
                                Icon(Icons.Default.Visibility, null, modifier = Modifier.size(16.dp), tint = Color(0xFF54C7EC))
                                Spacer(Modifier.width(8.dp))
                                Text("Ver Simulación", color = Color(0xFF54C7EC), fontSize = 12.sp)
                            }
                        }

                        if (isAwaitingSupervisor) {
                            // Permitir cancelar incluso esperando supervisor (opcional, pero buena UX)
                            Spacer(Modifier.height(8.dp))
                            TextButton(onClick = { onDeleteRequest(req) }, modifier = Modifier.align(Alignment.End)) {
                                Text("Cancelar Solicitud", color = Color(0xFFFFB4AB), fontSize = 12.sp)
                            }
                        } else if (amITarget) {
                            Spacer(Modifier.height(16.dp))
                            Row(horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                                OutlinedButton(
                                    onClick = { onRejectByPartner(req) },
                                    border = BorderStroke(1.dp, Color(0xFFFFB4AB)),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFFFB4AB))
                                ) {
                                    Text("Rechazar")
                                }
                                Spacer(Modifier.width(8.dp))
                                Button(
                                    onClick = { onAcceptByPartner(req) },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black)
                                ) {
                                    Text("Aceptar Cambio")
                                }
                            }
                        } else {
                            Spacer(Modifier.height(8.dp))
                            TextButton(onClick = { onRejectByPartner(req) }, modifier = Modifier.align(Alignment.End)) {
                                Text("Cancelar Solicitud", color = Color(0xFFFFB4AB), fontSize = 12.sp)
                            }
                        }
                    }
                }
            }
        }

        // 3. MIS BÚSQUEDAS (INICIADOS)
        if (openRequests.isNotEmpty()) {
            item { Text("Mis Búsquedas Activas (Sin Candidato)", color = Color(0xFF54C7EC), fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            items(openRequests) { req ->
                Card(colors = CardDefaults.cardColors(containerColor = Color(0x1154C7EC)), border = BorderStroke(1.dp, Color(0x3354C7EC))) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Search, null, tint = Color(0xFF54C7EC), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Buscando candidato...", color = Color(0xFF54C7EC), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.weight(1f))
                            IconButton(onClick = { onDeleteRequest(req) }, modifier = Modifier.size(24.dp)) {
                                Icon(Icons.Default.Delete, null, tint = Color(0xFFFFB4AB), modifier = Modifier.size(16.dp))
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                        Text("Ofreces: ${req.requesterShiftDate} (${req.requesterShiftName})", color = Color.White, fontWeight = FontWeight.Bold)
                        Text("Ve a la pestaña 'Sugerencias' para proponer cambio.", color = Color.Gray, fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }
        }

        // 4. HISTORIAL
        if (historyRequests.isNotEmpty()) {
            item { Text("Historial (Completados)", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
            items(historyRequests) { req ->
                val statusText = "CAMBIO APROBADO"
                val statusColor = Color(0xFF4CAF50) // Verde

                Card(colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF))) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(8.dp).background(statusColor, CircleShape))
                            Spacer(Modifier.width(8.dp))
                            Text(statusText, color = statusColor, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.height(8.dp))

                        Text("${req.requesterName} ↔ ${req.targetUserName}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text("${req.requesterShiftDate} por ${req.targetShiftDate}", color = Color.Gray, fontSize = 12.sp)

                        // Botón de limpieza para historial antiguo
                        Spacer(Modifier.height(8.dp))
                        TextButton(onClick = { onDeleteRequest(req) }, modifier = Modifier.align(Alignment.End)) {
                            Text("Borrar del Historial", color = Color.Gray, fontSize = 11.sp)
                        }
                    }
                }
            }
        } else if (openRequests.isEmpty() && peerPendingRequests.isEmpty()) {
            item {
                Text("No tienes actividad reciente.", color = Color.Gray, modifier = Modifier.fillMaxWidth().padding(32.dp), textAlign = TextAlign.Center)
            }
        }
    }

    // LÓGICA DE VISUALIZACIÓN DE PREVIEW EN EL DIALOGO
    if (previewReq != null) {
        val req = previewReq!!

        val dateReq = LocalDate.parse(req.requesterShiftDate)
        val dateTarget = if(req.targetShiftDate != null) LocalDate.parse(req.targetShiftDate) else null

        // Preparar datos para las dos filas (Arriba y Abajo)
        // Usamos una data class auxiliar Quintuple definida al final
        val (row1Schedule, row1Name, row1DateOut, row1DateIn, row1ShiftIn) = if (isPreviewSupervisorMode) {
            // Supervisor: Fila 1 = Requester
            Quintuple(
                userSchedules[req.requesterId] ?: emptyMap(),
                req.requesterName,
                dateReq, // Pierde este día
                dateTarget, // Gana este día
                req.targetShiftName // Gana este turno
            )
        } else {
            // Partner Mode (Target User View): Fila 1 = YO (Target)
            Quintuple(
                mySchedule,
                "Yo",
                dateTarget, // Pierdo mi turno
                dateReq, // Gano su turno
                req.requesterShiftName // Gano su turno
            )
        }

        val (row2Schedule, row2Name, row2DateOut, row2DateIn, row2ShiftIn) = if (isPreviewSupervisorMode) {
            // Supervisor: Fila 2 = Target
            Quintuple(
                userSchedules[req.targetUserId] ?: emptyMap(),
                req.targetUserName ?: "?",
                dateTarget, // Pierde este día
                dateReq, // Gana este día
                req.requesterShiftName // Gana este turno
            )
        } else {
            // Partner Mode: Fila 2 = EL OTRO (Requester)
            Quintuple(
                userSchedules[req.requesterId] ?: emptyMap(),
                req.requesterName,
                dateReq, // Él pierde su turno
                dateTarget, // Él gana mi turno
                req.targetShiftName // Él gana mi turno
            )
        }

        SchedulePreviewDialog(
            onDismiss = { previewReq = null },
            row1Schedule = row1Schedule,
            row1Name = row1Name,
            row1DateToRemove = row1DateOut,
            row1DateToAdd = row1DateIn,
            row1ShiftToAdd = row1ShiftIn,
            row2Schedule = row2Schedule,
            row2Name = row2Name,
            row2DateToRemove = row2DateOut,
            row2DateToAdd = row2DateIn,
            row2ShiftToAdd = row2ShiftIn,
            shiftColors = shiftColors // <--- Param
        )
    }
}

// ============================================================================================
// COMPONENTE: LISTA DE SUGERENCIAS (Para buscar candidatos)
// ============================================================================================

@Composable
fun MyRequestsForSuggestionsTab(
    myRequests: List<ShiftChangeRequest>,
    onSeeCandidates: (ShiftChangeRequest) -> Unit
) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Text(
                "Busca candidatos para tus turnos",
                color = Color(0xFF54C7EC),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            Text(
                "Selecciona uno de tus turnos ofertados para ver quién puede cambiártelo.",
                color = Color.Gray,
                fontSize = 12.sp
            )
        }

        if (myRequests.isEmpty()) {
            item {
                Column(Modifier.fillMaxWidth().padding(top = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.Info, null, tint = Color.Gray, modifier = Modifier.size(48.dp))
                    Text("No tienes ofertas activas.", color = Color.Gray)
                    Text("Crea una en 'Mis Turnos' primero.", color = Color.Gray, fontSize = 12.sp)
                }
            }
        }

        items(myRequests) { req ->
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x2254C7EC)),
                border = BorderStroke(1.dp, Color(0x4454C7EC))
            ) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Ofreces el turno del:", color = Color(0xCCFFFFFF), fontSize = 12.sp)
                            Text("${req.requesterShiftDate} (${req.requesterShiftName})", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        }
                        Badge(containerColor = Color(0xFF54C7EC), contentColor = Color.Black) { Text("ACTIVA") }
                    }
                    Spacer(Modifier.height(16.dp))
                    Button(
                        onClick = { onSeeCandidates(req) },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Search, null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("VER CANDIDATOS COMPATIBLES")
                    }
                }
            }
        }
    }
}

// ============================================================================================
// COMPONENTE: LISTADO COMPLETO CON FILTROS (Cuando seleccionas "Ver Candidatos")
// ============================================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FullPlantShiftsList(
    request: ShiftChangeRequest,
    allShifts: List<PlantShift>,
    currentUserId: String,
    userSchedules: Map<String, Map<LocalDate, String>>,
    currentUserSchedule: Map<LocalDate, String>,
    shiftColors: ShiftColors,
    onProposeSwap: (PlantShift) -> Unit
) {
    // ESTADOS UI
    var filterDate by remember { mutableStateOf<LocalDate?>(null) }
    var filterPerson by remember { mutableStateOf<String?>(null) }
    var filterShiftType by remember { mutableStateOf<String?>(null) }

    var showDatePicker by remember { mutableStateOf(false) }
    var showPersonMenu by remember { mutableStateOf(false) }
    var showShiftMenu by remember { mutableStateOf(false) }

    // Estado para el Dialog de Preview
    var showPreviewDialog by remember { mutableStateOf(false) }
    var previewCandidate by remember { mutableStateOf<PlantShift?>(null) }

    // Personas disponibles (mismo rol)
    val availablePeople = remember(allShifts, request.requesterRole) {
        allShifts
            .filter { ShiftRulesEngine.areRolesCompatible(request.requesterRole, it.userRole) && it.userId != currentUserId }
            .map { it.userName }
            .distinct()
            .sorted()
    }

    // LÓGICA DE FILTRADO UNIFICADA
    val filteredShifts = remember(allShifts, request, currentUserId, filterDate, filterPerson, filterShiftType) {
        val today = LocalDate.now()
        val myDate = LocalDate.parse(request.requesterShiftDate)

        val mySimulatedSchedule = currentUserSchedule.filterKeys { it != myDate }

        allShifts.filter { shift ->
            val isFuture = !shift.date.isBefore(today)
            val isCompatibleRole = ShiftRulesEngine.areRolesCompatible(request.requesterRole, shift.userRole)
            val isNotMe = shift.userId != currentUserId

            val isSameExactShift = (
                    shift.date == myDate &&
                            shift.shiftName.trim().equals(request.requesterShiftName.trim(), ignoreCase = true)
                    )

            if (!isFuture || !isCompatibleRole || !isNotMe || isSameExactShift) return@filter false

            if (filterDate != null && shift.date != filterDate) return@filter false
            if (filterPerson != null && shift.userName != filterPerson) return@filter false
            if (filterShiftType != null && !shift.shiftName.contains(filterShiftType!!, ignoreCase = true)) return@filter false

            val errorForMe = ShiftRulesEngine.validateWorkRules(shift.date, shift.shiftName, mySimulatedSchedule)
            if (errorForMe != null) return@filter false

            val candidateSchedule = userSchedules[shift.userId] ?: emptyMap()
            val candidateSimulatedSchedule = candidateSchedule.filterKeys { it != shift.date }

            val errorForHim = ShiftRulesEngine.validateWorkRules(myDate, request.requesterShiftName, candidateSimulatedSchedule)
            if (errorForHim != null) return@filter false

            true
        }.sortedWith(compareBy({ it.date }, { it.shiftName }))
    }

    Column(Modifier.fillMaxSize()) {
        Card(
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0x3354C7EC))
        ) {
            Row(Modifier.padding(12.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Info, null, tint = Color(0xFF54C7EC))
                Spacer(Modifier.width(12.dp))
                Column {
                    Text("Candidatos Compatibles", color = Color.White, fontWeight = FontWeight.Bold)
                    Text("Turno del: ${request.requesterShiftDate}", color = Color(0xAAFFFFFF), fontSize = 12.sp)
                }
            }
        }

        // --- BARRA DE FILTROS (LazyRow) ---
        LazyRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 16.dp)
        ) {
            // 1. FECHA
            item {
                FilterChip(
                    selected = filterDate != null,
                    onClick = { showDatePicker = true },
                    label = { Text(if(filterDate != null) filterDate.toString() else "Fecha") },
                    leadingIcon = { Icon(Icons.Default.CalendarToday, null, Modifier.size(16.dp)) },
                    trailingIcon = if (filterDate != null) {
                        { Icon(Icons.Default.Close, "Borrar", Modifier.size(16.dp).clickable { filterDate = null }) }
                    } else null,
                    colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Color(0xFF54C7EC), selectedLabelColor = Color.Black)
                )
            }

            // 2. PERSONA
            item {
                Box {
                    FilterChip(
                        selected = filterPerson != null,
                        onClick = { showPersonMenu = true },
                        label = { Text(filterPerson ?: "Persona") },
                        leadingIcon = { Icon(Icons.Default.Person, null, Modifier.size(16.dp)) },
                        trailingIcon = if (filterPerson != null) {
                            { Icon(Icons.Default.Close, "Borrar", Modifier.size(16.dp).clickable { filterPerson = null }) }
                        } else null,
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Color(0xFF54C7EC), selectedLabelColor = Color.Black)
                    )
                    DropdownMenu(expanded = showPersonMenu, onDismissRequest = { showPersonMenu = false }) {
                        availablePeople.forEach { name ->
                            DropdownMenuItem(
                                text = { Text(name) },
                                onClick = { filterPerson = name; showPersonMenu = false }
                            )
                        }
                    }
                }
            }

            // 3. TURNO
            item {
                Box {
                    FilterChip(
                        selected = filterShiftType != null,
                        onClick = { showShiftMenu = true },
                        label = { Text(filterShiftType ?: "Turno") },
                        leadingIcon = { Icon(Icons.Default.Schedule, null, Modifier.size(16.dp)) },
                        trailingIcon = if (filterShiftType != null) {
                            { Icon(Icons.Default.Close, "Borrar", Modifier.size(16.dp).clickable { filterShiftType = null }) }
                        } else null,
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Color(0xFF54C7EC), selectedLabelColor = Color.Black)
                    )
                    DropdownMenu(expanded = showShiftMenu, onDismissRequest = { showShiftMenu = false }) {
                        listOf("Mañana", "Tarde", "Noche").forEach { type ->
                            DropdownMenuItem(
                                text = { Text(type) },
                                onClick = { filterShiftType = type; showShiftMenu = false }
                            )
                        }
                    }
                }
            }
        }

        if (showDatePicker) {
            val datePickerState = rememberDatePickerState()
            DatePickerDialog(
                onDismissRequest = { showDatePicker = false },
                confirmButton = {
                    TextButton(onClick = {
                        datePickerState.selectedDateMillis?.let {
                            filterDate = java.time.Instant.ofEpochMilli(it).atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                        }
                        showDatePicker = false
                    }) { Text("OK") }
                },
                dismissButton = {
                    TextButton(onClick = { showDatePicker = false }) { Text("Cancelar") }
                }
            ) {
                DatePicker(state = datePickerState)
            }
        }

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
        ) {
            if (filteredShifts.isEmpty()) {
                item {
                    Text(
                        text = "No se encontraron compañeros disponibles con estos filtros.",
                        color = Color.Gray,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(32.dp)
                    )
                }
            } else {
                items(filteredShifts) { shift ->
                    PlantShiftCard(
                        shift = shift,
                        shiftColors = shiftColors, // Pasamos colores
                        onAction = { onProposeSwap(shift) },
                        onPreview = {
                            previewCandidate = shift
                            showPreviewDialog = true
                        }
                    )
                }
            }
        }
    }

    if (showPreviewDialog && previewCandidate != null) {
        val candidate = previewCandidate!!
        val dateReq = LocalDate.parse(request.requesterShiftDate)

        // Simulación: Yo propongo (Row 1), a Candidato (Row 2)
        SchedulePreviewDialog(
            onDismiss = { showPreviewDialog = false },
            row1Schedule = currentUserSchedule,
            row1Name = "Yo",
            row1DateToRemove = dateReq,     // Doy mi turno
            row1DateToAdd = candidate.date, // Recibo su turno
            row1ShiftToAdd = candidate.shiftName,

            row2Schedule = userSchedules[candidate.userId] ?: emptyMap(),
            row2Name = candidate.userName,
            row2DateToRemove = candidate.date, // Él da su turno
            row2DateToAdd = dateReq,           // Él recibe mi turno
            row2ShiftToAdd = request.requesterShiftName,
            shiftColors = shiftColors // Param
        )
    }
}

// ============================================================================================
// COMPONENTE: TARJETA DE TURNO (Individual)
// ============================================================================================

@Composable
fun PlantShiftCard(
    shift: PlantShift,
    shiftColors: ShiftColors,
    onAction: () -> Unit,
    onPreview: () -> Unit // Callback para preview
) {
    // Usamos el color dinámico
    val shiftColor = getShiftColorDynamic(shift.shiftName, false, shiftColors)

    val initials = shift.userName.split(" ")
        .take(2)
        .mapNotNull { it.firstOrNull()?.toString() }
        .joinToString("")
        .uppercase()

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E293B)),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Row(modifier = Modifier.height(IntrinsicSize.Min)) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(6.dp)
                    .background(shiftColor)
            )

            Column(
                modifier = Modifier
                    .padding(8.dp) // Reducimos padding
                    .fillMaxWidth()
            ) {
                // Fila Superior: Avatar + Nombre
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp) // Avatar más pequeño
                            .background(Color(0xFF334155), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(text = initials, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = shift.userName,
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = shift.userRole,
                            color = Color(0xFF64748B),
                            fontSize = 11.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Fila Inferior: Info Turno + Botones
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // Info Turno
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Default.Schedule, null, tint = Color(0xFF94A3B8), modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "${shift.date} • ${shift.shiftName}",
                            color = Color(0xFF94A3B8),
                            fontSize = 12.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }

                    // Botones (Compactos)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = onPreview,
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF54C7EC)),
                            border = BorderStroke(1.dp, Color(0xFF54C7EC)),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                            modifier = Modifier.height(28.dp)
                        ) {
                            Text("Preview", fontSize = 11.sp)
                        }

                        Button(
                            onClick = onAction,
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC)),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                            modifier = Modifier.height(28.dp)
                        ) {
                            Text("Elegir", color = Color.Black, fontSize = 11.sp)
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================================
// COMPONENTE: DIÁLOGO DE PREVIEW (Actualizado: Ajuste de Altura y Tamaños)
// ============================================================================================

@Composable
fun SchedulePreviewDialog(
    onDismiss: () -> Unit,
    row1Schedule: Map<LocalDate, String>,
    row1Name: String,
    row1DateToRemove: LocalDate?,
    row1DateToAdd: LocalDate?,
    row1ShiftToAdd: String?,
    row2Schedule: Map<LocalDate, String>,
    row2Name: String,
    row2DateToRemove: LocalDate?,
    row2DateToAdd: LocalDate?,
    row2ShiftToAdd: String?,
    shiftColors: ShiftColors // <--- Param
) {
    val date1 = row1DateToRemove ?: LocalDate.now()
    val date2 = row1DateToAdd ?: date1

    val days1 = remember(date1) { (-5..5).map { date1.plusDays(it.toLong()) } }
    val days2 = remember(date2) { (-5..5).map { date2.plusDays(it.toLong()) } }

    AlertDialog(
        onDismissRequest = onDismiss,
        // CAMBIO: wrapContentHeight en lugar de fillMaxHeight(0.9f) para "recortar" abajo
        modifier = Modifier
            .fillMaxWidth(0.95f)
            .wrapContentHeight(),
        properties = DialogProperties(usePlatformDefaultWidth = false),
        containerColor = Color(0xFF0F172A),
        title = {
            // AJUSTE: Tamaño proporcional más moderado
            Text("Simulación del Cambio", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {

                // --- BLOQUE 1 ---
                Text(
                    text = "Alrededor del ${date1.format(DateTimeFormatter.ofPattern("dd 'de' MMMM", Locale("es", "ES")))}",
                    color = Color(0xFF54C7EC),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 8.dp)
                )

                ScheduleWeekView(
                    days = days1,
                    row1Schedule = row1Schedule,
                    row1Name = row1Name,
                    row1DateToRemove = row1DateToRemove,
                    row1DateToAdd = row1DateToAdd,
                    row1ShiftToAdd = row1ShiftToAdd,
                    row2Schedule = row2Schedule,
                    row2Name = row2Name,
                    row2DateToRemove = row2DateToRemove,
                    row2DateToAdd = row2DateToAdd,
                    row2ShiftToAdd = row2ShiftToAdd,
                    shiftColors = shiftColors
                )

                Spacer(modifier = Modifier.height(24.dp))
                HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
                Spacer(modifier = Modifier.height(16.dp))

                // --- BLOQUE 2 ---
                Text(
                    text = "Alrededor del ${date2.format(DateTimeFormatter.ofPattern("dd 'de' MMMM", Locale("es", "ES")))}",
                    color = Color(0xFF54C7EC),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 8.dp)
                )

                ScheduleWeekView(
                    days = days2,
                    row1Schedule = row1Schedule,
                    row1Name = row1Name,
                    row1DateToRemove = row1DateToRemove,
                    row1DateToAdd = row1DateToAdd,
                    row1ShiftToAdd = row1ShiftToAdd,
                    row2Schedule = row2Schedule,
                    row2Name = row2Name,
                    row2DateToRemove = row2DateToRemove,
                    row2DateToAdd = row2DateToAdd,
                    row2ShiftToAdd = row2ShiftToAdd,
                    shiftColors = shiftColors
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Cerrar", fontSize = 14.sp) }
        }
    )
}

@Composable
fun ScheduleWeekView(
    days: List<LocalDate>,
    row1Schedule: Map<LocalDate, String>,
    row1Name: String,
    row1DateToRemove: LocalDate?,
    row1DateToAdd: LocalDate?,
    row1ShiftToAdd: String?,
    row2Schedule: Map<LocalDate, String>,
    row2Name: String,
    row2DateToRemove: LocalDate?,
    row2DateToAdd: LocalDate?,
    row2ShiftToAdd: String?,
    shiftColors: ShiftColors // <--- Param
) {
    // CAMBIO: Celdas más pequeñas (38dp) y columna nombre más ancha (115dp)
    val nameColumnWidth = 115.dp
    val dayColumnWidth = 38.dp

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(bottom = 8.dp)) {
            Column {
                // Header Días
                Row {
                    Spacer(modifier = Modifier.width(nameColumnWidth))
                    days.forEach { date ->
                        val isRelevant = date == row1DateToRemove || date == row1DateToAdd
                        val textColor = if (isRelevant) Color(0xFF54C7EC) else Color.Gray
                        // AJUSTE: Fuentes proporcionales
                        Column(modifier = Modifier.width(dayColumnWidth), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(text = date.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale("es", "ES")).uppercase(), color = textColor, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            Text(text = "${date.dayOfMonth}", color = textColor, fontSize = 13.sp)
                        }
                    }
                }
                HorizontalDivider(color = Color.White.copy(0.1f))

                Spacer(modifier = Modifier.height(6.dp))

                // Fila 1
                ScheduleRow(
                    label = row1Name,
                    days = days,
                    schedule = row1Schedule,
                    dateToRemove = row1DateToRemove,
                    dateToAdd = row1DateToAdd,
                    shiftToAdd = row1ShiftToAdd,
                    nameWidth = nameColumnWidth,
                    cellWidth = dayColumnWidth,
                    shiftColors = shiftColors
                )
                Spacer(modifier = Modifier.height(8.dp))
                // Fila 2
                ScheduleRow(
                    label = row2Name,
                    days = days,
                    schedule = row2Schedule,
                    dateToRemove = row2DateToRemove,
                    dateToAdd = row2DateToAdd,
                    shiftToAdd = row2ShiftToAdd,
                    nameWidth = nameColumnWidth,
                    cellWidth = dayColumnWidth,
                    shiftColors = shiftColors
                )
            }
        }
    }
}

@Composable
fun ScheduleRow(
    label: String,
    days: List<LocalDate>,
    schedule: Map<LocalDate, String>,
    dateToRemove: LocalDate?,
    dateToAdd: LocalDate?,
    shiftToAdd: String?,
    nameWidth: androidx.compose.ui.unit.Dp,
    cellWidth: androidx.compose.ui.unit.Dp,
    shiftColors: ShiftColors // <--- Param
) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        // Nombre con más espacio
        Text(
            text = label,
            modifier = Modifier.width(nameWidth).padding(end = 8.dp),
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        days.forEach { date ->
            // 1. Calcular estado FINAL (Simulado)
            var finalShift = schedule[date] ?: ""
            var isChanged = false

            if (date == dateToRemove) {
                finalShift = ""
                isChanged = true
            }
            if (date == dateToAdd) {
                finalShift = shiftToAdd ?: ""
                isChanged = true
            }

            // Calcular turno anterior SIMULADO para determinar si es Saliente
            val prevDate = date.minusDays(1)
            var prevShift = schedule[prevDate] ?: ""
            if (prevDate == dateToRemove) prevShift = ""
            if (prevDate == dateToAdd) prevShift = shiftToAdd ?: ""

            val isSaliente = prevShift.contains("Noche", true) && finalShift.isBlank()

            // 2. Calcular estado ORIGINAL (para comparar y saber si resaltar)
            val originalCurrentShift = schedule[date] ?: ""
            val originalPrevShift = schedule[prevDate] ?: ""
            val originalIsSaliente = originalPrevShift.contains("Noche", true) && originalCurrentShift.isBlank()

            // 3. Determinar Highlight
            // Resaltamos si cambió el turno directo O si cambió el estado de saliente
            val isSalienteChanged = isSaliente != originalIsSaliente
            val shouldHighlight = isChanged || isSalienteChanged

            // COLOR DINÁMICO
            val baseColor = getShiftColorDynamic(finalShift, isSaliente, shiftColors)
            // Usamos shouldHighlight para el fondo en lugar de solo isChanged
            val cellColor = if (shouldHighlight) baseColor else Color.Transparent

            // LÓGICA MT/MM
            val lowerShift = finalShift.lowercase()
            val displayText = when {
                lowerShift.contains("media") && lowerShift.contains("tarde") -> "MT"
                lowerShift.contains("media") && lowerShift.contains("mañana") -> "MM"
                finalShift.isNotBlank() -> finalShift.take(1).uppercase()
                isSaliente -> "S"
                else -> "L"
            }

            // AJUSTE: Celdas de 38dp y fuente de 16sp
            Box(
                modifier = Modifier
                    .width(cellWidth)
                    .height(cellWidth)
                    .padding(2.dp)
                    .background(cellColor, RoundedCornerShape(6.dp))
                    .border(
                        if (shouldHighlight) 1.5.dp else 0.dp,
                        if (shouldHighlight) Color.White else Color.Transparent,
                        RoundedCornerShape(6.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(text = displayText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }
}

// ============================================================================================
// COMPONENTE: CALENDARIO DE MIS TURNOS
// ============================================================================================

@Composable
fun MyShiftsCalendarTab(
    shifts: List<MyShiftDisplay>,
    shiftColors: ShiftColors, // <--- Param
    onSelectShiftForChange: (MyShiftDisplay) -> Unit
) {
    var selectedDate by remember { mutableStateOf<LocalDate?>(null) }
    var currentMonth by remember { mutableStateOf(YearMonth.now()) }
    val shiftsMap = remember(shifts) { shifts.associateBy { it.fullDate } }

    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF)),
            border = BorderStroke(1.dp, Color(0x33FFFFFF))
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { currentMonth = currentMonth.minusMonths(1) }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White) }
                    Text("${currentMonth.month.getDisplayName(TextStyle.FULL, Locale("es", "ES")).uppercase()} ${currentMonth.year}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    IconButton(onClick = { currentMonth = currentMonth.plusMonths(1) }) { Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Color.White) }
                }
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                    listOf("L", "M", "X", "J", "V", "S", "D").forEach { Text(it, modifier = Modifier.weight(1f), color = Color.Gray, textAlign = TextAlign.Center, fontWeight = FontWeight.Bold) }
                }
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
                                    val shift = shiftsMap[date]
                                    val isSelected = date == selectedDate

                                    // COLOR DINÁMICO
                                    val color = getShiftColorDynamic(shift?.shiftName ?: "", false, shiftColors)

                                    Box(modifier = Modifier.weight(1f).height(48.dp).padding(2.dp).background(color, CircleShape).border(if (isSelected) 0.dp else 1.dp, if (isSelected) Color.White.copy(alpha = 0.1f) else Color.White.copy(alpha = 0.1f), CircleShape).clickable { selectedDate = date }, contentAlignment = Alignment.Center) {
                                        Text("$dayIndex", color = if (shift != null) Color.White else Color.White, fontWeight = if(shift!=null) FontWeight.Bold else FontWeight.Bold, fontSize = 18.sp)
                                    }
                                } else { Spacer(modifier = Modifier.weight(1f)) }
                            }
                        }
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(24.dp))
        AnimatedVisibility(visible = selectedDate != null) {
            val date = selectedDate!!
            val shift = shiftsMap[date]
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text(text = date.format(DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", Locale("es", "ES"))).replaceFirstChar { it.uppercase() }, color = Color(0xFF54C7EC), style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                if (shift != null) {
                    Text(text = "Turno actual: ${shift.shiftName}", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { onSelectShiftForChange(shift) }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black), modifier = Modifier.fillMaxWidth().height(50.dp)) {
                        Icon(Icons.Default.SwapHoriz, null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("BUSCAR CAMBIO", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                } else { Text("No tienes turno este día.", color = Color.Gray) }
            }
        }
    }
}

// ============================================================================================
// COMPONENTE: DIALOGO PARA CREAR SOLICITUD
// ============================================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateShiftRequestDialog(
    shift: MyShiftDisplay,
    onDismiss: () -> Unit,
    onConfirm: (List<String>, RequestMode) -> Unit
) {
    var selectedMode by remember { mutableStateOf(RequestMode.FLEXIBLE) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF0F172A),
        title = { Text("Solicitar Cambio Abierto", color = Color.White) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0x2254C7EC)),
                    border = BorderStroke(1.dp, Color(0x4454C7EC))
                ) {
                    Column(modifier = Modifier.padding(12.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Vas a ofrecer tu turno del:", color = Color(0xCCFFFFFF), fontSize = 12.sp)
                        Text("${shift.date} (${shift.shiftName})", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
                HorizontalDivider(color = Color.White.copy(0.1f))
                Column {
                    Text("Preferencia de Cambio:", color = Color.White, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = selectedMode == RequestMode.FLEXIBLE,
                            onClick = { selectedMode = RequestMode.FLEXIBLE },
                            label = { Text("Flexible") },
                            leadingIcon = if (selectedMode == RequestMode.FLEXIBLE) {{ Icon(Icons.Filled.Done, null, modifier = Modifier.size(16.dp)) }} else null,
                            modifier = Modifier.weight(1f)
                        )
                        FilterChip(
                            selected = selectedMode == RequestMode.STRICT,
                            onClick = { selectedMode = RequestMode.STRICT },
                            label = { Text("Estricto") },
                            leadingIcon = if (selectedMode == RequestMode.STRICT) {{ Icon(Icons.Filled.Done, null, modifier = Modifier.size(16.dp)) }} else null,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    Text(
                        text = if(selectedMode == RequestMode.FLEXIBLE) "Se buscará cualquier compañero compatible." else "Se priorizará a quienes te deben turnos.",
                        color = Color.Gray,
                        fontSize = 12.sp,
                        lineHeight = 14.sp
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { onConfirm(emptyList(), selectedMode) },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC), contentColor = Color.Black),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("PUBLICAR SOLICITUD ABIERTA")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("Cancelar") }
        }
    )
}

// ============================================================================================
// HELPERS Y LÓGICA DE NEGOCIO
// ============================================================================================

// Helper para colores dinámicos (reemplaza a getShiftColorExact)
fun getShiftColorDynamic(shiftName: String, isSaliente: Boolean = false, colors: ShiftColors): Color {
    if (isSaliente) return colors.saliente
    if (shiftName.isBlank()) return colors.free

    val lower = shiftName.lowercase()
    return when {
        lower.contains("vacaciones") -> colors.holiday
        lower.contains("noche") -> colors.night
        lower.contains("media") && lower.contains("mañana") -> colors.morningHalf
        lower.contains("mañana") -> colors.morning
        lower.contains("media") && lower.contains("tarde") -> colors.afternoonHalf
        lower.contains("tarde") -> colors.afternoon
        lower.contains("día") || lower.contains("dia") -> colors.morning
        else -> colors.free
    }
}

// Mantenemos esta función para compatibilidad si fuera necesaria en otros archivos,
// pero internamente delegamos al dinámico con colores default
fun getShiftColorExact(shiftName: String, isSaliente: Boolean = false): Color {
    return getShiftColorDynamic(shiftName, isSaliente, ShiftColors())
}

fun performDirectProposal(
    database: FirebaseDatabase,
    plantId: String,
    myReq: ShiftChangeRequest,
    targetShift: PlantShift,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit
) {
    val updates = mapOf(
        "plants/$plantId/shift_requests/${myReq.id}/status" to RequestStatus.PENDING_PARTNER,
        "plants/$plantId/shift_requests/${myReq.id}/targetUserId" to targetShift.userId,
        "plants/$plantId/shift_requests/${myReq.id}/targetUserName" to targetShift.userName,
        "plants/$plantId/shift_requests/${myReq.id}/targetShiftDate" to targetShift.date.toString(),
        "plants/$plantId/shift_requests/${myReq.id}/targetShiftName" to targetShift.shiftName
    )

    database.reference.updateChildren(updates).addOnSuccessListener {
        onSaveNotification(
            targetShift.userId,
            "SHIFT_PROPOSAL",
            "${myReq.requesterName} te propone cambiar tu turno del ${targetShift.date} por el suyo del ${myReq.requesterShiftDate}.",
            "ShiftChangeScreen",
            myReq.id,
            {}
        )
    }
}

fun rejectSwapProposal(
    database: FirebaseDatabase,
    plantId: String,
    requestId: String
) {
    deleteShiftRequest(database, plantId, requestId)
}

fun updateRequestStatus(
    database: FirebaseDatabase,
    plantId: String,
    requestId: String,
    newStatus: RequestStatus
) {
    database.reference.child("plants/$plantId/shift_requests/$requestId/status").setValue(newStatus)
}

fun approveSwapBySupervisor(
    database: FirebaseDatabase,
    plantId: String,
    req: ShiftChangeRequest,
    onSuccess: () -> Unit,
    onError: (String) -> Unit
) {
    if (req.targetUserId == null || req.targetShiftDate == null || req.targetShiftName == null) {
        onError("Datos de intercambio incompletos.")
        return
    }

    val requesterDayRef = database.reference.child("plants/$plantId/turnos/turnos-${req.requesterShiftDate}")
    val targetDayRef = database.reference.child("plants/$plantId/turnos/turnos-${req.targetShiftDate}")

    requesterDayRef.addListenerForSingleValueEvent(object : ValueEventListener {
        override fun onDataChange(snapA: DataSnapshot) {
            targetDayRef.addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapB: DataSnapshot) {

                    // Helper para obtener datos completos del slot (path y si es media jornada)
                    data class SlotInfo(val path: String, val isHalfDay: Boolean, val fullSlotKey: String, val group: String)

                    fun findSlotInfo(snapshot: DataSnapshot, shiftName: String, userName: String): SlotInfo? {
                        // Limpiamos "Media " si viene de la UI para buscar el nodo real
                        val realShiftName = shiftName.replace("Media ", "").trim()
                        val shiftRef = snapshot.child(realShiftName)
                        val groups = listOf("nurses", "auxiliaries")

                        for (group in groups) {
                            shiftRef.child(group).children.forEach { slot ->
                                val p = slot.child("primary").value.toString()
                                val s = slot.child("secondary").value.toString()
                                val half = slot.child("halfDay").value as? Boolean == true

                                if (p == userName) {
                                    return SlotInfo("$realShiftName/$group/${slot.key}/primary", half, slot.key!!, group)
                                }
                                if (s == userName) {
                                    return SlotInfo("$realShiftName/$group/${slot.key}/secondary", half, slot.key!!, group)
                                }
                            }
                        }
                        return null
                    }

                    val infoA = findSlotInfo(snapA, req.requesterShiftName, req.requesterName)
                    val infoB = findSlotInfo(snapB, req.targetShiftName!!, req.targetUserName!!)

                    if (infoA != null && infoB != null) {
                        val updates = mutableMapOf<String, Any?>()

                        // LOGICA DE INTERCAMBIO (COMPLETO / MEDIA JORNADA)
                        if (infoA.isHalfDay && !infoB.isHalfDay) {
                            val partsA = infoA.path.split("/") // Turno/Group/Key/Role
                            val basePathA = "plants/$plantId/turnos/turnos-${req.requesterShiftDate}/${partsA[0]}/${partsA[1]}/${partsA[2]}"

                            updates["$basePathA/primary"] = req.targetUserName
                            updates["$basePathA/secondary"] = ""
                            updates["$basePathA/halfDay"] = false

                            updates["plants/$plantId/turnos/turnos-${req.targetShiftDate}/${infoB.path}"] = req.requesterName

                        } else if (!infoA.isHalfDay && infoB.isHalfDay) {
                            val partsB = infoB.path.split("/")
                            val basePathB = "plants/$plantId/turnos/turnos-${req.targetShiftDate}/${partsB[0]}/${partsB[1]}/${partsB[2]}"

                            updates["$basePathB/primary"] = req.requesterName
                            updates["$basePathB/secondary"] = ""
                            updates["$basePathB/halfDay"] = false

                            updates["plants/$plantId/turnos/turnos-${req.requesterShiftDate}/${infoA.path}"] = req.targetUserName

                        } else {
                            updates["plants/$plantId/turnos/turnos-${req.requesterShiftDate}/${infoA.path}"] = req.targetUserName
                            updates["plants/$plantId/turnos/turnos-${req.targetShiftDate}/${infoB.path}"] = req.requesterName
                        }

                        updates["plants/$plantId/shift_requests/${req.id}/status"] = RequestStatus.APPROVED

                        database.reference.updateChildren(updates)
                            .addOnSuccessListener { onSuccess() }
                            .addOnFailureListener { onError(it.message ?: "Error al guardar") }
                    } else {
                        onError("No se encontraron los turnos originales (quizás cambiaron).")
                    }
                }
                override fun onCancelled(e: DatabaseError) { onError(e.message) }
            })
        }
        override fun onCancelled(e: DatabaseError) { onError(e.message) }
    })
}

fun deleteShiftRequest(database: FirebaseDatabase, plantId: String, requestId: String) {
    database.getReference("plants/$plantId/shift_requests/$requestId").removeValue()
}

// Data Class auxiliar para la previsualización
data class Quintuple<A, B, C, D, E>(val first: A, val second: B, val third: C, val fourth: D, val fifth: E)