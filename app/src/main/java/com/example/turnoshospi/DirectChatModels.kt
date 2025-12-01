package com.example.turnoshospi

data class DirectMessage(
    val id: String = "",
    val senderId: String = "",
    val text: String = "",
    val timestamp: Long = System.currentTimeMillis(),
    val read: Boolean = false
)

data class ChatUserSummary(
    val userId: String,
    val name: String,
    val role: String,
    val hasUnread: Boolean = false
)

data class ActiveChatSummary(
    val chatId: String,
    val otherUserId: String,
    val otherUserName: String,
    val lastMessage: String,
    val timestamp: Long
)