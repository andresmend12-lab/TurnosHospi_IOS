//
//  ErrorHandlingTests.swift
//  TurnosHospi_IOSTests
//
//  Tests for the error handling system
//

import XCTest
@testable import TurnosHospi_IOS

final class ErrorHandlingTests: XCTestCase {

    // MARK: - AppError Tests

    func testAppError_LocalizedDescription_AuthenticationErrors() {
        // Given
        let errors: [(AppError, String)] = [
            (.userNotAuthenticated, "Debes iniciar sesión"),
            (.invalidCredentials, "Email o contraseña incorrectos"),
            (.emailAlreadyInUse, "Este email ya está registrado"),
            (.weakPassword, "contraseña debe tener al menos 6 caracteres"),
            (.accountDisabled, "Esta cuenta ha sido deshabilitada")
        ]

        // Then
        for (error, expectedSubstring) in errors {
            XCTAssertTrue(
                error.localizedDescription.contains(expectedSubstring),
                "\(error) should contain '\(expectedSubstring)' but was '\(error.localizedDescription)'"
            )
        }
    }

    func testAppError_LocalizedDescription_NetworkErrors() {
        XCTAssertTrue(AppError.networkUnavailable.localizedDescription.contains("conexión"))
        XCTAssertTrue(AppError.serverError(code: 500).localizedDescription.contains("500"))
        XCTAssertTrue(AppError.timeout.localizedDescription.contains("tardó"))
    }

    func testAppError_LocalizedDescription_ValidationErrors() {
        let error = AppError.validationFailed(field: "Email", reason: "formato inválido")
        XCTAssertTrue(error.localizedDescription.contains("Email"))
        XCTAssertTrue(error.localizedDescription.contains("formato inválido"))
    }

    func testAppError_LocalizedDescription_BusinessLogicErrors() {
        XCTAssertTrue(AppError.consecutiveDaysExceeded.localizedDescription.contains("6 días"))
        XCTAssertTrue(AppError.nightShiftRestRequired.localizedDescription.contains("noche"))
        XCTAssertTrue(AppError.alreadyHasShift.localizedDescription.contains("turno"))
    }

    // MARK: - Error Category Tests

    func testAppError_Category_Authentication() {
        let authErrors: [AppError] = [
            .authenticationFailed(reason: "test"),
            .userNotAuthenticated,
            .invalidCredentials,
            .emailAlreadyInUse,
            .weakPassword,
            .accountDisabled
        ]

        for error in authErrors {
            XCTAssertEqual(error.category, .authentication, "\(error) should be authentication category")
        }
    }

    func testAppError_Category_Network() {
        let networkErrors: [AppError] = [
            .networkUnavailable,
            .serverError(code: 500),
            .timeout,
            .invalidResponse
        ]

        for error in networkErrors {
            XCTAssertEqual(error.category, .network, "\(error) should be network category")
        }
    }

    func testAppError_Category_Database() {
        let dbErrors: [AppError] = [
            .databaseReadFailed(path: "/test"),
            .databaseWriteFailed(path: "/test"),
            .permissionDenied,
            .dataNotFound,
            .invalidData(reason: "test")
        ]

        for error in dbErrors {
            XCTAssertEqual(error.category, .database, "\(error) should be database category")
        }
    }

    func testAppError_Category_Validation() {
        let validationErrors: [AppError] = [
            .validationFailed(field: "test", reason: "test"),
            .invalidDateFormat,
            .roleIncompatible,
            .shiftConflict(reason: "test"),
            .workRuleViolation(reason: "test")
        ]

        for error in validationErrors {
            XCTAssertEqual(error.category, .validation, "\(error) should be validation category")
        }
    }

    func testAppError_Category_BusinessLogic() {
        let businessErrors: [AppError] = [
            .swapNotAllowed(reason: "test"),
            .coverageNotAvailable,
            .alreadyHasShift,
            .consecutiveDaysExceeded,
            .nightShiftRestRequired
        ]

        for error in businessErrors {
            XCTAssertEqual(error.category, .businessLogic, "\(error) should be businessLogic category")
        }
    }

    // MARK: - Recovery Suggestion Tests

    func testAppError_RecoverySuggestion_NetworkErrors() {
        XCTAssertNotNil(AppError.networkUnavailable.recoverySuggestion)
        XCTAssertNotNil(AppError.timeout.recoverySuggestion)
    }

    func testAppError_RecoverySuggestion_AuthErrors() {
        XCTAssertNotNil(AppError.invalidCredentials.recoverySuggestion)
        XCTAssertNotNil(AppError.permissionDenied.recoverySuggestion)
    }

    func testAppError_RecoverySuggestion_BusinessLogic() {
        XCTAssertNotNil(AppError.consecutiveDaysExceeded.recoverySuggestion)
        XCTAssertNotNil(AppError.nightShiftRestRequired.recoverySuggestion)
    }

    // MARK: - Recoverable Error Tests

