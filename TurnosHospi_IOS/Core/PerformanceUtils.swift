//
//  PerformanceUtils.swift
//  TurnosHospi_IOS
//
//  Performance monitoring, lazy loading, and view optimization utilities
//

import SwiftUI
import Combine

// MARK: - Performance Monitor

final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published private(set) var metrics: PerformanceMetrics = .empty

    private var operationStarts: [String: Date] = [:]
    private var operationDurations: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "com.turnoshospi.performance")

    struct PerformanceMetrics {
        var averageLoadTime: TimeInterval
        var cacheHitRate: Double
        var networkSuccessRate: Double
        var memoryUsageMB: Double
        var activeListeners: Int

        static let empty = PerformanceMetrics(
            averageLoadTime: 0,
            cacheHitRate: 0,
            networkSuccessRate: 0,
            memoryUsageMB: 0,
            activeListeners: 0
        )
    }

    private init() {
        startPeriodicUpdate()
    }

    private func startPeriodicUpdate() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }

    // MARK: - Operation Tracking

    func startOperation(_ name: String) {
        queue.async { [weak self] in
            self?.operationStarts[name] = Date()
        }
    }

    func endOperation(_ name: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let startTime = self.operationStarts[name] else { return }

            let duration = Date().timeIntervalSince(startTime)
            self.operationStarts.removeValue(forKey: name)

            if self.operationDurations[name] == nil {
                self.operationDurations[name] = []
            }
            self.operationDurations[name]?.append(duration)

            // Keep only last 100 samples
            if let count = self.operationDurations[name]?.count, count > 100 {
                self.operationDurations[name]?.removeFirst()
            }
        }
    }

    func measure<T>(_ name: String, operation: () throws -> T) rethrows -> T {
        startOperation(name)
        defer { endOperation(name) }
        return try operation()
    }

    func measureAsync<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        startOperation(name)
        defer { endOperation(name) }
        return try await operation()
    }

    // MARK: - Metrics

    private func updateMetrics() {
        let cache = CacheManager.shared
        let network = NetworkManager.shared

        // Calculate average load time
        var totalDuration: TimeInterval = 0
        var totalSamples = 0
        for (_, durations) in operationDurations {
            totalDuration += durations.reduce(0, +)
            totalSamples += durations.count
        }
        let avgLoadTime = totalSamples > 0 ? totalDuration / Double(totalSamples) : 0

        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let memoryMB = result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0

        DispatchQueue.main.async { [weak self] in
            self?.metrics = PerformanceMetrics(
                averageLoadTime: avgLoadTime,
                cacheHitRate: cache.hitRate,
                networkSuccessRate: network.successRate,
                memoryUsageMB: memoryMB,
                activeListeners: 0 // Would need to track from repositories
            )
        }
    }

    func getAverageTime(for operation: String) -> TimeInterval? {
        guard let durations = operationDurations[operation], !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }
}

// MARK: - Debouncer

final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Throttler

final class Throttler {
    private var lastExecution: Date?
    private let interval: TimeInterval
    private let queue: DispatchQueue

    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    func throttle(_ action: @escaping () -> Void) {
        let now = Date()

        if let last = lastExecution, now.timeIntervalSince(last) < interval {
            return
        }

        lastExecution = now
        queue.async(execute: action)
    }
}

// MARK: - Lazy Loading View Modifier

struct LazyLoadModifier<Data>: ViewModifier {
    let data: Data?
    let placeholder: AnyView

    func body(content: Content) -> some View {
        if data != nil {
            content
        } else {
            placeholder
        }
    }
}

extension View {
    func lazyLoad<Data>(
        _ data: Data?,
        placeholder: some View = ProgressView()
    ) -> some View {
        modifier(LazyLoadModifier(data: data, placeholder: AnyView(placeholder)))
    }
}

// MARK: - Optimized List Cell

struct OptimizedListCell<Content: View>: View {
    let id: String
    @ViewBuilder let content: () -> Content

    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                content()
            } else {
                Color.clear
                    .frame(height: 60)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

// MARK: - Async Image with Cache

struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private static var imageCache = NSCache<NSURL, UIImage>()

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let url = url else { return }

        // Check cache
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            loadedImage = cached
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false

                guard let data = data, let image = UIImage(data: data) else { return }

                // Cache the image
                Self.imageCache.setObject(image, forKey: url as NSURL)
                loadedImage = image
            }
        }.resume()
    }
}

// MARK: - Prefetch Manager

final class PrefetchManager {
    static let shared = PrefetchManager()

    private var prefetchTasks: [String: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "com.turnoshospi.prefetch")

    private init() {}

    func prefetch(key: String, task: @escaping () async -> Void) {
        queue.async { [weak self] in
            // Cancel existing task if any
            self?.prefetchTasks[key]?.cancel()

            // Start new prefetch task
            self?.prefetchTasks[key] = Task {
                await task()
            }
        }
    }

    func cancelPrefetch(key: String) {
        queue.async { [weak self] in
            self?.prefetchTasks[key]?.cancel()
            self?.prefetchTasks.removeValue(forKey: key)
        }
    }

    func cancelAll() {
        queue.async { [weak self] in
            self?.prefetchTasks.values.forEach { $0.cancel() }
            self?.prefetchTasks.removeAll()
        }
    }
}

// MARK: - Memory Pressure Handler

final class MemoryPressureHandler {
    static let shared = MemoryPressureHandler()

    private var source: DispatchSourceMemoryPressure?

    private init() {
        setupMemoryPressureHandler()
    }

    private func setupMemoryPressureHandler() {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }

        source?.resume()
    }

    private func handleMemoryPressure() {
        // Clear caches
        CacheManager.shared.clearExpired()

        // Cancel prefetch tasks
        PrefetchManager.shared.cancelAll()

        // Post notification for views to respond
        NotificationCenter.default.post(name: .didReceiveMemoryPressure, object: nil)
    }
}

extension Notification.Name {
    static let didReceiveMemoryPressure = Notification.Name("didReceiveMemoryPressure")
}

// MARK: - Batch Update Collector

final class BatchUpdateCollector<T> {
    private var items: [T] = []
    private var updateHandler: (([T]) -> Void)?
    private let debouncer: Debouncer

    init(delay: TimeInterval = 0.1) {
        self.debouncer = Debouncer(delay: delay)
    }

    func add(_ item: T) {
        items.append(item)
        debouncer.debounce { [weak self] in
            guard let self = self else { return }
            self.updateHandler?(self.items)
            self.items.removeAll()
        }
    }

    func onBatchUpdate(_ handler: @escaping ([T]) -> Void) {
        updateHandler = handler
    }
}

// MARK: - View Performance Wrapper

struct PerformanceTrackedView<Content: View>: View {
    let name: String
    let content: Content

    init(_ name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }

    var body: some View {
        content
            .onAppear {
                PerformanceMonitor.shared.startOperation("view_\(name)")
            }
            .onDisappear {
                PerformanceMonitor.shared.endOperation("view_\(name)")
            }
    }
}

// MARK: - Optimized ForEach

struct OptimizedForEach<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    @State private var visibleRange: Range<Int>?

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(data) { item in
                content(item)
            }
        }
    }
}

// MARK: - String ID Generator (Faster than UUID)

struct FastID {
    private static var counter: UInt64 = 0
    private static let queue = DispatchQueue(label: "com.turnoshospi.fastid")

    static func generate() -> String {
        queue.sync {
            counter += 1
            return String(counter, radix: 36)
        }
    }
}
