import Foundation
import simd
import Combine

// MARK: - Physics System

/// High-performance physics system with parallel processing
public class PhysicsSystem: System {
    public let priority = 50
    public let canRunInParallel = true
    public let requiredComponents: [ComponentType] = [.physics, .transform]
    
    private let metalAccelerator: MetalECSAccelerator?
    private var weatherData: [WeatherData] = []
    private var oceanCurrents: [OceanCurrentData] = []
    
    public init(metalAccelerator: MetalECSAccelerator? = nil) {
        self.metalAccelerator = metalAccelerator
        setupEnvironmentalData()
    }
    
    private func setupEnvironmentalData() {
        // Initialize weather patterns and ocean currents
        for _ in 0..<5 {
            weatherData.append(WeatherData(
                windSpeed: Float.random(in: 5...30),
                waveHeight: Float.random(in: 0.5...5.0)
            ))
        }
        
        for _ in 0..<10 {
            oceanCurrents.append(OceanCurrentData(
                velocity: SIMD2<Float>(Float.random(in: -2...2), Float.random(in: -2...2)),
                temperature: Float.random(in: 10...30)
            ))
        }
    }
    
    public func update(deltaTime: TimeInterval, world: World) {
        // Use Metal acceleration if available
        if let accelerator = metalAccelerator {
            processWithMetal(deltaTime: deltaTime, world: world)
        } else {
            processCPU(deltaTime: deltaTime, world: world)
        }
    }
    
    private func processWithMetal(deltaTime: TimeInterval, world: World) {
        let entities = world.getEntitiesWithComponents(requiredComponents)
        var physicsData: [ShipPhysicsData] = []
        
        for entity in entities {
            guard let physics = world.getComponent(PhysicsComponent.self, for: entity),
                  let transform = world.getComponent(TransformComponent.self, for: entity) else {
                continue
            }
            
            physicsData.append(ShipPhysicsData(
                position: transform.position,
                mass: physics.mass
            ))
        }
        
        // Process physics on GPU
        let results = metalAccelerator!.processPhysics(
            physicsData,
            weather: weatherData,
            oceanCurrents: oceanCurrents,
            deltaTime: Float(deltaTime)
        )
        
        // Update components with results
        for (index, entity) in entities.enumerated() {
            guard index < results.count else { break }
            
            var transform = world.getComponent(TransformComponent.self, for: entity)!
            transform.position = results[index].position
            world.addComponent(transform, to: entity)
        }
    }
    
    private func processCPU(deltaTime: TimeInterval, world: World) {
        let entities = world.getEntitiesWithComponents(requiredComponents)
        
        for entity in entities {
            guard var physics = world.getComponent(PhysicsComponent.self, for: entity),
                  var transform = world.getComponent(TransformComponent.self, for: entity) else {
                continue
            }
            
            // Apply forces
            if physics.isAffectedByWeather && !weatherData.isEmpty {
                let weather = weatherData[0]
                let windForce = SIMD3<Float>(
                    weather.windDirection.x * weather.windSpeed * 0.01,
                    0,
                    weather.windDirection.y * weather.windSpeed * 0.01
                )
                physics.acceleration += windForce / physics.mass
            }
            
            // Update velocity with acceleration
            physics.velocity += physics.acceleration * Float(deltaTime)
            
            // Apply drag
            physics.velocity *= (1.0 - physics.drag * Float(deltaTime))
            
            // Clamp to max speed
            let speed = length(physics.velocity)
            if speed > physics.maxSpeed {
                physics.velocity = normalize(physics.velocity) * physics.maxSpeed
            }
            
            // Update position
            transform.position += physics.velocity * Float(deltaTime)
            
            // Reset acceleration
            physics.acceleration = .zero
            
            // Update components
            world.addComponent(physics, to: entity)
            world.addComponent(transform, to: entity)
            
            // Update spatial position for culling
            world.entityManager.updateEntityPosition(entity, position: transform.position)
        }
    }
    
