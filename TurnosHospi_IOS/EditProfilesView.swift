import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Campos editables
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedRole: String = ""
    
    // Estados de UI
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    // ⚠️ LISTA LIMITADA DE ROLES
    let roles = ["Supervisor", "Enfermero", "Auxiliar"]
    
    var body: some View {
        ZStack {
            // Fondo Deep Space
            Color.deepSpace.ignoresSafeArea()
            
            // Decoración
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 300).blur(radius: 80).offset(x: -150, y: -300).opacity(0.4)
                Circle().fill(Color.neonViolet).frame(width: 300).blur(radius: 80).offset(x: 150, y: 300).opacity(0.4)
            }
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    Text("Editar Perfil")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    // Avatar con iniciales
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                            .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        // Corrección de String interpolation aplicada aquí
                        Text("\(String(firstName.prefix(1)))\(String(lastName.prefix(1)))")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .textCase(.uppercase)
                    }
                    .padding(.bottom, 10)
                    
                    // --- FORMULARIO ---
                    VStack(spacing: 20) {
                        
                        // Nombre
                        CustomEditField(title: "Nombre", text: $firstName)
                        
                        // Apellidos
                        CustomEditField(title: "Apellidos", text: $lastName)
                        
                        // Rol (Selector con lista limitada)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Puesto / Rol")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                            
                            Menu {
                                ForEach(roles, id: \.self) { role in
                                    Button(role) {
                                        selectedRole = role
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedRole.isEmpty ? "Selecciona un rol" : selectedRole)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.neonViolet)
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top)
                    }
                    
                    // Botón Guardar
                    Button(action: saveChanges) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Guardar Cambios")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .disabled(isLoading)
                }
                .padding(.bottom, 30)
            }
        }
        // Cargar datos actuales al abrir la vista
        .onAppear {
            firstName = authManager.currentUserName
            lastName = authManager.currentUserLastName
            selectedRole = authManager.userRole
        }
        .alert("Perfil Actualizado", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Tus datos se han guardado correctamente.")
        }
    }
    
    func saveChanges() {
        guard !firstName.isEmpty, !lastName.isEmpty else {
            errorMessage = "El nombre y apellidos no pueden estar vacíos."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        authManager.updateUserProfile(firstName: firstName, lastName: lastName, role: selectedRole) { success, error in
            isLoading = false
            if success {
                showSuccessAlert = true
            } else {
                errorMessage = error ?? "Error desconocido"
            }
        }
    }
}

// Componente para los campos de texto
struct CustomEditField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 5)
            
            TextField("", text: $text)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .foregroundColor(.white)
        }
    }
}
