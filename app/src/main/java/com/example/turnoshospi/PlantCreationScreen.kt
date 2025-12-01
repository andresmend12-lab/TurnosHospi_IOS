package com.example.turnoshospi

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.firebase.database.FirebaseDatabase
import java.util.UUID
import kotlinx.coroutines.launch

// --- MODELOS DE DATOS ---
data class PlantCredentials(
    val plantId: String,
    val accessPassword: String
)

data class RegisteredUser(
    val id: String = "",
    val name: String = "",
    val role: String = "",
    val email: String = "",
    val profileType: String = ""
)

data class Plant(
    val id: String = "",
    val name: String = "",
    val unitType: String = "",
    val hospitalName: String = "",
    val shiftDuration: String = "",
    val allowHalfDay: Boolean = false,
    val staffScope: String = "",
    val shiftTimes: Map<String, ShiftTime> = emptyMap(),
    val staffRequirements: Map<String, Int> = emptyMap(),
    val createdAt: Long = 0L,
    val accessPassword: String = "",
    val personal_de_planta: Map<String, RegisteredUser> = emptyMap()
)

data class ShiftTime(val start: String = "", val end: String = "")

private enum class StaffScope {
    NursesOnly,
    NursesAndAux
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlantCreationScreen(
    onBack: () -> Unit,
    onPlantCreated: (PlantCredentials) -> Unit,
    currentUserId: String?,
    currentUserProfile: UserProfile?
) {
    val scrollState = rememberScrollState()
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current
    val database = remember {
        FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
    }

    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    var plantName by remember { mutableStateOf("") }
    var unitType by remember { mutableStateOf("") }
    var hospitalName by remember { mutableStateOf("") }

    val durationOptions = listOf(
        stringResource(id = R.string.shift_duration_8h),
        stringResource(id = R.string.shift_duration_12h)
    )
    var expanded by remember { mutableStateOf(false) }
    var selectedDuration by remember { mutableStateOf(durationOptions.first()) }

    val shiftLabels = if (selectedDuration == durationOptions.first()) {
        listOf(
            stringResource(id = R.string.shift_morning),
            stringResource(id = R.string.shift_afternoon),
            stringResource(id = R.string.shift_night)
        )
    } else {
        listOf(
            stringResource(id = R.string.shift_day),
            stringResource(id = R.string.shift_night)
        )
    }

    var shiftTimes by remember(selectedDuration) {
        mutableStateOf(shiftLabels.associateWith { ShiftTime() })
    }

    var staffRequirements by remember(selectedDuration) {
        mutableStateOf(shiftLabels.associateWith { "" })
    }

    var allowHalfDay by remember { mutableStateOf(false) }
    var staffScope by remember { mutableStateOf(StaffScope.NursesOnly) }

    Scaffold(
        containerColor = Color(0xFF0B1220),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = stringResource(id = R.string.plant_creation_title),
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = stringResource(id = R.string.close_label),
                            tint = Color.White
                        )
                    }
                },
                colors = androidx.compose.material3.TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(listOf(Color(0xFF0F172A), Color(0xFF0B1220)))
                )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .verticalScroll(scrollState)
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                CardSection(title = stringResource(id = R.string.plant_general_data_title)) {
                    PlantTextField(
                        value = plantName,
                        onValueChange = { plantName = it },
                        label = stringResource(id = R.string.plant_name_label)
                    )
                    PlantTextField(
                        value = unitType,
                        onValueChange = { unitType = it },
                        label = stringResource(id = R.string.unit_type_label)
                    )
                    PlantTextField(
                        value = hospitalName,
                        onValueChange = { hospitalName = it },
                        label = stringResource(id = R.string.hospital_name_label)
                    )
                }

                CardSection(title = stringResource(id = R.string.shift_configuration_title)) {
                    Text(
                        text = stringResource(id = R.string.shift_duration_label),
                        color = Color.White,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                    ExposedDropdownMenuBox(
                        expanded = expanded,
                        onExpandedChange = { expanded = !expanded }
                    ) {
                        OutlinedTextField(
                            value = selectedDuration,
                            onValueChange = {},
                            readOnly = true,
                            modifier = Modifier
                                .menuAnchor()
                                .fillMaxWidth(),
                            label = { Text(text = stringResource(id = R.string.shift_duration_placeholder)) },
                            trailingIcon = {
                                ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
                            },
                            colors = TextFieldDefaults.colors(
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                focusedIndicatorColor = Color(0xFF54C7EC),
                                unfocusedIndicatorColor = Color(0x66FFFFFF),
                                cursorColor = Color.White,
                                focusedLabelColor = Color.White,
                                unfocusedLabelColor = Color(0xCCFFFFFF),
                                focusedContainerColor = Color(0x22FFFFFF),
                                unfocusedContainerColor = Color(0x11FFFFFF)
                            )
                        )
                        DropdownMenu(
                            expanded = expanded,
                            onDismissRequest = { expanded = false }
                        ) {
                            durationOptions.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(text = option) },
                                    onClick = {
                                        selectedDuration = option
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }

                    Text(
                        text = stringResource(id = R.string.shift_timing_instruction),
                        color = Color(0xCCFFFFFF),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(vertical = 8.dp)
                    )

                    shiftLabels.forEach { label ->
                        ShiftTimeRow(
                            label = label,
                            value = shiftTimes[label] ?: ShiftTime(),
                            onValueChange = { updated ->
                                shiftTimes = shiftTimes.toMutableMap().apply { put(label, updated) }
                            }
                        )
                    }

                    Divider(color = Color(0x33FFFFFF), modifier = Modifier.padding(vertical = 8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = stringResource(id = R.string.shift_half_day_question),
                            color = Color.White,
                            modifier = Modifier.weight(1f)
                        )
                        androidx.compose.material3.Switch(
                            checked = allowHalfDay,
                            onCheckedChange = { allowHalfDay = it },
                            colors = androidx.compose.material3.SwitchDefaults.colors(
                                checkedThumbColor = Color.White,
                                checkedTrackColor = Color(0xFF54C7EC)
                            )
                        )
                    }
                }

                CardSection(title = stringResource(id = R.string.plant_staff_title)) {
                    Text(
                        text = stringResource(id = R.string.staff_scope_question),
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    StaffScopeOption(
                        text = stringResource(id = R.string.staff_scope_nurses_only),
                        selected = staffScope == StaffScope.NursesOnly,
                        onSelect = { staffScope = StaffScope.NursesOnly }
                    )
                    StaffScopeOption(
                        text = stringResource(id = R.string.staff_scope_with_aux),
                        selected = staffScope == StaffScope.NursesAndAux,
                        onSelect = { staffScope = StaffScope.NursesAndAux }
                    )
                }

                CardSection(title = stringResource(id = R.string.staff_requirements_title)) {
                    Text(
                        text = stringResource(id = R.string.staff_minimum_label),
                        color = Color(0xCCFFFFFF),
                        style = MaterialTheme.typography.bodySmall
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    shiftLabels.forEach { label ->
                        PlantTextField(
                            value = staffRequirements[label].orEmpty(),
                            onValueChange = { value ->
                                staffRequirements = staffRequirements.toMutableMap().apply { put(label, value) }
                            },
                            label = label,
                            keyboardType = KeyboardType.Number
                        )
                    }
                }

                if (errorMessage != null) {
                    Text(
                        text = errorMessage.orEmpty(),
                        color = Color(0xFFFFB4AB),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        if (plantName.isBlank() || unitType.isBlank() || hospitalName.isBlank()) {
                            errorMessage = context.getString(R.string.plant_required_fields_error)
                            return@Button
                        }

                        isSaving = true
                        errorMessage = null

                        val plantId = database.reference.child("plants").push().key
                            ?: UUID.randomUUID().toString()
                        val accessPassword = UUID.randomUUID().toString().take(8)
                        val staffScopeValue = when (staffScope) {
                            StaffScope.NursesOnly -> "nurses_only"
                            StaffScope.NursesAndAux -> "nurses_and_aux"
                        }

                        // --- NUEVA LÓGICA: SUPERVISOR AUTOMÁTICO ---
                        val supervisorStaffId = currentUserId ?: UUID.randomUUID().toString()
                        val userId = currentUserId ?: ""

                        val supervisorName = if (currentUserProfile != null) {
                            "${currentUserProfile.firstName} ${currentUserProfile.lastName}".trim().ifEmpty { currentUserProfile.email }
                        } else {
                            "Supervisor"
                        }
                        // Usamos el rol que tenga el usuario o forzamos "Supervisor"
                        val supervisorRole = currentUserProfile?.role.takeIf { !it.isNullOrBlank() } ?: "Supervisor"

                        // 1. Crear el objeto del personal (Supervisor)
                        val supervisorStaffMember = RegisteredUser(
                            id = supervisorStaffId,
                            name = supervisorName,
                            role = supervisorRole,
                            email = currentUserProfile?.email ?: "",
                            profileType = "Supervisor"
                        )

                        // 2. Crear la planta con el supervisor ya incluido
                        val plant = Plant(
                            id = plantId,
                            name = plantName,
                            unitType = unitType,
                            hospitalName = hospitalName,
                            shiftDuration = selectedDuration,
                            allowHalfDay = allowHalfDay,
                            staffScope = staffScopeValue,
                            shiftTimes = shiftTimes,
                            staffRequirements = staffRequirements.mapValues { (_, value) ->
                                value.toIntOrNull() ?: 0
                            },
                            createdAt = System.currentTimeMillis(),
                            accessPassword = accessPassword,
                            personal_de_planta = mapOf(supervisorStaffId to supervisorStaffMember)
                        )

                        coroutineScope.launch {
                            val updates = mutableMapOf<String, Any?>()

                            // Guardar Planta
                            updates["plants/$plantId"] = plant

                            // Si hay usuario logueado, vincularlo inmediatamente
                            if (userId.isNotEmpty()) {
                                // Enlace en la planta (userPlants)
                                val membershipData = mapOf(
                                    "plantId" to plantId,
                                    "staffId" to supervisorStaffId,
                                    "staffName" to supervisorName,
                                    "staffRole" to supervisorRole
                                )
                                updates["plants/$plantId/userPlants/$userId"] = membershipData

                                // Enlace en el usuario (users)
                                updates["users/$userId/plantId"] = plantId
                                updates["users/$userId/plantStaffId"] = supervisorStaffId
                                updates["users/$userId/linkedStaffName"] = supervisorName
                                // Opcional: Asegurar que el rol en 'users' sea Supervisor
                                updates["users/$userId/role"] = supervisorRole
                            }

                            database.reference
                                .updateChildren(updates)
                                .addOnSuccessListener {
                                    isSaving = false
                                    onPlantCreated(PlantCredentials(plantId, accessPassword))
                                }
                                .addOnFailureListener { exception ->
                                    isSaving = false
                                    errorMessage = exception.message
                                        ?: context.getString(R.string.plant_save_error)
                                }
                        }
                    },
                    enabled = !isSaving,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF54C7EC),
                        contentColor = Color.Black
                    )
                ) {
                    Text(
                        text = if (isSaving) stringResource(id = R.string.saving_label) else stringResource(
                            id = R.string.create_plant_action
                        ),
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
fun PlantCreatedScreen(credentials: PlantCredentials?, onBackToMenu: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F172A))
            .padding(20.dp),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
            shape = RoundedCornerShape(24.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x22FFFFFF))
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF54C7EC),
                    modifier = Modifier.padding(top = 8.dp)
                )
                Text(
                    text = stringResource(id = R.string.plant_created_title),
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = stringResource(id = R.string.plant_created_message),
                    color = Color(0xCCFFFFFF),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
                credentials?.let { plantCredentials ->
                    CardSection(title = stringResource(id = R.string.plant_credentials_title)) {
                        PlantTextField(
                            value = plantCredentials.plantId,
                            onValueChange = {},
                            label = stringResource(id = R.string.plant_id_label),
                            modifier = Modifier.fillMaxWidth(),
                            readOnly = true
                        )
                        PlantTextField(
                            value = plantCredentials.accessPassword,
                            onValueChange = {},
                            label = stringResource(id = R.string.plant_access_password_label),
                            modifier = Modifier.fillMaxWidth(),
                            readOnly = true
                        )
                        Text(
                            text = stringResource(id = R.string.plant_share_hint),
                            color = Color(0xCCFFFFFF),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = onBackToMenu,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC))
                ) {
                    Text(text = stringResource(id = R.string.back_to_menu))
                }
            }
        }
    }
}

