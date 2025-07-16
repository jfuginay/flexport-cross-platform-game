import Foundation
import simd

/// Factory for creating common game entities with optimized batching
public class WorldFactory {
    private weak var world: World?
    
    public init(world: World) {
        self.world = world
    }
    
    // MARK: - Ship Creation
    
    /// Create a ship entity with all necessary components
    public func createShip(
        name: String,
        position: SIMD3<Float>,
        shipClass: ShipClass = .containerShip,
        owner: Entity? = nil
    ) -> Entity? {
        guard let world = world else { return nil }
        
        let ship = world.createEntity(with: [
            TransformComponent(position: position),
            ShipComponent(
                name: name,
                capacity: shipClass == .containerShip ? 20000 : 50000,
                speed: shipClass == .containerShip ? 25.0 : 15.0,
                efficiency: shipClass.baseEfficiency,
                maintenanceCost: 10000.0,
                fuelCapacity: shipClass == .tanker ? 5000.0 : 2000.0
            ),
            PhysicsComponent(
                mass: shipClass == .bulkCarrier ? 100000.0 : 50000.0,
                maxSpeed: shipClass == .containerShip ? 25.0 : 20.0
            ),
            TouchInputComponent(
                isSelectable: true,
                isDraggable: false,
                selectionRadius: 50.0
            )
        ])
        
        // Add AI component for non-player ships
        if owner == nil || !isPlayerEntity(owner!) {
            world.addComponent(
                AIComponent(
                    behaviorType: .balanced,
                    learningRate: 0.01,
                    riskTolerance: 0.5
                ),
                to: ship
            )
        }
        
        return ship
    }
    
    /// Batch create multiple ships
    public func createShipFleet(
        baseName: String,
        count: Int,
        startPosition: SIMD3<Float>,
        spacing: Float = 100.0,
        shipClass: ShipClass = .containerShip
    ) -> [Entity] {
        guard let world = world else { return [] }
        
        var ships: [Entity] = []
        ships.reserveCapacity(count)
        
        // Pre-allocate entities for better performance
        let entities = world.entityManager.createEntitiesBatch(count: count)
        
        for (index, entity) in entities.enumerated() {
            let offset = SIMD3<Float>(
                Float(index % 10) * spacing,
                0,
                Float(index / 10) * spacing
            )
            
            let components: [Component] = [
                TransformComponent(position: startPosition + offset),
                ShipComponent(
                    name: "\(baseName) \(index + 1)",
                    capacity: 20000,
                    speed: 22.0,
                    efficiency: 0.85,
                    maintenanceCost: 8000.0,
                    fuelCapacity: 2000.0
                ),
                PhysicsComponent(mass: 60000.0, maxSpeed: 22.0),
                AIComponent(behaviorType: .balanced)
            ]
            
            for component in components {
                world.addComponent(component, to: entity)
            }
            
            ships.append(entity)
        }
        
        return ships
    }
    
    // MARK: - Port Creation
    
    /// Create a port entity with facilities
    public func createPort(
        name: String,
        position: SIMD3<Float>,
        portType: PortType = .megaPort,
        maxBerths: Int = 20
    ) -> Entity? {
        guard let world = world else { return nil }
        
        let port = world.createEntity(with: [
            TransformComponent(position: position),
            PortComponent(
                name: name,
                portType: portType,
                maxBerths: maxBerths,
                portFees: portType == .megaPort ? 200.0 : 100.0,
                handlingEfficiency: portType == .megaPort ? 0.95 : 0.80
            ),
            EconomyComponent(
                money: 10_000_000.0,
                creditRating: 0.8
            ),
            TouchInputComponent(
                isSelectable: true,
                isDraggable: false,
                selectionRadius: 100.0
            )
        ])
        
        // Add warehouse facilities to ports
        if portType == .megaPort || portType == .containerPort {
            world.addComponent(
                WarehouseComponent(
                    capacity: 100000,
                    storageCost: 50.0,
                    securityLevel: 0.9,
                    temperatureControl: portType == .containerPort
                ),
                to: port
            )
        }
        
        return port
    }
    
