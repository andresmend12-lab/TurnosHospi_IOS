import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthManager: ObservableObject {
    // Variables publicadas para que las vistas se actualicen solas
    @Published var user: User?
    @Published var currentUserName: String = ""
    @Published var userRole: String = "" // <--- Guardamos el rol aquí
    
    private let ref = Database.database().reference()
    
    init() {
        // Escuchar cambios de sesión
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            if let user = user {
                // Si hay usuario, descargamos sus datos
                self?.fetchUserData(uid: user.uid)
            } else {
                // Si cerramos sesión, limpiamos todo
                self?.currentUserName = ""
                self?.userRole = ""
            }
        }
    }
    
    // MARK: - Obtener datos (Nombre y Rol)
    func fetchUserData(uid: String) {
        ref.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            // 1. Obtener Nombre
            if let firstName = value["firstName"] as? String {
                DispatchQueue.main.async {
                    self.currentUserName = firstName
                }
            }
            
            // 2. Obtener Rol (Supervisor, Enfermero, etc.)
            if let role = value["role"] as? String {
                DispatchQueue.main.async {
                    self.userRole = role
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
                completion(nil)
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
            
            // Guardamos todos los datos, incluido el ROL
            let userData: [String: Any] = [
                "uid": uid,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "gender": gender,
                "role": role, // <--- Importante
                "createdAt": ServerValue.timestamp()
            ]
            
            self.ref.child("users").child(uid).setValue(userData) { error, _ in
                if let error = error {
                    completion(error.localizedDescription)
                } else {
                    // Actualizamos localmente para no esperar
                    DispatchQueue.main.async {
                        self.currentUserName = firstName
                        self.userRole = role
                    }
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Cerrar Sesión
    func signOut() {
        do {
            try Auth.auth().signOut()
            // Limpiamos variables locales
            self.currentUserName = ""
            self.userRole = ""
        } catch {
            print("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
}
