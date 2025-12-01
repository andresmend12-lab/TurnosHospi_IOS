package com.example.turnoshospi

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.example.turnoshospi.R
import androidx.compose.ui.tooling.preview.Preview
import com.example.turnoshospi.ui.theme.TurnoshospiTheme

@Composable
fun ProfileEditorOverlay(
    userEmail: String,
    existingProfile: UserProfile?,
    isLoading: Boolean,
    onDismiss: () -> Unit,
    onSave: (UserProfile, (Boolean) -> Unit) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xB3000000)),
        contentAlignment = Alignment.Center
    ) {
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF0F172A)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(id = R.string.edit_profile),
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge
                    )
                    TextButton(
                        onClick = onDismiss,
                        colors = ButtonDefaults.textButtonColors(contentColor = Color(0xCCFFFFFF))
                    ) {
                        Text(text = stringResource(id = R.string.close_label))
                    }
                }

                RegistrationScreen(
                    modifier = Modifier.fillMaxWidth(),
                    userEmail = userEmail,
                    existingProfile = existingProfile,
                    isLoading = isLoading,
                    onSave = onSave
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegistrationScreen(
    modifier: Modifier = Modifier,
    userEmail: String,
    existingProfile: UserProfile?,
    isLoading: Boolean,
    onSave: (UserProfile, (Boolean) -> Unit) -> Unit
) {
    var firstName by remember { mutableStateOf("") }
    var lastName by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf("") }
    var expanded by remember { mutableStateOf(false) }
    var genderExpanded by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }

    LaunchedEffect(existingProfile?.firstName, existingProfile?.lastName, existingProfile?.role, existingProfile?.gender) {
        firstName = existingProfile?.firstName.orEmpty()
        lastName = existingProfile?.lastName.orEmpty()
        role = existingProfile?.role.orEmpty()
        gender = existingProfile?.gender.orEmpty()
    }

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(28.dp),
        border = BorderStroke(
            1.dp,
            Brush.linearGradient(
                listOf(
                    Color(0x66FFFFFF),
                    Color(0x33FFFFFF)
                )
            )
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.28f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = stringResource(id = R.string.create_account_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            if (isLoading) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text(text = "Cargando datos...", color = Color.White)
                }
            }

            OutlinedTextField(
                value = userEmail,
                onValueChange = {},
                enabled = false,
                label = { Text("Correo electrónico") },
                colors = TextFieldDefaults.colors(
                    disabledContainerColor = Color(0x11FFFFFF),
                    disabledIndicatorColor = Color(0x66FFFFFF),
                    disabledLabelColor = Color(0xCCFFFFFF),
                    disabledTextColor = Color.White
                ),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = firstName,
                onValueChange = { firstName = it },
                label = { Text("Nombre") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                colors = TextFieldDefaults.colors(
                    focusedIndicatorColor = Color(0x99FFFFFF),
                    unfocusedIndicatorColor = Color(0x66FFFFFF),
                    focusedContainerColor = Color(0x22FFFFFF),
                    unfocusedContainerColor = Color(0x18FFFFFF),
                    focusedLabelColor = Color.White,
                    unfocusedLabelColor = Color(0xCCFFFFFF),
                    cursorColor = Color.White,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                ),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = lastName,
                onValueChange = { lastName = it },
                label = { Text("Apellidos") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                colors = TextFieldDefaults.colors(
                    focusedIndicatorColor = Color(0x99FFFFFF),
                    unfocusedIndicatorColor = Color(0x66FFFFFF),
                    focusedContainerColor = Color(0x22FFFFFF),
                    unfocusedContainerColor = Color(0x18FFFFFF),
                    focusedLabelColor = Color.White,
                    unfocusedLabelColor = Color(0xCCFFFFFF),
                    cursorColor = Color.White,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                ),
                modifier = Modifier.fillMaxWidth()
            )

            val roleSupervisorMale = stringResource(id = R.string.role_supervisor_male)
            val roleSupervisorFemale = stringResource(id = R.string.role_supervisor_female)
            val roleNurseMale = stringResource(id = R.string.role_nurse_male)
            val roleNurseFemale = stringResource(id = R.string.role_nurse_female)
            val roleAuxMale = stringResource(id = R.string.role_aux_male)
            val roleAuxFemale = stringResource(id = R.string.role_aux_female)
            val genderLabelMale = stringResource(id = R.string.gender_male)
            val genderLabelFemale = stringResource(id = R.string.gender_female)

            GenderDropdown(
                gender = gender,
                labelMale = genderLabelMale,
                labelFemale = genderLabelFemale,
                expanded = genderExpanded,
                onGenderSelected = { selectedGender ->
                    gender = selectedGender
                    role = convertRoleForGender(
                        role = role,
                        gender = selectedGender,
                        maleLabels = listOf(
                            roleSupervisorMale,
                            roleNurseMale,
                            roleAuxMale
                        ),
                        femaleLabels = listOf(
                            roleSupervisorFemale,
                            roleNurseFemale,
                            roleAuxFemale
                        )
                    )
                },
                onExpandedChange = { genderExpanded = it }
            )

            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = it }
            ) {
                OutlinedTextField(
                    value = role,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Puesto") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    colors = TextFieldDefaults.colors(
                        focusedIndicatorColor = Color(0x99FFFFFF),
                        unfocusedIndicatorColor = Color(0x66FFFFFF),
                        focusedContainerColor = Color(0x22FFFFFF),
                        unfocusedContainerColor = Color(0x18FFFFFF),
                        focusedLabelColor = Color.White,
                        unfocusedLabelColor = Color(0xCCFFFFFF),
                        cursorColor = Color.White,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor()
                )

                DropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = if (gender == "female") roleSupervisorFemale else roleSupervisorMale
                            )
                        },
                        onClick = {
                            role = if (gender == "female") roleSupervisorFemale else roleSupervisorMale
                            expanded = false
                        }
                    )
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = if (gender == "female") roleNurseFemale else roleNurseMale
                            )
                        },
                        onClick = {
                            role = if (gender == "female") roleNurseFemale else roleNurseMale
                            expanded = false
                        }
                    )
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = if (gender == "female") roleAuxFemale else roleAuxMale
                            )
                        },
                        onClick = {
                            role = if (gender == "female") roleAuxFemale else roleAuxMale
                            expanded = false
                        }
                    )
                }
            }

            Button(
                onClick = {
                    isSaving = true
                    onSave(
                        UserProfile(
                            firstName = firstName.trim(),
                            lastName = lastName.trim(),
                            role = role,
                            gender = gender,
                            email = userEmail,
                            plantId = existingProfile?.plantId
                        )
                    ) { isSaving = false }
                },
                enabled = firstName.isNotBlank() && lastName.isNotBlank() && role.isNotBlank() && gender.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF7C3AED),
                    contentColor = Color.White
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .size(20.dp)
                            .padding(end = 8.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                }
                Text(text = stringResource(id = R.string.register_button))
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xB3000000)
@Composable
fun ProfileEditorOverlayPreview() {
    TurnoshospiTheme {
        ProfileEditorOverlay(
            userEmail = "preview@example.com",
            existingProfile = UserProfile(
                firstName = "Carlos",
                lastName = "López",
                role = "Enfermero",
                gender = "male",
                email = "preview@example.com"
            ),
            isLoading = false,
            onDismiss = {},
            onSave = { _, _ -> }
        )
    }
}
