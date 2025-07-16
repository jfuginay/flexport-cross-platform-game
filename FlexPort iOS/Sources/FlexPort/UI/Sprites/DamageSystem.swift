import Foundation
import Metal
import simd

/// Manages ship damage states, visual effects, and sinking animations
class DamageSystem {
    
    // MARK: - Damage Events
    
    enum DamageType {
        case collision(impactForce: Float)
        case fire
        case explosion
        case flooding
        case structuralFailure
        case piracyAttack
        case stormDamage
        case groundingDamage
    }
    
    // MARK: - Damage State
    
    struct ShipDamageState {
        var structuralIntegrity: Float = 1.0 // 1.0 = pristine, 0.0 = destroyed
        var fireLevel: Float = 0.0           // 0.0 = no fire, 1.0 = fully ablaze
        var floodingLevel: Float = 0.0       // 0.0 = no flooding, 1.0 = fully flooded
        var listAngle: Float = 0.0           // Ship tilt in radians
        var trimAngle: Float = 0.0           // Forward/backward tilt
        var smokeDensity: Float = 0.0        // Smoke particle emission rate
        var debrisEmitted: Bool = false      // Whether debris has been spawned
        var alarmActive: Bool = false        // Emergency alarm state
        var evacuationProgress: Float = 0.0   // Crew evacuation progress
        
        var isDamaged: Bool {
            structuralIntegrity < 0.95 || fireLevel > 0 || floodingLevel > 0
        }
        
        var isCritical: Bool {
            structuralIntegrity < 0.3 || fireLevel > 0.7 || floodingLevel > 0.7
        }
        
        var isSinking: Bool {
            structuralIntegrity < 0.1 || floodingLevel > 0.9
        }
        
        var speedModifier: Float {
            structuralIntegrity * (1.0 - floodingLevel * 0.7) * (1.0 - fireLevel * 0.3)
        }
    }
    
    // MARK: - Visual Effects Configuration
    
    struct DamageVisualConfig {
        // Texture overlays for damage
        var scorchTexture: MTLTexture?
        var rustTexture: MTLTexture?
        var dentTexture: MTLTexture?
        var crackTexture: MTLTexture?
        
        // Particle effect intensities
        var smokeIntensity: Float = 0.0
        var fireIntensity: Float = 0.0
        var sparkIntensity: Float = 0.0
        var steamIntensity: Float = 0.0
        
        // Deformation parameters
        var hullDeformation: SIMD3<Float> = .zero
        var deckCollapse: Float = 0.0
        
        // Color modifications
        var tintColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
        var charLevel: Float = 0.0 // How burnt the ship looks
    }
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let particleSystem: ParticleSystem
    private var shipDamageStates: [UUID: ShipDamageState] = [:]
    private var damageVisuals: [UUID: DamageVisualConfig] = [:]
    private var damageTextures: [String: MTLTexture] = [:]
    
    // Sinking animation parameters
    private var sinkingShips: [UUID: SinkingAnimation] = [:]
    
    struct SinkingAnimation {
        let startTime: CFTimeInterval
        var elapsed: Float = 0
        let duration: Float
        var finalExplosion: Bool = false
        var debrisSpawned: Bool = false
        var lifeboatsLaunched: Bool = false
    }
    
    init(device: MTLDevice, particleSystem: ParticleSystem) {
        self.device = device
        self.particleSystem = particleSystem
        generateDamageTextures()
    }
    
    // MARK: - Damage Application
    
    func applyDamage(to shipID: UUID, type: DamageType) {
        var state = shipDamageStates[shipID] ?? ShipDamageState()
        
        switch type {
        case .collision(let impactForce):
            applyCollisionDamage(&state, force: impactForce)
            
        case .fire:
            applyFireDamage(&state)
            
        case .explosion:
            applyExplosionDamage(&state)
            
        case .flooding:
            applyFloodingDamage(&state)
            
        case .structuralFailure:
            state.structuralIntegrity *= 0.5
            
        case .piracyAttack:
            applyPiracyDamage(&state)
            
        case .stormDamage:
            applyStormDamage(&state)
            
        case .groundingDamage:
            applyGroundingDamage(&state)
        }
        
        // Update visual configuration based on damage
        updateVisualConfig(for: shipID, state: state)
        
        // Check if ship should start sinking
        if state.isSinking && sinkingShips[shipID] == nil {
            startSinkingAnimation(shipID: shipID)
        }
        
        shipDamageStates[shipID] = state
    }
    