@Composable
private fun CardSection(title: String, content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = title,
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            content()
        }
    }
}

@Composable
private fun PlantTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    modifier: Modifier = Modifier.fillMaxWidth(),
    readOnly: Boolean = false
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        readOnly = readOnly,
        label = { Text(text = label) },
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = TextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedIndicatorColor = Color(0xFF54C7EC),
            unfocusedIndicatorColor = Color(0x66FFFFFF),
            cursorColor = Color.White,
            focusedLabelColor = Color.White,
            unfocusedLabelColor = Color(0xCCFFFFFF),
            focusedContainerColor = Color(0x22FFFFFF),
            unfocusedContainerColor = Color(0x11FFFFFF)
        )
    )
}

@Composable
private fun ShiftTimeRow(label: String, value: ShiftTime, onValueChange: (ShiftTime) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = label,
            color = Color.White,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            PlantTextField(
                value = value.start,
                onValueChange = { onValueChange(value.copy(start = it)) },
                label = stringResource(id = R.string.shift_start_label),
                modifier = Modifier.weight(1f)
            )
            PlantTextField(
                value = value.end,
                onValueChange = { onValueChange(value.copy(end = it)) },
                label = stringResource(id = R.string.shift_end_label),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun StaffScopeOption(text: String, selected: Boolean, onSelect: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        RadioButton(selected = selected, onClick = onSelect)
        Text(text = text, color = Color.White)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0F172A)
@Composable
private fun PlantCreationScreenPreview() {
    PlantCreationScreen(
        onBack = {},
        onPlantCreated = {},
        currentUserId = "preview-user",
        currentUserProfile = UserProfile(firstName = "Ana", lastName = "Supervisor", role = "Supervisor")
    )
}