    /// Create a network of ports
    public func createPortNetwork(locations: [(String, SIMD3<Float>, PortType)]) -> [Entity] {
        var ports: [Entity] = []
        
        for (name, position, portType) in locations {
            if let port = createPort(name: name, position: position, portType: portType) {
                ports.append(port)
            }
        }
        
        return ports
    }
    
    // MARK: - Route Creation
    
    /// Create a trade route between ports
    public func createTradeRoute(
        name: String,
        waypoints: [SIMD3<Float>],
        commodity: String = "Container"
    ) -> Entity? {
        guard let world = world else { return nil }
        
        let routeId = UUID()
        let route = world.createEntity(with: [
            RouteComponent(routeId: routeId, waypoints: waypoints),
            EconomyComponent(money: 0.0) // Routes can track their profitability
        ])
        
        return route
    }
    
    /// Assign a ship to a trade route
    public func assignShipToRoute(ship: Entity, route: Entity) -> Bool {
        guard let world = world,
              let routeComponent = world.getComponent(RouteComponent.self, for: route) else {
            return false
        }
        
        world.addComponent(
            RouteComponent(
                routeId: routeComponent.routeId,
                waypoints: routeComponent.waypoints
            ),
            to: ship
        )
        
        return true
    }
    
    // MARK: - Cargo Creation
    
    /// Create cargo entity
    public func createCargo(
        commodity: String,
        quantity: Int,
        value: Double,
        origin: Entity,
        destination: Entity
    ) -> Entity? {
        guard let world = world else { return nil }
        
        let cargo = world.createEntity(with: [
            CargoComponent(
                commodityType: commodity,
                quantity: quantity,
                weight: Float(quantity) * 0.5,
                value: value,
                perishable: commodity == "Food" || commodity == "Medicine"
            )
        ])
        
        return cargo
    }
    
    // MARK: - AI Company Creation
    
    /// Create an AI-controlled shipping company
    public func createAICompany(
        name: String,
        startingCapital: Double = 5_000_000.0,
        aggressiveness: Float = 0.5
    ) -> Entity? {
        guard let world = world else { return nil }
        
        let company = world.createEntity(with: [
            EconomyComponent(
                money: startingCapital,
                creditRating: 0.7
            ),
            AIComponent(
                behaviorType: aggressiveness > 0.7 ? .aggressive : .balanced,
                learningRate: 0.02,
                riskTolerance: aggressiveness
            ),
            TraderComponent(
                traderType: .corporation,
                riskProfile: aggressiveness
            )
        ])
        
        // Add singularity component for advanced AI companies
        if aggressiveness > 0.8 {
            world.addComponent(
                SingularityComponent(computeLevel: 0.1),
                to: company
            )
        }
        
        return company
    }
    
    // MARK: - World Initialization
    
