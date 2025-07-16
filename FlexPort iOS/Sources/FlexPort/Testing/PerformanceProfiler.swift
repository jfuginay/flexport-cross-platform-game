import Foundation
import Combine
import Metal
import os.log
import UIKit

/// Comprehensive performance monitoring and profiling system for FlexPort
@MainActor
public class PerformanceProfiler: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "Performance")
    
    @Published public private(set) var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published public private(set) var isProfilingEnabled: Bool = true
    @Published public private(set) var alertThresholds: PerformanceThresholds = PerformanceThresholds()
    
    private var activeProfiles: [String: ProfileSession] = [:]
    private var metricsHistory: [PerformanceMetrics] = []
    private var frameTimeHistory: [TimeInterval] = []
    private var memoryHistory: [MemoryMetrics] = []
    
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var metalDevice: MTLDevice?
    
    // Publishers for alerts
    public let performanceAlert = PassthroughSubject<PerformanceAlert, Never>()
    public let metricsUpdated = PassthroughSubject<PerformanceMetrics, Never>()
    
    // Configuration
    private let maxHistoryCount = 1000
    private let metricsUpdateInterval: TimeInterval = 1.0
    private var metricsTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        setupMetal()
        startPerformanceMonitoring()
    }
    
    deinit {
        stopPerformanceMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Start profiling a specific operation
    public func startProfiling(for identifier: String, category: ProfilingCategory = .general) {
        guard isProfilingEnabled else { return }
        
        let session = ProfileSession(
            identifier: identifier,
            category: category,
            startTime: CACurrentMediaTime()
        )
        
        activeProfiles[identifier] = session
        logger.debug("Started profiling: \(identifier)")
    }
    
    /// End profiling and return the duration
    @discardableResult
    public func endProfiling(for identifier: String) -> TimeInterval {
        guard isProfilingEnabled,
              let session = activeProfiles.removeValue(forKey: identifier) else {
            return 0
        }
        
        let endTime = CACurrentMediaTime()
        let duration = endTime - session.startTime
        
        // Update metrics
        updateCategoryMetrics(session.category, duration: duration)
        
        // Check for performance alerts
        checkPerformanceThresholds(category: session.category, duration: duration)
        
        logger.debug("Completed profiling: \(identifier) - \(duration * 1000, format: .fixed(precision: 2))ms")
        
        return duration
    }
    
    /// Measure a block of code execution
    public func measure<T>(
        identifier: String,
        category: ProfilingCategory = .general,
        operation: () throws -> T
    ) rethrows -> (result: T, duration: TimeInterval) {
        startProfiling(for: identifier, category: category)
        
        let result = try operation()
        let duration = endProfiling(for: identifier)
        
        return (result, duration)
    }
    
    /// Measure an async operation
    public func measureAsync<T>(
        identifier: String,
        category: ProfilingCategory = .general,
        operation: () async throws -> T
    ) async rethrows -> (result: T, duration: TimeInterval) {
        startProfiling(for: identifier, category: category)
        
        let result = try await operation()
        let duration = endProfiling(for: identifier)
        
        return (result, duration)
    }
    
    /// Get performance summary for a category
    public func getPerformanceSummary(for category: ProfilingCategory) -> CategoryPerformanceSummary {
        let relevantMetrics = metricsHistory.suffix(100) // Last 100 measurements
        
        let durations = relevantMetrics.compactMap { metrics in
            getCategoryDuration(from: metrics, category: category)
        }
        
        guard !durations.isEmpty else {
            return CategoryPerformanceSummary(category: category)
        }
        
        return CategoryPerformanceSummary(
            category: category,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.min(),
            maxDuration: durations.max(),
            sampleCount: durations.count
        )
    }
    
    /// Generate comprehensive performance report
    public func generatePerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            timestamp: Date(),
            currentMetrics: currentMetrics,
            frameTimeHistory: Array(frameTimeHistory.suffix(60)), // Last 60 frames
            memoryHistory: Array(memoryHistory.suffix(60)),
            categorySummaries: ProfilingCategory.allCases.map { getPerformanceSummary(for: $0) },
            deviceInfo: getDeviceInfo(),
            alerts: [] // Would contain recent alerts in full implementation
        )
    }
    
    /// Export performance data as JSON
    public func exportPerformanceData() throws -> Data {
        let report = generatePerformanceReport()
        return try JSONEncoder().encode(report)
    }
    
    // MARK: - Configuration
    
    public func setProfilingEnabled(_ enabled: Bool) {
        isProfilingEnabled = enabled
        
        if enabled {
            startPerformanceMonitoring()
        } else {
            stopPerformanceMonitoring()
            activeProfiles.removeAll()
        }
        
        logger.info("Performance profiling \(enabled ? "enabled" : "disabled")")
    }
    
    public func updateThresholds(_ thresholds: PerformanceThresholds) {
        alertThresholds = thresholds
    }
    
    public func clearHistory() {
        metricsHistory.removeAll()
        frameTimeHistory.removeAll()
        memoryHistory.removeAll()
        logger.info("Performance history cleared")
    }
    
    // MARK: - Private Implementation
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
    }
    
    private func startPerformanceMonitoring() {
        guard isProfilingEnabled else { return }
        
        // Start frame rate monitoring
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink?.add(to: .main, forMode: .common)
        
        // Start metrics collection timer
        metricsTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
            }
        }
    }
    
    private func stopPerformanceMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            frameTimeHistory.append(frameDuration)
            
            // Keep only recent frame times
            if frameTimeHistory.count > maxHistoryCount {
                frameTimeHistory.removeFirst()
            }
            
            // Update frame rate metrics
            frameCount += 1
            if frameCount >= 60 { // Update every 60 frames
                updateFrameRateMetrics()
                frameCount = 0
            }
        }
        
        lastFrameTime = currentTime
    }
    
    private func updateMetrics() {
        let memoryMetrics = getMemoryMetrics()
        let thermalState = getThermalState()
        let batteryLevel = getBatteryLevel()
        
        currentMetrics = PerformanceMetrics(
            timestamp: Date(),
            frameRate: calculateCurrentFrameRate(),
            frameTime: calculateAverageFrameTime(),
            memory: memoryMetrics,
            thermalState: thermalState,
            batteryLevel: batteryLevel,
            ecsUpdateTime: 0, // Would be updated by ECS system
            renderTime: 0,    // Would be updated by rendering system
            networkLatency: 0, // Would be updated by network system
            aiProcessingTime: 0 // Would be updated by AI system
        )
        
        // Add to history
        metricsHistory.append(currentMetrics)
        memoryHistory.append(memoryMetrics)
        
        // Keep history within limits
        if metricsHistory.count > maxHistoryCount {
            metricsHistory.removeFirst()
        }
        if memoryHistory.count > maxHistoryCount {
            memoryHistory.removeFirst()
        }
        
        // Publish updates
        metricsUpdated.send(currentMetrics)
        
        // Check for alerts
        checkSystemPerformanceAlerts()
    }
    
    private func updateFrameRateMetrics() {
        // This would update frame rate related metrics
        // Implementation depends on specific requirements
    }
    
    private func updateCategoryMetrics(_ category: ProfilingCategory, duration: TimeInterval) {
        // Update category-specific metrics based on the category
        switch category {
        case .ecs:
            currentMetrics.ecsUpdateTime = duration
        case .rendering:
            currentMetrics.renderTime = duration
        case .networking:
            currentMetrics.networkLatency = duration
        case .ai:
            currentMetrics.aiProcessingTime = duration
        case .general:
            break // General category doesn't update specific metrics
        }
    }
    
    private func calculateCurrentFrameRate() -> Double {
        guard frameTimeHistory.count >= 10 else { return 0 }
        
        let recentFrames = frameTimeHistory.suffix(60)
        let averageFrameTime = recentFrames.reduce(0, +) / Double(recentFrames.count)
        
        return averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
    }
    
    private func calculateAverageFrameTime() -> TimeInterval {
        guard !frameTimeHistory.isEmpty else { return 0 }
        
        let recentFrames = frameTimeHistory.suffix(60)
        return recentFrames.reduce(0, +) / Double(recentFrames.count)
    }
    
    private func getMemoryMetrics() -> MemoryMetrics {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return MemoryMetrics(
                usedMemory: Double(info.resident_size) / 1024 / 1024, // Convert to MB
                availableMemory: Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024
            )
        }
        
        return MemoryMetrics(usedMemory: 0, availableMemory: 0)
    }
    
    private func getThermalState() -> ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .nominal
        }
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            metalDevice: metalDevice?.name ?? "Unknown"
        )
    }
    
    private func getCategoryDuration(from metrics: PerformanceMetrics, category: ProfilingCategory) -> TimeInterval? {
        switch category {
        case .ecs:
            return metrics.ecsUpdateTime > 0 ? metrics.ecsUpdateTime : nil
        case .rendering:
            return metrics.renderTime > 0 ? metrics.renderTime : nil
        case .networking:
            return metrics.networkLatency > 0 ? metrics.networkLatency : nil
        case .ai:
            return metrics.aiProcessingTime > 0 ? metrics.aiProcessingTime : nil
        case .general:
            return nil
        }
    }
    
    private func checkPerformanceThresholds(category: ProfilingCategory, duration: TimeInterval) {
        let threshold = getThreshold(for: category)
        
        if duration > threshold {
            let alert = PerformanceAlert(
                type: .slowPerformance,
                category: category,
                message: "Operation '\(category.rawValue)' took \(duration * 1000, format: .fixed(precision: 2))ms (threshold: \(threshold * 1000, format: .fixed(precision: 2))ms)",
                severity: getSeverity(duration: duration, threshold: threshold),
                timestamp: Date()
            )
            
            performanceAlert.send(alert)
            logger.warning("Performance alert: \(alert.message)")
        }
    }
    
    private func checkSystemPerformanceAlerts() {
        // Check frame rate
        if currentMetrics.frameRate < alertThresholds.minimumFrameRate {
            let alert = PerformanceAlert(
                type: .lowFrameRate,
                category: .rendering,
                message: "Frame rate dropped to \(currentMetrics.frameRate, format: .fixed(precision: 1)) FPS",
                severity: .warning,
                timestamp: Date()
            )
            performanceAlert.send(alert)
        }
        
        // Check memory usage
        let memoryUsagePercentage = (currentMetrics.memory.usedMemory / currentMetrics.memory.availableMemory) * 100
        if memoryUsagePercentage > alertThresholds.maximumMemoryUsagePercentage {
            let alert = PerformanceAlert(
                type: .highMemoryUsage,
                category: .general,
                message: "Memory usage at \(memoryUsagePercentage, format: .fixed(precision: 1))%",
                severity: .critical,
                timestamp: Date()
            )
            performanceAlert.send(alert)
        }
        
        // Check thermal state
        if currentMetrics.thermalState == .serious || currentMetrics.thermalState == .critical {
            let alert = PerformanceAlert(
                type: .thermalThrottling,
                category: .general,
                message: "Device thermal state: \(currentMetrics.thermalState)",
                severity: .critical,
                timestamp: Date()
            )
            performanceAlert.send(alert)
        }
    }
    
    private func getThreshold(for category: ProfilingCategory) -> TimeInterval {
        switch category {
        case .ecs:
            return alertThresholds.ecsUpdateThreshold
        case .rendering:
            return alertThresholds.renderingThreshold
        case .networking:
            return alertThresholds.networkThreshold
        case .ai:
            return alertThresholds.aiProcessingThreshold
        case .general:
            return alertThresholds.generalOperationThreshold
        }
    }
    
    private func getSeverity(duration: TimeInterval, threshold: TimeInterval) -> AlertSeverity {
        let ratio = duration / threshold
        
        if ratio > 3.0 {
            return .critical
        } else if ratio > 2.0 {
            return .warning
        } else {
            return .info
        }
    }
}

