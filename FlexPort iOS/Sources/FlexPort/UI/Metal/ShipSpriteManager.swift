import Metal
import MetalKit
import simd

// MARK: - Ship Sprite Manager

public class ShipSpriteManager {
    private let device: MTLDevice
    private let spriteManager: SpriteManager
    
    // Active ships
    private var ships: [String: ShipInstance] = [:]
    private var shipBatch: ShipBatch
    
    // Render pipelines
    private var shipRenderPipeline: MTLRenderPipelineState!
    private var wakeRenderPipeline: MTLRenderPipelineState!
    private var particleRenderPipeline: MTLRenderPipelineState!
    
    // Buffers
    private var shipInstanceBuffer: MTLBuffer!
    private var wakeInstanceBuffer: MTLBuffer!
    private var particleBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // Textures
    private var shipTextureArray: MTLTexture!
    private var wakeTexture: MTLTexture!
    private var particleTexture: MTLTexture!
    
    // Performance settings
    public var enableParticleEffects = true
    public var enableDynamicLighting = true
    public var enableAdvancedEffects = false
    
    // Weather conditions
    private var currentWeather: AdvancedOceanRenderer.WeatherType = .clear
    private var weatherIntensity: Float = 0
    
    // Animation timing
    private var animationTime: Float = 0
    
    private let maxShips = 200
    private let maxWakes = 200
    private let maxParticles = 5000
    
    // MARK: - Ship Instance Data
    
    private struct ShipInstance {
        var id: String
        var type: ShipType
        var position: SIMD2<Float>
        var rotation: Float
        var scale: Float
        var velocity: SIMD2<Float>
        var highlight: SIMD4<Float>
        var wakeIntensity: Float
        var animationOffset: Float
        var health: Float
        var lastPosition: SIMD2<Float>
        var bobPhase: Float
    }
    
    private struct ShipBatch {
        var instances: [ShipInstanceData] = []
        var count: Int = 0
    }
    
    private struct ShipInstanceData {
        var modelMatrix: matrix_float4x4
        var textureIndex: Int32
        var tintColor: SIMD4<Float>
        var animationData: SIMD4<Float> // x: bobAmount, y: bobPhase, z: wakeIntensity, w: damage
    }
    
    private struct WakeInstance {
        var position: SIMD3<Float>
        var size: SIMD2<Float>
        var opacity: Float
        var age: Float
    }
    
    private struct Particle {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var color: SIMD4<Float>
        var size: Float
        var life: Float
        var type: Int32
    }
    
    // MARK: - Initialization
    
    public init(device: MTLDevice) {
        self.device = device
        self.spriteManager = SpriteManager(device: device)
        self.shipBatch = ShipBatch()
        
        setupPipelines()
        setupBuffers()
        setupTextures()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        // Ship render pipeline
        let shipDescriptor = MTLRenderPipelineDescriptor()
        shipDescriptor.vertexFunction = library.makeFunction(name: "shipInstanceVertexShader")
        shipDescriptor.fragmentFunction = library.makeFunction(name: "shipInstanceFragmentShader")
        shipDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        shipDescriptor.colorAttachments[0].isBlendingEnabled = true
        shipDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        shipDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        shipDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            shipRenderPipeline = try device.makeRenderPipelineState(descriptor: shipDescriptor)
        } catch {
            fatalError("Failed to create ship render pipeline: \(error)")
        }
        
