const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

// ==================================================================
// 1. Notificaciones Generales (MOTOR CENTRAL DE PUSH)
// Esta función escucha la DB y envía la Push.
// Todas las demás funciones solo deben escribir en la DB.
// ==================================================================
exports.sendNotification = functions.database.ref('/user_notifications/{userId}/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const notification = snapshot.val();
        const userId = context.params.userId;

        // Evitar enviar push si la notificación ya fue marcada como leída (por si acaso)
        if (notification.read) return null;

        const userSnapshot = await admin.database().ref(`/users/${userId}/fcmToken`).once('value');
        const fcmToken = userSnapshot.val();

        if (!fcmToken) {
            console.log(`Usuario ${userId} no tiene token FCM.`);
            return null;
        }

        const message = {
            token: fcmToken,
            notification: {
                title: notification.title || "Shift Manager",
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
                // Mapeo flexible para asegurar que Android reciba los extras correctos
                plantId: notification.targetId || "",
                argument: notification.argument || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        };

        try {
            return await admin.messaging().send(message);
        } catch (error) {
            console.error('Error enviando notificación push:', error);
            return null;
        }
    });

// ==================================================================
// 2. Notificaciones de Chat
// ==================================================================
exports.sendChatNotification = functions.database.ref('/plants/{plantId}/direct_chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.val();
        const plantId = context.params.plantId;
        const chatId = context.params.chatId;

        const senderId = messageData.senderId;
        const text = messageData.text;

        const ids = chatId.split("_");
        const receiverId = (ids[0] === senderId) ? ids[1] : ids[0];

        if (!receiverId) return null;

        // 1. Actualizar metadatos del chat
        const chatMetaRef = admin.database().ref(`/user_direct_chats/${receiverId}/${chatId}`);
        await chatMetaRef.transaction((currentData) => {
            const count = (currentData && currentData.unreadCount) ? currentData.unreadCount + 1 : 1;
            return {
                ...currentData,
                unreadCount: count,
                lastMessage: text,
                timestamp: admin.database.ServerValue.TIMESTAMP,
                plantId: plantId,
                otherUserId: senderId
            };
        });

        // 2. Enviar Push directamente (EXCEPCIÓN: Chat no usa user_notifications para historial, solo Push directa)
        // NOTA: Si quisieras historial de "Te han escrito", deberías escribir en user_notifications,
        // pero para chats suele ser molesto llenar el historial. Lo dejamos como push directa.
        const userSnapshot = await admin.database().ref(`/users/${receiverId}/fcmToken`).once('value');
        const fcmToken = userSnapshot.val();
        if (!fcmToken) return null;

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
                    channelId: "turnoshospi_sound_v2",
                    sound: "default",
                    icon: "ic_logo_hospi_round",
                    tag: chatId // Agrupa notificaciones del mismo chat
                }
            },
            data: {
                screen: "DirectChat",
                chatId: chatId,
                plantId: plantId,
                otherUserId: senderId,
                otherUserName: senderName,
                click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
        };

        return admin.messaging().send(pushMessage);
    });

