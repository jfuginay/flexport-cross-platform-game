import Foundation
import simd

/// Manages complex animations for ships and ports
class AnimationSystem {
    
    // MARK: - Animation Types
    
    enum AnimationType {
        case shipDocking(ship: ShipSprite, port: PortSprite, duration: Float)
        case containerLoading(crane: PortSprite, ship: ShipSprite, containerCount: Int)
        case containerUnloading(crane: PortSprite, ship: ShipSprite, containerCount: Int)
        case shipDeparture(ship: ShipSprite, port: PortSprite, duration: Float)
        case craneMovement(crane: PortSprite, from: SIMD2<Float>, to: SIMD2<Float>)
        case tankLoading(port: PortSprite, ship: ShipSprite, duration: Float)
        case bulkLoading(port: PortSprite, ship: ShipSprite, commodityType: String)
        case shipSinking(ship: ShipSprite, duration: Float)
        case emergencyResponse(ships: [ShipSprite], location: SIMD2<Float>)
    }
    
    // MARK: - Active Animations
    
    private struct ActiveAnimation {
        let id: UUID
        let type: AnimationType
        var elapsed: Float
        let startTime: CFTimeInterval
        var state: AnimationState
        var completionHandler: (() -> Void)?
    }
    
    enum AnimationState {
        case preparing
        case inProgress
        case completing
        case finished
    }
    
    private var activeAnimations: [UUID: ActiveAnimation] = [:]
    private var animationQueue: [AnimationType] = []
    
    // MARK: - Container Loading Animation
    
    struct ContainerAnimation {
        let containerID: UUID
        let startPosition: SIMD2<Float>
        let endPosition: SIMD2<Float>
        let cranePosition: SIMD2<Float>
        var progress: Float
        let color: SIMD4<Float>
        let size: SIMD2<Float>
    }
    
    private var activeContainers: [ContainerAnimation] = []
    
    // MARK: - Public Interface
    
    func startAnimation(_ type: AnimationType, completion: (() -> Void)? = nil) -> UUID {
        let animationID = UUID()
        let animation = ActiveAnimation(
            id: animationID,
            type: type,
            elapsed: 0,
            startTime: CACurrentMediaTime(),
            state: .preparing,
            completionHandler: completion
        )
        
        activeAnimations[animationID] = animation
        return animationID
    }
    
    func cancelAnimation(_ id: UUID) {
        activeAnimations.removeValue(forKey: id)
    }
    
    func update(deltaTime: Float) {
        // Update all active animations
        for (id, var animation) in activeAnimations {
            animation.elapsed += deltaTime
            
            switch animation.type {
            case .containerLoading(let crane, let ship, let count):
                updateContainerLoading(crane: crane, ship: ship, count: count, animation: &animation, deltaTime: deltaTime)
                
            case .containerUnloading(let crane, let ship, let count):
                updateContainerUnloading(crane: crane, ship: ship, count: count, animation: &animation, deltaTime: deltaTime)
                
            case .shipDocking(let ship, let port, let duration):
                updateShipDocking(ship: ship, port: port, duration: duration, animation: &animation, deltaTime: deltaTime)
                
            case .shipDeparture(let ship, let port, let duration):
                updateShipDeparture(ship: ship, port: port, duration: duration, animation: &animation, deltaTime: deltaTime)
                
            case .craneMovement(let crane, let from, let to):
                updateCraneMovement(crane: crane, from: from, to: to, animation: &animation, deltaTime: deltaTime)
                
            case .tankLoading(let port, let ship, let duration):
                updateTankLoading(port: port, ship: ship, duration: duration, animation: &animation, deltaTime: deltaTime)
                
            case .bulkLoading(let port, let ship, let commodityType):
                updateBulkLoading(port: port, ship: ship, commodityType: commodityType, animation: &animation, deltaTime: deltaTime)
                
            case .shipSinking(let ship, let duration):
                updateShipSinking(ship: ship, duration: duration, animation: &animation, deltaTime: deltaTime)
                
            case .emergencyResponse(let ships, let location):
                updateEmergencyResponse(ships: ships, location: location, animation: &animation, deltaTime: deltaTime)
            }
            
            // Update animation state
            activeAnimations[id] = animation
            
            // Check if animation is complete
            if animation.state == .finished {
                animation.completionHandler?()
                activeAnimations.removeValue(forKey: id)
            }
        }
        
        // Update container animations
        updateContainerAnimations(deltaTime: deltaTime)
    }
    
