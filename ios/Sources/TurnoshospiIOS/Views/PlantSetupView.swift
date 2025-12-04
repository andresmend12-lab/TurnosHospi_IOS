import SwiftUI

struct PlantSetupView: View {
    let profile: UserProfile
    @EnvironmentObject private var plantVM: PlantViewModel
    @EnvironmentObject private var auth: AuthViewModel

    @State private var name = ""
    @State private var code = ""
    @State private var description = ""
    @State private var joinCode = ""
    @State private var mode: Mode = .join

    enum Mode: String, CaseIterable, Identifiable { case join, create; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.18)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Picker("Modo", selection: $mode) {
                        Text("Unirme a planta").tag(Mode.join)
                        Text("Crear planta").tag(Mode.create)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    GlassCard(title: mode == .join ? "Unirme con código" : "Crear nueva planta", icon: "building.2.fill") {
                        if mode == .join {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Código", text: $joinCode)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    Task { await plantVM.joinPlant(code: joinCode, userId: profile.id); auth.plant = plantVM.pendingPlant }
                                } label: { Label("Unirme", systemImage: "person.crop.circle.badge.plus") }
                                .buttonStyle(.borderedProminent)
                                .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Nombre de la planta", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Código", text: $code)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Descripción", text: $description)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    Task { await plantVM.createPlant(name: name, code: code, description: description, user: profile); auth.plant = plantVM.pendingPlant }
                                } label: { Label("Crear y asignarme", systemImage: "checkmark.seal.fill") }
                                .buttonStyle(.borderedProminent)
                                .disabled(name.isEmpty || code.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let error = plantVM.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .navigationTitle("Configurar planta")
            }
        }
    }
}
