//
//  ShiftChangeViewModel.swift
//  TurnosHospi_IOS
//
//  ViewModel para gestión de cambios de turno
//  Extrae la lógica de negocio y Firebase de ShiftChangeView
//

import Foundation
import Combine
import FirebaseDatabase
import FirebaseAuth

// MARK: - ShiftSlotInfo Helper

struct ShiftSlotInfo {
    let shiftKey: String
    let group: String
    let slotKey: String
    let field: String
    let isHalfDay: Bool

    var fullPath: String {
        "\(shiftKey)/\(group)/\(slotKey)/\(field)"
    }

    var slotBasePath: String {
        "\(shiftKey)/\(group)/\(slotKey)"
    }
}

// MARK: - ViewModel

class ShiftChangeViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Lista de todas las solicitudes de cambio
    @Published var requests: [ShiftChangeRequest] = []

    /// Lista de turnos candidatos para intercambio
    @Published var candidateShifts: [PlantShift] = []

    /// Horarios de usuarios para validación de reglas
    @Published var userSchedules: [String: [String: String]] = [:]

    /// Estado de carga de candidatos
    @Published var isLoadingCandidates: Bool = false

    /// Estado de carga general
    @Published var isLoading: Bool = false

    /// Mensaje de error para mostrar al usuario
    @Published var errorMessage: String?

    /// Mensaje de éxito para mostrar al usuario
    @Published var successMessage: String?

    /// Mapa de personal de la planta
    @Published var plantStaffMap: [String: PlantStaff] = [:]

    /// Mapa de staffId a userId
    @Published var staffIdToUserId: [String: String] = [:]

    // MARK: - Dependencies

    private let plantId: String
    private let ref = Database.database().reference()
    private var requestsHandle: DatabaseHandle?
    private var requestsRef: DatabaseReference?

    /// PlantManager para acceder a datos de la planta
    weak var plantManager: PlantManager?

    /// Usuario actual
    var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    // MARK: - Computed Properties

    /// Solicitudes activas (no finalizadas)
    var activeRequests: [ShiftChangeRequest] {
        let todayStr = dateFormatter.string(from: Date())
        return requests.filter { req in
            req.requesterShiftDate >= todayStr &&
            req.status != .approved &&
            req.status != .rejected
        }
    }

    /// Solicitudes en historial
    var historyRequests: [ShiftChangeRequest] {
        let todayStr = dateFormatter.string(from: Date())
        return requests.filter { req in
            req.requesterShiftDate < todayStr ||
            req.status == .approved ||
            req.status == .rejected
        }
    }

    /// Solicitudes pendientes de supervisor
    var supervisorPendingRequests: [ShiftChangeRequest] {
        requests.filter { $0.status == .awaitingSupervisor }
    }

    /// Mis solicitudes en búsqueda
    var mySearchingRequests: [ShiftChangeRequest] {
        requests.filter {
            $0.requesterId == currentUserId && $0.status == .searching
        }
    }

    // MARK: - Private Properties

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init & Deinit

    init(plantId: String) {
        self.plantId = plantId

        guard !plantId.isEmpty else { return }
        startListening()
        loadStaffMappings()
    }

    deinit {
        stopListening()
    }

    // MARK: - Firebase Listeners

    func startListening() {
        guard !plantId.isEmpty else { return }

        requestsRef = ref.child("plants/\(plantId)/shift_requests")
        requestsHandle = requestsRef?.observe(.value) { [weak self] snapshot in
            self?.handleRequestsSnapshot(snapshot)
        }
    }

    func stopListening() {
        if let handle = requestsHandle {
            requestsRef?.removeObserver(withHandle: handle)
        }
        requestsHandle = nil
        requestsRef = nil
    }

    private func handleRequestsSnapshot(_ snapshot: DataSnapshot) {
        var newRequests: [ShiftChangeRequest] = []

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            if let dict = child.value as? [String: Any],
               let req = parseRequest(dict: dict, id: child.key) {
                newRequests.append(req)
            }
        }

        DispatchQueue.main.async {
            self.requests = newRequests
        }
    }

    // MARK: - Load Data

    func loadStaffMappings() {
        guard !plantId.isEmpty else { return }

        let staffRef = ref.child("plants/\(plantId)/personal_de_planta")
        staffRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            var map: [String: PlantStaff] = [:]

            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                let staff = PlantStaff(
                    id: dict["id"] as? String ?? child.key,
                    name: dict["name"] as? String ?? "Personal",
                    role: dict["role"] as? String ?? "",
                    email: dict["email"] as? String ?? "",
                    profileType: dict["profileType"] as? String ?? ""
                )
                map[staff.id] = staff
            }

            DispatchQueue.main.async {
                self?.plantStaffMap = map
            }
        }

        let userPlantsRef = ref.child("plants/\(plantId)/userPlants")
        userPlantsRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            var mapping: [String: String] = [:]

            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let staffId = child.childSnapshot(forPath: "staffId").value as? String {
                    mapping[staffId] = child.key
                }
            }

            DispatchQueue.main.async {
                self?.staffIdToUserId = mapping
            }
        }
    }

    // MARK: - Load Candidates

    func loadCandidates(for request: ShiftChangeRequest) {
        guard !plantId.isEmpty else { return }

        self.candidateShifts = []
        self.userSchedules = [:]
        self.isLoadingCandidates = true

        // Cargar contexto histórico (7 días atrás) para reglas de racha/saliente
        guard let historyStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            self.isLoadingCandidates = false
            return
        }

        let startKey = "turnos-\(dateFormatter.string(from: historyStart))"

        ref.child("plants/\(plantId)/turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: startKey)
            .observeSingleEvent(of: .value) { [weak self] snapshot in
                self?.processCandidatesSnapshot(snapshot, for: request)
            }
    }

    private func processCandidatesSnapshot(_ snapshot: DataSnapshot, for myRequest: ShiftChangeRequest) {
        var tempSchedules: [String: [String: String]] = [:]
        var potentialCandidates: [PlantShift] = []

        let staffList = plantManager?.currentPlant?.allStaffList ?? []
        let plantUsers = plantManager?.plantUsers ?? []

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            let key = child.key
            guard key.hasPrefix("turnos-") else { continue }

            let dateStr = String(key.dropFirst(7))
            guard let date = dateFormatter.date(from: dateStr) else { continue }

            if let shiftsMap = child.value as? [String: Any] {
                for (shiftName, shiftData) in shiftsMap {
                    guard let data = shiftData as? [String: Any] else { continue }

                    // Procesar listas de enfermeros y auxiliares
                    if let nurses = data["nurses"] as? [[String: Any]] {
                        processShiftList(
                            list: nurses,
                            defaultRole: "Enfermero",
                            date: date,
                            dateStr: dateStr,
                            shiftName: shiftName,
                            tempSchedules: &tempSchedules,
                            potentialCandidates: &potentialCandidates,
                            staffList: staffList,
                            plantUsers: plantUsers
                        )
                    }

                    if let auxs = data["auxiliaries"] as? [[String: Any]] {
                        processShiftList(
                            list: auxs,
                            defaultRole: "Auxiliar",
                            date: date,
                            dateStr: dateStr,
                            shiftName: shiftName,
                            tempSchedules: &tempSchedules,
                            potentialCandidates: &potentialCandidates,
                            staffList: staffList,
                            plantUsers: plantUsers
                        )
                    }
                }
            }
        }

        // Filtrar candidatos usando ShiftRulesEngine
        let mySchedule = tempSchedules[currentUserId] ?? [:]

        let filteredShifts = potentialCandidates.filter { candidate in
            // 1. No soy yo
            if candidate.userId == currentUserId { return false }

            // 2. Roles compatibles
            if !ShiftRulesEngine.areRolesCompatible(
                roleA: myRequest.requesterRole,
                roleB: candidate.userRole
            ) {
                return false
            }

            let candidateSchedule = tempSchedules[candidate.userId] ?? [:]

            // 3. Validación cruzada con ShiftRulesEngine
            let candidateRequest = ShiftChangeRequest(
                type: .swap,
                status: .searching,
                mode: .flexible,
                hardnessLevel: .normal,
                requesterId: candidate.userId,
                requesterName: candidate.userName,
                requesterRole: candidate.userRole,
                requesterShiftDate: candidate.dateString,
                requesterShiftName: candidate.shiftName
            )

            let isValidMatch = ShiftRulesEngine.checkMatch(
                requesterRequest: myRequest,
                candidateRequest: candidateRequest,
                requesterSchedule: mySchedule,
                candidateSchedule: candidateSchedule
            )

            return isValidMatch
        }

        DispatchQueue.main.async {
            self.userSchedules = tempSchedules
            self.candidateShifts = filteredShifts
            self.isLoadingCandidates = false
        }
    }

    private func processShiftList(
        list: [[String: Any]],
        defaultRole: String,
        date: Date,
        dateStr: String,
        shiftName: String,
        tempSchedules: inout [String: [String: String]],
        potentialCandidates: inout [PlantShift],
        staffList: [PlantStaff],
        plantUsers: [ChatUser]
    ) {
        for slot in list {
            let primaryName = slot["primary"] as? String ?? ""
            let halfDay = slot["halfDay"] as? Bool ?? false
            let secondaryName = slot["secondary"] as? String ?? ""

            // Turno principal
            if !primaryName.isEmpty && primaryName != "Sin asignar" {
                addShiftToStructures(
                    name: primaryName,
                    defaultRole: defaultRole,
                    date: date,
                    dateStr: dateStr,
                    shiftName: shiftName,
                    tempSchedules: &tempSchedules,
                    potentialCandidates: &potentialCandidates,
                    staffList: staffList,
                    plantUsers: plantUsers
                )
            }

            // Turno secundario (media jornada)
            if halfDay && !secondaryName.isEmpty && secondaryName != "Sin asignar" {
                addShiftToStructures(
                    name: secondaryName,
                    defaultRole: defaultRole,
                    date: date,
                    dateStr: dateStr,
                    shiftName: shiftName,
                    tempSchedules: &tempSchedules,
                    potentialCandidates: &potentialCandidates,
                    staffList: staffList,
                    plantUsers: plantUsers
                )
            }
        }
    }

    private func addShiftToStructures(
        name: String,
        defaultRole: String,
        date: Date,
        dateStr: String,
        shiftName: String,
        tempSchedules: inout [String: [String: String]],
        potentialCandidates: inout [PlantShift],
        staffList: [PlantStaff],
        plantUsers: [ChatUser]
    ) {
        let staff = staffList.first { $0.name == name }
        let chatUser = plantUsers.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        let uid = chatUser?.id ?? staff?.id ?? name
        let role = staff?.role ?? defaultRole

        // Guardar en horario global
        if tempSchedules[uid] == nil {
            tempSchedules[uid] = [:]
        }
        tempSchedules[uid]?[dateStr] = shiftName

        // Añadir a candidatos si es fecha futura o hoy
        if date >= Calendar.current.startOfDay(for: Date()) {
            potentialCandidates.append(PlantShift(
                userId: uid,
                userName: name,
                userRole: role,
                date: date,
                dateString: dateStr,
                shiftName: shiftName
            ))
        }
    }

    // MARK: - Actions

    /// Crear una nueva solicitud de cambio
    func createRequest(
        shiftDate: String,
        shiftName: String,
        requesterName: String,
        requesterRole: String,
        mode: RequestMode,
        completion: ((Bool, String?) -> Void)? = nil
    ) {
        guard let user = Auth.auth().currentUser else {
            completion?(false, "Usuario no autenticado")
            return
        }

        let id = UUID().uuidString
        let data: [String: Any] = [
            "type": RequestType.swap.rawValue,
            "status": RequestStatus.searching.rawValue,
            "mode": mode.rawValue,
            "hardnessLevel": ShiftHardness.normal.rawValue,
            "requesterId": user.uid,
            "requesterName": requesterName,
            "requesterRole": requesterRole,
            "requesterShiftDate": shiftDate,
            "requesterShiftName": shiftName,
            "timestamp": ServerValue.timestamp()
        ]

        ref.child("plants/\(plantId)/shift_requests/\(id)").setValue(data) { [weak self] error, _ in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion?(false, error.localizedDescription)
                } else {
                    self?.successMessage = "Solicitud creada correctamente"
                    completion?(true, nil)
                }
            }
        }
    }

    /// Proponer un intercambio con un candidato
    func performProposal(for request: ShiftChangeRequest, with candidate: PlantShift) {
        let updates: [String: Any] = [
            "status": RequestStatus.pendingPartner.rawValue,
            "targetUserId": candidate.userId,
            "targetUserName": candidate.userName,
            "targetShiftDate": candidate.dateString,
            "targetShiftName": candidate.shiftName
        ]

        ref.child("plants/\(plantId)/shift_requests/\(request.id)")
            .updateChildValues(updates) { [weak self] error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.successMessage = "Propuesta enviada"
                    }
                }
            }
    }

    /// Aceptar una solicitud (como target)
    func acceptRequest(_ request: ShiftChangeRequest) {
        guard request.targetUserId == currentUserId else { return }

        // Buscar supervisores
        var supervisorIds: [String] = []
        for (staffId, data) in plantStaffMap {
            if data.role.lowercased().contains("supervisor"),
               let supUid = staffIdToUserId[staffId] {
                supervisorIds.append(supUid)
            }
        }

        let updates: [String: Any] = [
            "status": RequestStatus.awaitingSupervisor.rawValue,
            "supervisorIds": supervisorIds
        ]

        ref.child("plants/\(plantId)/shift_requests/\(request.id)")
            .updateChildValues(updates) { [weak self] error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.successMessage = "Solicitud aceptada, pendiente de supervisor"
                    }
                }
            }
    }

    /// Rechazar una solicitud (como target)
    func rejectRequest(_ request: ShiftChangeRequest) {
        guard request.targetUserId == currentUserId else { return }

        let updates: [String: Any] = [
            "status": RequestStatus.rejected.rawValue
        ]

        ref.child("plants/\(plantId)/shift_requests/\(request.id)")
            .updateChildValues(updates) { [weak self] error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.successMessage = "Solicitud rechazada"
                    }
                }
            }
    }

    /// Rechazar como supervisor
    func rejectAsSupervisor(_ request: ShiftChangeRequest) {
        ref.child("plants/\(plantId)/shift_requests/\(request.id)/status")
            .setValue(RequestStatus.rejected.rawValue) { [weak self] error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.successMessage = "Solicitud rechazada por supervisor"
                    }
                }
            }
    }

    /// Aprobar como supervisor
    func approveSwapBySupervisor(_ request: ShiftChangeRequest) {
        if request.type == .coverage {
            approveCoverage(request: request)
            return
        }

        let targetUserName = request.targetUserName ?? ""
        let targetShiftDate = request.targetShiftDate ?? ""
        let targetShiftName = request.targetShiftName ?? ""

        guard !targetUserName.isEmpty,
              !targetShiftDate.isEmpty,
              !targetShiftName.isEmpty else {
            errorMessage = "Datos de intercambio incompletos"
            return
        }

        let requesterDayRef = ref.child("plants/\(plantId)/turnos/turnos-\(request.requesterShiftDate)")
        let targetDayRef = ref.child("plants/\(plantId)/turnos/turnos-\(targetShiftDate)")

        requesterDayRef.observeSingleEvent(of: .value) { [weak self] snapshotA in
            guard let self = self else { return }

            targetDayRef.observeSingleEvent(of: .value) { snapshotB in
                guard snapshotA.exists(), snapshotB.exists() else {
                    DispatchQueue.main.async {
                        self.errorMessage = "No se encontraron los turnos en la base de datos"
                    }
                    return
                }

                guard let slotA = self.findSlotInfo(in: snapshotA, shiftName: request.requesterShiftName, userName: request.requesterName),
                      let slotB = self.findSlotInfo(in: snapshotB, shiftName: targetShiftName, userName: targetUserName) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "No se encontraron los slots de turno"
                    }
                    return
                }

                var updates: [String: Any] = [:]

                // Manejar casos de media jornada
                if slotA.isHalfDay && !slotB.isHalfDay {
                    let baseA = "plants/\(self.plantId)/turnos/turnos-\(request.requesterShiftDate)/\(slotA.slotBasePath)"
                    updates["\(baseA)/primary"] = targetUserName
                    updates["\(baseA)/secondary"] = ""
                    updates["\(baseA)/halfDay"] = false
                    updates["plants/\(self.plantId)/turnos/turnos-\(targetShiftDate)/\(slotB.fullPath)"] = request.requesterName
                } else if !slotA.isHalfDay && slotB.isHalfDay {
                    let baseB = "plants/\(self.plantId)/turnos/turnos-\(targetShiftDate)/\(slotB.slotBasePath)"
                    updates["\(baseB)/primary"] = request.requesterName
                    updates["\(baseB)/secondary"] = ""
                    updates["\(baseB)/halfDay"] = false
                    updates["plants/\(self.plantId)/turnos/turnos-\(request.requesterShiftDate)/\(slotA.fullPath)"] = targetUserName
                } else {
                    // Intercambio directo
                    updates["plants/\(self.plantId)/turnos/turnos-\(request.requesterShiftDate)/\(slotA.fullPath)"] = targetUserName
                    updates["plants/\(self.plantId)/turnos/turnos-\(targetShiftDate)/\(slotB.fullPath)"] = request.requesterName
                }

                // Marcar como aprobado
                updates["plants/\(self.plantId)/shift_requests/\(request.id)/status"] = RequestStatus.approved.rawValue

                self.ref.updateChildValues(updates) { error, _ in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        } else {
                            self.successMessage = "Intercambio aprobado y aplicado"
                        }
                    }
                }
            }
        }
    }

    /// Aprobar cobertura
    private func approveCoverage(request: ShiftChangeRequest) {
        let covererName = request.targetUserName ?? ""
        guard !covererName.isEmpty else {
            errorMessage = "Nombre del cubridor no encontrado"
            return
        }

        let turnosRef = ref.child("plants/\(plantId)/turnos/turnos-\(request.requesterShiftDate)")

        turnosRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }

            guard let shiftSnapshot = self.findShiftSnapshot(in: snapshot, shiftName: request.requesterShiftName),
                  let slot = self.findSlotInfo(inShiftSnapshot: shiftSnapshot, userName: request.requesterName) else {
                DispatchQueue.main.async {
                    self.errorMessage = "No se encontró el slot de turno"
                }
                return
            }

            let transactionId = UUID().uuidString
            var updates: [String: Any] = [:]

            // Actualizar el turno
            updates["plants/\(self.plantId)/turnos/turnos-\(request.requesterShiftDate)/\(slot.fullPath)"] = covererName
            updates["plants/\(self.plantId)/shift_requests/\(request.id)/status"] = RequestStatus.approved.rawValue

            // Crear transacción de favor
            if let covererId = request.targetUserId {
                let transaction: [String: Any] = [
                    "id": transactionId,
                    "covererId": covererId,
                    "covererName": covererName,
                    "requesterId": request.requesterId,
                    "requesterName": request.requesterName,
                    "date": request.requesterShiftDate,
                    "shiftName": request.requesterShiftName,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ]
                updates["plants/\(self.plantId)/transactions/\(transactionId)"] = transaction
            }

            self.ref.updateChildValues(updates) { error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.successMessage = "Cobertura aprobada"
                    }
                }
            }
        }
    }

    /// Eliminar una solicitud propia
    func deleteRequest(_ request: ShiftChangeRequest) {
        guard request.requesterId == currentUserId else {
            errorMessage = "Solo puedes eliminar tus propias solicitudes"
            return
        }

        ref.child("plants/\(plantId)/shift_requests/\(request.id)")
            .removeValue { [weak self] error, _ in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.successMessage = "Solicitud eliminada"
                    }
                }
            }
    }

    // MARK: - Helper Methods

    func parseRequest(dict: [String: Any], id: String) -> ShiftChangeRequest? {
        guard let rId = dict["requesterId"] as? String,
              let rName = dict["requesterName"] as? String,
              let rRole = dict["requesterRole"] as? String,
              let rDate = dict["requesterShiftDate"] as? String,
              let rShift = dict["requesterShiftName"] as? String else {
            return nil
        }

        let statusStr = dict["status"] as? String ?? "SEARCHING"
        let typeStr = dict["type"] as? String ?? "SWAP"
        let modeStr = dict["mode"] as? String ?? "FLEXIBLE"
        let hardnessStr = dict["hardnessLevel"] as? String ?? "NORMAL"

        return ShiftChangeRequest(
            id: id,
            type: RequestType(rawValue: typeStr) ?? .swap,
            status: RequestStatus(rawValue: statusStr) ?? .searching,
            mode: RequestMode(rawValue: modeStr) ?? .flexible,
            hardnessLevel: ShiftHardness(rawValue: hardnessStr) ?? .normal,
            requesterId: rId,
            requesterName: rName,
            requesterRole: rRole,
            requesterShiftDate: rDate,
            requesterShiftName: rShift,
            offeredDates: dict["offeredDates"] as? [String] ?? [],
            targetUserId: dict["targetUserId"] as? String,
            targetUserName: dict["targetUserName"] as? String,
            targetShiftDate: dict["targetShiftDate"] as? String,
            targetShiftName: dict["targetShiftName"] as? String,
            supervisorIds: dict["supervisorIds"] as? [String] ?? []
        )
    }

    private func findSlotInfo(in snapshot: DataSnapshot, shiftName: String, userName: String) -> ShiftSlotInfo? {
        guard let shiftSnapshot = findShiftSnapshot(in: snapshot, shiftName: shiftName) else {
            return nil
        }
        return findSlotInfo(inShiftSnapshot: shiftSnapshot, userName: userName)
    }

    private func findShiftSnapshot(in snapshot: DataSnapshot, shiftName: String) -> DataSnapshot? {
        let normalized = shiftName
            .replacingOccurrences(of: "Media ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
            if child.key.caseInsensitiveCompare(normalized) == .orderedSame {
                return child
            }
        }
        return nil
    }

    private func findSlotInfo(inShiftSnapshot shiftSnapshot: DataSnapshot, userName: String) -> ShiftSlotInfo? {
        let targetName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = ["nurses", "auxiliaries"]

        for group in groups {
            let groupSnapshot = shiftSnapshot.childSnapshot(forPath: group)

            for slot in groupSnapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let primary = (slot.childSnapshot(forPath: "primary").value as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let secondary = (slot.childSnapshot(forPath: "secondary").value as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let halfDay = slot.childSnapshot(forPath: "halfDay").value as? Bool ?? false

                if primary.caseInsensitiveCompare(targetName) == .orderedSame {
                    return ShiftSlotInfo(
                        shiftKey: shiftSnapshot.key,
                        group: group,
                        slotKey: slot.key,
                        field: "primary",
                        isHalfDay: halfDay
                    )
                } else if secondary.caseInsensitiveCompare(targetName) == .orderedSame {
                    return ShiftSlotInfo(
                        shiftKey: shiftSnapshot.key,
                        group: group,
                        slotKey: slot.key,
                        field: "secondary",
                        isHalfDay: halfDay
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Validation Helpers

    /// Verificar si el usuario actual puede actuar sobre una solicitud
    func canActOnRequest(_ request: ShiftChangeRequest, currentUserDisplayName: String) -> Bool {
        guard request.status == .pendingPartner else { return false }

        if request.targetUserId == currentUserId { return true }

        let trimmedDisplayName = currentUserDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayName.isEmpty,
           let target = request.targetUserName?.trimmingCharacters(in: .whitespacesAndNewlines),
           target.caseInsensitiveCompare(trimmedDisplayName) == .orderedSame {
            return true
        }

        return false
    }

    // MARK: - Message Handling

    /// Limpiar mensajes de error/éxito
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
