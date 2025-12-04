import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var currentUserName: String = ""
    @Published var currentUserLastName: String = ""
    @Published var userRole: String = ""
    @Published var userPlantId: String = ""
    
    private let ref = Database.database().reference()
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.user = user
            if let user = user {
                self?.fetchUserData(uid: user.uid)
            } else {
                self?.cleanSession()
            }
        }
    }
    
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
    
    func updateUserProfile(firstName: String, lastName: String, role: String, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = user?.uid else { return }
        let updates = ["firstName": firstName, "lastName": lastName, "role": role]
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
    
    func register(email: String, pass: String, firstName: String, lastName: String, gender: String, role: String, completion: @escaping (String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: pass) { result, error in
            if let error = error { completion(error.localizedDescription); return }
            guard let uid = result?.user.uid else { return }
            
            let userData: [String: Any] = [
                "uid": uid, "firstName": firstName, "lastName": lastName, "email": email,
                "gender": gender, "role": role, "createdAt": ServerValue.timestamp()
            ]
            self.ref.child("users").child(uid).setValue(userData) { error, _ in
                if let error = error { completion(error.localizedDescription) }
                else {
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
    
    func signIn(email: String, pass: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: pass) { result, error in
            completion(error?.localizedDescription)
        }
    }
    
    func signOut() {
        do { try Auth.auth().signOut(); cleanSession() } catch {}
    }
    
    private func cleanSession() {
        currentUserName = ""; currentUserLastName = ""; userRole = ""; userPlantId = ""
    }
}
