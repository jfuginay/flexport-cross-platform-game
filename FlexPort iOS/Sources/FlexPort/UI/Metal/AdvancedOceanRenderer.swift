import Metal
import MetalKit
import simd

// MARK: - Advanced Ocean Renderer

/// Advanced Metal renderer for realistic ocean effects with weather and disasters
public class AdvancedOceanRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Render pipelines
    private var oceanRenderPipeline: MTLRenderPipelineState!
    private var waveComputePipeline: MTLComputePipelineState!
    private var particleRenderPipeline: MTLRenderPipelineState!
    private var disasterEffectPipeline: MTLRenderPipelineState!
    
    // Buffers
    private var oceanVertexBuffer: MTLBuffer!
    private var oceanIndexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var waveBuffer: MTLBuffer!
    private var particleBuffer: MTLBuffer!
    private var disasterBuffer: MTLBuffer!
    
    // Textures
    private var heightmapTexture: MTLTexture!
    private var normalTexture: MTLTexture!
    private var foamTexture: MTLTexture!
    private var causticTexture: MTLTexture!
    private var skyboxTexture: MTLTexture!
    
    // Ocean configuration
    private let oceanSize: Float = 2000.0
    private let oceanResolution: Int = 256
    private var oceanTime: Float = 0.0
    private var waveAmplitude: Float = 1.0
    private var waveFrequency: Float = 0.02
    private var waveSpeed: Float = 1.0
    
    // Weather effects
    private var currentWeather: WeatherType = .clear
    private var weatherIntensity: Float = 0.0
    private var stormCenter: SIMD3<Float> = .zero
    private var windDirection: SIMD2<Float> = SIMD2<Float>(1, 0)
    private var windSpeed: Float = 10.0
    
    // Disaster effects
    private var activeDisasters: [DisasterEffect] = []
    private var maxParticles: Int = 10000
    private var particleCount: Int = 0
    
    public enum WeatherType: String, CaseIterable {
        case clear = "Clear"
        case cloudy = "Cloudy"
        case storm = "Storm"
        case hurricane = "Hurricane"
        case fog = "Fog"
        case rain = "Rain"
    }
    
    public struct DisasterEffect {
        let type: DisasterEffectComponent.DisasterType
        let position: SIMD3<Float>
        let radius: Float
        let intensity: Float
        let duration: Float
        var remainingTime: Float
        let color: SIMD4<Float>
        
        init(type: DisasterEffectComponent.DisasterType, position: SIMD3<Float>, radius: Float, intensity: Float, duration: Float) {
            self.type = type
            self.position = position
            self.radius = radius
            self.intensity = intensity
            self.duration = duration
            self.remainingTime = duration
            self.color = DisasterEffect.getColor(for: type)
        }
        
        private static func getColor(for type: DisasterEffectComponent.DisasterType) -> SIMD4<Float> {
            switch type {
            case .hurricane: return SIMD4<Float>(0.2, 0.2, 0.3, 0.8)
            case .tsunami: return SIMD4<Float>(0.0, 0.3, 0.8, 0.9)
            case .earthquake: return SIMD4<Float>(0.5, 0.3, 0.1, 0.7)
            case .storm: return SIMD4<Float>(0.3, 0.3, 0.3, 0.8)
            case .fog: return SIMD4<Float>(0.9, 0.9, 0.9, 0.6)
            case .piracy: return SIMD4<Float>(1.0, 0.5, 0.0, 1.0)
            case .cyberAttack: return SIMD4<Float>(0.0, 0.8, 1.0, 1.0)
            case .fire: return SIMD4<Float>(1.0, 0.3, 0.0, 1.0)
            case .flooding: return SIMD4<Float>(0.2, 0.4, 0.8, 0.8)
            }
        }
    }
    
    // Uniform structures for shaders
    struct OceanUniforms {
        var projectionMatrix: matrix_float4x4
        var viewMatrix: matrix_float4x4
        var modelMatrix: matrix_float4x4
        var normalMatrix: matrix_float3x3
        var time: Float
        var waveAmplitude: Float
        var waveFrequency: Float
        var waveSpeed: Float
        var windDirection: SIMD2<Float>
        var windSpeed: Float
        var weatherIntensity: Float
        var weatherType: Int32
        var stormCenter: SIMD3<Float>
        var cameraPosition: SIMD3<Float>
        var lightDirection: SIMD3<Float>
        var lightColor: SIMD3<Float>
    }
    
    struct ParticleUniforms {
        var projectionMatrix: matrix_float4x4
        var viewMatrix: matrix_float4x4
        var time: Float
        var particleCount: Int32
        var windDirection: SIMD2<Float>
        var windSpeed: Float
    }
    
    struct Particle {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var life: Float
        var size: Float
        var color: SIMD4<Float>
        var type: Int32 // 0=foam, 1=spray, 2=rain, 3=smoke
    }
    
    public init?(device: MTLDevice) {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create default library")
            return nil
        }
        self.library = library
        
        setupPipelines()
        setupBuffers()
        setupTextures()
        generateOceanMesh()
    }
    
    private func setupPipelines() {
        // Ocean rendering pipeline
        let oceanVertexFunction = library.makeFunction(name: "oceanVertexShader")
        let oceanFragmentFunction = library.makeFunction(name: "oceanFragmentShader")
        
        let oceanPipelineDescriptor = MTLRenderPipelineDescriptor()
        oceanPipelineDescriptor.vertexFunction = oceanVertexFunction
        oceanPipelineDescriptor.fragmentFunction = oceanFragmentFunction
        oceanPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        oceanPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        oceanPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        oceanPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        oceanPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        oceanPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            oceanRenderPipeline = try device.makeRenderPipelineState(descriptor: oceanPipelineDescriptor)
        } catch {
            fatalError("Failed to create ocean render pipeline: \(error)")
        }
        
        // Wave computation pipeline
        guard let waveComputeFunction = library.makeFunction(name: "waveComputeShader") else {
            fatalError("Failed to find wave compute function")
        }
        
        do {
            waveComputePipeline = try device.makeComputePipelineState(function: waveComputeFunction)
        } catch {
            fatalError("Failed to create wave compute pipeline: \(error)")
        }
        
        // Particle rendering pipeline
        let particleVertexFunction = library.makeFunction(name: "particleVertexShader")
        let particleFragmentFunction = library.makeFunction(name: "particleFragmentShader")
        
        let particlePipelineDescriptor = MTLRenderPipelineDescriptor()
        particlePipelineDescriptor.vertexFunction = particleVertexFunction
        particlePipelineDescriptor.fragmentFunction = particleFragmentFunction
        particlePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        particlePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        particlePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        particlePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        particlePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        particlePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            particleRenderPipeline = try device.makeRenderPipelineState(descriptor: particlePipelineDescriptor)
        } catch {
            fatalError("Failed to create particle render pipeline: \(error)")
        }
        
        // Disaster effect pipeline
        let disasterVertexFunction = library.makeFunction(name: "disasterVertexShader")
        let disasterFragmentFunction = library.makeFunction(name: "disasterFragmentShader")
        
        let disasterPipelineDescriptor = MTLRenderPipelineDescriptor()
        disasterPipelineDescriptor.vertexFunction = disasterVertexFunction
        disasterPipelineDescriptor.fragmentFunction = disasterFragmentFunction
        disasterPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        disasterPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        disasterPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        disasterPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        disasterPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        disasterPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            disasterEffectPipeline = try device.makeRenderPipelineState(descriptor: disasterPipelineDescriptor)
        } catch {
            fatalError("Failed to create disaster effect pipeline: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<OceanUniforms>.size, options: [.storageModeShared])
        
        // Wave computation buffer
        let waveDataSize = oceanResolution * oceanResolution * MemoryLayout<SIMD4<Float>>.size
        waveBuffer = device.makeBuffer(length: waveDataSize, options: [.storageModeShared])
        
        // Particle buffer
        let particleDataSize = maxParticles * MemoryLayout<Particle>.size
        particleBuffer = device.makeBuffer(length: particleDataSize, options: [.storageModeShared])
        
        // Disaster buffer
        let disasterDataSize = 10 * MemoryLayout<DisasterEffect>.size // Max 10 disasters
        disasterBuffer = device.makeBuffer(length: disasterDataSize, options: [.storageModeShared])
    }
    
    private func setupTextures() {
        // Create procedural textures for ocean effects
        createHeightmapTexture()
        createNormalTexture()
        createFoamTexture()
        createCausticTexture()
        createSkyboxTexture()
    }
    
    private func createHeightmapTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .r32Float
        textureDescriptor.width = 512
        textureDescriptor.height = 512
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        heightmapTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Generate initial heightmap data
        generateHeightmapData()
    }
    
    private func createNormalTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 512
        textureDescriptor.height = 512
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        normalTexture = device.makeTexture(descriptor: textureDescriptor)
    }
    
    private func createFoamTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.usage = [.shaderRead]
        
        foamTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Generate foam pattern
        generateFoamTexture()
    }
    
    private func createCausticTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 512
        textureDescriptor.height = 512
        textureDescriptor.usage = [.shaderRead]
        
        causticTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Generate caustic pattern
        generateCausticTexture()
    }
    
    private func createSkyboxTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .typeCube
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 512
        textureDescriptor.height = 512
        textureDescriptor.usage = [.shaderRead]
        
        skyboxTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Generate skybox data
        generateSkyboxTexture()
    }
    
    private func generateOceanMesh() {
        let vertexCount = (oceanResolution + 1) * (oceanResolution + 1)
        let indexCount = oceanResolution * oceanResolution * 6
        
        // Generate vertices
        var vertices: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        
        for y in 0...oceanResolution {
            for x in 0...oceanResolution {
                let worldX = (Float(x) / Float(oceanResolution) - 0.5) * oceanSize
                let worldZ = (Float(y) / Float(oceanResolution) - 0.5) * oceanSize
                
                vertices.append(SIMD3<Float>(worldX, 0, worldZ))
                texCoords.append(SIMD2<Float>(Float(x) / Float(oceanResolution), Float(y) / Float(oceanResolution)))
            }
        }
        
        // Generate indices
        var indices: [UInt32] = []
        for y in 0..<oceanResolution {
            for x in 0..<oceanResolution {
                let topLeft = UInt32(y * (oceanResolution + 1) + x)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((y + 1) * (oceanResolution + 1) + x)
                let bottomRight = bottomLeft + 1
                
                // First triangle
                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                
                // Second triangle
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }
        
        // Create vertex buffer with interleaved data
        struct OceanVertex {
            let position: SIMD3<Float>
            let texCoord: SIMD2<Float>
        }
        
        var oceanVertices: [OceanVertex] = []
        for i in 0..<vertices.count {
            oceanVertices.append(OceanVertex(position: vertices[i], texCoord: texCoords[i]))
        }
        
        oceanVertexBuffer = device.makeBuffer(
            bytes: oceanVertices,
            length: oceanVertices.count * MemoryLayout<OceanVertex>.size,
            options: [.storageModeShared]
        )
        
        oceanIndexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt32>.size,
            options: [.storageModeShared]
        )
    }
    
    private func generateHeightmapData() {
        // Generate initial Perlin noise heightmap
        let width = heightmapTexture.width
        let height = heightmapTexture.height
        var heightData: [Float] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let nx = Float(x) / Float(width) * 8.0
                let ny = Float(y) / Float(height) * 8.0
                
                let value = perlinNoise(nx, ny) * 0.5 + 0.5
                heightData.append(value)
            }
        }
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: width, height: height, depth: 1))
        
        heightmapTexture.replace(region: region,
                               mipmapLevel: 0,
                               withBytes: heightData,
                               bytesPerRow: width * MemoryLayout<Float>.size)
    }
    
    private func generateFoamTexture() {
        let width = foamTexture.width
        let height = foamTexture.height
        var foamData: [UInt8] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let distance = sqrt(pow(Float(x) - Float(width)/2, 2) + pow(Float(y) - Float(height)/2, 2))
                let normalized = distance / (Float(width) / 2)
                let alpha = max(0, 1.0 - normalized)
                
                foamData.append(255) // R
                foamData.append(255) // G
                foamData.append(255) // B
                foamData.append(UInt8(alpha * 255)) // A
            }
        }
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: width, height: height, depth: 1))
        
        foamTexture.replace(region: region,
                          mipmapLevel: 0,
                          withBytes: foamData,
                          bytesPerRow: width * 4)
    }
    
    private func generateCausticTexture() {
        let width = causticTexture.width
        let height = causticTexture.height
        var causticData: [UInt8] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let nx = Float(x) / Float(width) * 16.0
                let ny = Float(y) / Float(height) * 16.0
                
                let caustic = abs(sin(nx) * cos(ny) * sin(nx + ny))
                let intensity = UInt8(caustic * 255)
                
                causticData.append(intensity) // R
                causticData.append(intensity) // G
                causticData.append(intensity) // B
                causticData.append(intensity) // A
            }
        }
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: width, height: height, depth: 1))
        
        causticTexture.replace(region: region,
                             mipmapLevel: 0,
                             withBytes: causticData,
                             bytesPerRow: width * 4)
    }
    
    private func generateSkyboxTexture() {
        // Generate simple gradient skybox for each face
        let width = skyboxTexture.width
        let height = skyboxTexture.height
        
        for face in 0..<6 {
            var skyboxData: [UInt8] = []
            
            for y in 0..<height {
                for x in 0..<width {
                    let gradient = Float(height - y) / Float(height)
                    
                    let r = UInt8(mix(135, 200, gradient)) // Sky blue to light blue
                    let g = UInt8(mix(206, 235, gradient))
                    let b = UInt8(mix(235, 255, gradient))
                    
                    skyboxData.append(r)
                    skyboxData.append(g)
                    skyboxData.append(b)
                    skyboxData.append(255)
                }
            }
            
            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                  size: MTLSize(width: width, height: height, depth: 1))
            
            skyboxTexture.replace(region: region,
                                mipmapLevel: 0,
                                slice: face,
                                withBytes: skyboxData,
                                bytesPerRow: width * 4,
                                bytesPerImage: width * height * 4)
        }
    }
    
    // MARK: - Rendering
    
    public func render(
        in renderEncoder: MTLRenderCommandEncoder,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4,
        deltaTime: Float
    ) {
        oceanTime += deltaTime
        
        // Update uniforms
        updateUniforms(projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        
        // Compute wave displacement
        computeWaves(deltaTime: deltaTime)
        
        // Update particles
        updateParticles(deltaTime: deltaTime)
        
        // Render ocean surface
        renderOcean(in: renderEncoder)
        
        // Render particle effects
        renderParticles(in: renderEncoder)
        
        // Render disaster effects
        renderDisasterEffects(in: renderEncoder)
    }
    
    private func updateUniforms(projectionMatrix: matrix_float4x4, viewMatrix: matrix_float4x4) {
        guard let uniformData = uniformBuffer.contents().bindMemory(to: OceanUniforms.self, capacity: 1) else {
            return
        }
        
        let modelMatrix = matrix_identity_float4x4
        let normalMatrix = matrix_float3x3(
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 0, 1)
        )
        
        let lightDirection = normalize(SIMD3<Float>(0.3, -0.8, 0.5))
        let lightColor = SIMD3<Float>(1.0, 0.95, 0.8)
        let cameraPosition = SIMD3<Float>(0, 10, 0) // Extract from view matrix
        
        uniformData.pointee = OceanUniforms(
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix,
            modelMatrix: modelMatrix,
            normalMatrix: normalMatrix,
            time: oceanTime,
            waveAmplitude: waveAmplitude * (1.0 + weatherIntensity),
            waveFrequency: waveFrequency,
            waveSpeed: waveSpeed * (1.0 + windSpeed / 50.0),
            windDirection: windDirection,
            windSpeed: windSpeed,
            weatherIntensity: weatherIntensity,
            weatherType: Int32(currentWeather.hashValue),
            stormCenter: stormCenter,
            cameraPosition: cameraPosition,
            lightDirection: lightDirection,
            lightColor: lightColor
        )
    }
    
    private func computeWaves(deltaTime: Float) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        computeEncoder.setComputePipelineState(waveComputePipeline)
        computeEncoder.setBuffer(waveBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (oceanResolution + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (oceanResolution + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    private func updateParticles(deltaTime: Float) {
        guard let particleData = particleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles) else {
            return
        }
        
        // Update existing particles
        var activeParticles = 0
        for i in 0..<particleCount {
            var particle = particleData[i]
            
            // Update life
            particle.life -= deltaTime
            
            if particle.life > 0 {
                // Update position
                particle.position += particle.velocity * deltaTime
                
                // Apply wind effect
                let windEffect = SIMD3<Float>(windDirection.x, 0, windDirection.y) * windSpeed * 0.01
                particle.velocity += windEffect * deltaTime
                
                // Apply gravity for spray particles
                if particle.type == 1 { // spray
                    particle.velocity.y -= 9.8 * deltaTime
                }
                
                // Fade out over lifetime
                let lifeFactor = particle.life / 5.0 // Assume 5 second max life
                particle.color.w = lifeFactor
                
                particleData[activeParticles] = particle
                activeParticles += 1
            }
        }
        
        particleCount = activeParticles
        
        // Generate new particles based on weather and disasters
        generateWeatherParticles(particleData: particleData, deltaTime: deltaTime)
        generateDisasterParticles(particleData: particleData, deltaTime: deltaTime)
    }
    
    private func generateWeatherParticles(particleData: UnsafeMutablePointer<Particle>, deltaTime: Float) {
        let particleGenRate = Int(weatherIntensity * 100 * deltaTime)
        
        for _ in 0..<min(particleGenRate, maxParticles - particleCount) {
            let particle = Particle(
                position: SIMD3<Float>(
                    Float.random(in: -oceanSize/2...oceanSize/2),
                    Float.random(in: 5...20),
                    Float.random(in: -oceanSize/2...oceanSize/2)
                ),
                velocity: SIMD3<Float>(
                    windDirection.x * windSpeed * 0.1,
                    Float.random(in: -2...0),
                    windDirection.y * windSpeed * 0.1
                ),
                life: Float.random(in: 2...8),
                size: Float.random(in: 0.1...0.5),
                color: getParticleColor(for: currentWeather),
                type: getParticleType(for: currentWeather)
            )
            
            particleData[particleCount] = particle
            particleCount += 1
        }
    }
    
    private func generateDisasterParticles(particleData: UnsafeMutablePointer<Particle>, deltaTime: Float) {
        for disaster in activeDisasters {
            let particleGenRate = Int(disaster.intensity * 50 * deltaTime)
            
            for _ in 0..<min(particleGenRate, maxParticles - particleCount) {
                let offset = SIMD3<Float>(
                    Float.random(in: -disaster.radius...disaster.radius),
                    Float.random(in: 0...disaster.radius),
                    Float.random(in: -disaster.radius...disaster.radius)
                )
                
                let particle = Particle(
                    position: disaster.position + offset,
                    velocity: getDisasterParticleVelocity(for: disaster),
                    life: Float.random(in: 1...5),
                    size: Float.random(in: 0.2...1.0),
                    color: disaster.color,
                    type: getDisasterParticleType(for: disaster.type)
                )
                
                particleData[particleCount] = particle
                particleCount += 1
            }
        }
    }
    
    private func renderOcean(in renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setRenderPipelineState(oceanRenderPipeline)
        renderEncoder.setVertexBuffer(oceanVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(waveBuffer, offset: 0, index: 2)
        
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(heightmapTexture, index: 0)
        renderEncoder.setFragmentTexture(normalTexture, index: 1)
        renderEncoder.setFragmentTexture(foamTexture, index: 2)
        renderEncoder.setFragmentTexture(causticTexture, index: 3)
        renderEncoder.setFragmentTexture(skyboxTexture, index: 4)
        
        let indexCount = oceanResolution * oceanResolution * 6
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: oceanIndexBuffer,
            indexBufferOffset: 0
        )
    }
    
    private func renderParticles(in renderEncoder: MTLRenderCommandEncoder) {
        guard particleCount > 0 else { return }
        
        renderEncoder.setRenderPipelineState(particleRenderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
    }
    
    private func renderDisasterEffects(in renderEncoder: MTLRenderCommandEncoder) {
        guard !activeDisasters.isEmpty else { return }
        
        // Update disaster buffer
        guard let disasterData = disasterBuffer.contents().bindMemory(to: DisasterEffect.self, capacity: 10) else {
            return
        }
        
        for (index, disaster) in activeDisasters.enumerated() {
            disasterData[index] = disaster
        }
        
        renderEncoder.setRenderPipelineState(disasterEffectPipeline)
        renderEncoder.setVertexBuffer(disasterBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Render each disaster as a quad with special effects
        for disaster in activeDisasters {
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }
    
    // MARK: - Public Interface
    
    public func setWeather(_ weather: WeatherType, intensity: Float) {
        currentWeather = weather
        weatherIntensity = max(0.0, min(1.0, intensity))
        
        // Adjust ocean parameters based on weather
        switch weather {
        case .clear:
            waveAmplitude = 0.5
            windSpeed = 5.0
        case .cloudy:
            waveAmplitude = 0.8
            windSpeed = 10.0
        case .storm:
            waveAmplitude = 2.0
            windSpeed = 25.0
        case .hurricane:
            waveAmplitude = 4.0
            windSpeed = 50.0
        case .fog:
            waveAmplitude = 0.3
            windSpeed = 3.0
        case .rain:
            waveAmplitude = 1.0
            windSpeed = 15.0
        }
    }
    
    public func addDisasterEffect(_ effect: DisasterEffect) {
        activeDisasters.append(effect)
        
        // Limit number of active disasters
        if activeDisasters.count > 10 {
            activeDisasters.removeFirst()
        }
    }
    
    public func updateDisasters(deltaTime: Float) {
        // Update disaster timers
        for i in (0..<activeDisasters.count).reversed() {
            activeDisasters[i].remainingTime -= deltaTime
            
            if activeDisasters[i].remainingTime <= 0 {
                activeDisasters.remove(at: i)
            }
        }
    }
    
    public func setWindDirection(_ direction: SIMD2<Float>) {
        windDirection = normalize(direction)
    }
    
    public func setStormCenter(_ center: SIMD3<Float>) {
        stormCenter = center
    }
    
    // MARK: - Helper Functions
    
    private func perlinNoise(_ x: Float, _ y: Float) -> Float {
        // Simplified Perlin noise implementation
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        
        let xf = x - floor(x)
        let yf = y - floor(y)
        
        let u = fade(xf)
        let v = fade(yf)
        
        let aa = hash(xi) + yi
        let ab = hash(xi) + yi + 1
        let ba = hash(xi + 1) + yi
        let bb = hash(xi + 1) + yi + 1
        
        let x1 = lerp(grad(hash(aa), xf, yf), grad(hash(ba), xf - 1, yf), u)
        let x2 = lerp(grad(hash(ab), xf, yf - 1), grad(hash(bb), xf - 1, yf - 1), u)
        
        return lerp(x1, x2, v)
    }
    
    private func fade(_ t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + t * (b - a)
    }
    
    private func grad(_ hash: Int, _ x: Float, _ y: Float) -> Float {
        let h = hash & 3
        let u = h < 2 ? x : y
        let v = h < 2 ? y : x
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
    
    private func hash(_ x: Int) -> Int {
        var h = x
        h = h ^ (h >> 16)
        h = h &* 0x85ebca6b
        h = h ^ (h >> 13)
        h = h &* 0xc2b2ae35
        h = h ^ (h >> 16)
        return h & 255
    }
    
    private func mix(_ a: Int, _ b: Int, _ t: Float) -> Float {
        return Float(a) * (1 - t) + Float(b) * t
    }
    
    private func getParticleColor(for weather: WeatherType) -> SIMD4<Float> {
        switch weather {
        case .rain: return SIMD4<Float>(0.8, 0.9, 1.0, 0.6)
        case .storm: return SIMD4<Float>(0.6, 0.7, 0.8, 0.8)
        case .fog: return SIMD4<Float>(0.9, 0.9, 0.9, 0.4)
        default: return SIMD4<Float>(1.0, 1.0, 1.0, 0.7)
        }
    }
    
    private func getParticleType(for weather: WeatherType) -> Int32 {
        switch weather {
        case .rain, .storm: return 2 // rain
        case .fog: return 3 // fog
        default: return 1 // spray
        }
    }
    
    private func getDisasterParticleVelocity(for disaster: DisasterEffect) -> SIMD3<Float> {
        switch disaster.type {
        case .hurricane:
            let angle = Float.random(in: 0...2*Float.pi)
            let speed = disaster.intensity * 20.0
            return SIMD3<Float>(cos(angle) * speed, Float.random(in: -5...5), sin(angle) * speed)
        case .tsunami:
            return SIMD3<Float>(0, 0, disaster.intensity * 30.0)
        case .fire:
            return SIMD3<Float>(Float.random(in: -2...2), disaster.intensity * 10.0, Float.random(in: -2...2))
        default:
            return SIMD3<Float>(Float.random(in: -5...5), Float.random(in: -2...2), Float.random(in: -5...5))
        }
    }
    
    private func getDisasterParticleType(for disasterType: DisasterEffectComponent.DisasterType) -> Int32 {
        switch disasterType {
        case .fire: return 3 // smoke
        case .tsunami, .flooding: return 1 // spray
        default: return 0 // foam
        }
    }
}