import SwiftUI
import simd
import Combine

/// Advanced camera controller with 3D rotation and smooth transitions
public class CameraController: ObservableObject {
    // MARK: - Published Properties
    @Published public var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published public var rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published public var zoom: Float = 1.0
    @Published public var fieldOfView: Float = 60.0
    @Published public var is3DMode: Bool = false
    @Published public var viewMatrix: float4x4 = float4x4(1)
    @Published public var projectionMatrix: float4x4 = float4x4(1)
    
    // MARK: - Camera Constraints
    public var constraints = CameraConstraints()
    
    // MARK: - Animation State
    private var animationTimer: Timer?
    private var animations: [CameraAnimation] = []
    
    // MARK: - Smooth Following
    private var followTarget: FollowTarget?
    private var followOffset: SIMD3<Float> = SIMD3<Float>(0, 5, 10)
    
    // MARK: - Orbit Camera
    private var orbitCenter: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var orbitRadius: Float = 10.0
    private var orbitAngles: SIMD2<Float> = SIMD2<Float>(0, 0) // (azimuth, elevation)
    
    public init() {
        setupUpdateTimer()
        updateMatrices()
    }
    
    // MARK: - Camera Control
    
    public func pan(by delta: CGVector, screenSize: CGSize) {
        let sensitivity = constraints.panSensitivity / zoom
        let worldDelta = screenToWorldDelta(delta, screenSize: screenSize)
        
        if is3DMode {
            // In 3D mode, pan moves the camera in the view plane
            let right = getRightVector()
            let up = getUpVector()
            
            position += right * worldDelta.x * sensitivity
            position += up * worldDelta.y * sensitivity
        } else {
            // In 2D mode, pan moves the camera in the XZ plane
            position.x += worldDelta.x * sensitivity
            position.z += worldDelta.y * sensitivity
        }
        
        clampPosition()
        updateMatrices()
    }
    
    public func zoom(by factor: Float, focusPoint: CGPoint? = nil, screenSize: CGSize) {
        let oldZoom = zoom
        zoom *= factor
        zoom = simd_clamp(zoom, constraints.minZoom, constraints.maxZoom)
        
        // Zoom towards focus point if provided
        if let focusPoint = focusPoint, zoom != oldZoom {
            let zoomDelta = zoom / oldZoom
            let screenCenter = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
            let offset = CGVector(
                dx: (focusPoint.x - screenCenter.x) * (1 - 1 / zoomDelta),
                dy: (focusPoint.y - screenCenter.y) * (1 - 1 / zoomDelta)
            )
            pan(by: offset, screenSize: screenSize)
        }
        
        updateMatrices()
    }
    
    public func rotate(by angles: SIMD2<Float>) {
        if is3DMode {
            orbitAngles += angles * constraints.rotationSensitivity
            orbitAngles.y = simd_clamp(orbitAngles.y, constraints.minElevation, constraints.maxElevation)
            updateOrbitPosition()
        } else {
            // In 2D mode, only allow yaw rotation
            rotation.y += angles.x * constraints.rotationSensitivity
        }
        
        updateMatrices()
    }
    
    public func setFieldOfView(_ fov: Float) {
        fieldOfView = simd_clamp(fov, constraints.minFieldOfView, constraints.maxFieldOfView)
        updateMatrices()
    }
    
    public func toggle3DMode() {
        is3DMode.toggle()
        
        if is3DMode {
            // Transition to 3D view
            animateToPosition(
                position: SIMD3<Float>(position.x, 10, position.z + 10),
                rotation: SIMD3<Float>(-30 * .pi / 180, 0, 0),
                zoom: zoom * 0.8,
                duration: 0.6
            )
        } else {
            // Transition to 2D view
            animateToPosition(
                position: SIMD3<Float>(position.x, 20, position.z),
                rotation: SIMD3<Float>(-.pi / 2, 0, 0),
                zoom: zoom * 1.25,
                duration: 0.6
            )
        }
    }
    
    // MARK: - Focus and Animation
    
    public func focusOn(position: SIMD3<Float>, zoom: Float? = nil, animated: Bool = true) {
        let targetPosition = SIMD3<Float>(position.x, self.position.y, position.z)
        let targetZoom = zoom ?? calculateOptimalZoom(for: position)
        
        if animated {
            animateToPosition(position: targetPosition, zoom: targetZoom, duration: 0.6)
        } else {
            self.position = targetPosition
            self.zoom = targetZoom
            updateMatrices()
        }
    }
    
    public func focusOnRegion(min: SIMD3<Float>, max: SIMD3<Float>, animated: Bool = true) {
        let center = (min + max) * 0.5
        let size = max - min
        let maxDimension = max(size.x, size.z)
        let targetZoom = calculateZoomForSize(maxDimension)
        
        focusOn(position: center, zoom: targetZoom, animated: animated)
    }
    
