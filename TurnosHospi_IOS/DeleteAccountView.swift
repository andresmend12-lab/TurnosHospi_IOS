import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var password: String = ""
    @State private var confirmText: String = ""
    @State private var isDeleting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showFinalConfirmation: Bool = false

    private let confirmationWord = "ELIMINAR"

    var canDelete: Bool {
        !password.isEmpty && confirmText == confirmationWord
    }

    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("Eliminar Cuenta")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Placeholder para centrar el título
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 25) {
                        // Icono de advertencia
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .padding(.top, 20)

                        // Título de advertencia
                        Text("¿Estás seguro?")
                            .font(.title.bold())
                            .foregroundColor(.white)

                        // Descripción
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Esta acción es irreversible. Se eliminarán permanentemente:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            VStack(alignment: .leading, spacing: 10) {
                                DeleteItemRow(icon: "person.fill", text: "Tu perfil y datos personales")
                                DeleteItemRow(icon: "message.fill", text: "Todos tus mensajes y conversaciones")
                                DeleteItemRow(icon: "calendar", text: "Tu historial de turnos")
                                DeleteItemRow(icon: "bell.fill", text: "Tus notificaciones")
                                DeleteItemRow(icon: "building.2.fill", text: "Tu asociación con plantas")
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )

                        // Campo de contraseña
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Confirma tu contraseña")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.8))

                            SecureField("Contraseña actual", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                        }

                        // Campo de confirmación
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Escribe \"\(confirmationWord)\" para confirmar")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.8))

                            TextField("", text: $confirmText)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .autocorrectionDisabled()
                        }

                        // Mensaje de error
                        if showError {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(errorMessage)
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Botón de eliminar
                        Button(action: {
                            showFinalConfirmation = true
                        }) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("Eliminar mi cuenta")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canDelete ? Color.red : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!canDelete || isDeleting)

                        // Botón cancelar
                        Button(action: { dismiss() }) {
                            Text("Cancelar")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .alert("Confirmación Final", isPresented: $showFinalConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Esta es tu última oportunidad. ¿Realmente deseas eliminar tu cuenta? Esta acción NO se puede deshacer.")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        showError = false

        authManager.deleteAccount(password: password) { success, error in
            isDeleting = false

            if success {
                // La cuenta fue eliminada, el AuthManager limpiará la sesión
                // y ContentView mostrará LoginView automáticamente
                dismiss()
            } else {
                showError = true
                errorMessage = error ?? "Error desconocido al eliminar la cuenta"
            }
        }
    }
}

struct DeleteItemRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.red.opacity(0.8))
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

#Preview {
    DeleteAccountView()
        .environmentObject(AuthManager())
}
