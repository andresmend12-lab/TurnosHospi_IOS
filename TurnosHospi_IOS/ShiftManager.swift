import Foundation
import FirebaseDatabase
import FirebaseAuth

class ShiftManager: ObservableObject {
    @Published var userShifts: [Shift] = []
    private let ref = Database.database().reference()
    
    func fetchUserShifts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Escucha en tiempo real la ruta: users -> [UID] -> shifts
        ref.child("users").child(uid).child("shifts").observe(.value) { snapshot in
            var newShifts: [Shift] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    
                    let id = childSnapshot.key
                    let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                    let typeString = dict["type"] as? String ?? "Mañana"
                    
                    if let type = ShiftType(rawValue: typeString) {
                        let shift = Shift(id: id, timestamp: timestamp, type: type)
                        newShifts.append(shift)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.userShifts = newShifts
            }
        }
    }
    
    // Función para crear turnos de prueba (ÚTIL PARA PROBAR SI NO TIENES DATOS)
    func createTestShift(date: Date, type: ShiftType) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "timestamp": date.timeIntervalSince1970 * 1000,
            "type": type.rawValue
        ]
        ref.child("users").child(uid).child("shifts").childByAutoId().setValue(data)
    }
}
