import Foundation
import simd
import Combine

// MARK: - Economic Event Generation System

/// System responsible for generating and managing economic events
public class EconomicEventGenerationSystem: System {
    public let priority = 100
    public let canRunInParallel = false
    public let requiredComponents: [ComponentType] = []
    
    private let eventGenerationInterval: TimeInterval = 30.0 // Generate events every 30 seconds
    private var lastEventGeneration = Date()
    private var activeEvents: [UUID: EconomicEventComponent] = [:]
    private let maxActiveEvents = 5
    private var globalMarketStress: Float = 0.0
    
    // Event probability weights
    private let eventProbabilities: [EconomicEventComponent.EconomicEventType: Double] = [
        .portStrike: 0.15,
        .hurricaneWarning: 0.12,
        .oilPriceSurge: 0.18,
        .tradeWar: 0.08,
        .pandemic: 0.02,
        .cyberAttack: 0.10,
        .earthquake: 0.08,
        .tsunami: 0.03,
        .piracy: 0.12,
        .sanctions: 0.05,
        .recession: 0.03,
        .boom: 0.02,
        .techBreakthrough: 0.01,
        .environmentalDisaster: 0.04,
        .regulatoryChange: 0.07
    ]
    
    public init() {}
    
    public func update(deltaTime: TimeInterval, world: World) {
        updateActiveEvents(deltaTime: deltaTime, world: world)
        
        // Check if it's time to generate new events
        let timeSinceLastGeneration = Date().timeIntervalSince(lastEventGeneration)
        if timeSinceLastGeneration >= eventGenerationInterval {
            generateRandomEvent(world: world)
            lastEventGeneration = Date()
        }
        
        // Update global market stress based on active events
        updateGlobalMarketStress()
    }
    
    private func updateActiveEvents(deltaTime: TimeInterval, world: World) {
        var eventsToRemove: [UUID] = []
        
        for (eventId, var event) in activeEvents {
            event.remainingDuration -= deltaTime
            
            if event.remainingDuration <= 0 {
                // Event has expired
                eventsToRemove.append(eventId)
                finishEvent(event, world: world)
            } else {
                // Update event
                activeEvents[eventId] = event
                updateEventEffects(event, world: world)
            }
        }
        
        // Remove expired events
        for eventId in eventsToRemove {
            activeEvents.removeValue(forKey: eventId)
        }
    }
    
    private func generateRandomEvent(world: World) {
        // Don't generate if we have too many active events
        guard activeEvents.count < maxActiveEvents else { return }
        
        // Adjust probability based on market stress
        let stressMultiplier = 1.0 + Double(globalMarketStress) * 0.5
        let eventChance = 0.3 * stressMultiplier // 30% base chance, increases with stress
        
        guard Double.random(in: 0...1) < eventChance else { return }
        
        // Select random event type based on probabilities
        guard let eventType = selectRandomEventType() else { return }
        
        // Generate event parameters
        let severity = generateEventSeverity(for: eventType)
        let duration = generateEventDuration(for: eventType, severity: severity)
        let affectedRegions = generateAffectedRegions(for: eventType)
        
        // Create event component
        let event = EconomicEventComponent(
            eventType: eventType,
            severity: severity,
            duration: duration,
            affectedRegions: affectedRegions
        )
        
        // Create event entity
        let eventEntity = world.createEntity()
        world.addComponent(event, to: eventEntity)
        
        // Store in active events
        activeEvents[event.eventId] = event
        
        // Create disaster effects if applicable
        if shouldCreateDisasterEffect(for: eventType) {
            createDisasterEffect(for: event, world: world)
        }
        
        // Trigger haptic feedback if needed
        if event.triggerHapticFeedback {
            triggerHapticFeedback(for: event)
        }
        
        // Send notification
        NotificationCenter.default.post(
            name: Notification.Name("EconomicEventGenerated"),
            object: event,
            userInfo: ["eventEntity": eventEntity]
        )
        
        print("Generated economic event: \(event.name) (\(event.severity.rawValue)) - Duration: \(Int(duration))s")
    }
    
