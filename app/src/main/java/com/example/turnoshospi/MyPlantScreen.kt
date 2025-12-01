package com.example.turnoshospi

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyPlantScreen(
    modifier: Modifier = Modifier,
    plant: Plant?,
    isLoading: Boolean,
    isLoadingMembership: Boolean,
    currentUserProfile: UserProfile?,
    plantMembership: PlantMembership?,
    isLinkingStaff: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onOpenPlantDetail: (Plant) -> Unit,
    onJoinPlant: (String, String, (Boolean, String?) -> Unit) -> Unit,
    onLinkUserToStaff: (RegisteredUser) -> Unit
) {
    var plantIdInput by remember { mutableStateOf("") }
    var invitationCode by remember { mutableStateOf("") }
    var joinError by remember { mutableStateOf<String?>(null) }
    var joinSuccess by remember { mutableStateOf(false) }
    var isJoining by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }

    val supervisorRoles = listOf(
        stringResource(id = R.string.role_supervisor_male),
        stringResource(id = R.string.role_supervisor_female)
    )
    val nurseRoles = listOf(
        stringResource(id = R.string.role_nurse_generic),
        stringResource(id = R.string.role_nurse_male),
        stringResource(id = R.string.role_nurse_female)
    )
    val auxRoles = listOf(
        stringResource(id = R.string.role_aux_generic),
        stringResource(id = R.string.role_aux_male),
        stringResource(id = R.string.role_aux_female)
    )
    val normalizedSupervisorRoles = remember(supervisorRoles) { supervisorRoles.map { it.normalizedRole() } }
    val normalizedNurseRoles = remember(nurseRoles) { nurseRoles.map { it.normalizedRole() } }
    val normalizedAuxRoles = remember(auxRoles) { auxRoles.map { it.normalizedRole() } }
    val resolvedRole = plantMembership?.staffRole?.ifBlank { currentUserProfile?.role } ?: currentUserProfile?.role
    val normalizedUserRole = resolvedRole?.normalizedRole()
    val isSupervisor = normalizedUserRole != null && normalizedUserRole in normalizedSupervisorRoles
    val staffOptions = remember(plant?.personal_de_planta, normalizedUserRole) {
        val staff = plant?.personal_de_planta?.values.orEmpty()
        val roleFiltered = when {
            normalizedUserRole == null -> staff
            normalizedUserRole in normalizedSupervisorRoles -> staff
            normalizedUserRole in normalizedNurseRoles -> staff.filter { it.isNurseRole(normalizedNurseRoles) }
            normalizedUserRole in normalizedAuxRoles -> staff.filter { it.isAuxRole(normalizedAuxRoles) }
            else -> staff
        }
        (roleFiltered.ifEmpty { staff }).sortedBy { it.name.lowercase() }
    }
    val resolvedMembership = remember(plantMembership, plant?.id) {
        plantMembership?.takeIf { it.plantId == plant?.id }
    }
    var selectedStaffId by remember(plant?.id) { mutableStateOf(resolvedMembership?.staffId) }
    var showStaffLinkDialog by remember(plant?.id, resolvedMembership?.staffId) { mutableStateOf(false) }
    val shouldPromptLink = plant != null && !isLoading && !isLoadingMembership &&
        resolvedMembership?.staffId == null && staffOptions.isNotEmpty() && !isSupervisor

    LaunchedEffect(shouldPromptLink) {
        if (shouldPromptLink) {
            showStaffLinkDialog = true
        }
    }

    LaunchedEffect(staffOptions) {
        if (selectedStaffId == null && staffOptions.isNotEmpty()) {
            selectedStaffId = staffOptions.first().id
        }
    }

    Scaffold(
        modifier = modifier,
        containerColor = Color(0xFF0F172A),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = stringResource(id = R.string.menu_my_plants),
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
                actions = {
                    IconButton(onClick = onRefresh, enabled = !isLoading) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = stringResource(id = R.string.refresh_plant_action),
                            tint = if (isLoading) Color(0x88FFFFFF) else Color.White
                        )
                    }
                },
                colors = androidx.compose.material3.TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = Color.White
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(
                    Brush.linearGradient(listOf(Color(0xFF0F172A), Color(0xFF0B1220)))
                )
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (isLoading) {
                PlantLoadingCard()
            } else if (plant != null) {
                PlantInfoCard(
                    plant = plant,
                    membership = resolvedMembership,
                    isMembershipLoading = isLoadingMembership,
                    isSupervisor = isSupervisor,
                    onOpenPlantDetail = onOpenPlantDetail
                )

            } else {
                EmptyPlantCard(
                    plantIdInput = plantIdInput,
                    invitationCode = invitationCode,
                    isJoining = isJoining,
                    joinError = joinError ?: errorMessage,
                    joinSuccess = joinSuccess,
                    onPlantIdChange = { plantIdInput = it },
                    onInvitationCodeChange = { invitationCode = it },
                    onJoin = {
                        joinError = null
                        joinSuccess = false
                        isJoining = true
                        onJoinPlant(plantIdInput.trim(), invitationCode.trim()) { success, message ->
                            isJoining = false
                            joinError = message
                            joinSuccess = success && message == null
                            if (success) {
                                onRefresh()
                            }
                        }
                    }
                )
            }

            if (!errorMessage.isNullOrBlank() && plant != null) {
                InfoMessageCard(message = errorMessage)
            }
        }
    }

    if (showStaffLinkDialog && shouldPromptLink) {
        StaffLinkDialog(
            plantName = plant?.name.orEmpty(),
            staffOptions = staffOptions,
            selectedStaffId = selectedStaffId,
            isLinking = isLinkingStaff,
            onStaffSelected = { selectedStaffId = it },
            onConfirm = {
                val chosen = staffOptions.firstOrNull { it.id == selectedStaffId }
                if (chosen != null && !isLinkingStaff) {
                    onLinkUserToStaff(chosen)
                }
            },
            onDismiss = { showStaffLinkDialog = false }
        )
    }
}

