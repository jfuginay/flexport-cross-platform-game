import UIKit
import Combine
import simd

/// Advanced gesture detection system for complex multi-touch gestures
public class GestureDetector: ObservableObject {
    
    // MARK: - Publishers
    public let complexGestureDetected = PassthroughSubject<GestureEvent, Never>()
    public let gestureSequenceDetected = PassthroughSubject<GestureSequence, Never>()
    
    // MARK: - Configuration
    public struct Configuration {
        public var swipeVelocityThreshold: Float = 500.0
        public var swipeDistanceThreshold: Float = 50.0
        public var rotationAngleThreshold: Float = 0.1 // radians
        public var multiTouchTimeWindow: TimeInterval = 0.5
        public var gestureSequenceTimeout: TimeInterval = 2.0
        public var smoothingFactor: Float = 0.8
        
        public init() {}
    }
    
    // MARK: - Properties
    @Published public private(set) var activeGestures: Set<GestureType> = []
    @Published public private(set) var gestureVelocity: SIMD2<Float> = SIMD2<Float>(0, 0)
    @Published public private(set) var gestureAcceleration: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    public var configuration = Configuration()
    
    // MARK: - Internal State
    private var touchHistory: [TouchHistoryEntry] = []
    private var gestureSequence: [GestureType] = []
    private var lastGestureTime: Date = Date()
    private var velocityHistory: [SIMD2<Float>] = []
    private var accelerationHistory: [SIMD2<Float>] = []
    
    // For multi-touch gesture analysis
    private var currentMultiTouchGesture: MultiTouchGestureAnalyzer?
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Public Interface
    
    /// Process touch data and detect complex gestures
    public func processTouchData(_ touchData: TouchData, history: [TouchData]) {
        updateTouchHistory(touchData)
        updateVelocityAndAcceleration()
        
        // Analyze single touch gestures
        analyzeSingleTouchGestures()
        
        // Analyze multi-touch gestures
        analyzeMultiTouchGestures(history)
        
        // Clean up old history
        cleanupHistory()
    }
    
    /// Detect gesture sequences (e.g., double tap, triple tap, complex combinations)
    public func detectGestureSequences(_ gesture: GestureType) {
        let now = Date()
        
        // Check if this gesture is part of a sequence
        if now.timeIntervalSince(lastGestureTime) < configuration.gestureSequenceTimeout {
            gestureSequence.append(gesture)
        } else {
            // Start new sequence
            gestureSequence = [gesture]
        }
        
        lastGestureTime = now
        
        // Analyze current sequence
        analyzeGestureSequence()
    }
    
    // MARK: - Private Implementation
    
    private func updateTouchHistory(_ touchData: TouchData) {
        let entry = TouchHistoryEntry(
            touchData: touchData,
            timestamp: Date()
        )
        
        touchHistory.append(entry)
        
        // Keep only last 120 entries (2 seconds at 60fps)
        if touchHistory.count > 120 {
            touchHistory.removeFirst(touchHistory.count - 120)
        }
    }
    
    private func updateVelocityAndAcceleration() {
        guard touchHistory.count >= 2 else { return }
        
        let latest = touchHistory[touchHistory.count - 1]
        let previous = touchHistory[touchHistory.count - 2]
        
        let deltaTime = Float(latest.timestamp.timeIntervalSince(previous.timestamp))
        guard deltaTime > 0 else { return }
        
        let deltaPosition = latest.touchData.worldPosition - previous.touchData.worldPosition
        let currentVelocity = deltaPosition / deltaTime
        
        // Apply smoothing
        let smoothedVelocity = gestureVelocity * configuration.smoothingFactor + 
                              currentVelocity * (1.0 - configuration.smoothingFactor)
        
        // Calculate acceleration
        let deltaVelocity = smoothedVelocity - gestureVelocity
        let currentAcceleration = deltaVelocity / deltaTime
        
        gestureVelocity = smoothedVelocity
        gestureAcceleration = currentAcceleration
        
        // Update history for analysis
        velocityHistory.append(gestureVelocity)
        accelerationHistory.append(gestureAcceleration)
        
        if velocityHistory.count > 60 {
            velocityHistory.removeFirst()
        }
        if accelerationHistory.count > 60 {
            accelerationHistory.removeFirst()
        }
    }
    
    private func analyzeSingleTouchGestures() {
        guard !touchHistory.isEmpty else { return }
        
        // Detect swipes
        detectSwipeGestures()
        
        // Detect hover gestures (if supported)
        detectHoverGestures()
    }
    
