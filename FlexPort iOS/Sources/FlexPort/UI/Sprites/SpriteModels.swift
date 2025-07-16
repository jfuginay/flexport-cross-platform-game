import Foundation
import simd
import Metal

// MARK: - Core Sprite Structures

/// Represents a single sprite in the game
struct Sprite {
    let id: UUID
    var texture: MTLTexture?
    var position: SIMD2<Float>
    var size: SIMD2<Float>
    var rotation: Float
    var scale: Float
    var tintColor: SIMD4<Float>
    var alpha: Float
    var anchor: SIMD2<Float> // Anchor point (0,0 = top-left, 0.5,0.5 = center)
    var zOrder: Int
    var isVisible: Bool
    
    init(id: UUID = UUID(),
         position: SIMD2<Float> = .zero,
         size: SIMD2<Float> = SIMD2<Float>(64, 64),
         rotation: Float = 0,
         scale: Float = 1.0,
         tintColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1),
         alpha: Float = 1.0,
         anchor: SIMD2<Float> = SIMD2<Float>(0.5, 0.5),
         zOrder: Int = 0,
         isVisible: Bool = true) {
        self.id = id
        self.position = position
        self.size = size
        self.rotation = rotation
        self.scale = scale
        self.tintColor = tintColor
        self.alpha = alpha
        self.anchor = anchor
        self.zOrder = zOrder
        self.isVisible = isVisible
    }
}

// MARK: - Ship Sprite Types

enum ShipSpriteType: String, CaseIterable {
    // Container Ships
    case containerSmall = "container_small"
    case containerMedium = "container_medium"
    case containerLarge = "container_large"
    case containerMega = "container_mega"
    case containerFeeder = "container_feeder"
    
    // Tanker Ships
    case tankerCrude = "tanker_crude"
    case tankerProduct = "tanker_product"
    case tankerChemical = "tanker_chemical"
    case tankerLNG = "tanker_lng"
    case tankerLPG = "tanker_lpg"
    
    // Bulk Carriers
    case bulkHandysize = "bulk_handysize"
    case bulkHandymax = "bulk_handymax"
    case bulkPanamax = "bulk_panamax"
    case bulkCapesize = "bulk_capesize"
    case bulkVLOC = "bulk_vloc"
    
    // Specialized Ships
    case carCarrier = "car_carrier"
    case reefer = "reefer"
    case generalCargo = "general_cargo"
    case heavyLift = "heavy_lift"
    case livestock = "livestock"
    
    // Military/Security
    case coastGuard = "coast_guard"
    case naval = "naval"
    case pirate = "pirate"
    
    // Service Vessels
    case tugboat = "tugboat"
    case pilot = "pilot"
    case bunker = "bunker"
    case dredger = "dredger"
    
    // Passenger
    case ferry = "ferry"
    case cruiseSmall = "cruise_small"
    case cruiseLarge = "cruise_large"
    case yacht = "yacht"
    
    // Future Tech
    case autonomous = "autonomous"
    case hydrofoil = "hydrofoil"
    case ekranoplan = "ekranoplan"
    case submarineFreight = "submarine_freight"
    
    // Special
    case aiControlled = "ai_controlled"
    case quantum = "quantum"
    case singularity = "singularity"
    
    var baseSize: SIMD2<Float> {
        switch self {
        case .containerMega, .tankerCrude, .bulkCapesize, .bulkVLOC:
            return SIMD2<Float>(120, 40)
        case .containerLarge, .tankerLNG, .cruiseLarge:
            return SIMD2<Float>(100, 35)
        case .containerMedium, .tankerProduct, .bulkPanamax:
            return SIMD2<Float>(80, 30)
        case .containerSmall, .tankerChemical, .bulkHandymax:
            return SIMD2<Float>(60, 25)
        case .tugboat, .pilot, .bunker:
            return SIMD2<Float>(30, 15)
        case .yacht:
            return SIMD2<Float>(40, 12)
        case .quantum, .singularity:
            return SIMD2<Float>(150, 50)
        default:
            return SIMD2<Float>(70, 28)
        }
    }
    
