import Foundation
import Metal
import simd

/// Advanced particle system for ship wakes, smoke, and other effects
class ParticleSystem {
    
    // MARK: - Particle Types
    
    enum ParticleType {
        case wake
        case foam
        case smoke
        case fire
        case steam
        case splash
        case bubble
        case spark
        case debris
        case rain
        case snow
    }
    
    // MARK: - Particle Structure
    
    struct Particle {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var acceleration: SIMD2<Float>
        var color: SIMD4<Float>
        var size: Float
        var rotation: Float
        var rotationSpeed: Float
        var lifetime: Float
        var age: Float
        var type: ParticleType
        
        var isAlive: Bool {
            age < lifetime
        }
        
        var normalizedAge: Float {
            age / lifetime
        }
    }
    
    // MARK: - Emitter Configuration
    
    struct EmitterConfig {
        var position: SIMD2<Float>
        var direction: SIMD2<Float>
        var spread: Float // Angle spread in radians
        var particlesPerSecond: Float
        var particleLifetime: Float
        var startSize: Float
        var endSize: Float
        var startColor: SIMD4<Float>
        var endColor: SIMD4<Float>
        var startSpeed: Float
        var endSpeed: Float
        var gravity: SIMD2<Float>
        var texture: MTLTexture?
    }
    
    // MARK: - Wake Trail System
    
    class WakeTrail {
        var emitters: [WakeEmitter] = []
        let ship: ShipSprite
        private var lastEmitPosition: SIMD2<Float>
        private let emitDistance: Float = 5.0
        
        init(ship: ShipSprite) {
            self.ship = ship
            self.lastEmitPosition = ship.sprite.position
        }
        
        func update(deltaTime: Float, particleSystem: ParticleSystem) {
            let currentPos = ship.sprite.position
            let distance = simd_distance(currentPos, lastEmitPosition)
            
            // Emit new wake points based on distance traveled
            if distance >= emitDistance && ship.speed > 0 {
                createWakeEmitters(at: currentPos, particleSystem: particleSystem)
                lastEmitPosition = currentPos
            }
            
            // Update existing emitters
            emitters.removeAll { emitter in
                emitter.update(deltaTime: deltaTime)
                return !emitter.isActive
            }
        }
        
        private func createWakeEmitters(at position: SIMD2<Float>, particleSystem: ParticleSystem) {
            // Calculate wake positions based on ship size and direction
            let shipDirection = SIMD2<Float>(cos(ship.heading), sin(ship.heading))
            let perpendicular = SIMD2<Float>(-shipDirection.y, shipDirection.x)
            
            // Stern position
            let sternOffset = -shipDirection * (ship.sprite.size.x * 0.5)
            let sternPos = position + sternOffset
            
            // Create V-shaped wake
            let wakeWidth = ship.sprite.size.y * 0.8
            let leftWakePos = sternPos - perpendicular * (wakeWidth * 0.5)
            let rightWakePos = sternPos + perpendicular * (wakeWidth * 0.5)
            
            // Left wake emitter
            let leftEmitter = WakeEmitter(
                position: leftWakePos,
                direction: -shipDirection + perpendicular * 0.3,
                intensity: ship.speed / ship.type.maxSpeed,
                size: ship.sprite.size.y * 0.5
            )
            emitters.append(leftEmitter)
            
            // Right wake emitter
            let rightEmitter = WakeEmitter(
                position: rightWakePos,
                direction: -shipDirection - perpendicular * 0.3,
                intensity: ship.speed / ship.type.maxSpeed,
                size: ship.sprite.size.y * 0.5
            )
            emitters.append(rightEmitter)
            
            // Emit particles
            leftEmitter.emit(particleSystem: particleSystem)
            rightEmitter.emit(particleSystem: particleSystem)
        }
    }
    
    class WakeEmitter {
        var position: SIMD2<Float>
        var direction: SIMD2<Float>
        var intensity: Float
        var size: Float
        var lifetime: Float
        
        var isActive: Bool {
            lifetime > 0
        }
        
        init(position: SIMD2<Float>, direction: SIMD2<Float>, intensity: Float, size: Float) {
            self.position = position
            self.direction = normalize(direction)
            self.intensity = intensity
            self.size = size
            self.lifetime = 5.0 // Wake persists for 5 seconds
        }
        
        func update(deltaTime: Float) {
            lifetime -= deltaTime
            intensity *= 0.98 // Gradual fade
        }
        
