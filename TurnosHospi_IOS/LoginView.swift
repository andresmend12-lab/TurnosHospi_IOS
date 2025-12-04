import SwiftUI

// 1. Definición de los colores del tema "Espacial"
extension Color {
    static let deepSpace = Color(red: 0.05, green: 0.05, blue: 0.1) // Fondo casi negro
    static let neonViolet = Color(red: 0.6, green: 0.2, blue: 0.9)
    static let electricBlue = Color(red: 0.2, green: 0.4, blue: 1.0)
}

struct LoginView: View {
    // Variables de estado para los campos de texto
    @State private var email: String = ""
    @State private var password: String = ""
    
    // Variable para controlar la animación de fondo
    @State private var animateBackground = false
    
    var body: some View {
        ZStack {
            // --- FONDO AMBIENTAL ANIMADO ---
            Color.deepSpace
                .ignoresSafeArea()
            
            // Círculos de luz con efecto "Lava Lamp"
            ZStack {
                // Círculo Azul Eléctrico
                Circle()
                    .fill(Color.electricBlue)
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: animateBackground ? 30 : -130, y: animateBackground ? -30 : -180)
                    .scaleEffect(animateBackground ? 1.1 : 0.8)
                
                // Círculo Violeta Neón
                Circle()
                    .fill(Color.neonViolet)
                    .frame(width: 350, height: 350)
                    .blur(radius: 90)
                    .offset(x: animateBackground ? -30 : 130, y: animateBackground ? 30 : 180)
                    .scaleEffect(animateBackground ? 1.2 : 0.9)
                
                // Círculo pequeño para detalle (Cyan/Azul claro)
                Circle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .offset(x: animateBackground ? 100 : -50, y: animateBackground ? 150 : 50)
            }
            .opacity(0.7)
            .onAppear {
                // Animación lenta y continua (7 segundos)
                withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }
            
            // --- TARJETA DE CRISTAL (GLASS CARD) ---
            VStack(spacing: 25) {
                
                // Título y Logo
                VStack(spacing: 5) {
                    Image(systemName: "cross.case.fill") // Icono médico
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .padding(.bottom, 10)
                        
                    Text("TurnosHospi")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Bienvenido de nuevo")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 20)
                
                // Campos de Texto
                VStack(spacing: 15) {
                    GlassTextField(icon: "envelope.fill", placeholder: "Correo electrónico", text: $email)
                    
                    GlassTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                    
                    // Botón Olvidaste contraseña
                    HStack {
                        Spacer()
                        Button("¿Olvidaste tu contraseña?") {
                            print("Ir a recuperar contraseña")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Botón de Iniciar Sesión
                Button(action: {
                    print("Login con: \(email)")
                }) {
                    Text("Iniciar Sesión")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(15)
                        .shadow(color: .neonViolet.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 10)
                
                // Separador y Crear Cuenta
                VStack(spacing: 15) {
                    Text("o")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Button(action: {
                        print("Ir a crear cuenta")
                    }) {
                        Text("Crear una cuenta nueva")
                            .fontWeight(.semibold)
                            .foregroundColor(.electricBlue)
                    }
                }
            }
            .padding(30)
            .background(.ultraThinMaterial) // Efecto de vidrio esmerilado
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(.white.opacity(0.2), lineWidth: 1) // Borde sutil
            )
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// 3. Componente reutilizable para los campos de texto estilo cristal
struct GlassTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1)) // Fondo semitransparente
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// 4. Extensión para permitir placeholder con color personalizado
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// Previsualización
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
