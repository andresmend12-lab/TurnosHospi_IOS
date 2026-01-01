//
//  NetworkManager.swift
//  TurnosHospi_IOS
//
//  Network connectivity monitoring and retry logic for Firebase operations
//

import Foundation
import Network
import Combine

// MARK: - Network Status

enum NetworkStatus: Equatable {
    case connected
    case disconnected
    case connecting

    var isConnected: Bool {
        self == .connected
    }
}

// MARK: - Retry Configuration

struct RetryConfiguration {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitterFactor: Double

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitterFactor: 0.1
    )

    static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitterFactor: 0.15
    )

    static let minimal = RetryConfiguration(
        maxAttempts: 2,
        initialDelay: 2.0,
        maxDelay: 10.0,
        multiplier: 1.5,
        jitterFactor: 0.05
    )

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let baseDelay = initialDelay * pow(multiplier, Double(attempt - 1))
        let cappedDelay = min(baseDelay, maxDelay)
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
        return max(0.1, cappedDelay + jitter)
    }
}

// MARK: - Network Manager

final class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    @Published private(set) var status: NetworkStatus = .connecting
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.turnoshospi.network")

    // Statistics
    private(set) var totalRequests: Int = 0
    private(set) var failedRequests: Int = 0
    private(set) var retriedRequests: Int = 0

    var successRate: Double {
        totalRequests > 0 ? Double(totalRequests - failedRequests) / Double(totalRequests) : 1.0
    }

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func updateStatus(from path: NWPath) {
        switch path.status {
        case .satisfied:
            status = .connected
            connectionType = path.availableInterfaces.first?.type
        case .unsatisfied:
            status = .disconnected
            connectionType = nil
        case .requiresConnection:
            status = .connecting
            connectionType = nil
        @unknown default:
            status = .disconnected
            connectionType = nil
        }
    }

    // MARK: - Retry Logic

    func withRetry<T>(
        configuration: RetryConfiguration = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        totalRequests += 1
        var lastError: Error?

        for attempt in 1...configuration.maxAttempts {
            do {
                // Check network before attempting
                if !status.isConnected && attempt > 1 {
                    try await waitForConnection(timeout: 5.0)
                }

                let result = try await operation()
                return result

            } catch {
                lastError = error
                retriedRequests += 1

                // Don't retry if it's a non-recoverable error
                if !isRetryable(error) {
                    failedRequests += 1
                    throw error
                }

                // Don't wait after the last attempt
                if attempt < configuration.maxAttempts {
                    let delay = configuration.delay(forAttempt: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        failedRequests += 1
        throw lastError ?? AppError.unknown(message: "Operation failed after \(configuration.maxAttempts) attempts")
    }

    func withRetryCallback<T>(
        configuration: RetryConfiguration = .default,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        totalRequests += 1
        attemptWithRetry(
            attempt: 1,
            configuration: configuration,
            operation: operation,
            completion: completion
        )
    }

    private func attemptWithRetry<T>(
        attempt: Int,
        configuration: RetryConfiguration,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        operation { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                completion(result)

            case .failure(let error):
                self.retriedRequests += 1

                if attempt >= configuration.maxAttempts || !self.isRetryable(error) {
                    self.failedRequests += 1
                    completion(result)
                    return
                }

                let delay = configuration.delay(forAttempt: attempt)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.attemptWithRetry(
                        attempt: attempt + 1,
                        configuration: configuration,
                        operation: operation,
                        completion: completion
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func isRetryable(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Network errors are retryable
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost:
                return true
            default:
                return false
            }
        }

        // Firebase errors
        if nsError.domain == "com.firebase.database" {
            switch nsError.code {
            case -24: // Network error
                return true
            default:
                return false
            }
        }

        // App errors
        if let appError = error as? AppError {
            return appError.isRecoverable
        }

        return false
    }

    private func waitForConnection(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if status.isConnected {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        throw AppError.networkUnavailable
    }

    // MARK: - Convenience Methods

    func executeWhenConnected(_ operation: @escaping () -> Void) {
        if status.isConnected {
            operation()
        } else {
            var cancellable: AnyCancellable?
            cancellable = $status
                .filter { $0.isConnected }
                .first()
                .sink { _ in
                    operation()
                    cancellable?.cancel()
                }
        }
    }
}

// MARK: - Firebase Retry Extensions

import FirebaseDatabase

extension DatabaseReference {

    func observeSingleEventWithRetry(
        of eventType: DataEventType,
        retryConfig: RetryConfiguration = .default,
        completion: @escaping (Result<DataSnapshot, Error>) -> Void
    ) {
        NetworkManager.shared.withRetryCallback(
            configuration: retryConfig,
            operation: { callback in
                self.observeSingleEvent(of: eventType) { snapshot in
                    callback(.success(snapshot))
                } withCancel: { error in
                    callback(.failure(error))
                }
            },
            completion: completion
        )
    }

    func setValueWithRetry(
        _ value: Any?,
        retryConfig: RetryConfiguration = .default,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        NetworkManager.shared.withRetryCallback(
            configuration: retryConfig,
            operation: { callback in
                self.setValue(value) { error, _ in
                    if let error = error {
                        callback(.failure(error))
                    } else {
                        callback(.success(()))
                    }
                }
            },
            completion: completion
        )
    }

    func updateChildValuesWithRetry(
        _ values: [String: Any],
        retryConfig: RetryConfiguration = .default,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        NetworkManager.shared.withRetryCallback(
            configuration: retryConfig,
            operation: { callback in
                self.updateChildValues(values) { error, _ in
                    if let error = error {
                        callback(.failure(error))
                    } else {
                        callback(.success(()))
                    }
                }
            },
            completion: completion
        )
    }
}
