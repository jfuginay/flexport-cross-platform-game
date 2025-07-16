import Foundation
import simd

/// Advanced pathfinding system for trade routes using A* with dynamic obstacles
public class PathfindingSystem {
    private var navigationGrid: NavigationGrid
    private var dynamicObstacles: [DynamicObstacle] = []
    private var staticObstacles: [StaticObstacle] = []
    
    public init(worldSize: SIMD2<Int>) {
        self.navigationGrid = NavigationGrid(size: worldSize)
        initializeStaticObstacles()
    }
    
    private func initializeStaticObstacles() {
        // Major landmasses and shallow waters
        staticObstacles = [
            // Continents (simplified)
            StaticObstacle(region: GeographicRegion(minLat: 25, maxLat: 75, minLon: -130, maxLon: -60), type: .landmass, name: "North America"),
            StaticObstacle(region: GeographicRegion(minLat: -55, maxLat: 15, minLon: -85, maxLon: -35), type: .landmass, name: "South America"),
            StaticObstacle(region: GeographicRegion(minLat: 35, maxLat: 75, minLon: -15, maxLon: 45), type: .landmass, name: "Europe"),
            StaticObstacle(region: GeographicRegion(minLat: -35, maxLat: 35, minLon: -20, maxLon: 50), type: .landmass, name: "Africa"),
            StaticObstacle(region: GeographicRegion(minLat: 5, maxLat: 80, minLon: 25, maxLon: 180), type: .landmass, name: "Asia"),
            StaticObstacle(region: GeographicRegion(minLat: -45, maxLat: -10, minLon: 110, maxLon: 155), type: .landmass, name: "Australia"),
            
            // Major straits and canals
            StaticObstacle(region: GeographicRegion(minLat: 29.5, maxLat: 31.5, minLon: 32, maxLon: 34), type: .canal, name: "Suez Canal"),
            StaticObstacle(region: GeographicRegion(minLat: 8.5, maxLat: 9.5, minLon: -80.5, maxLon: -79.5), type: .canal, name: "Panama Canal"),
            StaticObstacle(region: GeographicRegion(minLat: 1, maxLat: 2, minLon: 103, maxLon: 104), type: .strait, name: "Strait of Malacca"),
            StaticObstacle(region: GeographicRegion(minLat: 25, maxLat: 27, minLon: 56, maxLon: 58), type: .strait, name: "Strait of Hormuz"),
        ]
        
        // Update navigation grid with static obstacles
        updateNavigationGrid()
    }
    
    private func updateNavigationGrid() {
        navigationGrid.reset()
        
        // Mark static obstacles
        for obstacle in staticObstacles {
            navigationGrid.markObstacle(obstacle.region, cost: obstacle.type.navigationCost)
        }
        
        // Mark dynamic obstacles
        for obstacle in dynamicObstacles {
            navigationGrid.markTemporaryObstacle(obstacle.position, radius: obstacle.radius, cost: obstacle.type.navigationCost, duration: obstacle.remainingTime)
        }
    }
    
