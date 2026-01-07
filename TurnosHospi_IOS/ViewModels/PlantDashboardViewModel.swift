//
//  PlantDashboardViewModel.swift
//  TurnosHospi_IOS
//
//  ViewModel para gestión del dashboard de planta
//  Extrae la lógica de negocio y Firebase de PlantDashboardView
//

import Foundation
import Combine
import FirebaseDatabase
import FirebaseAuth

class PlantDashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Fecha seleccionada en el calendario
    @Published var selectedDate: Date = Date()

    /// Primer día del mes actual
    @Published var currentMonth: Date = Date()

    /// Estado de carga general
    @Published var isLoading: Bool = false

    /// Mensaje de error
    @Published var errorMessage: String?

    /// Mensaje de éxito
    @Published var successMessage: String?

    // MARK: - Supervisor Assignment Properties

    /// Asignaciones de supervisor por turno
    @Published var supervisorAssignments: [String: ShiftAssignmentState] = [:]

    /// Estado de carga de asignaciones de supervisor
    @Published var isLoadingSupervisorAssignments: Bool = false

    /// Indica si las asignaciones fueron cargadas
    @Published var isSupervisorAssignmentsLoaded: Bool = false

    /// Estado de guardado de asignaciones
    @Published var isSavingSupervisorAssignments: Bool = false

    /// Mensaje de estado de operaciones de supervisor
    @Published var supervisorStatusMessage: String?

    // MARK: - Plant Deletion Properties

    /// Estado de eliminación de planta
    @Published var isDeletingPlant: Bool = false

    /// Mensaje de estado de eliminación
    @Published var plantDeleteStatusMessage: String?

    // MARK: - Dependencies

    private let plantId: String
    private let ref = Database.database().reference()

    /// PlantManager para acceder a datos de la planta
    weak var plantManager: PlantManager?

    /// AuthManager para datos del usuario
    weak var authManager: AuthManager?

    /// Work item para debounce de cambios de fecha
    private var dateSelectionWorkItem: DispatchWorkItem?

    // MARK: - Computed Properties

    /// Calendario con configuración española
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }

    /// Frase requerida para eliminar planta
    var deletePhrase: String {
        let name = plantManager?.currentPlant?.name ?? ""
        if name.isEmpty { return "borrar mi planta" }
        return "borrar \(name.lowercased())"
    }

    /// Scope del personal (nurses_only o nurses_and_aux)
    var staffScope: String {
        plantManager?.currentPlant?.staffScope ?? "nurses_only"
    }

    /// Verifica si el usuario es supervisor
    var isSupervisor: Bool {
        authManager?.userRole.lowercased().contains("supervisor") ?? false
    }

    // MARK: - Init & Deinit

    init(plantId: String) {
        self.plantId = plantId
        resetCurrentMonthToFirstDay(of: Date())
    }

    deinit {
        dateSelectionWorkItem?.cancel()
    }

    // MARK: - Date Handling

    /// Resetea currentMonth al primer día del mes de la fecha dada
    func resetCurrentMonthToFirstDay(of date: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        if let firstOfMonth = calendar.date(from: components) {
            currentMonth = firstOfMonth
        }
    }

    /// Programa el manejo de selección de fecha con debounce
    func scheduleDateHandling(for date: Date) {
        dateSelectionWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.handleDateSelection(date)
        }

        dateSelectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    /// Maneja la selección de una nueva fecha
    func handleDateSelection(_ newDate: Date) {
        guard !plantId.isEmpty else { return }

        // Si cambió de mes, actualizar currentMonth y cargar asignaciones mensuales
        if !calendar.isDate(newDate, equalTo: currentMonth, toGranularity: .month) {
            let components = calendar.dateComponents([.year, .month], from: newDate)
            if let firstOfMonth = calendar.date(from: components) {
                currentMonth = firstOfMonth
                plantManager?.fetchMonthlyAssignments(plantId: plantId, month: firstOfMonth)
            }
        }

        // Actualizar fecha seleccionada
        selectedDate = newDate

        // Cargar personal del día
        plantManager?.fetchDailyStaff(plantId: plantId, date: newDate)

        // Si es supervisor, cargar asignaciones editables
        if isSupervisor {
            loadSupervisorAssignments(for: newDate)
        }
    }

    // MARK: - Supervisor Assignments

    /// Carga las asignaciones de supervisor para una fecha
    func loadSupervisorAssignments(for date: Date? = nil) {
        guard isSupervisor,
              let plant = plantManager?.currentPlant else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let targetDate = date ?? selectedDate
        let dateKey = formatter.string(from: targetDate)

        isLoadingSupervisorAssignments = true
        isSupervisorAssignmentsLoaded = false
        supervisorStatusMessage = nil

        let dayRef = ref
            .child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateKey)")

        dayRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }

            var result: [String: ShiftAssignmentState] = [:]
            let unassigned = "Sin asignar"

            if let shiftsDict = snapshot.value as? [String: Any] {
                for (shiftName, shiftValue) in shiftsDict {
                    guard let shiftData = shiftValue as? [String: Any] else { continue }

                    // Procesar enfermeros
                    var nurseSlots: [SlotAssignment] = []
                    if let nursesArray = shiftData["nurses"] as? [[String: Any]] {
                        for dict in nursesArray {
                            let halfDay = dict["halfDay"] as? Bool ?? false
                            let primary = dict["primary"] as? String ?? ""
                            let secondary = dict["secondary"] as? String ?? ""
                            let slot = SlotAssignment(
                                primaryName: primary == unassigned ? "" : primary,
                                secondaryName: secondary == unassigned ? "" : secondary,
                                hasHalfDay: halfDay
                            )
                            nurseSlots.append(slot)
                        }
                    }

                    // Procesar auxiliares
                    var auxSlots: [SlotAssignment] = []
                    if let auxArray = shiftData["auxiliaries"] as? [[String: Any]] {
                        for dict in auxArray {
                            let halfDay = dict["halfDay"] as? Bool ?? false
                            let primary = dict["primary"] as? String ?? ""
                            let secondary = dict["secondary"] as? String ?? ""
                            let slot = SlotAssignment(
                                primaryName: primary == unassigned ? "" : primary,
                                secondaryName: secondary == unassigned ? "" : secondary,
                                hasHalfDay: halfDay
                            )
                            auxSlots.append(slot)
                        }
                    }

                    // Asegurar mínimo de slots según requerimientos
                    let required = plant.staffRequirements?[shiftName] ?? 0
                    let desiredNurseCount = max(1, required)
                    if nurseSlots.count < desiredNurseCount {
                        nurseSlots.append(contentsOf: Array(
                            repeating: SlotAssignment(),
                            count: desiredNurseCount - nurseSlots.count
                        ))
                    }

                    let desiredAuxCount = plant.staffScope == "nurses_and_aux" ? max(1, required) : 0
                    if desiredAuxCount == 0 {
                        auxSlots = []
                    } else if auxSlots.count < desiredAuxCount {
                        auxSlots.append(contentsOf: Array(
                            repeating: SlotAssignment(),
                            count: desiredAuxCount - auxSlots.count
                        ))
                    }

                    result[shiftName] = ShiftAssignmentState(
                        nurseSlots: nurseSlots,
                        auxSlots: auxSlots
                    )
                }
            }

            // Asegurar que todos los turnos de la planta aparecen
            if let shiftTimes = plant.shiftTimes {
                for shiftName in shiftTimes.keys {
                    if result[shiftName] == nil {
                        let required = plant.staffRequirements?[shiftName] ?? 0
                        let nurseCount = max(1, required)
                        let auxCount = plant.staffScope == "nurses_and_aux" ? max(1, required) : 0
                        let nurseSlots = Array(repeating: SlotAssignment(), count: nurseCount)
                        let auxSlots = auxCount > 0 ? Array(repeating: SlotAssignment(), count: auxCount) : []
                        result[shiftName] = ShiftAssignmentState(
                            nurseSlots: nurseSlots,
                            auxSlots: auxSlots
                        )
                    }
                }
            }

            DispatchQueue.main.async {
                self.supervisorAssignments = result
                self.isLoadingSupervisorAssignments = false
                self.isSupervisorAssignmentsLoaded = true
            }
        }
    }

    /// Guarda las asignaciones de supervisor
    func saveSupervisorAssignments() {
        guard isSupervisor,
              let plant = plantManager?.currentPlant else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: selectedDate)

        let dayRef = ref
            .child("plants")
            .child(plant.id)
            .child("turnos")
            .child("turnos-\(dateKey)")

        let unassigned = "Sin asignar"
        var payload: [String: Any] = [:]

        for (shiftName, state) in supervisorAssignments {
            var nursesArray: [[String: Any]] = []
            for (index, slot) in state.nurseSlots.enumerated() {
                nursesArray.append(
                    slot.toFirebaseMap(unassigned: unassigned, base: "enfermero\(index + 1)")
                )
            }

            var auxArray: [[String: Any]] = []
            for (index, slot) in state.auxSlots.enumerated() {
                auxArray.append(
                    slot.toFirebaseMap(unassigned: unassigned, base: "auxiliar\(index + 1)")
                )
            }

            payload[shiftName] = [
                "nurses": nursesArray,
                "auxiliaries": auxArray
            ]
        }

        isSavingSupervisorAssignments = true
        supervisorStatusMessage = nil

        dayRef.setValue(payload) { [weak self] error, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isSavingSupervisorAssignments = false

                if let error = error {
                    self.supervisorStatusMessage = "Error al guardar: \(error.localizedDescription)"
                } else {
                    self.supervisorStatusMessage = "Cambios guardados"
                    // Refrescar vistas
                    self.plantManager?.fetchDailyStaff(plantId: self.plantId, date: self.selectedDate)
                    self.plantManager?.fetchMonthlyAssignments(plantId: self.plantId, month: self.selectedDate)
                }
            }
        }
    }

    // MARK: - Plant Deletion

    /// Elimina la planta actual
    func deletePlant(completion: @escaping (Bool) -> Void) {
        guard let plant = plantManager?.currentPlant,
              !plant.id.isEmpty else {
            plantDeleteStatusMessage = "No se encontró la planta"
            completion(false)
            return
        }

        isDeletingPlant = true
        plantDeleteStatusMessage = nil

        let plantRef = ref.child("plants").child(plant.id)

        // Primero obtener los usuarios de la planta
        plantRef.child("userPlants").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }

            var userIds: [String] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                userIds.append(child.key)
            }

            let dispatchGroup = DispatchGroup()

            // Limpiar plantId de cada usuario
            for uid in userIds {
                dispatchGroup.enter()
                self.ref.child("users").child(uid).updateChildValues([
                    "plantId": "",
                    "role": "Personal"
                ]) { _, _ in
                    dispatchGroup.leave()
                }
            }

            // Cuando todos los usuarios estén actualizados, eliminar la planta
            dispatchGroup.notify(queue: .main) {
                plantRef.removeValue { error, _ in
                    DispatchQueue.main.async {
                        self.isDeletingPlant = false

                        if let error = error {
                            self.plantDeleteStatusMessage = "Error al eliminar: \(error.localizedDescription)"
                            completion(false)
                        } else {
                            self.plantDeleteStatusMessage = nil

                            // Limpiar estado en AuthManager
                            self.authManager?.userPlantId = ""
                            self.authManager?.userRole = "Personal"
                            self.plantManager?.currentPlant = nil

                            completion(true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Daily Assignments

    /// Carga las asignaciones diarias
    func fetchDailyAssignments(for date: Date) {
        guard !plantId.isEmpty else { return }

        plantManager?.fetchDailyStaff(plantId: plantId, date: date)
    }

    /// Carga las asignaciones mensuales
    func fetchMonthlyAssignments(for month: Date) {
        guard !plantId.isEmpty else { return }

        plantManager?.fetchMonthlyAssignments(plantId: plantId, month: month)
    }

    // MARK: - Initial Load

    /// Carga inicial de datos
    func loadInitialData() {
        guard !plantId.isEmpty else { return }

        plantManager?.fetchCurrentPlant(plantId: plantId)
        resetCurrentMonthToFirstDay(of: selectedDate)
        plantManager?.fetchMonthlyAssignments(plantId: plantId, month: currentMonth)
        plantManager?.fetchDailyStaff(plantId: plantId, date: selectedDate)

        if isSupervisor {
            loadSupervisorAssignments(for: selectedDate)
        }
    }

    // MARK: - Message Handling

    /// Limpia los mensajes de estado
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
        supervisorStatusMessage = nil
        plantDeleteStatusMessage = nil
    }

    /// Limpia mensaje de estado de supervisor después de un tiempo
    func clearSupervisorStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.supervisorStatusMessage?.contains("guardados") == true {
                self?.supervisorStatusMessage = nil
            }
        }
    }

    // MARK: - Helpers

    /// Obtiene icono para una opción del menú
    func getIconForOption(_ option: String) -> String {
        switch option {
        case "Añadir personal": return "person.badge.plus"
        case "Lista de personal": return "person.3.fill"
        case "Configuración de la planta": return "gearshape.2.fill"
        case "Importar turnos": return "square.and.arrow.down"
        case "Gestión de cambios": return "arrow.triangle.2.circlepath"
        case "Invitar compañeros": return "envelope.fill"
        case "Días de vacaciones": return "sun.max.fill"
        case "Chat de grupo": return "bubble.left.and.bubble.right.fill"
        case "Estadísticas": return "chart.bar.xaxis"
        case "Cambio de turnos": return "arrow.triangle.2.circlepath"
        case "Bolsa de Turnos": return "briefcase.fill"
        default: return "calendar"
        }
    }

    /// Orden preferido de turnos
    var orderedShiftNames: [String] {
        let preferred = [
            "Mañana",
            "Media mañana",
            "Tarde",
            "Media tarde",
            "Noche",
            "Día",
            "Turno de Día",
            "Turno de Noche"
        ]

        guard let plant = plantManager?.currentPlant,
              let shiftTimes = plant.shiftTimes else {
            return preferred
        }

        let existingKeys = Set(shiftTimes.keys)
        let orderedExisting = preferred.filter { existingKeys.contains($0) }
        let extra = existingKeys.subtracting(orderedExisting).sorted()

        return orderedExisting + extra
    }

    /// Lista de enfermeros disponibles
    var nurseOptions: [String] {
        plantManager?.currentPlant?.allStaffList
            .filter { $0.role.lowercased().contains("enfermer") }
            .map { $0.name }
            .sorted() ?? []
    }

    /// Lista de auxiliares disponibles
    var auxOptions: [String] {
        plantManager?.currentPlant?.allStaffList
            .filter {
                let r = $0.role.lowercased()
                return r.contains("aux") || r.contains("tcae")
            }
            .map { $0.name }
            .sorted() ?? []
    }
}