    private func applyCollisionDamage(_ state: inout ShipDamageState, force: Float) {
        // Structural damage based on impact force
        state.structuralIntegrity -= force * 0.3
        state.structuralIntegrity = max(0, state.structuralIntegrity)
        
        // Chance of fire from collision
        if force > 0.5 && Float.random(in: 0...1) < force * 0.3 {
            state.fireLevel = min(1.0, state.fireLevel + 0.3)
        }
        
        // Hull breach causing flooding
        if force > 0.7 {
            state.floodingLevel = min(1.0, state.floodingLevel + force * 0.4)
        }
        
        // List from impact
        state.listAngle += Float.random(in: -0.1...0.1) * force
    }
    
    private func applyFireDamage(_ state: inout ShipDamageState) {
        state.fireLevel = min(1.0, state.fireLevel + 0.2)
        state.smokeDensity = state.fireLevel
        
        // Fire damages structure over time
        state.structuralIntegrity -= 0.05
    }
    
    private func applyExplosionDamage(_ state: inout ShipDamageState) {
        state.structuralIntegrity *= 0.3
        state.fireLevel = 1.0
        state.smokeDensity = 1.0
        state.listAngle += Float.random(in: -0.3...0.3)
        state.trimAngle += Float.random(in: -0.2...0.2)
        
        // Major hull breach
        state.floodingLevel = min(1.0, state.floodingLevel + 0.6)
    }
    
    private func applyFloodingDamage(_ state: inout ShipDamageState) {
        state.floodingLevel = min(1.0, state.floodingLevel + 0.1)
        
        // Flooding causes list and trim
        state.listAngle += Float.random(in: -0.05...0.05)
        state.trimAngle += Float.random(in: -0.03...0.03)
    }
    
    private func applyPiracyDamage(_ state: inout ShipDamageState) {
        // Light structural damage and possible fire
        state.structuralIntegrity -= 0.1
        if Float.random(in: 0...1) < 0.3 {
            state.fireLevel = min(1.0, state.fireLevel + 0.2)
        }
        state.alarmActive = true
    }
    
    private func applyStormDamage(_ state: inout ShipDamageState) {
        // Storm causes flooding and structural stress
        state.structuralIntegrity -= 0.15
        state.floodingLevel = min(1.0, state.floodingLevel + 0.2)
        state.listAngle += Float.random(in: -0.2...0.2)
    }
    
    private func applyGroundingDamage(_ state: inout ShipDamageState) {
        // Hull damage and flooding
        state.structuralIntegrity -= 0.25
        state.floodingLevel = min(1.0, state.floodingLevel + 0.4)
        state.trimAngle = 0.1 // Stuck bow-up
    }
    
    // MARK: - Visual Updates
    
