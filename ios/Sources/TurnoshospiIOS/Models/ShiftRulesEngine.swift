import Foundation

enum ShiftRulesEngine {
    enum Hardness { case night, weekend, holiday, normal }
    enum ShiftType { case morning, afternoon, night, off }

    struct DebtEntry { let debtorId: String; let creditorId: String; let hardness: Hardness; let amount: Int }

    static func calculateShiftHardness(date: Date, shiftName: String) -> Hardness {
        let lower = shiftName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if lower.contains("noche") { return .night }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return .weekend }
        return .normal
    }

    private static func shiftType(for name: String) -> ShiftType {
        let lower = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if lower.contains("noche") { return .night }
        if lower.contains("mañana") || lower.contains("manana") { return .morning }
        if lower.contains("tarde") { return .afternoon }
        return .off
    }

    static func canUserParticipate(userRole: String) -> Bool {
        let normalized = userRole.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return !normalized.contains("supervisor") && (normalized.contains("enfermer") || normalized.contains("auxiliar"))
    }

    static func areRolesCompatible(roleA: String, roleB: String) -> Bool {
        let rA = roleA.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let rB = roleB.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return (rA.contains("enfermer") && rB.contains("enfermer")) || (rA.contains("auxiliar") && rB.contains("auxiliar"))
    }

    static func validateWorkRules(targetDate: Date, targetShiftName: String, userSchedule: [Date: String]) -> String? {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: targetDate)
        let targetType = shiftType(for: targetShiftName)

        if userSchedule.keys.contains(where: { calendar.isDate($0, inSameDayAs: normalizedDate) }) {
            return "Ya tienes un turno asignado el \(formatted(normalizedDate))."
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: normalizedDate)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedDate)!

        let shiftYesterday = userSchedule.first { calendar.isDate($0.key, inSameDayAs: yesterday) }
            .map { shiftType(for: $0.value) } ?? .off
        let shiftTomorrow = userSchedule.first { calendar.isDate($0.key, inSameDayAs: tomorrow) }
            .map { shiftType(for: $0.value) } ?? .off

        if shiftYesterday == .night {
            return "Vienes de una noche (Saliente). Debes descansar."
        }
        if targetType == .night && shiftTomorrow != .off {
            return "Si trabajas noche, mañana debes librar."
        }

        var simulated = userSchedule
        simulated[normalizedDate] = targetShiftName
        if calculateConsecutiveDays(pivotDate: normalizedDate, schedule: simulated) > 6 {
            return "Superarías el límite de 6 días seguidos de trabajo."
        }

        return nil
    }

    private static func calculateConsecutiveDays(pivotDate: Date, schedule: [Date: String]) -> Int {
        let calendar = Calendar.current
        var count = 1
        var current = calendar.date(byAdding: .day, value: -1, to: pivotDate)!
        while schedule.keys.contains(where: { calendar.isDate($0, inSameDayAs: current) }) {
            count += 1
            current = calendar.date(byAdding: .day, value: -1, to: current)!
        }
        current = calendar.date(byAdding: .day, value: 1, to: pivotDate)!
        while schedule.keys.contains(where: { calendar.isDate($0, inSameDayAs: current) }) {
            count += 1
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return count
    }

    static func checkMatch(requesterRequest: ShiftChangeRequest, candidateRequest: ShiftChangeRequest, requesterSchedule: [Date: String], candidateSchedule: [Date: String]) -> Bool {
        if !areRolesCompatible(roleA: requesterRequest.requesterRole, roleB: candidateRequest.requesterRole) { return false }

        let requesterWantsB = requesterRequest.offeredDates.isEmpty || requesterRequest.offeredDates.contains(candidateRequest.requesterShiftDate)
        let candidateWantsA = candidateRequest.offeredDates.isEmpty || candidateRequest.offeredDates.contains(requesterRequest.requesterShiftDate)
        if !requesterWantsB || !candidateWantsA { return false }

        if let requesterError = validateWorkRules(targetDate: candidateRequest.requesterShiftDate, targetShiftName: candidateRequest.requesterShiftName, userSchedule: requesterSchedule) { return false }
        if let candidateError = validateWorkRules(targetDate: requesterRequest.requesterShiftDate, targetShiftName: requesterRequest.requesterShiftName, userSchedule: candidateSchedule) { return false }
        return true
    }

    static func buildSchedule(from shifts: [Shift]) -> [Date: String] {
        let calendar = Calendar.current
        return Dictionary(uniqueKeysWithValues: shifts.map { (calendar.startOfDay(for: $0.date), $0.name) })
    }

    private static func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