    private func detectSwipeGestures() {
        guard velocityHistory.count >= 5 else { return }
        
        let currentSpeed = length(gestureVelocity)
        guard currentSpeed > configuration.swipeVelocityThreshold else { return }
        
        // Check for consistent direction over recent history
        let recentVelocities = Array(velocityHistory.suffix(5))
        let avgDirection = recentVelocities.reduce(SIMD2<Float>(0, 0), +) / Float(recentVelocities.count)
        let normalizedDirection = normalize(avgDirection)
        
        // Check if movement is consistent in direction
        let consistency = recentVelocities.map { dot(normalize($0), normalizedDirection) }.reduce(0, +) / Float(recentVelocities.count)
        
        if consistency > 0.8 { // 80% consistency threshold
            let swipeDirection = getSwipeDirection(normalizedDirection)
            emitGestureEvent(.swipe, properties: [
                "direction": swipeDirection,
                "velocity": currentSpeed,
                "consistency": consistency
            ])
        }
    }
    
    private func detectHoverGestures() {
        // Check for minimal movement over extended period
        guard touchHistory.count >= 30 else { return }
        
        let recentHistory = Array(touchHistory.suffix(30))
        let positions = recentHistory.map { $0.touchData.worldPosition }
        
        let avgPosition = positions.reduce(SIMD2<Float>(0, 0), +) / Float(positions.count)
        let maxDeviation = positions.map { length($0 - avgPosition) }.max() ?? 0
        
        if maxDeviation < 5.0 { // Very small movement threshold
            emitGestureEvent(.hover, properties: [
                "position": avgPosition,
                "stability": 1.0 - (maxDeviation / 5.0),
                "duration": recentHistory.last!.timestamp.timeIntervalSince(recentHistory.first!.timestamp)
            ])
        }
    }
    
    private func analyzeMultiTouchGestures(_ history: [TouchData]) {
        let currentTouches = Set(history.suffix(5)) // Get recent touches
        let touchCount = currentTouches.count
        
        switch touchCount {
        case 2:
            analyzeTwoFingerGestures(Array(currentTouches))
        case 3:
            analyzeThreeFingerGestures(Array(currentTouches))
        case 4:
            analyzeFourFingerGestures(Array(currentTouches))
        default:
            break
        }
    }
    
    private func analyzeTwoFingerGestures(_ touches: [TouchData]) {
        guard touches.count == 2 else { return }
        
        let touch1 = touches[0]
        let touch2 = touches[1]
        
        // Calculate center point and distance
        let center = (touch1.worldPosition + touch2.worldPosition) * 0.5
        let distance = length(touch1.worldPosition - touch2.worldPosition)
        let angle = atan2(touch2.worldPosition.y - touch1.worldPosition.y, 
                         touch2.worldPosition.x - touch1.worldPosition.x)
        
        // Store in multi-touch analyzer
        if currentMultiTouchGesture == nil {
            currentMultiTouchGesture = MultiTouchGestureAnalyzer(touchCount: 2)
        }
        
        currentMultiTouchGesture?.addDataPoint(center: center, distance: distance, angle: angle)
        
        // Analyze for rotation
        if let analyzer = currentMultiTouchGesture {
            if let rotationDelta = analyzer.getRotationDelta() {
                if abs(rotationDelta) > configuration.rotationAngleThreshold {
                    emitGestureEvent(.rotation, properties: [
                        "angle": rotationDelta,
                        "center": center,
                        "radius": distance * 0.5
                    ])
                }
            }
        }
        
        // Check for two-finger tap
        if touch1.timestamp.timeIntervalSince(touch2.timestamp) < 0.1 {
            emitGestureEvent(.twoFingerTap, properties: [
                "center": center,
                "separation": distance
            ])
        }
    }
    
    private func analyzeThreeFingerGestures(_ touches: [TouchData]) {
        guard touches.count == 3 else { return }
        
        let center = touches.reduce(SIMD2<Float>(0, 0)) { $0 + $1.worldPosition } / 3.0
        
        // Check for simultaneous three-finger tap
        let maxTimeDiff = touches.map { $0.timestamp }.max()!.timeIntervalSince(
            touches.map { $0.timestamp }.min()!
        )
        
        if maxTimeDiff < 0.1 {
            emitGestureEvent(.threeFingerTap, properties: [
                "center": center
            ])
        }
    }
    
    private func analyzeFourFingerGestures(_ touches: [TouchData]) {
        guard touches.count == 4 else { return }
        
        let center = touches.reduce(SIMD2<Float>(0, 0)) { $0 + $1.worldPosition } / 4.0
        
        // Check for simultaneous four-finger tap
        let maxTimeDiff = touches.map { $0.timestamp }.max()!.timeIntervalSince(
            touches.map { $0.timestamp }.min()!
        )
        
        if maxTimeDiff < 0.1 {
            emitGestureEvent(.fourFingerTap, properties: [
                "center": center
            ])
        }
    }
    