@Composable
private fun PlantInfoCard(
    plant: Plant,
    membership: PlantMembership?,
    isMembershipLoading: Boolean,
    isSupervisor: Boolean,
    onOpenPlantDetail: (Plant) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = plant.name,
                color = Color.White,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(id = R.string.plant_hospital_only_label, plant.hospitalName),
                color = Color(0xCCFFFFFF)
            )

            if (!isSupervisor) {
                if (isMembershipLoading) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.width(18.dp),
                            color = Color(0xFF54C7EC),
                            strokeWidth = 2.dp
                        )
                        Text(
                            text = stringResource(id = R.string.plant_staff_lookup_message),
                            color = Color(0xCCFFFFFF),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                } else if (!membership?.staffName.isNullOrBlank()) {
                    Text(
                        text = stringResource(
                            id = R.string.plant_staff_linked_label,
                            membership?.staffName.orEmpty(),
                            membership?.staffRole.orEmpty()
                        ),
                        color = Color(0xCCFFFFFF),
                        style = MaterialTheme.typography.bodyMedium
                    )
                } else {
                    Text(
                        text = stringResource(id = R.string.plant_staff_link_prompt),
                        color = Color(0x99FFFFFF),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }

            Button(
                onClick = { onOpenPlantDetail(plant) },
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC))
            ) {
                Text(text = stringResource(id = R.string.open_plant_detail_action), color = Color.Black)
            }
        }
    }
}