// ==================================================================
// 4. Notificar al Supervisor Y al Solicitante (ESTADO: PENDIENTE APROBACIÓN)
// ==================================================================
exports.notifySupervisorOnPending = functions.database.ref('/plants/{plantId}/shift_requests/{requestId}')
    .onUpdate(async (change, context) => {
        const before = change.before.val();
        const after = change.after.val();
        const plantId = context.params.plantId;
        const requestId = context.params.requestId;

        // Detectar cambio a AWAITING_SUPERVISOR
        if (before.status !== 'AWAITING_SUPERVISOR' && after.status === 'AWAITING_SUPERVISOR') {
            const requesterName = after.requesterName || "Usuario";
            const targetName = after.targetUserName || "Compañero";
            const shiftDate = after.requesterShiftDate;
            const supervisorIds = after.supervisorIds;
            const requesterId = after.requesterId;

            console.log(`Cambio pendiente de supervisor. Requester: ${requesterId}, Supervisors: ${supervisorIds}`);

            const promises = [];

            // A. Notificar al REQUESTER (Tú) de que el compañero aceptó
            if (requesterId) {
                const reqNotifRef = admin.database().ref(`/user_notifications/${requesterId}`).push();
                promises.push(reqNotifRef.set({
                    title: "Compañero aceptó",
                    message: `${targetName} ha aceptado el cambio. Pendiente de aprobación del supervisor.`,
                    timestamp: admin.database.ServerValue.TIMESTAMP,
                    read: false,
                    targetScreen: "ShiftChangeScreen",
                    targetId: plantId,
                    argument: requestId
                }));
            }

            // B. Notificar a los SUPERVISORES
            // Función auxiliar para escribir en DB del supervisor (La función 1 enviará la Push)
            const notifySupervisorDB = (supId) => {
                const notifRef = admin.database().ref(`/user_notifications/${supId}`).push();
                return notifRef.set({
                    title: "Solicitud Requiere Aprobación",
                    message: `${targetName} aceptó el cambio con ${requesterName} (${shiftDate}).`,
                    timestamp: admin.database.ServerValue.TIMESTAMP,
                    read: false,
                    targetScreen: "ShiftChangeScreen",
                    targetId: plantId,
                    argument: requestId
                });
            };

            // Caso 1: Lista directa de IDs (Rápido)
            if (supervisorIds && Array.isArray(supervisorIds) && supervisorIds.length > 0) {
                for (const supId of supervisorIds) {
                    promises.push(notifySupervisorDB(supId));
                }
            }
            // Caso 2: Fallback buscando en userPlants (Lento)
            else {
                const usersSnap = await admin.database().ref(`/plants/${plantId}/userPlants`).once('value');
                if (usersSnap.exists()) {
                    usersSnap.forEach((userChild) => {
                        const role = userChild.child("staffRole").val() || "";
                        const userId = userChild.key;
                        if (role.toLowerCase().includes("supervisor")) {
                            promises.push(notifySupervisorDB(userId));
                        }
                    });
                }
            }

            return Promise.all(promises);
        }
        return null;
    });

// ==================================================================
// 5. Notificar a Usuarios (Supervisor Aprueba o Rechaza)
// ==================================================================
exports.notifyUsersOnStatusChange = functions.database.ref('/plants/{plantId}/shift_requests/{requestId}')
    .onUpdate(async (change, context) => {
        const before = change.before.val();
        const after = change.after.val();
        const plantId = context.params.plantId;
        const requestId = context.params.requestId;

        const requesterId = after.requesterId;
        const targetUserId = after.targetUserId;
        const requesterName = after.requesterName;
        const targetName = after.targetUserName;
        const shiftDate = after.requesterShiftDate;

        const promises = [];

        // Función auxiliar: SOLO escribe en DB. La función 1 enviará la Push.
        const saveNotification = async (userId, title, body) => {
            if (!userId || userId.startsWith("UNREGISTERED")) return;

            const notifRef = admin.database().ref(`/user_notifications/${userId}`).push();
            return notifRef.set({
                title: title,
                message: body,
                timestamp: admin.database.ServerValue.TIMESTAMP,
                read: false,
                targetScreen: "ShiftChangeScreen",
                targetId: plantId,
                argument: requestId
            });
        };

        // APROBADO
        if (before.status !== 'APPROVED' && after.status === 'APPROVED') {
            if (requesterId) promises.push(saveNotification(requesterId, "¡Cambio Aprobado!", `El supervisor aprobó tu cambio con ${targetName} (${shiftDate}).`));
            if (targetUserId) promises.push(saveNotification(targetUserId, "¡Cambio Aprobado!", `El supervisor aprobó el cambio con ${requesterName} (${shiftDate}).`));
        }

        // RECHAZADO
        if (before.status !== 'REJECTED' && after.status === 'REJECTED') {
            if (requesterId) promises.push(saveNotification(requesterId, "Solicitud Rechazada", `La solicitud de cambio para el ${shiftDate} ha sido rechazada.`));
            if (targetUserId) promises.push(saveNotification(targetUserId, "Solicitud Rechazada", `La solicitud de cambio con ${requesterName} ha sido rechazada.`));
        }

        return Promise.all(promises);
    });

