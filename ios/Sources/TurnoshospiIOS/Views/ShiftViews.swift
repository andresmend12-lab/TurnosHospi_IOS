import SwiftUI

struct ShiftDashboardView: View {
    let profile: UserProfile
    @EnvironmentObject private var shiftVM: ShiftViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hola, \(profile.firstName)")
                                    .font(.title2.bold())
                                Text("Tu agenda clínica")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: profile.avatarSystemName)
                                .symbolRenderingMode(.hierarchical)
                                .font(.largeTitle)
                                .foregroundStyle(.cyan)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Resumen rápido", icon: "waveform.path.ecg") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                                SummaryPill(title: "Horas", value: "\(Int(shiftVM.stats.totalHours))h", icon: "clock.arrow.circlepath", tint: .cyan)
                                SummaryPill(title: "Noches", value: "\(shiftVM.stats.nightCount)", icon: "moon.stars.fill", tint: .indigo)
                                SummaryPill(title: "½ Jornadas", value: "\(shiftVM.stats.halfDays)", icon: "clock.badge.exclamationmark", tint: .orange)
                                SummaryPill(title: "Vacaciones", value: "\(shiftVM.stats.vacations)", icon: "beach.umbrella.fill", tint: .mint)
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Turnos de la semana", icon: "calendar") {
                            VStack(spacing: 12) {
                                ForEach(shiftVM.myShifts) { shift in
                                    NavigationLink {
                                        ShiftDetailView(shift: shift, profile: profile)
                                    } label: {
                                        ShiftRowView(shift: shift)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Vacaciones y descansos", icon: "airplane.departure") {
                            if shiftVM.vacations.isEmpty {
                                Text("Sin vacaciones declaradas")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(shiftVM.vacations) { vacation in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(vacation.startDate, style: .date) - \(vacation.endDate, style: .date)")
                                            Text(vacation.notes.isEmpty ? "Vacaciones" : vacation.notes)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Label(vacation.status.rawValue.capitalized, systemImage: "checkmark.seal")
                                            .font(.caption)
                                            .padding(8)
                                            .background(.ultraThinMaterial, in: Capsule())
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                        Spacer(minLength: 16)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Mis turnos")
        }
    }
}

struct ShiftRowView: View {
    let shift: Shift
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: shift.segment.icon)
                .font(.title2)
                .foregroundStyle(.cyan)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.name).font(.headline)
                Text("\(shift.segment.label) · \(shift.location)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(shift.notes).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(shift.date, style: .date).font(.subheadline)
                Label(shift.status.rawValue, systemImage: "circle.fill")
                    .font(.footnote)
                    .foregroundStyle(color(for: shift.status))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func color(for status: Shift.Status) -> Color {
        switch status {
        case .assigned: return .green
        case .offered: return .orange
        case .swapped: return .blue
        case .unavailable: return .gray
        }
    }
}

struct ShiftDetailView: View {
    let shift: Shift
    let profile: UserProfile

    var body: some View {
        Form {
            Section("Turno") {
                Text(shift.name)
                Text(shift.date.formatted(date: .complete, time: .omitted))
                Label(shift.segment.label, systemImage: shift.segment.icon)
                Text("Duración: \(Int(shift.hours))h")
                Text(shift.notes)
            }
            Section("Acciones") {
                Button {
                    // In a real app this would open a marketplace modal
                } label: {
                    Label("Proponer intercambio", systemImage: "arrow.triangle.swap")
                }
                Button {
                    // placeholder
                } label: {
                    Label("Solicitar reemplazo", systemImage: "person.2.fill")
                }
            }
            Section("Historial") {
                Text("Registro de cambios y aprobaciones")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(shift.name)
    }
}

struct MarketplaceView: View {
    let plant: Plant
    @EnvironmentObject private var shiftVM: ShiftViewModel
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.1, green: 0.13, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let warning = shiftVM.validationMessage {
                            Text(warning)
                                .foregroundStyle(.yellow)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                        }

                        GlassCard(title: "Coberturas y cambios", icon: "arrow.2.squarepath") {
                            if shiftVM.marketplaceRequests.isEmpty {
                                Text("Sin solicitudes abiertas")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(shiftVM.marketplaceRequests) { request in
                                    MarketplaceRow(request: request)
                                }
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Turnos disponibles", icon: "calendar.badge.plus") {
                            ForEach(shiftVM.myShifts.filter { $0.status == .offered || $0.segment == .halfDay }) { shift in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(shift.name).font(.headline)
                                        Text(shift.date, style: .date).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Ofrecer") {
                                        // Placeholder, would publish to Firebase
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(8)
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Equipo y roles", icon: "person.3.fill") {
                            ForEach(plant.members) { member in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(member.name).font(.headline)
                                        Text(member.role.rawValue).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Rol crítico")
                                        .font(.caption2)
                                        .padding(6)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        Spacer(minLength: 24)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Marketplace")
        }
    }
}

struct MarketplaceRow: View {
    @EnvironmentObject private var shiftVM: ShiftViewModel
    @EnvironmentObject private var auth: AuthViewModel
    let request: ShiftChangeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shiftVM.resolveName(for: request.requesterId))
                    .font(.headline)
                Spacer()
                Text(request.type == .coverage ? "Cobertura" : "Intercambio")
                    .font(.caption)
                    .padding(6)
                    .background(Color.orange.opacity(0.2), in: Capsule())
            }
            Text("Turno: \(request.requesterShiftName) · \(request.requesterShiftDate, style: .date)")
                .font(.subheadline)
            if !request.offeredDates.isEmpty {
                Text("Ofrece: \(request.offeredDates.map { $0.formatted(date: .numeric, time: .omitted) }.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let profile = auth.profile, let plantId = auth.plant?.id {
                Button {
                    shiftVM.respond(to: request, with: shiftVM.myShifts.first, profile: profile, plantId: plantId)
                } label: {
                    Label("Postularme", systemImage: "hand.wave")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SummaryPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Circle().fill(tint.opacity(0.4)).frame(width: 14, height: 14).offset(x: -6, y: 6)
        }
    }
}

struct GlassCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }
}

struct StatsView: View {
    @EnvironmentObject private var shiftVM: ShiftViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, Color(red: 0.09, green: 0.12, blue: 0.18)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassCard(title: "Estadísticas", icon: "chart.bar.fill") {
                            VStack(spacing: 12) {
                                SummaryRow(title: "Horas asignadas", value: "\(Int(shiftVM.stats.totalHours)) h")
                                SummaryRow(title: "Turnos nocturnos", value: "\(shiftVM.stats.nightCount)")
                                SummaryRow(title: "Medias jornadas", value: "\(shiftVM.stats.halfDays)")
                                SummaryRow(title: "Vacaciones", value: "\(shiftVM.stats.vacations)")
                                SummaryRow(title: "Cambios confirmados", value: "\(shiftVM.stats.swapsCompleted)")
                                SummaryRow(title: "Sugerencias enviadas", value: "\(shiftVM.stats.suggestionsSent)")
                            }
                        }
                        .padding(.horizontal)

                        GlassCard(title: "Roles críticos", icon: "shield.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mantén cubiertos los roles médicos y de enfermería críticos. Las medias jornadas se destacan para avisos tempranos de refuerzo.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Estadísticas")
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
