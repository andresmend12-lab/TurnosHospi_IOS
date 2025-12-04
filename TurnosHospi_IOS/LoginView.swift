import SwiftUI

struct LoginView: View {
    // Accedemos al servicio de autenticación
    @EnvironmentObject var authService: AuthService
    
    // Variables locales para el formulario
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false // Para saber si estamos logueando o registrando
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
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
                }
                .padding(.horizontal)
                
                // --- Mensaje de Error ---
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // --- Botón de Acción Principal ---
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
    
    // Lógica para decidir qué función llamar
    func handleAction() {
        if isRegistering {
            authService.registerUser(email: email, password: password) { error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                }
            }
        } else {
            authService.loginUser(email: email, password: password) { error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Previsualización (opcional)
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthService())
    }
}
