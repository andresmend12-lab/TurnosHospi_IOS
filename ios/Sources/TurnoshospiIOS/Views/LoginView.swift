import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72)
                        .foregroundColor(.blue)
                    Text("Turnoshospi")
                        .font(.largeTitle.bold())
                    Text("Gestión de turnos y comunicación clínica")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 12) {
                    TextField("Correo corporativo", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    SecureField("Contraseña", text: $password)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Button {
                        auth.login(email: email, password: password)
                    } label: {
                        Label(auth.isLoading ? "Conectando..." : "Ingresar", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(auth.isLoading)
                }
                .padding(.horizontal)
                Button("Crear cuenta") { showCreate = true }
                Spacer()
            }
            .padding()
            .sheet(isPresented: $showCreate) {
                CreateAccountView()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var specialty = "Pediatría"
    @State private var role: StaffRole = .doctor
    @State private var gender = "Femenino"
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre", text: $firstName)
                    TextField("Apellidos", text: $lastName)
                    TextField("Correo", text: $email)
                    SecureField("Contraseña", text: $password)
                    Picker("Rol", selection: $role) {
                        ForEach(StaffRole.allCases) { role in
                            Label(role.rawValue, systemImage: role.icon).tag(role)
                        }
                    }
                    Picker("Género", selection: $gender) {
                        ForEach(["Femenino", "Masculino", "Otro"], id: \.self, content: Text.init)
                    }
                    TextField("Servicio", text: $specialty)
                }
            }
            .navigationTitle("Crear cuenta")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        auth.register(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            role: role,
                            gender: gender,
                            password: password,
                            specialty: specialty
                        )
                    }
                    .disabled(firstName.isEmpty || email.isEmpty || password.count < 6)
                }
            }
        }
    }
}