@Composable
private fun EmptyPlantCard(
    plantIdInput: String,
    invitationCode: String,
    isJoining: Boolean,
    joinError: String?,
    joinSuccess: Boolean,
    onPlantIdChange: (String) -> Unit,
    onInvitationCodeChange: (String) -> Unit,
    onJoin: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = stringResource(id = R.string.my_plant_empty_title),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(id = R.string.my_plant_empty_message),
                color = Color(0xCCFFFFFF),
                style = MaterialTheme.typography.bodyMedium
            )

            OutlinedTextField(
                value = plantIdInput,
                onValueChange = onPlantIdChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(text = stringResource(id = R.string.plant_id_label)) },
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

            OutlinedTextField(
                value = invitationCode,
                onValueChange = onInvitationCodeChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(text = stringResource(id = R.string.invitation_code_label)) },
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

            Button(
                onClick = onJoin,
                enabled = !isJoining && plantIdInput.isNotBlank() && invitationCode.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC))
            ) {
                Text(
                    text = if (isJoining) stringResource(id = R.string.saving_label)
                    else stringResource(id = R.string.join_plant_action),
                    fontWeight = FontWeight.Bold
                )
            }

            joinError?.let {
                InfoMessageCard(message = it, isError = true)
            }

            if (joinSuccess) {
                InfoMessageCard(message = stringResource(id = R.string.join_plant_success))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StaffLinkDialog(
    plantName: String,
    staffOptions: List<RegisteredUser>,
    selectedStaffId: String?,
    isLinking: Boolean,
    onStaffSelected: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedStaff = staffOptions.firstOrNull { it.id == selectedStaffId }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            Button(
                onClick = onConfirm,
                enabled = selectedStaff != null && !isLinking,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54C7EC))
            ) {
                if (isLinking) {
                    CircularProgressIndicator(
                        modifier = Modifier.width(18.dp),
                        color = Color.Black,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(text = stringResource(id = R.string.plant_staff_link_confirm), color = Color.Black)
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(text = stringResource(id = R.string.close_label))
            }
        },
        title = {
            Text(
                text = stringResource(id = R.string.plant_staff_link_title, plantName),
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(text = stringResource(id = R.string.plant_staff_link_message))

                ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                    OutlinedTextField(
                        value = selectedStaff?.readableName().orEmpty(),
                        onValueChange = {},
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                        label = { Text(text = stringResource(id = R.string.plant_staff_link_field_label)) },
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
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

                    ExposedDropdownMenu(
                        expanded = expanded,
                        onDismissRequest = { expanded = false }
                    ) {
                        staffOptions.forEach { staff ->
                            DropdownMenuItem(
                                text = { Text(text = staff.readableName()) },
                                onClick = {
                                    onStaffSelected(staff.id)
                                    expanded = false
                                }
                            )
                        }
                    }
                }
            }
        },
        containerColor = Color(0xFF0F172A),
        textContentColor = Color.White,
        titleContentColor = Color.White
    )
}

private fun RegisteredUser.readableName(): String {
    return name.ifBlank { email.ifBlank { role.ifBlank { id } } }
}

@Composable
private fun PlantLoadingCard() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0x22000000)),
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x22FFFFFF))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                CircularProgressIndicator(color = Color(0xFF54C7EC))
                Text(
                    text = stringResource(id = R.string.loading_my_plant),
                    color = Color.White,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun InfoMessageCard(message: String, isError: Boolean = false) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isError) Color(0x33FFB4AB) else Color(0x2231D3A1)
        ),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (isError) Color(0x66FFB4AB) else Color(0x6631D3A1)
        )
    ) {
        Text(
            text = message,
            color = Color.White,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

private fun String.normalizedRole(): String = trim().lowercase()

private fun RegisteredUser.isNurseRole(normalizedRoles: List<String>): Boolean {
    val normalizedRole = role.normalizedRole()
    return normalizedRoles.any { normalizedRole == it } || normalizedRole.contains("enfermer")
}

private fun RegisteredUser.isAuxRole(normalizedRoles: List<String>): Boolean {
    val normalizedRole = role.normalizedRole()
    return normalizedRoles.any { normalizedRole == it } || normalizedRole.contains("auxiliar")
}

@Preview(showBackground = true, backgroundColor = 0xFF0F172A)
@Composable
private fun MyPlantScreenPreview() {
    val samplePlant = Plant(
        id = "plant-123",
        name = "Planta Norte",
        hospitalName = "Hospital Central",
        unitType = "UCI",
        shiftDuration = "12h",
        staffScope = "with_aux",
        shiftTimes = mapOf(
            "Día" to ShiftTime(start = "08:00", end = "20:00"),
            "Noche" to ShiftTime(start = "20:00", end = "08:00")
        ),
        staffRequirements = mapOf("Día" to 4, "Noche" to 3)
    )

    MyPlantScreen(
        plant = samplePlant,
        isLoading = false,
        isLoadingMembership = false,
        currentUserProfile = UserProfile(firstName = "Elena", role = "Supervisora"),
        plantMembership = null,
        isLinkingStaff = false,
        errorMessage = null,
        onBack = {},
        onRefresh = {},
        onOpenPlantDetail = {},
        onJoinPlant = { _, _, callback -> callback(true, null) },
        onLinkUserToStaff = {}
    )
}