// ==================================================================
// 6. Notificar al Destinatario cuando recibe una PROPUESTA
// ==================================================================
exports.notifyTargetOnProposal = functions.database.ref('/plants/{plantId}/shift_requests/{requestId}')
    .onUpdate(async (change, context) => {
        const before = change.before.val();
        const after = change.after.val();
        const plantId = context.params.plantId;
        const requestId = context.params.requestId;

        // Detectar cambio a PENDING_PARTNER (Propuesta directa enviada)
        if (before.status !== 'PENDING_PARTNER' && after.status === 'PENDING_PARTNER') {
            const targetUserId = after.targetUserId;
            const requesterName = after.requesterName || "Un compañero";
            const requesterShiftDate = after.requesterShiftDate;
            const targetShiftDate = after.targetShiftDate;

            if (!targetUserId || targetUserId.startsWith("UNREGISTERED")) return null;

            console.log(`Nueva propuesta directa enviada a: ${targetUserId}`);

            const title = "Te han propuesto un cambio";
            const body = `${requesterName} quiere cambiar su turno del ${requesterShiftDate} por tu turno del ${targetShiftDate}.`;

            // SOLO Guardar en DB Interna.
            // La Función 1 detectará esto y enviará la Push automáticamente.
            const notifRef = admin.database().ref(`/user_notifications/${targetUserId}`).push();
            return notifRef.set({
                title: title,
                message: body,
                timestamp: admin.database.ServerValue.TIMESTAMP,
                read: false,
                targetScreen: "ShiftChangeScreen",
                targetId: plantId,
                argument: requestId
            });
        }
        return null;
    });

// ==================================================================
// 7. VALIDACION SERVER-SIDE: Estado de Solicitudes de Cambio
// Verifica que solo supervisores puedan aprobar/rechazar solicitudes
// ==================================================================
exports.validateShiftRequestStatus = functions.database.ref('/plants/{plantId}/shift_requests/{requestId}/status')
    .onUpdate(async (change, context) => {
        const beforeStatus = change.before.val();
        const afterStatus = change.after.val();
        const plantId = context.params.plantId;
        const requestId = context.params.requestId;
        const authUid = context.auth ? context.auth.uid : null;

        // Estados que requieren privilegios de supervisor
        const supervisorOnlyStatuses = ['APPROVED', 'REJECTED'];

        // Si el nuevo status requiere ser supervisor
        if (supervisorOnlyStatuses.includes(afterStatus)) {
            // Verificar que hay un usuario autenticado
            if (!authUid) {
                console.error(`[SECURITY] Intento de cambio sin autenticacion. Plant: ${plantId}, Request: ${requestId}, Status: ${afterStatus}`);
                // Revertir al estado anterior
                await change.after.ref.set(beforeStatus);
                return null;
            }

            // Verificar rol del usuario en la planta
            const userPlantRef = admin.database().ref(`/plants/${plantId}/userPlants/${authUid}`);
            const userPlantSnap = await userPlantRef.once('value');

            if (!userPlantSnap.exists()) {
                console.error(`[SECURITY] Usuario ${authUid} no pertenece a planta ${plantId}. Intento de aprobar solicitud ${requestId}`);
                await change.after.ref.set(beforeStatus);
                await logSecurityEvent(plantId, authUid, 'UNAUTHORIZED_STATUS_CHANGE', {
                    requestId,
                    attemptedStatus: afterStatus,
                    reason: 'User not in plant'
                });
                return null;
            }

            const staffRole = userPlantSnap.child('staffRole').val() || '';
            const isSupervisor = staffRole.toLowerCase().includes('supervisor');

            if (!isSupervisor) {
                console.error(`[SECURITY] Usuario ${authUid} con rol "${staffRole}" intento aprobar/rechazar solicitud ${requestId}`);
                // Revertir el cambio
                await change.after.ref.set(beforeStatus);
                // Loguear intento sospechoso
                await logSecurityEvent(plantId, authUid, 'UNAUTHORIZED_APPROVAL_ATTEMPT', {
                    requestId,
                    attemptedStatus: afterStatus,
                    userRole: staffRole
                });
                return null;
            }

            // Usuario es supervisor - permitir el cambio y loguear
            console.log(`[AUDIT] Supervisor ${authUid} cambio solicitud ${requestId} a ${afterStatus}`);
        }

        return null;
    });