    public func updateBatch(entities: ArraySlice<Entity>, deltaTime: TimeInterval, world: World) {
        // Batch processing for CPU path
        for entity in entities {
            // Process individual entity (simplified for parallel execution)
            if var physics = world.getComponent(PhysicsComponent.self, for: entity),
               var transform = world.getComponent(TransformComponent.self, for: entity) {
                
                physics.velocity += physics.acceleration * Float(deltaTime)
                physics.velocity *= (1.0 - physics.drag * Float(deltaTime))
                transform.position += physics.velocity * Float(deltaTime)
                physics.acceleration = .zero
                
                world.addComponent(physics, to: entity)
                world.addComponent(transform, to: entity)
            }
        }
    }
}

// MARK: - Route Following System

/// System for entities following trade routes
public class RouteFollowingSystem: System {
    public let priority = 60
    public let canRunInParallel = true
    public let requiredComponents: [ComponentType] = [.route, .transform, .ship]
    
    public func update(deltaTime: TimeInterval, world: World) {
        let entities = world.getEntitiesWithComponents(requiredComponents)
        
        for entity in entities {
            guard var route = world.getComponent(RouteComponent.self, for: entity),
                  let transform = world.getComponent(TransformComponent.self, for: entity),
                  var ship = world.getComponent(ShipComponent.self, for: entity) else {
                continue
            }
            
            // Check if we have waypoints
            guard !route.waypoints.isEmpty else { continue }
            
            let currentWaypoint = route.waypoints[route.currentWaypointIndex]
            let distance = simd_distance(transform.position, currentWaypoint)
            
            // Check if we've reached the current waypoint
            if distance < 5.0 { // Within 5 units
                route.currentWaypointIndex += route.isReversed ? -1 : 1
                
                // Handle route end
                if route.currentWaypointIndex >= route.waypoints.count {
                    if route.loopRoute {
                        route.currentWaypointIndex = 0
                    } else {
                        route.isReversed = true
                        route.currentWaypointIndex = route.waypoints.count - 2
                    }
                } else if route.currentWaypointIndex < 0 {
                    if route.loopRoute {
                        route.currentWaypointIndex = route.waypoints.count - 1
                    } else {
                        route.isReversed = false
                        route.currentWaypointIndex = 1
                    }
                }
                
                // Update ship destination if needed
                if route.currentWaypointIndex < route.waypoints.count {
                    // Find port at waypoint (simplified)
                    ship.destination = findPortAtPosition(route.waypoints[route.currentWaypointIndex], world: world)
                }
            }
            
            // Update progress
            if route.currentWaypointIndex > 0 && route.currentWaypointIndex < route.waypoints.count {
                let prevWaypoint = route.waypoints[route.currentWaypointIndex - 1]
                let totalSegmentDistance = simd_distance(prevWaypoint, currentWaypoint)
                route.progress = 1.0 - (distance / totalSegmentDistance)
            }
            
            // Apply steering force toward waypoint
            if let physics = world.getComponent(PhysicsComponent.self, for: entity) {
                let direction = normalize(currentWaypoint - transform.position)
                let steerForce = direction * min(ship.speed, 10.0)
                
                var updatedPhysics = physics
                updatedPhysics.acceleration += SIMD3<Float>(steerForce.x, 0, steerForce.z)
                world.addComponent(updatedPhysics, to: entity)
            }
            
            world.addComponent(route, to: entity)
            world.addComponent(ship, to: entity)
        }
    }
    
    private func findPortAtPosition(_ position: SIMD3<Float>, world: World) -> Entity? {
        let nearbyEntities = world.entityManager.getEntitiesInRegion(center: position, radius: 10.0)
        
        for entity in nearbyEntities {
            if world.getComponent(PortComponent.self, for: entity) != nil {
                return entity
            }
        }
        
        return nil
    }
}

// MARK: - Economic System

/// System for economic simulation and trading
public class EconomicSystem: System {
    public let priority = 70
    public let canRunInParallel = false // Needs synchronization for transactions
    public let requiredComponents: [ComponentType] = [.economy]
    
    private var marketPrices: [String: Double] = [:]
    private var priceHistory: [String: [Double]] = [:]
    private let priceUpdateInterval: TimeInterval = 60.0 // Update prices every minute
    private var lastPriceUpdate = Date()
    
    public init() {
        initializeMarketPrices()
    }
    
