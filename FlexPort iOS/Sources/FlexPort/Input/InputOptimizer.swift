import UIKit
import Combine
import simd
import Metal
import MetalKit

/// High-performance input optimization system for smooth 60fps touch interaction
public class InputOptimizer: ObservableObject {
    
    // MARK: - Performance Metrics
    @Published public private(set) var currentFPS: Double = 60.0
    @Published public private(set) var inputLatency: TimeInterval = 0.0
    @Published public private(set) var droppedFrames: Int = 0
    @Published public private(set) var performanceLevel: PerformanceLevel = .optimal
    
    // MARK: - Publishers
    public let optimizedTouchEvent = PassthroughSubject<TouchEvent, Never>()
    public let performanceWarning = PassthroughSubject<PerformanceWarning, Never>()
    
    // MARK: - Configuration
    public struct Configuration {
        public var targetFPS: Double = 60.0
        public var maxInputLatency: TimeInterval = 0.016 // ~1 frame at 60fps
        public var adaptiveFiltering: Bool = true
        public var predictiveTracking: Bool = true
        public var batchProcessing: Bool = true
        public var metalAcceleration: Bool = true
        public var maxBatchSize: Int = 16
        public var smoothingWindow: Int = 5
        public var deadZoneThreshold: Float = 2.0
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - Metal Resources
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    
    // MARK: - Performance Tracking
    private var frameTimeHistory: [TimeInterval] = []
    private var inputEventHistory: [InputPerformanceMetric] = []
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var performanceTimer: Timer?
    
    // MARK: - Input Processing
    private var touchEventQueue: [TouchEvent] = []
    private var processingQueue = DispatchQueue(label: "com.flexport.input.processing", qos: .userInteractive)
    private var batchProcessingTimer: Timer?
    
    // MARK: - Coordinate Transformation
    private var worldToScreenTransform: simd_float4x4 = matrix_identity_float4x4
    private var screenToWorldTransform: simd_float4x4 = matrix_identity_float4x4
    private var viewportSize: SIMD2<Float> = SIMD2<Float>(1, 1)
    private var worldBounds: (min: SIMD2<Float>, max: SIMD2<Float>) = (
        min: SIMD2<Float>(-1000, -1000),
        max: SIMD2<Float>(1000, 1000)
    )
    
    // MARK: - Predictive Tracking
    private var velocityPredictor: VelocityPredictor = VelocityPredictor()
    private var touchPredictor: TouchPredictor = TouchPredictor()
    
    // MARK: - Adaptive Filtering
    private var adaptiveFilter: AdaptiveFilter = AdaptiveFilter()
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init() {
        setupMetal()
        setupPerformanceMonitoring()
        setupBatchProcessing()
    }
    
