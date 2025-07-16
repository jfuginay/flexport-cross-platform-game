import Foundation
import Metal
import MetalKit
import simd

/// Handles rendering of sprites in the Metal pipeline
class SpriteRenderer {
    
    private let device: MTLDevice
    private let spriteManager: SpriteManager
    
    // Render pipeline states
    private var spritePipelineState: MTLRenderPipelineState!
    private var particlePipelineState: MTLRenderPipelineState!
    private var trailPipelineState: MTLRenderPipelineState!
    
    // Vertex buffer for sprite quads
    private var quadVertexBuffer: MTLBuffer!
    private var quadIndexBuffer: MTLBuffer!
    
    // Instance buffers for batch rendering
    private var shipInstanceBuffer: MTLBuffer!
    private var portInstanceBuffer: MTLBuffer!
    private var effectInstanceBuffer: MTLBuffer!
    
    // Maximum instances per batch
    private let maxShipInstances = 500
    private let maxPortInstances = 200
    private let maxEffectInstances = 1000
    
    // Active sprites
    private var activeShips: [ShipSprite] = []
    private var activePorts: [PortSprite] = []
    private var activeEffects: [Sprite] = []
    
    // MARK: - Vertex Structures
    
    struct SpriteVertex {
        var position: SIMD2<Float>
        var texCoords: SIMD2<Float>
    }
    
    struct SpriteInstance {
        var transform: matrix_float3x3  // 2D transform matrix
        var textureRect: SIMD4<Float>   // x, y, width, height in texture atlas
        var color: SIMD4<Float>          // Tint color with alpha
        var animationData: SIMD4<Float> // time, frame, custom1, custom2
    }
    
    init(device: MTLDevice, spriteManager: SpriteManager) {
        self.device = device
        self.spriteManager = spriteManager
        
        setupPipelines()
        setupBuffers()
    }
    
    // MARK: - Setup
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        // Sprite pipeline
        let spriteDescriptor = MTLRenderPipelineDescriptor()
        spriteDescriptor.label = "Sprite Pipeline"
        spriteDescriptor.vertexFunction = library.makeFunction(name: "spriteVertexShader")
        spriteDescriptor.fragmentFunction = library.makeFunction(name: "spriteFragmentShader")
        spriteDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending
        spriteDescriptor.colorAttachments[0].isBlendingEnabled = true
        spriteDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        spriteDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        spriteDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        spriteDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // Configure vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position attribute
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Texture coordinates attribute
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Per-vertex layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Instance transform attribute
        vertexDescriptor.attributes[2].format = .float3
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 1
        
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[3].bufferIndex = 1
        
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        vertexDescriptor.attributes[4].bufferIndex = 1
        
        // Instance texture rect
        vertexDescriptor.attributes[5].format = .float4
        vertexDescriptor.attributes[5].offset = MemoryLayout<matrix_float3x3>.stride
        vertexDescriptor.attributes[5].bufferIndex = 1
        
        // Instance color
        vertexDescriptor.attributes[6].format = .float4
        vertexDescriptor.attributes[6].offset = MemoryLayout<matrix_float3x3>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[6].bufferIndex = 1
        
        // Instance animation data
        vertexDescriptor.attributes[7].format = .float4
        vertexDescriptor.attributes[7].offset = MemoryLayout<matrix_float3x3>.stride + MemoryLayout<SIMD4<Float>>.stride * 2
        vertexDescriptor.attributes[7].bufferIndex = 1
        
        // Per-instance layout
        vertexDescriptor.layouts[1].stride = MemoryLayout<SpriteInstance>.stride
        vertexDescriptor.layouts[1].stepRate = 1
        vertexDescriptor.layouts[1].stepFunction = .perInstance
        
        spriteDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            spritePipelineState = try device.makeRenderPipelineState(descriptor: spriteDescriptor)
        } catch {
            fatalError("Failed to create sprite pipeline state: \(error)")
        }
        
        // Particle pipeline (similar setup with different shaders)
        let particleDescriptor = spriteDescriptor.copy() as! MTLRenderPipelineDescriptor
        particleDescriptor.label = "Particle Pipeline"
        particleDescriptor.vertexFunction = library.makeFunction(name: "particleVertexShader")
        particleDescriptor.fragmentFunction = library.makeFunction(name: "particleFragmentShader")
        
        do {
            particlePipelineState = try device.makeRenderPipelineState(descriptor: particleDescriptor)
        } catch {
            fatalError("Failed to create particle pipeline state: \(error)")
        }
        
        // Trail pipeline
        let trailDescriptor = MTLRenderPipelineDescriptor()
        trailDescriptor.label = "Trail Pipeline"
        trailDescriptor.vertexFunction = library.makeFunction(name: "trailVertexShader")
        trailDescriptor.fragmentFunction = library.makeFunction(name: "trailFragmentShader")
        trailDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        trailDescriptor.colorAttachments[0].isBlendingEnabled = true
        trailDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        trailDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            trailPipelineState = try device.makeRenderPipelineState(descriptor: trailDescriptor)
        } catch {
            fatalError("Failed to create trail pipeline state: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Create quad vertices for sprites
        let vertices: [SpriteVertex] = [
            SpriteVertex(position: SIMD2<Float>(-0.5, -0.5), texCoords: SIMD2<Float>(0, 1)),
            SpriteVertex(position: SIMD2<Float>( 0.5, -0.5), texCoords: SIMD2<Float>(1, 1)),
            SpriteVertex(position: SIMD2<Float>( 0.5,  0.5), texCoords: SIMD2<Float>(1, 0)),
            SpriteVertex(position: SIMD2<Float>(-0.5,  0.5), texCoords: SIMD2<Float>(0, 0))
        ]
        
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
        
        quadVertexBuffer = device.makeBuffer(bytes: vertices,
                                           length: vertices.count * MemoryLayout<SpriteVertex>.stride,
                                           options: [])
        
        quadIndexBuffer = device.makeBuffer(bytes: indices,
                                          length: indices.count * MemoryLayout<UInt16>.stride,
                                          options: [])
        
        // Create instance buffers
        shipInstanceBuffer = device.makeBuffer(length: maxShipInstances * MemoryLayout<SpriteInstance>.stride,
                                             options: [])
        
        portInstanceBuffer = device.makeBuffer(length: maxPortInstances * MemoryLayout<SpriteInstance>.stride,
                                             options: [])
        
        effectInstanceBuffer = device.makeBuffer(length: maxEffectInstances * MemoryLayout<SpriteInstance>.stride,
                                               options: [])
    }
    
    // MARK: - Sprite Management
    
    func addShip(_ ship: ShipSprite) {
        activeShips.append(ship)
    }
    
    func addPort(_ port: PortSprite) {
        activePorts.append(port)
    }
    
    func addEffect(_ effect: Sprite) {
        activeEffects.append(effect)
    }
    
    func removeShip(id: UUID) {
        activeShips.removeAll { $0.id == id }
    }
    
    func removePort(id: UUID) {
        activePorts.removeAll { $0.id == id }
    }
    
    func clearAll() {
        activeShips.removeAll()
        activePorts.removeAll()
        activeEffects.removeAll()
    }
    
    // MARK: - Update
    
    func update(deltaTime: Float) {
        // Update ship animations and positions
        for i in 0..<activeShips.count {
            updateShip(&activeShips[i], deltaTime: deltaTime)
        }
        
        // Update port animations
        for i in 0..<activePorts.count {
            updatePort(&activePorts[i], deltaTime: deltaTime)
        }
        
        // Update effects
        activeEffects.removeAll { effect in
            // Remove expired effects
            false // Implement effect lifetime logic
        }
    }
    
    private func updateShip(_ ship: inout ShipSprite, deltaTime: Float) {
        // Update position based on speed and heading
        let velocity = SIMD2<Float>(
            cos(ship.heading) * ship.speed * deltaTime,
            sin(ship.heading) * ship.speed * deltaTime
        )
        ship.sprite.position += velocity
        
        // Update rotation to match heading
        ship.sprite.rotation = ship.heading
        
        // Update trail
        ship.trail.addPoint(ship.sprite.position)
        ship.trail.update()
        
        // Update animations
        ship.engineAnimation += deltaTime * 2.0
        ship.waveOffset += deltaTime * 0.5
        
        // Bob effect
        let bobAmount = sin(ship.waveOffset) * ship.bobAmount * 2.0
        ship.sprite.position.y += bobAmount * deltaTime
        
        // Update damage effects
        if ship.damageLevel > 0 {
            // Add smoke effect
            if ship.damageLevel > 0.5 && Int(ship.engineAnimation * 10) % 5 == 0 {
                addSmokeEffect(at: ship.sprite.position, intensity: ship.damageLevel)
            }
            
            // List to one side when heavily damaged
            if ship.damageLevel > 0.7 {
                ship.sprite.rotation += sin(ship.waveOffset * 2) * 0.1 * ship.damageLevel
            }
        }
    }
    
    private func updatePort(_ port: inout PortSprite, deltaTime: Float) {
        // Update port animations
        for i in 0..<port.animations.count {
            switch port.animations[i] {
            case .craneLoading(var progress):
                progress = min(1.0, progress + deltaTime * 0.2)
                port.animations[i] = .craneLoading(progress: progress)
                
            case .craneUnloading(var progress):
                progress = min(1.0, progress + deltaTime * 0.2)
                port.animations[i] = .craneUnloading(progress: progress)
                
            case .vehicleMovement(let path, var progress):
                progress = min(1.0, progress + deltaTime * 0.3)
                port.animations[i] = .vehicleMovement(path: path, progress: progress)
                
            case .lighthouseRotation(let speed):
                port.sprite.rotation += speed * deltaTime
                
            default:
                break
            }
        }
        
        // Pulse effect based on activity
        let pulse = sin(CACurrentMediaTime() * 2.0 + Double(port.id.hashValue)) * 0.1 + 0.9
        port.sprite.scale = Float(pulse) * (0.8 + port.activityLevel * 0.4)
    }
    
    // MARK: - Effects
    
    private func addSmokeEffect(at position: SIMD2<Float>, intensity: Float) {
        var smoke = Sprite(position: position, size: SIMD2<Float>(30, 30))
        smoke.texture = spriteManager.loadTexture(named: "smoke_effect")
        smoke.alpha = intensity
        smoke.tintColor = SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
        activeEffects.append(smoke)
    }
    
    private func addWakeEffect(for ship: ShipSprite) {
        guard ship.speed > 0 else { return }
        
        var wake = Sprite(
            position: ship.sprite.position - SIMD2<Float>(cos(ship.heading), sin(ship.heading)) * 20,
            size: SIMD2<Float>(40, 60)
        )
        wake.texture = spriteManager.loadTexture(named: "wake_effect")
        wake.rotation = ship.heading
        wake.alpha = min(1.0, ship.speed / 10.0)
        activeEffects.append(wake)
    }
    
    // MARK: - Rendering
    
    func render(encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        // Render ships
        renderShips(encoder: encoder, uniforms: uniforms)
        
        // Render ports
        renderPorts(encoder: encoder, uniforms: uniforms)
        
        // Render effects
        renderEffects(encoder: encoder, uniforms: uniforms)
        
        // Render trails
        renderTrails(encoder: encoder, uniforms: uniforms)
    }
    
    private func renderShips(encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        guard !activeShips.isEmpty else { return }
        
        encoder.setRenderPipelineState(spritePipelineState)
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        
        // Update instance buffer
        let instanceCount = min(activeShips.count, maxShipInstances)
        let instancePointer = shipInstanceBuffer.contents().bindMemory(
            to: SpriteInstance.self,
            capacity: instanceCount
        )
        
        for (index, ship) in activeShips.prefix(instanceCount).enumerated() {
            let instance = createInstance(from: ship.sprite)
            instancePointer[index] = instance
        }
        
        encoder.setVertexBuffer(shipInstanceBuffer, offset: 0, index: 1)
        
        // Set textures
        for (index, ship) in activeShips.prefix(instanceCount).enumerated() {
            if let texture = ship.sprite.texture {
                encoder.setFragmentTexture(texture, index: index)
            }
        }
        
        // Set uniforms
        var mutableUniforms = uniforms
        encoder.setVertexBytes(&mutableUniforms, length: MemoryLayout<SpriteUniforms>.stride, index: 2)
        
        // Draw
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: quadIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
    
    private func renderPorts(encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        guard !activePorts.isEmpty else { return }
        
        encoder.setRenderPipelineState(spritePipelineState)
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        
        // Update instance buffer
        let instanceCount = min(activePorts.count, maxPortInstances)
        let instancePointer = portInstanceBuffer.contents().bindMemory(
            to: SpriteInstance.self,
            capacity: instanceCount
        )
        
        for (index, port) in activePorts.prefix(instanceCount).enumerated() {
            let instance = createInstance(from: port.sprite)
            instancePointer[index] = instance
        }
        
        encoder.setVertexBuffer(portInstanceBuffer, offset: 0, index: 1)
        
        // Set textures
        for (index, port) in activePorts.prefix(instanceCount).enumerated() {
            if let texture = port.sprite.texture {
                encoder.setFragmentTexture(texture, index: index)
            }
        }
        
        // Set uniforms
        var mutableUniforms = uniforms
        encoder.setVertexBytes(&mutableUniforms, length: MemoryLayout<SpriteUniforms>.stride, index: 2)
        
        // Draw
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: quadIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
    
    private func renderEffects(encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        guard !activeEffects.isEmpty else { return }
        
        encoder.setRenderPipelineState(particlePipelineState)
        encoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        
        // Update instance buffer
        let instanceCount = min(activeEffects.count, maxEffectInstances)
        let instancePointer = effectInstanceBuffer.contents().bindMemory(
            to: SpriteInstance.self,
            capacity: instanceCount
        )
        
        for (index, effect) in activeEffects.prefix(instanceCount).enumerated() {
            let instance = createInstance(from: effect)
            instancePointer[index] = instance
        }
        
        encoder.setVertexBuffer(effectInstanceBuffer, offset: 0, index: 1)
        
        // Set uniforms
        var mutableUniforms = uniforms
        encoder.setVertexBytes(&mutableUniforms, length: MemoryLayout<SpriteUniforms>.stride, index: 2)
        
        // Draw
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: quadIndexBuffer,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
    }
    
    private func renderTrails(encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        encoder.setRenderPipelineState(trailPipelineState)
        
        // Render ship trails
        for ship in activeShips {
            renderTrail(ship.trail, encoder: encoder, uniforms: uniforms)
        }
    }
    
    private func renderTrail(_ trail: ShipTrail, encoder: MTLRenderCommandEncoder, uniforms: SpriteUniforms) {
        guard trail.points.count > 1 else { return }
        
        // Create trail geometry
        var vertices: [SIMD2<Float>] = []
        let currentTime = CACurrentMediaTime()
        
        for i in 0..<trail.points.count - 1 {
            let p1 = trail.points[i]
            let p2 = trail.points[i + 1]
            
            let direction = normalize(p2.position - p1.position)
            let perpendicular = SIMD2<Float>(-direction.y, direction.x)
            
            let alpha1 = p1.alpha(currentTime: currentTime, fadeTime: trail.fadeTime)
            let alpha2 = p2.alpha(currentTime: currentTime, fadeTime: trail.fadeTime)
            
            let width1 = trail.width * alpha1
            let width2 = trail.width * alpha2
            
            // Create quad vertices
            vertices.append(p1.position - perpendicular * width1 * 0.5)
            vertices.append(p1.position + perpendicular * width1 * 0.5)
            vertices.append(p2.position - perpendicular * width2 * 0.5)
            vertices.append(p2.position + perpendicular * width2 * 0.5)
        }
        
        // Create temporary buffer
        if !vertices.isEmpty {
            let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
                options: []
            )
            
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var mutableUniforms = uniforms
            encoder.setVertexBytes(&mutableUniforms, length: MemoryLayout<SpriteUniforms>.stride, index: 1)
            
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        }
    }
    
    // MARK: - Helper Functions
    
    private func createInstance(from sprite: Sprite) -> SpriteInstance {
        // Create 2D transform matrix
        let translation = matrix_float3x3(
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(sprite.position.x, sprite.position.y, 1)
        )
        
        let rotation = matrix_float3x3(
            SIMD3<Float>(cos(sprite.rotation), sin(sprite.rotation), 0),
            SIMD3<Float>(-sin(sprite.rotation), cos(sprite.rotation), 0),
            SIMD3<Float>(0, 0, 1)
        )
        
        let scale = matrix_float3x3(
            SIMD3<Float>(sprite.size.x * sprite.scale, 0, 0),
            SIMD3<Float>(0, sprite.size.y * sprite.scale, 0),
            SIMD3<Float>(0, 0, 1)
        )
        
        let transform = translation * rotation * scale
        
        // Texture rect (full texture for now)
        let textureRect = SIMD4<Float>(0, 0, 1, 1)
        
        // Color with alpha
        let color = SIMD4<Float>(
            sprite.tintColor.x,
            sprite.tintColor.y,
            sprite.tintColor.z,
            sprite.tintColor.w * sprite.alpha
        )
        
        // Animation data
        let animationData = SIMD4<Float>(0, 0, 0, 0)
        
        return SpriteInstance(
            transform: transform,
            textureRect: textureRect,
            color: color,
            animationData: animationData
        )
    }
}

// MARK: - Matrix Helpers

extension matrix_float3x3 {
    init(_ col0: SIMD3<Float>, _ col1: SIMD3<Float>, _ col2: SIMD3<Float>) {
        self.init(columns: (col0, col1, col2))
    }
}