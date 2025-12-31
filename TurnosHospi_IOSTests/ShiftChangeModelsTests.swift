//
//  ShiftChangeModelsTests.swift
//  TurnosHospi_IOSTests
//
//  Tests for data models and their Codable conformance
//

import XCTest
@testable import TurnosHospi_IOS

final class ShiftChangeModelsTests: XCTestCase {

    // MARK: - ShiftChangeRequest Tests

    func testShiftChangeRequest_DefaultInitialization() {
        // When
        let request = ShiftChangeRequest()

        // Then
        XCTAssertEqual(request.type, .swap)
        XCTAssertEqual(request.status, .searching)
        XCTAssertEqual(request.mode, .flexible)
        XCTAssertEqual(request.hardnessLevel, .normal)
        XCTAssertTrue(request.offeredDates.isEmpty)
        XCTAssertNil(request.targetUserId)
        XCTAssertNil(request.targetUserName)
        XCTAssertNil(request.targetShiftDate)
        XCTAssertNil(request.targetShiftName)
    }

    func testShiftChangeRequest_CustomInitialization() {
        // Given
        let id = "test-id-123"
        let requesterId = "user-456"
        let requesterName = "María García"
        let requesterRole = "Enfermera"
        let shiftDate = "2024-12-18"
        let shiftName = "Mañana"

        // When
        let request = ShiftChangeRequest(
            id: id,
            type: .coverage,
            status: .pendingPartner,
            mode: .strict,
            hardnessLevel: .night,
            requesterId: requesterId,
            requesterName: requesterName,
            requesterRole: requesterRole,
            requesterShiftDate: shiftDate,
            requesterShiftName: shiftName,
            offeredDates: ["2024-12-20", "2024-12-21"],
            targetUserId: "user-789",
            targetUserName: "Juan Pérez"
        )

        // Then
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.type, .coverage)
        XCTAssertEqual(request.status, .pendingPartner)
        XCTAssertEqual(request.mode, .strict)
        XCTAssertEqual(request.hardnessLevel, .night)
        XCTAssertEqual(request.requesterId, requesterId)
        XCTAssertEqual(request.requesterName, requesterName)
        XCTAssertEqual(request.requesterRole, requesterRole)
        XCTAssertEqual(request.requesterShiftDate, shiftDate)
        XCTAssertEqual(request.requesterShiftName, shiftName)
        XCTAssertEqual(request.offeredDates, ["2024-12-20", "2024-12-21"])
        XCTAssertEqual(request.targetUserId, "user-789")
        XCTAssertEqual(request.targetUserName, "Juan Pérez")
    }

    func testShiftChangeRequest_Identifiable() {
        // Given
        let request1 = ShiftChangeRequest(id: "id-1")
        let request2 = ShiftChangeRequest(id: "id-2")
        let request3 = ShiftChangeRequest(id: "id-1")

        // Then
        XCTAssertEqual(request1.id, "id-1")
        XCTAssertNotEqual(request1.id, request2.id)
        XCTAssertEqual(request1.id, request3.id)
    }

    func testShiftChangeRequest_EncodeDecode() throws {
        // Given
        let originalRequest = ShiftChangeRequest(
            id: "test-encode",
            type: .swap,
            status: .approved,
            mode: .flexible,
            hardnessLevel: .weekend,
            requesterId: "user-1",
            requesterName: "Test User",
            requesterRole: "Enfermero",
            requesterShiftDate: "2024-12-25",
            requesterShiftName: "Tarde",
            offeredDates: ["2024-12-26"],
            targetUserId: "user-2",
            targetUserName: "Target User",
            targetShiftDate: "2024-12-26",
            targetShiftName: "Mañana"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRequest)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(ShiftChangeRequest.self, from: data)

        // Then
        XCTAssertEqual(decodedRequest.id, originalRequest.id)
        XCTAssertEqual(decodedRequest.type, originalRequest.type)
        XCTAssertEqual(decodedRequest.status, originalRequest.status)
        XCTAssertEqual(decodedRequest.mode, originalRequest.mode)
        XCTAssertEqual(decodedRequest.hardnessLevel, originalRequest.hardnessLevel)
        XCTAssertEqual(decodedRequest.requesterId, originalRequest.requesterId)
        XCTAssertEqual(decodedRequest.requesterName, originalRequest.requesterName)
        XCTAssertEqual(decodedRequest.requesterRole, originalRequest.requesterRole)
        XCTAssertEqual(decodedRequest.requesterShiftDate, originalRequest.requesterShiftDate)
        XCTAssertEqual(decodedRequest.requesterShiftName, originalRequest.requesterShiftName)
        XCTAssertEqual(decodedRequest.offeredDates, originalRequest.offeredDates)
        XCTAssertEqual(decodedRequest.targetUserId, originalRequest.targetUserId)
        XCTAssertEqual(decodedRequest.targetUserName, originalRequest.targetUserName)
    }

    // MARK: - RequestType Tests

    func testRequestType_RawValues() {
        XCTAssertEqual(RequestType.coverage.rawValue, "COVERAGE")
        XCTAssertEqual(RequestType.swap.rawValue, "SWAP")
    }

    func testRequestType_Codable() throws {
        // Given
        let types: [RequestType] = [.coverage, .swap]

        for type in types {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(type)

            let decoder = JSONDecoder()
            let decodedType = try decoder.decode(RequestType.self, from: data)

            // Then
            XCTAssertEqual(decodedType, type)
        }
    }

    // MARK: - RequestMode Tests

    func testRequestMode_RawValues() {
        XCTAssertEqual(RequestMode.strict.rawValue, "STRICT")
        XCTAssertEqual(RequestMode.flexible.rawValue, "FLEXIBLE")
    }

    // MARK: - RequestStatus Tests

    func testRequestStatus_AllCases() {
        let allCases: [RequestStatus] = [
            .draft,
            .searching,
            .pendingPartner,
            .awaitingSupervisor,
            .approved,
            .rejected
        ]

        let expectedRawValues = [
            "DRAFT",
            "SEARCHING",
            "PENDING_PARTNER",
            "AWAITING_SUPERVISOR",
            "APPROVED",
            "REJECTED"
        ]

        for (status, expectedRaw) in zip(allCases, expectedRawValues) {
            XCTAssertEqual(status.rawValue, expectedRaw, "\(status) should have raw value \(expectedRaw)")
        }
    }

    func testRequestStatus_Codable() throws {
        // Given
        let statuses: [RequestStatus] = [.draft, .searching, .pendingPartner, .awaitingSupervisor, .approved, .rejected]

        for status in statuses {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(status)

            let decoder = JSONDecoder()
            let decodedStatus = try decoder.decode(RequestStatus.self, from: data)

            // Then
            XCTAssertEqual(decodedStatus, status)
        }
    }

    // MARK: - ShiftHardness Tests

    func testShiftHardness_RawValues() {
        XCTAssertEqual(ShiftHardness.night.rawValue, "NIGHT")
        XCTAssertEqual(ShiftHardness.weekend.rawValue, "WEEKEND")
        XCTAssertEqual(ShiftHardness.holiday.rawValue, "HOLIDAY")
        XCTAssertEqual(ShiftHardness.normal.rawValue, "NORMAL")
    }

    // MARK: - FavorTransaction Tests

    func testFavorTransaction_Initialization() {
        // Given
        let id = "favor-123"
        let covererId = "coverer-1"
        let covererName = "Ana López"
        let requesterId = "requester-1"
        let requesterName = "Pedro García"
        let date = "2024-12-25"
        let shiftName = "Noche"
        let timestamp: TimeInterval = 1703520000

        // When
        let transaction = FavorTransaction(
            id: id,
            covererId: covererId,
            covererName: covererName,
            requesterId: requesterId,
            requesterName: requesterName,
            date: date,
            shiftName: shiftName,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(transaction.id, id)
        XCTAssertEqual(transaction.covererId, covererId)
        XCTAssertEqual(transaction.covererName, covererName)
        XCTAssertEqual(transaction.requesterId, requesterId)
        XCTAssertEqual(transaction.requesterName, requesterName)
        XCTAssertEqual(transaction.date, date)
        XCTAssertEqual(transaction.shiftName, shiftName)
        XCTAssertEqual(transaction.timestamp, timestamp)
    }

    func testFavorTransaction_Codable() throws {
        // Given
        let original = FavorTransaction(
            id: "favor-test",
            covererId: "user-1",
            covererName: "Coverer",
            requesterId: "user-2",
            requesterName: "Requester",
            date: "2024-12-25",
            shiftName: "Mañana",
            timestamp: 1703520000
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FavorTransaction.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.covererId, original.covererId)
        XCTAssertEqual(decoded.covererName, original.covererName)
        XCTAssertEqual(decoded.requesterId, original.requesterId)
        XCTAssertEqual(decoded.requesterName, original.requesterName)
        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.shiftName, original.shiftName)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
    }

    // MARK: - MyShiftDisplay Tests

    func testMyShiftDisplay_ComputedId() {
        // Given
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fullDate = dateFormatter.date(from: "2024-12-25")!

        // When
        let display = MyShiftDisplay(
            dateString: "25 Dic",
            shiftName: "Mañana",
            fullDate: fullDate,
            fullDateString: "2024-12-25"
        )

        // Then
        XCTAssertEqual(display.id, "2024-12-25", "ID should equal fullDateString")
        XCTAssertEqual(display.dateString, "25 Dic")
        XCTAssertEqual(display.shiftName, "Mañana")
        XCTAssertEqual(display.fullDateString, "2024-12-25")
    }

    // MARK: - PlantShift Tests

    func testPlantShift_ComputedId() {
        // Given
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2024-12-25")!

        // When
        let shift = PlantShift(
            userId: "user-123",
            userName: "Test User",
            userRole: "Enfermero",
            date: date,
            dateString: "2024-12-25",
            shiftName: "Tarde"
        )

        // Then
        XCTAssertEqual(shift.id, "user-123_2024-12-25", "ID should be userId_dateString")
        XCTAssertEqual(shift.userId, "user-123")
        XCTAssertEqual(shift.userName, "Test User")
        XCTAssertEqual(shift.userRole, "Enfermero")
        XCTAssertEqual(shift.dateString, "2024-12-25")
        XCTAssertEqual(shift.shiftName, "Tarde")
    }

    func testPlantShift_Identifiable_UniqueIds() {
        // Given
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2024-12-25")!

        // When - Same user, same date
        let shift1 = PlantShift(userId: "user-1", userName: "User 1", userRole: "Enfermero", date: date, dateString: "2024-12-25", shiftName: "Mañana")
        let shift2 = PlantShift(userId: "user-1", userName: "User 1", userRole: "Enfermero", date: date, dateString: "2024-12-25", shiftName: "Tarde")

        // Different user, same date
        let shift3 = PlantShift(userId: "user-2", userName: "User 2", userRole: "Auxiliar", date: date, dateString: "2024-12-25", shiftName: "Mañana")

        // Then
        XCTAssertEqual(shift1.id, shift2.id, "Same user and date should have same ID")
        XCTAssertNotEqual(shift1.id, shift3.id, "Different users should have different IDs")
    }
}