    var maxSpeed: Float {
        switch self {
        case .containerMega, .containerLarge:
            return 25.0
        case .tankerCrude, .bulkVLOC:
            return 15.0
        case .ferry, .cruiseSmall:
            return 28.0
        case .tugboat:
            return 12.0
        case .hydrofoil:
            return 45.0
        case .quantum:
            return 100.0
        case .singularity:
            return 200.0
        default:
            return 20.0
        }
    }
}

// MARK: - Ship Sprite Data

struct ShipSprite {
    let id: UUID
    var sprite: Sprite
    var type: ShipSpriteType
    var heading: Float // Direction in radians
    var speed: Float
    var targetPosition: SIMD2<Float>?
    var trail: ShipTrail
    var damageLevel: Float // 0.0 = pristine, 1.0 = sinking
    var cargo: CargoVisual?
    var effects: [ShipEffect]
    
    // Animation states
    var engineAnimation: Float
    var waveOffset: Float
    var bobAmount: Float
    
    init(type: ShipSpriteType, position: SIMD2<Float>) {
        self.id = UUID()
        self.sprite = Sprite(position: position, size: type.baseSize)
        self.type = type
        self.heading = 0
        self.speed = 0
        self.trail = ShipTrail()
        self.damageLevel = 0
        self.engineAnimation = 0
        self.waveOffset = Float.random(in: 0...Float.pi * 2)
        self.bobAmount = Float.random(in: 0.8...1.2)
        self.effects = []
    }
}

// MARK: - Port Infrastructure Sprites

enum PortSpriteType: String, CaseIterable {
    // Cranes
    case craneGantry = "crane_gantry"
    case craneMobile = "crane_mobile"
    case craneFloating = "crane_floating"
    case craneSTS = "crane_sts" // Ship-to-Shore
    case craneRTG = "crane_rtg" // Rubber Tired Gantry
    
    // Storage
    case warehouseSmall = "warehouse_small"
    case warehouseLarge = "warehouse_large"
    case warehouseCold = "warehouse_cold"
    case containerYard = "container_yard"
    case tankFarm = "tank_farm"
    case silos = "silos"
    
    // Docks
    case dockConcrete = "dock_concrete"
    case dockFloating = "dock_floating"
    case dockDrydock = "dock_drydock"
    case pierSmall = "pier_small"
    case pierLarge = "pier_large"
    
    // Support Buildings
    case officeBuilding = "office_building"
    case customsHouse = "customs_house"
    case pilotStation = "pilot_station"
    case bunkerStation = "bunker_station"
    case maintenanceShed = "maintenance_shed"
    
    // Transportation
    case railTerminal = "rail_terminal"
    case truckGate = "truck_gate"
    case conveyorBelt = "conveyor_belt"
    case pipeline = "pipeline"
    
    // Special
    case lighthouse = "lighthouse"
    case controlTower = "control_tower"
    case helipad = "helipad"
    case aiDataCenter = "ai_datacenter"
    case quantumTerminal = "quantum_terminal"
}

struct PortSprite {
    let id: UUID
    var sprite: Sprite
    var type: PortSpriteType
    var activityLevel: Float
    var animations: [PortAnimation]
    var connectedInfrastructure: Set<UUID>
}

// MARK: - Animation Structures

struct AnimationFrame {
    let texture: MTLTexture?
    let duration: Float
    let offset: SIMD2<Float>
}

struct Animation {
    let id: String
    var frames: [AnimationFrame]
    var currentFrame: Int
    var elapsedTime: Float
    var isLooping: Bool
    var playbackSpeed: Float
    
    mutating func update(deltaTime: Float) {
        guard !frames.isEmpty else { return }
        
        elapsedTime += deltaTime * playbackSpeed
        
        if elapsedTime >= frames[currentFrame].duration {
            elapsedTime = 0
            currentFrame += 1
            
            if currentFrame >= frames.count {
                if isLooping {
                    currentFrame = 0
                } else {
                    currentFrame = frames.count - 1
                }
            }
        }
    }
    
    var currentTexture: MTLTexture? {
        guard currentFrame < frames.count else { return nil }
        return frames[currentFrame].texture
    }
}

// MARK: - Effects

enum ShipEffect {
    case wake(intensity: Float)
    case smoke(density: Float, color: SIMD3<Float>)
    case fire(intensity: Float)
    case electricalSparks
    case quantumGlow
    case aiProcessing
    case damage(severity: Float)
}

