import SwiftUI

struct ShiftDashboardView: View {
    let profile: UserProfile
    @EnvironmentObject private var shiftVM: ShiftViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Resumen") {
                    HStack {
                        Label("Turnos asignados", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text("\(shiftVM.myShifts.filter { $0.status == .assigned }.count)")
                    }
                    HStack {
                        Label("En intercambio", systemImage: "arrow.2.squarepath")
                        Spacer()
                        Text("\(shiftVM.myShifts.filter { $0.status == .offered }.count)")
                    }
                }
                Section("Semana") {
                    ForEach(shiftVM.myShifts) { shift in
                        NavigationLink {
                            ShiftDetailView(shift: shift, profile: profile)
                        } label: {
                            ShiftRowView(shift: shift)
                        }
                    }
                }
            }
            .navigationTitle("Mis turnos")
        }
    }
}

struct ShiftRowView: View {
    let shift: Shift
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.name).font(.headline)
                Text(shift.location).font(.subheadline).foregroundStyle(.secondary)
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

    var body: some View {
        NavigationStack {
            List {
                Section("Ofertas activas") {
                    ForEach(shiftVM.offers) { offer in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(offer.owner.name).font(.headline)
                                Spacer()
                                Label(offer.offeredShift.status.rawValue, systemImage: "arrow.left.arrow.right")
                                    .foregroundStyle(.orange)
                                    .font(.footnote)
                            }
                            Text("Cambia su \(offer.offeredShift.name) por: \(offer.desiredShiftName)")
                            Text(offer.extraNotes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Equipo") {
                    ForEach(plant.members) { member in
                        VStack(alignment: .leading) {
                            Text(member.name).font(.headline)
                            Text(member.role.rawValue).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Marketplace")
        }
    }
}