    private func selectRandomEventType() -> EconomicEventComponent.EconomicEventType? {
        let totalWeight = eventProbabilities.values.reduce(0, +)
        let randomValue = Double.random(in: 0...totalWeight)
        
        var cumulativeWeight = 0.0
        for (eventType, weight) in eventProbabilities {
            cumulativeWeight += weight
            if randomValue <= cumulativeWeight {
                return eventType
            }
        }
        
        return nil
    }
    
    private func generateEventSeverity(for eventType: EconomicEventComponent.EconomicEventType) -> EconomicEventComponent.EventSeverity {
        // Some events are more likely to be severe
        let severityWeights: [EconomicEventComponent.EventSeverity: Double]
        
        switch eventType {
        case .tsunami, .earthquake, .pandemic:
            severityWeights = [.minor: 0.1, .moderate: 0.2, .major: 0.4, .catastrophic: 0.3]
        case .hurricaneWarning, .cyberAttack, .environmentalDisaster:
            severityWeights = [.minor: 0.2, .moderate: 0.3, .major: 0.4, .catastrophic: 0.1]
        case .oilPriceSurge, .tradeWar, .sanctions:
            severityWeights = [.minor: 0.3, .moderate: 0.4, .major: 0.2, .catastrophic: 0.1]
        default:
            severityWeights = [.minor: 0.4, .moderate: 0.4, .major: 0.15, .catastrophic: 0.05]
        }
        
        let totalWeight = severityWeights.values.reduce(0, +)
        let randomValue = Double.random(in: 0...totalWeight)
        
        var cumulativeWeight = 0.0
        for (severity, weight) in severityWeights {
            cumulativeWeight += weight
            if randomValue <= cumulativeWeight {
                return severity
            }
        }
        
        return .minor
    }
    
    private func generateEventDuration(for eventType: EconomicEventComponent.EconomicEventType, severity: EconomicEventComponent.EventSeverity) -> TimeInterval {
        let baseDuration: TimeInterval
        
        switch eventType {
        case .earthquake, .tsunami, .cyberAttack:
            baseDuration = 300 // 5 minutes
        case .hurricaneWarning, .storm:
            baseDuration = 600 // 10 minutes
        case .portStrike, .piracy:
            baseDuration = 900 // 15 minutes
        case .oilPriceSurge, .regulatoryChange:
            baseDuration = 1800 // 30 minutes
        case .tradeWar, .sanctions, .pandemic:
            baseDuration = 3600 // 1 hour
        case .recession, .boom:
            baseDuration = 7200 // 2 hours
        default:
            baseDuration = 1200 // 20 minutes
        }
        
        let severityMultiplier: Double
        switch severity {
        case .minor: severityMultiplier = 0.5
        case .moderate: severityMultiplier = 0.8
        case .major: severityMultiplier = 1.2
        case .catastrophic: severityMultiplier = 2.0
        }
        
        return baseDuration * severityMultiplier * Double.random(in: 0.7...1.3)
    }
    
    private func generateAffectedRegions(for eventType: EconomicEventComponent.EconomicEventType) -> Set<GeographicRegion> {
        switch eventType {
        case .earthquake, .tsunami, .hurricaneWarning:
            // Natural disasters are regional
            return Set([GeographicRegion.allCases.randomElement()!])
        case .pandemic, .recession, .boom, .oilPriceSurge:
            // Global events
            return Set(GeographicRegion.allCases)
        case .tradeWar, .sanctions:
            // Bilateral/multilateral
            return Set(Array(GeographicRegion.allCases.shuffled().prefix(Int.random(in: 2...4))))
        case .piracy:
            // Specific high-risk regions
            return Set([.africa, .middleEast, .southeastAsia].shuffled().prefix(1))
        default:
            // Random regional impact
            let regionCount = Int.random(in: 1...3)
            return Set(Array(GeographicRegion.allCases.shuffled().prefix(regionCount)))
        }
    }
    
    private func shouldCreateDisasterEffect(for eventType: EconomicEventComponent.EconomicEventType) -> Bool {
        switch eventType {
        case .hurricaneWarning, .earthquake, .tsunami, .piracy, .cyberAttack, .environmentalDisaster:
            return true
        default:
            return false
        }
    }
    
