//
//  FirebaseConfig.swift
//  TurnosHospi_IOS
//
//  Configuración centralizada de Firebase Database
//  Todos los paths y referencias deben definirse aquí
//

import Foundation
import FirebaseDatabase

// MARK: - Firebase Configuration

enum FirebaseConfig {

    // MARK: - Database Reference

    /// Referencia principal a la base de datos
    /// La URL se obtiene automáticamente de GoogleService-Info.plist
    static var databaseReference: DatabaseReference {
        Database.database().reference()
    }

    // MARK: - Paths

    /// Paths de nivel superior en la base de datos
    enum Paths {

        // MARK: - Usuarios

        /// Nodo principal de usuarios
        static let users = "users"

        /// Token FCM del usuario
        static let fcmToken = "fcmToken"

        /// Turnos del usuario
        static let shifts = "shifts"

        // MARK: - Plantas

        /// Nodo principal de plantas
        static let plants = "plants"

        /// Personal de la planta
        static let personalDePlanta = "personal_de_planta"

        /// Usuarios asociados a la planta
        static let userPlants = "userPlants"

        /// Turnos de la planta
        static let turnos = "turnos"

        /// Chat grupal de la planta
        static let chat = "chat"

        /// Vacaciones de la planta
        static let vacations = "vacations"

        /// Solicitudes de cambio de turno
        static let shiftRequests = "shift_requests"

        /// Transacciones de favores
        static let transactions = "transactions"

        /// Requerimientos de personal
        static let staffRequirements = "staffRequirements"

        /// Horarios de turnos
        static let shiftTimes = "shiftTimes"

        // MARK: - Notificaciones

        /// Notificaciones de usuario
        static let userNotifications = "user_notifications"

        /// Cola de notificaciones push
        static let notificationsQueue = "notifications_queue"

        /// Estado de lectura
        static let read = "read"

        // MARK: - Chats Directos

        /// Metadatos de chats directos por usuario
        static let userDirectChats = "user_direct_chats"

        /// Nombre del otro usuario
        static let otherUserName = "otherUserName"
    }

    // MARK: - Path Builders

    /// Construye paths comunes de forma type-safe
    enum PathBuilder {

        /// Path a un usuario específico: users/{userId}
        static func user(_ userId: String) -> String {
            "\(Paths.users)/\(userId)"
        }

        /// Path a una planta específica: plants/{plantId}
        static func plant(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)"
        }

        /// Path a turnos de una planta: plants/{plantId}/turnos
        static func plantTurnos(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.turnos)"
        }

        /// Path a turnos de un día: plants/{plantId}/turnos/turnos-{date}
        static func plantTurnosDay(_ plantId: String, date: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.turnos)/turnos-\(date)"
        }

        /// Path a personal de planta: plants/{plantId}/personal_de_planta
        static func plantStaff(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.personalDePlanta)"
        }

        /// Path a miembro específico: plants/{plantId}/personal_de_planta/{staffId}
        static func plantStaffMember(_ plantId: String, staffId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.personalDePlanta)/\(staffId)"
        }

        /// Path a userPlants: plants/{plantId}/userPlants
        static func plantUserPlants(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.userPlants)"
        }

        /// Path a chat grupal: plants/{plantId}/chat
        static func plantChat(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.chat)"
        }

        /// Path a vacaciones: plants/{plantId}/vacations/{userId}
        static func plantVacations(_ plantId: String, userId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.vacations)/\(userId)"
        }

        /// Path a solicitudes de cambio: plants/{plantId}/shift_requests
        static func shiftRequests(_ plantId: String) -> String {
            "\(Paths.plants)/\(plantId)/\(Paths.shiftRequests)"
        }

        /// Path a notificaciones de usuario: user_notifications/{userId}
        static func userNotifications(_ userId: String) -> String {
            "\(Paths.userNotifications)/\(userId)"
        }

        /// Path a chats directos de usuario: user_direct_chats/{userId}
        static func userDirectChats(_ userId: String) -> String {
            "\(Paths.userDirectChats)/\(userId)"
        }

        /// Path a un chat directo específico: user_direct_chats/{userId}/{chatId}
        static func userDirectChat(_ userId: String, chatId: String) -> String {
            "\(Paths.userDirectChats)/\(userId)/\(chatId)"
        }
    }

    // MARK: - Reference Builders

    /// Construye referencias de Firebase de forma type-safe
    enum RefBuilder {

        /// Referencia a usuarios
        static var users: DatabaseReference {
            databaseReference.child(Paths.users)
        }

        /// Referencia a un usuario específico
        static func user(_ userId: String) -> DatabaseReference {
            databaseReference.child(Paths.users).child(userId)
        }

        /// Referencia a plantas
        static var plants: DatabaseReference {
            databaseReference.child(Paths.plants)
        }

        /// Referencia a una planta específica
        static func plant(_ plantId: String) -> DatabaseReference {
            databaseReference.child(Paths.plants).child(plantId)
        }

        /// Referencia a turnos de planta
        static func plantTurnos(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.turnos)
        }

        /// Referencia a turnos de un día específico
        static func plantTurnosDay(_ plantId: String, date: String) -> DatabaseReference {
            plantTurnos(plantId).child("turnos-\(date)")
        }

        /// Referencia a personal de planta
        static func plantStaff(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.personalDePlanta)
        }

        /// Referencia a userPlants
        static func plantUserPlants(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.userPlants)
        }

        /// Referencia a chat grupal
        static func plantChat(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.chat)
        }

        /// Referencia a vacaciones de planta
        static func plantVacations(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.vacations)
        }

        /// Referencia a vacaciones de un usuario
        static func plantVacationsUser(_ plantId: String, userId: String) -> DatabaseReference {
            plantVacations(plantId).child(userId)
        }

        /// Referencia a solicitudes de cambio
        static func shiftRequests(_ plantId: String) -> DatabaseReference {
            plant(plantId).child(Paths.shiftRequests)
        }

        /// Referencia a notificaciones de usuario
        static func userNotifications(_ userId: String) -> DatabaseReference {
            databaseReference.child(Paths.userNotifications).child(userId)
        }

        /// Referencia a chats directos de usuario
        static func userDirectChats(_ userId: String) -> DatabaseReference {
            databaseReference.child(Paths.userDirectChats).child(userId)
        }

        /// Referencia a un chat directo específico
        static func userDirectChat(_ userId: String, chatId: String) -> DatabaseReference {
            userDirectChats(userId).child(chatId)
        }

        /// Referencia a cola de notificaciones
        static var notificationsQueue: DatabaseReference {
            databaseReference.child(Paths.notificationsQueue)
        }
    }
}

// MARK: - Convenience Typealias

typealias FBConfig = FirebaseConfig
typealias FBPaths = FirebaseConfig.Paths
typealias FBRef = FirebaseConfig.RefBuilder