    private func updateVisualConfig(for shipID: UUID, state: ShipDamageState) {
        var config = damageVisuals[shipID] ?? DamageVisualConfig()
        
        // Update particle effects
        config.smokeIntensity = state.smokeDensity
        config.fireIntensity = state.fireLevel
        config.sparkIntensity = state.fireLevel > 0.5 ? state.fireLevel * 0.5 : 0
        config.steamIntensity = state.floodingLevel * state.fireLevel * 0.5
        
        // Hull deformation based on damage
        config.hullDeformation = SIMD3<Float>(
            Float.random(in: -0.1...0.1) * (1.0 - state.structuralIntegrity),
            -state.floodingLevel * 0.2, // Sag from water weight
            Float.random(in: -0.1...0.1) * (1.0 - state.structuralIntegrity)
        )
        
        // Deck collapse for severe damage
        config.deckCollapse = state.structuralIntegrity < 0.3 ? (0.3 - state.structuralIntegrity) : 0
        
        // Tint color gets darker with damage
        let darkness = 1.0 - (1.0 - state.structuralIntegrity) * 0.3
        let redness = 1.0 + state.fireLevel * 0.2 // Slight red tint for fire
        config.tintColor = SIMD4<Float>(darkness * redness, darkness * 0.9, darkness * 0.8, 1.0)
        
        // Char level for fire damage
        config.charLevel = min(1.0, state.fireLevel * 2.0)
        
        // Set damage textures
        config.scorchTexture = state.fireLevel > 0 ? damageTextures["scorch"] : nil
        config.rustTexture = state.floodingLevel > 0 ? damageTextures["rust"] : nil
        config.dentTexture = state.structuralIntegrity < 0.7 ? damageTextures["dent"] : nil
        config.crackTexture = state.structuralIntegrity < 0.5 ? damageTextures["crack"] : nil
        
        damageVisuals[shipID] = config
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float, ships: [ShipSprite]) {
        for ship in ships {
            guard var state = shipDamageStates[ship.id] else { continue }
            
            // Update ongoing damage effects
            if state.fireLevel > 0 {
                updateFire(&state, ship: ship, deltaTime: deltaTime)
            }
            
            if state.floodingLevel > 0 {
                updateFlooding(&state, ship: ship, deltaTime: deltaTime)
            }
            
            if state.isDamaged {
                updateDamageParticles(ship: ship, state: state)
            }
            
            // Update sinking animation
            if let sinkingAnim = sinkingShips[ship.id] {
                updateSinkingAnimation(ship: ship, state: &state, animation: sinkingAnim, deltaTime: deltaTime)
            }
            
            // Apply physics effects
            applyDamagePhysics(to: ship, state: state)
            
            shipDamageStates[ship.id] = state
        }
    }
    
    private func updateFire(_ state: inout ShipDamageState, ship: ShipSprite, deltaTime: Float) {
        // Fire spreads slowly
        state.fireLevel = min(1.0, state.fireLevel + deltaTime * 0.02)
        
        // Fire damages structure
        state.structuralIntegrity = max(0, state.structuralIntegrity - deltaTime * 0.01 * state.fireLevel)
        
        // Update smoke
        state.smokeDensity = state.fireLevel * (0.7 + sin(CACurrentMediaTime() * 2) * 0.3)
    }
    
    private func updateFlooding(_ state: inout ShipDamageState, ship: ShipSprite, deltaTime: Float) {
        // Flooding increases based on hull damage
        let floodRate = (1.0 - state.structuralIntegrity) * 0.05
        state.floodingLevel = min(1.0, state.floodingLevel + floodRate * deltaTime)
        
        // Flooding affects list and trim
        state.listAngle += Float.random(in: -0.01...0.01) * state.floodingLevel * deltaTime
        state.trimAngle += Float.random(in: -0.005...0.005) * state.floodingLevel * deltaTime
        
        // Clamp angles
        state.listAngle = max(-0.5, min(0.5, state.listAngle))
        state.trimAngle = max(-0.3, min(0.3, state.trimAngle))
    }
    