// ==================================================================
// 8. VALIDACION SERVER-SIDE: Escrituras en Turnos
// Verifica que solo supervisores puedan modificar turnos
// ==================================================================
exports.validateShiftWrite = functions.database.ref('/plants/{plantId}/turnos/{dateKey}/{shiftName}')
    .onWrite(async (change, context) => {
        const plantId = context.params.plantId;
        const dateKey = context.params.dateKey;
        const shiftName = context.params.shiftName;
        const authUid = context.auth ? context.auth.uid : null;

        // Permitir eliminaciones (cuando after no existe) solo si es supervisor
        const isDelete = !change.after.exists();
        const isCreate = !change.before.exists() && change.after.exists();
        const isUpdate = change.before.exists() && change.after.exists();

        // Verificar autenticacion
        if (!authUid) {
            console.error(`[SECURITY] Escritura en turnos sin autenticacion. Plant: ${plantId}, Date: ${dateKey}, Shift: ${shiftName}`);
            // Revertir: restaurar datos anteriores o eliminar si era creacion
            if (isCreate) {
                await change.after.ref.remove();
            } else if (isUpdate || isDelete) {
                await change.after.ref.set(change.before.val());
            }
            return null;
        }

        // Verificar rol del usuario
        const userPlantRef = admin.database().ref(`/plants/${plantId}/userPlants/${authUid}`);
        const userPlantSnap = await userPlantRef.once('value');

        if (!userPlantSnap.exists()) {
            console.error(`[SECURITY] Usuario ${authUid} no pertenece a planta ${plantId}. Intento de modificar turno.`);
            if (isCreate) {
                await change.after.ref.remove();
            } else {
                await change.after.ref.set(change.before.val());
            }
            await logSecurityEvent(plantId, authUid, 'UNAUTHORIZED_SHIFT_WRITE', {
                dateKey,
                shiftName,
                action: isCreate ? 'CREATE' : isDelete ? 'DELETE' : 'UPDATE',
                reason: 'User not in plant'
            });
            return null;
        }

        const staffRole = userPlantSnap.child('staffRole').val() || '';
        const isSupervisor = staffRole.toLowerCase().includes('supervisor');

        if (!isSupervisor) {
            console.error(`[SECURITY] Usuario ${authUid} (rol: ${staffRole}) intento modificar turno ${dateKey}/${shiftName}`);
            // Revertir el cambio
            if (isCreate) {
                await change.after.ref.remove();
            } else {
                await change.after.ref.set(change.before.val());
            }
            await logSecurityEvent(plantId, authUid, 'UNAUTHORIZED_SHIFT_MODIFICATION', {
                dateKey,
                shiftName,
                action: isCreate ? 'CREATE' : isDelete ? 'DELETE' : 'UPDATE',
                userRole: staffRole
            });
            return null;
        }

        // Usuario es supervisor - permitir y loguear
        const action = isCreate ? 'CREATE' : isDelete ? 'DELETE' : 'UPDATE';
        console.log(`[AUDIT] Supervisor ${authUid} realizo ${action} en turno ${dateKey}/${shiftName}`);
        return null;
    });

// ==================================================================
// UTILIDAD: Loguear eventos de seguridad
// ==================================================================
async function logSecurityEvent(plantId, userId, eventType, details) {
    const logRef = admin.database().ref('/security_logs').push();
    return logRef.set({
        plantId: plantId,
        userId: userId,
        eventType: eventType,
        details: details,
        timestamp: admin.database.ServerValue.TIMESTAMP,
        serverTime: new Date().toISOString()
    });
}