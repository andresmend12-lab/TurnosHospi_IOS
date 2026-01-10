import SwiftUI

// MARK: - Selector de Fecha Rápido

struct DatePickerSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSpacing.xl) {
                // Atajos rápidos
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    Text("Ir a...")
                        .font(DesignFonts.headline)
                        .foregroundColor(DesignColors.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSpacing.md) {
                        QuickDateButton(title: "Hoy", icon: "sun.max.fill") {
                            goToDate(Date())
                        }

                        QuickDateButton(title: "Este mes", icon: "calendar") {
                            goToMonth(Date())
                        }

                        QuickDateButton(title: "Mes anterior", icon: "arrow.left.circle") {
                            goToMonth(Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
                        }

                        QuickDateButton(title: "Próximo mes", icon: "arrow.right.circle") {
                            goToMonth(Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
                        }
                    }
                }

                Divider()
                    .background(DesignColors.cardBackgroundLight)

                // Selector de fecha personalizado
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    Text("Seleccionar fecha")
                        .font(DesignFonts.headline)
                        .foregroundColor(DesignColors.textPrimary)

                    DatePicker(
                        "Fecha",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .tint(DesignColors.accent)

                    Button {
                        goToDate(selectedDate)
                    } label: {
                        Text("Ir a esta fecha")
                            .font(DesignFonts.bodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSpacing.md)
                            .background(DesignColors.accent)
                            .cornerRadius(DesignCornerRadius.medium)
                    }
                }

                Spacer()
            }
            .padding(DesignSpacing.xl)
            .background(DesignColors.cardBackground.ignoresSafeArea())
            .navigationTitle("Navegar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func goToDate(_ date: Date) {
        HapticManager.selection()
        viewModel.currentMonth = date
        viewModel.selectedDate = date
        dismiss()
    }

    private func goToMonth(_ date: Date) {
        HapticManager.selection()
        viewModel.currentMonth = date
        dismiss()
    }
}

// MARK: - Quick Date Button

struct QuickDateButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSizes.iconSmall))

                Text(title)
                    .font(DesignFonts.bodyMedium)
            }
            .foregroundColor(DesignColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(DesignColors.cardBackgroundLight)
            )
        }
    }
}