// MARK: - Supporting Types

public struct PerformanceMetrics: Codable {
    public let timestamp: Date
    public let frameRate: Double
    public let frameTime: TimeInterval
    public let memory: MemoryMetrics
    public let thermalState: ThermalState
    public let batteryLevel: Float
    public var ecsUpdateTime: TimeInterval
    public var renderTime: TimeInterval
    public var networkLatency: TimeInterval
    public var aiProcessingTime: TimeInterval
    
    public init(
        timestamp: Date = Date(),
        frameRate: Double = 0,
        frameTime: TimeInterval = 0,
        memory: MemoryMetrics = MemoryMetrics(usedMemory: 0, availableMemory: 0),
        thermalState: ThermalState = .nominal,
        batteryLevel: Float = 1.0,
        ecsUpdateTime: TimeInterval = 0,
        renderTime: TimeInterval = 0,
        networkLatency: TimeInterval = 0,
        aiProcessingTime: TimeInterval = 0
    ) {
        self.timestamp = timestamp
        self.frameRate = frameRate
        self.frameTime = frameTime
        self.memory = memory
        self.thermalState = thermalState
        self.batteryLevel = batteryLevel
        self.ecsUpdateTime = ecsUpdateTime
        self.renderTime = renderTime
        self.networkLatency = networkLatency
        self.aiProcessingTime = aiProcessingTime
    }
}