    /// Initialize a complete game world with ports, ships, and routes
    public func initializeGameWorld(
        numberOfPorts: Int = 20,
        numberOfShips: Int = 100,
        numberOfAICompanies: Int = 5
    ) {
        guard let world = world else { return }
        
        // Create major ports around the world
        let majorPorts = createMajorWorldPorts()
        
        // Create AI companies
        var companies: [Entity] = []
        for i in 0..<numberOfAICompanies {
            if let company = createAICompany(
                name: "AI Shipping Corp \(i + 1)",
                startingCapital: Double.random(in: 3_000_000...10_000_000),
                aggressiveness: Float.random(in: 0.3...0.9)
            ) {
                companies.append(company)
            }
        }
        
        // Create ships and assign to companies
        let shipsPerCompany = numberOfShips / max(numberOfAICompanies, 1)
        for (index, company) in companies.enumerated() {
            let companyShips = createShipFleet(
                baseName: "AI Ship",
                count: shipsPerCompany,
                startPosition: majorPorts.randomElement()?.1 ?? .zero,
                shipClass: [.containerShip, .bulkCarrier, .tanker].randomElement()!
            )
            
            // Assign ships to routes
            for ship in companyShips {
                if let origin = majorPorts.randomElement(),
                   let destination = majorPorts.randomElement(),
                   origin.0 != destination.0 {
                    
                    let waypoints = [origin.1, destination.1]
                    if let route = createTradeRoute(
                        name: "\(origin.0) - \(destination.0)",
                        waypoints: waypoints
                    ) {
                        assignShipToRoute(ship: ship, route: route)
                    }
                }
            }
        }
        
        // Create initial cargo at ports
        for port in majorPorts {
            if let portEntity = createPort(
                name: port.0,
                position: port.1,
                portType: .megaPort
            ) {
                // Add some initial cargo
                for _ in 0..<5 {
                    let commodities = ["Container", "Oil", "Grain", "Electronics", "Steel"]
                    if let commodity = commodities.randomElement(),
                       let destination = majorPorts.randomElement(),
                       destination.0 != port.0 {
                        
                        createCargo(
                            commodity: commodity,
                            quantity: Int.random(in: 100...1000),
                            value: Double.random(in: 10000...100000),
                            origin: portEntity,
                            destination: portEntity // Simplified, should be destination port entity
                        )
                    }
                }
            }
        }
    }
    
    /// Create major world ports with realistic positions
    private func createMajorWorldPorts() -> [(String, SIMD3<Float>, PortType)] {
        return [
            // North America
            ("Los Angeles", SIMD3<Float>(-2500, 0, 1000), .megaPort),
            ("Long Beach", SIMD3<Float>(-2480, 0, 980), .containerPort),
            ("New York", SIMD3<Float>(-1000, 0, 1200), .megaPort),
            ("Houston", SIMD3<Float>(-1500, 0, 800), .tankerPort),
            ("Vancouver", SIMD3<Float>(-2600, 0, 1500), .containerPort),
            
            // Europe
            ("Rotterdam", SIMD3<Float>(500, 0, 1600), .megaPort),
            ("Hamburg", SIMD3<Float>(600, 0, 1700), .containerPort),
            ("Antwerp", SIMD3<Float>(450, 0, 1580), .containerPort),
            ("London", SIMD3<Float>(300, 0, 1600), .generalPort),
            
            // Asia
            ("Shanghai", SIMD3<Float>(2500, 0, 1000), .megaPort),
            ("Singapore", SIMD3<Float>(2200, 0, 100), .megaPort),
            ("Hong Kong", SIMD3<Float>(2400, 0, 800), .containerPort),
            ("Yokohama", SIMD3<Float>(2800, 0, 1100), .containerPort),
            ("Busan", SIMD3<Float>(2600, 0, 1100), .containerPort),
            
            // Middle East
            ("Dubai", SIMD3<Float>(1500, 0, 800), .freePort),
            ("Jeddah", SIMD3<Float>(1200, 0, 700), .generalPort),
            
            // South America
            ("Santos", SIMD3<Float>(-1000, 0, -800), .bulkPort),
            ("Buenos Aires", SIMD3<Float>(-1200, 0, -1100), .generalPort),
            
            // Africa
            ("Cape Town", SIMD3<Float>(700, 0, -1100), .generalPort),
            ("Durban", SIMD3<Float>(900, 0, -1000), .bulkPort),
            
            // Oceania
            ("Sydney", SIMD3<Float>(2900, 0, -1100), .containerPort),
            ("Melbourne", SIMD3<Float>(2850, 0, -1200), .generalPort)
        ]
    }
    
    // MARK: - Helper Functions
    
    private func isPlayerEntity(_ entity: Entity) -> Bool {
        guard let world = world,
              let trader = world.getComponent(TraderComponent.self, for: entity) else {
            return false
        }
        return trader.traderType == .player
    }
}