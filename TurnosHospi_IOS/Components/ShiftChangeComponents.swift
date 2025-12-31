//
//  ShiftChangeComponents.swift
//  TurnosHospi_IOS
//
//  Extracted reusable components from ShiftChangeView
//

import SwiftUI

// MARK: - Shift Change Header

struct ShiftChangeHeaderView: View {
    let isInCandidateMode: Bool
    let onBack: () -> Void

    var body: some View {
        HStack {
            if isInCandidateMode {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                }
                Text("Buscador de Candidatos")
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                Text("Gestión de Cambios")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Tab Selector

struct ShiftChangeTabSelector: View {
    @Binding var selectedTab: Int
    let tabs: [String]

    var body: some View {
        Picker("", selection: $selectedTab) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Text(tabs[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .colorScheme(.dark)
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Loading Candidates View

struct LoadingCandidatesView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Analizando compatibilidad con reglas...")
                .tint(.white)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

// MARK: - Status Indicator

struct RequestStatusIndicator: View {
    let status: RequestStatus

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
                .foregroundColor(color)
                .bold()
        }
    }

    private var text: String {
        switch status {
        case .draft: return "Borrador"
        case .searching: return "Buscando cambio"
        case .pendingPartner: return "Esperando confirmación"
        case .awaitingSupervisor: return "Pendiente de supervisor"
        case .approved: return "Aceptado"
        case .rejected: return "Rechazado"
        }
    }

    private var color: Color {
        switch status {
        case .searching: return .blue
        case .pendingPartner: return .orange
        case .awaitingSupervisor: return .purple
        case .approved: return .green
        case .rejected: return .red
        case .draft: return .gray
        }
    }

    private var icon: String {
        switch status {
        case .searching: return "magnifyingglass"
        case .pendingPartner: return "person.2.wave.2"
        case .awaitingSupervisor: return "hourglass"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .draft: return "circle"
        }
    }
}

// MARK: - Action Buttons Row

struct RequestActionButtonsRow: View {
    let onAccept: () -> Void
    let onReject: () -> Void
    let isSupervisor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSupervisor ? "Revisión de supervisor" : "Tú decides esta solicitud")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack {
                Button(action: onReject) {
                    Text("Rechazar")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)

                Button(action: onAccept) {
                    Text(isSupervisor ? "Aprobar" : "Aceptar")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.3))
                .foregroundColor(.green)
                .cornerRadius(8)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Date Badge

struct DateBadge: View {
    let dateString: String

    var body: some View {
        Text(dateString)
            .font(.caption)
            .bold()
            .foregroundColor(.white)
            .padding(4)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(4)
    }
}

// MARK: - Shift Name Label

struct ShiftNameLabel: View {
    let shiftName: String

    var body: some View {
        Text(shiftName)
            .font(.headline)
            .foregroundColor(.white)
    }
}

// MARK: - Mode Badge

struct ModeBadge: View {
    let mode: RequestMode

    var body: some View {
        Text(mode == .flexible ? "Flexible" : "Estricto")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white.opacity(0.8))
            .cornerRadius(4)
    }
}

// MARK: - Searching Status Badge

struct SearchingStatusBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("Buscando")
                .font(.caption)
                .foregroundColor(.green)
                .fontWeight(.bold)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Shift Icon View

struct ShiftIconView: View {
    let shiftName: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(color)
        }
    }

    private var color: Color {
        let n = shiftName.lowercased()
        if n.contains("mañana") || n.contains("día") || n.contains("dia") { return .yellow }
        if n.contains("tarde") { return .orange }
        if n.contains("noche") { return .indigo }
        return .blue
    }

    private var icon: String {
        let n = shiftName.lowercased()
        if n.contains("mañana") || n.contains("día") || n.contains("dia") { return "sun.max.fill" }
        if n.contains("tarde") { return "sunset.fill" }
        if n.contains("noche") { return "moon.stars.fill" }
        return "clock.fill"
    }
}

// MARK: - Empty Requests View

struct EmptyRequestsView: View {
    let iconName: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text(title)
                .foregroundColor(.gray)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

// MARK: - Candidate Row

struct CandidateRowView: View {
    let userName: String
    let dateString: String
    let shiftName: String
    let isDateFiltered: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.headline)
                    .foregroundColor(.white)
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(dateString) • \(shiftName)")
                        .font(.subheadline)
                        .foregroundColor(isDateFiltered ? .green : .gray)
                }
            }
            Spacer()
            Button(action: onSelect) {
                Text("Elegir")
                    .bold()
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.white.opacity(0.05))
    }
}

