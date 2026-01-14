import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthManager: ObservableObject {
    
    // 1. Singleton para acceso global (necesario para el AppDelegate)
    static let shared = AuthManager()
     
    @Published var user: User?
    @Published var currentUserName: String = ""
    @Published var currentUserLastName: String = ""
    @Published var userRole: String = ""
    @Published var userPlantId: String = ""
    @Published var totalUnreadChats: Int = 0
    @Published var unreadChatsById: [String: Int] = [:]
    @Published var pendingNavigation: [String: String]? = nil
    
    private let ref = Database.database().reference()
    private var unreadChatsRef: DatabaseReference?
    private var unreadChatsHandle: DatabaseHandle?
    
    // Clave para guardar el token localmente si no hay usuario logueado aún
    private let fcmTokenKey = "cached_fcm_token"
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            if let user = user {
                self?.fetchUserData(uid: user.uid)
                // Al iniciar sesión, intentamos subir el token si lo tenemos guardado
                self?.uploadPendingFcmToken()
                self?.startListeningUnreadChats(uid: user.uid)
            } else {
                self?.stopListeningUnreadChats()
                self?.cleanSession()
            }
        }
    }
    
    // MARK: - Gestión de FCM Token
    
    func updateFcmToken(_ token: String) {
        // 1. Guardar localmente siempre (para tener el último)
        UserDefaults.standard.set(token, forKey: fcmTokenKey)
        
        // 2. Si hay usuario, subir a la base de datos
        if let uid = Auth.auth().currentUser?.uid {
            saveTokenToDatabase(uid: uid, token: token)
        }
    }
    
    private func uploadPendingFcmToken() {
        if let token = UserDefaults.standard.string(forKey: fcmTokenKey),
           let uid = Auth.auth().currentUser?.uid {
            saveTokenToDatabase(uid: uid, token: token)
        }
    }
    
    private func saveTokenToDatabase(uid: String, token: String) {
        // Guardamos el token dentro del nodo del usuario
        ref.child("users").child(uid).updateChildValues(["fcmToken": token]) { error, _ in
            if let error = error {
                AppLogger.error("Error guardando FCM token: \(error.localizedDescription)")
            } else {
                AppLogger.auth("FCM Token actualizado en base de datos para usuario \(uid)")
            }
        }
    }
    
    // MARK: - Obtener datos
    func fetchUserData(uid: String) {
        ref.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                self.currentUserName = value["firstName"] as? String ?? ""
                self.currentUserLastName = value["lastName"] as? String ?? ""
                self.userRole = value["role"] as? String ?? ""
                self.userPlantId = value["plantId"] as? String ?? ""
            }
        }
    }
    
    // MARK: - Actualizar Perfil
    func updateUserProfile(firstName: String, lastName: String, role: String?, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = user?.uid else { return }
        
        var updates: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName
        ]
        if let role = role, !role.isEmpty {
            updates["role"] = role
        }
        
        ref.child("users").child(uid).updateChildValues(updates) { error, _ in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    self.currentUserName = firstName
                    self.currentUserLastName = lastName
                    if let role = role, !role.isEmpty {
                        self.userRole = role
                    }
                }
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Registro
    func register(email: String, pass: String, firstName: String, lastName: String, gender: String?, role: String?, completion: @escaping (String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: pass) { result, error in
            if let error = error {
                completion(error.localizedDescription)
                return
            }
            
            guard let uid = result?.user.uid else { return }
            
            // Obtenemos token pendiente si existe
            let currentToken = UserDefaults.standard.string(forKey: self.fcmTokenKey) ?? ""
            
            var userData: [String: Any] = [
                "uid": uid,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "fcmToken": currentToken, // Guardamos el token al crear el usuario
                "createdAt": ServerValue.timestamp()
            ]
            if let gender = gender, !gender.isEmpty {
                userData["gender"] = gender
            }
            if let role = role, !role.isEmpty {
                userData["role"] = role
            }
            
            self.ref.child("users").child(uid).setValue(userData) { error, _ in
                if let error = error {
                    completion(error.localizedDescription)
                } else {
                    DispatchQueue.main.async {
                        self.currentUserName = firstName
                        self.currentUserLastName = lastName
                        self.userRole = role ?? ""
                    }
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Iniciar Sesión
    func signIn(email: String, pass: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: pass) { result, error in
            if let error = error {
                completion(error.localizedDescription)
            } else {
                // La subida del token se maneja automáticamente en el listener del init
                completion(nil)
            }
        }
    }
    
    // MARK: - Cerrar Sesión
    func signOut() {
        do {
            // Opcional: Eliminar el token de la DB al cerrar sesión para no recibir notificaciones
            // if let uid = user?.uid { ref.child("users").child(uid).child("fcmToken").removeValue() }
            
            try Auth.auth().signOut()
            stopListeningUnreadChats()
            cleanSession()
        } catch {
            AppLogger.error("Error logout: \(error.localizedDescription)")
        }
    }
    
    private func cleanSession() {
        self.currentUserName = ""
        self.currentUserLastName = ""
        self.userRole = ""
        self.userPlantId = ""
        self.totalUnreadChats = 0
        self.unreadChatsById = [:]
        self.pendingNavigation = nil
    }
    
    private func startListeningUnreadChats(uid: String) {
        stopListeningUnreadChats()
        let userChatsRef = Database.database().reference().child("user_direct_chats").child(uid)
        unreadChatsRef = userChatsRef
        
        unreadChatsHandle = userChatsRef.observe(.value) { snapshot in
            var total = 0
            var map: [String: Int] = [:]
            
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let chatId = child.key
                if let data = child.value as? [String: Any] {
                    let unread = data["unreadCount"] as? Int ?? 0
                    map[chatId] = unread
                    total += unread
                }
            }
            
            DispatchQueue.main.async {
                self.totalUnreadChats = total
                self.unreadChatsById = map
            }
        }
    }
    
    private func stopListeningUnreadChats() {
        if let handle = unreadChatsHandle {
            unreadChatsRef?.removeObserver(withHandle: handle)
        }
        unreadChatsRef = nil
        unreadChatsHandle = nil
        DispatchQueue.main.async {
            self.totalUnreadChats = 0
            self.unreadChatsById = [:]
        }
    }

    // MARK: - Eliminar Cuenta (Requisito App Store)

    /// Re-autentica al usuario antes de operaciones sensibles como eliminar cuenta
    func reauthenticate(password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            completion(false, "No hay usuario autenticado")
            return
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }

    /// Elimina completamente la cuenta del usuario
    /// 1. Elimina datos de Realtime Database
    /// 2. Elimina chats del usuario
    /// 3. Elimina el usuario de Firebase Auth
    func deleteAccount(password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, "No hay usuario autenticado")
            return
        }

        let uid = user.uid

        // Primero re-autenticar (Firebase lo requiere para operaciones sensibles)
        reauthenticate(password: password) { [weak self] success, error in
            guard let self = self else { return }

            if !success {
                completion(false, error ?? "Error de autenticación")
                return
            }

            // Eliminar datos del usuario de la base de datos
            self.deleteUserData(uid: uid) { dataDeleted, dataError in
                if !dataDeleted {
                    AppLogger.debug("Advertencia: No se pudieron eliminar todos los datos: \(dataError ?? "")")
                    // Continuamos con la eliminación de la cuenta aunque falle la BD
                }

                // Eliminar la cuenta de Firebase Auth
                user.delete { authError in
                    if let authError = authError {
                        completion(false, authError.localizedDescription)
                    } else {
                        // Limpiar sesión local
                        DispatchQueue.main.async {
                            self.stopListeningUnreadChats()
                            self.cleanSession()
                            // Limpiar token guardado
                            UserDefaults.standard.removeObject(forKey: self.fcmTokenKey)
                        }
                        completion(true, nil)
                    }
                }
            }
        }
    }

    /// Elimina todos los datos del usuario de Firebase Realtime Database
    private func deleteUserData(uid: String, completion: @escaping (Bool, String?) -> Void) {
        let group = DispatchGroup()
        var errors: [String] = []

        // 1. Eliminar perfil del usuario
        group.enter()
        ref.child("users").child(uid).removeValue { error, _ in
            if let error = error {
                errors.append("Perfil: \(error.localizedDescription)")
            }
            group.leave()
        }

        // 2. Eliminar chats directos del usuario
        group.enter()
        ref.child("user_direct_chats").child(uid).removeValue { error, _ in
            if let error = error {
                errors.append("Chats: \(error.localizedDescription)")
            }
            group.leave()
        }

        // 3. Si el usuario tiene planta asignada, eliminar su referencia en la planta
        if !userPlantId.isEmpty {
            group.enter()
            ref.child("plants").child(userPlantId).child("userPlants").child(uid).removeValue { error, _ in
                if let error = error {
                    errors.append("Planta: \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(true, nil)
            } else {
                completion(false, errors.joined(separator: ", "))
            }
        }
    }

    // MARK: - Deep Link Handling
    func handleRemoteNotificationPayload(_ payload: [AnyHashable: Any]) {
        var map: [String: String] = [:]
        for (key, value) in payload {
            if let keyString = key as? String {
                map[keyString] = "\(value)"
            }
        }
        DispatchQueue.main.async {
            self.pendingNavigation = map
        }
    }
    
    func consumePendingNavigation() -> [String: String]? {
        let nav = pendingNavigation
        pendingNavigation = nil
        return nav
    }
}