    private func createDisasterEffect(for event: EconomicEventComponent, world: World) {
        let disasterType: DisasterEffectComponent.DisasterType
        
        switch event.eventType {
        case .hurricaneWarning: disasterType = .hurricane
        case .earthquake: disasterType = .earthquake
        case .tsunami: disasterType = .tsunami
        case .piracy: disasterType = .piracy
        case .cyberAttack: disasterType = .cyberAttack
        case .environmentalDisaster: disasterType = .flooding
        default: return
        }
        
        // Generate random position on the map
        let position = SIMD3<Float>(
            Float.random(in: -1000...1000),
            0,
            Float.random(in: -1000...1000)
        )
        
        let radius = Float.random(in: 100...500) * event.severity.impactMultiplier
        let intensity = Float.random(in: 0.3...1.0) * event.severity.hapticIntensity
        
        let disasterEffect = DisasterEffectComponent(
            disasterType: disasterType,
            position: position,
            radius: Float(radius),
            intensityLevel: intensity,
            duration: event.duration
        )
        
        let disasterEntity = world.createEntity()
        world.addComponent(disasterEffect, to: disasterEntity)
        
        NotificationCenter.default.post(
            name: Notification.Name("DisasterEffectCreated"),
            object: disasterEffect,
            userInfo: ["disasterEntity": disasterEntity, "parentEvent": event]
        )
    }
    
    private func updateEventEffects(event: EconomicEventComponent, world: World) {
        // Update market prices based on event
        if let economicSystem = world.getSystem(EconomicSystem.self) {
            // Apply price multipliers to affected commodities
            for commodity in event.affectedCommodities {
                // This would interact with the economic system to modify prices
            }
        }
    }
    
    private func finishEvent(_ event: EconomicEventComponent, world: World) {
        NotificationCenter.default.post(
            name: Notification.Name("EconomicEventFinished"),
            object: event
        )
        
        print("Economic event finished: \(event.name)")
    }
    
    private func updateGlobalMarketStress() {
        // Calculate stress based on active events
        let eventStress = activeEvents.values.reduce(0.0) { total, event in
            total + Double(event.severity.impactMultiplier)
        }
        
        globalMarketStress = Float(min(1.0, eventStress / 3.0)) // Normalize to 0-1
    }
    
    private func triggerHapticFeedback(for event: EconomicEventComponent) {
        // This will be handled by the haptic system
        NotificationCenter.default.post(
            name: Notification.Name("TriggerHapticFeedback"),
            object: nil,
            userInfo: [
                "eventType": event.eventType,
                "severity": event.severity,
                "intensity": event.severity.hapticIntensity
            ]
        )
    }
    
    public func getActiveEvents() -> [EconomicEventComponent] {
        return Array(activeEvents.values)
    }
    
    public func getGlobalMarketStress() -> Float {
        return globalMarketStress
    }
}

// MARK: - Disaster Effect System

/// System for managing disaster effects on ships and routes
public class DisasterEffectSystem: System {
    public let priority = 95
    public let canRunInParallel = true
    public let requiredComponents: [ComponentType] = [.disasterEffect]
    
    public func update(deltaTime: TimeInterval, world: World) {
        let disasterEntities = world.getEntitiesWithComponents(requiredComponents)
        
        for disasterEntity in disasterEntities {
            guard var disaster = world.getComponent(DisasterEffectComponent.self, for: disasterEntity) else {
                continue
            }
            
            // Update disaster duration
            disaster.remainingDuration -= deltaTime
            
            if disaster.remainingDuration <= 0 {
                // Disaster expired, remove it
                world.removeEntity(disasterEntity)
                continue
            }
            
            // Apply effects to nearby ships
            applyDisasterEffects(disaster: disaster, world: world)
            
            // Update disaster component
            world.addComponent(disaster, to: disasterEntity)
        }
    }
    
