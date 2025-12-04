import Foundation
import FirebaseDatabase
import FirebaseAuth

class ShiftManager: ObservableObject {
    @Published var userShifts: [Shift] = []
    private let ref = Database.database().reference()
    
    // Cargar turnos del usuario actual
    func fetchUserShifts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Ruta: users -> [UID] -> shifts
        ref.child("users").child(uid).child("shifts").observe(.value) { snapshot in
            var newShifts: [Shift] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    
                    let id = childSnapshot.key
                    let timestamp = dict["timestamp"] as? TimeInterval ?? 0
                    let typeString = dict["type"] as? String ?? "Mañana"
                    
                    // Convertimos el string al Enum
                    if let type = ShiftType(rawValue: typeString) {
                        let shift = Shift(id: id, timestamp: timestamp, type: type)
                        newShifts.append(shift)
                    }
                }
            }
            
            // Actualizamos la UI en el hilo principal
            DispatchQueue.main.async {
                self.userShifts = newShifts
            }
        }
    }
    
    // Función auxiliar para crear un turno de prueba (para que puedas probarlo)
    func createTestShift(day: Int, month: Int, year: Int, type: ShiftType) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        let date = Calendar.current.date(from: components) ?? Date()
        
        let data: [String: Any] = [
            "timestamp": date.timeIntervalSince1970 * 1000,
            "type": type.rawValue
        ]
        
        ref.child("users").child(uid).child("shifts").childByAutoId().setValue(data)
    }
}
