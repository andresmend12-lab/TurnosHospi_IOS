import SwiftUI
import FirebaseDatabase

struct ShiftChangeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    
    // Estados
    @State private var selectedTab = 0
    @State private var myRequests: [ShiftChangeRequest] = []
    @State private var showNewRequestSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Selector de Pestañas (Segmented Control Personalizado)
            HStack {
                TabButton(title: "Mis Solicitudes", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "Mercado de Turnos", isSelected: selectedTab == 1) { selectedTab = 1 }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Contenido
            if selectedTab == 0 {
                MyRequestsView(requests: myRequests, onCreateNew: {
                    showNewRequestSheet = true
                })
            } else {
                MarketplaceView() // Vista placeholder para el mercado global
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea())
        .sheet(isPresented: $showNewRequestSheet) {
            CreateChangeRequestView(plantId: authManager.userPlantId)
        }
        .onAppear {
            // Aquí cargaríamos las solicitudes reales de Firebase
            loadMockData()
        }
    }
    
    func loadMockData() {
        // Datos de prueba
        myRequests = [
            ShiftChangeRequest(requesterId: "1", requesterName: authManager.currentUserName, originalShiftDate: "2023-12-25", originalShiftType: "Mañana")
        ]
    }
}

// MARK: - Subvistas

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .gray)
                
                if isSelected {
                    Rectangle()
                        .fill(Color(red: 0.2, green: 0.4, blue: 1.0)) // Electric Blue
                        .frame(height: 2)
                } else {
                    Rectangle().fill(Color.clear).frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MyRequestsView: View {
    let requests: [ShiftChangeRequest]
    let onCreateNew: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Botón Crear
                Button(action: onCreateNew) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Solicitar Cambio")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.6, green: 0.2, blue: 0.9)) // Neon Violet
                    .cornerRadius(12)
                }
                .padding(.top)
                
                // Lista
                if requests.isEmpty {
                    Text("No tienes solicitudes activas")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                } else {
                    ForEach(requests) { req in
                        RequestCard(request: req)
                    }
                }
            }
            .padding()
        }
    }
}

struct RequestCard: View {
    let request: ShiftChangeRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ofrezco:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(request.status.rawValue)
                    .font(.caption.bold())
                    .padding(5)
                    .background(statusColor(request.status).opacity(0.2))
                    .foregroundColor(statusColor(request.status))
                    .cornerRadius(5)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white)
                Text("\(request.originalShiftDate) - \(request.originalShiftType)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            Text("Busco: \(request.targetDate ?? "Cualquier fecha")")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func statusColor(_ status: ChangeStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
}

struct MarketplaceView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Mercado de turnos de compañeros")
                .foregroundColor(.gray)
                .padding(.top)
            Spacer()
        }
    }
}

// MARK: - Formulario de Creación (Modal)

struct CreateChangeRequestView: View {
    @Environment(\.dismiss) var dismiss
    let plantId: String
    
    @State private var selectedDate = Date()
    @State private var selectedShift = "Mañana"
    @State private var seekingDate = false
    @State private var desiredDate = Date()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Nueva Solicitud")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)
                
                Form {
                    Section(header: Text("¿Qué turno quieres cambiar?")) {
                        DatePicker("Fecha", selection: $selectedDate, displayedComponents: .date)
                        Picker("Turno", selection: $selectedShift) {
                            Text("Mañana").tag("Mañana")
                            Text("Tarde").tag("Tarde")
                            Text("Noche").tag("Noche")
                        }
                    }
                    
                    Section(header: Text("¿Qué buscas a cambio?")) {
                        Toggle("Busco una fecha específica", isOn: $seekingDate)
                        if seekingDate {
                            DatePicker("Fecha deseada", selection: $desiredDate, displayedComponents: .date)
                        } else {
                            Text("Busco cualquier turno o día libre")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button("Publicar Solicitud") {
                        // Lógica de guardado en Firebase iría aquí
                        dismiss()
                    }
                    .listRowBackground(Color(red: 0.2, green: 0.4, blue: 1.0))
                    .foregroundColor(.white)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