// MARK: - Filter Panel

struct CandidateFilterPanel: View {
    @Binding var filterName: String
    @Binding var filterShift: String
    @Binding var filterDate: Date
    @Binding var useDateFilter: Bool
    let uniqueNames: [String]
    let uniqueShifts: [String]
    let onClear: () -> Void

    var showClearButton: Bool {
        !filterName.isEmpty || !filterShift.isEmpty || useDateFilter
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Filtrar candidatos")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                Spacer()
                if showClearButton {
                    Button("Limpiar", action: onClear)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            // Filter Menus
            HStack(spacing: 10) {
                FilterMenuButton(
                    icon: "person.magnifyingglass",
                    placeholder: "Persona...",
                    selectedValue: filterName,
                    options: uniqueNames,
                    onSelect: { filterName = $0 },
                    onClear: { filterName = "" }
                )

                FilterMenuButton(
                    icon: "clock",
                    placeholder: "Turno...",
                    selectedValue: filterShift,
                    options: uniqueShifts,
                    onSelect: { filterShift = $0 },
                    onClear: { filterShift = "" }
                )
            }

            // Date Filter
            HStack {
                Toggle(isOn: $useDateFilter) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(useDateFilter ? .white : .gray)
                        Text("Fecha específica")
                            .font(.subheadline)
                            .foregroundColor(useDateFilter ? .white : .gray)
                    }
                }
                .tint(.blue)
                .fixedSize()

                Spacer()

                if useDateFilter {
                    DatePicker("", selection: $filterDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - Filter Menu Button

struct FilterMenuButton: View {
    let icon: String
    let placeholder: String
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        Menu {
            Button("Todos", action: onClear)
            ForEach(options, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                Text(selectedValue.isEmpty ? placeholder : selectedValue)
                    .foregroundColor(selectedValue.isEmpty ? .gray : .white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview Simulation Day Cell

struct SimulationDayCell: View {
    let dayNum: Int
    let displayText: String
    let isCenter: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNum)")
                .font(.caption2)
                .foregroundColor(isCenter ? .white : .gray)
                .fontWeight(isCenter ? .bold : .regular)

            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(displayText)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isCenter ? 2 : 0)
                )
        }
        .frame(width: 30)
    }
}

// MARK: - Calendar Weekday Header

struct CalendarWeekdayHeader: View {
    let weekDays = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        HStack {
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Calendar Month Header

struct CalendarMonthHeader: View {
    let monthYearString: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Text(monthYearString.capitalized)
                .font(.title3.bold())
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 20) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }
}

// MARK: - Selected Shift Detail Card

struct SelectedShiftDetailCard: View {
    let shiftName: String
    let isVacationDay: Bool
    let onRequestChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Turno seleccionado:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(shiftName)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            if isVacationDay {
                Label("Vacaciones", systemImage: "sun.max.fill")
                    .font(.caption.bold())
                    .foregroundColor(.red.opacity(0.9))
            } else {
                Button("Solicitar Cambio", action: onRequestChange)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.2, green: 0.4, blue: 1.0))
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.top, 10)
    }
}

// MARK: - Create Request Modal Components

struct RequestShiftInfoCard: View {
    let dateString: String
    let shiftName: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("Estás ofreciendo:")
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text(dateString)
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "clock")
                    .foregroundColor(.purple)
                Text(shiftName)
                    .bold()
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Request Mode Picker

struct RequestModePicker: View {
    @Binding var mode: RequestMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modo de cambio")
                .font(.caption)
                .foregroundColor(.gray)
            Picker("Modo", selection: $mode) {
                Text("Flexible (Cualquier cambio)").tag(RequestMode.flexible)
                Text("Estricto (Mismo rol/horario)").tag(RequestMode.strict)
            }
            .pickerStyle(SegmentedPickerStyle())
            .colorScheme(.dark)
        }
    }
}
