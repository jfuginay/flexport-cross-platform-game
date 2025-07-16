import Foundation
import simd
import Metal
import Combine

/// Physics system for realistic trade route simulation
public class TradeRoutePhysics: ObservableObject {
    @Published public var activeRoutes: [TradeRoute] = []
    @Published public var weatherConditions: WeatherSystem
    @Published public var oceanCurrents: [OceanCurrent] = []
    
    private var metalDevice: MTLDevice?
    private var computePipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    
    public init() {
        self.weatherConditions = WeatherSystem()
        setupMetal()
        initializeOceanCurrents()
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
        
        guard let device = metalDevice else {
            print("Metal device not available")
            return
        }
        
        // Setup compute shader for physics calculations
        let library = device.makeDefaultLibrary()
        guard let kernelFunction = library?.makeFunction(name: "physicsKernel") else {
            print("Could not load physics kernel")
            return
        }
        
        do {
            computePipeline = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Could not create compute pipeline: \(error)")
        }
    }
    
    private func initializeOceanCurrents() {
        // Major ocean currents affecting global shipping
        oceanCurrents = [
            OceanCurrent(
                name: "Gulf Stream",
                region: GeographicRegion(
                    minLat: 25.0, maxLat: 45.0,
                    minLon: -80.0, maxLon: -30.0
                ),
                velocity: SIMD2<Float>(2.5, 1.0),
                temperature: 20.0,
                strength: 0.8
            ),
            OceanCurrent(
                name: "Kuroshio Current",
                region: GeographicRegion(
                    minLat: 20.0, maxLat: 40.0,
                    minLon: 120.0, maxLon: 160.0
                ),
                velocity: SIMD2<Float>(1.8, 0.5),
                temperature: 18.0,
                strength: 0.7
            ),
            OceanCurrent(
                name: "Agulhas Current",
                region: GeographicRegion(
                    minLat: -40.0, maxLat: -25.0,
                    minLon: 15.0, maxLon: 40.0
                ),
                velocity: SIMD2<Float>(0.0, -2.0),
                temperature: 22.0,
                strength: 0.9
            )
        ]
    }
    
    /// Update physics for all active routes
    public func update(deltaTime: TimeInterval) {
        // Update weather conditions
        weatherConditions.update(deltaTime: deltaTime)
        
        // Update all trade routes with physics
        for i in 0..<activeRoutes.count {
            updateRoutePhysics(&activeRoutes[i], deltaTime: deltaTime)
        }
        
        // Update ocean currents (seasonal variations)
        updateOceanCurrents(deltaTime: deltaTime)
    }
    
    private func updateRoutePhysics(_ route: inout TradeRoute, deltaTime: TimeInterval) {
        guard !route.waypoints.isEmpty else { return }
        
        // Calculate environmental effects
        let weatherEffect = calculateWeatherEffect(at: route.currentPosition)
        let currentEffect = calculateOceanCurrentEffect(at: route.currentPosition)
        
        // Update ship physics
        updateShipPhysics(&route, weatherEffect: weatherEffect, currentEffect: currentEffect, deltaTime: deltaTime)
        
        // Update route progress
        updateRouteProgress(&route, deltaTime: deltaTime)
        
        // Check for hazards and obstacles
        checkRouteHazards(&route)
    }
    
    private func updateShipPhysics(_ route: inout TradeRoute, weatherEffect: WeatherEffect, currentEffect: SIMD2<Float>, deltaTime: TimeInterval) {
        // Base speed modified by ship characteristics
        var effectiveSpeed = route.baseSpeed * route.shipEfficiency
        
        // Apply weather effects
        effectiveSpeed *= weatherEffect.speedModifier
        
        // Apply fuel consumption
        let fuelConsumptionRate = calculateFuelConsumption(
            speed: effectiveSpeed,
            weather: weatherEffect,
            shipSize: route.shipSize
        )
        route.currentFuel -= Float(fuelConsumptionRate * deltaTime)
        
        // Adjust speed if low on fuel
        if route.currentFuel < route.maxFuel * 0.1 {
            effectiveSpeed *= 0.5 // Emergency speed
        }
        
        // Calculate movement vector
        let direction = route.currentDirection
        let velocityFromSpeed = direction * Float(effectiveSpeed * deltaTime)
        let velocityFromCurrent = currentEffect * Float(deltaTime * 0.1) // Ocean current effect
        
        let totalVelocity = velocityFromSpeed + velocityFromCurrent
        
        // Update position
        route.currentPosition += SIMD3<Float>(totalVelocity.x, totalVelocity.y, 0)
        
        // Update ship state
        route.weatherStress += weatherEffect.stressIncrease * Float(deltaTime)
        route.weatherStress = max(0, route.weatherStress - Float(deltaTime * 0.1)) // Natural stress recovery
    }
    
