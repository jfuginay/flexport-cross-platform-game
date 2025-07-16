import SwiftUI
import Combine
import simd

/// Advanced gesture management system with physics-based momentum
public class AdvancedGestureManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var currentGesture: GestureType = .none
    @Published public var gestureVelocity: CGVector = .zero
    @Published public var isGestureActive = false
    @Published public var contextMenuLocation: CGPoint?
    @Published public var focusEntity: FocusableEntity?
    @Published public var edgeScrollDirection: EdgeScrollDirection = .none
    
    // MARK: - Gesture State
    private var panVelocityTracker = VelocityTracker()
    private var zoomVelocityTracker = VelocityTracker()
    private var rotationVelocityTracker = VelocityTracker()
    private var momentumTimer: Timer?
    private var edgeScrollTimer: Timer?
    
    // MARK: - Configuration
    public var config = GestureConfiguration()
    
    // MARK: - Momentum Properties
    private var panMomentum: CGVector = .zero
    private var zoomMomentum: CGFloat = 0
    private var rotationMomentum: CGFloat = 0
    
    // MARK: - Edge Scrolling
    private var edgeScrollVelocity: CGVector = .zero
    private let edgeScrollThreshold: CGFloat = 50
    private let maxEdgeScrollSpeed: CGFloat = 300
    
    // MARK: - Focus Management
    private var focusAnimationTimer: Timer?
    private var focusTargetPosition: CGPoint?
    private var focusTargetZoom: CGFloat?
    
    public init() {
        setupMomentumTimer()
    }
    
    // MARK: - Gesture Handling
    
    public func handlePanBegan(at location: CGPoint) {
        currentGesture = .pan
        isGestureActive = true
        panVelocityTracker.reset()
        panVelocityTracker.addSample(location: location)
        stopMomentum()
        HapticManager.shared.playSelectionFeedback()
    }
    
    public func handlePanChanged(at location: CGPoint, translation: CGSize) {
        panVelocityTracker.addSample(location: location)
        gestureVelocity = panVelocityTracker.currentVelocity
        
        // Check for edge scrolling
        checkEdgeScroll(at: location)
    }
    
    public func handlePanEnded() {
        isGestureActive = false
        
        // Calculate final velocity for momentum
        let velocity = panVelocityTracker.finalVelocity
        if velocity.magnitude > config.minimumMomentumVelocity {
            panMomentum = velocity
            startMomentum()
        }
        
        currentGesture = .none
        stopEdgeScroll()
        HapticManager.shared.playImpactFeedback(.light)
    }
    
    public func handlePinchBegan(scale: CGFloat) {
        currentGesture = .zoom
        isGestureActive = true
        zoomVelocityTracker.reset()
        stopMomentum()
        HapticManager.shared.playSelectionFeedback()
    }
    
    public func handlePinchChanged(scale: CGFloat) {
        zoomVelocityTracker.addZoomSample(scale: scale)
        
        // Haptic feedback at zoom milestones
        if shouldPlayZoomHaptic(for: scale) {
            HapticManager.shared.playImpactFeedback(.medium)
        }
    }
    
    public func handlePinchEnded(finalScale: CGFloat) {
        isGestureActive = false
        
        // Calculate zoom momentum
        let velocity = zoomVelocityTracker.finalZoomVelocity
        if abs(velocity) > config.minimumZoomMomentumVelocity {
            zoomMomentum = velocity
            startMomentum()
        }
        
        currentGesture = .none
        HapticManager.shared.playImpactFeedback(.medium)
    }
    
    public func handleRotationBegan(angle: Angle) {
        currentGesture = .rotation
        isGestureActive = true
        rotationVelocityTracker.reset()
        stopMomentum()
        HapticManager.shared.playSelectionFeedback()
    }
    
    public func handleRotationChanged(angle: Angle) {
        rotationVelocityTracker.addRotationSample(angle: angle.radians)
        
        // Haptic feedback at cardinal directions
        if shouldPlayRotationHaptic(for: angle) {
            HapticManager.shared.playImpactFeedback(.rigid)
        }
    }
    
    public func handleRotationEnded(finalAngle: Angle) {
        isGestureActive = false
        
        // Calculate rotation momentum
        let velocity = rotationVelocityTracker.finalRotationVelocity
        if abs(velocity) > config.minimumRotationMomentumVelocity {
            rotationMomentum = velocity
            startMomentum()
        }
        
        currentGesture = .none
        HapticManager.shared.playImpactFeedback(.medium)
    }
    
    public func handleDoubleTap(at location: CGPoint, in size: CGSize) -> FocusAction {
        // Find nearest focusable entity
        if let entity = findNearestEntity(at: location, in: size) {
            focusOnEntity(entity, animated: true)
            HapticManager.shared.playNotificationFeedback(.success)
            return .focusEntity(entity)
        } else {
            // Reset to default view
            HapticManager.shared.playImpactFeedback(.heavy)
            return .resetView
        }
    }
    
    public func handleLongPress(at location: CGPoint) {
        contextMenuLocation = location
        HapticManager.shared.playNotificationFeedback(.warning)
    }
    
    public func handleTripleTap() {
        // Toggle 3D camera mode
        HapticManager.shared.playNotificationFeedback(.success)
    }
    
    // MARK: - Edge Scrolling
    
    private func checkEdgeScroll(at location: CGPoint) {
        guard let screenBounds = UIScreen.main.bounds as CGRect? else { return }
        
        var direction = EdgeScrollDirection.none
        var velocity = CGVector.zero
        
        // Check each edge
        if location.x < edgeScrollThreshold {
            direction.insert(.left)
            let strength = 1 - (location.x / edgeScrollThreshold)
            velocity.dx = -maxEdgeScrollSpeed * strength
        } else if location.x > screenBounds.width - edgeScrollThreshold {
            direction.insert(.right)
            let strength = (location.x - (screenBounds.width - edgeScrollThreshold)) / edgeScrollThreshold
            velocity.dx = maxEdgeScrollSpeed * strength
        }
        
        if location.y < edgeScrollThreshold {
            direction.insert(.top)
            let strength = 1 - (location.y / edgeScrollThreshold)
            velocity.dy = -maxEdgeScrollSpeed * strength
        } else if location.y > screenBounds.height - edgeScrollThreshold {
            direction.insert(.bottom)
            let strength = (location.y - (screenBounds.height - edgeScrollThreshold)) / edgeScrollThreshold
            velocity.dy = maxEdgeScrollSpeed * strength
        }
        
        if direction != edgeScrollDirection {
            edgeScrollDirection = direction
            edgeScrollVelocity = velocity
            
            if direction != .none {
                startEdgeScroll()
                HapticManager.shared.playSelectionFeedback()
            } else {
                stopEdgeScroll()
            }
        }
    }
    
    private func startEdgeScroll() {
        edgeScrollTimer?.invalidate()
        edgeScrollTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.objectWillChange.send()
        }
    }
    
    private func stopEdgeScroll() {
        edgeScrollTimer?.invalidate()
        edgeScrollTimer = nil
        edgeScrollDirection = .none
        edgeScrollVelocity = .zero
    }
    
    // MARK: - Momentum
    
    private func setupMomentumTimer() {
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.updateMomentum()
        }
    }
    
    private func startMomentum() {
        // Momentum is already running via the timer
    }
    
    private func stopMomentum() {
        panMomentum = .zero
        zoomMomentum = 0
        rotationMomentum = 0
    }
    
    private func updateMomentum() {
        var hasActiveM omentum = false
        
        // Update pan momentum
        if panMomentum.magnitude > config.momentumThreshold {
            panMomentum = panMomentum * config.momentumDamping
            hasActiveMomentum = true
        } else {
            panMomentum = .zero
        }
        
        // Update zoom momentum
        if abs(zoomMomentum) > config.zoomMomentumThreshold {
            zoomMomentum *= config.zoomMomentumDamping
            hasActiveMomentum = true
        } else {
            zoomMomentum = 0
        }
        
        // Update rotation momentum
        if abs(rotationMomentum) > config.rotationMomentumThreshold {
            rotationMomentum *= config.rotationMomentumDamping
            hasActiveMomentum = true
        } else {
            rotationMomentum = 0
        }
        
        if hasActiveMomentum || edgeScrollDirection != .none {
            objectWillChange.send()
        }
    }
    
    // MARK: - Focus Management
    
    public func focusOnEntity(_ entity: FocusableEntity, animated: Bool) {
        focusEntity = entity
        
        if animated {
            // Animate to entity position and appropriate zoom
            focusTargetPosition = entity.position
            focusTargetZoom = entity.recommendedZoom
            startFocusAnimation()
        }
    }
    
    private func startFocusAnimation() {
        focusAnimationTimer?.invalidate()
        
        var progress: CGFloat = 0
        focusAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            progress += 1/60
            if progress >= config.focusAnimationDuration {
                timer.invalidate()
                self.focusAnimationTimer = nil
                self.objectWillChange.send()
            } else {
                self.objectWillChange.send()
            }
        }
    }
    
    private func findNearestEntity(at location: CGPoint, in size: CGSize) -> FocusableEntity? {
        // This would be implemented by the container using this manager
        // For now, return nil
        return nil
    }
    
    // MARK: - Haptic Helpers
    
    private func shouldPlayZoomHaptic(for scale: CGFloat) -> Bool {
        // Play haptic at specific zoom levels
        let zoomLevels: [CGFloat] = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0]
        return zoomLevels.contains(where: { abs(scale - $0) < 0.05 })
    }
    
    private func shouldPlayRotationHaptic(for angle: Angle) -> Bool {
        // Play haptic at cardinal directions
        let degrees = angle.degrees.truncatingRemainder(dividingBy: 360)
        let cardinals: [Double] = [0, 90, 180, 270]
        return cardinals.contains(where: { abs(degrees - $0) < 5 })
    }
    
    // MARK: - Public Accessors
    
    public var currentPanMomentum: CGVector {
        return panMomentum
    }
    
    public var currentZoomMomentum: CGFloat {
        return zoomMomentum
    }
    
    public var currentRotationMomentum: CGFloat {
        return rotationMomentum
    }
    
    public var currentEdgeScrollVelocity: CGVector {
        return edgeScrollVelocity
    }
    
    public func dismissContextMenu() {
        contextMenuLocation = nil
    }
}

