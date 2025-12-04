import Foundation
import FirebaseDatabase
import Combine

class ShiftRepository: ObservableObject {
    
    // MARK: - Publishers para la UI
    // La UI se suscribirá a estas variables para actualizarse automáticamente
    @Published var myShifts: [UserShift] = []
    @Published var myChangeRequests: [ShiftChangeRequest] = []
    @Published var marketplaceRequests: [ShiftChangeRequest] = [] // Bolsa de turnos
    
    private let db = Database.database().reference()
    private var shiftsHandle: DatabaseHandle?
    private var requestsHandle: DatabaseHandle?
    
    // MARK: - Gestión de Turnos Propios
    
    /// Escucha en tiempo real los turnos asignados al usuario
    func listenToUserShifts(userId: String) {
        let ref = db.child("users").child(userId).child("shifts")
        
        // Removemos observer anterior si existe para evitar duplicados al cambiar de usuario
        if let handle = shiftsHandle { ref.removeObserver(withHandle: handle) }
        
        shiftsHandle = ref.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var newShifts: [UserShift] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    do {
                        // Convertir diccionario a JSON data y luego decodificar
                        let data = try JSONSerialization.data(withJSONObject: dict)
                        let shift = try JSONDecoder().decode(UserShift.self, from: data)
                        newShifts.append(shift)
                    } catch {
                        print("Error decodificando turno: \(error)")
                    }
                }
            }
            
            // Ordenar por fecha ascendente
            newShifts.sort { $0.date < $1.date }
            
            DispatchQueue.main.async {
                self.myShifts = newShifts
            }
        }
    }
    
    /// Asigna un turno a un usuario (usado por Supervisor o al aceptar un cambio)
    func assignShift(userId: String, shift: UserShift, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let data = try JSONEncoder().encode(shift)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Usamos shift.id (fecha + turno) como clave para evitar duplicados
            db.child("users").child(userId).child("shifts").child(shift.id).setValue(dict) { error, _ in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Gestión de Solicitudes (Cambios y Coberturas)
    
    /// Crea una nueva solicitud de cambio o cobertura
    func createShiftChangeRequest(request: ShiftChangeRequest, plantId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let data = try JSONEncoder().encode(request)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Guardamos en /plants/{plantId}/requests/{requestId}
            db.child("plants").child(plantId).child("requests").child(request.id).setValue(dict) { error, _ in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Escucha todas las peticiones de la planta y filtra las mías y las de la bolsa
    func listenToPlantRequests(plantId: String, currentUserId: String) {
        let ref = db.child("plants").child(plantId).child("requests")
        
        if let handle = requestsHandle { ref.removeObserver(withHandle: handle) }
        
        requestsHandle = ref.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var myRequests: [ShiftChangeRequest] = []
            var market: [ShiftChangeRequest] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    do {
                        let data = try JSONSerialization.data(withJSONObject: dict)
                        let request = try JSONDecoder().decode(ShiftChangeRequest.self, from: data)
                        
                        // Lógica de filtrado
                        let isMyRequest = request.requesterId == currentUserId || request.targetUserId == currentUserId
                        
                        if isMyRequest {
                            myRequests.append(request)
                        }
                        
                        // Bolsa: Solicitudes en estado SEARCHING que NO sean mías
                        if request.status == .searching && request.requesterId != currentUserId {
                            market.append(request)
                        }
                        
                    } catch {
                        print("Error decodificando request: \(error)")
                    }
                }
            }
            
            // Ordenar por fecha de creación o turno (opcional)
            DispatchQueue.main.async {
                self.myChangeRequests = myRequests
                self.marketplaceRequests = market
            }
        }
    }
    
    /// Actualiza el estado de una solicitud (Aprobar, Rechazar, Ofrecerse)
    func updateRequestStatus(requestId: String,
                             plantId: String,
                             newStatus: ChangeRequestStatus,
                             targetUserId: String? = nil,
                             targetUserName: String? = nil,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        
        var updates: [String: Any] = ["status": newStatus.rawValue]
        
        if let uid = targetUserId {
            updates["targetUserId"] = uid
        }
        if let name = targetUserName {
            updates["targetUserName"] = name
        }
        
        db.child("plants").child(plantId).child("requests").child(requestId).updateChildValues(updates) { error, _ in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Limpieza
    
    func stopListening() {
        if let shiftsHandle = shiftsHandle {
            db.removeObserver(withHandle: shiftsHandle)
        }
        if let requestsHandle = requestsHandle {
            db.removeObserver(withHandle: requestsHandle)
        }
    }
}