    deinit {
        performanceTimer?.invalidate()
        batchProcessingTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Process touch event with optimization
    public func processTouch(_ touchEvent: TouchEvent) {
        let startTime = CACurrentMediaTime()
        
        if configuration.batchProcessing {
            touchEventQueue.append(touchEvent)
        } else {
            processIndividualTouch(touchEvent, startTime: startTime)
        }
    }
    
    /// Update coordinate transformation matrices
    public func updateTransforms(worldToScreen: simd_float4x4, viewportSize: SIMD2<Float>) {
        self.worldToScreenTransform = worldToScreen
        self.screenToWorldTransform = worldToScreen.inverse
        self.viewportSize = viewportSize
    }
    
    /// Set world bounds for coordinate clamping
    public func setWorldBounds(min: SIMD2<Float>, max: SIMD2<Float>) {
        worldBounds = (min: min, max: max)
    }
    
    /// Convert screen coordinates to world coordinates
    public func convertScreenToWorld(_ screenPoint: CGPoint, in view: UIView) -> SIMD2<Float> {
        // Normalize screen coordinates to [-1, 1] range
        let normalizedX = (Float(screenPoint.x) / Float(view.bounds.width)) * 2.0 - 1.0
        let normalizedY = (1.0 - Float(screenPoint.y) / Float(view.bounds.height)) * 2.0 - 1.0
        
        let screenVec = SIMD4<Float>(normalizedX, normalizedY, 0, 1)
        let worldVec = screenToWorldTransform * screenVec
        
        var worldPos = SIMD2<Float>(worldVec.x, worldVec.y)
        
        // Clamp to world bounds
        worldPos.x = max(worldBounds.min.x, min(worldBounds.max.x, worldPos.x))
        worldPos.y = max(worldBounds.min.y, min(worldBounds.max.y, worldPos.y))
        
        return worldPos
    }
    
    /// Convert world coordinates to screen coordinates
    public func convertWorldToScreen(_ worldPoint: SIMD2<Float>, in view: UIView) -> CGPoint {
        let worldVec = SIMD4<Float>(worldPoint.x, worldPoint.y, 0, 1)
        let screenVec = worldToScreenTransform * worldVec
        
        // Convert from normalized coordinates to screen coordinates
        let screenX = (screenVec.x + 1.0) * 0.5 * Float(view.bounds.width)
        let screenY = (1.0 - screenVec.y) * 0.5 * Float(view.bounds.height)
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    /// Check if gesture should be allowed based on performance
    public func shouldAllowGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Throttle gestures if performance is poor
        switch performanceLevel {
        case .optimal, .good:
            return true
        case .fair:
            // Allow only essential gestures
            return gestureRecognizer is UITapGestureRecognizer || 
                   gestureRecognizer is UIPanGestureRecognizer
        case .poor:
            // Allow only taps
            return gestureRecognizer is UITapGestureRecognizer
        }
    }
    
    /// Get performance statistics
    public func getPerformanceStats() -> PerformanceStats {
        return PerformanceStats(
            averageFPS: frameTimeHistory.isEmpty ? 60.0 : 1.0 / (frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)),
            averageLatency: inputEventHistory.isEmpty ? 0.0 : inputEventHistory.map { $0.latency }.reduce(0, +) / Double(inputEventHistory.count),
            droppedFrames: droppedFrames,
            performanceLevel: performanceLevel,
            metalAccelerated: device != nil
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupMetal() {
        guard configuration.metalAcceleration else { return }
        
        device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            print("Metal not available for input optimization")
            return
        }
        
        commandQueue = device.makeCommandQueue()
        
        // Setup compute pipeline for coordinate transformations
        setupComputePipeline()
    }
    
    private func setupComputePipeline() {
        guard let device = device else { return }
        
        let library = device.makeDefaultLibrary()
        guard let function = library?.makeFunction(name: "coordinate_transform") else {
            print("Failed to find coordinate_transform function")
            return
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create compute pipeline state: \(error)")
        }
    }
    
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func setupBatchProcessing() {
        guard configuration.batchProcessing else { return }
        
        batchProcessingTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.processBatchedTouches()
        }
    }
    
    private func processIndividualTouch(_ touchEvent: TouchEvent, startTime: CFTimeInterval) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            var optimizedEvent = touchEvent
            
            // Apply adaptive filtering
            if self.configuration.adaptiveFiltering {
                optimizedEvent = self.adaptiveFilter.filter(optimizedEvent)
            }
            
            // Apply predictive tracking
            if self.configuration.predictiveTracking {
                optimizedEvent = self.touchPredictor.predict(optimizedEvent)
            }
            
            // Calculate latency
            let latency = CACurrentMediaTime() - startTime
            
            // Record performance metric
            let metric = InputPerformanceMetric(
                timestamp: Date(),
                latency: latency,
                eventType: touchEvent.phase
            )
            self.recordPerformanceMetric(metric)
            
