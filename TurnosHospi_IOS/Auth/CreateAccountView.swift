import SwiftUI

struct CreateAccountView: View {
    var onBack: () -> Void
    var onCreate: (UserProfile, String, @escaping (Bool) -> Void) -> Void
    
    // Estados del formulario
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role = ""
    @State private var gender = ""
    @State private var isSaving = false
    @State private var passwordMismatch = false
    
    // Modelos para los Pickers
    let genders = [("male", "Hombre"), ("female", "Mujer")]
    // La lógica de roles dinámicos según género se puede simplificar en UI
    var roles: [String] {
        if gender == "female" {
            return ["Supervisora", "Enfermera", "Auxiliar"]
        } else {
            return ["Supervisor", "Enfermero", "Auxiliar"]
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Crear Cuenta")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Group {
                    TextFieldWithLabel(label: "Correo electrónico", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureFieldWithLabel(label: "Contraseña", text: $password)
                    SecureFieldWithLabel(label: "Confirmar contraseña", text: $confirmPassword)
                    
                    TextFieldWithLabel(label: "Nombre", text: $firstName)
                    TextFieldWithLabel(label: "Apellidos", text: $lastName)
                }
                
                // Gender Picker
                VStack(alignment: .leading) {
                    Text("Género").font(.caption).foregroundColor(.white.opacity(0.8))
                    Menu {
                        ForEach(genders, id: \.0) { g in
                            Button(g.1) { gender = g.0; role = "" } // Reset role on gender change
                        }
                    } label: {
                        HStack {
                            Text(gender.isEmpty ? "Seleccionar" : (genders.first(where: {$0.0 == gender})?.1 ?? ""))
                                .foregroundColor(gender.isEmpty ? .gray : .white)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.6)))
                    }
                }
                
                // Role Picker
                VStack(alignment: .leading) {
                    Text("Puesto").font(.caption).foregroundColor(.white.opacity(0.8))
                    Menu {
                        ForEach(roles, id: \.self) { r in
                            Button(r) { role = r }
                        }
                    } label: {
                        HStack {
                            Text(role.isEmpty ? "Seleccionar" : role)
                                .foregroundColor(role.isEmpty ? .gray : .white)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.6)))
                    }
                }
                .disabled(gender.isEmpty)
                
                if passwordMismatch {
                    Text("Las contraseñas no coinciden")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                Button(action: {
                    if password != confirmPassword {
                        passwordMismatch = true
                        return
                    }
                    isSaving = true
                    let profile = UserProfile(firstName: firstName, lastName: lastName, role: role, gender: gender, email: email)
                    onCreate(profile, password) { success in
                        isSaving = false
                        if !success { password = ""; confirmPassword = "" }
                    }
                }) {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text("REGISTRARSE")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "7C3AED"))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(!isValidForm || isSaving)
                
                Button("Volver al inicio de sesión", action: onBack)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(22)
            .background(Color.white.opacity(0.1))
            .cornerRadius(28)
            .padding()
        }
    }
    
    var isValidForm: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && !firstName.isEmpty && !gender.isEmpty && !role.isEmpty
    }
}

// Helpers locales para campos
struct TextFieldWithLabel: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.white.opacity(0.8))
            TextField("", text: $text).textFieldStyle(OutlinedTextFieldStyle())
        }
    }
}

struct SecureFieldWithLabel: View {
    let label: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.white.opacity(0.8))
            SecureField("", text: $text).textFieldStyle(OutlinedTextFieldStyle())
        }
    }
}

// Necesitamos definir UserProfile temporalmente si no existe en otro lado,
// aunque idealmente debería estar en un archivo de modelos (DataModels.swift)
struct UserProfile: Codable {
    var firstName: String
    var lastName: String
    var role: String
    var gender: String
    var email: String
}
