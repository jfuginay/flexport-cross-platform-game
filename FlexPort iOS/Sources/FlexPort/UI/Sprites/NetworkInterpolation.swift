import Foundation
import simd

/// Manages smooth interpolation of sprite positions and states for network updates
class NetworkInterpolation {
    
    // MARK: - Interpolation State
    
    struct InterpolationState<T> {
        var current: T
        var target: T
        var startValue: T
        var startTime: CFTimeInterval
        var duration: CFTimeInterval
        var lastUpdateTime: CFTimeInterval
        
        var progress: Float {
            guard duration > 0 else { return 1.0 }
            let elapsed = CACurrentMediaTime() - startTime
            return Float(min(1.0, elapsed / duration))
        }
        
        var isComplete: Bool {
            progress >= 1.0
        }
    }
    
    // MARK: - Entity States
    
    struct ShipNetworkState {
        var positionInterp: InterpolationState<SIMD2<Float>>
        var rotationInterp: InterpolationState<Float>
        var speedInterp: InterpolationState<Float>
        var damageInterp: InterpolationState<Float>?
        
        // Prediction data
        var velocity: SIMD2<Float>
        var angularVelocity: Float
        var lastServerUpdate: CFTimeInterval
        
        // Lag compensation
        var serverPosition: SIMD2<Float>
        var clientPosition: SIMD2<Float>
        var positionError: SIMD2<Float>
        
        // Smoothing parameters
        var smoothingFactor: Float = 0.9
        var predictionEnabled: Bool = true
    }
    
    struct PortNetworkState {
        var activityInterp: InterpolationState<Float>
        var inventoryLevels: [String: InterpolationState<Float>]
        var lastUpdateTime: CFTimeInterval
    }
    
    // MARK: - Properties
    
    private var shipStates: [UUID: ShipNetworkState] = [:]
    private var portStates: [UUID: PortNetworkState] = [:]
    
    // Network settings
    private var networkLatency: CFTimeInterval = 0.1 // 100ms average latency
    private var jitterBuffer: CFTimeInterval = 0.05 // 50ms jitter buffer
    private var updateRate: CFTimeInterval = 1.0 / 20.0 // 20 updates per second
    
    // Interpolation settings
    private let positionLerpSpeed: Float = 10.0
    private let rotationLerpSpeed: Float = 5.0
    private let maxExtrapolationTime: CFTimeInterval = 0.5
    
    // MARK: - Ship Updates
    
    func updateShipFromNetwork(
        shipID: UUID,
        position: SIMD2<Float>,
        rotation: Float,
        speed: Float,
        timestamp: CFTimeInterval
    ) {
        let currentTime = CACurrentMediaTime()
        let serverTime = timestamp + networkLatency
        
        if var state = shipStates[shipID] {
            // Calculate velocity from position change
            let timeDelta = serverTime - state.lastServerUpdate
            if timeDelta > 0 {
                let positionDelta = position - state.serverPosition
                state.velocity = positionDelta / Float(timeDelta)
            }
            
            // Update interpolation targets
            state.positionInterp = InterpolationState(
                current: state.positionInterp.current,
                target: position,
                startValue: state.positionInterp.current,
                startTime: currentTime,
                duration: updateRate + jitterBuffer,
                lastUpdateTime: currentTime
            )
            
            state.rotationInterp = InterpolationState(
                current: state.rotationInterp.current,
                target: rotation,
                startValue: state.rotationInterp.current,
                startTime: currentTime,
                duration: updateRate + jitterBuffer,
                lastUpdateTime: currentTime
            )
            
            state.speedInterp = InterpolationState(
                current: state.speedInterp.current,
                target: speed,
                startValue: state.speedInterp.current,
                startTime: currentTime,
                duration: updateRate,
                lastUpdateTime: currentTime
            )
            
            state.serverPosition = position
            state.lastServerUpdate = serverTime
            
            // Calculate position error for smoothing
            state.positionError = state.clientPosition - position
            
            shipStates[shipID] = state
        } else {
            // Create new state
            let newState = ShipNetworkState(
                positionInterp: InterpolationState(
                    current: position,
                    target: position,
                    startValue: position,
                    startTime: currentTime,
                    duration: 0,
                    lastUpdateTime: currentTime
                ),
                rotationInterp: InterpolationState(
                    current: rotation,
                    target: rotation,
                    startValue: rotation,
                    startTime: currentTime,
                    duration: 0,
                    lastUpdateTime: currentTime
                ),
                speedInterp: InterpolationState(
                    current: speed,
                    target: speed,
                    startValue: speed,
                    startTime: currentTime,
                    duration: 0,
                    lastUpdateTime: currentTime
                ),
                velocity: .zero,
                angularVelocity: 0,
                lastServerUpdate: serverTime,
                serverPosition: position,
                clientPosition: position,
                positionError: .zero
            )
            
            shipStates[shipID] = newState
        }
    }
    
