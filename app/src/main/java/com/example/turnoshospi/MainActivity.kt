package com.example.turnoshospi

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable // [NUEVO] Import necesario
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.tooling.preview.Preview // [NUEVO] Import necesario
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.example.turnoshospi.ui.theme.TurnoshospiTheme
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseNetworkException
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthWeakPasswordException
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.DatabaseException
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import com.google.firebase.messaging.FirebaseMessaging
import java.util.Date

class MainActivity : ComponentActivity() {
    private lateinit var auth: FirebaseAuth
    private lateinit var realtimeDatabase: FirebaseDatabase

    // Estados observables para la UI
    private val currentUserState = mutableStateOf<FirebaseUser?>(null)
    private val authErrorMessage = mutableStateOf<String?>(null)

    // Estado para gestionar la navegación cuando se pulsa una notificación (Deep Linking)
    private val pendingNavigation = mutableStateOf<Map<String, String>?>(null)

    // Launcher para pedir permiso de notificación en Android 13+
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            fetchAndSaveFCMToken()
        } else {
            Log.e("FCM_DEBUG", "Permiso de notificaciones DENEGADO por el usuario.")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        // 1. Crear el canal CON SONIDO y BADGE al iniciar la app
        createNotificationChannel()

        enableEdgeToEdge()
        FirebaseApp.initializeApp(this)
        auth = FirebaseAuth.getInstance()
        realtimeDatabase = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
        currentUserState.value = auth.currentUser

        // Pedir permiso al arrancar si ya hay usuario logueado
        if (currentUserState.value != null) {
            askNotificationPermission()
        }

        // Revisar si la app se abrió desde una notificación (Cold Start)
        intent?.extras?.let { bundle ->
            if (bundle.containsKey("screen")) {
                val navData = mutableMapOf<String, String>()
                for (key in bundle.keySet()) {
                    bundle.getString(key)?.let { navData[key] = it }
                }
                pendingNavigation.value = navData
            }
        }

        setContent {
            TurnoshospiTheme {
                TurnoshospiApp(
                    user = currentUserState.value,
                    errorMessage = authErrorMessage.value,
                    pendingNavigation = pendingNavigation.value, // Pasamos la navegación pendiente
                    onNavigationHandled = { pendingNavigation.value = null }, // Callback para limpiar tras navegar
                    onErrorDismiss = { authErrorMessage.value = null },

                    // Callbacks de Autenticación
                    onLogin = { email, password, onResult ->
                        signInWithEmail(email, password, onResult)
                    },
                    onCreateAccount = { profile, password, onResult ->
                        createAccountWithEmail(profile, password, onResult)
                    },
                    onForgotPassword = { email, onResult ->
                        sendPasswordReset(email, onResult)
                    },

                    // Callbacks de Perfil
                    onLoadProfile = { onResult ->
                        loadUserProfile(onResult)
                    },
                    onSaveProfile = { profile, onResult ->
                        saveUserProfile(profile, onResult)
                    },

                    // Callbacks de Planta
                    onLoadPlant = { onResult ->
                        loadUserPlant(onResult)
                    },
                    onJoinPlant = { plantId, code, profile, onResult ->
                        joinPlantWithCode(plantId, code, profile, onResult)
                    },
                    onLoadPlantMembership = { plantId, userId, onResult ->
                        loadPlantMembership(plantId, userId, onResult)
                    },

                    // Callbacks de Personal
                    onLinkUserToStaff = { plantId, staff, onResult ->
                        linkUserToPlantStaff(plantId, staff, onResult)
                    },
                    onRegisterPlantStaff = { plantId, staffMember, onResult ->
                        registerPlantStaff(plantId, staffMember, onResult)
                    },
                    onEditPlantStaff = { plantId, staffMember, onResult ->
                        editPlantStaff(plantId, staffMember, onResult)
                    },

                    // Callbacks de Turnos
                    onListenToShifts = { plantId, staffId, onResult ->
                        listenToUserShifts(plantId, staffId, onResult)
                    },
                    onFetchColleagues = { plantId, date, shiftName, onResult ->
                        fetchColleaguesForShift(plantId, date, shiftName, onResult)
                    },

                    // Gestión de Cuenta
                    onSignOut = { signOut() },
                    onDeleteAccount = { deleteAccount() },
                    onDeletePlant = { plantId -> deletePlant(plantId) },

                    // Notificaciones
                    onSaveNotification = { userId, type, message, targetScreen, targetId, onResult ->
                        saveNotification(userId, type, message, targetScreen, targetId, onResult)
                    },
                    onListenToNotifications = { userId, onResult ->
                        listenToUserNotifications(userId, onResult)
                    },
                    onMarkNotificationAsRead = { userId, notifId ->
                        markNotificationAsRead(userId, notifId)
                    },
                    onDeleteNotification = { userId, notifId ->
                        deleteUserNotification(userId, notifId)
                    },
                    onClearAllNotifications = { userId ->
                        deleteAllUserNotifications(userId)
                    },
                    // NUEVO: Listener para obtener los contadores de no leídos
                    onListenToChatUnreadCounts = { userId, onResult ->
                        listenToChatUnreadCounts(userId, onResult)
                    }
                )
            }
        }
    }

    // Manejar nuevos intents cuando la app ya está abierta (Warm Start / Foreground)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.extras?.let { bundle ->
            if (bundle.containsKey("screen")) {
                val navData = mutableMapOf<String, String>()
                for (key in bundle.keySet()) {
                    bundle.getString(key)?.let { navData[key] = it }
                }
                pendingNavigation.value = navData
            }
        }
    }

    // --- CONFIGURACIÓN DEL CANAL ---
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "turnoshospi_sound_v2"
            val name = "Avisos de Turnos"
            val descriptionText = "Notificaciones con sonido y alerta visual"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    // --- LÓGICA DE PERMISOS Y TOKENS FCM ---
    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                fetchAndSaveFCMToken()
            }
        } else {
            fetchAndSaveFCMToken()
        }
    }

    private fun fetchAndSaveFCMToken() {
        val user = auth.currentUser
        if (user == null) {
            Log.e("FCM_DEBUG", "Error: No hay usuario logueado para guardar el token.")
            return
        }

        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.e("FCM_DEBUG", "Falló la obtención del token FCM", task.exception)
                return@addOnCompleteListener
            }
            val token = task.result
            Log.d("FCM_DEBUG", "Token obtenido con éxito: $token")

            realtimeDatabase.getReference("users/${user.uid}/fcmToken").setValue(token)
                .addOnSuccessListener {
                    Log.d("FCM_DEBUG", "Token guardado en Base de Datos correctamente.")
                }
                .addOnFailureListener { e ->
                    Log.e("FCM_DEBUG", "Error al guardar token en BD: ${e.message}")
                }
        }
    }

    // --- LÓGICA DE AUTENTICACIÓN ---
    private fun signInWithEmail(email: String, password: String, onResult: (Boolean) -> Unit) {
        authErrorMessage.value = null
        auth.signInWithEmailAndPassword(email.trim(), password)
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    currentUserState.value = auth.currentUser
                    fetchAndSaveFCMToken()
                    onResult(true)
                } else {
                    val errorMessage = task.exception?.let { formatAuthError(it) }
                        ?: "No se pudo iniciar sesión con ese correo"
                    authErrorMessage.value = errorMessage
                    onResult(false)
                }
            }
    }

    private fun createAccountWithEmail(
        profile: UserProfile,
        password: String,
        onResult: (Boolean) -> Unit
    ) {
        authErrorMessage.value = null
        auth.createUserWithEmailAndPassword(profile.email.trim(), password)
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val newUser = auth.currentUser
                    saveUserProfile(profile) { success ->
                        if (success) {
                            fetchAndSaveFCMToken()
                            currentUserState.value = newUser
                        }
                        onResult(success)
                    }
                } else {
                    val errorMessage = task.exception?.let { formatAuthError(it) }
                        ?: "No se pudo crear la cuenta"
                    authErrorMessage.value = errorMessage
                    onResult(false)
                }
            }
    }

    private fun sendPasswordReset(email: String, onResult: (Boolean) -> Unit) {
        authErrorMessage.value = null
        auth.sendPasswordResetEmail(email.trim())
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    onResult(true)
                } else {
                    val errorMessage = task.exception?.let { formatAuthError(it) }
                        ?: "No se pudo enviar el correo de recuperación"
                    authErrorMessage.value = errorMessage
                    onResult(false)
                }
            }
    }

    // --- LÓGICA DE PERFIL Y USUARIO ---
    private fun loadUserProfile(onResult: (UserProfile?) -> Unit) {
        val user = auth.currentUser ?: run {
            onResult(null)
            return
        }

        realtimeDatabase.getReference("users")
            .child(user.uid)
            .get()
            .addOnSuccessListener { snapshot ->
                val profile = snapshot.toUserProfile(user.email.orEmpty())
                onResult(profile)
            }
            .addOnFailureListener { databaseError ->
                authErrorMessage.value = databaseError.message
                onResult(null)
            }
    }

    private fun saveUserProfile(profile: UserProfile, onResult: (Boolean) -> Unit) {
        val user = auth.currentUser ?: run {
            authErrorMessage.value = "Debes iniciar sesión para continuar"
            onResult(false)
            return
        }

        val resolvedEmail = profile.email.ifEmpty { user.email.orEmpty() }

        saveRealtimeUser(user.uid, profile.copy(email = resolvedEmail)) { success ->
            if (!success && authErrorMessage.value == null) {
                authErrorMessage.value = "No se pudo guardar el perfil en tiempo real"
            }
            onResult(success)
        }
    }

    private fun saveRealtimeUser(
        userId: String,
        profile: UserProfile,
        onResult: (Boolean) -> Unit
    ) {
        val currentTime = System.currentTimeMillis()
        val userRef = realtimeDatabase.getReference("users").child(userId)

        userRef.get()
            .addOnSuccessListener { snapshot ->
                val persistedCreatedAt = snapshot.child("createdAt").getValue(Long::class.java)
                val persistedPlantId = snapshot.child("plantId").getValue(String::class.java)
                val resolvedPlantId = profile.plantId ?: persistedPlantId
                val realtimePayload = mutableMapOf<String, Any?>().apply {
                    put("firstName", profile.firstName)
                    put("lastName", profile.lastName)
                    put("role", profile.role)
                    put("gender", profile.gender)
                    put("email", profile.email)
                    put("createdAt", persistedCreatedAt ?: profile.createdAt?.toDate()?.time ?: currentTime)
                    put("updatedAt", currentTime)
                    resolvedPlantId?.let { put("plantId", it) }
                }

                userRef.setValue(realtimePayload)
                    .addOnSuccessListener { onResult(true) }
                    .addOnFailureListener {
                        val message = if (it is DatabaseException) {
                            "Revisa las reglas de Realtime Database y los permisos de escritura"
                        } else {
                            "No se pudo guardar el perfil en tiempo real"
                        }
                        authErrorMessage.value = message
                        onResult(false)
                    }
            }
            .addOnFailureListener {
                val message = if (it is DatabaseException) {
                    "Revisa las reglas de Realtime Database y los permisos de escritura"
                } else {
                    "No se pudo guardar el perfil en tiempo real"
                }
                authErrorMessage.value = message
                onResult(false)
            }
    }

    // --- LÓGICA DE PLANTA ---
    private fun loadUserPlant(onResult: (Plant?, String?) -> Unit) {
        val user = auth.currentUser ?: run {
            onResult(null, getString(R.string.plant_auth_error))
            return
        }

        realtimeDatabase.getReference("users")
            .child(user.uid)
            .child("plantId")
            .get()
            .addOnSuccessListener { mappingSnapshot ->
                val plantId = mappingSnapshot.getValue(String::class.java)
                if (plantId.isNullOrBlank()) {
                    onResult(null, null)
                    return@addOnSuccessListener
                }

                realtimeDatabase.getReference("plants")
                    .child(plantId)
                    .get()
                    .addOnSuccessListener { plantSnapshot ->
                        val plant = plantSnapshot.toPlant()
                        if (plant != null) {
                            onResult(plant, null)
                        } else {
                            onResult(null, getString(R.string.plant_load_error))
                        }
                    }
                    .addOnFailureListener {
                        onResult(null, getString(R.string.plant_load_error))
                    }
            }
            .addOnFailureListener {
                onResult(null, getString(R.string.plant_load_error))
            }
    }

    private fun loadPlantMembership(
        plantId: String,
        userId: String,
        onResult: (PlantMembership?) -> Unit
    ) {
        realtimeDatabase.reference
            .child("plants")
            .child(plantId)
            .child("userPlants")
            .child(userId)
            .get()
            .addOnSuccessListener { snapshot ->
                if (!snapshot.exists()) {
                    onResult(null)
                    return@addOnSuccessListener
                }

                if (snapshot.hasChildren()) {
                    val membership = PlantMembership(
                        plantId = snapshot.child("plantId").getValue(String::class.java) ?: plantId,
                        userId = userId,
                        staffId = snapshot.child("staffId").getValue(String::class.java),
                        staffName = snapshot.child("staffName").getValue(String::class.java),
                        staffRole = snapshot.child("staffRole").getValue(String::class.java)
                    )
                    onResult(membership)
                } else {
                    onResult(
                        PlantMembership(
                            plantId = plantId,
                            userId = userId,
                            staffId = null,
                            staffName = null,
                            staffRole = null
                        )
                    )
                }
            }
            .addOnFailureListener { onResult(null) }
    }

    private fun joinPlantWithCode(
        plantId: String,
        invitationCode: String,
        profile: UserProfile?,
        onResult: (Boolean, String?) -> Unit
    ) {
        val user = auth.currentUser ?: run {
            onResult(false, getString(R.string.plant_auth_error))
            return
        }

        val cleanPlantId = plantId.trim()
        val cleanInvitationCode = invitationCode.trim()

        realtimeDatabase.getReference("plants")
            .child(cleanPlantId)
            .get()
            .addOnSuccessListener { snapshot ->
                if (!snapshot.exists()) {
                    onResult(false, getString(R.string.join_plant_not_found))
                    return@addOnSuccessListener
                }

                val storedCode = snapshot.child("accessPassword").getValue(String::class.java)
                if (storedCode.isNullOrEmpty() || storedCode != cleanInvitationCode) {
                    onResult(false, getString(R.string.invalid_invitation_code))
                    return@addOnSuccessListener
                }

                val updates = mapOf(
                    "plants/$cleanPlantId/userPlants/${user.uid}/plantId" to cleanPlantId,
                    "users/${user.uid}/plantId" to cleanPlantId
                )

                realtimeDatabase.reference
                    .updateChildren(updates)
                    .addOnSuccessListener {
                        onResult(true, null)
                        val joinMessage = getString(R.string.join_plant_success)
                        saveNotification(
                            user.uid,
                            "PLANT_JOINED",
                            "Te has unido a la planta con éxito. $joinMessage",
                            AppScreen.MyPlant.name,
                            cleanPlantId,
                            {}
                        )
                    }
                    .addOnFailureListener {
                        onResult(false, getString(R.string.join_plant_error))
                    }
            }
            .addOnFailureListener {
                onResult(false, getString(R.string.join_plant_error))
            }
    }

    private fun registerPlantStaff(
        plantId: String,
        staffMember: RegisteredUser,
        onResult: (Boolean) -> Unit
    ) {
        val cleanPlantId = plantId.trim()

        if (cleanPlantId.isEmpty()) {
            onResult(false)
            return
        }

        realtimeDatabase.reference
            .child("plants")
            .child(cleanPlantId)
            .child("personal_de_planta")
            .child(staffMember.id)
            .setValue(staffMember)
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener { onResult(false) }
    }

    private fun editPlantStaff(
        plantId: String,
        staffMember: RegisteredUser,
        onResult: (Boolean) -> Unit
    ) {
        val cleanPlantId = plantId.trim()
        if (cleanPlantId.isEmpty() || staffMember.id.isEmpty()) {
            onResult(false)
            return
        }

        realtimeDatabase.reference
            .child("plants")
            .child(cleanPlantId)
            .child("personal_de_planta")
            .child(staffMember.id)
            .setValue(staffMember)
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener { onResult(false) }
    }

    private fun listenToUserShifts(
        plantId: String,
        staffId: String,
        onResult: (Map<String, UserShift>) -> Unit
    ) {
        realtimeDatabase.reference
            .child("plants")
            .child(plantId)
            .child("personal_de_planta")
            .child(staffId)
            .child("name")
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(nameSnapshot: DataSnapshot) {
                    val staffName = nameSnapshot.getValue(String::class.java)

                    if (staffName.isNullOrBlank()) {
                        onResult(emptyMap())
                        return
                    }

                    realtimeDatabase.reference
                        .child("plants")
                        .child(plantId)
                        .child("turnos")
                        .addValueEventListener(object : ValueEventListener {
                            override fun onDataChange(snapshot: DataSnapshot) {
                                val userShifts = mutableMapOf<String, UserShift>()

                                for (dateSnapshot in snapshot.children) {
                                    val dateKey = dateSnapshot.key?.removePrefix("turnos-") ?: continue

                                    for (shiftSnapshot in dateSnapshot.children) {
                                        val shiftName = shiftSnapshot.key ?: continue
                                        var found = false
                                        var isHalf = false

                                        for (slot in shiftSnapshot.child("nurses").children) {
                                            val primary = slot.child("primary").getValue(String::class.java)
                                            val secondary = slot.child("secondary").getValue(String::class.java)
                                            val halfDay = slot.child("halfDay").getValue(Boolean::class.java) ?: false

                                            if (primary == staffName) {
                                                found = true
                                                isHalf = halfDay
                                                break
                                            }
                                            if (secondary == staffName) {
                                                found = true
                                                isHalf = true
                                                break
                                            }
                                        }

                                        if (!found) {
                                            for (slot in shiftSnapshot.child("auxiliaries").children) {
                                                val primary = slot.child("primary").getValue(String::class.java)
                                                val secondary = slot.child("secondary").getValue(String::class.java)
                                                val halfDay = slot.child("halfDay").getValue(Boolean::class.java) ?: false

                                                if (primary == staffName) {
                                                    found = true
                                                    isHalf = halfDay
                                                    break
                                                }
                                                if (secondary == staffName) {
                                                    found = true
                                                    isHalf = true
                                                    break
                                                }
                                            }
                                        }

                                        if (found) {
                                            userShifts[dateKey] = UserShift(shiftName, isHalf)
                                            break
                                        }
                                    }
                                }
                                onResult(userShifts)
                            }

                            override fun onCancelled(error: DatabaseError) {
                            }
                        })
                }

                override fun onCancelled(error: DatabaseError) {
                    onResult(emptyMap())
                }
            })
    }

    private fun fetchColleaguesForShift(
        plantId: String,
        date: String,
        shiftName: String,
        onResult: (List<Colleague>) -> Unit
    ) {
        realtimeDatabase.reference
            .child("plants")
            .child(plantId)
            .child("turnos")
            .child("turnos-$date")
            .child(shiftName)
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val colleagues = mutableListOf<Colleague>()

                    fun collectNames(category: String, roleLabel: String) {
                        for (slot in snapshot.child(category).children) {
                            val primary = slot.child("primary").getValue(String::class.java)
                            val secondary = slot.child("secondary").getValue(String::class.java)

                            if (!primary.isNullOrBlank()) colleagues.add(Colleague(primary, roleLabel))
                            if (!secondary.isNullOrBlank()) colleagues.add(Colleague(secondary, roleLabel))
                        }
                    }

                    collectNames("nurses", "Enfermero/a")
                    collectNames("auxiliaries", "Auxiliar")

                    onResult(colleagues.distinctBy { it.name })
                }

                override fun onCancelled(error: DatabaseError) {
                    onResult(emptyList())
                }
            })
    }

    private fun linkUserToPlantStaff(
        plantId: String,
        staffMember: RegisteredUser,
        onResult: (Boolean) -> Unit
    ) {
        val user = auth.currentUser ?: run {
            onResult(false)
            return
        }

        val updates = mapOf(
            "plants/$plantId/userPlants/${user.uid}/plantId" to plantId,
            "plants/$plantId/userPlants/${user.uid}/staffId" to staffMember.id,
            "plants/$plantId/userPlants/${user.uid}/staffName" to staffMember.name,
            "plants/$plantId/userPlants/${user.uid}/staffRole" to staffMember.role,
            "users/${user.uid}/plantId" to plantId,
            "users/${user.uid}/plantStaffId" to staffMember.id,
            "users/${user.uid}/role" to staffMember.role,
            "users/${user.uid}/linkedStaffName" to staffMember.name
        )

        realtimeDatabase.reference
            .updateChildren(updates)
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener { onResult(false) }
    }

    private fun signOut() {
        auth.signOut()
        currentUserState.value = null
    }

    private fun deleteAccount() {
        val user = auth.currentUser ?: return
        realtimeDatabase.getReference("users").child(user.uid).removeValue()
            .addOnSuccessListener {
                user.delete()
                    .addOnSuccessListener {
                        auth.signOut()
                        currentUserState.value = null
                    }
                    .addOnFailureListener {
                        authErrorMessage.value = formatAuthError(it)
                    }
            }
            .addOnFailureListener {
                authErrorMessage.value = formatAuthError(it)
            }
    }

    private fun deletePlant(plantId: String) {
        realtimeDatabase.getReference("plants").child(plantId).removeValue()
            .addOnFailureListener {
                authErrorMessage.value = "No se pudo borrar la planta. Inténtalo de nuevo."
            }
    }

    private fun saveNotification(
        userId: String,
        type: String,
        message: String,
        targetScreen: String,
        targetId: String?,
        onResult: (Boolean) -> Unit
    ) {
        if (userId.isBlank() || userId == "GROUP_CHAT_FANOUT_ID" || userId == "SUPERVISOR_ID_PLACEHOLDER" || userId == "SHIFT_STAFF_PLACEHOLDER") {
            onResult(true)
            return
        }

        val notificationRef = realtimeDatabase.getReference("user_notifications").child(userId).push()
        val notificationId = notificationRef.key ?: run { onResult(false); return }

        val notification = UserNotification(
            id = notificationId,
            type = type,
            message = message,
            targetScreen = targetScreen,
            targetId = targetId,
            isRead = false
        )

        notificationRef.setValue(notification)
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener {
                authErrorMessage.value = "Error al guardar notificación: ${it.message}"
                onResult(false)
            }
    }

    // --- FUNCIONES PARA NOTIFICACIONES GENERALES ---

    private fun listenToUserNotifications(
        userId: String,
        onResult: (List<UserNotification>) -> Unit
    ) {
        realtimeDatabase.getReference("user_notifications")
            .child(userId)
            .orderByChild("timestamp")
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val notifications = mutableListOf<UserNotification>()
                    for (child in snapshot.children) {
                        val notif = child.getValue(UserNotification::class.java)
                        if (notif != null) {
                            notifications.add(notif)
                        }
                    }
                    onResult(notifications.reversed())
                }

                override fun onCancelled(error: DatabaseError) {
                    onResult(emptyList())
                }
            })
    }

    private fun markNotificationAsRead(userId: String, notificationId: String) {
        realtimeDatabase.getReference("user_notifications")
            .child(userId)
            .child(notificationId)
            .child("isRead")
            .setValue(true)
    }

    private fun deleteUserNotification(userId: String, notificationId: String) {
        realtimeDatabase.getReference("user_notifications")
            .child(userId)
            .child(notificationId)
            .removeValue()
    }

    private fun deleteAllUserNotifications(userId: String) {
        realtimeDatabase.getReference("user_notifications")
            .child(userId)
            .removeValue()
    }

    // --- NUEVO: LISTENER DE CONTADORES DE CHAT ---
    private fun listenToChatUnreadCounts(userId: String, onResult: (Map<String, Int>) -> Unit) {
        realtimeDatabase.getReference("user_direct_chats").child(userId)
            .addValueEventListener(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    val counts = mutableMapOf<String, Int>()
                    for (chatSnap in snapshot.children) {
                        val chatId = chatSnap.key ?: continue
                        val count = chatSnap.child("unreadCount").getValue(Int::class.java) ?: 0
                        counts[chatId] = count
                    }
                    onResult(counts)
                }
                override fun onCancelled(error: DatabaseError) {
                    onResult(emptyMap())
                }
            })
    }

    private fun formatAuthError(exception: Exception): String {
        return when (exception) {
            is FirebaseAuthWeakPasswordException -> "La contraseña es demasiado débil; debe tener al menos 6 caracteres"
            is FirebaseAuthUserCollisionException -> "Ya existe una cuenta registrada con este correo"
            is FirebaseAuthInvalidCredentialsException -> "El correo o la contraseña no son válidos"
            is FirebaseAuthInvalidUserException -> "Esta cuenta no existe o fue deshabilitada"
            is FirebaseAuthException -> when (exception.errorCode) {
                "ERROR_OPERATION_NOT_ALLOWED" -> "Habilita el proveedor de Email/Contraseña en la consola de Firebase"
                else -> "Error de autenticación: ${exception.localizedMessage ?: "intenta de nuevo"}"
            }
            is FirebaseNetworkException -> "No hay conexión con el servidor. Revisa tu conexión a internet"
            else -> "No se pudo completar la operación. Inténtalo de nuevo"
        }
    }
}