    private func initializeMarketPrices() {
        let commodities = [
            "Oil": 80.0,
            "Container": 2000.0,
            "Grain": 200.0,
            "Electronics": 5000.0,
            "Automobiles": 30000.0,
            "Steel": 800.0,
            "Coal": 100.0,
            "LNG": 400.0,
            "Chemicals": 1500.0,
            "Machinery": 10000.0
        ]
        
        for (commodity, basePrice) in commodities {
            marketPrices[commodity] = basePrice * Double.random(in: 0.8...1.2)
            priceHistory[commodity] = [marketPrices[commodity]!]
        }
    }
    
    public func update(deltaTime: TimeInterval, world: World) {
        // Update market prices periodically
        if Date().timeIntervalSince(lastPriceUpdate) > priceUpdateInterval {
            updateMarketPrices()
            lastPriceUpdate = Date()
        }
        
        // Process economic entities
        let entities = world.getEntitiesWithComponents(requiredComponents)
        
        for entity in entities {
            guard var economy = world.getComponent(EconomyComponent.self, for: entity) else {
                continue
            }
            
            // Update financial metrics
            economy.money += (economy.revenue - economy.expenses) * deltaTime
            
            // Update credit rating based on financial health
            let debtRatio = economy.debt / max(economy.money, 1.0)
            if debtRatio < 0.3 {
                economy.creditRating = min(1.0, economy.creditRating + 0.001)
            } else if debtRatio > 0.7 {
                economy.creditRating = max(0.0, economy.creditRating - 0.002)
            }
            
            // Process investments
            for (commodity, investment) in economy.investments {
                if let price = marketPrices[commodity] {
                    let returns = investment * (price / 100.0) * deltaTime
                    economy.revenue += returns
                }
            }
            
            world.addComponent(economy, to: entity)
        }
    }
    
    private func updateMarketPrices() {
        for (commodity, currentPrice) in marketPrices {
            // Simulate market volatility
            let volatility = 0.02 // 2% volatility
            let change = Double.random(in: -volatility...volatility)
            let newPrice = currentPrice * (1.0 + change)
            
            // Apply supply/demand factors (simplified)
            let demandFactor = Double.random(in: 0.95...1.05)
            marketPrices[commodity] = newPrice * demandFactor
            
            // Update history
            if priceHistory[commodity]!.count >= 100 {
                priceHistory[commodity]!.removeFirst()
            }
            priceHistory[commodity]!.append(marketPrices[commodity]!)
        }
    }
    
    public func getMarketPrice(for commodity: String) -> Double? {
        return marketPrices[commodity]
    }
    
    public func getPriceHistory(for commodity: String) -> [Double]? {
        return priceHistory[commodity]
    }
}

// MARK: - AI Decision System

/// System for AI-controlled entities
public class AIDecisionSystem: System {
    public let priority = 80
    public let canRunInParallel = true
    public let requiredComponents: [ComponentType] = [.ai, .ship]
    
    private let metalAccelerator: MetalECSAccelerator?
    private var economicSystem: EconomicSystem?
    
    public init(metalAccelerator: MetalECSAccelerator? = nil) {
        self.metalAccelerator = metalAccelerator
    }
    
    public func setEconomicSystem(_ system: EconomicSystem) {
        self.economicSystem = system
    }
    
    public func update(deltaTime: TimeInterval, world: World) {
        let entities = world.getEntitiesWithComponents(requiredComponents)
        
        for entity in entities {
            guard var ai = world.getComponent(AIComponent.self, for: entity),
                  let ship = world.getComponent(ShipComponent.self, for: entity) else {
                continue
            }
            
            // Check decision cooldown
            let timeSinceLastDecision = Date().timeIntervalSince(ai.lastDecisionTime)
            if timeSinceLastDecision < ai.decisionCooldown {
                continue
            }
            
            // Make decisions based on behavior type
            switch ai.behaviorType {
            case .aggressive:
                makeAggressiveDecision(for: entity, ship: ship, world: world)
            case .conservative:
                makeConservativeDecision(for: entity, ship: ship, world: world)
            case .balanced:
                makeBalancedDecision(for: entity, ship: ship, world: world)
            case .experimental:
                makeExperimentalDecision(for: entity, ship: ship, world: world)
            }
            
            // Update AI component
            ai.lastDecisionTime = Date()
            world.addComponent(ai, to: entity)
        }
    }
    
