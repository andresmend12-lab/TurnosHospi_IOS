//
//  ShiftRulesEngineTests.swift
//  TurnosHospi_IOSTests
//
//  Tests para la lógica de negocio de validación de cambios de turno
//

import XCTest
@testable import TurnosHospi_IOS

final class ShiftRulesEngineTests: XCTestCase {

    // MARK: - Helpers

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Lunes
        cal.locale = Locale(identifier: "es_ES")
        return cal
    }

    private func crearFecha(año: Int, mes: Int, dia: Int) -> Date {
        var components = DateComponents()
        components.year = año
        components.month = mes
        components.day = dia
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func fechaString(_ date: Date) -> String {
        return ShiftRulesEngine.dateFormatter.string(from: date)
    }

    private func crearSolicitud(
        role: String,
        shiftDate: String,
        shiftName: String,
        offeredDates: [String] = []
    ) -> ShiftChangeRequest {
        return ShiftChangeRequest(
            id: UUID().uuidString,
            type: .swap,
            status: .searching,
            mode: offeredDates.isEmpty ? .flexible : .strict,
            hardnessLevel: .normal,
            requesterId: "user_\(UUID().uuidString.prefix(4))",
            requesterName: "Test User",
            requesterRole: role,
            requesterShiftDate: shiftDate,
            requesterShiftName: shiftName,
            offeredDates: offeredDates
        )
    }

    // MARK: - Tests calculateShiftHardness

    func test_turnoNoche_retornaHardnessNight() {
        // Given
        let fechaLunes = crearFecha(año: 2025, mes: 1, dia: 6) // Lunes

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: fechaLunes, shiftName: "Noche")

        // Then
        XCTAssertEqual(resultado, .night, "Un turno de noche debe retornar .night")
    }

    func test_turnoNocheConEspacios_retornaHardnessNight() {
        // Given
        let fecha = crearFecha(año: 2025, mes: 1, dia: 6)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: fecha, shiftName: "  Noche  ")

        // Then
        XCTAssertEqual(resultado, .night, "Un turno de noche con espacios debe retornar .night")
    }

    func test_turnoNocheMayusculas_retornaHardnessNight() {
        // Given
        let fecha = crearFecha(año: 2025, mes: 1, dia: 6)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: fecha, shiftName: "NOCHE")

        // Then
        XCTAssertEqual(resultado, .night, "Un turno NOCHE en mayúsculas debe retornar .night")
    }

    func test_turnoSabado_retornaHardnessWeekend() {
        // Given - Sábado 11 de enero 2025
        let sabado = crearFecha(año: 2025, mes: 1, dia: 11)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: sabado, shiftName: "Mañana")

        // Then
        XCTAssertEqual(resultado, .weekend, "Un turno en sábado debe retornar .weekend")
    }

    func test_turnoDomingo_retornaHardnessWeekend() {
        // Given - Domingo 12 de enero 2025
        let domingo = crearFecha(año: 2025, mes: 1, dia: 12)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: domingo, shiftName: "Tarde")

        // Then
        XCTAssertEqual(resultado, .weekend, "Un turno en domingo debe retornar .weekend")
    }

    func test_turnoNormalDiaLaborable_retornaHardnessNormal() {
        // Given - Miércoles 8 de enero 2025
        let miercoles = crearFecha(año: 2025, mes: 1, dia: 8)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: miercoles, shiftName: "Mañana")

        // Then
        XCTAssertEqual(resultado, .normal, "Un turno normal en día laborable debe retornar .normal")
    }

    func test_turnoNocheEnFinDeSemana_retornaHardnessNight() {
        // Given - Sábado con turno de noche (noche tiene prioridad)
        let sabado = crearFecha(año: 2025, mes: 1, dia: 11)

        // When
        let resultado = ShiftRulesEngine.calculateShiftHardness(date: sabado, shiftName: "Noche")

        // Then
        XCTAssertEqual(resultado, .night, "Un turno de noche tiene prioridad sobre fin de semana")
    }

    // MARK: - Tests canUserParticipate

    func test_supervisor_noPuedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Supervisor")

        // Then
        XCTAssertFalse(resultado, "Un Supervisor NO debe poder participar en intercambios")
    }

    func test_supervisorPlanta_noPuedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Supervisor de Planta")

        // Then
        XCTAssertFalse(resultado, "Un Supervisor de Planta NO debe poder participar")
    }

    func test_enfermero_puedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Enfermero")

        // Then
        XCTAssertTrue(resultado, "Un Enfermero SÍ debe poder participar")
    }

    func test_enfermera_puedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Enfermera")

        // Then
        XCTAssertTrue(resultado, "Una Enfermera SÍ debe poder participar")
    }

    func test_auxiliar_puedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Auxiliar")

        // Then
        XCTAssertTrue(resultado, "Un Auxiliar SÍ debe poder participar")
    }

    func test_tcae_puedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "TCAE")

        // Then
        XCTAssertTrue(resultado, "Un TCAE SÍ debe poder participar")
    }

    func test_auxiliarEnfermeria_puedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Auxiliar de Enfermería")

        // Then
        XCTAssertTrue(resultado, "Un Auxiliar de Enfermería SÍ debe poder participar")
    }

    func test_rolDesconocido_noPuedeParticipar() {
        // When
        let resultado = ShiftRulesEngine.canUserParticipate(userRole: "Médico")

        // Then
        XCTAssertFalse(resultado, "Un rol desconocido NO debe poder participar")
    }

    // MARK: - Tests areRolesCompatible

    func test_enfermeroConEnfermera_sonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Enfermero", roleB: "Enfermera")

        // Then
        XCTAssertTrue(resultado, "Enfermero y Enfermera deben ser compatibles")
    }

    func test_enfermeroConEnfermero_sonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Enfermero", roleB: "Enfermero")

        // Then
        XCTAssertTrue(resultado, "Dos Enfermeros deben ser compatibles")
    }

    func test_auxiliarConTCAE_sonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Auxiliar", roleB: "TCAE")

        // Then
        XCTAssertTrue(resultado, "Auxiliar y TCAE deben ser compatibles")
    }

    func test_tcaeConTCAE_sonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "TCAE", roleB: "TCAE")

        // Then
        XCTAssertTrue(resultado, "Dos TCAE deben ser compatibles")
    }

    func test_enfermeroConAuxiliar_noSonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Enfermero", roleB: "Auxiliar")

        // Then
        XCTAssertFalse(resultado, "Enfermero y Auxiliar NO deben ser compatibles")
    }

    func test_enfermeraConTCAE_noSonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Enfermera", roleB: "TCAE")

        // Then
        XCTAssertFalse(resultado, "Enfermera y TCAE NO deben ser compatibles")
    }

    func test_supervisorConEnfermero_noSonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Supervisor", roleB: "Enfermero")

        // Then
        XCTAssertFalse(resultado, "Supervisor y Enfermero NO deben ser compatibles")
    }

    func test_supervisorConAuxiliar_noSonCompatibles() {
        // When
        let resultado = ShiftRulesEngine.areRolesCompatible(roleA: "Supervisor", roleB: "Auxiliar")

        // Then
        XCTAssertFalse(resultado, "Supervisor y Auxiliar NO deben ser compatibles")
    }

    // MARK: - Tests validateWorkRules

    func test_usuarioYaTieneTurnoEseDia_retornaError() {
        // Given
        let fecha = crearFecha(año: 2025, mes: 1, dia: 10)
        let fechaStr = fechaString(fecha)
        let schedule = [fechaStr: "Mañana"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: fecha,
            targetShiftName: "Tarde",
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Debe retornar error si ya tiene turno ese día")
        XCTAssertTrue(error!.contains("Ya tienes un turno"), "El mensaje debe indicar turno existente")
    }

    func test_diaPostNoche_retornaErrorSaliente() {
        // Given - Ayer trabajó noche, hoy debe descansar
        let ayer = crearFecha(año: 2025, mes: 1, dia: 9)
        let hoy = crearFecha(año: 2025, mes: 1, dia: 10)
        let ayerStr = fechaString(ayer)
        let schedule = [ayerStr: "Noche"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: hoy,
            targetShiftName: "Mañana",
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Debe retornar error por saliente de noche")
        XCTAssertTrue(error!.contains("Saliente") || error!.contains("noche"),
                      "El mensaje debe mencionar la regla de saliente")
    }

    func test_nocheConTurnoManana_retornaError() {
        // Given - Si trabaja noche hoy, mañana debe librar
        let hoy = crearFecha(año: 2025, mes: 1, dia: 10)
        let manana = crearFecha(año: 2025, mes: 1, dia: 11)
        let mananaStr = fechaString(manana)
        let schedule = [mananaStr: "Mañana"] // Ya tiene turno mañana

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: hoy,
            targetShiftName: "Noche",
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Debe retornar error si trabaja noche y tiene turno al día siguiente")
        XCTAssertTrue(error!.contains("noche") && error!.contains("librar"),
                      "El mensaje debe indicar que tras noche debe librar")
    }

    func test_masDe6DiasConsecutivos_retornaError() {
        // Given - 6 días seguidos trabajados, el 7º debe dar error
        let diaBase = crearFecha(año: 2025, mes: 1, dia: 10)
        var schedule: [String: String] = [:]

        // Crear 6 días consecutivos (del 4 al 9)
        for i in -6 ... -1 {
            let fecha = calendar.date(byAdding: .day, value: i, to: diaBase)!
            schedule[fechaString(fecha)] = "Mañana"
        }

        // When - Intentar añadir día 10 (sería el 7º consecutivo)
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: diaBase,
            targetShiftName: "Mañana",
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Debe retornar error si supera 6 días consecutivos")
        XCTAssertTrue(error!.contains("6 días"), "El mensaje debe mencionar el límite de 6 días")
    }

    func test_turnoValidoSinConflictos_retornaNil() {
        // Given - Horario sin conflictos
        let fecha = crearFecha(año: 2025, mes: 1, dia: 10)
        let otroDia = crearFecha(año: 2025, mes: 1, dia: 5)
        let schedule = [fechaString(otroDia): "Mañana"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: fecha,
            targetShiftName: "Tarde",
            userSchedule: schedule
        )

        // Then
        XCTAssertNil(error, "No debe retornar error si el turno es válido")
    }

    func test_5DiasConsecutivos_esValido() {
        // Given - 5 días seguidos (dentro del límite)
        let diaBase = crearFecha(año: 2025, mes: 1, dia: 10)
        var schedule: [String: String] = [:]

        // Crear 5 días consecutivos (del 5 al 9)
        for i in -5 ... -1 {
            let fecha = calendar.date(byAdding: .day, value: i, to: diaBase)!
            schedule[fechaString(fecha)] = "Mañana"
        }

        // When - Añadir día 10 (sería el 6º, dentro del límite)
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: diaBase,
            targetShiftName: "Mañana",
            userSchedule: schedule
        )

        // Then
        XCTAssertNil(error, "6 días consecutivos está dentro del límite")
    }

    // MARK: - Tests checkMatch

    func test_rolesIncompatibles_retornaFalse() {
        // Given
        let fechaA = "2025-01-10"
        let fechaB = "2025-01-11"

        let solicitudEnfermero = crearSolicitud(
            role: "Enfermero",
            shiftDate: fechaA,
            shiftName: "Mañana",
            offeredDates: [fechaB]
        )

        let solicitudAuxiliar = crearSolicitud(
            role: "Auxiliar",
            shiftDate: fechaB,
            shiftName: "Tarde",
            offeredDates: [fechaA]
        )

        // When
        let resultado = ShiftRulesEngine.checkMatch(
            requesterRequest: solicitudEnfermero,
            candidateRequest: solicitudAuxiliar,
            requesterSchedule: [fechaA: "Mañana"],
            candidateSchedule: [fechaB: "Tarde"]
        )

        // Then
        XCTAssertFalse(resultado, "Roles incompatibles deben retornar false")
    }

    func test_matchValidoEntreEnfermeros_retornaTrue() {
        // Given
        let fechaA = "2025-01-10"
        let fechaB = "2025-01-15"

        let solicitudA = crearSolicitud(
            role: "Enfermero",
            shiftDate: fechaA,
            shiftName: "Mañana",
            offeredDates: [] // Flexible
        )

        let solicitudB = crearSolicitud(
            role: "Enfermera",
            shiftDate: fechaB,
            shiftName: "Tarde",
            offeredDates: [] // Flexible
        )

        // When
        let resultado = ShiftRulesEngine.checkMatch(
            requesterRequest: solicitudA,
            candidateRequest: solicitudB,
            requesterSchedule: [fechaA: "Mañana"],
            candidateSchedule: [fechaB: "Tarde"]
        )

        // Then
        XCTAssertTrue(resultado, "Match válido entre enfermeros debe retornar true")
    }

    func test_matchValidoEntreAuxiliares_retornaTrue() {
        // Given
        let fechaA = "2025-01-10"
        let fechaB = "2025-01-15"

        let solicitudA = crearSolicitud(
            role: "Auxiliar",
            shiftDate: fechaA,
            shiftName: "Mañana"
        )

        let solicitudB = crearSolicitud(
            role: "TCAE",
            shiftDate: fechaB,
            shiftName: "Tarde"
        )

        // When
        let resultado = ShiftRulesEngine.checkMatch(
            requesterRequest: solicitudA,
            candidateRequest: solicitudB,
            requesterSchedule: [fechaA: "Mañana"],
            candidateSchedule: [fechaB: "Tarde"]
        )

        // Then
        XCTAssertTrue(resultado, "Match válido entre Auxiliar y TCAE debe retornar true")
    }

    func test_matchConFechasNoDeseadas_retornaFalse() {
        // Given - A quiere específicamente día 15, B ofrece día 20
        let fechaA = "2025-01-10"
        let fechaB = "2025-01-20"

        let solicitudA = crearSolicitud(
            role: "Enfermero",
            shiftDate: fechaA,
            shiftName: "Mañana",
            offeredDates: ["2025-01-15"] // Solo quiere día 15
        )

        let solicitudB = crearSolicitud(
            role: "Enfermera",
            shiftDate: fechaB,
            shiftName: "Tarde",
            offeredDates: [fechaA]
        )

        // When
        let resultado = ShiftRulesEngine.checkMatch(
            requesterRequest: solicitudA,
            candidateRequest: solicitudB,
            requesterSchedule: [fechaA: "Mañana"],
            candidateSchedule: [fechaB: "Tarde"]
        )

        // Then
        XCTAssertFalse(resultado, "Match debe fallar si las fechas deseadas no coinciden")
    }

    func test_matchConViolacionReglasLaborales_retornaFalse() {
        // Given - B viene de noche, no puede trabajar al día siguiente
        let fechaA = "2025-01-10"
        let fechaB = "2025-01-11"
        let diaAnteriorB = "2025-01-10"

        let solicitudA = crearSolicitud(
            role: "Enfermero",
            shiftDate: fechaA,
            shiftName: "Mañana"
        )

        let solicitudB = crearSolicitud(
            role: "Enfermera",
            shiftDate: fechaB,
            shiftName: "Tarde"
        )

        // B tiene noche el día anterior a fechaA
        let scheduleB = [
            fechaB: "Tarde",
            "2025-01-09": "Noche" // Noche antes del día que recibiría de A
        ]

        // When
        let resultado = ShiftRulesEngine.checkMatch(
            requesterRequest: solicitudA,
            candidateRequest: solicitudB,
            requesterSchedule: [fechaA: "Mañana"],
            candidateSchedule: scheduleB
        )

        // Then
        XCTAssertFalse(resultado, "Match debe fallar si viola reglas laborales (saliente)")
    }
}
