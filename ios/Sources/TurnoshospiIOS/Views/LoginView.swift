import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = "maria.diaz@hospi.cl"
    @State private var password = "123456"
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
                        Label("Ingresar", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
    @State private var name = "Nueva persona"
    @State private var email = ""
    @State private var specialty = "Pediatría"
    @State private var role: StaffRole = .doctor

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre", text: $name)
                    TextField("Correo", text: $email)
                    Picker("Rol", selection: $role) {
                        ForEach(StaffRole.allCases) { role in
                            Label(role.rawValue, systemImage: role.icon).tag(role)
                        }
                    }
                    TextField("Servicio", text: $specialty)
                }
            }
            .navigationTitle("Crear cuenta")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        auth.profile = UserProfile(
                            id: UUID(),
                            name: name,
                            email: email,
                            role: role,
                            avatarSystemName: "person.crop.circle.fill",
                            specialty: specialty
                        )
                        auth.isAuthenticated = true
                    }
                }
            }
        }
    }
}
