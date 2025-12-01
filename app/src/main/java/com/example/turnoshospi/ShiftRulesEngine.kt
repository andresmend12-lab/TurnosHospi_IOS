package com.example.turnoshospi

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit

object ShiftRulesEngine {

    // --- Enum de Dureza y Tipos ---
    enum class Hardness { NIGHT, WEEKEND, HOLIDAY, NORMAL }
    enum class ShiftType { MORNING, AFTERNOON, NIGHT, OFF }

    // --- Modelos Auxiliares para el Engine ---
    // Representa una deuda: "debtor" le debe a "creditor" X turnos de tipo "hardness"
    data class DebtEntry(val debtorId: String, val creditorId: String, val hardness: Hardness, val amount: Int)

    // --- REGLA 0: Cálculo de Dureza ---
    fun calculateShiftHardness(date: LocalDate, shiftName: String): Hardness {
        val name = shiftName.trim().lowercase()
        if (name.contains("noche")) return Hardness.NIGHT

        // Aquí podrías inyectar un calendario de festivos real
        val dayOfWeek = date.dayOfWeek
        if (dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY) return Hardness.WEEKEND

        // Si tuvieras lista de festivos: if (isHoliday(date)) return Hardness.HOLIDAY

        return Hardness.NORMAL
    }

    private fun getShiftType(shiftName: String): ShiftType {
        val name = shiftName.lowercase()
        return when {
            name.contains("noche") -> ShiftType.NIGHT
            name.contains("mañana") -> ShiftType.MORNING
            name.contains("tarde") -> ShiftType.AFTERNOON
            else -> ShiftType.OFF
        }
    }

    // --- REGLA 1: Roles ---
    fun canUserParticipate(userRole: String): Boolean {
        val normalized = userRole.trim().lowercase()
        return !normalized.contains("supervisor") &&
                (normalized.contains("enfermer") || normalized.contains("auxiliar"))
    }

    fun areRolesCompatible(roleA: String, roleB: String): Boolean {
        val rA = roleA.trim().lowercase()
        val rB = roleB.trim().lowercase()
        return (rA.contains("enfermer") && rB.contains("enfermer")) ||
                (rA.contains("auxiliar") && rB.contains("auxiliar"))
    }

    // --- REGLA 2: Validación Laboral (Salientes, Doble turno, Racha) ---
    // Devuelve NULL si es válido, o un String con el error
    fun validateWorkRules(
        targetDate: LocalDate,
        targetShiftName: String,
        userSchedule: Map<LocalDate, String> // Mapa Fecha -> NombreTurno
    ): String? {
        val targetType = getShiftType(targetShiftName)

        // 1. Ya tiene turno ese día
        if (userSchedule.containsKey(targetDate)) {
            return "Ya tienes un turno asignado el $targetDate."
        }

        // 2. Regla de Saliente (Noches)
        val yesterday = targetDate.minusDays(1)
        val tomorrow = targetDate.plusDays(1)
        val shiftYesterday = userSchedule[yesterday]?.let { getShiftType(it) } ?: ShiftType.OFF
        val shiftTomorrow = userSchedule[tomorrow]?.let { getShiftType(it) } ?: ShiftType.OFF

        // Ayer fue noche -> Hoy es SALIENTE (Descanso obligatorio)
        if (shiftYesterday == ShiftType.NIGHT) {
            return "Vienes de una noche (Saliente). Debes descansar."
        }
        // Hoy es noche -> Mañana es SALIENTE
        if (targetType == ShiftType.NIGHT && shiftTomorrow != ShiftType.OFF) {
            return "Si trabajas noche, mañana debes librar."
        }

        // 3. Regla de los 6 días (Max 6 seguidos)
        // Simulamos que añadimos el turno para verificar la racha resultante
        val simulatedSchedule = userSchedule.toMutableMap()
        simulatedSchedule[targetDate] = targetShiftName

        if (calculateConsecutiveDays(targetDate, simulatedSchedule) > 6) {
            return "Superarías el límite de 6 días seguidos de trabajo."
        }

        return null
    }

    private fun calculateConsecutiveDays(pivotDate: LocalDate, schedule: Map<LocalDate, String>): Int {
        var count = 1 // El día pivote cuenta

        // Hacia atrás
        var current = pivotDate.minusDays(1)
        while (schedule.containsKey(current)) {
            count++
            current = current.minusDays(1)
        }

        // Hacia adelante
        current = pivotDate.plusDays(1)
        while (schedule.containsKey(current)) {
            count++
            current = current.plusDays(1)
        }

        return count
    }

    // --- REGLA 3: Matching (Algoritmo Principal) ---
    // Verifica si "Candidate" puede hacer swap con "Requester"
    fun checkMatch(
        requesterRequest: ShiftChangeRequest, // La solicitud original (A quiere soltar X)
        candidateRequest: ShiftChangeRequest, // La solicitud del candidato (B quiere soltar Y)
        requesterSchedule: Map<LocalDate, String>,
        candidateSchedule: Map<LocalDate, String>
    ): Boolean {
        // A. Filtro de Rol
        if (!areRolesCompatible(requesterRequest.requesterRole, candidateRequest.requesterRole)) return false

        // B. Verificación de Intención (Wildcard / Comodín)
        // Si offeredDates está vacía, significa que el usuario acepta CUALQUIER fecha.
        val requesterWantsB = requesterRequest.offeredDates.isEmpty() ||
                requesterRequest.offeredDates.contains(candidateRequest.requesterShiftDate)

        val candidateWantsA = candidateRequest.offeredDates.isEmpty() ||
                candidateRequest.offeredDates.contains(requesterRequest.requesterShiftDate)

        if (!requesterWantsB || !candidateWantsA) return false

        // C. Validación Laboral Cruzada (Swap Puro)
        val dateA = LocalDate.parse(requesterRequest.requesterShiftDate)
        val dateB = LocalDate.parse(candidateRequest.requesterShiftDate)

        // Validar si Requester puede trabajar en FechaB (turno de Candidate)
        val errorForRequester = validateWorkRules(dateB, candidateRequest.requesterShiftName, requesterSchedule)
        // Validar si Candidate puede trabajar en FechaA (turno de Requester)
        val errorForCandidate = validateWorkRules(dateA, requesterRequest.requesterShiftName, candidateSchedule)

        return errorForRequester == null && errorForCandidate == null
    }
}