// --- MODELOS ---

data class UserShift(
    val shiftName: String,
    val isHalfDay: Boolean
)

data class UserProfile(
    val firstName: String = "",
    val lastName: String = "",
    val role: String = "",
    val gender: String = "",
    val email: String = "",
    val plantId: String? = null,
    val createdAt: Timestamp? = null,
    val updatedAt: Timestamp? = null
)

data class UserNotification(
    val id: String = "",
    val type: String = "",
    val message: String = "",
    val targetScreen: String = "",
    val targetId: String? = null,
    val timestamp: Long = System.currentTimeMillis(),
    val isRead: Boolean = false
)

fun DataSnapshot.toUserProfile(fallbackEmail: String): UserProfile? {
    if (!exists()) return null
    val createdAtMillis = child("createdAt").getValue(Long::class.java)
    val updatedAtMillis = child("updatedAt").getValue(Long::class.java)

    return UserProfile(
        firstName = child("firstName").getValue(String::class.java) ?: "",
        lastName = child("lastName").getValue(String::class.java) ?: "",
        role = child("role").getValue(String::class.java) ?: "",
        gender = child("gender").getValue(String::class.java) ?: "",
        email = child("email").getValue(String::class.java) ?: fallbackEmail,
        plantId = child("plantId").getValue(String::class.java),
        createdAt = createdAtMillis?.let { Timestamp(Date(it)) },
        updatedAt = updatedAtMillis?.let { Timestamp(Date(it)) }
    )
}

