import SwiftUI

struct LoginView: View {
    @Binding var email: String
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var resetSent = false
    
    // Closures para manejar acciones desde el padre
    var onLogin: (String, String, @escaping (Bool) -> Void) -> Void
    var onCreateAccount: () -> Void
    var onForgotPassword: (String, @escaping (Bool) -> Void) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Iniciar sesión")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email Field
            VStack(alignment: .leading) {
                Text("Correo electrónico").font(.caption).foregroundColor(.white.opacity(0.8))
                TextField("", text: $email)
                    .textFieldStyle(OutlinedTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Password Field
            VStack(alignment: .leading) {
                Text("Contraseña").font(.caption).foregroundColor(.white.opacity(0.8))
                HStack {
                    if isPasswordVisible {
                        TextField("", text: $password)
                    } else {
                        SecureField("", text: $password)
                    }
                }
                .textFieldStyle(OutlinedTextFieldStyle())
                .overlay(
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .foregroundColor(.white)
                            .padding(.trailing, 12)
                    }
                    , alignment: .trailing
                )
            }
            
            // Login Button
            Button(action: {
                isLoading = true
                onLogin(email, password) { success in
                    isLoading = false
                    if !success { password = "" }
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white).padding(.trailing, 5)
                    }
                    Text("ENTRAR")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "7C3AED")) // Color violeta similar al de Android
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            
            // Create Account Link
            Button(action: onCreateAccount) {
                Text("¿No tienes cuenta? Regístrate")
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Forgot Password
            Button(action: {
                resetSent = false
                onForgotPassword(email) { success in resetSent = success }
            }) {
                Text("He olvidado mi contraseña")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
            }
            .disabled(email.isEmpty)
            
            if resetSent {
                Text("Correo de recuperación enviado.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.1))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .padding()
    }
}
