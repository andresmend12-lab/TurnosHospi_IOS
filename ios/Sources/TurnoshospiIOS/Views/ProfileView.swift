import SwiftUI

struct ProfileView: View {
    let profile: UserProfile
    let plant: Plant
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var shiftVM: ShiftViewModel
    @State private var suggestionText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassCard(title: "Profesional", icon: "person.crop.circle") {
                            HStack(spacing: 12) {
                                Image(systemName: profile.avatarSystemName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 52, height: 52)
                                    .foregroundStyle(.cyan)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                                VStack(alignment: .leading) {
                                    Text(profile.name).font(.headline)
                                    Text(profile.displayRole).foregroundStyle(.secondary)
                                    Text("Servicio: \(profile.specialty)").font(.footnote)
                                }
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Planta", icon: "building.2.fill") {
                            Text(plant.name).font(.headline)
                            Text("Código: \(plant.code)").font(.footnote)
                            Text(plant.description).font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Sugerencias y mejoras", icon: "bubble.left.and.exclamationmark") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Comparte ideas para roles, vacaciones o estadísticas. Se envían a coordinación.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $suggestionText)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                Button("Enviar sugerencia") {
                                    shiftVM.submitSuggestion(text: suggestionText)
                                    suggestionText = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(suggestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                if !shiftVM.suggestions.isEmpty {
                                    Divider()
                                    ForEach(shiftVM.suggestions) { suggestion in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(suggestion.message)
                                                Text(suggestion.createdAt, style: .date)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(suggestion.status)
                                                .font(.caption)
                                                .padding(6)
                                                .background(.ultraThinMaterial, in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Sesión", icon: "rectangle.portrait.and.arrow.right") {
                            Button(role: .destructive) {
                                auth.signOut()
                            } label: {
                                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Perfil")
        }
    }
}
