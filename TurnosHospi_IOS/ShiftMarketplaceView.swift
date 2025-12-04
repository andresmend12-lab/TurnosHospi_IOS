import SwiftUI

struct ShiftMarketplaceView: View {
    @EnvironmentObject var shiftRepository: ShiftRepository
    @EnvironmentObject var authService: AuthService
    
    // Estado para alertas y feedback
    @State private var showingConfirmation = false
    @State private var selectedRequest: ShiftChangeRequest?
    @State private var message: String = ""
    @State private var showAlert = false
    
    // Filtrar solicitudes compatibles en tiempo real
    var compatibleRequests: [ShiftChangeRequest] {
        guard let currentUser = authService.currentUser else { return [] }
        
        return shiftRepository.marketplaceRequests.filter { request in
            // 1. Regla básica: Mismo rol
            // (Aunque el repositorio ya podría filtrar, aseguramos aquí)
            // Asumimos que el request lleva implícito el rol del solicitante,
            // y que solo se puede cubrir a alguien del mismo rol.
            
            // 2. Usar el motor de reglas
            // Necesitamos pasar los turnos actuales del usuario para validar descansos
            return ShiftRulesEngine.shared.canUserCoverShift(
                candidate: currentUser,
                targetDateString: request.requesterShiftDate,
                targetShiftName: request.requesterShiftName,
                candidateShifts: shiftRepository.myShifts
            )
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // --- Cabecera: Balance de Favores (Placeholder) ---
                HStack {
                    VStack {
                        Text("Debes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("0")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.red)
                    }
                    Spacer()
                    VStack {
                        Text("Te deben")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("0")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // --- Lista de Oportunidades ---
                if compatibleRequests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "hand.thumbsup.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                        Text("No hay turnos disponibles para ti")
                            .foregroundColor(.gray)
                        Text("La bolsa muestra solo los turnos compatibles con tu rol y agenda.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                    Spacer()
                } else {
                    List(compatibleRequests) { request in
                        MarketplaceRow(request: request) {
                            // Acción al pulsar "Cubrir"
                            self.selectedRequest = request
                            self.showingConfirmation = true
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Bolsa de Turnos")
            
            // Alerta de confirmación
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Confirmar Cobertura"),
                    message: Text("¿Seguro que quieres cubrir el turno de \(selectedRequest?.requesterShiftName ?? "") el día \(selectedRequest?.requesterShiftDate ?? "")?"),
                    primaryButton: .default(Text("Sí, cubrir"), action: coverShift),
                    secondaryButton: .cancel()
                )
            }
            // Alerta de resultado (éxito/error)
            .alert(item: $alertItem) { item in
                Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Lógica de Negocio
    
    func coverShift() {
        guard let request = selectedRequest,
              let currentUser = authService.currentUser else { return }
        
        // Llamar al repositorio para actualizar la solicitud
        // Estado pasa a PENDING_PARTNER o APPROVED según la lógica del hospital (si requiere check de supervisor)
        // Aquí asumimos que pasa directo a AWAITING_SUPERVISOR para validación final
        shiftRepository.updateRequestStatus(
            requestId: request.id,
            plantId: "HospitalGeneral", // ID fijo por ahora
            newStatus: .awaitingSupervisor,
            targetUserId: currentUser.id,
            targetUserName: currentUser.fullName
        ) { result in
            switch result {
            case .success:
                showResult(title: "Solicitud Enviada", message: "El supervisor revisará el cambio.")
            case .failure(let error):
                showResult(title: "Error", message: error.localizedDescription)
            }
        }
    }
    
    // Helper para alertas
    @State private var alertItem: AlertItem?
    
    func showResult(title: String, message: String) {
        self.alertItem = AlertItem(title: title, message: message)
    }
}

// Struct auxiliar para presentar alertas
struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

// MARK: - Subvista de Fila

struct MarketplaceRow: View {
    let request: ShiftChangeRequest
    var onCover: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(request.requesterShiftDate) // Idealmente formatear fecha
                    .font(.headline)
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                    Text(request.requesterName)
                        .font(.subheadline)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text(request.requesterShiftName)
                    .fontWeight(.bold)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(5)
                
                Button(action: onCover) {
                    Text("Cubrir")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