    func updateShipDamageFromNetwork(
        shipID: UUID,
        damageLevel: Float,
        timestamp: CFTimeInterval
    ) {
        guard var state = shipStates[shipID] else { return }
        
        let currentTime = CACurrentMediaTime()
        
        state.damageInterp = InterpolationState(
            current: state.damageInterp?.current ?? 0,
            target: damageLevel,
            startValue: state.damageInterp?.current ?? 0,
            startTime: currentTime,
            duration: 1.0, // 1 second for damage transitions
            lastUpdateTime: currentTime
        )
        
        shipStates[shipID] = state
    }
    
    // MARK: - Port Updates
    
    func updatePortFromNetwork(
        portID: UUID,
        activityLevel: Float,
        inventoryLevels: [String: Float],
        timestamp: CFTimeInterval
    ) {
        let currentTime = CACurrentMediaTime()
        
        if var state = portStates[portID] {
            // Update activity interpolation
            state.activityInterp = InterpolationState(
                current: state.activityInterp.current,
                target: activityLevel,
                startValue: state.activityInterp.current,
                startTime: currentTime,
                duration: 2.0, // Slower transitions for ports
                lastUpdateTime: currentTime
            )
            
            // Update inventory levels
            for (commodity, level) in inventoryLevels {
                let currentLevel = state.inventoryLevels[commodity]?.current ?? 0
                state.inventoryLevels[commodity] = InterpolationState(
                    current: currentLevel,
                    target: level,
                    startValue: currentLevel,
                    startTime: currentTime,
                    duration: 3.0,
                    lastUpdateTime: currentTime
                )
            }
            
            state.lastUpdateTime = currentTime
            portStates[portID] = state
        } else {
            // Create new state
            var inventoryInterps: [String: InterpolationState<Float>] = [:]
            for (commodity, level) in inventoryLevels {
                inventoryInterps[commodity] = InterpolationState(
                    current: level,
                    target: level,
                    startValue: level,
                    startTime: currentTime,
                    duration: 0,
                    lastUpdateTime: currentTime
                )
            }
            
            let newState = PortNetworkState(
                activityInterp: InterpolationState(
                    current: activityLevel,
                    target: activityLevel,
                    startValue: activityLevel,
                    startTime: currentTime,
                    duration: 0,
                    lastUpdateTime: currentTime
                ),
                inventoryLevels: inventoryInterps,
                lastUpdateTime: currentTime
            )
            
            portStates[portID] = newState
        }
    }
    
    // MARK: - Update & Interpolation
    
    func update(deltaTime: Float, ships: inout [ShipSprite], ports: inout [PortSprite]) {
        let currentTime = CACurrentMediaTime()
        
        // Update ships
        for i in 0..<ships.count {
            if let state = shipStates[ships[i].id] {
                updateShipInterpolation(&ships[i], state: state, deltaTime: deltaTime, currentTime: currentTime)
            }
        }
        
        // Update ports
        for i in 0..<ports.count {
            if let state = portStates[ports[i].id] {
                updatePortInterpolation(&ports[i], state: state, deltaTime: deltaTime, currentTime: currentTime)
            }
        }
    }
    
    private func updateShipInterpolation(
        _ ship: inout ShipSprite,
        state: ShipNetworkState,
        deltaTime: Float,
        currentTime: CFTimeInterval
    ) {
        var updatedState = state
        
        // Position interpolation with prediction
        if state.predictionEnabled {
            // Extrapolate position based on velocity
            let timeSinceUpdate = currentTime - state.lastServerUpdate
            if timeSinceUpdate < maxExtrapolationTime {
                let predictedPosition = state.positionInterp.target + state.velocity * Float(timeSinceUpdate)
                
                // Smooth error correction
                let errorCorrection = state.positionError * state.smoothingFactor * deltaTime
                updatedState.clientPosition = predictedPosition - errorCorrection
                
                // Reduce error over time
                updatedState.positionError *= (1.0 - deltaTime * 2.0)
            } else {
                // Fall back to simple interpolation if too much time has passed
                updatedState.clientPosition = interpolateValue(state.positionInterp, easing: .easeInOut)
            }
        } else {
            // Simple interpolation without prediction
            updatedState.clientPosition = interpolateValue(state.positionInterp, easing: .easeInOut)
        }
        
        // Apply interpolated position
        ship.sprite.position = updatedState.clientPosition
        
        // Rotation interpolation (shortest path)
        let currentRot = state.rotationInterp.current
        let targetRot = state.rotationInterp.target
        var rotDiff = targetRot - currentRot
        
        // Normalize rotation difference to [-π, π]
        if rotDiff > Float.pi {
            rotDiff -= 2 * Float.pi
        } else if rotDiff < -Float.pi {
            rotDiff += 2 * Float.pi
        }
        
        let interpolatedRotation = currentRot + rotDiff * min(1.0, deltaTime * rotationLerpSpeed)
        ship.heading = interpolatedRotation
        ship.sprite.rotation = interpolatedRotation
        
        // Speed interpolation
        ship.speed = interpolateValue(state.speedInterp, easing: .linear)
        
        // Damage interpolation
        if let damageInterp = state.damageInterp {
            ship.damageLevel = interpolateValue(damageInterp, easing: .easeOut)
        }
        
        // Update interpolation current values
        updatedState.positionInterp.current = updatedState.clientPosition
        updatedState.rotationInterp.current = interpolatedRotation
        updatedState.speedInterp.current = ship.speed
        
        shipStates[ship.id] = updatedState
    }
    