    /// Find optimal path between two points
    public func findPath(from start: SIMD3<Float>, to end: SIMD3<Float>, shipSize: ShipSize, constraints: PathfindingConstraints = PathfindingConstraints()) -> PathfindingResult {
        let startNode = navigationGrid.worldToGrid(SIMD2<Float>(start.x, start.y))
        let endNode = navigationGrid.worldToGrid(SIMD2<Float>(end.x, end.y))
        
        // Validate start and end points
        if !navigationGrid.isValidPosition(startNode) || !navigationGrid.isValidPosition(endNode) {
            return PathfindingResult(path: [], status: .invalidDestination, totalCost: Double.infinity)
        }
        
        // A* pathfinding
        var openSet: [PathNode] = [PathNode(position: startNode, gCost: 0, hCost: heuristic(startNode, endNode))]
        var closedSet: Set<SIMD2<Int>> = []
        var cameFrom: [SIMD2<Int>: SIMD2<Int>] = [:]
        var gScore: [SIMD2<Int>: Double] = [startNode: 0]
        
        while !openSet.isEmpty {
            // Get node with lowest f cost
            openSet.sort { $0.fCost < $1.fCost }
            let current = openSet.removeFirst()
            
            // Check if we reached the destination
            if current.position == endNode {
                let path = reconstructPath(cameFrom: cameFrom, current: endNode)
                let worldPath = path.map { navigationGrid.gridToWorld($0) }
                let totalCost = gScore[endNode] ?? Double.infinity
                
                return PathfindingResult(
                    path: worldPath.map { SIMD3<Float>($0.x, $0.y, 0) },
                    status: .success,
                    totalCost: totalCost
                )
            }
            
            closedSet.insert(current.position)
            
            // Check all neighbors
            for neighbor in getNeighbors(current.position) {
                if closedSet.contains(neighbor) {
                    continue
                }
                
                let movementCost = calculateMovementCost(from: current.position, to: neighbor, shipSize: shipSize, constraints: constraints)
                
                // Skip if impassable
                if movementCost == Double.infinity {
                    continue
                }
                
                let tentativeGScore = (gScore[current.position] ?? Double.infinity) + movementCost
                
                if tentativeGScore < (gScore[neighbor] ?? Double.infinity) {
                    cameFrom[neighbor] = current.position
                    gScore[neighbor] = tentativeGScore
                    
                    let hCost = heuristic(neighbor, endNode)
                    let newNode = PathNode(position: neighbor, gCost: tentativeGScore, hCost: hCost)
                    
                    // Add to open set if not already there
                    if !openSet.contains(where: { $0.position == neighbor }) {
                        openSet.append(newNode)
                    }
                }
            }
        }
        
        return PathfindingResult(path: [], status: .noPathFound, totalCost: Double.infinity)
    }
    
    /// Find multiple alternative paths
    public func findAlternativePaths(from start: SIMD3<Float>, to end: SIMD3<Float>, count: Int = 3, shipSize: ShipSize) -> [PathfindingResult] {
        var results: [PathfindingResult] = []
        var modifiedGrid = navigationGrid
        
        for i in 0..<count {
            let result = findPath(from: start, to: end, shipSize: shipSize)
            
            if result.status == .success && !result.path.isEmpty {
                results.append(result)
                
                // Temporarily increase cost of used path for next iteration
                if i < count - 1 {
                    for pathPoint in result.path {
                        let gridPos = modifiedGrid.worldToGrid(SIMD2<Float>(pathPoint.x, pathPoint.y))
                        modifiedGrid.increaseCost(at: gridPos, by: 10.0)
                    }
                }
            } else {
                break
            }
        }
        
        return results
    }
    
    /// Update dynamic obstacles (storms, traffic, etc.)
    public func updateDynamicObstacles(_ obstacles: [DynamicObstacle]) {
        self.dynamicObstacles = obstacles
        updateNavigationGrid()
    }
    
    /// Add temporary obstacle (storm, accident, etc.)
    public func addTemporaryObstacle(_ obstacle: DynamicObstacle) {
        dynamicObstacles.append(obstacle)
        updateNavigationGrid()
    }
    
    /// Calculate movement cost between adjacent grid cells
    private func calculateMovementCost(from: SIMD2<Int>, to: SIMD2<Int>, shipSize: ShipSize, constraints: PathfindingConstraints) -> Double {
        let baseCost = navigationGrid.getCost(at: to)
        
        // Impassable terrain
        if baseCost == Double.infinity {
            return Double.infinity
        }
        
        // Base movement cost (diagonal vs straight)
        let isDiagonal = abs(to.x - from.x) + abs(to.y - from.y) > 1
        var movementCost = isDiagonal ? 1.414 : 1.0
        
        // Apply terrain cost
        movementCost *= baseCost
        
        // Ship size restrictions
        let worldPos = navigationGrid.gridToWorld(to)
        if !canShipPassThrough(position: worldPos, shipSize: shipSize) {
            return Double.infinity
        }
        
        // Apply constraints
        if constraints.avoidStorms {
            let stormRisk = getStormRisk(at: worldPos)
            movementCost *= (1.0 + stormRisk * 5.0)
        }
        
        if constraints.avoidPiracy {
            let piracyRisk = getPiracyRisk(at: worldPos)
            movementCost *= (1.0 + piracyRisk * 3.0)
        }
        
        // Distance-based fuel cost
        movementCost *= constraints.fuelEfficiencyWeight
        
        return movementCost
    }
    
    private func canShipPassThrough(position: SIMD2<Float>, shipSize: ShipSize) -> Bool {
        // Check if ship can pass through narrow straits
        for obstacle in staticObstacles {
            if obstacle.type == .strait && obstacle.region.contains(position) {
                return shipSize != .ultraLarge // Ultra large ships can't use all straits
            }
        }
        return true
    }
    
