import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthService: ObservableObject {
    
    // Publicar cambios para que la UI reaccione
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    
    private let db = Database.database().reference()
    private var authHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        listenToAuthState()
    }
    
    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth Listener
    
    func listenToAuthState() {
        isLoading = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            
            if let user = user {
                // Usuario logueado, buscar su perfil en DB
                self.fetchUserProfile(uid: user.uid)
            } else {
                // Usuario no logueado
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Acciones
    
    func login(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.isLoading = false
                completion(.failure(error))
                return
            }
            // El listener detectará el cambio y cargará el perfil
            completion(.success(()))
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, role: UserRole, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.isLoading = false
                completion(.failure(error))
                return
            }
            
            guard let uid = result?.user.uid else {
                self.isLoading = false
                completion(.failure(NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener el UID"])))
                return
            }
            
            // Crear el modelo de usuario
            let newUser = UserProfile(
                id: uid,
                email: email,
                firstName: firstName,
                lastName: lastName,
                role: role,
                fcmToken: nil // Se actualizará luego con Messaging
            )
            
            // Guardar en Realtime Database
            self.saveUserProfile(user: newUser) { error in
                if let error = error {
                    self.isLoading = false
                    completion(.failure(error))
                } else {
                    // Éxito total
                    // fetchUserProfile se activará por el listener, pero podemos setearlo directamente para rapidez
                    self.currentUser = newUser
                    self.isAuthenticated = true
                    self.isLoading = false
                    completion(.success(()))
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            print("Error al cerrar sesión: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Database Operations
    
    private func saveUserProfile(user: UserProfile, completion: @escaping (Error?) -> Void) {
        do {
            // Codificar el struct a diccionario JSON
            let data = try JSONEncoder().encode(user)
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            
            db.child("users").child(user.id).setValue(json) { error, _ in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    private func fetchUserProfile(uid: String) {
            db.child("users").child(uid).observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let self = self else { return }
                
                // 1. Obtenemos el diccionario
                guard var value = snapshot.value as? [String: Any] else {
                    print("No se encontró perfil para el usuario \(uid)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // 2. CORRECCIÓN: Aseguramos que el ID exista en el diccionario antes de decodificar
                // Si el JSON en Firebase no tiene "id", se lo ponemos aquí usando el uid del nodo.
                value["id"] = uid
                
                do {
                    // 3. Decodificamos el diccionario (ahora ya tiene ID seguro)
                    let jsonData = try JSONSerialization.data(withJSONObject: value)
                    let userProfile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                    
                    DispatchQueue.main.async {
                        self.currentUser = userProfile
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                } catch {
                    print("Error decodificando perfil: \(error)")
                    // Manejar error gracefuly
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }
    
    // Función auxiliar para actualizar token FCM
    func updateFCMToken(token: String) {
        guard let uid = currentUser?.id else { return }
        db.child("users").child(uid).child("fcmToken").setValue(token)
    }
}