    // MARK: - Container Loading/Unloading
    
    private func updateContainerLoading(crane: PortSprite, ship: ShipSprite, count: Int, animation: inout ActiveAnimation, deltaTime: Float) {
        let loadingDuration: Float = 2.0 // seconds per container
        let totalDuration = Float(count) * loadingDuration
        
        switch animation.state {
        case .preparing:
            // Move crane to position
            let craneTargetPos = ship.sprite.position + SIMD2<Float>(0, 30)
            // Start crane movement animation
            animation.state = .inProgress
            
        case .inProgress:
            let progress = animation.elapsed / totalDuration
            let currentContainer = Int(progress * Float(count))
            
            // Create container animations
            if currentContainer < count {
                let containerProgress = fmodf(animation.elapsed, loadingDuration) / loadingDuration
                
                if containerProgress < 0.1 && !activeContainers.contains(where: { $0.progress < 0.1 }) {
                    // Start new container animation
                    let startPos = crane.sprite.position - SIMD2<Float>(0, 20)
                    let endPos = ship.sprite.position + SIMD2<Float>(
                        Float.random(in: -20...20),
                        Float.random(in: -10...10)
                    )
                    
                    let container = ContainerAnimation(
                        containerID: UUID(),
                        startPosition: startPos,
                        endPosition: endPos,
                        cranePosition: crane.sprite.position,
                        progress: 0,
                        color: randomContainerColor(),
                        size: SIMD2<Float>(15, 10)
                    )
                    
                    activeContainers.append(container)
                }
            }
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            // Clean up
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    private func updateContainerUnloading(crane: PortSprite, ship: ShipSprite, count: Int, animation: inout ActiveAnimation, deltaTime: Float) {
        let unloadingDuration: Float = 2.0 // seconds per container
        let totalDuration = Float(count) * unloadingDuration
        
        switch animation.state {
        case .preparing:
            animation.state = .inProgress
            
        case .inProgress:
            let progress = animation.elapsed / totalDuration
            let currentContainer = Int(progress * Float(count))
            
            // Create container animations (reverse of loading)
            if currentContainer < count {
                let containerProgress = fmodf(animation.elapsed, unloadingDuration) / unloadingDuration
                
                if containerProgress < 0.1 && !activeContainers.contains(where: { $0.progress < 0.1 }) {
                    // Start new container animation (from ship to dock)
                    let startPos = ship.sprite.position + SIMD2<Float>(
                        Float.random(in: -20...20),
                        Float.random(in: -10...10)
                    )
                    let endPos = crane.sprite.position + SIMD2<Float>(30, 0) // Stack on dock
                    
                    let container = ContainerAnimation(
                        containerID: UUID(),
                        startPosition: startPos,
                        endPosition: endPos,
                        cranePosition: crane.sprite.position,
                        progress: 0,
                        color: randomContainerColor(),
                        size: SIMD2<Float>(15, 10)
                    )
                    
                    activeContainers.append(container)
                }
            }
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    // MARK: - Ship Docking/Departure
    
    private func updateShipDocking(ship: ShipSprite, port: PortSprite, duration: Float, animation: inout ActiveAnimation, deltaTime: Float) {
        switch animation.state {
        case .preparing:
            // Calculate docking position
            let dockingOffset = SIMD2<Float>(50, 0) // Offset from port center
            let targetPosition = port.sprite.position + dockingOffset
            
            // Store original position and speed
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            
            // Slow down as approaching
            let speedMultiplier = 1.0 - progress * 0.9
            
            // Smooth approach curve
            let smoothProgress = progress * progress * (3.0 - 2.0 * progress)
            
            // Update ship heading to face port
            let toPort = port.sprite.position - ship.sprite.position
            let targetHeading = atan2(toPort.y, toPort.x)
            ship.heading = lerpAngle(ship.heading, targetHeading, smoothProgress * 0.1)
            
            // Reduce speed
            ship.speed *= speedMultiplier
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            // Stop ship
            ship.speed = 0
            
            // Add mooring lines effect
            // Could create line sprites between ship and dock
            
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    private func updateShipDeparture(ship: ShipSprite, port: PortSprite, duration: Float, animation: inout ActiveAnimation, deltaTime: Float) {
        switch animation.state {
        case .preparing:
            // Start engines
            ship.engineAnimation = 0
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            
            // Accelerate gradually
            ship.speed = ship.type.maxSpeed * progress * 0.5
            
            // Turn away from port
            let awayFromPort = ship.sprite.position - port.sprite.position
            let targetHeading = atan2(awayFromPort.y, awayFromPort.x)
            ship.heading = lerpAngle(ship.heading, targetHeading, progress * 0.05)
            
            // Increase engine animation
            ship.engineAnimation += deltaTime * 5.0
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            // Resume normal speed
            ship.speed = ship.type.maxSpeed * 0.8
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    // MARK: - Specialized Loading Animations
    
    private func updateTankLoading(port: PortSprite, ship: ShipSprite, duration: Float, animation: inout ActiveAnimation, deltaTime: Float) {
        switch animation.state {
        case .preparing:
            // Connect loading arms
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            
            // Visual feedback for liquid transfer
            // Could add particle effects for vapors
            // Animate loading arm positions
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            // Disconnect loading arms
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    private func updateBulkLoading(port: PortSprite, ship: ShipSprite, commodityType: String, animation: inout ActiveAnimation, deltaTime: Float) {
        let duration: Float = 10.0 // Bulk loading takes longer
        
        switch animation.state {
        case .preparing:
            // Position conveyor or crane
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            
            // Create falling particles for bulk cargo
            if Int(animation.elapsed * 10) % 3 == 0 {
                // Add grain/coal/ore particles falling into ship
                let particlePos = ship.sprite.position + SIMD2<Float>(0, 20)
                // Create particle effect
            }
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    // MARK: - Emergency Animations
    
    private func updateShipSinking(ship: ShipSprite, duration: Float, animation: inout ActiveAnimation, deltaTime: Float) {
        switch animation.state {
        case .preparing:
            // Start taking on water
            ship.damageLevel = 1.0
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            
            // Increase list angle
            let listAngle = progress * 0.3 * sin(animation.elapsed * 2.0)
            ship.sprite.rotation += listAngle * deltaTime
            
            // Lower in water
            ship.sprite.position.y -= progress * deltaTime * 5.0
            
            // Add more smoke/fire effects
            if Int(animation.elapsed * 10) % 5 == 0 {
                // Create smoke particles
            }
            
            // Slow down
            ship.speed *= 0.95
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            // Ship has sunk
            ship.sprite.isVisible = false
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    private func updateEmergencyResponse(ships: [ShipSprite], location: SIMD2<Float>, animation: inout ActiveAnimation, deltaTime: Float) {
        switch animation.state {
        case .preparing:
            // Alert nearby ships
            for ship in ships {
                // Set emergency destination
                ship.targetPosition = location
            }
            animation.state = .inProgress
            
        case .inProgress:
            // Ships converge on location
            for ship in ships {
                if let target = ship.targetPosition {
                    let toTarget = target - ship.sprite.position
                    let distance = length(toTarget)
                    
                    if distance > 10 {
                        // Navigate to target
                        ship.heading = atan2(toTarget.y, toTarget.x)
                        ship.speed = ship.type.maxSpeed
                    } else {
                        // Arrived, circle the area
                        ship.speed = ship.type.maxSpeed * 0.3
                    }
                }
            }
            
            // Continue until manually stopped
            
        case .completing:
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    // MARK: - Container Animation Updates
    
    private func updateContainerAnimations(deltaTime: Float) {
        var completedContainers: [UUID] = []
        
        for i in 0..<activeContainers.count {
            activeContainers[i].progress += deltaTime * 0.5 // 2 seconds per container
            
            if activeContainers[i].progress >= 1.0 {
                completedContainers.append(activeContainers[i].containerID)
            }
        }
        
        // Remove completed containers
        activeContainers.removeAll { container in
            completedContainers.contains(container.containerID)
        }
    }
    
    // MARK: - Crane Animations
    
    private func updateCraneMovement(crane: PortSprite, from: SIMD2<Float>, to: SIMD2<Float>, animation: inout ActiveAnimation, deltaTime: Float) {
        let duration: Float = 3.0
        
        switch animation.state {
        case .preparing:
            crane.sprite.position = from
            animation.state = .inProgress
            
        case .inProgress:
            let progress = min(1.0, animation.elapsed / duration)
            let smoothProgress = progress * progress * (3.0 - 2.0 * progress)
            
            // Interpolate position
            crane.sprite.position = mix(from, to, t: smoothProgress)
            
            // Animate crane hook/boom
            let swayAmount = sin(progress * Float.pi * 4) * 2.0
            crane.sprite.position.x += swayAmount
            
            if progress >= 1.0 {
                animation.state = .completing
            }
            
        case .completing:
            crane.sprite.position = to
            animation.state = .finished
            
        case .finished:
            break
        }
    }
    
    // MARK: - Helper Functions
    
    private func randomContainerColor() -> SIMD4<Float> {
        let colors: [SIMD4<Float>] = [
            SIMD4<Float>(0.8, 0.2, 0.2, 1.0), // Red
            SIMD4<Float>(0.2, 0.4, 0.8, 1.0), // Blue
            SIMD4<Float>(0.2, 0.6, 0.2, 1.0), // Green
            SIMD4<Float>(0.8, 0.6, 0.2, 1.0), // Orange
            SIMD4<Float>(0.6, 0.2, 0.6, 1.0), // Purple
            SIMD4<Float>(0.7, 0.7, 0.7, 1.0)  // Gray
        ]
        return colors.randomElement() ?? colors[0]
    }
    
    private func lerpAngle(_ from: Float, _ to: Float, _ t: Float) -> Float {
        var diff = to - from
        if diff > Float.pi {
            diff -= 2 * Float.pi
        } else if diff < -Float.pi {
            diff += 2 * Float.pi
        }
        return from + diff * t
    }
    
    // MARK: - Public Getters
    
    func getActiveContainers() -> [ContainerAnimation] {
        return activeContainers
    }
    
    func isAnimationActive(_ id: UUID) -> Bool {
        return activeAnimations[id] != nil
    }
    
    func getAnimationProgress(_ id: UUID) -> Float? {
        guard let animation = activeAnimations[id] else { return nil }
        
        switch animation.type {
        case .shipDocking(_, _, let duration),
             .shipDeparture(_, _, let duration),
             .tankLoading(_, _, let duration),
             .shipSinking(_, let duration):
            return min(1.0, animation.elapsed / duration)
            
        case .containerLoading(_, _, let count),
             .containerUnloading(_, _, let count):
            let duration = Float(count) * 2.0
            return min(1.0, animation.elapsed / duration)
            
        case .bulkLoading:
            return min(1.0, animation.elapsed / 10.0)
            
        case .craneMovement:
            return min(1.0, animation.elapsed / 3.0)
            
        case .emergencyResponse:
            return nil // Ongoing animation
        }
    }
}