    private func getStormRisk(at position: SIMD2<Float>) -> Double {
        // Calculate storm risk based on dynamic obstacles
        for obstacle in dynamicObstacles {
            if obstacle.type == .storm {
                let distance = length(obstacle.position - position)
                if distance < obstacle.radius {
                    return Double(1.0 - distance / obstacle.radius)
                }
            }
        }
        return 0.0
    }
    
    private func getPiracyRisk(at position: SIMD2<Float>) -> Double {
        // Check against known piracy zones
        for zone in PiracyZone.globalZones {
            if zone.region.contains(position) {
                return Double(zone.threatLevel)
            }
        }
        return 0.0
    }
    
    private func heuristic(_ a: SIMD2<Int>, _ b: SIMD2<Int>) -> Double {
        // Manhattan distance with diagonal movement
        let dx = abs(a.x - b.x)
        let dy = abs(a.y - b.y)
        return Double(max(dx, dy) + min(dx, dy) * 0.414) // Approximation of sqrt(2) - 1
    }
    
    private func getNeighbors(_ position: SIMD2<Int>) -> [SIMD2<Int>] {
        var neighbors: [SIMD2<Int>] = []
        
        // 8-directional movement
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                
                let neighbor = SIMD2<Int>(position.x + dx, position.y + dy)
                if navigationGrid.isValidPosition(neighbor) {
                    neighbors.append(neighbor)
                }
            }
        }
        
        return neighbors
    }
    
    private func reconstructPath(cameFrom: [SIMD2<Int>: SIMD2<Int>], current: SIMD2<Int>) -> [SIMD2<Int>] {
        var path: [SIMD2<Int>] = [current]
        var currentNode = current
        
        while let previous = cameFrom[currentNode] {
            path.insert(previous, at: 0)
            currentNode = previous
        }
        
        return path
    }
    
    /// Optimize path by removing unnecessary waypoints
    public func optimizePath(_ path: [SIMD3<Float>]) -> [SIMD3<Float>] {
        if path.count <= 2 {
            return path
        }
        
        var optimized: [SIMD3<Float>] = [path[0]]
        
        for i in 1..<(path.count - 1) {
            let prev = path[i - 1]
            let current = path[i]
            let next = path[i + 1]
            
            // Check if we can skip this waypoint
            if !canSkipWaypoint(from: prev, to: next, shipSize: .medium) {
                optimized.append(current)
            }
        }
        
        optimized.append(path[path.count - 1])
        return optimized
    }
    
    private func canSkipWaypoint(from start: SIMD3<Float>, to end: SIMD3<Float>, shipSize: ShipSize) -> Bool {
        // Simple line-of-sight check
        let direction = end - start
        let distance = length(direction)
        let step = normalize(direction) * 0.5
        
        var current = start
        let stepCount = Int(distance / 0.5)
        
        for _ in 0..<stepCount {
            current += step
            let gridPos = navigationGrid.worldToGrid(SIMD2<Float>(current.x, current.y))
            
            if navigationGrid.getCost(at: gridPos) == Double.infinity {
                return false
            }
            
            if !canShipPassThrough(position: SIMD2<Float>(current.x, current.y), shipSize: shipSize) {
                return false
            }
        }
        
        return true
    }
}

/// Navigation grid for spatial partitioning
public class NavigationGrid {
    private var grid: [[NavigationCell]]
    private let size: SIMD2<Int>
    private let cellSize: Float = 1.0
    private let worldOffset: SIMD2<Float>
    
    public init(size: SIMD2<Int>) {
        self.size = size
        self.worldOffset = SIMD2<Float>(-Float(size.x) / 2, -Float(size.y) / 2)
        
        // Initialize grid
        grid = Array(repeating: Array(repeating: NavigationCell(), count: size.y), count: size.x)
    }
    
    public func reset() {
        for x in 0..<size.x {
            for y in 0..<size.y {
                grid[x][y] = NavigationCell()
            }
        }
    }
    
    public func markObstacle(_ region: GeographicRegion, cost: Double) {
        let minGrid = worldToGrid(SIMD2<Float>(Float(region.minLon), Float(region.minLat)))
        let maxGrid = worldToGrid(SIMD2<Float>(Float(region.maxLon), Float(region.maxLat)))
        
        for x in max(0, minGrid.x)...min(size.x - 1, maxGrid.x) {
            for y in max(0, minGrid.y)...min(size.y - 1, maxGrid.y) {
                grid[x][y].cost = cost
            }
        }
    }
    