    private func analyzeGestureSequence() {
        // Detect common gesture sequences
        if gestureSequence.count >= 2 {
            let sequence = GestureSequence(gestures: gestureSequence, timeSpan: configuration.gestureSequenceTimeout)
            gestureSequenceDetected.send(sequence)
        }
    }
    
    private func cleanupHistory() {
        let cutoffTime = Date().addingTimeInterval(-5.0) // Keep 5 seconds of history
        touchHistory.removeAll { $0.timestamp < cutoffTime }
        
        // Reset multi-touch analyzer if no recent activity
        if let analyzer = currentMultiTouchGesture,
           analyzer.lastUpdateTime < cutoffTime {
            currentMultiTouchGesture = nil
        }
    }
    
    private func emitGestureEvent(_ type: GestureType, properties: [String: Any] = [:]) {
        guard !activeGestures.contains(type) else { return }
        
        activeGestures.insert(type)
        
        let location = touchHistory.last?.touchData.worldPosition ?? SIMD2<Float>(0, 0)
        let event = GestureEvent(
            type: type,
            state: .began,
            location: location,
            timestamp: Date(),
            properties: properties
        )
        
        complexGestureDetected.send(event)
        
        // Auto-remove after short delay to allow for immediate re-detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.activeGestures.remove(type)
        }
    }
    
    private func getSwipeDirection(_ direction: SIMD2<Float>) -> SwipeDirection {
        let angle = atan2(direction.y, direction.x)
        let degrees = angle * 180.0 / .pi
        
        switch degrees {
        case -45...45:
            return .right
        case 45...135:
            return .up
        case 135...180, -180...(-135):
            return .left
        case -135...(-45):
            return .down
        default:
            return .right
        }
    }
}

// MARK: - Supporting Types

private struct TouchHistoryEntry {
    let touchData: TouchData
    let timestamp: Date
}

private class MultiTouchGestureAnalyzer {
    let touchCount: Int
    var lastUpdateTime: Date = Date()
    
    private var centerHistory: [SIMD2<Float>] = []
    private var distanceHistory: [Float] = []
    private var angleHistory: [Float] = []
    
    init(touchCount: Int) {
        self.touchCount = touchCount
    }
    
    func addDataPoint(center: SIMD2<Float>, distance: Float, angle: Float) {
        lastUpdateTime = Date()
        
        centerHistory.append(center)
        distanceHistory.append(distance)
        angleHistory.append(angle)
        
        // Keep only recent history
        let maxPoints = 30
        if centerHistory.count > maxPoints {
            centerHistory.removeFirst()
            distanceHistory.removeFirst()
            angleHistory.removeFirst()
        }
    }
    
    func getRotationDelta() -> Float? {
        guard angleHistory.count >= 2 else { return nil }
        
        let current = angleHistory.last!
        let previous = angleHistory[angleHistory.count - 2]
        
        var delta = current - previous
        
        // Handle angle wrapping
        if delta > .pi {
            delta -= 2 * .pi
        } else if delta < -.pi {
            delta += 2 * .pi
        }
        
        return delta
    }
    
    func getScaleDelta() -> Float? {
        guard distanceHistory.count >= 2 else { return nil }
        
        let current = distanceHistory.last!
        let previous = distanceHistory[distanceHistory.count - 2]
        
        guard previous > 0 else { return nil }
        
        return current / previous
    }
}

public struct GestureSequence {
    public let gestures: [GestureType]
    public let timeSpan: TimeInterval
    public let timestamp: Date
    
    public init(gestures: [GestureType], timeSpan: TimeInterval) {
        self.gestures = gestures
        self.timeSpan = timeSpan
        self.timestamp = Date()
    }
    
    public var isDoubleTap: Bool {
        return gestures.count == 2 && gestures.allSatisfy { $0 == .tap }
    }
    
    public var isTripleTap: Bool {
        return gestures.count == 3 && gestures.allSatisfy { $0 == .tap }
    }
}

public enum SwipeDirection: String, CaseIterable {
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
    case upLeft = "upLeft"
    case upRight = "upRight"
    case downLeft = "downLeft"
    case downRight = "downRight"
}

// MARK: - SIMD Extensions

private func length(_ vector: SIMD2<Float>) -> Float {
    return sqrt(vector.x * vector.x + vector.y * vector.y)
}

private func normalize(_ vector: SIMD2<Float>) -> SIMD2<Float> {
    let len = length(vector)
    return len > 0 ? vector / len : vector
}

private func dot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    return a.x * b.x + a.y * b.y
}