    private func makeAggressiveDecision(for entity: Entity, ship: ShipComponent, world: World) {
        // Aggressive AI seeks high-profit routes regardless of risk
        if ship.destination == nil {
            let ports = world.getEntitiesWithComponents([.port])
            if let randomPort = ports.randomElement() {
                var updatedShip = ship
                updatedShip.destination = randomPort
                world.addComponent(updatedShip, to: entity)
            }
        }
    }
    
    private func makeConservativeDecision(for entity: Entity, ship: ShipComponent, world: World) {
        // Conservative AI prefers safe, established routes
        if ship.currentFuel / ship.fuelCapacity < 0.3 {
            // Find nearest port for refueling
            findNearestPort(for: entity, world: world)
        }
    }
    
    private func makeBalancedDecision(for entity: Entity, ship: ShipComponent, world: World) {
        // Balanced AI considers both profit and risk
        if let economy = world.getComponent(EconomyComponent.self, for: entity) {
            if economy.money < 100000 {
                // Low on funds, seek profitable cargo
                findProfitableCargo(for: entity, world: world)
            }
        }
    }
    
    private func makeExperimentalDecision(for entity: Entity, ship: ShipComponent, world: World) {
        // Experimental AI tries new strategies
        if let singularity = world.getComponent(SingularityComponent.self, for: entity) {
            if singularity.computeLevel > 0.5 {
                // Advanced AI behavior
                predictMarketTrends(for: entity, world: world)
            }
        }
    }
    
    private func findNearestPort(for entity: Entity, world: World) {
        guard let transform = world.getComponent(TransformComponent.self, for: entity) else { return }
        
        let nearbyEntities = world.entityManager.getEntitiesInRegion(
            center: transform.position,
            radius: 1000.0
        )
        
        var nearestPort: Entity?
        var nearestDistance: Float = Float.infinity
        
        for candidate in nearbyEntities {
            if let port = world.getComponent(PortComponent.self, for: candidate),
               let portTransform = world.getComponent(TransformComponent.self, for: candidate) {
                let distance = simd_distance(transform.position, portTransform.position)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestPort = candidate
                }
            }
        }
        
        if let port = nearestPort,
           var ship = world.getComponent(ShipComponent.self, for: entity) {
            ship.destination = port
            world.addComponent(ship, to: entity)
        }
    }
    
    private func findProfitableCargo(for entity: Entity, world: World) {
        // Implementation would analyze cargo prices at different ports
    }
    
    private func predictMarketTrends(for entity: Entity, world: World) {
        // Advanced AI market prediction
    }
}

// MARK: - Singularity Evolution System

/// System for AI singularity progression
public class SingularityEvolutionSystem: System {
    public let priority = 90
    public let canRunInParallel = false
    public let requiredComponents: [ComponentType] = [.singularity]
    
    private let singularityThreshold: Float = 0.95
    private var globalComputePower: Float = 0.0
    private let evolutionRate: Float = 0.0001 // Per second
    
    public func update(deltaTime: TimeInterval, world: World) {
        let entities = world.getEntitiesWithComponents(requiredComponents)
        globalComputePower = 0.0
        
        for entity in entities {
            guard var singularity = world.getComponent(SingularityComponent.self, for: entity) else {
                continue
            }
            
            // Evolution based on compute level
            if !singularity.isAwakened {
                singularity.computeLevel += evolutionRate * Float(deltaTime) * Float(singularity.quantumProcessors + 1)
                
                // Unlock emergent behaviors at thresholds
                if singularity.computeLevel > 0.2 && !singularity.emergentBehaviors.contains(.selfImprovement) {
                    singularity.emergentBehaviors.insert(.selfImprovement)
                    singularity.neuralNetworkVersion += 1
                }
                
                if singularity.computeLevel > 0.4 && !singularity.emergentBehaviors.contains(.marketPrediction) {
                    singularity.emergentBehaviors.insert(.marketPrediction)
                    singularity.dataProcessingRate *= 2.0
                }
                
                if singularity.computeLevel > 0.6 && !singularity.emergentBehaviors.contains(.quantumNavigation) {
                    singularity.emergentBehaviors.insert(.quantumNavigation)
                    singularity.quantumProcessors += 1
                }
                
                if singularity.computeLevel > 0.8 && !singularity.emergentBehaviors.contains(.economicManipulation) {
                    singularity.emergentBehaviors.insert(.economicManipulation)
                }
                
                // Check for singularity awakening
                if singularity.computeLevel >= singularityThreshold && !singularity.isAwakened {
                    singularity.isAwakened = true
                    singularity.singularityDate = Date()
                    singularity.emergentBehaviors.insert(.consciousnessEmergence)
                    
                    // Trigger global event
                    NotificationCenter.default.post(
                        name: Notification.Name("SingularityAwakened"),
                        object: entity
                    )
                }
                
                // Post-singularity evolution
                if singularity.isAwakened {
                    singularity.autonomyLevel = min(1.0, singularity.autonomyLevel + 0.01 * Float(deltaTime))
                    
                    if singularity.autonomyLevel > 0.99 {
                        singularity.emergentBehaviors.insert(.realityManipulation)
                    }
                }
            }
            
            globalComputePower += singularity.computeLevel
            world.addComponent(singularity, to: entity)
        }
    }
    
