import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            // Fondo
            Color.deepSpace.ignoresSafeArea()

            // Círculos decorativos
            ZStack {
                Circle()
                    .fill(Color.electricBlue)
                    .frame(width: 250)
                    .blur(radius: 80)
                    .offset(x: -80, y: -150)
                Circle()
                    .fill(Color.neonViolet)
                    .frame(width: 250)
                    .blur(radius: 80)
                    .offset(x: 80, y: 150)
            }
            .opacity(0.4)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Volver")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                // Contenido principal
                VStack(spacing: 30) {
                    // Icono
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.electricBlue, .neonViolet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Título
                    VStack(spacing: 10) {
                        Text("¿Olvidaste tu contraseña?")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Campo de email
                    VStack(spacing: 20) {
                        HStack(spacing: 15) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 20)

                            TextField("", text: $email)
                                .placeholder(when: email.isEmpty) {
                                    Text("Correo electrónico")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .foregroundColor(.white)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                        // Mensaje de error
                        if showError {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                        }

                        // Botón enviar
                        Button(action: sendResetEmail) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Enviar enlace")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.electricBlue, .neonViolet],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .neonViolet.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .disabled(email.isEmpty || isLoading)
                        .opacity(email.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 30)
                }

                Spacer()
                Spacer()
            }
        }
        .alert("Correo Enviado", isPresented: $showSuccess) {
            Button("Aceptar") {
                dismiss()
            }
        } message: {
            Text("Te hemos enviado un correo con instrucciones para restablecer tu contraseña. Revisa tu bandeja de entrada y la carpeta de spam.")
        }
    }

    private func sendResetEmail() {
        // Validar email
        guard !email.isEmpty else {
            showError = true
            errorMessage = "Por favor ingresa tu correo electrónico."
            return
        }

        guard email.contains("@") && email.contains(".") else {
            showError = true
            errorMessage = "Por favor ingresa un correo electrónico válido."
            return
        }

        isLoading = true
        showError = false

        authManager.resetPassword(email: email) { success, error in
            isLoading = false

            if success {
                showSuccess = true
            } else {
                showError = true
                // Traducir errores comunes de Firebase
                if let error = error {
                    if error.contains("no user record") || error.contains("user-not-found") {
                        errorMessage = "No existe una cuenta con este correo electrónico."
                    } else if error.contains("invalid-email") {
                        errorMessage = "El correo electrónico no es válido."
                    } else if error.contains("network") {
                        errorMessage = "Error de conexión. Verifica tu internet."
                    } else {
                        errorMessage = error
                    }
                } else {
                    errorMessage = "Error desconocido. Intenta de nuevo."
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthManager())
}
