import SwiftUI
import FirebaseDatabase

struct StaffListView: View {
    // Parámetros necesarios
    var plantId: String
    var staffScope: String // "nurses_only" o "nurses_and_aux"
    
    @State private var staffList: [PlantStaff] = []
    @State private var showingAddSheet = false
    @State private var selectedStaff: PlantStaff? // Para editar
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()
            
            VStack {
                // Cabecera
                HStack {
                    Text("Personal de Planta")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Spacer()
                    // Botón Añadir (+)
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.electricBlue)
                            .shadow(color: .electricBlue.opacity(0.5), radius: 10)
                    }
                }
                .padding()
                
                if isLoading {
                    ProgressView().tint(.white).padding(.top, 50)
                    Spacer()
                } else if staffList.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No hay personal registrado")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 100)
                    Spacer()
                } else {
                    // Lista de Personal
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(staffList) { person in
                                StaffRowCard(person: person) {
                                    // Al tocar la tarjeta, abrimos para editar
                                    selectedStaff = person
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            fetchStaff()
        }
        // Hoja para AÑADIR nuevo
        .sheet(isPresented: $showingAddSheet) {
            AddEditStaffView(plantId: plantId, staffScope: staffScope, staffToEdit: nil)
        }
        // Hoja para EDITAR existente
        .sheet(item: $selectedStaff) { person in
            AddEditStaffView(plantId: plantId, staffScope: staffScope, staffToEdit: person)
        }
    }
    
    // --- LÓGICA DE FIREBASE ---
    func fetchStaff() {
        let ref = Database.database().reference().child("plants").child(plantId).child("staffList")
        
        ref.observe(.value) { snapshot in
            var loadedStaff: [PlantStaff] = []
            
            // Iteración segura sobre los hijos
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                if let dict = child.value as? [String: Any] {
                    
                    let id = dict["id"] as? String ?? ""
                    let name = dict["name"] as? String ?? "Desconocido"
                    let role = dict["role"] as? String ?? ""
                    // Campos extra que requiere tu struct original en PlantModels.swift
                    let email = dict["email"] as? String ?? ""
                    let profileType = dict["profileType"] as? String ?? ""
                    
                    let staffMember = PlantStaff(id: id, name: name, role: role, email: email, profileType: profileType)
                    loadedStaff.append(staffMember)
                }
            }
            
            // Ordenar alfabéticamente
            self.staffList = loadedStaff.sorted(by: { $0.name < $1.name })
            self.isLoading = false
        }
    }
}

// MARK: - Componente de Fila (Tarjeta)
struct StaffRowCard: View {
    let person: PlantStaff
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Icono según rol
                ZStack {
                    Circle()
                        .fill(person.role == "Supervisor" ? Color.neonViolet : Color.electricBlue)
                        .frame(width: 45, height: 45)
                        .opacity(0.2)
                    
                    Image(systemName: person.role == "Supervisor" ? "star.fill" : "person.fill")
                        .foregroundColor(person.role == "Supervisor" ? .neonViolet : .electricBlue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(person.role)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(15)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
