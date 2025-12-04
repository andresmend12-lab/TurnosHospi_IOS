import SwiftUI

struct PlantDetailView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingAddStaff = false
    
    // Mock Data
    let staffMembers = [
        PlantMembership(plantId: "1", userId: "u1", staffId: "ENF-001", staffName: "Laura Martínez", staffRole: .enfermero),
        PlantMembership(plantId: "1", userId: "u2", staffId: "AUX-023", staffName: "Carlos Ruiz", staffRole: .auxiliar)
    ]
    
    var body: some View {
        List {
            Section(header: Text("Información")) {
                HStack {
                    Text("Planta")
                    Spacer()
                    Text("Hospital General - Norte")
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Código de Acceso")
                    Spacer()
                    Text("••••••") // Oculto por seguridad
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Personal Asignado")) {
                ForEach(staffMembers, id: \.staffId) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.staffName)
                                .font(.headline)
                            Text(member.staffRole.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if authService.currentUser?.role == .supervisor {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            if authService.currentUser?.role == .supervisor {
                Section {
                    Button(action: { showingAddStaff = true }) {
                        Label("Añadir Personal", systemImage: "person.badge.plus")
                    }
                }
            }
        }
#if os(iOS)
.listStyle(InsetGroupedListStyle())
#else
.listStyle(GroupedListStyle())
#endif
        .navigationTitle("Mi Planta")
        .sheet(isPresented: $showingAddStaff) {
            Text("Formulario para añadir personal") // Placeholder
        }
    }
}