            // Emit optimized event
            DispatchQueue.main.async {
                self.optimizedTouchEvent.send(optimizedEvent)
            }
        }
    }
    
    private func processBatchedTouches() {
        guard !touchEventQueue.isEmpty else { return }
        
        let batch = Array(touchEventQueue.prefix(configuration.maxBatchSize))
        touchEventQueue.removeFirst(min(configuration.maxBatchSize, touchEventQueue.count))
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CACurrentMediaTime()
            var optimizedEvents: [TouchEvent] = []
            
            for touchEvent in batch {
                var optimizedEvent = touchEvent
                
                // Apply optimizations
                if self.configuration.adaptiveFiltering {
                    optimizedEvent = self.adaptiveFilter.filter(optimizedEvent)
                }
                
                if self.configuration.predictiveTracking {
                    optimizedEvent = self.touchPredictor.predict(optimizedEvent)
                }
                
                optimizedEvents.append(optimizedEvent)
            }
            
            let latency = CACurrentMediaTime() - startTime
            
            // Record batch performance
            let metric = InputPerformanceMetric(
                timestamp: Date(),
                latency: latency,
                eventType: .moved // Most common in batches
            )
            self.recordPerformanceMetric(metric)
            
            // Emit optimized events
            DispatchQueue.main.async {
                for event in optimizedEvents {
                    self.optimizedTouchEvent.send(event)
                }
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        let currentTime = CACurrentMediaTime()
        let frameTime = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        frameTimeHistory.append(frameTime)
        if frameTimeHistory.count > 60 { // Keep 1 second of history
            frameTimeHistory.removeFirst()
        }
        
        // Calculate current FPS
        let avgFrameTime = frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        currentFPS = 1.0 / avgFrameTime
        
        // Check for dropped frames (frame time > 1.5x target)
        let targetFrameTime = 1.0 / configuration.targetFPS
        if frameTime > targetFrameTime * 1.5 {
            droppedFrames += 1
        }
        
        // Update performance level
        updatePerformanceLevel()
        
        // Clean up old metrics
        cleanupPerformanceHistory()
    }
    
    private func updatePerformanceLevel() {
        let targetFPS = configuration.targetFPS
        
        if currentFPS >= targetFPS * 0.95 {
            performanceLevel = .optimal
        } else if currentFPS >= targetFPS * 0.85 {
            performanceLevel = .good
        } else if currentFPS >= targetFPS * 0.70 {
            performanceLevel = .fair
            
            let warning = PerformanceWarning(
                type: .lowFrameRate,
                currentFPS: currentFPS,
                targetFPS: targetFPS
            )
            performanceWarning.send(warning)
        } else {
            performanceLevel = .poor
            
            let warning = PerformanceWarning(
                type: .severePerformanceDrop,
                currentFPS: currentFPS,
                targetFPS: targetFPS
            )
            performanceWarning.send(warning)
        }
    }
    
    private func recordPerformanceMetric(_ metric: InputPerformanceMetric) {
        inputEventHistory.append(metric)
        
        // Update input latency
        inputLatency = metric.latency
        
        // Check for high latency
        if metric.latency > configuration.maxInputLatency {
            let warning = PerformanceWarning(
                type: .highInputLatency,
                latency: metric.latency
            )
            DispatchQueue.main.async {
                self.performanceWarning.send(warning)
            }
        }
    }
    
    private func cleanupPerformanceHistory() {
        let cutoffTime = Date().addingTimeInterval(-10.0) // Keep 10 seconds
        inputEventHistory.removeAll { $0.timestamp < cutoffTime }
    }
}

// MARK: - Supporting Classes

private class VelocityPredictor {
    private var velocityHistory: [SIMD2<Float>] = []
    private let maxHistory = 5
    
    func predict(_ velocity: SIMD2<Float>) -> SIMD2<Float> {
        velocityHistory.append(velocity)
        if velocityHistory.count > maxHistory {
            velocityHistory.removeFirst()
        }
        
        guard velocityHistory.count >= 3 else { return velocity }
        
        // Simple linear prediction
        let recent = Array(velocityHistory.suffix(3))
        let acceleration = (recent[2] - recent[1]) - (recent[1] - recent[0])
        
        return velocity + acceleration * 0.5 // Predict half frame ahead
    }
}

private class TouchPredictor {
    private var positionHistory: [SIMD2<Float>] = []
    private var timeHistory: [TimeInterval] = []
    private let maxHistory = 5
    