struct ShipTrail {
    var points: [TrailPoint]
    let maxPoints: Int
    var width: Float
    var fadeTime: Float
    
    init(maxPoints: Int = 50, width: Float = 10, fadeTime: Float = 5.0) {
        self.points = []
        self.maxPoints = maxPoints
        self.width = width
        self.fadeTime = fadeTime
    }
    
    mutating func addPoint(_ position: SIMD2<Float>) {
        points.append(TrailPoint(position: position, timestamp: CACurrentMediaTime()))
        if points.count > maxPoints {
            points.removeFirst()
        }
    }
    
    mutating func update() {
        let currentTime = CACurrentMediaTime()
        points.removeAll { point in
            currentTime - point.timestamp > fadeTime
        }
    }
}

struct TrailPoint {
    let position: SIMD2<Float>
    let timestamp: CFTimeInterval
    
    func alpha(currentTime: CFTimeInterval, fadeTime: Float) -> Float {
        let age = Float(currentTime - timestamp)
        return max(0, 1.0 - (age / fadeTime))
    }
}

// MARK: - Port Animations

enum PortAnimation {
    case craneLoading(progress: Float)
    case craneUnloading(progress: Float)
    case vehicleMovement(path: [SIMD2<Float>], progress: Float)
    case conveyorBelt(speed: Float)
    case lighthouseRotation(speed: Float)
    case smokeStack(intensity: Float)
    case lights(pattern: LightPattern)
}

enum LightPattern {
    case steady
    case blinking(interval: Float)
    case rotating(speed: Float)
    case emergency
}

// MARK: - Cargo Visualization

struct CargoVisual {
    enum CargoType {
        case containers(count: Int, teu: Int)
        case bulk(type: String, fillLevel: Float)
        case liquid(type: String, tankLevel: Float)
        case vehicles(count: Int)
        case special(description: String)
    }
    
    let type: CargoType
    var visualRepresentation: [Sprite]
}

// MARK: - Network Interpolation

struct InterpolationState {
    var currentPosition: SIMD2<Float>
    var targetPosition: SIMD2<Float>
    var currentRotation: Float
    var targetRotation: Float
    var interpolationTime: Float
    var totalTime: Float
    
    mutating func update(deltaTime: Float) {
        guard totalTime > 0 else { return }
        
        interpolationTime = min(interpolationTime + deltaTime, totalTime)
        let t = interpolationTime / totalTime
        
        // Smooth interpolation using ease-in-out curve
        let smoothT = t * t * (3.0 - 2.0 * t)
        
        currentPosition = mix(currentPosition, targetPosition, t: smoothT)
        
        // Interpolate rotation using shortest path
        var rotDiff = targetRotation - currentRotation
        if rotDiff > Float.pi {
            rotDiff -= 2 * Float.pi
        } else if rotDiff < -Float.pi {
            rotDiff += 2 * Float.pi
        }
        currentRotation += rotDiff * smoothT
    }
    
    var isComplete: Bool {
        interpolationTime >= totalTime
    }
}

// MARK: - Sprite Batch Renderer

struct SpriteBatch {
    var sprites: [Sprite]
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    let maxSprites: Int
    
    init(maxSprites: Int = 1000) {
        self.sprites = []
        self.maxSprites = maxSprites
    }
    
    mutating func add(_ sprite: Sprite) {
        guard sprites.count < maxSprites else { return }
        sprites.append(sprite)
    }
    
    mutating func clear() {
        sprites.removeAll()
    }
    
    func sortedSprites() -> [Sprite] {
        sprites.sorted { $0.zOrder < $1.zOrder }
    }
}

// MARK: - Damage States

enum DamageState: Float {
    case pristine = 0.0
    case light = 0.25
    case moderate = 0.5
    case heavy = 0.75
    case critical = 0.9
    case sinking = 1.0
    
    var smokeIntensity: Float {
        max(0, rawValue - 0.25)
    }
    
    var fireChance: Float {
        max(0, rawValue - 0.5) * 2
    }
    
    var listAngle: Float {
        rawValue * 0.3 // Up to 30 degrees list when sinking
    }
    
    var speedReduction: Float {
        1.0 - (rawValue * 0.7) // Up to 70% speed reduction
    }
}