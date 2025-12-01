package com.example.turnoshospi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlin.random.Random

class MyFirebaseMessagingService : FirebaseMessagingService() {

    // USAR EL MISMO ID QUE EN MAIN ACTIVITY Y MANIFEST
    companion object {
        const val CHANNEL_ID = "turnoshospi_sound_v2"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM", "Refreshed token: $token")
        // Nota: MainActivity ya se encarga de guardar el token si hay usuario logueado.
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d("FCM", "Mensaje recibido de: ${remoteMessage.from}")

        // 1. Extraer datos (Prioridad a DATA para manejar la navegación)
        val data = remoteMessage.data
        if (data.isNotEmpty()) {
            Log.d("FCM", "Payload de datos: $data")
        }

        // Si la Cloud Function envía 'notification' y la app está en foreground, firebase llena esto.
        // Si envía solo 'data', construimos nosotros el título/cuerpo.
        val title = remoteMessage.notification?.title ?: data["title"] ?: "Turnos Hospi"
        val body = remoteMessage.notification?.body ?: data["body"] ?: "Tienes un nuevo mensaje"

        // Datos de navegación
        val screenDest = data["screen"] // Debe ser "DirectChat"
        val plantId = data["plantId"]
        val argument = data["argument"] // ID del otro usuario (para chat)

        sendNotification(title, body, screenDest, plantId, argument)
    }

    private fun sendNotification(
        title: String,
        messageBody: String,
        screen: String?,
        plantId: String?,
        arg: String?
    ) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            // Pasar datos exactos para que MainActivity los capture en onNewIntent o onCreate
            if (screen != null) putExtra("nav_screen", screen)
            if (plantId != null) putExtra("nav_plant_id", plantId)
            if (arg != null) putExtra("nav_argument", arg)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            Random.nextInt(), // RequestCode único para que no se sobrescriban extras si hay varias notif
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Crear el canal si no existe (aunque MainActivity ya lo crea, es bueno por seguridad)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Avisos de Turnos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones de chats y cambios de turno"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // Asegúrate que este icono sea blanco y transparente (regla de Android)
            .setContentTitle(title)
            .setContentText(messageBody)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)

        notificationManager.notify(Random.nextInt(), notificationBuilder.build())
    }
}