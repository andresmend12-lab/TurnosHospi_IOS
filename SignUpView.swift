import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss // Para volver atrás
    
    // Campos del formulario
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    // Selectores
    @State private var selectedGender = "Masculino"
    let genders = ["Masculino", "Femenino", "Otro"]
    
    @State private var selectedRole = "Enfermero"
    let roles = ["Supervisor", "Enfermero", "Auxiliar"]
    
    @State private var errorMessage: String?
    @State private var isLoading = false

    // Aceptación de términos
    @State private var acceptedTerms = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    var body: some View {
        ZStack {
            // Fondo estático (para no sobrecargar la navegación)
            Color.deepSpace.ignoresSafeArea()
            
            // Círculos de fondo estáticos
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 300).blur(radius: 80).offset(x: -100, y: -200)
                Circle().fill(Color.neonViolet).frame(width: 300).blur(radius: 80).offset(x: 100, y: 100)
            }
            .opacity(0.5)
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // Cabecera
                    Text("Crear Cuenta")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    VStack(spacing: 15) {
                        
                        // Nombre y Apellido
                        GlassTextField(icon: "person.fill", placeholder: "Nombre", text: $firstName)
                        GlassTextField(icon: "person.text.rectangle", placeholder: "Apellido", text: $lastName)
                        
                        // Género (Selector estilo Glass)
                        GlassPicker(title: "Género", selection: $selectedGender, options: genders)
                        
                        // Puesto (Selector estilo Glass)
                        GlassPicker(title: "Puesto", selection: $selectedRole, options: roles)
                        
                        Divider().background(Color.white.opacity(0.3)).padding(.vertical)
                        
                        // Credenciales
                        GlassTextField(icon: "envelope.fill", placeholder: "Correo electrónico", text: $email)
                        GlassTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                        GlassTextField(icon: "lock.shield.fill", placeholder: "Confirmar Contraseña", text: $confirmPassword, isSecure: true)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }

                        // Aceptación de términos y privacidad
                        VStack(spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                Button(action: { acceptedTerms.toggle() }) {
                                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundColor(acceptedTerms ? .electricBlue : .white.opacity(0.5))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Acepto los ")
                                        .foregroundColor(.white.opacity(0.8))
                                    +
                                    Text("Términos de Servicio")
                                        .foregroundColor(.electricBlue)
                                        .underline()
                                    +
                                    Text(" y la ")
                                        .foregroundColor(.white.opacity(0.8))
                                    +
                                    Text("Política de Privacidad")
                                        .foregroundColor(.electricBlue)
                                        .underline()
                                }
                                .font(.caption)
                                .onTapGesture {
                                    // No hacer nada aquí, usamos botones separados
                                }
                            }

                            // Enlaces a documentos
                            HStack(spacing: 20) {
                                Button(action: { showTermsOfService = true }) {
                                    Text("Ver Términos")
                                        .font(.caption2)
                                        .foregroundColor(.electricBlue)
                                }

                                Button(action: { showPrivacyPolicy = true }) {
                                    Text("Ver Privacidad")
                                        .font(.caption2)
                                        .foregroundColor(.electricBlue)
                                }
                            }
                        }
                        .padding(.top, 5)
                    }
                    .padding(25)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal)

                    // Botón de Registro
                    Button(action: registerUser) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Registrarse")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 40)
                    .disabled(isLoading || !acceptedTerms)
                    .opacity(acceptedTerms ? 1.0 : 0.5)

                    Spacer(minLength: 50)
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
    }
    
    // Lógica de validación y registro
    func registerUser() {
        // Validar aceptación de términos
        guard acceptedTerms else {
            errorMessage = "Debes aceptar los Términos y la Política de Privacidad."
            return
        }

        // Validaciones básicas
        guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty else {
            errorMessage = "Por favor, rellena todos los campos."
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Mapeo de género a inglés para la base de datos (según tu ejemplo "female")
        let genderDbValue = selectedGender == "Femenino" ? "female" : (selectedGender == "Masculino" ? "male" : "other")
        
        authManager.register(
            email: email,
            pass: password,
            firstName: firstName,
            lastName: lastName,
            gender: genderDbValue,
            role: selectedRole
        ) { error in
            isLoading = false
            if let error = error {
                errorMessage = error
            } else {
                // Éxito: AuthManager actualiza el usuario y ContentView cambiará la vista automáticamente
                // Pero por si acaso, cerramos esta vista
                dismiss()
            }
        }
    }
}

// Componente auxiliar para los selectores (Pickers) con estilo
struct GlassPicker: View {
    var title: String
    @Binding var selection: String
    var options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 5)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView().environmentObject(AuthManager())
    }
}	