public struct MemoryMetrics: Codable {
    public let usedMemory: Double // MB
    public let availableMemory: Double // MB
    
    public var usagePercentage: Double {
        guard availableMemory > 0 else { return 0 }
        return (usedMemory / availableMemory) * 100
    }
}

public enum ThermalState: String, Codable, CaseIterable {
    case nominal, fair, serious, critical
}

public enum ProfilingCategory: String, Codable, CaseIterable {
    case ecs, rendering, networking, ai, general
}

public struct PerformanceThresholds {
    public var minimumFrameRate: Double = 30.0
    public var maximumMemoryUsagePercentage: Double = 80.0
    public var ecsUpdateThreshold: TimeInterval = 0.016 // 16ms for 60fps
    public var renderingThreshold: TimeInterval = 0.016
    public var networkThreshold: TimeInterval = 0.100 // 100ms
    public var aiProcessingThreshold: TimeInterval = 0.050 // 50ms
    public var generalOperationThreshold: TimeInterval = 0.100
    
    public init() {}
}

public struct PerformanceAlert {
    public let type: AlertType
    public let category: ProfilingCategory
    public let message: String
    public let severity: AlertSeverity
    public let timestamp: Date
    
    public enum AlertType: String, CaseIterable {
        case slowPerformance, lowFrameRate, highMemoryUsage, thermalThrottling
    }
}

