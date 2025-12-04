import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthManager: ObservableObject {
    // Variable que detecta si hay sesión activa
    @Published var user: User?
    
    // Variable para guardar el nombre y mostrarlo en la vista
    @Published var currentUserName: String = ""
    
    private let ref = Database.database().reference()
    
    init() {
        // Escuchar cambios de sesión. Si el usuario ya está logueado, bajamos sus datos.
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            if let user = user {
                self?.fetchUserData(uid: user.uid)
            } else {
                self?.currentUserName = "" // Limpiar nombre si cierra sesión
            }
        }
    }
    
    // MARK: - Obtener datos del usuario (Nombre)
    func fetchUserData(uid: String) {
        // Vamos a la ruta users -> UID
        ref.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            
            // Convertimos la respuesta a un diccionario
            guard let value = snapshot.value as? [String: Any] else {
                print("Error al obtener datos o usuario vacío")
                return
            }
            
            // Extraemos el nombre (firstName)
            if let firstName = value["firstName"] as? String {
                DispatchQueue.main.async {
                    self.currentUserName = firstName
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
                // Al iniciar sesión, Auth listener (en init) se disparará y llamará a fetchUserData
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
            
            let userData: [String: Any] = [
                "uid": uid,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "gender": gender,
                "role": role,
                "createdAt": ServerValue.timestamp()
            ]
            
            self.ref.child("users").child(uid).setValue(userData) { error, _ in
                if let error = error {
                    completion(error.localizedDescription)
                } else {
                    // Actualizamos la variable local inmediatamente para no esperar recarga
                    DispatchQueue.main.async {
                        self.currentUserName = firstName
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
            self.currentUserName = ""
        } catch {
            print("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
}
