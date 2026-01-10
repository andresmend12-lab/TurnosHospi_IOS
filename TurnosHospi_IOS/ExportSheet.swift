import SwiftUI

// MARK: - Sheet de Exportación

struct ExportSheet: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportedFileURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case ics = "Calendario (.ics)"

        var icon: String {
            switch self {
            case .pdf: return "doc.fill"
            case .csv: return "tablecells"
            case .ics: return "calendar.badge.plus"
            }
        }

        var description: String {
            switch self {
            case .pdf: return "Documento visual con calendario completo"
            case .csv: return "Hoja de cálculo para Excel/Numbers"
            case .ics: return "Importar a Apple Calendar, Google, etc."
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSpacing.xl) {
                // Selector de formato
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    Text("Formato de exportación")
                        .font(DesignFonts.headline)
                        .foregroundColor(DesignColors.textPrimary)

                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        ExportFormatRow(
                            format: format,
                            isSelected: selectedFormat == format
                        ) {
                            selectedFormat = format
                            HapticManager.selection()
                        }
                    }
                }

                // Info del mes
                VStack(spacing: DesignSpacing.sm) {
                    Text("Se exportará:")
                        .font(DesignFonts.bodyMedium)
                        .foregroundColor(DesignColors.textSecondary)

                    Text(monthTitle)
                        .font(DesignFonts.headline)
                        .foregroundColor(DesignColors.textPrimary)

                    let stats = viewModel.calculateStats(for: viewModel.currentMonth)
                    Text("\(stats.totalShifts) turnos · \(String(format: "%.0f", stats.totalHours)) horas")
                        .font(DesignFonts.body)
                        .foregroundColor(DesignColors.textTertiary)
                }
                .padding(DesignSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                        .fill(DesignColors.cardBackgroundLight)
                )

                Spacer()

                // Botón de exportar
                Button {
                    exportCalendar()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "Exportando..." : "Exportar y Compartir")
                    }
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                            .fill(DesignColors.accent)
                    )
                }
                .disabled(isExporting)
            }
            .padding(DesignSpacing.xl)
            .background(DesignColors.cardBackground.ignoresSafeArea())
            .navigationTitle("Exportar Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: viewModel.currentMonth).capitalized
    }

    private func exportCalendar() {
        isExporting = true
        HapticManager.impact()

        DispatchQueue.global(qos: .userInitiated).async {
            let stats = viewModel.calculateStats(for: viewModel.currentMonth)
            var fileURL: URL?

            switch selectedFormat {
            case .pdf:
                if let data = CalendarExportService.exportToPDF(
                    month: viewModel.currentMonth,
                    shifts: viewModel.localShifts,
                    notes: viewModel.localNotes,
                    stats: stats
                ) {
                    let fileName = "Turnos_\(monthFileName).pdf"
                    fileURL = saveToTempFile(data: data, fileName: fileName)
                }

            case .csv:
                let csv = CalendarExportService.exportToCSV(
                    month: viewModel.currentMonth,
                    shifts: viewModel.localShifts,
                    notes: viewModel.localNotes
                )
                let fileName = "Turnos_\(monthFileName).csv"
                fileURL = saveToTempFile(data: csv.data(using: .utf8)!, fileName: fileName)

            case .ics:
                let ics = CalendarExportService.exportToICS(
                    month: viewModel.currentMonth,
                    shifts: viewModel.localShifts
                )
                let fileName = "Turnos_\(monthFileName).ics"
                fileURL = saveToTempFile(data: ics.data(using: .utf8)!, fileName: fileName)
            }

            DispatchQueue.main.async {
                isExporting = false

                if let url = fileURL {
                    exportedFileURL = url
                    showShareSheet = true
                    HapticManager.success()
                } else {
                    errorMessage = "No se pudo generar el archivo"
                    showError = true
                    HapticManager.warning()
                }
            }
        }
    }

    private var monthFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: viewModel.currentMonth)
    }

    private func saveToTempFile(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
}

// MARK: - Export Format Row

struct ExportFormatRow: View {
    let format: ExportSheet.ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSpacing.md) {
                Image(systemName: format.icon)
                    .font(.system(size: DesignSizes.iconMedium))
                    .foregroundColor(isSelected ? DesignColors.accent : DesignColors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(format.rawValue)
                        .font(DesignFonts.bodyMedium)
                        .foregroundColor(DesignColors.textPrimary)

                    Text(format.description)
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignColors.accent)
                }
            }
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(isSelected ? DesignColors.accent.opacity(0.1) : DesignColors.cardBackgroundLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                            .stroke(isSelected ? DesignColors.accent : Color.clear, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
