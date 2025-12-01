package com.example.turnoshospi

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.database.*
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DirectChatScreen(
    plantId: String,
    currentUserId: String,
    otherUserId: String,
    otherUserName: String,
    onBack: () -> Unit,
) {
    // Generamos el ID del chat ordenando los IDs para que sea consistente
    val chatId = if (currentUserId < otherUserId) "${currentUserId}_${otherUserId}" else "${otherUserId}_${currentUserId}"

    val database = FirebaseDatabase.getInstance("https://turnoshospi-f4870-default-rtdb.firebaseio.com/")
    val messagesRef = database.getReference("plants/$plantId/direct_chats/$chatId/messages")

    val messages = remember { mutableStateListOf<DirectMessage>() }
    var textState by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // --- CORRECCIÓN CLAVE ---
    // Reseteamos el contador a 0 no solo al entrar (Unit), sino también cada vez
    // que la lista de mensajes cambie (messages.size).
    // Esto asegura que si recibes un mensaje mientras tienes el chat abierto, se marque como leído.
    LaunchedEffect(chatId, messages.size) {
        if (currentUserId.isNotBlank()) {
            database.getReference("user_direct_chats/$currentUserId/$chatId/unreadCount").setValue(0)
        }
    }

    DisposableEffect(chatId) {
        val listener = object : ValueEventListener {
            override fun onDataChange(s: DataSnapshot) {
                messages.clear()
                s.children.mapNotNull { it.getValue(DirectMessage::class.java) }.forEach { messages.add(it) }
            }
            override fun onCancelled(e: DatabaseError) {}
        }
        messagesRef.addValueEventListener(listener)
        onDispose { messagesRef.removeEventListener(listener) }
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1)
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(otherUserName, color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Volver", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0F172A))
            )
        },
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF0F172A))
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = textState,
                    onValueChange = { textState = it },
                    placeholder = { Text("Mensaje...", color = Color.Gray) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(24.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    )
                )
                IconButton(onClick = {
                    if (textState.isNotBlank()) {
                        val key = messagesRef.push().key ?: return@IconButton
                        // Enviamos el mensaje. La Cloud Function detectará esto e incrementará el contador del OTRO usuario.
                        messagesRef.child(key).setValue(DirectMessage(key, currentUserId, textState.trim()))
                        textState = ""
                    }
                }) {
                    Icon(Icons.AutoMirrored.Filled.Send, "Enviar", tint = Color(0xFF54C7EC))
                }
            }
        }
    ) { padding ->
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
        ) {
            items(messages) { msg ->
                val isMine = msg.senderId == currentUserId
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalAlignment = if (isMine) Alignment.End else Alignment.Start
                ) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = if (isMine) Color(0xFF54C7EC) else Color(0xFF334155)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text(msg.text, color = if (isMine) Color.Black else Color.White)
                            Text(
                                SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(msg.timestamp)),
                                color = if (isMine) Color.DarkGray else Color.Gray,
                                fontSize = 10.sp,
                                modifier = Modifier.align(Alignment.End)
                            )
                        }
                    }
                }
            }
        }
    }
}