    private func updateRouteProgress(_ route: inout TradeRoute, deltaTime: TimeInterval) {
        guard route.currentWaypointIndex < route.waypoints.count else {
            route.status = .completed
            return
        }
        
        let targetWaypoint = route.waypoints[route.currentWaypointIndex]
        let targetPosition = targetWaypoint.position
        
        let distance = length(targetPosition - route.currentPosition)
        
        // Check if we've reached the waypoint
        if distance < 1.0 { // 1 unit tolerance
            route.currentWaypointIndex += 1
            
            if route.currentWaypointIndex >= route.waypoints.count {
                route.status = .completed
                route.completionTime = Date()
            } else {
                // Update direction to next waypoint
                updateDirection(&route)
            }
        } else {
            // Update direction toward current waypoint
            updateDirection(&route)
        }
        
        // Update estimated arrival time
        if route.status == .active {
            updateETA(&route)
        }
    }
    
    private func updateDirection(_ route: inout TradeRoute) {
        guard route.currentWaypointIndex < route.waypoints.count else { return }
        
        let targetPosition = route.waypoints[route.currentWaypointIndex].position
        let direction = targetPosition - route.currentPosition
        let distance = length(direction)
        
        if distance > 0 {
            route.currentDirection = SIMD2<Float>(direction.x, direction.y) / distance
        }
    }
    
    private func updateETA(_ route: inout TradeRoute) {
        var remainingDistance: Float = 0
        var currentPos = route.currentPosition
        
        // Calculate total remaining distance
        for i in route.currentWaypointIndex..<route.waypoints.count {
            let waypoint = route.waypoints[i]
            remainingDistance += length(waypoint.position - currentPos)
            currentPos = waypoint.position
        }
        
        // Estimate time based on current effective speed
        let averageSpeed = route.baseSpeed * route.shipEfficiency * 0.8 // Conservative estimate
        let estimatedHours = TimeInterval(remainingDistance / Float(averageSpeed))
        
        route.estimatedArrival = Date().addingTimeInterval(estimatedHours * 3600)
    }
    
    private func calculateWeatherEffect(at position: SIMD3<Float>) -> WeatherEffect {
        let weather = weatherConditions.getWeatherAt(position: SIMD2<Float>(position.x, position.y))
        
        var speedModifier: Double = 1.0
        var stressIncrease: Float = 0.0
        
        // Wind effects
        if weather.windSpeed > 15.0 {
            speedModifier *= 0.8 // Strong winds slow down ships
            stressIncrease += 0.1
        } else if weather.windSpeed > 5.0 {
            speedModifier *= 1.1 // Moderate winds can help
        }
        
        // Wave effects
        if weather.waveHeight > 3.0 {
            speedModifier *= 0.6
            stressIncrease += 0.2
        }
        
        // Visibility effects
        if weather.visibility < 0.5 {
            speedModifier *= 0.5 // Poor visibility forces slow navigation
            stressIncrease += 0.15
        }
        
        return WeatherEffect(speedModifier: speedModifier, stressIncrease: stressIncrease)
    }
    
    private func calculateOceanCurrentEffect(at position: SIMD3<Float>) -> SIMD2<Float> {
        let pos2D = SIMD2<Float>(position.x, position.y)
        var totalEffect = SIMD2<Float>(0, 0)
        
        for current in oceanCurrents {
            if current.region.contains(pos2D) {
                let distance = current.region.distanceFromCenter(pos2D)
                let falloff = max(0, 1.0 - distance / current.region.maxDistance())
                totalEffect += current.velocity * current.strength * falloff
            }
        }
        
        return totalEffect
    }
    
    private func calculateFuelConsumption(speed: Double, weather: WeatherEffect, shipSize: ShipSize) -> Double {
        let baseconsumption = speed * 0.1 // Base fuel consumption per speed unit
        let weatherMultiplier = 2.0 - weather.speedModifier // More fuel needed in bad weather
        let sizeMultiplier = shipSize.fuelMultiplier
        
        return baseconsumption * weatherMultiplier * sizeMultiplier
    }
    
