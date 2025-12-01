package com.example.turnoshospi

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.turnoshospi.ui.theme.ShiftColors
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.time.LocalDate
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShiftMarketplaceScreen(
    plantId: String,
    currentUserId: String,
    currentUserName: String,
    currentUserRole: String,
    shiftColors: ShiftColors, // <--- NUEVO PARÁMETRO
    onBack: () -> Unit,
    onSaveNotification: (String, String, String, String, String?, (Boolean) -> Unit) -> Unit
) {
    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
    val context = LocalContext.current

    // --- ESTADOS DE DATOS ---
    var rawMarketplaceRequests by remember { mutableStateOf<List<ShiftChangeRequest>>(emptyList()) }
    val balancesMap = remember { mutableStateMapOf<String, Int>() }
    val transactionsList = remember { mutableStateListOf<FavorTransaction>() }
    val staffNamesMap = remember { mutableStateMapOf<String, String>() }
    val userIdToStaffIdMap = remember { mutableStateMapOf<String, String>() }

    val myShiftsMap = remember { mutableStateMapOf<LocalDate, String>() }

    var isLoadingRequests by remember { mutableStateOf(true) }
    var isLoadingSchedule by remember { mutableStateOf(true) }

    // --- DIALOGO PREVIEW ---
    var showPreviewDialog by remember { mutableStateOf(false) }
    var previewRequest by remember { mutableStateOf<ShiftChangeRequest?>(null) }
    val requesterScheduleForPreview = remember { mutableStateMapOf<LocalDate, String>() }

    // Función auxiliar para resolver nombres
    fun resolveName(id: String): String {
        if (staffNamesMap.containsKey(id)) return staffNamesMap[id]!!
        val staffId = userIdToStaffIdMap[id]
        if (staffId != null && staffNamesMap.containsKey(staffId)) return staffNamesMap[staffId]!!
        return "Usuario"
    }

    // Función para cargar el horario del solicitante
    fun fetchWeeklySchedule(userId: String, date: LocalDate) {
        val pivotStart = date.minusDays(7)
        val pivotEnd = date.plusDays(7)

        val startKey = "turnos-$pivotStart"
        val endKey = "turnos-$pivotEnd"

        database.getReference("plants/$plantId/turnos")
            .orderByKey()
            .startAt(startKey)
            .endAt(endKey)
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    requesterScheduleForPreview.clear()
                    snapshot.children.forEach { dateSnapshot ->
                        val dateKey = dateSnapshot.key?.removePrefix("turnos-") ?: return@forEach
                        try {
                            val d = LocalDate.parse(dateKey)
                            dateSnapshot.children.forEach { shiftSnap ->
                                val shiftName = shiftSnap.key ?: ""
                                val userName = resolveName(userId)

                                fun checkSlot(node: String) {
                                    shiftSnap.child(node).children.forEach { slot ->
                                        val p = slot.child("primary").value.toString()
                                        val s = slot.child("secondary").value.toString()
                                        if (p.equals(userName, true) || s.equals(userName, true)) {
                                            requesterScheduleForPreview[d] = shiftName
                                        }
                                    }
                                }
                                checkSlot("nurses")
                                checkSlot("auxiliaries")
                            }
                        } catch (_: Exception) {}
                    }
                    showPreviewDialog = true
                }
                override fun onCancelled(error: DatabaseError) {
                    Toast.makeText(context, "Error cargando horario", Toast.LENGTH_SHORT).show()
                }
            })
    }

    LaunchedEffect(plantId) {
        // 1. Cargar Solicitudes Activas
        database.getReference("plants/$plantId/shift_requests")
            .orderByChild("status")
            .equalTo("SEARCHING")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val list = mutableListOf<ShiftChangeRequest>()
                    snapshot.children.forEach { child ->
                        val req = child.getValue(ShiftChangeRequest::class.java)
                        if (req != null && req.requesterId != currentUserId) {
                            list.add(req)
                        }
                    }
                    rawMarketplaceRequests = list
                    isLoadingRequests = false
                }
                override fun onCancelled(error: DatabaseError) { isLoadingRequests = false }
            })

        // 2. Cargar TU Horario
        val today = LocalDate.now()
        val startDate = today.minusDays(1)
        val startKey = "turnos-$startDate"

        database.getReference("plants/$plantId/turnos")
            .orderByKey()
            .startAt(startKey)
            .limitToFirst(62)
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    myShiftsMap.clear()
                    snapshot.children.forEach { dateSnapshot ->
                        val dateKey = dateSnapshot.key?.removePrefix("turnos-") ?: return@forEach
                        try {
                            val date = LocalDate.parse(dateKey)
                            dateSnapshot.children.forEach { shiftSnap ->
                                val shiftName = shiftSnap.key ?: ""
                                fun checkSlot(node: String) {
                                    shiftSnap.child(node).children.forEach { slot ->
                                        val name = slot.child("primary").value.toString()
                                        val secName = slot.child("secondary").value.toString()
                                        if (name.equals(currentUserName, ignoreCase = true) ||
                                            secName.equals(currentUserName, ignoreCase = true)) {
                                            myShiftsMap[date] = shiftName
                                        }
                                    }
                                }
                                checkSlot("nurses")
                                checkSlot("auxiliaries")
                            }
                        } catch (_: Exception) { }
                    }
                    isLoadingSchedule = false
                }
                override fun onCancelled(error: DatabaseError) { isLoadingSchedule = false }
            })

        // 3. Balances
        database.getReference("plants/$plantId/balances/$currentUserId")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    balancesMap.clear()
                    snapshot.children.forEach { child ->
                        val partnerId = child.key ?: return@forEach
                        val score = child.getValue(Int::class.java) ?: 0
                        if (score != 0) balancesMap[partnerId] = score
                    }
                }
                override fun onCancelled(error: DatabaseError) {}
            })

        // 4. Historial
        database.getReference("plants/$plantId/transactions")
            .limitToLast(100)
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    transactionsList.clear()
                    snapshot.children.forEach { child ->
                        val t = child.getValue(FavorTransaction::class.java)
                        if (t != null && (t.covererId == currentUserId || t.requesterId == currentUserId)) {
                            transactionsList.add(t)
                        }
                    }
                    transactionsList.sortByDescending { it.timestamp }
                }
                override fun onCancelled(error: DatabaseError) {}
            })

        // 5. Nombres
        database.getReference("plants/$plantId/personal_de_planta")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    staffNamesMap.clear()
                    snapshot.children.forEach { child ->
                        val name = child.child("name").value as? String
                        val key = child.key
                        val internalId = child.child("id").value as? String
                        if (name != null) {
                            if (key != null) staffNamesMap[key] = name
                            if (internalId != null) staffNamesMap[internalId] = name
                        }
                    }
                }
                override fun onCancelled(error: DatabaseError) {}
            })

        // 6. User IDs
        database.getReference("plants/$plantId/userPlants")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    userIdToStaffIdMap.clear()
                    snapshot.children.forEach { child ->
                        val userId = child.key
                        val staffId = child.child("staffId").value as? String
                        if (userId != null && staffId != null) userIdToStaffIdMap[userId] = staffId
                    }
                }
                override fun onCancelled(error: DatabaseError) {}
            })
    }

    val filteredRequests = remember(rawMarketplaceRequests, myShiftsMap, currentUserRole) {
        if (isLoadingSchedule) emptyList()
        else rawMarketplaceRequests.filter { req ->
            try {
                val reqDate = LocalDate.parse(req.requesterShiftDate)
                if (!ShiftRulesEngine.areRolesCompatible(currentUserRole, req.requesterRole)) return@filter false
                val validationError = ShiftRulesEngine.validateWorkRules(
                    targetDate = reqDate,
                    targetShiftName = req.requesterShiftName,
                    userSchedule = myShiftsMap
                )
                validationError == null
            } catch (e: Exception) {
                false
            }
        }
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("Bolsa de Turnos", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
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
                .padding(16.dp)
        ) {
            // Balances
            if (balancesMap.isNotEmpty()) {
                Text("Mis Balances con Compañeros", color = Color(0xFF54C7EC), fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 250.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(balancesMap.toList()) { (partnerId, score) ->
                        val partnerName = resolveName(partnerId)
                        val historyWithPartner = transactionsList.filter {
                            (it.covererId == currentUserId && it.requesterId == partnerId) ||
                                    (it.requesterId == currentUserId && it.covererId == partnerId)
                        }
                        BalanceCard(partnerName, score, historyWithPartner, currentUserId)
                    }
                }
                HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp), color = Color.White.copy(alpha = 0.1f))
            }

            // Turnos
            Text("Turnos Disponibles (Compatibles contigo)", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text("Solo se muestran turnos que puedes realizar legalmente.", color = Color.Gray, fontSize = 12.sp)
            Spacer(modifier = Modifier.height(8.dp))

            if (isLoadingRequests || isLoadingSchedule) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Color(0xFF54C7EC))
                }
            } else if (filteredRequests.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize().weight(1f), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("No hay turnos disponibles para ti.", color = Color.Gray)
                        if (rawMarketplaceRequests.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("(Se han ocultado ${rawMarketplaceRequests.size - filteredRequests.size} turnos incompatibles)", color = Color.DarkGray, fontSize = 11.sp)
                        }
                    }
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    items(filteredRequests) { req ->
                        val balanceWithRequester = balancesMap[req.requesterId] ?: 0
                        MarketplaceItem(
                            req = req,
                            balanceWithRequester = balanceWithRequester,
                            onAccept = {
                                acceptCoverage(
                                    database, plantId, req, currentUserId, currentUserName,
                                    onSuccess = {
                                        onSaveNotification(
                                            req.requesterId,
                                            "SHIFT_COVERED",
                                            "$currentUserName ha aceptado cubrir tu turno. ¡Mira tu balance!",
                                            "ShiftMarketplaceScreen",
                                            req.id,
                                            {}
                                        )
                                        Toast.makeText(context, "¡Turno aceptado!", Toast.LENGTH_LONG).show()
                                    },
                                    onError = { msg -> Toast.makeText(context, msg, Toast.LENGTH_LONG).show() }
                                )
                            },
                            onPreview = {
                                previewRequest = req
                                val date = LocalDate.parse(req.requesterShiftDate)
                                fetchWeeklySchedule(req.requesterId, date)
                            }
                        )
                    }
                }
            }
        }
    }

    if (showPreviewDialog && previewRequest != null) {
        val req = previewRequest!!
        val pivotDate = LocalDate.parse(req.requesterShiftDate)

        SchedulePreviewDialog(
            onDismiss = { showPreviewDialog = false },
            row1Schedule = myShiftsMap,
            row1Name = "Yo",
            row1DateToRemove = null,
            row1DateToAdd = pivotDate,
            row1ShiftToAdd = req.requesterShiftName,
            row2Schedule = requesterScheduleForPreview,
            row2Name = req.requesterName,
            row2DateToRemove = pivotDate,
            row2DateToAdd = null,
            row2ShiftToAdd = null,
            shiftColors = shiftColors // <--- PASAMOS LOS COLORES AQUÍ
        )
    }
}