        func emit(particleSystem: ParticleSystem) {
            let particleCount = Int(intensity * 20)
            
            for _ in 0..<particleCount {
                // Create foam particles
                let spread = Float.random(in: -0.5...0.5)
                let particleDir = direction + SIMD2<Float>(
                    direction.y * spread,
                    -direction.x * spread
                )
                
                let particle = Particle(
                    position: position + SIMD2<Float>.random(in: -size...size),
                    velocity: particleDir * Float.random(in: 5...15) * intensity,
                    acceleration: SIMD2<Float>(0, 0),
                    color: SIMD4<Float>(0.9, 0.95, 1.0, intensity),
                    size: Float.random(in: 2...5) * intensity,
                    rotation: Float.random(in: 0...Float.pi * 2),
                    rotationSpeed: Float.random(in: -1...1),
                    lifetime: Float.random(in: 2...4),
                    age: 0,
                    type: .foam
                )
                
                particleSystem.addParticle(particle)
            }
            
            // Create larger wake particles
            for _ in 0..<5 {
                let wakeParticle = Particle(
                    position: position,
                    velocity: direction * 2 * intensity,
                    acceleration: SIMD2<Float>(0, 0),
                    color: SIMD4<Float>(0.8, 0.9, 1.0, intensity * 0.5),
                    size: size * Float.random(in: 0.8...1.2),
                    rotation: 0,
                    rotationSpeed: 0,
                    lifetime: 3.0,
                    age: 0,
                    type: .wake
                )
                
                particleSystem.addParticle(wakeParticle)
            }
        }
    }
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let maxParticles: Int
    private var particles: [Particle] = []
    private var particleBuffer: MTLBuffer?
    private var activeEmitters: [UUID: EmitterConfig] = [:]
    
    // Particle accumulator for batch emission
    private var emitterAccumulators: [UUID: Float] = [:]
    
    // Wake trails for ships
    private var wakeTrails: [UUID: WakeTrail] = [:]
    
    init(device: MTLDevice, maxParticles: Int = 10000) {
        self.device = device
        self.maxParticles = maxParticles
        self.particles.reserveCapacity(maxParticles)
        
        // Create particle buffer
        particleBuffer = device.makeBuffer(
            length: maxParticles * MemoryLayout<ParticleGPUData>.stride,
            options: []
        )
    }
    
    // MARK: - Particle Management
    
    func addParticle(_ particle: Particle) {
        guard particles.count < maxParticles else { return }
        particles.append(particle)
    }
    
    func createEmitter(config: EmitterConfig) -> UUID {
        let id = UUID()
        activeEmitters[id] = config
        emitterAccumulators[id] = 0
        return id
    }
    
    func updateEmitter(id: UUID, config: EmitterConfig) {
        activeEmitters[id] = config
    }
    
    func removeEmitter(id: UUID) {
        activeEmitters.removeValue(forKey: id)
        emitterAccumulators.removeValue(forKey: id)
    }
    
    // MARK: - Wake Trail Management
    
    func createWakeTrail(for ship: ShipSprite) {
        wakeTrails[ship.id] = WakeTrail(ship: ship)
    }
    
    func removeWakeTrail(for shipID: UUID) {
        wakeTrails.removeValue(forKey: shipID)
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        // Update existing particles
        particles = particles.compactMap { particle in
            var p = particle
            
            // Update physics
            p.velocity += p.acceleration * deltaTime
            p.position += p.velocity * deltaTime
            p.rotation += p.rotationSpeed * deltaTime
            p.age += deltaTime
            
            // Apply particle type specific behavior
            updateParticleBehavior(&p, deltaTime: deltaTime)
            
            return p.isAlive ? p : nil
        }
        
        // Emit new particles from active emitters
        for (id, config) in activeEmitters {
            emitParticles(emitterID: id, config: config, deltaTime: deltaTime)
        }
        
        // Update wake trails
        for (_, trail) in wakeTrails {
            trail.update(deltaTime: deltaTime, particleSystem: self)
        }
        
        // Update GPU buffer
        updateGPUBuffer()
    }
    