    func testAppError_IsRecoverable_NetworkErrors() {
        XCTAssertTrue(AppError.networkUnavailable.isRecoverable)
        XCTAssertTrue(AppError.timeout.isRecoverable)
        XCTAssertTrue(AppError.serverError(code: 503).isRecoverable)
    }

    func testAppError_IsRecoverable_OtherErrors() {
        XCTAssertFalse(AppError.invalidCredentials.isRecoverable)
        XCTAssertFalse(AppError.permissionDenied.isRecoverable)
        XCTAssertFalse(AppError.operationCancelled.isRecoverable)
    }

    // MARK: - Should Log Tests

    func testAppError_ShouldLog_CancelledOperation() {
        XCTAssertFalse(AppError.operationCancelled.shouldLog)
    }

    func testAppError_ShouldLog_OtherErrors() {
        XCTAssertTrue(AppError.networkUnavailable.shouldLog)
        XCTAssertTrue(AppError.invalidCredentials.shouldLog)
        XCTAssertTrue(AppError.permissionDenied.shouldLog)
    }

    // MARK: - Equatable Tests

    func testAppError_Equatable() {
        XCTAssertEqual(AppError.networkUnavailable, AppError.networkUnavailable)
        XCTAssertEqual(AppError.serverError(code: 500), AppError.serverError(code: 500))
        XCTAssertNotEqual(AppError.serverError(code: 500), AppError.serverError(code: 503))
        XCTAssertNotEqual(AppError.networkUnavailable, AppError.timeout)
    }

    // MARK: - Result Extension Tests

    func testResult_IsSuccess() {
        let success: AppResult<String> = .success("test")
        let failure: AppResult<String> = .failure(.networkUnavailable)

        XCTAssertTrue(success.isSuccess)
        XCTAssertFalse(failure.isSuccess)
    }

    func testResult_SuccessValue() {
        let success: AppResult<String> = .success("test value")
        let failure: AppResult<String> = .failure(.networkUnavailable)

        XCTAssertEqual(success.successValue, "test value")
        XCTAssertNil(failure.successValue)
    }

    func testResult_Error() {
        let success: AppResult<String> = .success("test")
        let failure: AppResult<String> = .failure(.timeout)

        XCTAssertNil(success.error)
        XCTAssertEqual(failure.error, .timeout)
    }

    func testResult_FromError_WithNil() {
        let result: VoidResult = .from(error: nil)
        XCTAssertTrue(result.isSuccess)
    }

    func testResult_FromError_WithError() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let result: VoidResult = .from(error: nsError)

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error, .networkUnavailable)
    }

    // MARK: - Error Conversion Tests

    func testAppError_From_URLError_NotConnected() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let appError = AppError.from(nsError)

        XCTAssertEqual(appError, .networkUnavailable)
    }

    func testAppError_From_URLError_Timeout() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let appError = AppError.from(nsError)

        XCTAssertEqual(appError, .timeout)
    }

    func testAppError_From_URLError_Cancelled() {
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        let appError = AppError.from(nsError)

        XCTAssertEqual(appError, .operationCancelled)
    }

    func testAppError_From_UnknownError() {
        let nsError = NSError(domain: "CustomDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Custom error"])
        let appError = AppError.from(nsError)

        if case .unknown(let message) = appError {
            XCTAssertEqual(message, "Custom error")
        } else {
            XCTFail("Should be unknown error")
        }
    }

    // MARK: - LoadingState Tests

    func testLoadingState_Idle() {
        let state: LoadingState<String> = .idle

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.value)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.isSuccess)
    }

    func testLoadingState_Loading() {
        let state: LoadingState<String> = .loading

        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.value)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.isSuccess)
    }

    func testLoadingState_Success() {
        let state: LoadingState<String> = .success("test value")

        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.value, "test value")
        XCTAssertNil(state.error)
        XCTAssertTrue(state.isSuccess)
    }

    func testLoadingState_Failure() {
        let state: LoadingState<String> = .failure(.networkUnavailable)

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.value)
        XCTAssertEqual(state.error, .networkUnavailable)
        XCTAssertFalse(state.isSuccess)
    }

    // MARK: - UI Properties Tests

    func testAppError_AlertTitle() {
        XCTAssertEqual(AppError.invalidCredentials.alertTitle, "Error de Autenticación")
        XCTAssertEqual(AppError.networkUnavailable.alertTitle, "Error de Conexión")
        XCTAssertEqual(AppError.permissionDenied.alertTitle, "Error de Datos")
        XCTAssertEqual(AppError.invalidDateFormat.alertTitle, "Datos Inválidos")
        XCTAssertEqual(AppError.consecutiveDaysExceeded.alertTitle, "Acción No Permitida")
        XCTAssertEqual(AppError.unknown(message: "test").alertTitle, "Error")
    }

    func testAppError_Icon() {
        XCTAssertEqual(AppError.invalidCredentials.icon, "lock.shield.fill")
        XCTAssertEqual(AppError.networkUnavailable.icon, "wifi.slash")
        XCTAssertEqual(AppError.permissionDenied.icon, "externaldrive.badge.exclamationmark")
    }
}
