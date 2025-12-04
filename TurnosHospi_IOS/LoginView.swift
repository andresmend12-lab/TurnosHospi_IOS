import SwiftUI

struct LoginView: View {
    // Accedemos al servicio de autenticación
    @EnvironmentObject var authService: AuthService
    
    // Variables locales para el formulario
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: UserRole = .enfermero
    
    @State private var isRegistering = false // Para saber si estamos logueando o registrando
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- Título e Icono ---
                    Image(systemName: "cross.case.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .padding(.bottom, 20)
                    
                    Text(isRegistering ? "Crear Cuenta" : "Bienvenido")
                        .font(.largeTitle)
                        .bold()
                    
                    // --- Campos de Texto ---
                    VStack(spacing: 15) {
                        TextField("Correo electrónico", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        
                        SecureField("Contraseña", text: $password)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        
                        // Campos extra solo para Registro
                        if isRegistering {
                            TextField("Nombre", text: $firstName)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            
                            TextField("Apellidos", text: $lastName)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            
                            Picker("Rol", selection: $selectedRole) {
                                ForEach(UserRole.allCases, id: \.self) { role in
                                    Text(role.rawValue).tag(role)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- Mensaje de Error ---
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // --- Botón de Acción Principal ---
                    if authService.isLoading {
                        ProgressView()
                    } else {
                        Button(action: handleAction) {
                            Text(isRegistering ? "Registrarse" : "Iniciar Sesión")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    // --- Botón para cambiar modo ---
                    Button {
                        withAnimation {
                            isRegistering.toggle()
                            errorMessage = "" // Limpiamos errores al cambiar
                        }
                    } label: {
                        HStack {
                            Text(isRegistering ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?")
                            Text(isRegistering ? "Inicia Sesión" : "Regístrate")
                                .bold()
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    // Lógica para decidir qué función llamar
    func handleAction() {
        if isRegistering {
            // CORREGIDO: Llamada a signUp con todos los datos
            authService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                role: selectedRole
            ) { result in
                switch result {
                case .success:
                    break // El RootView cambiará automáticamente
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        } else {
            // CORREGIDO: Llamada a login
            authService.login(email: email, password: password) { result in
                switch result {
                case .success:
                    break // El RootView cambiará automáticamente
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
