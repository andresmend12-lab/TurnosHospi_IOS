import SwiftUI
import FirebaseDatabase

struct ShiftMarketplaceView: View {
    var plantId: String
    @EnvironmentObject var authManager: AuthManager
    
    @State private var marketplaceRequests: [ShiftChangeRequest] = []
    @State private var balances: [String: Int] = [:]
    
    // Referencia a la base de datos
    private let ref = Database.database().reference()
    
    var body: some View {
        ZStack {
            // Fondo oscuro
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack {
                Text("Bolsa de Turnos")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Sección de Balances
                if !balances.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(balances.sorted(by: { $0.key < $1.key }), id: \.key) { userId, score in
                                VStack {
                                    // CORRECCIÓN 1: Convertimos el Substring a String explícitamente
                                    Text("Usuario \(String(userId.prefix(4)))")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Text("\(score > 0 ? "+" : "")\(score)")
                                        .foregroundColor(score >= 0 ? .green : .red)
                                        .font(.title2.bold())
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 100)
                }
                
                Divider().background(Color.white.opacity(0.3))
                
                // Lista de Ofertas
                if marketplaceRequests.isEmpty {
                    Spacer()
                    Text("No hay turnos disponibles")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(marketplaceRequests) { req in
                            MarketplaceRow(req: req, onAccept: {
                                acceptCoverage(req: req)
                            })
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onAppear { loadMarketplace() }
    }
    
    func loadMarketplace() {
        // CORRECCIÓN 2: Tipado explícito del closure (DataSnapshot) para evitar el error de "NSObject"
        ref.child("plants/\(plantId)/shift_requests")
            .queryOrdered(byChild: "status")
            .queryEqual(toValue: "SEARCHING")
            .observe(.value, with: { (snapshot: DataSnapshot) in
                
                var newItems: [ShiftChangeRequest] = []
                
                // Iteramos sobre los hijos asegurando el tipo
                for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                    
                    // Intentamos convertir el diccionario al objeto Swift
                    if let value = child.value as? [String: Any],
                       let req = try? parseRequest(dict: value, id: child.key) {
                        
                        // Filtramos para no mostrar mis propias solicitudes
                        // Usamos user?.uid de forma segura
                        if let currentUid = authManager.user?.uid, req.requesterId != currentUid {
                            newItems.append(req)
                        }
                    }
                }
                
                // Actualizamos la UI en el hilo principal
                DispatchQueue.main.async {
                    self.marketplaceRequests = newItems
                }
            })
    }
    
    func acceptCoverage(req: ShiftChangeRequest) {
        print("Aceptando turno: \(req.id)")
        // Aquí iría la lógica de transacción (similar a Android)
    }
    
    // CORRECCIÓN 3: Helper manual para parsear el JSON de forma segura
    // Esto evita problemas si Codable falla por tipos de datos mixtos en Firebase
    func parseRequest(dict: [String: Any], id: String) throws -> ShiftChangeRequest? {
        guard let requesterId = dict["requesterId"] as? String,
              let requesterName = dict["requesterName"] as? String,
              let requesterRole = dict["requesterRole"] as? String,
              let requesterShiftDate = dict["requesterShiftDate"] as? String,
              let requesterShiftName = dict["requesterShiftName"] as? String else {
            return nil
        }
        
        let typeStr = dict["type"] as? String ?? "SWAP"
        let statusStr = dict["status"] as? String ?? "SEARCHING"
        let modeStr = dict["mode"] as? String ?? "FLEXIBLE"
        let hardnessStr = dict["hardnessLevel"] as? String ?? "NORMAL"
        
        return ShiftChangeRequest(
            id: id,
            type: RequestType(rawValue: typeStr) ?? .swap,
            status: RequestStatus(rawValue: statusStr) ?? .searching,
            mode: RequestMode(rawValue: modeStr) ?? .flexible,
            hardnessLevel: ShiftHardness(rawValue: hardnessStr) ?? .normal,
            requesterId: requesterId,
            requesterName: requesterName,
            requesterRole: requesterRole,
            requesterShiftDate: requesterShiftDate,
            requesterShiftName: requesterShiftName,
            offeredDates: dict["offeredDates"] as? [String] ?? [],
            targetUserId: dict["targetUserId"] as? String,
            targetUserName: dict["targetUserName"] as? String,
            targetShiftDate: dict["targetShiftDate"] as? String,
            targetShiftName: dict["targetShiftName"] as? String
        )
    }
}

// Subvista para cada fila
struct MarketplaceRow: View {
    let req: ShiftChangeRequest
    let onAccept: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(req.requesterName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text("\(req.requesterShiftDate) • \(req.requesterShiftName)")
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            Button(action: onAccept) {
                Text("Cubrir")
                    .bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