public enum AlertSeverity: String, CaseIterable {
    case info, warning, critical
}

private struct ProfileSession {
    let identifier: String
    let category: ProfilingCategory
    let startTime: CFTimeInterval
}

public struct CategoryPerformanceSummary: Codable {
    public let category: ProfilingCategory
    public let averageDuration: TimeInterval?
    public let minDuration: TimeInterval?
    public let maxDuration: TimeInterval?
    public let sampleCount: Int
    
    public init(category: ProfilingCategory,
                averageDuration: TimeInterval? = nil,
                minDuration: TimeInterval? = nil,
                maxDuration: TimeInterval? = nil,
                sampleCount: Int = 0) {
        self.category = category
        self.averageDuration = averageDuration
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.sampleCount = sampleCount
    }
}

public struct PerformanceReport: Codable {
    public let timestamp: Date
    public let currentMetrics: PerformanceMetrics
    public let frameTimeHistory: [TimeInterval]
    public let memoryHistory: [MemoryMetrics]
    public let categorySummaries: [CategoryPerformanceSummary]
    public let deviceInfo: DeviceInfo
    public let alerts: [String] // Simplified for encoding
}

public struct DeviceInfo: Codable {
    public let model: String
    public let systemVersion: String
    public let processorCount: Int
    public let physicalMemory: UInt64
    public let metalDevice: String
}