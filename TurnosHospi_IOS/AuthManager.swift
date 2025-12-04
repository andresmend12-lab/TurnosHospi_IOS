import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    // Variable que publica el estado del usuario (si está logueado o no)
    @Published var user: User?
    
    // Referencia a la base de datos Firestore
    private let db = Firestore.firestore()
    
    init() {
        // Escuchamos los cambios de estado (si el usuario cierra y abre la app)
        Auth.auth().addStateDidChangeListener { auth, user in
            self.user = user
        }
    }
    
    // MARK: - Iniciar Sesión
    func signIn(email: String, pass: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: pass) { result, error in
            if let error = error {
                completion(error.localizedDescription)
            } else {
                completion(nil) // Éxito
            }
        }
    }
    
    // MARK: - Registrarse (Auth + Firestore)
    func register(email: String, pass: String, firstName: String, lastName: String, gender: String, role: String, completion: @escaping (String?) -> Void) {
        
        // 1. Crear el usuario en Firebase Authentication (Email/Pass)
        Auth.auth().createUser(withEmail: email, password: pass) { result, error in
            if let error = error {
                print("❌ Error creando usuario en Auth: \(error.localizedDescription)")
                completion(error.localizedDescription)
                return
            }
            
            // Asegurarnos de tener el UID del usuario recién creado
            guard let uid = result?.user.uid else {
                completion("Error desconocido: No se obtuvo el ID del usuario.")
                return
            }
            
            print("✅ Usuario creado en Auth (UID: \(uid)). Guardando en Firestore...")
            
            // 2. Preparar los datos para la Base de Datos
            // Usamos Date().timeIntervalSince1970 * 1000 para obtener milisegundos
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            
            let userData: [String: Any] = [
                "uid": uid,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "gender": gender, // Se guardará como "male", "female" u "other" según lo que envíe la Vista
                "role": role,     // Ej: "Enfermero"
                "fcmToken": "",   // Se deja vacío por ahora
                "createdAt": timestamp,
                "updatedAt": timestamp
            ]
            
            // 3. Escribir el documento en la colección "users"
            self.db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    print("❌ Error guardando en Firestore: \(error.localizedDescription)")
                    // Nota: El usuario sí se creó en Auth, pero falló la base de datos.
                    // Podrías decidir borrar el usuario de Auth aquí si quieres ser estricto.
                    completion("Usuario creado, pero error al guardar datos: \(error.localizedDescription)")
                } else {
                    print("✅ Datos guardados correctamente en Firestore.")
                    completion(nil) // ¡Todo perfecto!
                }
            }
        }
    }
    
    // MARK: - Cerrar Sesión
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
}