    public func followEntity(_ target: FollowTarget, offset: SIMD3<Float>? = nil) {
        followTarget = target
        if let offset = offset {
            followOffset = offset
        }
    }
    
    public func stopFollowing() {
        followTarget = nil
    }
    
    public func resetView(animated: Bool = true) {
        if animated {
            animateToPosition(
                position: SIMD3<Float>(0, 20, 0),
                rotation: is3DMode ? SIMD3<Float>(-30 * .pi / 180, 0, 0) : SIMD3<Float>(-.pi / 2, 0, 0),
                zoom: 1.0,
                duration: 0.8
            )
        } else {
            position = SIMD3<Float>(0, 20, 0)
            rotation = is3DMode ? SIMD3<Float>(-30 * .pi / 180, 0, 0) : SIMD3<Float>(-.pi / 2, 0, 0)
            zoom = 1.0
            updateMatrices()
        }
    }
    
    // MARK: - Orbit Camera
    
    public func setOrbitCenter(_ center: SIMD3<Float>) {
        orbitCenter = center
        updateOrbitPosition()
    }
    
    public func orbitBy(azimuth: Float, elevation: Float) {
        orbitAngles.x += azimuth
        orbitAngles.y = simd_clamp(orbitAngles.y + elevation, constraints.minElevation, constraints.maxElevation)
        updateOrbitPosition()
    }
    
    private func updateOrbitPosition() {
        let x = orbitRadius * cos(orbitAngles.y) * sin(orbitAngles.x)
        let y = orbitRadius * sin(orbitAngles.y)
        let z = orbitRadius * cos(orbitAngles.y) * cos(orbitAngles.x)
        
        position = orbitCenter + SIMD3<Float>(x, y, z)
        
        // Look at orbit center
        let forward = normalize(orbitCenter - position)
        let right = normalize(cross(SIMD3<Float>(0, 1, 0), forward))
        let up = cross(forward, right)
        
        // Convert to euler angles
        rotation.x = atan2(forward.y, sqrt(forward.x * forward.x + forward.z * forward.z))
        rotation.y = atan2(-forward.x, -forward.z)
        
        updateMatrices()
    }
    
    // MARK: - Animation
    
    private func animateToPosition(
        position: SIMD3<Float>? = nil,
        rotation: SIMD3<Float>? = nil,
        zoom: Float? = nil,
        duration: TimeInterval
    ) {
        let animation = CameraAnimation(
            startPosition: self.position,
            targetPosition: position ?? self.position,
            startRotation: self.rotation,
            targetRotation: rotation ?? self.rotation,
            startZoom: self.zoom,
            targetZoom: zoom ?? self.zoom,
            duration: duration,
            startTime: CACurrentMediaTime(),
            easing: .easeInOut
        )
        
        animations.append(animation)
    }
    
    private func setupUpdateTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    private func update() {
        // Update follow target
        if let target = followTarget {
            let targetPosition = target.position + followOffset
            let delta = targetPosition - position
            position += delta * constraints.followSmoothness
        }
        
        // Update animations
        let currentTime = CACurrentMediaTime()
        animations = animations.filter { animation in
            let progress = min(1.0, Float((currentTime - animation.startTime) / animation.duration))
            
            if progress >= 1.0 {
                position = animation.targetPosition
                rotation = animation.targetRotation
                zoom = animation.targetZoom
                updateMatrices()
                return false
            }
            
            let t = animation.easing.apply(progress)
            position = mix(animation.startPosition, animation.targetPosition, t)
            rotation = mix(animation.startRotation, animation.targetRotation, t)
            zoom = mix(animation.startZoom, animation.targetZoom, t)
            updateMatrices()
            return true
        }
    }
    
    // MARK: - Matrix Calculation
    
    private func updateMatrices() {
        viewMatrix = calculateViewMatrix()
        projectionMatrix = calculateProjectionMatrix()
        objectWillChange.send()
    }
    
    private func calculateViewMatrix() -> float4x4 {
        var transform = float4x4(1)
        
        // Apply rotation
        transform = transform * float4x4(rotationX: rotation.x)
        transform = transform * float4x4(rotationY: rotation.y)
        transform = transform * float4x4(rotationZ: rotation.z)
        
        // Apply translation
        transform = transform * float4x4(translation: -position)
        
        // Apply zoom as a scale
        transform = transform * float4x4(scale: SIMD3<Float>(repeating: 1.0 / zoom))
        
        return transform
    }
    