// --- COMPONENTES UI ---

@Composable
fun BalanceCard(
    partnerName: String,
    score: Int,
    history: List<FavorTransaction>,
    currentUserId: String
) {
    var expanded by remember { mutableStateOf(false) }
    val isPositive = score > 0
    val scoreColor = if (isPositive) Color(0xFF4CAF50) else Color(0xFFE91E63)
    val containerColor = if (isPositive) Color(0xFF1E293B) else Color(0xFF2B1218)
    val borderColor = if (isPositive) Color(0xFF4CAF50) else Color(0xFFE91E63)

    Card(
        modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded },
        colors = CardDefaults.cardColors(containerColor = containerColor),
        border = BorderStroke(1.dp, borderColor.copy(alpha = 0.5f))
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Person, null, tint = Color.White, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(partnerName, color = Color.White, fontWeight = FontWeight.Bold)
                        Text(
                            text = if (isPositive) "Te debe $score favores" else "Le debes ${-score} favores",
                            color = scoreColor,
                            fontSize = 12.sp
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (score > 0) "+$score" else "$score",
                        color = scoreColor,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        contentDescription = "Expandir",
                        tint = Color.Gray
                    )
                }
            }

            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut()
            ) {
                Column(modifier = Modifier.padding(top = 12.dp)) {
                    HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Historial de favores:", color = Color.Gray, fontSize = 11.sp)
                    Spacer(modifier = Modifier.height(4.dp))

                    if (history.isEmpty()) {
                        Text("No hay historial disponible.", color = Color.Gray, fontSize = 12.sp)
                    } else {
                        history.forEach { t ->
                            val isMeCovering = t.covererId == currentUserId
                            Row(modifier = Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
                                Icon(
                                    imageVector = if (isMeCovering) Icons.Default.CheckCircle else Icons.Default.History,
                                    contentDescription = null,
                                    tint = if (isMeCovering) Color(0xFF4CAF50) else Color(0xFFFF9800),
                                    modifier = Modifier.size(14.dp).padding(top = 2.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = if (isMeCovering) "Le cubriste el turno" else "Te cubrió el turno",
                                        color = Color.White,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text(
                                        text = "${t.shiftName} del ${t.date}",
                                        color = Color(0xCCFFFFFF),
                                        fontSize = 12.sp
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

@Composable
fun MarketplaceItem(
    req: ShiftChangeRequest,
    balanceWithRequester: Int,
    onAccept: () -> Unit,
    onPreview: () -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF)),
        border = BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Solicita: ${req.requesterName}", color = Color.White, fontWeight = FontWeight.Bold)
                    if (balanceWithRequester != 0) {
                        Text(
                            text = if (balanceWithRequester > 0) "Te debe $balanceWithRequester" else "Le debes ${-balanceWithRequester}",
                            color = if (balanceWithRequester > 0) Color(0xFF4CAF50) else Color(0xFFE91E63),
                            fontSize = 11.sp
                        )
                    } else {
                        Text("Balance neutro (0)", color = Color.Gray, fontSize = 11.sp)
                    }
                }
                Badge(containerColor = Color(0xFF54C7EC)) {
                    Text(req.requesterShiftName, color = Color.Black)
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text("Fecha: ${req.requesterShiftDate}", color = Color(0xFF54C7EC), fontSize = 18.sp, fontWeight = FontWeight.Bold)

            Spacer(modifier = Modifier.height(16.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = onAccept,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50), contentColor = Color.White)
                ) {
                    Icon(Icons.AutoMirrored.Filled.Assignment, null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("CUBRIR TURNO")
                }

                OutlinedButton(
                    onClick = onPreview,
                    modifier = Modifier.weight(0.5f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF54C7EC)),
                    border = BorderStroke(1.dp, Color(0xFF54C7EC))
                ) {
                    Text("👁 Preview", fontSize = 12.sp)
                }
            }
        }
    }
}

fun acceptCoverage(
    database: FirebaseDatabase,
    plantId: String,
    req: ShiftChangeRequest,
    covererId: String,
    covererName: String,
    onSuccess: () -> Unit,
    onError: (String) -> Unit
) {
    val turnosRef = database.reference.child("plants/$plantId/turnos/turnos-${req.requesterShiftDate}")

    turnosRef.addListenerForSingleValueEvent(object : ValueEventListener {
        override fun onDataChange(snapshot: DataSnapshot) {
            if (!snapshot.exists()) { onError("Error: El día ya no existe."); return }

            val shiftRef = snapshot.child(req.requesterShiftName)

            var pathFound: String? = null
            var slotKey: String? = null
            var fieldToUpdate: String? = null

            fun findInNode(nodeName: String) {
                shiftRef.child(nodeName).children.forEach { slot ->
                    if (slot.child("primary").value == req.requesterName) {
                        pathFound = nodeName; slotKey = slot.key; fieldToUpdate = "primary"
                    } else if (slot.child("secondary").value == req.requesterName) {
                        pathFound = nodeName; slotKey = slot.key; fieldToUpdate = "secondary"
                    }
                }
            }

            findInNode("nurses")
            if (pathFound == null) findInNode("auxiliaries")

            if (pathFound != null && slotKey != null && fieldToUpdate != null) {
                val transactionId = UUID.randomUUID().toString()
                val transaction = FavorTransaction(
                    id = transactionId,
                    covererId = covererId,
                    covererName = covererName,
                    requesterId = req.requesterId,
                    requesterName = req.requesterName,
                    date = req.requesterShiftDate,
                    shiftName = req.requesterShiftName,
                    timestamp = System.currentTimeMillis()
                )

                database.reference.child("plants/$plantId/balances").runTransaction(object : com.google.firebase.database.Transaction.Handler {
                    override fun doTransaction(currentData: com.google.firebase.database.MutableData): com.google.firebase.database.Transaction.Result {
                        val myBalancePath = currentData.child(covererId).child(req.requesterId)
                        val myCurrentScore = myBalancePath.getValue(Int::class.java) ?: 0
                        myBalancePath.value = myCurrentScore + 1

                        val hisBalancePath = currentData.child(req.requesterId).child(covererId)
                        val hisCurrentScore = hisBalancePath.getValue(Int::class.java) ?: 0
                        hisBalancePath.value = hisCurrentScore - 1

                        return com.google.firebase.database.Transaction.success(currentData)
                    }

                    override fun onComplete(error: DatabaseError?, committed: Boolean, snapshot: DataSnapshot?) {
                        if (committed) {
                            val updates = mutableMapOf<String, Any?>()
                            updates["plants/$plantId/turnos/turnos-${req.requesterShiftDate}/${req.requesterShiftName}/$pathFound/$slotKey/$fieldToUpdate"] = covererName
                            updates["plants/$plantId/shift_requests/${req.id}/status"] = RequestStatus.APPROVED
                            updates["plants/$plantId/shift_requests/${req.id}/targetUserId"] = covererId
                            updates["plants/$plantId/transactions/$transactionId"] = transaction

                            database.reference.updateChildren(updates).addOnSuccessListener { onSuccess() }
                        } else {
                            onError("Error actualizando balances: ${error?.message}")
                        }
                    }
                })
            } else {
                onError("No se encontró al usuario original en el turno.")
            }
        }
        override fun onCancelled(error: DatabaseError) { onError("Error de conexión.") }
    })
}