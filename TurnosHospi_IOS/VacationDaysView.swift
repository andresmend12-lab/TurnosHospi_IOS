import SwiftUI

struct VacationDaysView: View {
    let plantId: String
    
    @EnvironmentObject var vacationManager: VacationManager
    
    @State private var currentMonth: Date = Date()
    
    private let weekSymbols = ["L", "M", "X", "J", "V", "S", "D"]
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateStyle = .full
        return f
    }()
    
    var body: some View {
        VStack(spacing: 20) {
            if plantId.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("Debes unirte a una planta para registrar tus vacaciones.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .padding()
            } else {
                instructionsSection
                calendarSection
                vacationsList
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
        .onAppear {
            resetCurrentMonth()
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selecciona tus días de vacaciones")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Toca los días en el calendario para activarlos o desactivarlos. Los días marcados aparecerán en tu calendario principal como \"Vacaciones\" y no podrás solicitar cambios de turno en ellos.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var calendarSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 16) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.blue)
            }
            
            HStack {
                ForEach(weekSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                
                ForEach(daysInMonth, id: \.self) { day in
                    let date = dateFor(day: day)
                    let isVacation = vacationManager.isVacation(date)
                    
                    Button {
                        vacationManager.toggleVacation(for: date)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(day)")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundColor(isVacation ? .white : .white)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isVacation ? Color.red.opacity(0.8) : Color.white.opacity(0.08))
                                )
                            if isVacation {
                                Text("VAC")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red.opacity(0.9))
                            } else {
                                Color.clear.frame(height: 10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var vacationsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Días marcados")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if vacationManager.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            
            if let error = vacationManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
            
            let sortedDays = vacationManager.vacationDays.sorted()
            
            if sortedDays.isEmpty {
                Text("Aún no has seleccionado vacaciones.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ForEach(sortedDays, id: \.self) { date in
                    HStack {
                        Text(dateFormatter.string(from: date).capitalized)
                            .foregroundColor(.white)
                        Spacer()
                        Button(role: .destructive) {
                            vacationManager.toggleVacation(for: date)
                        } label: {
                            Text("Quitar")
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(20)
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }
        return Array(range)
    }
    
    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday + 5) % 7
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func resetCurrentMonth() {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        if let first = calendar.date(from: comps) {
            currentMonth = first
        }
    }
    
    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? currentMonth
    }
}
