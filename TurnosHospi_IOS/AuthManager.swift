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
    
    private let ref = Database.database().reference()
    
    // Clave para guardar el token localmente si no hay usuario logueado aún
    private let fcmTokenKey = "cached_fcm_token"
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            if let user = user {
                self?.fetchUserData(uid: user.uid)
                // Al iniciar sesión, intentamos subir el token si lo tenemos guardado
                self?.uploadPendingFcmToken()
            } else {
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
                print("Error guardando FCM token: \(error.localizedDescription)")
            } else {
                print("FCM Token actualizado en base de datos para usuario \(uid)")
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
    func updateUserProfile(firstName: String, lastName: String, role: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = user?.uid else { return }
        
        let updates = [
            "firstName": firstName,
            "lastName": lastName,
            "role": role
        ]
        
        ref.child("users").child(uid).updateChildValues(updates) { error, _ in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    self.currentUserName = firstName
                    self.currentUserLastName = lastName
                    self.userRole = role
                }
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Registro
    func register(email: String, pass: String, firstName: String, lastName: String, gender: String, role: String, completion: @escaping (String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: pass) { result, error in
            if let error = error {
                completion(error.localizedDescription)
                return
            }
            
            guard let uid = result?.user.uid else { return }
            
            // Obtenemos token pendiente si existe
            let currentToken = UserDefaults.standard.string(forKey: self.fcmTokenKey) ?? ""
            
            let userData: [String: Any] = [
                "uid": uid,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "gender": gender,
                "role": role,
                "fcmToken": currentToken, // Guardamos el token al crear el usuario
                "createdAt": ServerValue.timestamp()
            ]
            
            self.ref.child("users").child(uid).setValue(userData) { error, _ in
                if let error = error {
                    completion(error.localizedDescription)
                } else {
                    DispatchQueue.main.async {
                        self.currentUserName = firstName
                        self.currentUserLastName = lastName
                        self.userRole = role
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
            cleanSession()
        } catch {
            print("Error logout: \(error.localizedDescription)")
        }
    }
    
    private func cleanSession() {
        self.currentUserName = ""
        self.currentUserLastName = ""
        self.userRole = ""
        self.userPlantId = ""
    }
}