// MARK: - Supporting Types

public enum GestureType {
    case none
    case pan
    case zoom
    case rotation
    case edgeScroll
}

public struct EdgeScrollDirection: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let none = EdgeScrollDirection([])
    public static let top = EdgeScrollDirection(rawValue: 1 << 0)
    public static let right = EdgeScrollDirection(rawValue: 1 << 1)
    public static let bottom = EdgeScrollDirection(rawValue: 1 << 2)
    public static let left = EdgeScrollDirection(rawValue: 1 << 3)
}

public struct FocusableEntity {
    public let id: UUID
    public let position: CGPoint
    public let recommendedZoom: CGFloat
    public let type: EntityType
    
    public enum EntityType {
        case port
        case ship
        case fleet
        case tradeRoute
    }
}

public enum FocusAction {
    case focusEntity(FocusableEntity)
    case resetView
}

public struct GestureConfiguration {
    // Momentum
    public var momentumDamping: CGFloat = 0.95
    public var momentumThreshold: CGFloat = 0.5
    public var minimumMomentumVelocity: CGFloat = 100
    
    // Zoom momentum
    public var zoomMomentumDamping: CGFloat = 0.9
    public var zoomMomentumThreshold: CGFloat = 0.01
    public var minimumZoomMomentumVelocity: CGFloat = 0.1
    
