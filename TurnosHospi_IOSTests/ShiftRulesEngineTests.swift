//
//  ShiftRulesEngineTests.swift
//  TurnosHospi_IOSTests
//
//  Comprehensive tests for ShiftRulesEngine business logic
//

import XCTest
@testable import TurnosHospi_IOS

final class ShiftRulesEngineTests: XCTestCase {

    // MARK: - Helper Properties

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }

    private func date(from string: String) -> Date {
        return dateFormatter.date(from: string)!
    }

    // MARK: - RULE 0: Hardness Calculation Tests

    func testCalculateShiftHardness_NightShift_ReturnsNight() {
        // Given
        let date = date(from: "2024-12-16") // Monday
        let shiftName = "Noche"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .night, "Night shift should return .night hardness")
    }

    func testCalculateShiftHardness_NightShiftWithSpaces_ReturnsNight() {
        // Given
        let date = date(from: "2024-12-16")
        let shiftName = "  Turno Noche  "

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .night, "Night shift with spaces should still return .night")
    }

    func testCalculateShiftHardness_NightShiftLowercase_ReturnsNight() {
        // Given
        let date = date(from: "2024-12-16")
        let shiftName = "noche larga"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .night, "Lowercase night shift should return .night")
    }

    func testCalculateShiftHardness_SaturdayMorning_ReturnsWeekend() {
        // Given - Saturday, December 14, 2024
        let date = date(from: "2024-12-14")
        let shiftName = "Mañana"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .weekend, "Saturday morning shift should return .weekend")
    }

    func testCalculateShiftHardness_SundayAfternoon_ReturnsWeekend() {
        // Given - Sunday, December 15, 2024
        let date = date(from: "2024-12-15")
        let shiftName = "Tarde"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .weekend, "Sunday afternoon shift should return .weekend")
    }

    func testCalculateShiftHardness_WeekdayMorning_ReturnsNormal() {
        // Given - Wednesday, December 18, 2024
        let date = date(from: "2024-12-18")
        let shiftName = "Mañana"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .normal, "Weekday morning shift should return .normal")
    }

    func testCalculateShiftHardness_WeekdayAfternoon_ReturnsNormal() {
        // Given - Thursday, December 19, 2024
        let date = date(from: "2024-12-19")
        let shiftName = "Tarde"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .normal, "Weekday afternoon shift should return .normal")
    }

    func testCalculateShiftHardness_NightOnWeekend_ReturnsNight() {
        // Given - Saturday night (night takes precedence over weekend)
        let date = date(from: "2024-12-14")
        let shiftName = "Noche"

        // When
        let hardness = ShiftRulesEngine.calculateShiftHardness(date: date, shiftName: shiftName)

        // Then
        XCTAssertEqual(hardness, .night, "Night shift on weekend should return .night (night takes precedence)")
    }

    // MARK: - RULE 1: Role Participation Tests

    func testCanUserParticipate_Supervisor_ReturnsFalse() {
        // Given
        let role = "Supervisor"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertFalse(canParticipate, "Supervisors should NOT be able to participate in swaps")
    }

    func testCanUserParticipate_SupervisorWithSpaces_ReturnsFalse() {
        // Given
        let role = "  Supervisor de Planta  "

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertFalse(canParticipate, "Supervisor with extra text should NOT participate")
    }

    func testCanUserParticipate_Enfermero_ReturnsTrue() {
        // Given
        let role = "Enfermero"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertTrue(canParticipate, "Enfermero should be able to participate")
    }

    func testCanUserParticipate_Enfermera_ReturnsTrue() {
        // Given
        let role = "Enfermera"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertTrue(canParticipate, "Enfermera should be able to participate")
    }

    func testCanUserParticipate_Auxiliar_ReturnsTrue() {
        // Given
        let role = "Auxiliar"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertTrue(canParticipate, "Auxiliar should be able to participate")
    }

    func testCanUserParticipate_TCAE_ReturnsTrue() {
        // Given
        let role = "TCAE"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertTrue(canParticipate, "TCAE should be able to participate")
    }

    func testCanUserParticipate_AuxiliarEnfermeria_ReturnsTrue() {
        // Given
        let role = "Auxiliar de Enfermería"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertTrue(canParticipate, "Auxiliar de Enfermería should be able to participate")
    }

    func testCanUserParticipate_UnknownRole_ReturnsFalse() {
        // Given
        let role = "Médico"

        // When
        let canParticipate = ShiftRulesEngine.canUserParticipate(userRole: role)

        // Then
        XCTAssertFalse(canParticipate, "Unknown roles should NOT be able to participate")
    }

    // MARK: - RULE 1: Role Compatibility Tests

    func testAreRolesCompatible_NurseToNurse_ReturnsTrue() {
        // Given
        let roleA = "Enfermero"
        let roleB = "Enfermera"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertTrue(compatible, "Nurses should be compatible with each other")
    }

    func testAreRolesCompatible_AuxiliarToAuxiliar_ReturnsTrue() {
        // Given
        let roleA = "Auxiliar"
        let roleB = "Auxiliar de Enfermería"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertTrue(compatible, "Auxiliars should be compatible with each other")
    }

    func testAreRolesCompatible_TCAEToAuxiliar_ReturnsTrue() {
        // Given
        let roleA = "TCAE"
        let roleB = "Auxiliar"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertTrue(compatible, "TCAE should be compatible with Auxiliar")
    }

    func testAreRolesCompatible_TCAEToTCAE_ReturnsTrue() {
        // Given
        let roleA = "TCAE"
        let roleB = "TCAE"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertTrue(compatible, "TCAE should be compatible with TCAE")
    }

    func testAreRolesCompatible_NurseToAuxiliar_ReturnsFalse() {
        // Given
        let roleA = "Enfermero"
        let roleB = "Auxiliar"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertFalse(compatible, "Nurse should NOT be compatible with Auxiliar")
    }

    func testAreRolesCompatible_NurseToTCAE_ReturnsFalse() {
        // Given
        let roleA = "Enfermera"
        let roleB = "TCAE"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertFalse(compatible, "Nurse should NOT be compatible with TCAE")
    }

    func testAreRolesCompatible_WithExtraSpaces_StillWorks() {
        // Given
        let roleA = "  Enfermero  "
        let roleB = "Enfermera de Planta"

        // When
        let compatible = ShiftRulesEngine.areRolesCompatible(roleA: roleA, roleB: roleB)

        // Then
        XCTAssertTrue(compatible, "Should handle extra spaces correctly")
    }

    // MARK: - RULE 2: Work Rules Validation Tests

    func testValidateWorkRules_AlreadyHasShift_ReturnsError() {
        // Given
        let targetDate = date(from: "2024-12-16")
        let shiftName = "Mañana"
        let schedule = ["2024-12-16": "Tarde"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Should return error when already has shift")
        XCTAssertTrue(error!.contains("Ya tienes un turno"), "Error should mention existing shift")
    }

    func testValidateWorkRules_NightShiftYesterday_ReturnsError() {
        // Given - Coming from a night shift (Saliente)
        let targetDate = date(from: "2024-12-17")
        let shiftName = "Mañana"
        let schedule = ["2024-12-16": "Noche"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Should return error after night shift")
        XCTAssertTrue(error!.contains("Saliente") || error!.contains("noche"), "Error should mention rest after night")
    }

    func testValidateWorkRules_NightShiftWithWorkTomorrow_ReturnsError() {
        // Given - Night shift today but already has work tomorrow
        let targetDate = date(from: "2024-12-16")
        let shiftName = "Noche"
        let schedule = ["2024-12-17": "Mañana"]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Should return error when working tomorrow after night")
        XCTAssertTrue(error!.contains("mañana") || error!.contains("librar"), "Error should mention rest tomorrow")
    }

    func testValidateWorkRules_SixConsecutiveDays_ReturnsNil() {
        // Given - 5 consecutive days, adding 6th should be allowed
        let targetDate = date(from: "2024-12-21")
        let shiftName = "Mañana"
        let schedule = [
            "2024-12-16": "Mañana",
            "2024-12-17": "Tarde",
            "2024-12-18": "Mañana",
            "2024-12-19": "Tarde",
            "2024-12-20": "Mañana"
        ]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNil(error, "6 consecutive days should be allowed")
    }

    func testValidateWorkRules_SevenConsecutiveDays_ReturnsError() {
        // Given - 6 consecutive days, adding 7th should fail
        let targetDate = date(from: "2024-12-22")
        let shiftName = "Mañana"
        let schedule = [
            "2024-12-16": "Mañana",
            "2024-12-17": "Tarde",
            "2024-12-18": "Mañana",
            "2024-12-19": "Tarde",
            "2024-12-20": "Mañana",
            "2024-12-21": "Tarde"
        ]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "7 consecutive days should NOT be allowed")
        XCTAssertTrue(error!.contains("6 días"), "Error should mention 6-day limit")
    }

    func testValidateWorkRules_ConsecutiveDaysInMiddle_ReturnsError() {
        // Given - Adding a day in the middle that creates 7 consecutive
        let targetDate = date(from: "2024-12-19")
        let shiftName = "Mañana"
        let schedule = [
            "2024-12-16": "Mañana",
            "2024-12-17": "Tarde",
            "2024-12-18": "Mañana",
            // Gap on 19
            "2024-12-20": "Mañana",
            "2024-12-21": "Tarde",
            "2024-12-22": "Mañana"
        ]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNotNil(error, "Filling gap that creates 7 days should fail")
    }

    func testValidateWorkRules_ValidShift_ReturnsNil() {
        // Given - Normal valid shift
        let targetDate = date(from: "2024-12-18")
        let shiftName = "Tarde"
        let schedule = [
            "2024-12-16": "Mañana",
            "2024-12-20": "Tarde"
        ]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNil(error, "Valid shift should return nil")
    }

    func testValidateWorkRules_EmptySchedule_ReturnsNil() {
        // Given - Empty schedule
        let targetDate = date(from: "2024-12-18")
        let shiftName = "Mañana"
        let schedule: [String: String] = [:]

        // When
        let error = ShiftRulesEngine.validateWorkRules(
            targetDate: targetDate,
            targetShiftName: shiftName,
            userSchedule: schedule
        )

        // Then
        XCTAssertNil(error, "Empty schedule should allow any shift")
    }

    // MARK: - RULE 3: Match Checking Tests

    func testCheckMatch_CompatibleRolesAndDates_ReturnsTrue() {
        // Given - Two nurses want to swap shifts
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        let requesterSchedule = ["2024-12-16": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertTrue(isMatch, "Compatible roles with flexible mode should match")
    }

    func testCheckMatch_IncompatibleRoles_ReturnsFalse() {
        // Given - Nurse and Auxiliar try to swap
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Pedro",
            requesterRole: "Auxiliar",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        let requesterSchedule = ["2024-12-16": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertFalse(isMatch, "Incompatible roles should NOT match")
    }

    func testCheckMatch_StrictModeWithMatchingDates_ReturnsTrue() {
        // Given - Strict mode with matching offered dates
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .strict,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: ["2024-12-18", "2024-12-19"]
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .strict,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: ["2024-12-16", "2024-12-17"]
        )

        let requesterSchedule = ["2024-12-16": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertTrue(isMatch, "Strict mode with matching dates should match")
    }

    func testCheckMatch_StrictModeWithNonMatchingDates_ReturnsFalse() {
        // Given - Strict mode without matching offered dates
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .strict,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: ["2024-12-20", "2024-12-21"] // Does NOT include 2024-12-18
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .strict,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: ["2024-12-16"]
        )

        let requesterSchedule = ["2024-12-16": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertFalse(isMatch, "Strict mode without matching dates should NOT match")
    }

    func testCheckMatch_WorkRulesViolation_RequesterCannotWork_ReturnsFalse() {
        // Given - Requester would violate work rules (night yesterday)
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        // Requester has night shift on 2024-12-17, so cannot work on 2024-12-18
        let requesterSchedule = [
            "2024-12-16": "Mañana",
            "2024-12-17": "Noche"
        ]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertFalse(isMatch, "Should NOT match when requester violates work rules")
    }

    func testCheckMatch_WorkRulesViolation_CandidateCannotWork_ReturnsFalse() {
        // Given - Candidate would violate work rules
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-20",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        let requesterSchedule = ["2024-12-18": "Mañana"]
        // Candidate has night shift on 2024-12-17, so cannot work on 2024-12-18
        let candidateSchedule = [
            "2024-12-17": "Noche",
            "2024-12-20": "Tarde"
        ]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertFalse(isMatch, "Should NOT match when candidate violates work rules")
    }

    func testCheckMatch_SameDateSwap_ShouldWork() {
        // Given - Same date, different shift types (morning <-> afternoon)
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        let requesterSchedule = ["2024-12-18": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertTrue(isMatch, "Same date different shifts should be allowed to swap")
    }

    // MARK: - Edge Cases

    func testCheckMatch_InvalidDateFormat_ReturnsFalse() {
        // Given - Invalid date format
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "María",
            requesterRole: "Enfermera",
            requesterShiftDate: "invalid-date",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Juan",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: [:],
            candidateSchedule: [:]
        )

        // Then
        XCTAssertFalse(isMatch, "Invalid date format should not match")
    }

    func testCheckMatch_AuxiliarsCompatible_ReturnsTrue() {
        // Given - Two auxiliars (TCAE and Auxiliar)
        let requesterRequest = ShiftChangeRequest(
            id: "req1",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user1",
            requesterName: "Ana",
            requesterRole: "TCAE",
            requesterShiftDate: "2024-12-16",
            requesterShiftName: "Mañana",
            offeredDates: []
        )

        let candidateRequest = ShiftChangeRequest(
            id: "req2",
            type: .swap,
            status: .searching,
            mode: .flexible,
            requesterId: "user2",
            requesterName: "Pedro",
            requesterRole: "Auxiliar de Enfermería",
            requesterShiftDate: "2024-12-18",
            requesterShiftName: "Tarde",
            offeredDates: []
        )

        let requesterSchedule = ["2024-12-16": "Mañana"]
        let candidateSchedule = ["2024-12-18": "Tarde"]

        // When
        let isMatch = ShiftRulesEngine.checkMatch(
            requesterRequest: requesterRequest,
            candidateRequest: candidateRequest,
            requesterSchedule: requesterSchedule,
            candidateSchedule: candidateSchedule
        )

        // Then
        XCTAssertTrue(isMatch, "TCAE and Auxiliar should be compatible")
    }

    // MARK: - Performance Tests

    func testPerformance_ValidateWorkRules_LargeSchedule() {
        // Given - Large schedule with 365 days
        var schedule: [String: String] = [:]
        let calendar = Calendar.current
        let startDate = date(from: "2024-01-01")

        for i in 0..<365 {
            if i % 3 != 0 { // Skip every 3rd day
                let date = calendar.date(byAdding: .day, value: i, to: startDate)!
                let dateStr = dateFormatter.string(from: date)
                schedule[dateStr] = "Mañana"
            }
        }

        let targetDate = date(from: "2024-12-31")

        // When/Then
        measure {
            _ = ShiftRulesEngine.validateWorkRules(
                targetDate: targetDate,
                targetShiftName: "Tarde",
                userSchedule: schedule
            )
        }
    }

    func testPerformance_CalculateShiftHardness() {
        let testDate = date(from: "2024-12-16")

        measure {
            for _ in 0..<1000 {
                _ = ShiftRulesEngine.calculateShiftHardness(date: testDate, shiftName: "Noche")
            }
        }
    }
}
