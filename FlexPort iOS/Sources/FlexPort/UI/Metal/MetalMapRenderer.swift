import SwiftUI
import MetalKit
import simd
import CoreLocation

class MetalMapRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    // Multiple pipeline states for different rendering passes
    var worldMapPipelineState: MTLRenderPipelineState!
    var oceanPipelineState: MTLRenderPipelineState!
    var portPipelineState: MTLRenderPipelineState!
    var routePipelineState: MTLRenderPipelineState!
    var particlePipelineState: MTLRenderPipelineState!
    
    // Buffers
    var worldVertexBuffer: MTLBuffer!
    var worldIndexBuffer: MTLBuffer!
    var oceanVertexBuffer: MTLBuffer!
    var oceanIndexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var lightingUniformBuffer: MTLBuffer!
    var oceanUniformBuffer: MTLBuffer!
    
    // Textures for photorealistic rendering
    var earthTexture: MTLTexture!
    var normalMapTexture: MTLTexture!
    var specularMapTexture: MTLTexture!
    var nightLightsTexture: MTLTexture!
    var cloudTexture: MTLTexture!
    var foamTexture: MTLTexture!
    var waterNormalTexture: MTLTexture!
    
    // Transform matrices
    var modelMatrix = matrix_identity_float4x4
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    
    // Camera and interaction
    var cameraPosition = SIMD3<Float>(0, 5, 5)
    var zoom: Float = 1.0
    var pan = SIMD2<Float>(0, 0)
    var rotation = SIMD3<Float>(0, 0, 0)
    
    // Animation and time
    var startTime: CFTimeInterval = 0
    var currentTime: Float = 0
    
    // Rendering parameters
    var enableRealtimeLighting = true
    var enableOceanWaves = true
    var enableParticleEffects = true
    var renderQuality: RenderQuality = .high
    
    // Port locations and data
    var ports: [EnhancedPort] = []
    var selectedPorts: Set<UUID> = []
    var tradeRoutes: [TradeRouteVisualization] = []
    var ships: [ShipVisualization] = []
    
    // MARK: - Vertex Structures
    
    struct WorldVertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
        var texCoords: SIMD2<Float>
        var normal: SIMD3<Float>
    }
    
    struct OceanVertex {
        var position: SIMD3<Float>
        var texCoords: SIMD2<Float>
    }
    
    struct PortVertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var texCoords: SIMD2<Float>
        var color: SIMD4<Float>
    }
    
    // MARK: - Uniform Structures
    
    struct Uniforms {
        var modelViewProjectionMatrix: float4x4
        var modelMatrix: float4x4
        var viewMatrix: float4x4
        var projectionMatrix: float4x4
        var cameraPosition: SIMD3<Float>
        var time: Float
        var zoom: Float
        var pan: SIMD2<Float>
    }
    
    struct LightingUniforms {
        var sunDirection: SIMD3<Float>
        var sunColor: SIMD3<Float>
        var sunIntensity: Float
        var ambientColor: SIMD3<Float>
        var ambientIntensity: Float
        var timeOfDay: Float
    }
    
    struct OceanUniforms {
        var waveHeight: Float
        var waveSpeed: Float
        var waveFrequency: Float
        var foam: Float
        var shallowColor: SIMD3<Float>
        var deepColor: SIMD3<Float>
        var transparency: Float
    }
    
    // MARK: - Enhanced Data Structures
    
    struct EnhancedPort {
        var id: UUID
        var location: Coordinates
        var name: String
        var type: PortType
        var facilities: Set<PortFacility>
        var importance: Float
        var activity: Float
        var visualScale: Float
        
        var normalizedPosition: SIMD2<Float> {
            let x = Float((location.longitude + 180) / 360)
            let y = Float((location.latitude + 90) / 180)
            return SIMD2<Float>(x * 2 - 1, y * 2 - 1)
        }
        
        var worldPosition: SIMD3<Float> {
            let pos = normalizedPosition
            return SIMD3<Float>(pos.x, 0, pos.y)
        }
    }
    
    struct TradeRouteVisualization {
        var id: UUID
        var startPort: UUID
        var endPort: UUID
        var waypoints: [SIMD3<Float>]
        var commodity: String
        var activity: Float
        var color: SIMD3<Float>
    }
    
    struct ShipVisualization {
        var id: UUID
        var position: SIMD3<Float>
        var destination: SIMD3<Float>
        var progress: Float
        var shipType: ShipType
        var scale: Float
        var trailParticles: [ParticleData]
    }
    
    struct ParticleData {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var life: Float
        var size: Float
        var color: SIMD4<Float>
    }
    
    enum RenderQuality {
        case low, medium, high, ultra
        
        var tessellationLevel: Int {
            switch self {
            case .low: return 32
            case .medium: return 64
            case .high: return 128
            case .ultra: return 256
            }
        }
    }
    
    enum ShipType {
        case container
        case bulk
        case tanker
        case general
        
        var modelScale: Float {
            switch self {
            case .container: return 1.2
            case .bulk: return 1.1
            case .tanker: return 1.0
            case .general: return 0.9
            }
        }
    }
    
    override init() {
        super.init()
        setupMetal()
        loadPortData()
        loadTextures()
        setupInitialScene()
        startTime = CACurrentMediaTime()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        createPipelineStates()
        createBuffers()
    }
    
    private func createPipelineStates() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load Metal library")
        }
        
        // World Map Pipeline
        worldMapPipelineState = createPipelineState(
            library: library,
            vertexFunction: "mapVertexShader",
            fragmentFunction: "mapFragmentShader"
        )
        
        // Ocean Pipeline
        oceanPipelineState = createPipelineState(
            library: library,
            vertexFunction: "oceanVertexShader",
            fragmentFunction: "oceanFragmentShader"
        )
        
        // Port Visualization Pipeline
        portPipelineState = createPipelineState(
            library: library,
            vertexFunction: "portVertexShader",
            fragmentFunction: "portFragmentShader"
        )
        
        // Trade Route Pipeline
        routePipelineState = createPipelineState(
            library: library,
            vertexFunction: "routeVertexShader",
            fragmentFunction: "routeFragmentShader"
        )
        
        // Particle System Pipeline
        particlePipelineState = createPipelineState(
            library: library,
            vertexFunction: "particleVertexShader",
            fragmentFunction: "particleFragmentShader"
        )
    }
    
    private func createPipelineState(library: MTLLibrary, vertexFunction: String, fragmentFunction: String) -> MTLRenderPipelineState {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: vertexFunction)
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending for transparent effects
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    private func createBuffers() {
        createWorldMapBuffers()
        createOceanBuffers()
        createUniformBuffers()
    }
    
    private func createWorldMapBuffers() {
        // Create detailed world map geometry with proper UVs and normals
        let tessellation = renderQuality.tessellationLevel
        var vertices: [WorldVertex] = []
        var indices: [UInt16] = []
        
        // Generate sphere geometry for Earth
        for i in 0...tessellation {
            for j in 0...tessellation {
                let u = Float(i) / Float(tessellation)
                let v = Float(j) / Float(tessellation)
                
                let theta = u * 2.0 * Float.pi
                let phi = v * Float.pi
                
                let x = sin(phi) * cos(theta)
                let y = cos(phi)
                let z = sin(phi) * sin(theta)
                
                let position = SIMD3<Float>(x, y, z)
                let normal = normalize(position)
                let texCoords = SIMD2<Float>(u, v)
                let color = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
                
                vertices.append(WorldVertex(
                    position: position,
                    color: color,
                    texCoords: texCoords,
                    normal: normal
                ))
                
                // Generate indices for triangulation
                if i < tessellation && j < tessellation {
                    let current = UInt16(i * (tessellation + 1) + j)
                    let next = UInt16((i + 1) * (tessellation + 1) + j)
                    let nextRow = UInt16(i * (tessellation + 1) + (j + 1))
                    let nextRowNext = UInt16((i + 1) * (tessellation + 1) + (j + 1))
                    
                    indices.append(contentsOf: [current, next, nextRow, next, nextRowNext, nextRow])
                }
            }
        }
        
        worldVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<WorldVertex>.stride, options: [])
        worldIndexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }
    
    private func createOceanBuffers() {
        // Create ocean surface with detailed tessellation for waves
        let tessellation = renderQuality.tessellationLevel
        var vertices: [OceanVertex] = []
        var indices: [UInt16] = []
        
        let size: Float = 100.0
        let halfSize = size / 2.0
        
        for i in 0...tessellation {
            for j in 0...tessellation {
                let x = Float(i) / Float(tessellation) * size - halfSize
                let z = Float(j) / Float(tessellation) * size - halfSize
                let u = Float(i) / Float(tessellation)
                let v = Float(j) / Float(tessellation)
                
                vertices.append(OceanVertex(
                    position: SIMD3<Float>(x, 0, z),
                    texCoords: SIMD2<Float>(u, v)
                ))
                
                if i < tessellation && j < tessellation {
                    let current = UInt16(i * (tessellation + 1) + j)
                    let next = UInt16((i + 1) * (tessellation + 1) + j)
                    let nextRow = UInt16(i * (tessellation + 1) + (j + 1))
                    let nextRowNext = UInt16((i + 1) * (tessellation + 1) + (j + 1))
                    
                    indices.append(contentsOf: [current, next, nextRow, next, nextRowNext, nextRow])
                }
            }
        }
        
        oceanVertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<OceanVertex>.stride, options: [])
        oceanIndexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: [])
    }
    
    private func createUniformBuffers() {
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        lightingUniformBuffer = device.makeBuffer(length: MemoryLayout<LightingUniforms>.stride, options: [])
        oceanUniformBuffer = device.makeBuffer(length: MemoryLayout<OceanUniforms>.stride, options: [])
    }
    
    private func loadTextures() {
        // For now, create placeholder textures - in production these would load satellite imagery
        createPlaceholderTextures()
    }
    
    private func createPlaceholderTextures() {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1024,
            height: 512,
            mipmapped: false
        )
        
        earthTexture = device.makeTexture(descriptor: textureDescriptor)
        normalMapTexture = device.makeTexture(descriptor: textureDescriptor)
        specularMapTexture = device.makeTexture(descriptor: textureDescriptor)
        nightLightsTexture = device.makeTexture(descriptor: textureDescriptor)
        cloudTexture = device.makeTexture(descriptor: textureDescriptor)
        foamTexture = device.makeTexture(descriptor: textureDescriptor)
        waterNormalTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Fill with procedural data
        fillPlaceholderTextureData()
    }
    
    private func fillPlaceholderTextureData() {
        // Generate basic earth-like colors and patterns
        let width = 1024
        let height = 512
        var earthData = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let lat = Float(y) / Float(height) * Float.pi - Float.pi/2
                let lon = Float(x) / Float(width) * 2 * Float.pi - Float.pi
                
                // Simple land/water distinction
                let isLand = (abs(lat) < 1.0 && (abs(lon) < 0.5 || abs(lon - Float.pi) < 1.0))
                
                if isLand {
                    earthData[index] = 139  // Brown
                    earthData[index + 1] = 111
                    earthData[index + 2] = 78
                } else {
                    earthData[index] = 65   // Blue
                    earthData[index + 1] = 105
                    earthData[index + 2] = 225
                }
                earthData[index + 3] = 255
            }
        }
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
        earthTexture.replace(region: region, mipmapLevel: 0, withBytes: earthData, bytesPerRow: width * 4)
    }
    
    private func setupInitialScene() {
        // Setup camera
        updateCameraMatrices()
        
        // Initialize lighting
        updateLighting()
        
        // Initialize ocean parameters
        updateOceanParameters()
    }
    
    // MARK: - Camera and Transform Updates
    
    private func updateCameraMatrices() {
        // Model matrix
        modelMatrix = matrix4x4_rotation(radians: rotation.x, axis: SIMD3<Float>(1, 0, 0)) *
                     matrix4x4_rotation(radians: rotation.y, axis: SIMD3<Float>(0, 1, 0)) *
                     matrix4x4_rotation(radians: rotation.z, axis: SIMD3<Float>(0, 0, 1))
        
        // View matrix
        let target = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        viewMatrix = matrix_look_at(eye: cameraPosition, center: target, up: up)
    }
    
    private func updateLighting() {
        // Dynamic sun lighting based on time of day
        let timeOfDay = sin(currentTime * 0.1) * 0.5 + 0.5
        let sunAngle = timeOfDay * Float.pi
        
        var lighting = LightingUniforms(
            sunDirection: SIMD3<Float>(cos(sunAngle), sin(sunAngle), 0.3),
            sunColor: SIMD3<Float>(1.0, 0.95, 0.8),
            sunIntensity: 0.8,
            ambientColor: SIMD3<Float>(0.3, 0.4, 0.6),
            ambientIntensity: 0.2,
            timeOfDay: timeOfDay
        )
        
        lightingUniformBuffer.contents().copyMemory(from: &lighting, byteCount: MemoryLayout<LightingUniforms>.stride)
    }
    
    private func updateOceanParameters() {
        var ocean = OceanUniforms(
            waveHeight: 0.5,
            waveSpeed: 2.0,
            waveFrequency: 0.8,
            foam: 0.7,
            shallowColor: SIMD3<Float>(0.4, 0.8, 0.9),
            deepColor: SIMD3<Float>(0.1, 0.3, 0.6),
            transparency: 0.7
        )
        
        oceanUniformBuffer.contents().copyMemory(from: &ocean, byteCount: MemoryLayout<OceanUniforms>.stride)
    }
    
    private func loadPortData() {
        // Enhanced major world ports with detailed visualization data
        ports = [
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 22.3964, longitude: 114.1095),
                name: "Hong Kong",
                type: .sea,
                facilities: [.containerTerminal, .pilotage, .bunkerFueling],
                importance: 1.0,
                activity: 0.9,
                visualScale: 1.2
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 1.2897, longitude: 103.8501),
                name: "Singapore",
                type: .multimodal,
                facilities: [.containerTerminal, .liquidBulkTerminal, .bunkerFueling, .drydock],
                importance: 1.0,
                activity: 1.0,
                visualScale: 1.3
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 31.2304, longitude: 121.4737),
                name: "Shanghai",
                type: .sea,
                facilities: [.containerTerminal, .bulkTerminal],
                importance: 0.95,
                activity: 0.95,
                visualScale: 1.1
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 51.5074, longitude: -0.0278),
                name: "London",
                type: .multimodal,
                facilities: [.containerTerminal, .roroTerminal],
                importance: 0.8,
                activity: 0.7,
                visualScale: 1.0
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 40.7128, longitude: -74.0060),
                name: "New York",
                type: .multimodal,
                facilities: [.containerTerminal, .cruiseTerminal],
                importance: 0.9,
                activity: 0.8,
                visualScale: 1.1
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 33.7490, longitude: -118.2923),
                name: "Los Angeles",
                type: .sea,
                facilities: [.containerTerminal, .roroTerminal],
                importance: 0.85,
                activity: 0.8,
                visualScale: 1.0
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 51.8985, longitude: 4.4813),
                name: "Rotterdam",
                type: .sea,
                facilities: [.containerTerminal, .liquidBulkTerminal, .bulkTerminal],
                importance: 0.9,
                activity: 0.85,
                visualScale: 1.1
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 25.7617, longitude: -80.1918),
                name: "Miami",
                type: .sea,
                facilities: [.containerTerminal, .cruiseTerminal],
                importance: 0.6,
                activity: 0.7,
                visualScale: 0.8
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: -33.8688, longitude: 151.2093),
                name: "Sydney",
                type: .sea,
                facilities: [.containerTerminal, .cruiseTerminal],
                importance: 0.7,
                activity: 0.6,
                visualScale: 0.9
            ),
            EnhancedPort(
                id: UUID(),
                location: Coordinates(latitude: 35.6762, longitude: 139.6503),
                name: "Tokyo",
                type: .sea,
                facilities: [.containerTerminal, .bulkTerminal],
                importance: 0.85,
                activity: 0.8,
                visualScale: 1.0
            )
        ]
        
        // Create sample trade routes
        createSampleTradeRoutes()
        
        // Create sample ships
        createSampleShips()
    }
    
    private func createSampleTradeRoutes() {
        guard ports.count >= 2 else { return }
        
        // Hong Kong to Los Angeles
        if let hongKong = ports.first(where: { $0.name == "Hong Kong" }),
           let losAngeles = ports.first(where: { $0.name == "Los Angeles" }) {
            
            let route = TradeRouteVisualization(
                id: UUID(),
                startPort: hongKong.id,
                endPort: losAngeles.id,
                waypoints: generateRouteWaypoints(from: hongKong.worldPosition, to: losAngeles.worldPosition),
                commodity: "Electronics",
                activity: 0.8,
                color: SIMD3<Float>(0.2, 0.8, 1.0)
            )
            tradeRoutes.append(route)
        }
        
        // Singapore to Rotterdam
        if let singapore = ports.first(where: { $0.name == "Singapore" }),
           let rotterdam = ports.first(where: { $0.name == "Rotterdam" }) {
            
            let route = TradeRouteVisualization(
                id: UUID(),
                startPort: singapore.id,
                endPort: rotterdam.id,
                waypoints: generateRouteWaypoints(from: singapore.worldPosition, to: rotterdam.worldPosition),
                commodity: "Oil",
                activity: 0.9,
                color: SIMD3<Float>(1.0, 0.5, 0.2)
            )
            tradeRoutes.append(route)
        }
    }
    
    private func generateRouteWaypoints(from start: SIMD3<Float>, to end: SIMD3<Float>) -> [SIMD3<Float>] {
        var waypoints: [SIMD3<Float>] = []
        let segments = 20
        
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let position = mix(start, end, t)
            waypoints.append(position)
        }
        
        return waypoints
    }
    
    private func createSampleShips() {
        for i in 0..<5 {
            let randomRoute = tradeRoutes.randomElement()
            let ship = ShipVisualization(
                id: UUID(),
                position: SIMD3<Float>(Float.random(in: -1...1), 0, Float.random(in: -1...1)),
                destination: SIMD3<Float>(Float.random(in: -1...1), 0, Float.random(in: -1...1)),
                progress: Float.random(in: 0...1),
                shipType: ShipType.allCases.randomElement() ?? .container,
                scale: Float.random(in: 0.8...1.2),
                trailParticles: []
            )
            ships.append(ship)
        }
    }
    
    func updateTransform(aspectRatio: Float) {
        let scaledZoom = max(0.1, min(50.0, zoom))
        
        // Update camera position based on zoom and pan
        let distance = 5.0 / scaledZoom
        cameraPosition = SIMD3<Float>(
            pan.x * distance,
            distance,
            pan.y * distance
        )
        
        // Create perspective projection
        projectionMatrix = matrix_perspective_right_hand(
            fovyRadians: Float.pi / 4,
            aspectRatio: aspectRatio,
            nearZ: 0.1,
            farZ: 1000.0
        )
        
        updateCameraMatrices()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspectRatio = Float(size.width / size.height)
        updateTransform(aspectRatio: aspectRatio)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Update time for animations
        currentTime = Float(CACurrentMediaTime() - startTime)
        
        // Clear to deep space color
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        
        // Update uniforms
        updateUniforms()
        updateLighting()
        updateOceanParameters()
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Render world map
        renderWorldMap(encoder: renderEncoder)
        
        // Render ocean with waves
        if enableOceanWaves {\n            renderOcean(encoder: renderEncoder)\n        }\n        \n        // Render ports\n        renderPorts(encoder: renderEncoder)\n        \n        // Render trade routes\n        renderTradeRoutes(encoder: renderEncoder)\n        \n        // Render ships\n        renderShips(encoder: renderEncoder)\n        \n        // Render particle effects\n        if enableParticleEffects {\n            renderParticles(encoder: renderEncoder)\n        }\n        \n        renderEncoder.endEncoding()\n        commandBuffer.present(drawable)\n        commandBuffer.commit()\n    }\n    \n    private func updateUniforms() {\n        let mvpMatrix = projectionMatrix * viewMatrix * modelMatrix\n        \n        var uniforms = Uniforms(\n            modelViewProjectionMatrix: mvpMatrix,\n            modelMatrix: modelMatrix,\n            viewMatrix: viewMatrix,\n            projectionMatrix: projectionMatrix,\n            cameraPosition: cameraPosition,\n            time: currentTime,\n            zoom: zoom,\n            pan: pan\n        )\n        \n        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<Uniforms>.stride)\n    }\n    \n    private func renderWorldMap(encoder: MTLRenderCommandEncoder) {\n        encoder.setRenderPipelineState(worldMapPipelineState)\n        encoder.setVertexBuffer(worldVertexBuffer, offset: 0, index: 0)\n        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)\n        encoder.setFragmentBuffer(lightingUniformBuffer, offset: 0, index: 2)\n        \n        // Set textures\n        encoder.setFragmentTexture(earthTexture, index: 0)\n        encoder.setFragmentTexture(normalMapTexture, index: 1)\n        encoder.setFragmentTexture(specularMapTexture, index: 2)\n        encoder.setFragmentTexture(nightLightsTexture, index: 3)\n        encoder.setFragmentTexture(cloudTexture, index: 4)\n        \n        let indexCount = (renderQuality.tessellationLevel * renderQuality.tessellationLevel * 6)\n        encoder.drawIndexedPrimitives(\n            type: .triangle,\n            indexCount: indexCount,\n            indexType: .uint16,\n            indexBuffer: worldIndexBuffer,\n            indexBufferOffset: 0\n        )\n    }\n    \n    private func renderOcean(encoder: MTLRenderCommandEncoder) {\n        encoder.setRenderPipelineState(oceanPipelineState)\n        encoder.setVertexBuffer(oceanVertexBuffer, offset: 0, index: 0)\n        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)\n        encoder.setVertexBuffer(oceanUniformBuffer, offset: 0, index: 2)\n        encoder.setFragmentBuffer(lightingUniformBuffer, offset: 0, index: 2)\n        encoder.setFragmentBuffer(oceanUniformBuffer, offset: 0, index: 3)\n        \n        encoder.setFragmentTexture(foamTexture, index: 0)\n        encoder.setFragmentTexture(waterNormalTexture, index: 1)\n        \n        let indexCount = (renderQuality.tessellationLevel * renderQuality.tessellationLevel * 6)\n        encoder.drawIndexedPrimitives(\n            type: .triangle,\n            indexCount: indexCount,\n            indexType: .uint16,\n            indexBuffer: oceanIndexBuffer,\n            indexBufferOffset: 0\n        )\n    }\n    \n    private func renderPorts(encoder: MTLRenderCommandEncoder) {\n        // Render port visualizations as 3D models\n        for port in ports {\n            renderPort(port, encoder: encoder)\n        }\n    }\n    \n    private func renderPort(_ port: EnhancedPort, encoder: MTLRenderCommandEncoder) {\n        // Create simple port geometry on the fly\n        let scale = port.visualScale * (selectedPorts.contains(port.id) ? 1.5 : 1.0)\n        let height = port.importance * 0.2 + 0.1\n        \n        // Animate port activity\n        let activityPulse = sin(currentTime * 3.0 + Float(port.id.hashValue % 100)) * 0.1 + 0.9\n        let intensity = port.activity * activityPulse\n        \n        // Port color based on type and activity\n        let baseColor = getPortColor(type: port.type)\n        let color = SIMD4<Float>(baseColor.x * intensity, baseColor.y * intensity, baseColor.z * intensity, 1.0)\n        \n        // For now, render as simple colored cubes - in production would use detailed 3D models\n        // This would be replaced with actual port infrastructure models\n    }\n    \n    private func getPortColor(type: PortType) -> SIMD3<Float> {\n        switch type {\n        case .sea: return SIMD3<Float>(0.2, 0.6, 1.0)\n        case .air: return SIMD3<Float>(1.0, 0.8, 0.2)\n        case .rail: return SIMD3<Float>(0.8, 0.4, 0.2)\n        case .multimodal: return SIMD3<Float>(0.8, 0.2, 0.8)\n        default: return SIMD3<Float>(0.6, 0.6, 0.6)\n        }\n    }\n    \n    private func renderTradeRoutes(encoder: MTLRenderCommandEncoder) {\n        encoder.setRenderPipelineState(routePipelineState)\n        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)\n        \n        for route in tradeRoutes {\n            renderTradeRoute(route, encoder: encoder)\n        }\n    }\n    \n    private func renderTradeRoute(_ route: TradeRouteVisualization, encoder: MTLRenderCommandEncoder) {\n        // Render animated trade route lines\n        // Implementation would create line geometry from waypoints and render with animation\n    }\n    \n    private func renderShips(encoder: MTLRenderCommandEncoder) {\n        for ship in ships {\n            renderShip(ship, encoder: encoder)\n        }\n    }\n    \n    private func renderShip(_ ship: ShipVisualization, encoder: MTLRenderCommandEncoder) {\n        // Render ship models with wake trails\n        // Implementation would use detailed ship models and particle trails\n    }\n    \n    private func renderParticles(encoder: MTLRenderCommandEncoder) {\n        encoder.setRenderPipelineState(particlePipelineState)\n        // Render all particle systems\n    }
    
    private func orthographicProjectionMatrix(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> float4x4 {
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = farZ + nearZ
        let fsn = farZ - nearZ
        
        return float4x4(
            SIMD4<Float>(2.0 / rsl, 0.0, 0.0, 0.0),
            SIMD4<Float>(0.0, 2.0 / tsb, 0.0, 0.0),
            SIMD4<Float>(0.0, 0.0, -2.0 / fsn, 0.0),
            SIMD4<Float>(-ral / rsl, -tab / tsb, -fan / fsn, 1.0)
        )
    }
}