    // Rotation momentum
    public var rotationMomentumDamping: CGFloat = 0.92
    public var rotationMomentumThreshold: CGFloat = 0.01
    public var minimumRotationMomentumVelocity: CGFloat = 0.1
    
    // Animation
    public var focusAnimationDuration: TimeInterval = 0.6
    
    // Edge scrolling
    public var edgeScrollEnabled = true
    public var edgeScrollThreshold: CGFloat = 50
    public var maxEdgeScrollSpeed: CGFloat = 300
}

// MARK: - Velocity Tracking

private class VelocityTracker {
    private var samples: [(location: CGPoint, time: TimeInterval)] = []
    private var zoomSamples: [(scale: CGFloat, time: TimeInterval)] = []
    private var rotationSamples: [(angle: Double, time: TimeInterval)] = []
    private let maxSamples = 10
    
    func reset() {
        samples.removeAll()
        zoomSamples.removeAll()
        rotationSamples.removeAll()
    }
    
    func addSample(location: CGPoint) {
        let time = CACurrentMediaTime()
        samples.append((location: location, time: time))
        
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }
    
    func addZoomSample(scale: CGFloat) {
        let time = CACurrentMediaTime()
        zoomSamples.append((scale: scale, time: time))
        
        if zoomSamples.count > maxSamples {
            zoomSamples.removeFirst()
        }
    }
    
    func addRotationSample(angle: Double) {
        let time = CACurrentMediaTime()
        rotationSamples.append((angle: angle, time: time))
        
        if rotationSamples.count > maxSamples {
            rotationSamples.removeFirst()
        }
    }
    
    var currentVelocity: CGVector {
        guard samples.count >= 2 else { return .zero }
        
        let recent = samples.suffix(3)
        guard recent.count >= 2 else { return .zero }
        
        let first = recent.first!
        let last = recent.last!
        let timeDelta = last.time - first.time
        
        guard timeDelta > 0 else { return .zero }
        
        let dx = (last.location.x - first.location.x) / CGFloat(timeDelta)
        let dy = (last.location.y - first.location.y) / CGFloat(timeDelta)
        
        return CGVector(dx: dx, dy: dy)
    }
    
    var finalVelocity: CGVector {
        return currentVelocity
    }
    
    var finalZoomVelocity: CGFloat {
        guard zoomSamples.count >= 2 else { return 0 }
        
        let recent = zoomSamples.suffix(3)
        guard recent.count >= 2 else { return 0 }
        
        let first = recent.first!
        let last = recent.last!
        let timeDelta = last.time - first.time
        
        guard timeDelta > 0 else { return 0 }
        
        return (last.scale - first.scale) / CGFloat(timeDelta)
    }
    
    var finalRotationVelocity: CGFloat {
        guard rotationSamples.count >= 2 else { return 0 }
        
        let recent = rotationSamples.suffix(3)
        guard recent.count >= 2 else { return 0 }
        
        let first = recent.first!
        let last = recent.last!
        let timeDelta = last.time - first.time
        
        guard timeDelta > 0 else { return 0 }
        
        return CGFloat(last.angle - first.angle) / CGFloat(timeDelta)
    }
}

// MARK: - CGVector Extensions

extension CGVector {
    var magnitude: CGFloat {
        return sqrt(dx * dx + dy * dy)
    }
    
    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        return CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }
}