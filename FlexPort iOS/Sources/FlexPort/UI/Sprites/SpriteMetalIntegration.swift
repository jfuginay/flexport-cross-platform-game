import Foundation
import Metal
import MetalKit
import simd

/// Integrates the sprite system with the existing Metal rendering pipeline
class SpriteMetalIntegration {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let spriteManager: SpriteManager
    private let spriteRenderer: SpriteRenderer
    private let animationSystem: AnimationSystem
    private let particleSystem: ParticleSystem
    private let damageSystem: DamageSystem
    private let networkInterpolation: NetworkInterpolation
    
    // Integration with existing renderer
    weak var metalMapRenderer: MetalMapRenderer?
    
    // Active game entities
    private var ships: [ShipSprite] = []
    private var ports: [PortSprite] = []
    
    // Update timing
    private var lastUpdateTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    init(device: MTLDevice, metalMapRenderer: MetalMapRenderer) {
        self.device = device
        self.metalMapRenderer = metalMapRenderer
        
        // Initialize subsystems
        self.spriteManager = SpriteManager(device: device)
        self.spriteRenderer = SpriteRenderer(device: device, spriteManager: spriteManager)
        self.animationSystem = AnimationSystem()
        self.particleSystem = ParticleSystem(device: device)
        self.damageSystem = DamageSystem(device: device, particleSystem: particleSystem)
        self.networkInterpolation = NetworkInterpolation()
        
        setupInitialEntities()
    }
    
    // MARK: - Setup
    
    private func setupInitialEntities() {
        // Create ships based on existing data from MetalMapRenderer
        if let renderer = metalMapRenderer {
            // Convert existing ship visualizations to sprite-based ships
            for shipVis in renderer.ships {
                let shipType = convertShipType(shipVis.shipType)
                let ship = spriteManager.createShipSprite(
                    type: shipType,
                    position: SIMD2<Float>(shipVis.position.x, shipVis.position.z)
                )
                
                ships.append(ship)
                spriteRenderer.addShip(ship)
                
                // Create wake trail for moving ships
                particleSystem.createWakeTrail(for: ship)
            }
            
            // Convert ports to sprite-based ports
            for portData in renderer.ports {
                let portSprites = createPortSprites(from: portData)
                ports.append(contentsOf: portSprites)
                
                for port in portSprites {
                    spriteRenderer.addPort(port)
                }
            }
        }
    }
    
    private func convertShipType(_ type: MetalMapRenderer.ShipType) -> ShipSpriteType {
        switch type {
        case .container:
            return .containerLarge
        case .bulk:
            return .bulkPanamax
        case .tanker:
            return .tankerCrude
        case .general:
            return .generalCargo
        }
    }
    
    private func createPortSprites(from port: MetalMapRenderer.EnhancedPort) -> [PortSprite] {
        var sprites: [PortSprite] = []
        let basePosition = SIMD2<Float>(port.worldPosition.x, port.worldPosition.z)
        
        // Create main port building
        let mainBuilding = spriteManager.createPortSprite(
            type: .officeBuilding,
            position: basePosition
        )
        sprites.append(mainBuilding)
        
        // Add infrastructure based on port facilities
        if port.facilities.contains(.containerTerminal) {
            // Add container cranes
            for i in 0..<3 {
                let cranePos = basePosition + SIMD2<Float>(Float(i) * 30 - 30, 20)
                let crane = spriteManager.createPortSprite(type: .craneSTS, position: cranePos)
                sprites.append(crane)
            }
            
            // Add container yard
            let yardPos = basePosition + SIMD2<Float>(0, -30)
            let yard = spriteManager.createPortSprite(type: .containerYard, position: yardPos)
            sprites.append(yard)
        }
        
        if port.facilities.contains(.liquidBulkTerminal) {
            // Add tank farm
            let tankPos = basePosition + SIMD2<Float>(-40, 0)
            let tanks = spriteManager.createPortSprite(type: .tankFarm, position: tankPos)
            sprites.append(tanks)
        }
        
        if port.facilities.contains(.bulkTerminal) {
            // Add silos
            let siloPos = basePosition + SIMD2<Float>(40, 0)
            let silos = spriteManager.createPortSprite(type: .silos, position: siloPos)
            sprites.append(silos)
            
            // Add conveyor
            let conveyor = spriteManager.createPortSprite(type: .conveyorBelt, position: basePosition)
            sprites.append(conveyor)
        }
        
        // Add warehouses
        let warehouseCount = port.importance > 0.8 ? 2 : 1
        for i in 0..<warehouseCount {
            let warehousePos = basePosition + SIMD2<Float>(Float(i) * 35, -50)
            let warehouse = spriteManager.createPortSprite(
                type: port.importance > 0.8 ? .warehouseLarge : .warehouseSmall,
                position: warehousePos
            )
            sprites.append(warehouse)
        }
        
        // Special features
        if port.name == "Singapore" || port.name == "Rotterdam" {
            // Major ports get lighthouses
            let lighthousePos = basePosition + SIMD2<Float>(60, 60)
            let lighthouse = spriteManager.createPortSprite(type: .lighthouse, position: lighthousePos)
            sprites.append(lighthouse)
        }
        
        return sprites
    }
    