    private func updateDamageParticles(ship: ShipSprite, state: ShipDamageState) {
        let position = ship.sprite.position
        
        // Smoke particles
        if state.smokeDensity > 0 {
            let smokeCount = Int(state.smokeDensity * 5)
            for _ in 0..<smokeCount {
                let offset = SIMD2<Float>(
                    Float.random(in: -ship.sprite.size.x/4...ship.sprite.size.x/4),
                    Float.random(in: -ship.sprite.size.y/4...ship.sprite.size.y/4)
                )
                
                let particle = ParticleSystem.Particle(
                    position: position + offset,
                    velocity: SIMD2<Float>(Float.random(in: -5...5), Float.random(in: 10...20)),
                    acceleration: SIMD2<Float>(0, 5),
                    color: SIMD4<Float>(0.3, 0.3, 0.3, 0.8),
                    size: Float.random(in: 10...20),
                    rotation: 0,
                    rotationSpeed: Float.random(in: -1...1),
                    lifetime: Float.random(in: 2...4),
                    age: 0,
                    type: .smoke
                )
                particleSystem.addParticle(particle)
            }
        }
        
        // Fire particles
        if state.fireLevel > 0 {
            let fireCount = Int(state.fireLevel * 10)
            for _ in 0..<fireCount {
                let offset = SIMD2<Float>(
                    Float.random(in: -ship.sprite.size.x/3...ship.sprite.size.x/3),
                    Float.random(in: -ship.sprite.size.y/3...ship.sprite.size.y/3)
                )
                
                let particle = ParticleSystem.Particle(
                    position: position + offset,
                    velocity: SIMD2<Float>(Float.random(in: -3...3), Float.random(in: 15...25)),
                    acceleration: SIMD2<Float>(0, 10),
                    color: SIMD4<Float>(1.0, Float.random(in: 0.5...1.0), 0, 1.0),
                    size: Float.random(in: 5...15),
                    rotation: 0,
                    rotationSpeed: 0,
                    lifetime: Float.random(in: 0.5...1.0),
                    age: 0,
                    type: .fire
                )
                particleSystem.addParticle(particle)
            }
        }
        
        // Steam from water hitting fire
        if state.fireLevel > 0 && state.floodingLevel > 0 {
            let steamCount = Int(min(state.fireLevel, state.floodingLevel) * 5)
            for _ in 0..<steamCount {
                let particle = ParticleSystem.Particle(
                    position: position,
                    velocity: SIMD2<Float>(Float.random(in: -10...10), Float.random(in: 20...30)),
                    acceleration: SIMD2<Float>(0, 5),
                    color: SIMD4<Float>(0.9, 0.9, 0.9, 0.6),
                    size: Float.random(in: 15...25),
                    rotation: 0,
                    rotationSpeed: Float.random(in: -0.5...0.5),
                    lifetime: Float.random(in: 1...2),
                    age: 0,
                    type: .steam
                )
                particleSystem.addParticle(particle)
            }
        }
    }
    
    // MARK: - Sinking Animation
    
    private func startSinkingAnimation(shipID: UUID) {
        let animation = SinkingAnimation(
            startTime: CACurrentMediaTime(),
            elapsed: 0,
            duration: Float.random(in: 30...60) // 30-60 seconds to sink
        )
        sinkingShips[shipID] = animation
    }
    
    private func updateSinkingAnimation(ship: ShipSprite, state: inout ShipDamageState, animation: SinkingAnimation, deltaTime: Float) {
        var anim = animation
        anim.elapsed += deltaTime
        
        let progress = min(1.0, anim.elapsed / anim.duration)
        
        // Launch lifeboats at 20% progress
        if progress > 0.2 && !anim.lifeboatsLaunched {
            launchLifeboats(from: ship)
            anim.lifeboatsLaunched = true
        }
        
        // Spawn debris at 50% progress
        if progress > 0.5 && !anim.debrisSpawned {
            spawnDebris(from: ship)
            anim.debrisSpawned = true
        }
        
        // Final explosion at 80% progress
        if progress > 0.8 && !anim.finalExplosion {
            particleSystem.createExplosion(at: ship.sprite.position, intensity: 2.0)
            anim.finalExplosion = true
        }
        
        // Update ship position and rotation
        let sinkDepth = progress * 50 // Sink 50 units deep
        ship.sprite.position.y -= sinkDepth * deltaTime
        
        // Increase list and trim as sinking
        state.listAngle = sin(progress * Float.pi) * 0.5 * (Float.random(in: 0...1) > 0.5 ? 1 : -1)
        state.trimAngle = progress * 0.3 * (Float.random(in: 0...1) > 0.5 ? 1 : -1)
        
        // Ship disappears when fully sunk
        if progress >= 1.0 {
            ship.sprite.isVisible = false
            sinkingShips.removeValue(forKey: ship.id)
            
            // Create final bubble burst
            createBubbleBurst(at: ship.sprite.position)
        } else {
            sinkingShips[ship.id] = anim
        }
    }
    
    private func launchLifeboats(from ship: ShipSprite) {
        // Create small lifeboat sprites moving away from ship
        let lifeboatCount = Int.random(in: 2...4)
        
        for i in 0..<lifeboatCount {
            let angle = Float(i) / Float(lifeboatCount) * Float.pi * 2
            let distance: Float = 30
            let position = ship.sprite.position + SIMD2<Float>(cos(angle), sin(angle)) * distance
            
            // Create lifeboat particle or sprite
            // This would integrate with the sprite system to create actual lifeboat entities
        }
    }
    