    private func calculateProjectionMatrix() -> float4x4 {
        let aspect = constraints.aspectRatio
        let fov = fieldOfView * .pi / 180
        let near = constraints.nearPlane
        let far = constraints.farPlane
        
        if constraints.isOrthographic && !is3DMode {
            // Orthographic projection for 2D mode
            let height = 20.0 / zoom
            let width = height * aspect
            return float4x4(orthographicProjection: 
                left: -width/2, right: width/2,
                bottom: -height/2, top: height/2,
                near: near, far: far
            )
        } else {
            // Perspective projection for 3D mode
            return float4x4(perspectiveProjection:
                fov: fov, aspect: aspect,
                near: near, far: far
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func screenToWorldDelta(_ screenDelta: CGVector, screenSize: CGSize) -> SIMD2<Float> {
        let worldWidth = Float(20.0 / zoom)
        let worldHeight = worldWidth / constraints.aspectRatio
        
        return SIMD2<Float>(
            Float(screenDelta.dx / screenSize.width) * worldWidth,
            Float(screenDelta.dy / screenSize.height) * worldHeight
        )
    }
    
    private func getRightVector() -> SIMD3<Float> {
        let transform = float4x4(rotationY: rotation.y) * float4x4(rotationX: rotation.x)
        return normalize(SIMD3<Float>(transform[0][0], transform[1][0], transform[2][0]))
    }
    
    private func getUpVector() -> SIMD3<Float> {
        let transform = float4x4(rotationY: rotation.y) * float4x4(rotationX: rotation.x)
        return normalize(SIMD3<Float>(transform[0][1], transform[1][1], transform[2][1]))
    }
    
    private func clampPosition() {
        position.x = simd_clamp(position.x, constraints.minPosition.x, constraints.maxPosition.x)
        position.y = simd_clamp(position.y, constraints.minPosition.y, constraints.maxPosition.y)
        position.z = simd_clamp(position.z, constraints.minPosition.z, constraints.maxPosition.z)
    }
    
    private func calculateOptimalZoom(for position: SIMD3<Float>) -> Float {
        // Calculate zoom based on position and current view
        return 2.0
    }
    
    private func calculateZoomForSize(_ size: Float) -> Float {
        return max(constraints.minZoom, min(constraints.maxZoom, 20.0 / size))
    }
}

// MARK: - Supporting Types

public struct CameraConstraints {
    public var minZoom: Float = 0.1
    public var maxZoom: Float = 10.0
    public var minPosition = SIMD3<Float>(-100, -50, -100)
    public var maxPosition = SIMD3<Float>(100, 50, 100)
    public var minElevation: Float = -80 * .pi / 180
    public var maxElevation: Float = 80 * .pi / 180
    public var minFieldOfView: Float = 30.0
    public var maxFieldOfView: Float = 120.0
    public var panSensitivity: Float = 1.0
    public var rotationSensitivity: Float = 0.01
    public var followSmoothness: Float = 0.1
    public var aspectRatio: Float = 16.0 / 9.0
    public var nearPlane: Float = 0.1
    public var farPlane: Float = 1000.0
    public var isOrthographic: Bool = false
}

public struct FollowTarget {
    public let position: SIMD3<Float>
    public let velocity: SIMD3<Float>?
    public let rotation: SIMD3<Float>?
}

private struct CameraAnimation {
    let startPosition: SIMD3<Float>
    let targetPosition: SIMD3<Float>
    let startRotation: SIMD3<Float>
    let targetRotation: SIMD3<Float>
    let startZoom: Float
    let targetZoom: Float
    let duration: TimeInterval
    let startTime: TimeInterval
    let easing: EasingFunction
}

private enum EasingFunction {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    
    func apply(_ t: Float) -> Float {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return t * (2 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
        }
    }
}

// MARK: - Matrix Extensions

extension float4x4 {
    init(rotationX angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, c, s, 0),
            SIMD4<Float>(0, -s, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(rotationY angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, 0, -s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(rotationZ angle: Float) {
        let c = cos(angle)
        let s = sin(angle)
        self.init(
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(translation: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }
    
    init(scale: SIMD3<Float>) {
        self.init(
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(orthographicProjection left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let rl = right - left
        let tb = top - bottom
        let fn = far - near
        
        self.init(
            SIMD4<Float>(2 / rl, 0, 0, 0),
            SIMD4<Float>(0, 2 / tb, 0, 0),
            SIMD4<Float>(0, 0, -2 / fn, 0),
            SIMD4<Float>(-(right + left) / rl, -(top + bottom) / tb, -(far + near) / fn, 1)
        )
    }
    
    init(perspectiveProjection fov: Float, aspect: Float, near: Float, far: Float) {
        let yScale = 1 / tan(fov * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        self.init(
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        )
    }
}