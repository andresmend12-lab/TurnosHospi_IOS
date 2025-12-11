import SwiftUI

// Extensiones de color (si no las tienes en otro archivo común)
extension Color {
    static let deepSpace = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let neonViolet = Color(red: 0.6, green: 0.2, blue: 0.9)
    static let electricBlue = Color(red: 0.2, green: 0.4, blue: 1.0)
}

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var animateBackground = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack { // <--- NUEVO: Permite navegar a SignUpView
            ZStack {
                // --- FONDO ANIMADO ---
                Color.deepSpace.ignoresSafeArea()
                
                ZStack {
                    Circle()
                        .fill(Color.electricBlue)
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(x: animateBackground ? 30 : -130, y: animateBackground ? -30 : -180)
                        .scaleEffect(animateBackground ? 1.1 : 0.8)
                    
                    Circle()
                        .fill(Color.neonViolet)
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(x: animateBackground ? -30 : 130, y: animateBackground ? 30 : 180)
                        .scaleEffect(animateBackground ? 1.2 : 0.9)
                }
                .opacity(0.7)
                .onAppear {
                    withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                        animateBackground = true
                    }
                }
                
                // --- FORMULARIO ---
                VStack(spacing: 25) {
                    VStack(spacing: 5) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .padding(.bottom, 10)
                            
                        Text("TurnosHospi")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 20)
                    
                    VStack(spacing: 15) {
                        GlassTextField(icon: "envelope.fill", placeholder: "Correo electrónico", text: $email)
                        GlassTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Button(action: {
                        authManager.signIn(email: email, pass: password) { error in
                            if let error = error {
                                self.errorMessage = "Error: \(error)"
                            }
                        }
                    }) {
                        Text("Iniciar Sesión")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(15)
                            .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 15) {
                        Text("o")
                            .foregroundColor(.white.opacity(0.5))
                        
                        // ENLACE A REGISTRO CAMBIADO
                        NavigationLink(destination: SignUpView()) {
                            Text("Crear una cuenta nueva")
                                .fontWeight(.semibold)
                                .foregroundColor(.electricBlue)
                        }
                    }
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
    }
}

// Mantén GlassTextField aquí si lo tenías en este archivo, o asegúrate de que esté disponible
struct GlassTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.white.opacity(0.6)).frame(width: 20)
            if isSecure {
                SecureField("", text: $text).placeholder(when: text.isEmpty) { Text(placeholder).foregroundColor(.white.opacity(0.5)) }.foregroundColor(.white)
            } else {
                TextField("", text: $text).placeholder(when: text.isEmpty) { Text(placeholder).foregroundColor(.white.opacity(0.5)) }.foregroundColor(.white).autocapitalization(.none).keyboardType(.emailAddress)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// Asegúrate de tener la extensión de placeholder también
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
