import Foundation
import FirebaseDatabase

/// Maneja los días de vacaciones del usuario dentro de una planta concreta.
class VacationManager: ObservableObject {
    @Published private(set) var vacationDays: Set<Date> = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let ref = Database.database().reference()
    private var vacationsRef: DatabaseReference?
    private var vacationsHandle: DatabaseHandle?
    
    private var currentUserId: String?
    private var currentPlantId: String?
    
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone.current
        return f
    }()
    
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    deinit {
        stopListening()
    }
    
    /// Actualiza el contexto. Si cambia el usuario o la planta, se vuelve a escuchar el nodo correspondiente.
    func updateContext(userId: String?, plantId: String?) {
        let normalizedUser = userId ?? ""
        let normalizedPlant = plantId ?? ""
        
        let sameUser = normalizedUser == (currentUserId ?? "")
        let samePlant = normalizedPlant == (currentPlantId ?? "")
        
        guard !sameUser || !samePlant else { return }
        
        currentUserId = normalizedUser.isEmpty ? nil : normalizedUser
        currentPlantId = normalizedPlant.isEmpty ? nil : normalizedPlant
        
        observeVacations()
    }
    
    func stopListening() {
        if let handle = vacationsHandle {
            vacationsRef?.removeObserver(withHandle: handle)
        }
        vacationsHandle = nil
        vacationsRef = nil
    }
    
    private func observeVacations() {
        stopListening()
        vacationDays = []
        errorMessage = nil
        
        guard let userId = currentUserId, let plantId = currentPlantId else {
            return
        }
        
        let node = ref.child("plants").child(plantId).child("vacations").child(userId)
        vacationsRef = node
        isLoading = true
        
        vacationsHandle = node.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var newDays: Set<Date> = []
            
            if let list = snapshot.value as? [String: Any] {
                for key in list.keys {
                    if let date = self.formatter.date(from: key) {
                        newDays.insert(self.normalize(date))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.vacationDays = newDays
                self.isLoading = false
            }
        }
    }
    
    func isVacation(_ date: Date) -> Bool {
        let normalized = normalize(date)
        return vacationDays.contains(normalized)
    }
    
    func toggleVacation(for date: Date) {
        let normalized = normalize(date)
        guard let userId = currentUserId, let plantId = currentPlantId else {
            errorMessage = "No se encontró la planta o el usuario."
            return
        }
        
        let key = formatter.string(from: normalized)
        let node = ref
            .child("plants")
            .child(plantId)
            .child("vacations")
            .child(userId)
            .child(key)
        
        if vacationDays.contains(normalized) {
            node.removeValue()
        } else {
            node.setValue(true)
        }
    }
    
    private func normalize(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: comps) ?? date
    }
}