fun DataSnapshot.toPlant(): Plant? {
    if (!exists()) return null

    val shiftTimes = child("shiftTimes").children.mapNotNull { shiftSnapshot ->
        val label = shiftSnapshot.key ?: return@mapNotNull null
        val start = shiftSnapshot.child("start").getValue(String::class.java) ?: ""
        val end = shiftSnapshot.child("end").getValue(String::class.java) ?: ""
        label to ShiftTime(start, end)
    }.toMap()

    val staffRequirements = child("staffRequirements").children.mapNotNull { requirementSnapshot ->
        val label = requirementSnapshot.key ?: return@mapNotNull null
        val value = requirementSnapshot.getValue(Int::class.java)
            ?: requirementSnapshot.getValue(Long::class.java)?.toInt()
            ?: 0
        label to value
    }.toMap()

    val personalDePlanta = child("personal_de_planta").children.mapNotNull { userSnapshot ->
        val userId = userSnapshot.key ?: return@mapNotNull null
        val registeredUser = userSnapshot.getValue(RegisteredUser::class.java)
            ?: RegisteredUser(
                id = userId,
                name = userSnapshot.child("name").getValue(String::class.java).orEmpty(),
                role = userSnapshot.child("role").getValue(String::class.java).orEmpty(),
                email = userSnapshot.child("email").getValue(String::class.java).orEmpty(),
                profileType = userSnapshot.child("profileType").getValue(String::class.java).orEmpty()
            )
        userId to registeredUser
    }.toMap()

    return Plant(
        id = child("id").getValue(String::class.java) ?: key.orEmpty(),
        name = child("name").getValue(String::class.java) ?: "",
        unitType = child("unitType").getValue(String::class.java) ?: "",
        hospitalName = child("hospitalName").getValue(String::class.java) ?: "",
        shiftDuration = child("shiftDuration").getValue(String::class.java) ?: "",
        allowHalfDay = child("allowHalfDay").getValue(Boolean::class.java) ?: false,
        staffScope = child("staffScope").getValue(String::class.java) ?: "",
        shiftTimes = shiftTimes,
        staffRequirements = staffRequirements,
        createdAt = child("createdAt").getValue(Long::class.java) ?: 0L,
        accessPassword = child("accessPassword").getValue(String::class.java) ?: "",
        personal_de_planta = personalDePlanta
    )
}