    private func checkRouteHazards(_ route: inout TradeRoute) {
        // Check for piracy zones
        for hazard in PiracyZone.globalZones {
            if hazard.isPositionInZone(route.currentPosition) {
                route.risks.append(RouteRisk(type: .piracy, severity: hazard.threatLevel, position: route.currentPosition))
            }
        }
        
        // Check for storms
        let weather = weatherConditions.getWeatherAt(position: SIMD2<Float>(route.currentPosition.x, route.currentPosition.y))
        if weather.stormIntensity > 0.7 {
            route.risks.append(RouteRisk(type: .storm, severity: weather.stormIntensity, position: route.currentPosition))
        }
        
        // Check fuel levels
        if route.currentFuel < route.maxFuel * 0.2 {
            route.risks.append(RouteRisk(type: .fuel, severity: 1.0 - route.currentFuel / (route.maxFuel * 0.2), position: route.currentPosition))
        }
    }
    
    private func updateOceanCurrents(deltaTime: TimeInterval) {
        // Simulate seasonal variations in ocean currents
        let seasonalFactor = sin(Date().timeIntervalSince1970 / (365.25 * 24 * 3600) * 2 * .pi)
        
        for i in 0..<oceanCurrents.count {
            let basevelocity = oceanCurrents[i].velocity
            oceanCurrents[i].velocity = basevelocity * (1.0 + Float(seasonalFactor) * 0.2)
        }
    }
    
    /// Create a new trade route
    public func createRoute(from origin: SIMD3<Float>, to destination: SIMD3<Float>, waypoints: [RouteWaypoint] = []) -> TradeRoute {
        var route = TradeRoute(
            origin: origin,
            destination: destination,
            waypoints: waypoints.isEmpty ? generateWaypoints(from: origin, to: destination) : waypoints
        )
        
        updateDirection(&route)
        route.status = .active
        activeRoutes.append(route)
        
        return route
    }
    
    private func generateWaypoints(from origin: SIMD3<Float>, to destination: SIMD3<Float>) -> [RouteWaypoint] {
        // Simple great circle route with intermediate waypoints
        let direction = destination - origin
        let distance = length(direction)
        let segments = max(2, Int(distance / 100.0)) // One waypoint per 100 units
        
        var waypoints: [RouteWaypoint] = []
        
        for i in 1...segments {
            let progress = Float(i) / Float(segments)
            let position = origin + direction * progress
            
            waypoints.append(RouteWaypoint(
                position: position,
                waypointType: i == segments ? .destination : .intermediate,
                estimatedArrival: Date().addingTimeInterval(TimeInterval(progress * distance / 20.0 * 3600)) // Assume 20 units/hour
            ))
        }
        
        return waypoints
    }
}

/// Weather system for environmental effects
public class WeatherSystem: ObservableObject {
    @Published public var globalWeather: [WeatherCell] = []
    
    private let gridSize = 50
    private var timeAccumulator: Double = 0
    
    public init() {
        generateGlobalWeather()
    }
    
    private func generateGlobalWeather() {
        globalWeather.removeAll()
        
        for x in 0..<gridSize {
            for y in 0..<gridSize {
                let lat = (Float(y) / Float(gridSize) - 0.5) * 180.0
                let lon = (Float(x) / Float(gridSize) - 0.5) * 360.0
                
                let cell = WeatherCell(
                    position: SIMD2<Float>(lon, lat),
                    windSpeed: Float.random(in: 0...25),
                    windDirection: Float.random(in: 0...360),
                    waveHeight: Float.random(in: 0...8),
                    visibility: Float.random(in: 0.1...1.0),
                    stormIntensity: Float.random(in: 0...1)
                )
                
                globalWeather.append(cell)
            }
        }
    }
    
    public func update(deltaTime: TimeInterval) {
        timeAccumulator += deltaTime
        
        // Update weather every 10 seconds
        if timeAccumulator > 10.0 {
            updateWeatherPatterns()
            timeAccumulator = 0
        }
    }
    
    private func updateWeatherPatterns() {
        for i in 0..<globalWeather.count {
            var cell = globalWeather[i]
            
            // Simulate weather evolution
            cell.windSpeed += Float.random(in: -2...2)
            cell.windSpeed = max(0, min(30, cell.windSpeed))
            
            cell.waveHeight += Float.random(in: -1...1)
            cell.waveHeight = max(0, min(10, cell.waveHeight))
            
            cell.visibility += Float.random(in: -0.1...0.1)
            cell.visibility = max(0.1, min(1.0, cell.visibility))
            
            globalWeather[i] = cell
        }
    }
    
