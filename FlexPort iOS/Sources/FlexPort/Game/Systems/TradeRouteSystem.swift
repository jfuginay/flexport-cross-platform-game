import Foundation
import GameplayKit

// MARK: - Trade Route Management System
class TradeRouteSystem: ObservableObject {
    @Published var activeRoutes: [TradeRoute] = []
    @Published var discoveredPorts: Set<Port> = []
    
    private let pathfinder = TradeRoutePathfinder()
    
    func calculateOptimalRoute(from origin: Port, to destination: Port, cargo: Cargo) -> TradeRoute? {
        // Use A* pathfinding with economic considerations
        let path = pathfinder.findOptimalPath(
            from: origin,
            to: destination,
            cargo: cargo,
            consideringFactors: .all
        )
        
        guard let validPath = path else { return nil }
        
        return TradeRoute(
            id: UUID(),
            origin: origin,
            destination: destination,
            waypoints: validPath.waypoints,
            cargo: cargo,
            estimatedProfit: validPath.estimatedProfit,
            estimatedDuration: validPath.estimatedDuration,
            riskLevel: validPath.riskLevel
        )
    }
    
    func executeRoute(_ route: TradeRoute, with asset: TransportAsset) -> RouteExecution {
        let execution = RouteExecution(route: route, asset: asset)
        execution.start()
        activeRoutes.append(route)
        return execution
    }
    
    func optimizeAllRoutes() {
        // Re-calculate all active routes based on current market conditions
        activeRoutes = activeRoutes.compactMap { route in
            calculateOptimalRoute(
                from: route.origin,
                to: route.destination,
                cargo: route.cargo
            )
        }
    }
}

// MARK: - Pathfinding Algorithm
class TradeRoutePathfinder {
    struct PathfindingFactors: OptionSet {
        let rawValue: Int
        
        static let distance = PathfindingFactors(rawValue: 1 << 0)
        static let fuelCost = PathfindingFactors(rawValue: 1 << 1)
        static let marketDemand = PathfindingFactors(rawValue: 1 << 2)
        static let weatherRisk = PathfindingFactors(rawValue: 1 << 3)
        static let politicalStability = PathfindingFactors(rawValue: 1 << 4)
        static let congestion = PathfindingFactors(rawValue: 1 << 5)
        
        static let all: PathfindingFactors = [.distance, .fuelCost, .marketDemand, .weatherRisk, .politicalStability, .congestion]
    }
    
    struct PathResult {
        let waypoints: [Port]
        let estimatedProfit: Double
        let estimatedDuration: TimeInterval
        let riskLevel: Double
    }
    
    func findOptimalPath(from origin: Port, to destination: Port, cargo: Cargo, consideringFactors factors: PathfindingFactors) -> PathResult? {
        // Implement A* pathfinding with economic heuristics
        var openSet = Set<Port>([origin])
        var cameFrom = [Port: Port]()
        var gScore = [Port: Double]()
        var fScore = [Port: Double]()
        
        gScore[origin] = 0
        fScore[origin] = heuristicCost(from: origin, to: destination, cargo: cargo, factors: factors)
        
        while !openSet.isEmpty {
            guard let current = openSet.min(by: { fScore[$0, default: .infinity] < fScore[$1, default: .infinity] }) else {
                break
            }
            
            if current == destination {
                return reconstructPath(cameFrom: cameFrom, current: current, cargo: cargo)
            }
            
            openSet.remove(current)
            
            for neighbor in current.connectedPorts {
                let tentativeGScore = gScore[current, default: .infinity] + 
                    calculateCost(from: current, to: neighbor, cargo: cargo, factors: factors)
                
                if tentativeGScore < gScore[neighbor, default: .infinity] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeGScore
                    fScore[neighbor] = tentativeGScore + heuristicCost(from: neighbor, to: destination, cargo: cargo, factors: factors)
                    openSet.insert(neighbor)
                }
            }
        }
        