    private func updatePortInterpolation(
        _ port: inout PortSprite,
        state: PortNetworkState,
        deltaTime: Float,
        currentTime: CFTimeInterval
    ) {
        // Activity level interpolation
        port.activityLevel = interpolateValue(state.activityInterp, easing: .easeInOut)
        
        // Inventory levels would be used for visual indicators
        // This could affect crane activity, warehouse fullness indicators, etc.
    }
    
    // MARK: - Interpolation Methods
    
    private func interpolateValue<T: SIMD>(_ state: InterpolationState<T>, easing: EasingFunction) -> T where T.Scalar: FloatingPoint & ExpressibleByFloatLiteral {
        let t = state.progress
        let easedT = applyEasing(t, function: easing)
        return mix(state.startValue, state.target, t: T.Scalar(easedT))
    }
    
    private func interpolateValue(_ state: InterpolationState<Float>, easing: EasingFunction) -> Float {
        let t = state.progress
        let easedT = applyEasing(t, function: easing)
        return mix(state.startValue, state.target, t: easedT)
    }
    
    // MARK: - Easing Functions
    
    enum EasingFunction {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring
    }
    
    private func applyEasing(_ t: Float, function: EasingFunction) -> Float {
        switch function {
        case .linear:
            return t
            
        case .easeIn:
            return t * t
            
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
            
        case .easeInOut:
            if t < 0.5 {
                return 2 * t * t
            } else {
                return 1 - pow(-2 * t + 2, 2) / 2
            }
            
        case .spring:
            let c4 = (2 * Float.pi) / 3
            return t == 0 ? 0 : t == 1 ? 1 :
                   pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
        }
    }
    
    // MARK: - Lag Compensation
    
    func enablePrediction(for shipID: UUID, enabled: Bool) {
        shipStates[shipID]?.predictionEnabled = enabled
    }
    
    func setSmoothingFactor(for shipID: UUID, factor: Float) {
        shipStates[shipID]?.smoothingFactor = max(0, min(1, factor))
    }
    
    func setNetworkLatency(_ latency: CFTimeInterval) {
        self.networkLatency = max(0, latency)
    }
    
    // MARK: - Collision Rollback
    
    func getServerPosition(for shipID: UUID) -> SIMD2<Float>? {
        return shipStates[shipID]?.serverPosition
    }
    
    func rollbackToServerPosition(for shipID: UUID) {
        guard var state = shipStates[shipID] else { return }
        
        state.clientPosition = state.serverPosition
        state.positionError = .zero
        state.positionInterp.current = state.serverPosition
        
        shipStates[shipID] = state
    }
    
    // MARK: - Debug Info
    
    func getDebugInfo(for shipID: UUID) -> String? {
        guard let state = shipStates[shipID] else { return nil }
        
        let posError = length(state.positionError)
        let timeSinceUpdate = CACurrentMediaTime() - state.lastServerUpdate
        
        return """
        Position Error: \(String(format: "%.2f", posError))
        Time Since Update: \(String(format: "%.3f", timeSinceUpdate))s
        Velocity: [\(String(format: "%.1f", state.velocity.x)), \(String(format: "%.1f", state.velocity.y))]
        Prediction: \(state.predictionEnabled ? "ON" : "OFF")
        """
    }
    
    // MARK: - Cleanup
    
    func removeShip(id: UUID) {
        shipStates.removeValue(forKey: id)
    }
    
    func removePort(id: UUID) {
        portStates.removeValue(forKey: id)
    }
    
    func cleanup(activeShipIDs: Set<UUID>, activePortIDs: Set<UUID>) {
        // Remove states for entities that no longer exist
        shipStates = shipStates.filter { activeShipIDs.contains($0.key) }
        portStates = portStates.filter { activePortIDs.contains($0.key) }
    }
}

// MARK: - Helper Functions

private func mix<T: SIMD>(_ x: T, _ y: T, t: T.Scalar) -> T where T.Scalar: FloatingPoint {
    return x + (y - x) * t
}

private func mix(_ x: Float, _ y: Float, t: Float) -> Float {
    return x + (y - x) * t
}