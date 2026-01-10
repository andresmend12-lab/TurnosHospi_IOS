import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Servicio de Exportación de Calendario

class CalendarExportService {

    // MARK: - Tipos de exportación

    enum ExportFormat {
        case pdf
        case image
        case csv
        case ics
    }

    // MARK: - Exportar a PDF

    static func exportToPDF(
        month: Date,
        shifts: [String: UserShift],
        notes: [String: [String]],
        stats: OfflineMonthlyStats
    ) -> Data? {
        let pageWidth: CGFloat = 612 // Letter size
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = pdfRenderer.pdfData { context in
            context.beginPage()

            let contentWidth = pageWidth - (margin * 2)
            var yPosition: CGFloat = margin

            // Título
            let title = monthTitle(from: month)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(
                at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: yPosition),
                withAttributes: titleAttributes
            )
            yPosition += titleSize.height + 20

            // Subtítulo con stats
            let subtitle = "Total: \(stats.totalShifts) turnos · \(String(format: "%.1f", stats.totalHours)) horas"
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.gray
            ]
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            subtitle.draw(
                at: CGPoint(x: (pageWidth - subtitleSize.width) / 2, y: yPosition),
                withAttributes: subtitleAttributes
            )
            yPosition += subtitleSize.height + 30

            // Grid del calendario
            let cellWidth = contentWidth / 7
            let cellHeight: CGFloat = 60
            let daysOfWeek = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

            // Header días de la semana
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]

            for (index, day) in daysOfWeek.enumerated() {
                let x = margin + (CGFloat(index) * cellWidth) + (cellWidth - day.size(withAttributes: headerAttributes).width) / 2
                day.draw(at: CGPoint(x: x, y: yPosition), withAttributes: headerAttributes)
            }
            yPosition += 25

            // Días del mes
            let days = daysInMonth(for: month)
            var dayIndex = 0

            let dayAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black
            ]

            let shiftAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]

            while dayIndex < days.count {
                for col in 0..<7 {
                    guard dayIndex < days.count else { break }

                    let cellX = margin + (CGFloat(col) * cellWidth)
                    let cellY = yPosition

                    // Borde de celda
                    let cellRect = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
                    UIColor.lightGray.setStroke()
                    let path = UIBezierPath(rect: cellRect)
                    path.lineWidth = 0.5
                    path.stroke()

                    if let date = days[dayIndex] {
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let dayString = "\(dayNumber)"
                        let dateKey = dateKey(for: date)

                        // Número del día
                        dayString.draw(
                            at: CGPoint(x: cellX + 5, y: cellY + 5),
                            withAttributes: dayAttributes
                        )

                        // Turno si existe
                        if let shift = shifts[dateKey] {
                            let shiftName = shift.shiftName.prefix(8)
                            String(shiftName).draw(
                                at: CGPoint(x: cellX + 5, y: cellY + 25),
                                withAttributes: shiftAttributes
                            )
                        }

                        // Indicador de nota
                        if let noteList = notes[dateKey], !noteList.isEmpty {
                            let noteIndicator = "📝"
                            noteIndicator.draw(
                                at: CGPoint(x: cellX + cellWidth - 20, y: cellY + 5),
                                withAttributes: [:]
                            )
                        }
                    }

                    dayIndex += 1
                }
                yPosition += cellHeight
            }

            // Desglose de turnos
            yPosition += 30

            if !stats.breakdown.isEmpty {
                let breakdownTitle = "Desglose:"
                breakdownTitle.draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                        .foregroundColor: UIColor.black
                    ]
                )
                yPosition += 20

                for (shiftName, data) in stats.breakdown.sorted(by: { $0.value.hours > $1.value.hours }) {
                    let text = "• \(shiftName): \(data.count) turnos, \(String(format: "%.1f", data.hours))h"
                    text.draw(
                        at: CGPoint(x: margin + 10, y: yPosition),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                            .foregroundColor: UIColor.darkGray
                        ]
                    )
                    yPosition += 18
                }
            }
        }

        return data
    }

    // MARK: - Exportar a CSV

    static func exportToCSV(
        month: Date,
        shifts: [String: UserShift],
        notes: [String: [String]]
    ) -> String {
        var csv = "Fecha,Día,Turno,Media Jornada,Notas\n"

        let days = daysInMonth(for: month)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.dateFormat = "dd/MM/yyyy"

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"

        for day in days.compactMap({ $0 }) {
            let key = dateKey(for: day)
            let dateStr = dateFormatter.string(from: day)
            let dayName = dayFormatter.string(from: day).capitalized
            let shift = shifts[key]
            let shiftName = shift?.shiftName ?? "Libre"
            let isHalf = shift?.isHalfDay == true ? "Sí" : "No"
            let notesList = notes[key]?.joined(separator: "; ") ?? ""

            // Escapar campos con comas
            let escapedNotes = notesList.contains(",") ? "\"\(notesList)\"" : notesList

            csv += "\(dateStr),\(dayName),\(shiftName),\(isHalf),\(escapedNotes)\n"
        }

        return csv
    }

    // MARK: - Exportar a iCalendar (.ics)

    static func exportToICS(
        month: Date,
        shifts: [String: UserShift]
    ) -> String {
        var ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//TurnosHospi//Calendario de Turnos//ES
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        X-WR-CALNAME:Mis Turnos

        """

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let days = daysInMonth(for: month)

        for day in days.compactMap({ $0 }) {
            let key = dateKey(for: day)
            guard let shift = shifts[key] else { continue }

            let dateStr = dateFormatter.string(from: day)
            let uid = "\(dateStr)-\(UUID().uuidString)@turnoshospi"
            let summary = shift.isHalfDay ? "\(shift.shiftName) (Media)" : shift.shiftName

            ics += """
            BEGIN:VEVENT
            UID:\(uid)
            DTSTART;VALUE=DATE:\(dateStr)
            DTEND;VALUE=DATE:\(dateStr)
            SUMMARY:\(summary)
            DESCRIPTION:Turno asignado en TurnosHospi
            STATUS:CONFIRMED
            END:VEVENT

            """
        }

        ics += "END:VCALENDAR"

        return ics
    }

    // MARK: - Helpers

    private static func monthTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func daysInMonth(for month: Date) -> [Date?] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.firstWeekday = 2

        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }
}