@Preview(showBackground = true, showSystemUi = true)
@Composable
fun MainActivityPreview() {
    TurnoshospiTheme {
        TurnoshospiApp(
            user = null,
            errorMessage = null,
            onErrorDismiss = {},
            pendingNavigation = null, // [NUEVO]
            onNavigationHandled = {}, // [NUEVO]
            onLogin = { _, _, _ -> },
            onCreateAccount = { _, _, _ -> },
            onForgotPassword = { _, _ -> },
            onLoadProfile = { onResult -> onResult(null) },
            onSaveProfile = { _, _ -> },
            onLoadPlant = { onResult -> onResult(null, null) },
            onJoinPlant = { _, _, _, _ -> },
            onLoadPlantMembership = { _, _, _ -> },
            onLinkUserToStaff = { _, _, _ -> },
            onRegisterPlantStaff = { _, _, _ -> },
            onEditPlantStaff = { _, _, _ -> },
            onListenToShifts = { _, _, _ -> },
            onFetchColleagues = { _, _, _, _ -> },
            onSignOut = {},
            onDeleteAccount = {},
            onDeletePlant = {},
            onSaveNotification = { _, _, _, _, _, _ -> },
            onListenToNotifications = { _, _ -> },
            onMarkNotificationAsRead = { _, _ -> },
            onDeleteNotification = { _, _ -> },
            onClearAllNotifications = { _ -> },
            onListenToChatUnreadCounts = { _, _ -> }
        )
    }
}