    private func updateParticleBehavior(_ particle: inout Particle, deltaTime: Float) {
        switch particle.type {
        case .wake:
            // Wake particles spread out and fade
            particle.velocity *= 0.98
            particle.size *= 1.02
            particle.color.w = 1.0 - particle.normalizedAge
            
        case .foam:
            // Foam particles float and dissipate
            particle.velocity.y += 2.0 * deltaTime // Slight upward drift
            particle.velocity *= 0.95
            particle.size = mix(particle.size, particle.size * 0.5, t: particle.normalizedAge)
            particle.color.w = 1.0 - pow(particle.normalizedAge, 0.5)
            
        case .smoke:
            // Smoke rises and expands
            particle.velocity.y += 10.0 * deltaTime
            particle.velocity.x += sin(particle.age * 5) * 2 * deltaTime
            particle.size *= 1.01
            particle.color.w = 1.0 - pow(particle.normalizedAge, 2)
            
        case .fire:
            // Fire particles rise quickly and shrink
            particle.velocity.y += 30.0 * deltaTime
            particle.size = mix(particle.size, 0, t: particle.normalizedAge)
            // Color shifts from yellow to red
            particle.color.y = 1.0 - particle.normalizedAge * 0.5
            particle.color.w = 1.0 - pow(particle.normalizedAge, 0.7)
            
        case .splash:
            // Splash particles fall with gravity
            particle.velocity.y -= 20.0 * deltaTime
            particle.color.w = 1.0 - particle.normalizedAge
            
        case .bubble:
            // Bubbles rise and wobble
            particle.velocity.y += 15.0 * deltaTime
            particle.position.x += sin(particle.age * 10) * deltaTime
            particle.color.w = 1.0 - pow(particle.normalizedAge, 3)
            
        case .spark:
            // Sparks fall with gravity and fade quickly
            particle.velocity.y -= 50.0 * deltaTime
            particle.size *= 0.95
            particle.color.w = 1.0 - pow(particle.normalizedAge, 0.3)
            
        case .debris:
            // Debris falls and tumbles
            particle.velocity.y -= 30.0 * deltaTime
            particle.rotationSpeed *= 1.01
            
        case .steam:
            // Steam rises and disperses
            particle.velocity.y += 5.0 * deltaTime
            particle.size *= 1.03
            particle.color.w = 1.0 - particle.normalizedAge
            
        case .rain:
            // Rain falls straight down
            particle.velocity.y = -100.0
            
        case .snow:
            // Snow drifts gently
            particle.velocity.y = -10.0
            particle.position.x += sin(particle.age * 2) * 5 * deltaTime
        }
    }
    
    private func emitParticles(emitterID: UUID, config: EmitterConfig, deltaTime: Float) {
        // Accumulate emission time
        emitterAccumulators[emitterID]? += config.particlesPerSecond * deltaTime
        
        // Emit whole particles
        while let accumulated = emitterAccumulators[emitterID], accumulated >= 1.0 {
            emitterAccumulators[emitterID]? -= 1.0
            
            // Calculate emission parameters
            let angleVariation = Float.random(in: -config.spread...config.spread)
            let speed = Float.random(in: config.startSpeed...config.endSpeed)
            
            let emissionAngle = atan2(config.direction.y, config.direction.x) + angleVariation
            let velocity = SIMD2<Float>(cos(emissionAngle), sin(emissionAngle)) * speed
            
            let particle = Particle(
                position: config.position,
                velocity: velocity,
                acceleration: config.gravity,
                color: config.startColor,
                size: config.startSize,
                rotation: Float.random(in: 0...Float.pi * 2),
                rotationSpeed: Float.random(in: -2...2),
                lifetime: config.particleLifetime,
                age: 0,
                type: .wake // Default, should be configurable
            )
            
            addParticle(particle)
        }
    }
    
    // MARK: - Special Effects
    
    func createExplosion(at position: SIMD2<Float>, intensity: Float) {
        let particleCount = Int(intensity * 100)
        
        // Fire particles
        for _ in 0..<particleCount / 2 {
            let angle = Float.random(in: 0...Float.pi * 2)
            let speed = Float.random(in: 20...50) * intensity
            let velocity = SIMD2<Float>(cos(angle), sin(angle)) * speed
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                acceleration: SIMD2<Float>(0, -10),
                color: SIMD4<Float>(1.0, Float.random(in: 0.5...1.0), 0, 1.0),
                size: Float.random(in: 5...15) * intensity,
                rotation: 0,
                rotationSpeed: Float.random(in: -5...5),
                lifetime: Float.random(in: 0.5...1.5),
                age: 0,
                type: .fire
            )
            addParticle(particle)
        }
        