    private func spawnDebris(from ship: ShipSprite) {
        let debrisCount = Int.random(in: 20...40)
        
        for _ in 0..<debrisCount {
            let offset = SIMD2<Float>(
                Float.random(in: -ship.sprite.size.x...ship.sprite.size.x),
                Float.random(in: -ship.sprite.size.y...ship.sprite.size.y)
            )
            
            let particle = ParticleSystem.Particle(
                position: ship.sprite.position + offset,
                velocity: SIMD2<Float>(
                    Float.random(in: -20...20),
                    Float.random(in: -10...10)
                ),
                acceleration: SIMD2<Float>(0, -5), // Float for a bit then sink
                color: SIMD4<Float>(0.4, 0.3, 0.2, 1.0), // Brown debris
                size: Float.random(in: 5...15),
                rotation: Float.random(in: 0...Float.pi * 2),
                rotationSpeed: Float.random(in: -2...2),
                lifetime: Float.random(in: 10...20),
                age: 0,
                type: .debris
            )
            particleSystem.addParticle(particle)
        }
    }
    
    private func createBubbleBurst(at position: SIMD2<Float>) {
        let bubbleCount = Int.random(in: 50...100)
        
        for _ in 0..<bubbleCount {
            let offset = SIMD2<Float>.random(in: -20...20)
            
            let particle = ParticleSystem.Particle(
                position: position + offset,
                velocity: SIMD2<Float>(
                    Float.random(in: -10...10),
                    Float.random(in: 20...40)
                ),
                acceleration: SIMD2<Float>(0, 10), // Bubbles accelerate upward
                color: SIMD4<Float>(0.8, 0.9, 1.0, 0.6),
                size: Float.random(in: 3...10),
                rotation: 0,
                rotationSpeed: 0,
                lifetime: Float.random(in: 2...5),
                age: 0,
                type: .bubble
            )
            particleSystem.addParticle(particle)
        }
    }
    
    // MARK: - Physics
    
    private func applyDamagePhysics(to ship: ShipSprite, state: ShipDamageState) {
        // Apply speed reduction
        ship.speed *= state.speedModifier
        
        // Apply list and trim rotations
        let baseRotation = ship.heading
        let totalRotation = baseRotation + state.listAngle
        ship.sprite.rotation = totalRotation
        
        // Modify ship behavior based on damage
        if state.isCritical {
            // Ship can't maintain course well
            ship.heading += Float.random(in: -0.01...0.01)
        }
    }
    
    // MARK: - Damage Texture Generation
    
    private func generateDamageTextures() {
        // Generate scorch marks
        if let scorchTexture = generateScorchTexture() {
            damageTextures["scorch"] = scorchTexture
        }
        
        // Generate rust texture
        if let rustTexture = generateRustTexture() {
            damageTextures["rust"] = rustTexture
        }
        
        // Generate dent texture
        if let dentTexture = generateDentTexture() {
            damageTextures["dent"] = dentTexture
        }
        
        // Generate crack texture
        if let crackTexture = generateCrackTexture() {
            damageTextures["crack"] = crackTexture
        }
    }
    
    private func generateScorchTexture() -> MTLTexture? {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                // Noise-based scorch pattern
                let noise1 = sin(Float(x) * 0.05) * cos(Float(y) * 0.05)
                let noise2 = sin(Float(x + y) * 0.03)
                let scorch = (noise1 + noise2) * 0.5 + 0.5
                
                let intensity = UInt8(scorch * 100)
                
                pixelData[index] = intensity      // R
                pixelData[index + 1] = intensity / 2  // G
                pixelData[index + 2] = intensity / 3  // B
                pixelData[index + 3] = UInt8(scorch * 200) // A
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        return texture
    }
    
    private func generateRustTexture() -> MTLTexture? {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                // Rust pattern
                let noise = sin(Float(x) * 0.1) * sin(Float(y) * 0.1) +
                           cos(Float(x * y) * 0.01) * 0.5
                let rust = max(0, min(1, noise * 0.5 + 0.5))
                
                pixelData[index] = UInt8(180 * rust)     // R
                pixelData[index + 1] = UInt8(100 * rust) // G
                pixelData[index + 2] = UInt8(50 * rust)  // B
                pixelData[index + 3] = UInt8(rust * 150) // A
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        return texture
    }
    
