package com.example.turnoshospi

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DirectChatListScreen(
    plantId: String,
    currentUserId: String,
    unreadCounts: Map<String, Int>,
    onBack: () -> Unit,
    onNavigateToChat: (String, String) -> Unit
) {
    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")

    // Estados de datos
    val activeChats = remember { mutableStateListOf<ActiveChatSummary>() }
    val availableUsers = remember { mutableStateListOf<ChatUserSummary>() }
    var isLoadingChats by remember { mutableStateOf(true) }

    // Estados de UI
    var showNewChatDialog by remember { mutableStateOf(false) }
    var chatToDelete by remember { mutableStateOf<ActiveChatSummary?>(null) }

    // 1. Cargar Chats Activos
    LaunchedEffect(plantId, currentUserId) {
        val chatsRef = database.getReference("plants/$plantId/direct_chats")
        chatsRef.addValueEventListener(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val tempChats = mutableListOf<ActiveChatSummary>()

                snapshot.children.forEach { chatSnap ->
                    val chatId = chatSnap.key ?: return@forEach
                    if (chatId.contains(currentUserId)) {
                        val ids = chatId.split("_")
                        val otherId = if (ids[0] == currentUserId) ids.getOrNull(1) else ids[0]

                        if (otherId != null) {
                            val messagesSnap = chatSnap.child("messages")
                            val lastMsgSnap = messagesSnap.children.lastOrNull()
                            val lastText = lastMsgSnap?.child("text")?.value.toString()
                            val timestamp = lastMsgSnap?.child("timestamp")?.value as? Long ?: 0L

                            tempChats.add(ActiveChatSummary(chatId, otherId, "Cargando...", lastText, timestamp))
                        }
                    }
                }
                tempChats.sortByDescending { it.timestamp }
                activeChats.clear()
                activeChats.addAll(tempChats)
                isLoadingChats = false
            }
            override fun onCancelled(error: DatabaseError) { isLoadingChats = false }
        })

        // 2. CORRECCIÓN: Cargar Usuarios buscando en los miembros de la planta (userPlants)
        // en lugar de escanear toda la tabla 'users'.
        val plantMembersRef = database.getReference("plants/$plantId/userPlants")

        plantMembersRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                availableUsers.clear()
                val userIdsToFetch = snapshot.children.mapNotNull { it.key }.filter { it != currentUserId }

                if (userIdsToFetch.isEmpty()) {
                    // No hay más usuarios
                    return
                }

                // Para cada ID encontrado en la planta, buscamos sus detalles en 'users'
                userIdsToFetch.forEach { uid ->
                    database.getReference("users/$uid").addListenerForSingleValueEvent(object : ValueEventListener {
                        override fun onDataChange(userSnap: DataSnapshot) {
                            val firstName = userSnap.child("firstName").getValue(String::class.java) ?: ""
                            val lastName = userSnap.child("lastName").getValue(String::class.java) ?: ""
                            val role = userSnap.child("role").getValue(String::class.java) ?: "Sin rol"
                            val email = userSnap.child("email").getValue(String::class.java) ?: ""

                            val fullName = "$firstName $lastName".trim()
                            val displayName = if (fullName.isNotEmpty()) fullName else email.ifEmpty { "Usuario" }

                            // Añadir a la lista de usuarios disponibles
                            val userSummary = ChatUserSummary(userId = uid, name = displayName, role = role)
                            if (availableUsers.none { it.userId == uid }) {
                                availableUsers.add(userSummary)
                            }

                            // Actualizar nombre en chats activos si ya existía
                            val index = activeChats.indexOfFirst { it.otherUserId == uid }
                            if (index != -1) {
                                activeChats[index] = activeChats[index].copy(otherUserName = displayName)
                            }
                        }
                        override fun onCancelled(error: DatabaseError) {}
                    })
                }
            }
            override fun onCancelled(error: DatabaseError) {}
        })
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text("Mis Chats", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Volver", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent)
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showNewChatDialog = true },
                containerColor = Color(0xFF54C7EC),
                contentColor = Color.Black,
                modifier = Modifier.padding(start = 32.dp)
            ) {
                Icon(Icons.Default.Add, "Nuevo Chat")
            }
        },
        floatingActionButtonPosition = FabPosition.Start
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (isLoadingChats) {
                CircularProgressIndicator(color = Color(0xFF54C7EC), modifier = Modifier.align(Alignment.Center))
            } else if (activeChats.isEmpty()) {
                Column(modifier = Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("No tienes chats recientes.", color = Color.Gray)
                    Text("Pulsa + para empezar.", color = Color.Gray, fontSize = 12.sp)
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(activeChats) { chat ->
                        val unreadCount = unreadCounts[chat.chatId] ?: 0
                        // Intentamos buscar el nombre actualizado en availableUsers
                        val updatedName = availableUsers.find { it.userId == chat.otherUserId }?.name ?: chat.otherUserName

                        Box {
                            ActiveChatCard(
                                chat = chat.copy(otherUserName = updatedName),
                                unreadCount = unreadCount,
                                onClick = { onNavigateToChat(chat.otherUserId, updatedName) },
                                onLongClick = { chatToDelete = chat }
                            )

                            DropdownMenu(
                                expanded = chatToDelete == chat,
                                onDismissRequest = { chatToDelete = null },
                                containerColor = Color(0xFF1E293B)
                            ) {
                                DropdownMenuItem(
                                    text = { Text("Borrar chat", color = Color(0xFFFFB4AB)) },
                                    leadingIcon = { Icon(Icons.Default.Delete, null, tint = Color(0xFFFFB4AB)) },
                                    onClick = {
                                        database.getReference("plants/$plantId/direct_chats/${chat.chatId}").removeValue()
                                        database.getReference("user_direct_chats/$currentUserId/${chat.chatId}").removeValue()
                                        activeChats.remove(chat)
                                        chatToDelete = null
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (showNewChatDialog) {
        ModalBottomSheet(
            onDismissRequest = { showNewChatDialog = false },
            containerColor = Color(0xFF0F172A),
            contentColor = Color.White
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    "Iniciar nuevo chat",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 16.dp)
                )

                if (availableUsers.isEmpty()) {
                    Text("No se encontraron otros usuarios registrados en esta planta.", color = Color.Gray)
                } else {
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(availableUsers) { user ->
                            UserSelectionCard(user) {
                                showNewChatDialog = false
                                onNavigateToChat(user.userId, user.name)
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ActiveChatCard(
    chat: ActiveChatSummary,
    unreadCount: Int,
    onClick: () -> Unit,
    onLongClick: () -> Unit
) {
    val dateFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    val dateStr = if (chat.timestamp > 0) dateFormat.format(Date(chat.timestamp)) else ""
    val lastMsgDisplay = if (chat.lastMessage == "null" || chat.lastMessage.isBlank()) "Mensaje..." else chat.lastMessage

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
        colors = CardDefaults.cardColors(containerColor = Color(0x22FFFFFF)),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFA855F7)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = chat.otherUserName.take(1).uppercase(),
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(chat.otherUserName, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    if (unreadCount > 0) {
                        Badge(containerColor = Color.Red, contentColor = Color.White) {
                            Text(text = unreadCount.toString(), modifier = Modifier.padding(horizontal = 4.dp))
                        }
                    } else {
                        Text(dateStr, color = Color(0xAAFFFFFF), fontSize = 12.sp)
                    }
                }
                Text(
                    text = lastMsgDisplay,
                    color = Color(0xCCFFFFFF),
                    fontSize = 14.sp,
                    fontWeight = if (unreadCount > 0) FontWeight.Bold else FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserSelectionCard(user: ChatUserSummary, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color(0x11FFFFFF)),
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF54C7EC)),
                contentAlignment = Alignment.Center
            ) {
                Text(user.name.take(1).uppercase(), fontWeight = FontWeight.Bold, color = Color.Black)
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(user.name, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text(user.role, color = Color.Gray, fontSize = 12.sp)
            }
        }
    }
}