    public func markTemporaryObstacle(_ position: SIMD2<Float>, radius: Float, cost: Double, duration: TimeInterval) {
        let centerGrid = worldToGrid(position)
        let gridRadius = Int(radius / cellSize)
        
        for x in max(0, centerGrid.x - gridRadius)...min(size.x - 1, centerGrid.x + gridRadius) {
            for y in max(0, centerGrid.y - gridRadius)...min(size.y - 1, centerGrid.y + gridRadius) {
                let gridPos = SIMD2<Int>(x, y)
                let worldPos = gridToWorld(gridPos)
                
                if length(worldPos - position) <= radius {
                    grid[x][y].temporaryCost = cost
                    grid[x][y].temporaryDuration = duration
                }
            }
        }
    }
    
    public func increaseCost(at position: SIMD2<Int>, by amount: Double) {
        if isValidPosition(position) {
            grid[position.x][position.y].cost += amount
        }
    }
    
    public func getCost(at position: SIMD2<Int>) -> Double {
        if !isValidPosition(position) {
            return Double.infinity
        }
        
        let cell = grid[position.x][position.y]
        let baseCost = cell.cost
        let tempCost = cell.temporaryDuration > 0 ? cell.temporaryCost : 1.0
        
        return baseCost * tempCost
    }
    
    public func isValidPosition(_ position: SIMD2<Int>) -> Bool {
        return position.x >= 0 && position.x < size.x && position.y >= 0 && position.y < size.y
    }
    
    public func worldToGrid(_ worldPos: SIMD2<Float>) -> SIMD2<Int> {
        let localPos = worldPos - worldOffset
        return SIMD2<Int>(Int(localPos.x / cellSize), Int(localPos.y / cellSize))
    }
    
    public func gridToWorld(_ gridPos: SIMD2<Int>) -> SIMD2<Float> {
        let localPos = SIMD2<Float>(Float(gridPos.x) * cellSize, Float(gridPos.y) * cellSize)
        return localPos + worldOffset
    }
}

/// Navigation cell in the grid
public struct NavigationCell {
    public var cost: Double = 1.0
    public var temporaryCost: Double = 1.0
    public var temporaryDuration: TimeInterval = 0.0
}

/// Pathfinding node for A* algorithm
public struct PathNode {
    public let position: SIMD2<Int>
    public let gCost: Double
    public let hCost: Double
    public var fCost: Double { gCost + hCost }
}

/// Pathfinding constraints
public struct PathfindingConstraints {
    public var avoidStorms: Bool = true
    public var avoidPiracy: Bool = true
    public var fuelEfficiencyWeight: Double = 1.0
    public var maxDetourPercentage: Double = 0.5 // 50% longer than direct route
    public var prioritizeSpeed: Bool = false
    public var prioritizeSafety: Bool = true
}

/// Pathfinding result
public struct PathfindingResult {
    public let path: [SIMD3<Float>]
    public let status: PathfindingStatus
    public let totalCost: Double
    
    public enum PathfindingStatus {
        case success
        case noPathFound
        case invalidDestination
        case constraintsNotMet
    }
}

/// Dynamic obstacles that change over time
public struct DynamicObstacle {
    public var position: SIMD2<Float>
    public var radius: Float
    public var type: ObstacleType
    public var remainingTime: TimeInterval
    
    public enum ObstacleType {
        case storm
        case traffic
        case accident
        case militaryZone
        case iceField
        
        var navigationCost: Double {
            switch self {
            case .storm: return 5.0
            case .traffic: return 2.0
            case .accident: return Double.infinity
            case .militaryZone: return Double.infinity
            case .iceField: return 3.0
            }
        }
    }
}

/// Static obstacles (landmasses, canals, etc.)
public struct StaticObstacle {
    public var region: GeographicRegion
    public var type: StaticObstacleType
    public var name: String
    
    public enum StaticObstacleType {
        case landmass
        case shallowWater
        case canal
        case strait
        case reef
        
        var navigationCost: Double {
            switch self {
            case .landmass: return Double.infinity
            case .shallowWater: return 3.0
            case .canal: return 1.5
            case .strait: return 2.0
            case .reef: return Double.infinity
            }
        }
    }
}