    public func getWeatherAt(position: SIMD2<Float>) -> WeatherCell {
        // Find nearest weather cell
        var nearestCell = globalWeather[0]
        var minDistance = Float.greatestFiniteMagnitude
        
        for cell in globalWeather {
            let distance = length(cell.position - position)
            if distance < minDistance {
                minDistance = distance
                nearestCell = cell
            }
        }
        
        return nearestCell
    }
}

/// Data structures for physics system
public struct TradeRoute: Identifiable {
    public let id = UUID()
    public var origin: SIMD3<Float>
    public var destination: SIMD3<Float>
    public var waypoints: [RouteWaypoint]
    public var currentPosition: SIMD3<Float>
    public var currentDirection: SIMD2<Float> = SIMD2<Float>(1, 0)
    public var currentWaypointIndex: Int = 0
    public var status: RouteStatus = .planning
    public var baseSpeed: Double = 20.0 // knots
    public var shipEfficiency: Double = 1.0
    public var shipSize: ShipSize = .medium
    public var currentFuel: Float = 1000.0
    public var maxFuel: Float = 1000.0
    public var weatherStress: Float = 0.0
    public var estimatedArrival: Date?
    public var completionTime: Date?
    public var risks: [RouteRisk] = []
    
    public init(origin: SIMD3<Float>, destination: SIMD3<Float>, waypoints: [RouteWaypoint]) {
        self.origin = origin
        self.destination = destination
        self.waypoints = waypoints
        self.currentPosition = origin
    }
}

public struct RouteWaypoint {
    public var position: SIMD3<Float>
    public var waypointType: WaypointType
    public var estimatedArrival: Date
    
    public enum WaypointType {
        case origin
        case intermediate
        case fuelStop
        case destination
    }
}

public enum RouteStatus {
    case planning
    case active
    case delayed
    case emergency
    case completed
    case cancelled
}

public enum ShipSize {
    case small
    case medium
    case large
    case ultraLarge
    
    var fuelMultiplier: Double {
        switch self {
        case .small: return 0.5
        case .medium: return 1.0
        case .large: return 1.8
        case .ultraLarge: return 3.0
        }
    }
}

public struct RouteRisk {
    public var type: RiskType
    public var severity: Float
    public var position: SIMD3<Float>
    public var timestamp = Date()
    
    public enum RiskType {
        case storm
        case piracy
        case fuel
        case mechanical
        case political
    }
}

public struct WeatherCell {
    public var position: SIMD2<Float>
    public var windSpeed: Float
    public var windDirection: Float
    public var waveHeight: Float
    public var visibility: Float
    public var stormIntensity: Float
}

public struct WeatherEffect {
    public var speedModifier: Double
    public var stressIncrease: Float
}

public struct OceanCurrent {
    public var name: String
    public var region: GeographicRegion
    public var velocity: SIMD2<Float>
    public var temperature: Double
    public var strength: Float
}

public struct GeographicRegion {
    public var minLat: Double
    public var maxLat: Double
    public var minLon: Double
    public var maxLon: Double
    
    public func contains(_ position: SIMD2<Float>) -> Bool {
        let lon = Double(position.x)
        let lat = Double(position.y)
        return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat
    }
    
    public func distanceFromCenter(_ position: SIMD2<Float>) -> Float {
        let centerLon = (minLon + maxLon) / 2
        let centerLat = (minLat + maxLat) / 2
        let center = SIMD2<Float>(Float(centerLon), Float(centerLat))
        return length(position - center)
    }
    
    public func maxDistance() -> Float {
        let width = Float(maxLon - minLon)
        let height = Float(maxLat - minLat)
        return sqrt(width * width + height * height) / 2
    }
}

public struct PiracyZone {
    public var region: GeographicRegion
    public var threatLevel: Float
    public var name: String
    
    public func isPositionInZone(_ position: SIMD3<Float>) -> Bool {
        return region.contains(SIMD2<Float>(position.x, position.y))
    }
    
    public static let globalZones = [
        PiracyZone(
            region: GeographicRegion(minLat: 10, maxLat: 20, minLon: 40, maxLon: 70),
            threatLevel: 0.8,
            name: "Gulf of Aden"
        ),
        PiracyZone(
            region: GeographicRegion(minLat: -10, maxLat: 10, minLon: -10, maxLon: 20),
            threatLevel: 0.6,
            name: "Gulf of Guinea"
        )
    ]
}