    func predict(_ touchEvent: TouchEvent) -> TouchEvent {
        let position = touchEvent.touchData.worldPosition
        let time = touchEvent.timestamp.timeIntervalSince1970
        
        positionHistory.append(position)
        timeHistory.append(time)
        
        if positionHistory.count > maxHistory {
            positionHistory.removeFirst()
            timeHistory.removeFirst()
        }
        
        guard positionHistory.count >= 3 else { return touchEvent }
        
        // Calculate velocity and predict next position
        let recentPositions = Array(positionHistory.suffix(3))
        let recentTimes = Array(timeHistory.suffix(3))
        
        let velocity = (recentPositions[2] - recentPositions[1]) / Float(recentTimes[2] - recentTimes[1])
        let predictedPosition = position + velocity * (1.0 / 60.0) // Predict one frame ahead
        
        var predictedTouchData = touchEvent.touchData
        predictedTouchData = TouchData(
            id: predictedTouchData.id,
            screenPosition: predictedTouchData.screenPosition,
            worldPosition: predictedPosition,
            timestamp: predictedTouchData.timestamp,
            force: predictedTouchData.force,
            radius: predictedTouchData.radius
        )
        
        return TouchEvent(
            touchData: predictedTouchData,
            phase: touchEvent.phase,
            timestamp: touchEvent.timestamp
        )
    }
}

private class AdaptiveFilter {
    private var smoothingFactor: Float = 0.8
    private var lastPosition: SIMD2<Float>?
    private var deadZone: Float = 2.0
    
    func filter(_ touchEvent: TouchEvent) -> TouchEvent {
        let currentPosition = touchEvent.touchData.worldPosition
        
        guard let lastPos = lastPosition else {
            lastPosition = currentPosition
            return touchEvent
        }
        
        // Apply dead zone filtering
        let delta = currentPosition - lastPos
        let distance = length(delta)
        
        if distance < deadZone {
            // Position hasn't changed enough, keep last position
            return createFilteredEvent(touchEvent, position: lastPos)
        }
        
        // Apply smoothing
        let smoothedPosition = lastPos * smoothingFactor + currentPosition * (1.0 - smoothingFactor)
        lastPosition = smoothedPosition
        
        return createFilteredEvent(touchEvent, position: smoothedPosition)
    }
    
    private func createFilteredEvent(_ originalEvent: TouchEvent, position: SIMD2<Float>) -> TouchEvent {
        var filteredTouchData = originalEvent.touchData
        filteredTouchData = TouchData(
            id: filteredTouchData.id,
            screenPosition: filteredTouchData.screenPosition,
            worldPosition: position,
            timestamp: filteredTouchData.timestamp,
            force: filteredTouchData.force,
            radius: filteredTouchData.radius
        )
        
        return TouchEvent(
            touchData: filteredTouchData,
            phase: originalEvent.phase,
            timestamp: originalEvent.timestamp
        )
    }
}

// MARK: - Supporting Types

public enum PerformanceLevel: String, CaseIterable {
    case optimal = "Optimal"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

public struct PerformanceWarning {
    public let type: WarningType
    public let currentFPS: Double?
    public let targetFPS: Double?
    public let latency: TimeInterval?
    public let timestamp: Date
    
    public init(type: WarningType, currentFPS: Double? = nil, targetFPS: Double? = nil, latency: TimeInterval? = nil) {
        self.type = type
        self.currentFPS = currentFPS
        self.targetFPS = targetFPS
        self.latency = latency
        self.timestamp = Date()
    }
}

public enum WarningType {
    case lowFrameRate
    case severePerformanceDrop
    case highInputLatency
    case memoryPressure
}

public struct PerformanceStats {
    public let averageFPS: Double
    public let averageLatency: TimeInterval
    public let droppedFrames: Int
    public let performanceLevel: PerformanceLevel
    public let metalAccelerated: Bool
}

private struct InputPerformanceMetric {
    let timestamp: Date
    let latency: TimeInterval
    let eventType: TouchPhase
}

// MARK: - Matrix Extensions

private extension simd_float4x4 {
    var inverse: simd_float4x4 {
        return simd_inverse(self)
    }
}

// MARK: - SIMD Extensions

private func length(_ vector: SIMD2<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y)
}