import SwiftUI
import FirebaseDatabase

struct AddEditStaffView: View {
    @Environment(\.dismiss) var dismiss
    
    let plantId: String
    let staffScope: String
    let staffToEdit: PlantStaff? // Si es nil, es modo CREAR. Si existe, es modo EDITAR.
    
    @State private var fullName: String = ""
    @State private var selectedRole: String = "Enfermero"
    @State private var isLoading = false
    
    // Roles disponibles según la configuración de la planta
    var availableRoles: [String] {
        var roles = ["Supervisor", "Enfermero"]
        if staffScope == "nurses_and_aux" {
            roles.append("TCAE") // Auxiliar
        }
        return roles
    }
    
    var isEditing: Bool {
        return staffToEdit != nil
    }
    
    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Título Modal
                Text(isEditing ? "Editar Personal" : "Añadir Personal")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)
                
                // Formulario
                VStack(spacing: 20) {
                    // Campo Nombre
                    VStack(alignment: .leading) {
                        Text("Nombre Completo")
                            .font(.caption).foregroundColor(.gray)
                        HStack {
                            Image(systemName: "person.fill").foregroundColor(.gray)
                            TextField("Ej: Ana García", text: $fullName)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // Selector de Rol
                    VStack(alignment: .leading) {
                        Text("Rol")
                            .font(.caption).foregroundColor(.gray)
                        
                        Picker("Selecciona un rol", selection: $selectedRole) {
                            ForEach(availableRoles, id: \.self) { role in
                                Text(role).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                
                Spacer()
                
                // Botón Guardar
                Button(action: saveStaff) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEditing ? "Guardar Cambios" : "Añadir a la Planta")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                fullName.isEmpty ? Color.gray : Color.electricBlue
                            )
                            .cornerRadius(15)
                    }
                }
                .disabled(fullName.isEmpty || isLoading)
                .padding(.bottom)
            }
            .padding()
        }
        .onAppear {
            // Si estamos editando, cargar los datos existentes
            if let staff = staffToEdit {
                fullName = staff.name
                selectedRole = staff.role
            }
        }
    }
    
    func saveStaff() {
        isLoading = true
        let ref = Database.database().reference().child("plants").child(plantId).child("staffList")
        
        // Si editamos, usamos el ID existente. Si es nuevo, generamos uno.
        let staffId = staffToEdit?.id ?? ref.childByAutoId().key ?? UUID().uuidString
        
        let staffData: [String: Any] = [
            "id": staffId,
            "name": fullName,
            "role": selectedRole,
            // Mantener datos antiguos si es edición, o vacíos si es nuevo para cumplir con PlantStaff
            "email": staffToEdit?.email ?? "",
            "profileType": staffToEdit?.profileType ?? "staff"
        ]
        
        // Guardar en Firebase
        ref.child(staffId).setValue(staffData) { error, _ in
            isLoading = false
            if let error = error {
                print("Error al guardar: \(error.localizedDescription)")
            } else {
                dismiss()
            }
        }
    }
}