    // MARK: - Update
    
    func update() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime == 0 ? 0 : Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        
        guard deltaTime > 0 && deltaTime < 1.0 else { return } // Skip if delta is invalid
        
        // Update all subsystems
        animationSystem.update(deltaTime: deltaTime)
        particleSystem.update(deltaTime: deltaTime)
        damageSystem.update(deltaTime: deltaTime, ships: ships)
        networkInterpolation.update(deltaTime: deltaTime, ships: &ships, ports: &ports)
        spriteRenderer.update(deltaTime: deltaTime)
        
        // Update ship behaviors
        updateShipBehaviors(deltaTime: deltaTime)
        
        // Update port activities
        updatePortActivities(deltaTime: deltaTime)
        
        // Handle collisions
        checkCollisions()
    }
    
    private func updateShipBehaviors(deltaTime: Float) {
        for i in 0..<ships.count {
            var ship = ships[i]
            
            // Simple AI navigation (replace with actual game logic)
            if ship.targetPosition == nil {
                // Set random destination
                ship.targetPosition = SIMD2<Float>(
                    Float.random(in: -100...100),
                    Float.random(in: -100...100)
                )
            }
            
            if let target = ship.targetPosition {
                let toTarget = target - ship.sprite.position
                let distance = length(toTarget)
                
                if distance > 5 {
                    // Navigate to target
                    ship.heading = atan2(toTarget.y, toTarget.x)
                    ship.speed = min(ship.type.maxSpeed, distance / 10) * ship.type.maxSpeed
                } else {
                    // Reached target, pick new one
                    ship.targetPosition = nil
                    ship.speed = 0
                }
            }
            
            ships[i] = ship
        }
    }
    
    private func updatePortActivities(deltaTime: Float) {
        // Simulate port activity
        for i in 0..<ports.count {
            // Update activity levels with some random variation
            ports[i].activityLevel = max(0, min(1,
                ports[i].activityLevel + Float.random(in: -0.1...0.1) * deltaTime
            ))
            
            // Trigger animations based on nearby ships
            for ship in ships {
                let distance = simd_distance(ship.sprite.position, ports[i].sprite.position)
                if distance < 50 && ship.speed < 2 {
                    // Ship is docked, start loading/unloading
                    startPortAnimation(port: ports[i], ship: ship)
                }
            }
        }
    }
    
    private func startPortAnimation(port: PortSprite, ship: ShipSprite) {
        // Check if animation already running
        let animationID = UUID() // In real implementation, track this properly
        
        switch ship.type {
        case .containerSmall, .containerMedium, .containerLarge, .containerMega:
            _ = animationSystem.startAnimation(
                .containerLoading(crane: port, ship: ship, containerCount: 20)
            )
            
        case .tankerCrude, .tankerProduct, .tankerLNG:
            _ = animationSystem.startAnimation(
                .tankLoading(port: port, ship: ship, duration: 5.0)
            )
            
        case .bulkHandysize, .bulkPanamax, .bulkCapesize:
            _ = animationSystem.startAnimation(
                .bulkLoading(port: port, ship: ship, commodityType: "grain")
            )
            
        default:
            break
        }
    }
    
    private func checkCollisions() {
        // Simple collision detection between ships
        for i in 0..<ships.count {
            for j in (i+1)..<ships.count {
                let distance = simd_distance(ships[i].sprite.position, ships[j].sprite.position)
                let minDistance = (ships[i].sprite.size.x + ships[j].sprite.size.x) / 2
                
                if distance < minDistance {
                    // Collision detected
                    handleCollision(ship1: ships[i], ship2: ships[j])
                }
            }
        }
    }
    
    private func handleCollision(ship1: ShipSprite, ship2: ShipSprite) {
        // Calculate collision force based on relative velocities
        let relativeSpeed = abs(ship1.speed - ship2.speed)
        let impactForce = relativeSpeed / 50.0 // Normalize to 0-1 range
        
        // Apply damage to both ships
        damageSystem.applyDamage(to: ship1.id, type: .collision(impactForce: impactForce))
        damageSystem.applyDamage(to: ship2.id, type: .collision(impactForce: impactForce))
        
        // Create collision effects
        let collisionPoint = (ship1.sprite.position + ship2.sprite.position) / 2
        particleSystem.createSplash(at: collisionPoint, size: impactForce * 20)
        
        if impactForce > 0.7 {
            particleSystem.createExplosion(at: collisionPoint, intensity: impactForce)
        }
    }
    
    // MARK: - Rendering Integration
    
    func render(in metalMapRenderer: MetalMapRenderer, encoder: MTLRenderCommandEncoder) {
        // Create uniforms that match the existing Metal pipeline
        var uniforms = SpriteUniforms(
            viewProjectionMatrix: metalMapRenderer.projectionMatrix * metalMapRenderer.viewMatrix,
            time: metalMapRenderer.currentTime
        )
        
        // Render sprites using the sprite renderer
        spriteRenderer.render(encoder: encoder, uniforms: uniforms)
        
        // The particle system would also render here
        // particleSystem.render(encoder: encoder, uniforms: uniforms)
    }
    
    // MARK: - Network Updates
    
    func handleNetworkShipUpdate(
        shipID: UUID,
        position: SIMD2<Float>,
        rotation: Float,
        speed: Float,
        damage: Float?,
        timestamp: CFTimeInterval
    ) {
        networkInterpolation.updateShipFromNetwork(
            shipID: shipID,
            position: position,
            rotation: rotation,
            speed: speed,
            timestamp: timestamp
        )
        
        if let damage = damage {
            networkInterpolation.updateShipDamageFromNetwork(
                shipID: shipID,
                damageLevel: damage,
                timestamp: timestamp
            )
        }
    }
    
    func handleNetworkPortUpdate(
        portID: UUID,
        activityLevel: Float,
        inventoryLevels: [String: Float],
        timestamp: CFTimeInterval
    ) {
        networkInterpolation.updatePortFromNetwork(
            portID: portID,
            activityLevel: activityLevel,
            inventoryLevels: inventoryLevels,
            timestamp: timestamp
        )
    }
    
    // MARK: - Game Events
    
    func spawnShip(type: ShipSpriteType, at position: SIMD2<Float>, heading: Float) -> ShipSprite {
        var ship = spriteManager.createShipSprite(type: type, position: position)
        ship.heading = heading
        ship.speed = type.maxSpeed * 0.5
        
        ships.append(ship)
        spriteRenderer.addShip(ship)
        particleSystem.createWakeTrail(for: ship)
        
        // Splash effect for ship spawn
        particleSystem.createSplash(at: position, size: ship.sprite.size.x / 2)
        
        return ship
    }
    
    func despawnShip(id: UUID) {
        if let index = ships.firstIndex(where: { $0.id == id }) {
            let ship = ships[index]
            
            // Create despawn effects
            particleSystem.createSplash(at: ship.sprite.position, size: ship.sprite.size.x)
            
            // Remove from systems
            ships.remove(at: index)
            spriteRenderer.removeShip(id: id)
            particleSystem.removeWakeTrail(for: id)
            networkInterpolation.removeShip(id: id)
        }
    }
    
    func triggerStorm(at position: SIMD2<Float>, radius: Float) {
        // Find ships in storm radius
        for ship in ships {
            let distance = simd_distance(ship.sprite.position, position)
            if distance < radius {
                let stormIntensity = 1.0 - (distance / radius)
                damageSystem.applyDamage(to: ship.id, type: .stormDamage)
                
                // Add storm particle effects
                // This would create rain, waves, etc.
            }
        }
    }
    
    func triggerPiracyEvent(targetShipID: UUID, pirateShipIDs: [UUID]) {
        // Apply damage to target
        damageSystem.applyDamage(to: targetShipID, type: .piracyAttack)
        
        // Make pirate ships converge on target
        if let targetShip = ships.first(where: { $0.id == targetShipID }) {
            let pirateShips = ships.filter { pirateShipIDs.contains($0.id) }
            _ = animationSystem.startAnimation(
                .emergencyResponse(ships: pirateShips, location: targetShip.sprite.position)
            )
        }
    }
    
    // MARK: - Debug
    
    func getDebugInfo() -> String {
        return """
        Active Ships: \(ships.count)
        Active Ports: \(ports.count)
        \(particleSystem.debugInfo)
        Active Animations: \(animationSystem.getActiveContainers().count)
        """
    }
}

// MARK: - Extensions for Metal Renderer Integration

extension MetalMapRenderer {
    func setupSpriteSystem() {
        // This would be called from the main Metal renderer to set up sprite integration
        // The sprite system would handle all ship and port rendering
    }
    
    func renderSprites(encoder: MTLRenderCommandEncoder) {
        // This would be called from the main render loop
        // to render all sprites after the base world is rendered
    }
}