        // Wake render pipeline
        let wakeDescriptor = MTLRenderPipelineDescriptor()
        wakeDescriptor.vertexFunction = library.makeFunction(name: "wakeVertexShader")
        wakeDescriptor.fragmentFunction = library.makeFunction(name: "wakeFragmentShader")
        wakeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        wakeDescriptor.colorAttachments[0].isBlendingEnabled = true
        wakeDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        wakeDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        wakeDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            wakeRenderPipeline = try device.makeRenderPipelineState(descriptor: wakeDescriptor)
        } catch {
            fatalError("Failed to create wake render pipeline: \(error)")
        }
        
        // Particle render pipeline
        let particleDescriptor = MTLRenderPipelineDescriptor()
        particleDescriptor.vertexFunction = library.makeFunction(name: "particleVertexShader")
        particleDescriptor.fragmentFunction = library.makeFunction(name: "particleFragmentShader")
        particleDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        particleDescriptor.colorAttachments[0].isBlendingEnabled = true
        particleDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        particleDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        particleDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            particleRenderPipeline = try device.makeRenderPipelineState(descriptor: particleDescriptor)
        } catch {
            fatalError("Failed to create particle render pipeline: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Ship instance buffer
        let shipInstanceSize = MemoryLayout<ShipInstanceData>.stride * maxShips
        shipInstanceBuffer = device.makeBuffer(length: shipInstanceSize, options: .storageModeShared)
        
        // Wake instance buffer
        let wakeInstanceSize = MemoryLayout<WakeInstance>.stride * maxWakes
        wakeInstanceBuffer = device.makeBuffer(length: wakeInstanceSize, options: .storageModeShared)
        
        // Particle buffer
        let particleSize = MemoryLayout<Particle>.stride * maxParticles
        particleBuffer = device.makeBuffer(length: particleSize, options: .storageModeShared)
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<ShipUniforms>.stride, options: .storageModeShared)
    }
    
    private func setupTextures() {
        // Create ship texture array for different ship types
        createShipTextureArray()
        
        // Load or create wake texture
        if let texture = spriteManager.loadTexture(named: "wake_effect") {
            wakeTexture = texture
        } else {
            wakeTexture = createWakeTexture()
        }
        
        // Load or create particle texture
        if let texture = spriteManager.loadTexture(named: "particle_circle") {
            particleTexture = texture
        } else {
            particleTexture = createParticleTexture()
        }
    }
    
    private func createShipTextureArray() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2DArray
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.arrayLength = ShipType.allCases.count
        textureDescriptor.mipmapLevelCount = 1
        textureDescriptor.usage = [.shaderRead]
        
        shipTextureArray = device.makeTexture(descriptor: textureDescriptor)
        
        // Generate ship sprites for each type
        for (index, shipType) in ShipType.allCases.enumerated() {
            generateShipSprite(type: shipType, slice: index)
        }
    }
    
    private func generateShipSprite(type: ShipType, slice: Int) {
        let size = 256
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        // Generate ship sprite based on type
        switch type {
        case .container:
            generateContainerShipSprite(&pixelData, size: size)
        case .tanker:
            generateTankerShipSprite(&pixelData, size: size)
        case .bulk:
            generateBulkCarrierSprite(&pixelData, size: size)
        case .cruise:
            generateCruiseShipSprite(&pixelData, size: size)
        case .military:
            generateMilitaryShipSprite(&pixelData, size: size)
        case .research:
            generateResearchShipSprite(&pixelData, size: size)
        case .quantum:
            generateQuantumShipSprite(&pixelData, size: size)
        }
        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: size, height: size, depth: 1)
        )
        
        shipTextureArray?.replace(
            region: region,
            mipmapLevel: 0,
            slice: slice,
            withBytes: pixelData,
            bytesPerRow: size * 4,
            bytesPerImage: size * size * 4
        )
    }
    
    // MARK: - Ship Sprite Generation
    
    private func generateContainerShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 3 / 4
        let shipWidth = size / 4
        
        // Hull
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                // Ship body
                let dx = x - centerX
                let dy = y - centerY
                
                if abs(dx) < shipWidth / 2 && abs(dy) < shipLength / 2 {
                    // Main hull - dark blue
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(40, 60, 80, 255))
                    
                    // Container stacks
                    if abs(dy) < shipLength / 3 {
                        let containerSize = 20
                        if (x - centerX + shipWidth/2) % containerSize < containerSize - 2 &&
                           (y - centerY + shipLength/3) % containerSize < containerSize - 2 {
                            let colors = [
                                SIMD4<UInt8>(200, 50, 50, 255),   // Red
                                SIMD4<UInt8>(50, 100, 200, 255),  // Blue
                                SIMD4<UInt8>(50, 150, 50, 255),   // Green
                                SIMD4<UInt8>(200, 150, 50, 255)   // Orange
                            ]
                            let colorIndex = ((x + y) / containerSize) % colors.count
                            setPixel(&pixels, index: index, color: colors[colorIndex])
                        }
                    }
                }
                
                // Bridge at stern
                if dx > shipWidth / 4 && dx < shipWidth / 2 &&
                   dy > shipLength / 3 && dy < shipLength / 2 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(220, 220, 220, 255))
                }
            }
        }
    }
    
    private func generateTankerShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 3 / 4
        let shipWidth = size / 3
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = Float(x - centerX) / Float(shipWidth / 2)
                let dy = Float(y - centerY) / Float(shipLength / 2)
                
                // Elliptical hull
                if dx * dx + dy * dy * 0.7 <= 1.0 {
                    // Black hull
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(30, 30, 40, 255))
                    
                    // Red deck area
                    if abs(dy) < 0.6 {
                        setPixel(&pixels, index: index, color: SIMD4<UInt8>(180, 60, 60, 255))
                        
                        // Pipe manifolds
                        if Int(abs(dx * Float(shipWidth))) % 15 < 3 {
                            setPixel(&pixels, index: index, color: SIMD4<UInt8>(150, 150, 150, 255))
                        }
                    }
                }
                
                // Bridge
                if dx > 0.5 && dx < 0.8 && dy > 0.4 && dy < 0.7 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(200, 200, 200, 255))
                }
            }
        }
    }
    
    private func generateBulkCarrierSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 3 / 4
        let shipWidth = size / 4
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = x - centerX
                let dy = y - centerY
                
                // Blocky hull
                if abs(dx) < shipWidth / 2 && abs(dy) < shipLength / 2 {
                    // Brown hull
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(80, 60, 40, 255))
                    
                    // Cargo hatches
                    if abs(dy) < shipLength / 3 {
                        let hatchSpacing = shipLength / 5
                        if abs(dy) % hatchSpacing < 20 && abs(dx) < shipWidth / 3 {
                            setPixel(&pixels, index: index, color: SIMD4<UInt8>(100, 100, 120, 255))
                        }
                    }
                }
                
                // Cranes
                if abs(dx) < 3 && abs(dy) < shipLength / 3 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(200, 200, 50, 255))
                }
            }
        }
    }
    
    private func generateCruiseShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 4 / 5
        let shipWidth = size / 5
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = x - centerX
                let dy = y - centerY
                
                // Sleek hull
                let hullTaper = 1.0 - abs(Float(dy)) / Float(shipLength / 2) * 0.3
                if abs(Float(dx)) < Float(shipWidth) / 2 * hullTaper && abs(dy) < shipLength / 2 {
                    // White superstructure
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(250, 250, 250, 255))
                    
                    // Deck levels with balconies
                    let deckLevel = abs(dy) / 20
                    if deckLevel < 8 && x % 8 < 6 {
                        // Windows/balconies
                        setPixel(&pixels, index: index, color: SIMD4<UInt8>(100, 150, 200, 255))
                    }
                    
                    // Dark blue hull bottom
                    if dy > shipLength / 3 {
                        setPixel(&pixels, index: index, color: SIMD4<UInt8>(30, 30, 60, 255))
                    }
                }
            }
        }
    }
    
    private func generateMilitaryShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 3 / 4
        let shipWidth = size / 5
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = x - centerX
                let dy = y - centerY
                
                // Angular military design
                let hullWidth = shipWidth - abs(dy) / 10
                if abs(dx) < hullWidth / 2 && abs(dy) < shipLength / 2 {
                    // Gray military color
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(100, 100, 110, 255))
                    
                    // Weapon systems
                    if abs(dy) < shipLength / 4 && abs(dx) < 5 {
                        if abs(dy) % 40 < 10 {
                            setPixel(&pixels, index: index, color: SIMD4<UInt8>(60, 60, 70, 255))
                        }
                    }
                }
                
                // Bridge/command center
                if abs(dx) < shipWidth / 4 && dy > 0 && dy < shipLength / 4 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(80, 80, 90, 255))
                }
            }
        }
    }
    
    private func generateResearchShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 2 / 3
        let shipWidth = size / 4
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = x - centerX
                let dy = y - centerY
                
                if abs(dx) < shipWidth / 2 && abs(dy) < shipLength / 2 {
                    // White research vessel
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(240, 240, 240, 255))
                    
                    // Research equipment (orange)
                    if abs(dy) < shipLength / 3 {
                        if abs(dx) % 30 < 10 && abs(dy) % 30 < 10 {
                            setPixel(&pixels, index: index, color: SIMD4<UInt8>(255, 150, 0, 255))
                        }
                    }
                }
                
                // Observation deck
                if abs(dx) < shipWidth / 3 && dy < -shipLength / 4 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(100, 200, 255, 255))
                }
            }
        }
    }
    
    private func generateQuantumShipSprite(_ pixels: inout [UInt8], size: Int) {
        let centerX = size / 2
        let centerY = size / 2
        let shipLength = size * 3 / 4
        let shipWidth = size / 3
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = Float(x - centerX)
                let dy = Float(y - centerY)
                let distance = sqrt(dx * dx + dy * dy)
                
                // Futuristic design with energy field
                if distance < Float(shipLength) / 2 {
                    let angle = atan2(dy, dx)
                    let radius = Float(shipWidth) / 2 * (1 + sin(angle * 3) * 0.2)
                    
                    if distance < radius {
                        // Quantum blue core
                        let intensity = 1.0 - distance / radius
                        let r = UInt8(100 * intensity)
                        let g = UInt8(200 * intensity)
                        let b = UInt8(255)
                        let a = UInt8(255 * (0.8 + intensity * 0.2))
                        
                        setPixel(&pixels, index: index, color: SIMD4<UInt8>(r, g, b, a))
                    } else if distance < radius + 10 {
                        // Energy field edge
                        let edgeIntensity = 1.0 - (distance - radius) / 10
                        let a = UInt8(200 * edgeIntensity)
                        setPixel(&pixels, index: index, color: SIMD4<UInt8>(150, 230, 255, a))
                    }
                }
            }
        }
    }
    
    private func setPixel(_ pixels: inout [UInt8], index: Int, color: SIMD4<UInt8>) {
        guard index + 3 < pixels.count else { return }
        pixels[index] = color.x
        pixels[index + 1] = color.y
        pixels[index + 2] = color.z
        pixels[index + 3] = color.w
    }
    
    // MARK: - Texture Creation
    
    private func createWakeTexture() -> MTLTexture? {
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
                
                // V-shaped wake pattern
                let centerX = size / 2
                let dx = Float(x - centerX) / Float(size / 2)
                let dy = Float(y) / Float(size)
                
                let wakeIntensity = max(0, 1.0 - abs(dx) * 2) * (1.0 - dy)
                let foam = (sin(dy * 20) * 0.3 + 0.7) * wakeIntensity
                
                pixelData[index] = 255
                pixelData[index + 1] = 255
                pixelData[index + 2] = 255
                pixelData[index + 3] = UInt8(foam * 255)
            }
        }
        
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: size, height: size, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: size * 4
        )
        
        return texture
    }
    
    private func createParticleTexture() -> MTLTexture? {
        let size = 64
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        let center = Float(size) / 2
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = Float(x) - center
                let dy = Float(y) - center
                let distance = sqrt(dx * dx + dy * dy) / center
                
                let alpha = max(0, 1.0 - distance)
                
                pixelData[index] = 255
                pixelData[index + 1] = 255
                pixelData[index + 2] = 255
                pixelData[index + 3] = UInt8(alpha * alpha * 255)
            }
        }
        
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: size, height: size, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: size * 4
        )
        
        return texture
    }
    
    // MARK: - Ship Management
    
    public func addShip(id: String, type: ShipType, position: SIMD2<Float>) {
        let ship = ShipInstance(
            id: id,
            type: type,
            position: position,
            rotation: 0,
            scale: 1.0,
            velocity: SIMD2<Float>(0, 0),
            highlight: SIMD4<Float>(1, 1, 1, 1),
            wakeIntensity: 0,
            animationOffset: Float.random(in: 0...Float.pi * 2),
            health: 1.0,
            lastPosition: position,
            bobPhase: Float.random(in: 0...Float.pi * 2)
        )
        
        ships[id] = ship
    }
    
    public func updateShip(id: String, position: SIMD2<Float>, rotation: Float) {
        guard var ship = ships[id] else { return }
        
        // Calculate velocity for wake effects
        let deltaPos = position - ship.lastPosition
        ship.velocity = deltaPos
        ship.lastPosition = ship.position
        
        ship.position = position
        ship.rotation = rotation
        
        // Update wake intensity based on speed
        let speed = length(ship.velocity)
        ship.wakeIntensity = min(speed * 10, 1.0)
        
        ships[id] = ship
    }
    
    public func removeShip(id: String) {
        ships.removeValue(forKey: id)
    }
    
    public func highlightShip(id: String, color: SIMD4<Float>) {
        if var ship = ships[id] {
            ship.highlight = color
            ships[id] = ship
        }
    }
    
    public func setWakeIntensity(for shipId: String, intensity: Float) {
        if var ship = ships[shipId] {
            ship.wakeIntensity = intensity
            ships[shipId] = ship
        }
    }
    
    // MARK: - Weather
    
    public func setWeatherConditions(weather: AdvancedOceanRenderer.WeatherType, intensity: Float) {
        currentWeather = weather
        weatherIntensity = intensity
    }
    
    // MARK: - Effects
    
    public func createExplosionEffect(at position: SIMD2<Float>) {
        guard enableParticleEffects else { return }
        
        // This would create explosion particles
        // Implementation would update particle buffer
    }
    
    // MARK: - Rendering
    
    public func render(
        encoder: MTLRenderCommandEncoder,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4,
        oceanTime: Float
    ) {
        animationTime = oceanTime
        
        // Update ship instances
        updateShipInstances()
        
        // Render ships
        renderShips(encoder: encoder, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        
        // Render wakes
        if enableParticleEffects {
            renderWakes(encoder: encoder, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        }
        
        // Render particles
        if enableAdvancedEffects {
            renderParticles(encoder: encoder, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        }
    }
    
    private func updateShipInstances() {
        shipBatch.instances.removeAll()
        shipBatch.count = 0
        
        for ship in ships.values {
            // Calculate ship bobbing on waves
            let bobAmount: Float = 0.5 + weatherIntensity * 1.5
            let bobSpeed: Float = 1.0 + weatherIntensity * 0.5
            let bobOffset = sin(animationTime * bobSpeed + ship.bobPhase) * bobAmount
            
            // Create model matrix
            var transform = matrix_identity_float4x4
            transform = matrix_multiply(transform, matrix_translation(ship.position.x, bobOffset, ship.position.y))
            transform = matrix_multiply(transform, matrix_rotation_y(ship.rotation))
            transform = matrix_multiply(transform, matrix_scale(ship.scale, ship.scale, ship.scale))
            
            let instance = ShipInstanceData(
                modelMatrix: transform,
                textureIndex: Int32(ship.type.rawValue),
                tintColor: ship.highlight,
                animationData: SIMD4<Float>(bobAmount, ship.bobPhase, ship.wakeIntensity, 1.0 - ship.health)
            )
            
            shipBatch.instances.append(instance)
            shipBatch.count += 1
            
            if shipBatch.count >= maxShips {
                break
            }
        }
        
        // Update buffer
        if shipBatch.count > 0 {
            shipInstanceBuffer.contents().copyMemory(
                from: shipBatch.instances,
                byteCount: MemoryLayout<ShipInstanceData>.stride * shipBatch.count
            )
        }
    }
    
    private func renderShips(
        encoder: MTLRenderCommandEncoder,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4
    ) {
        guard shipBatch.count > 0 else { return }
        
        // Update uniforms
        var uniforms = ShipUniforms(
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix,
            time: animationTime,
            lightDirection: normalize(SIMD3<Float>(0.3, -0.8, 0.5)),
            lightColor: SIMD3<Float>(1.0, 0.95, 0.8),
            ambientLight: SIMD3<Float>(0.3, 0.4, 0.5),
            fogColor: SIMD3<Float>(0.7, 0.8, 0.9),
            fogDensity: 0.001 + weatherIntensity * 0.002
        )
        
        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<ShipUniforms>.stride)
        
        encoder.setRenderPipelineState(shipRenderPipeline)
        encoder.setVertexBuffer(shipInstanceBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(shipTextureArray, index: 0)
        
        // Draw instanced ships
        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4,
            instanceCount: shipBatch.count
        )
    }
    
    private func renderWakes(
        encoder: MTLRenderCommandEncoder,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4
    ) {
        // Wake rendering implementation
        encoder.setRenderPipelineState(wakeRenderPipeline)
        encoder.setVertexBuffer(wakeInstanceBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(wakeTexture, index: 0)
        
        // Draw wake instances
        // Implementation would render wake trails behind ships
    }
    
    private func renderParticles(
        encoder: MTLRenderCommandEncoder,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4
    ) {
        // Particle rendering implementation
        encoder.setRenderPipelineState(particleRenderPipeline)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(particleTexture, index: 0)
        
        // Draw particles
        // Implementation would render spray, smoke, etc.
    }
    
    // MARK: - Utility Functions
    
    private func matrix_translation(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
        return matrix_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        )
    }
    
    private func matrix_rotation_y(_ angle: Float) -> matrix_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        
        return matrix_float4x4(
            SIMD4<Float>(c, 0, s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(-s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    private func matrix_scale(_ x: Float, _ y: Float, _ z: Float) -> matrix_float4x4 {
        return matrix_float4x4(
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
}

// MARK: - Supporting Types

public enum ShipType: Int, CaseIterable {
    case container = 0
    case tanker = 1
    case bulk = 2
    case cruise = 3
    case military = 4
    case research = 5
    case quantum = 6
}

struct ShipUniforms {
    var projectionMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
    var time: Float
    var lightDirection: SIMD3<Float>
    var lightColor: SIMD3<Float>
    var ambientLight: SIMD3<Float>
    var fogColor: SIMD3<Float>
    var fogDensity: Float
}