    private func applyDisasterEffects(disaster: DisasterEffectComponent, world: World) {
        // Find all ships within disaster radius
        let nearbyShips = world.entityManager.getEntitiesInRegion(
            center: disaster.position,
            radius: disaster.radius
        )
        
        for shipEntity in nearbyShips {
            guard let ship = world.getComponent(ShipComponent.self, for: shipEntity),
                  let transform = world.getComponent(TransformComponent.self, for: shipEntity) else {
                continue
            }
            
            let distance = simd_distance(transform.position, disaster.position)
            guard distance <= disaster.radius else { continue }
            
            // Calculate effect intensity based on distance
            let effectIntensity = 1.0 - (distance / disaster.radius)
            let adjustedIntensity = disaster.intensityLevel * effectIntensity
            
            // Apply speed reduction
            if var physics = world.getComponent(PhysicsComponent.self, for: shipEntity) {
                physics.maxSpeed *= disaster.speedMultiplier
                world.addComponent(physics, to: shipEntity)
            }
            
            // Apply fuel consumption increase
            if var fuelComponent = world.getComponent(FuelComponent.self, for: shipEntity) {
                fuelComponent.consumptionRate *= disaster.fuelConsumptionMultiplier
                world.addComponent(fuelComponent, to: shipEntity)
            }
            
            // Apply damage over time
            if var assetManagement = world.getComponent(AssetManagementComponent.self, for: shipEntity) {
                let damageAmount = disaster.damageRate * Float(1.0/60.0) * adjustedIntensity // Per frame damage
                assetManagement.condition = max(0.0, assetManagement.condition - damageAmount)
                
                // Add cost record for disaster damage
                assetManagement.addCost(
                    Double(damageAmount * 10000), // Convert to monetary damage
                    category: .emergency,
                    description: "Damage from \(disaster.disasterType.rawValue)"
                )
                
                world.addComponent(assetManagement, to: shipEntity)
            }
            
            // Trigger emergency protocols if damage is severe
            if adjustedIntensity > 0.7 {
                triggerEmergencyProtocols(for: shipEntity, disaster: disaster, world: world)
            }
            
            // Create visual and audio effects
            createDisasterVisualEffects(for: shipEntity, disaster: disaster, intensity: adjustedIntensity, world: world)
        }
    }
    
    private func triggerEmergencyProtocols(for shipEntity: Entity, disaster: DisasterEffectComponent, world: World) {
        // Trigger haptic feedback for emergency
        NotificationCenter.default.post(
            name: Notification.Name("EmergencyHapticFeedback"),
            object: nil,
            userInfo: [
                "shipEntity": shipEntity,
                "disasterType": disaster.disasterType,
                "pattern": disaster.hapticPattern,
                "intensity": disaster.intensityLevel
            ]
        )
        
        // Update ship status to emergency
        if var assetManagement = world.getComponent(AssetManagementComponent.self, for: shipEntity) {
            assetManagement.operationalStatus = .emergency
            world.addComponent(assetManagement, to: shipEntity)
        }
        
        // Force rerouting if possible
        if var route = world.getComponent(RouteComponent.self, for: shipEntity) {
            // Try to find alternative route to nearest safe port
            findEmergencyRoute(for: shipEntity, disaster: disaster, route: &route, world: world)
            world.addComponent(route, to: shipEntity)
        }
    }
    
    private func findEmergencyRoute(
        for shipEntity: Entity,
        disaster: DisasterEffectComponent,
        route: inout RouteComponent,
        world: World
    ) {
        guard let transform = world.getComponent(TransformComponent.self, for: shipEntity) else { return }
        
        // Find nearest port outside disaster radius
        let allPorts = world.getEntitiesWithComponents([.port])
        var nearestSafePort: Entity?
        var nearestDistance: Float = Float.infinity
        
        for portEntity in allPorts {
            guard let portTransform = world.getComponent(TransformComponent.self, for: portEntity) else {
                continue
            }
            
            let distanceToDisaster = simd_distance(portTransform.position, disaster.position)
            if distanceToDisaster > disaster.radius * 1.2 { // Safe margin
                let distanceToShip = simd_distance(transform.position, portTransform.position)
                if distanceToShip < nearestDistance {
                    nearestDistance = distanceToShip
                    nearestSafePort = portEntity
                }
            }
        }
        
        // Update route to emergency port
        if let safePort = nearestSafePort,
           let safePortTransform = world.getComponent(TransformComponent.self, for: safePort) {
            route.waypoints = [transform.position, safePortTransform.position]
            route.currentWaypointIndex = 0
            route.isReversed = false
            route.loopRoute = false
        }
    }
    