        // Smoke particles
        for _ in 0..<particleCount / 2 {
            let angle = Float.random(in: 0...Float.pi * 2)
            let speed = Float.random(in: 10...30) * intensity
            let velocity = SIMD2<Float>(cos(angle), sin(angle)) * speed
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                acceleration: SIMD2<Float>(0, 5),
                color: SIMD4<Float>(0.3, 0.3, 0.3, 0.8),
                size: Float.random(in: 10...20) * intensity,
                rotation: 0,
                rotationSpeed: Float.random(in: -1...1),
                lifetime: Float.random(in: 2...4),
                age: 0,
                type: .smoke
            )
            addParticle(particle)
        }
        
        // Sparks
        for _ in 0..<particleCount / 4 {
            let angle = Float.random(in: 0...Float.pi * 2)
            let speed = Float.random(in: 50...100) * intensity
            let velocity = SIMD2<Float>(cos(angle), sin(angle)) * speed
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                acceleration: SIMD2<Float>(0, -50),
                color: SIMD4<Float>(1.0, 1.0, 0.5, 1.0),
                size: Float.random(in: 1...3),
                rotation: 0,
                rotationSpeed: 0,
                lifetime: Float.random(in: 0.3...0.7),
                age: 0,
                type: .spark
            )
            addParticle(particle)
        }
    }
    
    func createSplash(at position: SIMD2<Float>, size: Float) {
        let particleCount = Int(size * 20)
        
        for _ in 0..<particleCount {
            let angle = Float.random(in: 0...Float.pi * 2)
            let speed = Float.random(in: 10...30)
            let velocity = SIMD2<Float>(cos(angle), sin(angle)) * speed
            velocity.y = abs(velocity.y) // Splash upward
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                acceleration: SIMD2<Float>(0, -30),
                color: SIMD4<Float>(0.8, 0.9, 1.0, 0.8),
                size: Float.random(in: 2...5),
                rotation: 0,
                rotationSpeed: 0,
                lifetime: Float.random(in: 0.5...1.0),
                age: 0,
                type: .splash
            )
            addParticle(particle)
        }
        
        // Add some foam
        for _ in 0..<particleCount / 2 {
            let offset = SIMD2<Float>.random(in: -size...size)
            
            let particle = Particle(
                position: position + offset,
                velocity: SIMD2<Float>(0, Float.random(in: 1...5)),
                acceleration: SIMD2<Float>(0, 0),
                color: SIMD4<Float>(0.95, 0.95, 1.0, 0.7),
                size: Float.random(in: 3...8),
                rotation: 0,
                rotationSpeed: Float.random(in: -0.5...0.5),
                lifetime: Float.random(in: 2...4),
                age: 0,
                type: .foam
            )
            addParticle(particle)
        }
    }
    
    // MARK: - GPU Buffer Update
    
    struct ParticleGPUData {
        var position: SIMD2<Float>
        var size: Float
        var rotation: Float
        var color: SIMD4<Float>
        var textureIndex: Int32
        var padding: SIMD3<Float> // Alignment padding
    }
    
    private func updateGPUBuffer() {
        guard let buffer = particleBuffer,
              !particles.isEmpty else { return }
        
        let pointer = buffer.contents().bindMemory(
            to: ParticleGPUData.self,
            capacity: particles.count
        )
        
        for (index, particle) in particles.enumerated() {
            // Interpolate size and color based on age
            let t = particle.normalizedAge
            let size = particle.size // Can be modified based on type
            
            let gpuData = ParticleGPUData(
                position: particle.position,
                size: size,
                rotation: particle.rotation,
                color: particle.color,
                textureIndex: textureIndex(for: particle.type),
                padding: SIMD3<Float>(0, 0, 0)
            )
            
            pointer[index] = gpuData
        }
    }
    
    private func textureIndex(for type: ParticleType) -> Int32 {
        switch type {
        case .wake: return 0
        case .foam: return 1
        case .smoke: return 2
        case .fire: return 3
        case .steam: return 4
        case .splash: return 5
        case .bubble: return 6
        case .spark: return 7
        case .debris: return 8
        case .rain: return 9
        case .snow: return 10
        }
    }
    
    // MARK: - Getters
    
    func getParticleBuffer() -> MTLBuffer? {
        return particleBuffer
    }
    
    func getParticleCount() -> Int {
        return particles.count
    }
    
    var debugInfo: String {
        """
        Active Particles: \(particles.count)/\(maxParticles)
        Active Emitters: \(activeEmitters.count)
        Wake Trails: \(wakeTrails.count)
        """
    }
}

// MARK: - Helper Extensions

extension SIMD2 where Scalar == Float {
    static func random(in range: ClosedRange<Float>) -> SIMD2<Float> {
        return SIMD2<Float>(
            Float.random(in: range),
            Float.random(in: range)
        )
    }
}