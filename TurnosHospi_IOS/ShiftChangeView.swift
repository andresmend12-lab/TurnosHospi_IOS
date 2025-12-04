import SwiftUI

struct ShiftChangeView: View {
    @State private var selectedSegment = 0
    @State private var showNewRequestSheet = false
    
    // Datos simulados para la UI
    @State private var receivedRequests = [
        ChangeRequestMock(id: 1, requesterName: "Laura Martínez", originalDate: "12 Oct", originalShift: "Mañana", targetDate: "14 Oct", targetShift: "Tarde", status: .pending),
        ChangeRequestMock(id: 2, requesterName: "Carlos Ruiz", originalDate: "20 Oct", originalShift: "Noche", targetDate: "21 Oct", targetShift: "Noche", status: .pending)
    ]
    
    @State private var sentRequests = [
        ChangeRequestMock(id: 3, requesterName: "Yo", originalDate: "15 Oct", originalShift: "Tarde", targetDate: "18 Oct", targetShift: "Mañana", status: .rejected)
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Selector: Recibidas vs Enviadas
                Picker("Tipo", selection: $selectedSegment) {
                    Text("Recibidas").tag(0)
                    Text("Enviadas").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Lista de solicitudes
                List {
                    if selectedSegment == 0 {
                        if receivedRequests.isEmpty {
                            Text("No tienes solicitudes pendientes.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(receivedRequests) { request in
                                RequestRow(request: request, isReceived: true)
                            }
                            .onDelete(perform: deleteReceived)
                        }
                    } else {
                        if sentRequests.isEmpty {
                            Text("No has enviado solicitudes.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(sentRequests) { request in
                                RequestRow(request: request, isReceived: false)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Cambios de Turno")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewRequestSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewRequestSheet) {
                NewChangeRequestView()
            }
        }
    }
    
    func deleteReceived(at offsets: IndexSet) {
        receivedRequests.remove(atOffsets: offsets)
    }
}

// MARK: - Modelos y Subvistas de UI (Mock)

enum RequestStatus {
    case pending, accepted, rejected
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
    
    var text: String {
        switch self {
        case .pending: return "Pendiente"
        case .accepted: return "Aceptado"
        case .rejected: return "Rechazado"
        }
    }
}

struct ChangeRequestMock: Identifiable {
    let id: Int
    let requesterName: String
    let originalDate: String
    let originalShift: String // El turno que ofrecen
    let targetDate: String    // El turno que quieren (el tuyo)
    let targetShift: String
    var status: RequestStatus
}

struct RequestRow: View {
    let request: ChangeRequestMock
    let isReceived: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isReceived ? request.requesterName : "Para: Administración/Compañero")
                    .font(.headline)
                Spacer()
                Text(request.status.text)
                    .font(.caption)
                    .padding(5)
                    .background(request.status.color.opacity(0.2))
                    .foregroundColor(request.status.color)
                    .cornerRadius(5)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Ofrece:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(request.originalDate) - \(request.originalShift)")
                        .fontWeight(.medium)
                }
                
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Solicita:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(request.targetDate) - \(request.targetShift)")
                        .fontWeight(.medium)
                }
            }
            
            if isReceived && request.status == .pending {
                HStack {
                    Button("Rechazar") {
                        // Acción simulada
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Aceptar") {
                        // Acción simulada
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(.green)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Vista para Crear Nueva Solicitud
struct NewChangeRequestView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMyShiftIndex = 0
    @State private var selectedTargetUser = ""
    @State private var note = ""
    
    // Mock de mis turnos
    let myShifts = ["12 Oct - Mañana", "15 Oct - Tarde", "19 Oct - Noche"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("¿Qué turno quieres cambiar?")) {
                    Picker("Mi Turno", selection: $selectedMyShiftIndex) {
                        ForEach(0..<myShifts.count, id: \.self) { index in
                            Text(myShifts[index])
                        }
                    }
                }
                
                Section(header: Text("¿Con quién? (Opcional)")) {
                    TextField("Nombre del compañero (o dejar libre)", text: $selectedTargetUser)
                }
                
                Section(header: Text("Nota")) {
                    TextEditor(text: $note)
                        .frame(height: 80)
                }
                
                Button(action: {
                    // Lógica de envío aquí
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Enviar Solicitud")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Solicitar Cambio")
            .navigationBarItems(leading: Button("Cancelar") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ShiftChangeView_Previews: PreviewProvider {
    static var previews: some View {
        ShiftChangeView()
    }
}