    private func createDisasterVisualEffects(
        for shipEntity: Entity,
        disaster: DisasterEffectComponent,
        intensity: Float,
        world: World
    ) {
        // Create visual effect component for renderer
        let visualEffect = VisualEffectComponent(
            effectType: getVisualEffectType(for: disaster.disasterType),
            intensity: intensity,
            duration: min(5.0, disaster.remainingDuration),
            position: disaster.position,
            attachedEntity: shipEntity
        )
        
        let effectEntity = world.createEntity()
        world.addComponent(visualEffect, to: effectEntity)
        
        // Trigger audio effect
        NotificationCenter.default.post(
            name: Notification.Name("TriggerAudioEffect"),
            object: nil,
            userInfo: [
                "audioEffect": disaster.audioEffectType,
                "intensity": intensity,
                "position": disaster.position
            ]
        )
    }
    
    private func getVisualEffectType(for disasterType: DisasterEffectComponent.DisasterType) -> VisualEffectComponent.EffectType {
        switch disasterType {
        case .hurricane: return .hurricane
        case .tsunami: return .tsunami
        case .earthquake: return .earthquake
        case .storm: return .storm
        case .fog: return .fog
        case .piracy: return .explosion
        case .cyberAttack: return .electrical
        case .fire: return .fire
        case .flooding: return .water
        }
    }
}

// MARK: - Asset Management System

/// System for managing assets, maintenance, and costs
public class AssetManagementSystem: System {
    public let priority = 85
    public let canRunInParallel = true
    public let requiredComponents: [ComponentType] = [.assetManagement]
    
    private let maintenanceCheckInterval: TimeInterval = 60.0 // Check every minute
    private var lastMaintenanceCheck = Date()
    
    public func update(deltaTime: TimeInterval, world: World) {
        let assetEntities = world.getEntitiesWithComponents(requiredComponents)
        
        for assetEntity in assetEntities {
            guard var assetManagement = world.getComponent(AssetManagementComponent.self, for: assetEntity) else {
                continue
            }
            
            // Update asset condition based on usage
            updateAssetCondition(&assetManagement, deltaTime: deltaTime, world: world)
            
            // Process ongoing costs
            processOngoingCosts(&assetManagement, deltaTime: deltaTime)
            
            // Check maintenance schedules
            if Date().timeIntervalSince(lastMaintenanceCheck) >= maintenanceCheckInterval {
                checkMaintenanceSchedule(&assetManagement, assetEntity: assetEntity, world: world)
            }
            
            // Update crew morale and efficiency
            updateCrewMetrics(&assetManagement, deltaTime: deltaTime)
            
            world.addComponent(assetManagement, to: assetEntity)
        }
        
        if Date().timeIntervalSince(lastMaintenanceCheck) >= maintenanceCheckInterval {
            lastMaintenanceCheck = Date()
        }
    }
    
    private func updateAssetCondition(
        _ assetManagement: inout AssetManagementComponent,
        deltaTime: TimeInterval,
        world: World
    ) {
        // Base degradation rate (0.1% per hour for active assets)
        let baseDegradationRate: Float = 0.001 / 3600.0
        
        // Modify degradation based on operational status
        let statusMultiplier: Float
        switch assetManagement.operationalStatus {
        case .active: statusMultiplier = 1.0
        case .maintenance: statusMultiplier = -0.5 // Condition improves during maintenance
        case .damaged: statusMultiplier = 2.0 // Condition degrades faster when damaged
        case .idle: statusMultiplier = 0.1 // Minimal degradation when idle
        case .emergency: statusMultiplier = 3.0 // Rapid degradation in emergency
        case .decommissioned: statusMultiplier = 0.0 // No change when decommissioned
        }
        
        // Apply crew efficiency effect
        let crewEffect = (assetManagement.crewEfficiency - 0.5) * 0.5 // ±25% effect
        let finalMultiplier = statusMultiplier * (1.0 + crewEffect)
        
        let conditionChange = baseDegradationRate * finalMultiplier * Float(deltaTime)
        assetManagement.condition = max(0.0, min(1.0, assetManagement.condition - conditionChange))
        
        // Update operational status based on condition
        if assetManagement.condition < 0.2 && assetManagement.operationalStatus == .active {
            assetManagement.operationalStatus = .damaged
        } else if assetManagement.condition > 0.8 && assetManagement.operationalStatus == .damaged {
            assetManagement.operationalStatus = .active
        }
    }
    
