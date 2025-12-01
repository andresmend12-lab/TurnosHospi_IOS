const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

// 1. Notificaciones Generales (Sistema existente)
exports.sendNotification = functions.database.ref('/user_notifications/{userId}/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const notification = snapshot.val();
        const userId = context.params.userId;

        console.log('Nueva notificacion para:', userId);

        const userSnapshot = await admin.database().ref(`/users/${userId}/fcmToken`).once('value');
        const fcmToken = userSnapshot.val();

        if (!fcmToken) {
            console.log('Sin token para usuario:', userId);
            return null;
        }

        const message = {
            token: fcmToken,
            notification: {
                title: "Turnoshospi",
                body: notification.message
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "turnoshospi_sound_v2",
                    sound: "default",
                    priority: "high",
                    defaultSound: true,
                    icon: "ic_logo_hospi_round"
                }
            },
            data: {
                screen: notification.targetScreen || "MainMenu",
                targetId: notification.targetId || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        };

        try {
            const response = await admin.messaging().send(message);
            console.log('Mensaje enviado con éxito:', response);
            return response;
        } catch (error) {
            console.error('Error enviando notificación:', error);
            return null;
        }
    });

// 2. NUEVO: Notificaciones de Chat y Contadores
exports.sendChatNotification = functions.database.ref('/plants/{plantId}/direct_chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.val();
        const plantId = context.params.plantId;
        const chatId = context.params.chatId;

        const senderId = messageData.senderId;
        const text = messageData.text;

        // Deducir receiverId del chatId (el formato es id1_id2)
        const ids = chatId.split("_");
        // El receptor es el ID que NO coincide con el senderId
        const receiverId = (ids[0] === senderId) ? ids[1] : ids[0];

        if (!receiverId) return console.log("No receiverId found in chat:", chatId);

        console.log(`Nuevo mensaje de ${senderId} para ${receiverId} en planta ${plantId}`);

        // A. Actualizar metadata del chat para el receptor (Contador de no leídos)
        // Guardamos esto en una ruta fácil de leer para la app: user_direct_chats/{userId}
        const chatMetaRef = admin.database().ref(`/user_direct_chats/${receiverId}/${chatId}`);

        await chatMetaRef.transaction((currentData) => {
            // Si existe dato previo, incrementamos. Si no, empezamos en 1.
            const count = (currentData && currentData.unreadCount) ? currentData.unreadCount + 1 : 1;
            return {
                ...currentData,
                unreadCount: count,
                lastMessage: text,
                timestamp: admin.database.ServerValue.TIMESTAMP,
                plantId: plantId, // Guardamos plantId para facilitar navegación si hace falta
                otherUserId: senderId // Guardamos quién es la otra persona
            };
        });

        // B. Enviar Notificación Push
        const userSnapshot = await admin.database().ref(`/users/${receiverId}/fcmToken`).once('value');
        const fcmToken = userSnapshot.val();

        if (!fcmToken) return console.log('Sin token para receptor de chat:', receiverId);

        // Obtener nombre del remitente para mostrar en la notificación
        const senderSnapshot = await admin.database().ref(`/users/${senderId}`).once('value');
        const senderUser = senderSnapshot.val();
        const senderName = senderUser ? `${senderUser.firstName} ${senderUser.lastName}` : "Compañero";

        const pushMessage = {
            token: fcmToken,
            notification: {
                title: senderName,
                body: text
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "turnoshospi_sound_v2", // Canal con sonido
                    sound: "default",
                    priority: "high",
                    defaultSound: true,
                    icon: "ic_logo_hospi_round",
                    tag: chatId // Agrupa notificaciones del mismo chat para no llenar la barra
                }
            },
            data: {
                // Datos para que la App sepa abrir el chat directamente
                screen: "DirectChat",
                chatId: chatId,
                plantId: plantId,
                otherUserId: senderId,
                otherUserName: senderName,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        };

        try {
            return await admin.messaging().send(pushMessage);
        } catch (error) {
            console.error('Error enviando push de chat:', error);
            return null;
        }
    });