    private func generateDentTexture() -> MTLTexture? {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        // Create circular dent patterns
        let dentCount = 5
        var dentCenters: [(x: Int, y: Int, radius: Float)] = []
        
        for _ in 0..<dentCount {
            dentCenters.append((
                x: Int.random(in: 50...size-50),
                y: Int.random(in: 50...size-50),
                radius: Float.random(in: 20...40)
            ))
        }
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                var dentValue: Float = 0
                
                for dent in dentCenters {
                    let dx = Float(x - dent.x)
                    let dy = Float(y - dent.y)
                    let dist = sqrt(dx * dx + dy * dy)
                    
                    if dist < dent.radius {
                        let depth = 1.0 - (dist / dent.radius)
                        dentValue = max(dentValue, depth)
                    }
                }
                
                let shadow = UInt8(50 * dentValue)
                
                pixelData[index] = shadow         // R
                pixelData[index + 1] = shadow     // G
                pixelData[index + 2] = shadow     // B
                pixelData[index + 3] = UInt8(dentValue * 200) // A
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        return texture
    }
    
    private func generateCrackTexture() -> MTLTexture? {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        // Generate crack pattern using lines
        for _ in 0..<10 {
            let startX = Int.random(in: 0..<size)
            let startY = Int.random(in: 0..<size)
            let length = Int.random(in: 30...100)
            let angle = Float.random(in: 0...Float.pi * 2)
            
            for i in 0..<length {
                let x = startX + Int(cos(angle) * Float(i))
                let y = startY + Int(sin(angle) * Float(i))
                
                if x >= 0 && x < size && y >= 0 && y < size {
                    let index = (y * size + x) * 4
                    
                    pixelData[index] = 20         // R
                    pixelData[index + 1] = 20     // G
                    pixelData[index + 2] = 20     // B
                    pixelData[index + 3] = 255    // A
                    
                    // Add some width to cracks
                    for offset in [-1, 1] {
                        let offsetX = x + offset
                        if offsetX >= 0 && offsetX < size {
                            let offsetIndex = (y * size + offsetX) * 4
                            pixelData[offsetIndex + 3] = 128
                        }
                    }
                }
                
                // Crack branches
                if i % 20 == 0 && Float.random(in: 0...1) < 0.3 {
                    let branchAngle = angle + Float.random(in: -0.5...0.5)
                    let branchLength = Int.random(in: 10...30)
                    
                    for j in 0..<branchLength {
                        let bx = x + Int(cos(branchAngle) * Float(j))
                        let by = y + Int(sin(branchAngle) * Float(j))
                        
                        if bx >= 0 && bx < size && by >= 0 && by < size {
                            let branchIndex = (by * size + bx) * 4
                            pixelData[branchIndex + 3] = 200
                        }
                    }
                }
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        return texture
    }
    
    // MARK: - Getters
    
    func getDamageState(for shipID: UUID) -> ShipDamageState? {
        return shipDamageStates[shipID]
    }
    
    func getVisualConfig(for shipID: UUID) -> DamageVisualConfig? {
        return damageVisuals[shipID]
    }
    
    func repair(shipID: UUID, amount: Float) {
        guard var state = shipDamageStates[shipID] else { return }
        
        state.structuralIntegrity = min(1.0, state.structuralIntegrity + amount)
        state.fireLevel = max(0, state.fireLevel - amount * 0.5)
        state.floodingLevel = max(0, state.floodingLevel - amount * 0.3)
        state.smokeDensity = state.fireLevel
        
        if state.structuralIntegrity >= 0.95 &&
           state.fireLevel <= 0 &&
           state.floodingLevel <= 0 {
            // Ship fully repaired
            shipDamageStates.removeValue(forKey: shipID)
            damageVisuals.removeValue(forKey: shipID)
            sinkingShips.removeValue(forKey: shipID)
        } else {
            shipDamageStates[shipID] = state
            updateVisualConfig(for: shipID, state: state)
        }
    }
}