    private func processOngoingCosts(_ assetManagement: inout AssetManagementComponent, deltaTime: TimeInterval) {
        let hoursElapsed = deltaTime / 3600.0
        
        // Calculate hourly costs
        let hourlyCrew = (assetManagement.maintenanceCost * 0.3) / (365 * 24) // 30% of annual maintenance for crew
        let hourlyInsurance = assetManagement.insurancePremium / (365 * 24) // Insurance spread over year
        let hourlyMaintenance = (assetManagement.maintenanceCost * 0.7) / (365 * 24) // 70% for actual maintenance
        
        // Apply costs based on operational status
        let costMultiplier: Double
        switch assetManagement.operationalStatus {
        case .active: costMultiplier = 1.0
        case .maintenance: costMultiplier = 1.5 // Higher costs during maintenance
        case .damaged: costMultiplier = 2.0 // Emergency repair costs
        case .idle: costMultiplier = 0.3 // Reduced costs when idle
        case .emergency: costMultiplier = 3.0 // Emergency operation costs
        case .decommissioned: costMultiplier = 0.1 // Minimal storage costs
        }
        
        let totalHourlyCost = (hourlyCrew + hourlyInsurance + hourlyMaintenance) * costMultiplier * hoursElapsed
        
        // Add cost records periodically (every 6 hours)
        let sixHours: TimeInterval = 6 * 3600
        if let lastCost = assetManagement.costHistory.last,
           Date().timeIntervalSince(lastCost.date) >= sixHours {
            
            assetManagement.addCost(
                totalHourlyCost,
                category: .maintenance,
                description: "Operational costs (\(assetManagement.operationalStatus.rawValue))"
            )
        }
    }
    
    private func checkMaintenanceSchedule(
        _ assetManagement: inout AssetManagementComponent,
        assetEntity: Entity,
        world: World
    ) {
        guard let scheduledDate = assetManagement.scheduledMaintenanceDate else { return }
        
        // Check if maintenance is due
        if Date() >= scheduledDate && assetManagement.operationalStatus != .maintenance {
            // Start maintenance
            assetManagement.operationalStatus = .maintenance
            assetManagement.lastMaintenanceDate = Date()
            
            // Schedule next maintenance (6 months from now)
            assetManagement.scheduledMaintenanceDate = Calendar.current.date(
                byAdding: .month,
                value: 6,
                to: Date()
            )
            
            // Calculate maintenance cost
            let maintenanceCost = assetManagement.value * 0.02 // 2% of asset value
            assetManagement.addCost(
                maintenanceCost,
                category: .maintenance,
                description: "Scheduled maintenance"
            )
            
            // Notify about maintenance start
            NotificationCenter.default.post(
                name: Notification.Name("AssetMaintenanceStarted"),
                object: assetEntity,
                userInfo: ["assetManagement": assetManagement]
            )
        }
        
        // Check if maintenance should complete (condition improved to 95%+)
        if assetManagement.operationalStatus == .maintenance && assetManagement.condition >= 0.95 {
            assetManagement.operationalStatus = .active
            
            NotificationCenter.default.post(
                name: Notification.Name("AssetMaintenanceCompleted"),
                object: assetEntity,
                userInfo: ["assetManagement": assetManagement]
            )
        }
    }
    
    private func updateCrewMetrics(_ assetManagement: inout AssetManagementComponent, deltaTime: TimeInterval) {
        // Crew morale changes based on various factors
        let moraleChangeRate: Float = 0.001 / 3600.0 // Base change per hour
        
        // Factors affecting morale
        var moraleChange: Float = 0
        
        // Asset condition affects morale
        if assetManagement.condition > 0.8 {
            moraleChange += moraleChangeRate * 0.5 // Good conditions improve morale
        } else if assetManagement.condition < 0.3 {
            moraleChange -= moraleChangeRate * 2.0 // Poor conditions hurt morale
        }
        
        // Emergency situations hurt morale
        if assetManagement.operationalStatus == .emergency {
            moraleChange -= moraleChangeRate * 3.0
        }
        
        // Maintenance periods slightly improve morale (rest time)
        if assetManagement.operationalStatus == .maintenance {
            moraleChange += moraleChangeRate * 0.3
        }
        
        assetManagement.crewMorale = max(0.0, min(1.0, assetManagement.crewMorale + moraleChange * Float(deltaTime)))
        
        // Crew efficiency is influenced by morale and asset condition
        let targetEfficiency = (assetManagement.crewMorale * 0.6 + assetManagement.condition * 0.4)
        let efficiencyChangeRate: Float = 0.5 // How quickly efficiency adapts
        
        assetManagement.crewEfficiency += (targetEfficiency - assetManagement.crewEfficiency) * efficiencyChangeRate * Float(deltaTime)
        assetManagement.crewEfficiency = max(0.0, min(1.0, assetManagement.crewEfficiency))
    }
}