        return nil
    }
    
    private func heuristicCost(from: Port, to: Port, cargo: Cargo, factors: PathfindingFactors) -> Double {
        var cost = 0.0
        
        if factors.contains(.distance) {
            cost += from.location.distance(to: to.location)
        }
        
        if factors.contains(.marketDemand) {
            cost -= to.marketDemand[cargo.type, default: 1.0] * 100
        }
        
        if factors.contains(.weatherRisk) {
            cost += from.weatherRisk * 50
        }
        
        return max(0, cost)
    }
    
    private func calculateCost(from: Port, to: Port, cargo: Cargo, factors: PathfindingFactors) -> Double {
        var cost = 0.0
        
        if factors.contains(.distance) {
            cost += from.location.distance(to: to.location) * 0.1 // Cost per mile
        }
        
        if factors.contains(.fuelCost) {
            let fuelConsumption = from.location.distance(to: to.location) * 0.05
            cost += fuelConsumption * from.fuelPrice
        }
        
        if factors.contains(.congestion) {
            cost += to.congestionLevel * 20
        }
        
        return cost
    }
    
    private func reconstructPath(cameFrom: [Port: Port], current: Port, cargo: Cargo) -> PathResult {
        var waypoints = [current]
        var node = current
        
        while let previous = cameFrom[node] {
            waypoints.insert(previous, at: 0)
            node = previous
        }
        
        let estimatedProfit = calculateEstimatedProfit(path: waypoints, cargo: cargo)
        let estimatedDuration = calculateEstimatedDuration(path: waypoints)
        let riskLevel = calculateRiskLevel(path: waypoints)
        
        return PathResult(
            waypoints: waypoints,
            estimatedProfit: estimatedProfit,
            estimatedDuration: estimatedDuration,
            riskLevel: riskLevel
        )
    }
    
    private func calculateEstimatedProfit(path: [Port], cargo: Cargo) -> Double {
        guard let origin = path.first, let destination = path.last else { return 0 }
        
        let buyPrice = origin.marketPrices[cargo.type, default: 100] * Double(cargo.quantity)
        let sellPrice = destination.marketPrices[cargo.type, default: 100] * Double(cargo.quantity)
        let transportCost = path.enumerated().dropFirst().reduce(0.0) { cost, element in
            let (index, port) = element
            return cost + path[index - 1].location.distance(to: port.location) * 0.1
        }
        
        return sellPrice - buyPrice - transportCost
    }
    
    private func calculateEstimatedDuration(path: [Port]) -> TimeInterval {
        return path.enumerated().dropFirst().reduce(0.0) { duration, element in
            let (index, port) = element
            let distance = path[index - 1].location.distance(to: port.location)
            return duration + (distance / 30) * 3600 // Assuming 30 mph average speed
        }
    }
    
    private func calculateRiskLevel(path: [Port]) -> Double {
        let averageRisk = path.reduce(0.0) { $0 + $1.weatherRisk + $1.politicalRisk } / Double(path.count)
        return min(1.0, averageRisk)
    }
}

// MARK: - Supporting Models
struct TradeRoute: Identifiable {
    let id: UUID
    let origin: Port
    let destination: Port
    let waypoints: [Port]
    let cargo: Cargo
    let estimatedProfit: Double
    let estimatedDuration: TimeInterval
    let riskLevel: Double
}

struct Port: Hashable {
    let id: UUID
    let name: String
    let location: Location
    let type: PortType
    var connectedPorts: Set<Port>
    var marketPrices: [CargoType: Double]
    var marketDemand: [CargoType: Double]
    var fuelPrice: Double
    var congestionLevel: Double
    var weatherRisk: Double
    var politicalRisk: Double
    
    static func == (lhs: Port, rhs: Port) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Cargo {
    let type: CargoType
    let quantity: Int
    let weight: Double
    let value: Double
    let perishable: Bool
    let specialHandling: Set<SpecialHandling>
}

enum CargoType: String, CaseIterable {
    case electronics
    case textiles
    case food
    case rawMaterials
    case machinery
    case chemicals
    case vehicles
}

enum SpecialHandling: String {
    case refrigerated
    case hazmat
    case fragile
    case oversized
    case highValue
}

protocol TransportAsset {
    var id: UUID { get }
    var capacity: Double { get }
    var speed: Double { get }
    var efficiency: Double { get }
    var currentLocation: Location { get }
}

class RouteExecution: ObservableObject {
    @Published var status: ExecutionStatus = .pending
    @Published var currentLocation: Location
    @Published var progress: Double = 0.0
    @Published var estimatedArrival: Date?
    
    let route: TradeRoute
    let asset: TransportAsset
    private var timer: Timer?
    
    init(route: TradeRoute, asset: TransportAsset) {
        self.route = route
        self.asset = asset
        self.currentLocation = asset.currentLocation
    }
    
    func start() {
        status = .inProgress
        estimatedArrival = Date().addingTimeInterval(route.estimatedDuration)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    func pause() {
        status = .paused
        timer?.invalidate()
    }
    
    func resume() {
        status = .inProgress
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateProgress() {
        progress += 1.0 / route.estimatedDuration
        
        if progress >= 1.0 {
            complete()
        }
    }
    
    private func complete() {
        status = .completed
        timer?.invalidate()
        currentLocation = route.destination.location
    }
}

enum ExecutionStatus {
    case pending
    case inProgress
    case paused
    case completed
    case failed
}

extension Location {
    func distance(to other: Location) -> Double {
        // Haversine formula for great circle distance
        let R = 6371.0 // Earth's radius in kilometers
        
        let lat1 = coordinates.latitude * .pi / 180
        let lat2 = other.coordinates.latitude * .pi / 180
        let deltaLat = (other.coordinates.latitude - coordinates.latitude) * .pi / 180
        let deltaLon = (other.coordinates.longitude - coordinates.longitude) * .pi / 180
        
        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    }
}