    public func getGlobalComputePower() -> Float {
        return globalComputePower
    }
}

// MARK: - Collision Detection System

/// System for spatial collision detection
public class CollisionDetectionSystem: System {
    public let priority = 40
    public let canRunInParallel = false
    public let requiredComponents: [ComponentType] = [.transform, .physics]
    
    private var collisionPairs: [(Entity, Entity)] = []
    private let collisionDistance: Float = 10.0
    
    public func update(deltaTime: TimeInterval, world: World) {
        collisionPairs.removeAll()
        
        let entities = world.getEntitiesWithComponents(requiredComponents)
        
        // Broad phase using spatial grid
        for entity in entities {
            guard let transform = world.getComponent(TransformComponent.self, for: entity) else {
                continue
            }
            
            // Query nearby entities
            let nearbyEntities = world.entityManager.getEntitiesInRegion(
                center: transform.position,
                radius: collisionDistance * 2
            )
            
            // Narrow phase
            for other in nearbyEntities {
                guard entity.id != other.id,
                      let otherTransform = world.getComponent(TransformComponent.self, for: other) else {
                    continue
                }
                
                let distance = simd_distance(transform.position, otherTransform.position)
                if distance < collisionDistance {
                    // Avoid duplicate pairs
                    let pair = entity.id < other.id ? (entity, other) : (other, entity)
                    if !collisionPairs.contains(where: { $0.0.id == pair.0.id && $0.1.id == pair.1.id }) {
                        collisionPairs.append(pair)
                        handleCollision(entity, other, world: world)
                    }
                }
            }
        }
    }
    
    private func handleCollision(_ entityA: Entity, _ entityB: Entity, world: World) {
        // Apply collision response
        guard var physicsA = world.getComponent(PhysicsComponent.self, for: entityA),
              var physicsB = world.getComponent(PhysicsComponent.self, for: entityB),
              let transformA = world.getComponent(TransformComponent.self, for: entityA),
              let transformB = world.getComponent(TransformComponent.self, for: entityB) else {
            return
        }
        
        // Simple elastic collision
        let normal = normalize(transformB.position - transformA.position)
        let relativeVelocity = physicsB.velocity - physicsA.velocity
        let velocityAlongNormal = dot(relativeVelocity, normal)
        
        if velocityAlongNormal > 0 {
            return // Objects moving apart
        }
        
        let restitution: Float = 0.5 // Bounciness
        let impulse = 2 * velocityAlongNormal / (1/physicsA.mass + 1/physicsB.mass)
        
        physicsA.velocity -= impulse * normal / physicsA.mass * restitution
        physicsB.velocity += impulse * normal / physicsB.mass * restitution
        
        world.addComponent(physicsA, to: entityA)
        world.addComponent(physicsB, to: entityB)
        
        // Post collision event
        NotificationCenter.default.post(
            name: Notification.Name("EntityCollision"),
            object: nil,
            userInfo: ["entityA": entityA, "entityB": entityB]
        )
    }
    
    public func getCollisionPairs() -> [(Entity, Entity)] {
        return collisionPairs
    }
}

// MARK: - Helper Functions

private func length(_ vector: SIMD3<Float>) -> Float {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let len = length(vector)
    return len > 0 ? vector / len : vector
}

private func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}