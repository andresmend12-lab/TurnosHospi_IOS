import SwiftUI

struct ProfileView: View {
    let profile: UserProfile
    let plant: Plant
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Profesional") {
                    HStack(spacing: 12) {
                        Image(systemName: profile.avatarSystemName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.headline)
                            Text(profile.role.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    Text("Servicio: \(profile.specialty)")
                }
                Section("Planta") {
                    Text(plant.name)
                    Text("Código: \(plant.code)").font(.footnote)
                    Text(plant.description).font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Perfil")
        }
    }
}