// MARK: - Visual Effect Component

/// Component for visual effects created by disasters and events
public struct VisualEffectComponent: Component {
    public static let componentType = ComponentType.visualEffect
    
    public var effectType: EffectType
    public var intensity: Float
    public var duration: TimeInterval
    public var remainingDuration: TimeInterval
    public var position: SIMD3<Float>
    public var attachedEntity: Entity?
    public var scale: Float
    public var color: SIMD4<Float>
    public var animationSpeed: Float
    
    public enum EffectType: String, Codable {
        case hurricane
        case tsunami
        case earthquake
        case storm
        case fog
        case explosion
        case electrical
        case fire
        case water
        case smoke
        case sparks
    }
    
    public init(
        effectType: EffectType,
        intensity: Float,
        duration: TimeInterval,
        position: SIMD3<Float>,
        attachedEntity: Entity? = nil
    ) {
        self.effectType = effectType
        self.intensity = intensity
        self.duration = duration
        self.remainingDuration = duration
        self.position = position
        self.attachedEntity = attachedEntity
        self.scale = intensity
        self.color = VisualEffectComponent.getDefaultColor(for: effectType)
        self.animationSpeed = intensity * 2.0
    }
    
    private static func getDefaultColor(for effectType: EffectType) -> SIMD4<Float> {
        switch effectType {
        case .hurricane: return SIMD4<Float>(0.3, 0.3, 0.3, 0.8) // Dark gray
        case .tsunami: return SIMD4<Float>(0.0, 0.4, 0.8, 0.9) // Blue
        case .earthquake: return SIMD4<Float>(0.6, 0.4, 0.2, 0.7) // Brown
        case .storm: return SIMD4<Float>(0.2, 0.2, 0.2, 0.8) // Dark gray
        case .fog: return SIMD4<Float>(0.9, 0.9, 0.9, 0.6) // Light gray
        case .explosion: return SIMD4<Float>(1.0, 0.5, 0.0, 1.0) // Orange
        case .electrical: return SIMD4<Float>(0.0, 0.8, 1.0, 1.0) // Electric blue
        case .fire: return SIMD4<Float>(1.0, 0.3, 0.0, 1.0) // Red-orange
        case .water: return SIMD4<Float>(0.0, 0.6, 1.0, 0.8) // Blue
        case .smoke: return SIMD4<Float>(0.5, 0.5, 0.5, 0.7) // Gray
        case .sparks: return SIMD4<Float>(1.0, 1.0, 0.5, 1.0) // Yellow-white
        }
    }
}

// MARK: - Extended Component Types

extension ComponentType {
    public static let visualEffect = ComponentType(rawValue: "visualEffect")
    public static let fuelComponent = ComponentType(rawValue: "fuelComponent")
}

/// Fuel component for ships
public struct FuelComponent: Component {
    public static let componentType = ComponentType.fuelComponent
    
    public var currentFuel: Float
    public var capacity: Float
    public var consumptionRate: Float // Per hour
    public var fuelType: FuelType
    public var efficiency: Float
    
    public enum FuelType: String, Codable {
        case diesel
        case heavyFuelOil
        case lng
        case hydrogen
        case electric
    }
    
    public init(capacity: Float, fuelType: FuelType = .diesel) {
        self.capacity = capacity
        self.currentFuel = capacity
        self.consumptionRate = capacity * 0.1 // 10% per hour default
        self.fuelType = fuelType
        self.efficiency = 1.0
    }
    
    public var fuelPercentage: Float {
        guard capacity > 0 else { return 0 }
        return currentFuel / capacity
    }
}