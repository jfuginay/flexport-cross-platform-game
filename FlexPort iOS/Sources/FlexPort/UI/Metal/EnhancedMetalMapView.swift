import SwiftUI
import MetalKit
import simd

struct EnhancedMetalMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedPort: String?
    @State private var showingPortDetails = false
    @State private var renderMode: RenderMode = .satellite
    @State private var timeOfDay: Double = 0.5 // 0-1, where 0.5 is noon
    @State private var weatherEnabled = true
    
    enum RenderMode: String, CaseIterable {
        case satellite = "Satellite"
        case terrain = "Terrain"
        case economic = "Economic"
        case weather = "Weather"
    }
    
    var body: some View {
        ZStack {
            // Metal-rendered world map
            MetalWorldMapView(
                zoom: $zoom,
                offset: $offset,
                renderMode: $renderMode,
                timeOfDay: $timeOfDay,
                weatherEnabled: $weatherEnabled
            ) { portName in
                selectedPort = portName
                showingPortDetails = true
                HapticManager.shared.impact(.medium)
            }
            
            // Overlay UI elements
            VStack {
                // Top controls
                HStack {
                    // Map controls
                    VStack(spacing: 10) {
                        Button(action: { 
                            withAnimation(.spring()) {
                                zoom = min(zoom * 1.5, 10.0)
                            }
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        
                        Button(action: { 
                            withAnimation(.spring()) {
                                zoom = max(zoom * 0.7, 0.5)
                            }
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        
                        Button(action: { 
                            withAnimation(.spring()) {
                                zoom = 1.0
                                offset = .zero
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Render mode selector
                    VStack(spacing: 10) {
                        Picker("View Mode", selection: $renderMode) {
                            ForEach(RenderMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 200)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        
                        // Weather toggle
                        Toggle(isOn: $weatherEnabled) {
                            Label("Weather", systemImage: weatherEnabled ? "cloud.rain.fill" : "sun.max.fill")
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(maxWidth: 150)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Ship count and stats
                    VStack(alignment: .trailing, spacing: 8) {
                        Label("\(gameManager.gameState.playerAssets.ships.count)", systemImage: "ferry.fill")
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        
                        Label("$\(Int(gameManager.gameState.playerAssets.money))", systemImage: "dollarsign.circle.fill")
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Day/night cycle slider
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundColor(.orange)
                    
                    Slider(value: $timeOfDay, in: 0...1)
                        .frame(maxWidth: 300)
                        .accentColor(.yellow)
                    
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.bottom, 20)
                
                // Trade route creation hint
                if gameManager.gameState.tradeRoutes.isEmpty {
                    Text("Tap on ports to create trade routes")
                        .padding(12)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }
            }
            
            // Minimap
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MinimapView(mainZoom: $zoom, mainOffset: $offset)
                        .frame(width: 150, height: 100)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingPortDetails) {
            if let port = selectedPort {
                PortDetailsView(portName: port, gameManager: gameManager)
            }
        }
    }
}

// Minimap view
struct MinimapView: View {
    @Binding var mainZoom: CGFloat
    @Binding var mainOffset: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Simple world representation
                Canvas { context, size in
                    // Ocean
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.blue.opacity(0.3)))
                    
                    // Continents (simplified)
                    let continents = [
                        CGRect(x: size.width * 0.1, y: size.height * 0.2, width: size.width * 0.2, height: size.height * 0.3), // Americas
                        CGRect(x: size.width * 0.45, y: size.height * 0.15, width: size.width * 0.15, height: size.height * 0.4), // Africa/Europe
                        CGRect(x: size.width * 0.65, y: size.height * 0.1, width: size.width * 0.3, height: size.height * 0.5), // Asia
                        CGRect(x: size.width * 0.75, y: size.height * 0.7, width: size.width * 0.15, height: size.height * 0.2) // Australia
                    ]
                    
                    for continent in continents {
                        context.fill(Path(continent), with: .color(.green.opacity(0.5)))
                    }
                    
                    // Viewport indicator
                    let viewportWidth = size.width / mainZoom
                    let viewportHeight = size.height / mainZoom
                    let viewportX = size.width / 2 - mainOffset.width / 10 / mainZoom
                    let viewportY = size.height / 2 - mainOffset.height / 10 / mainZoom
                    
                    let viewport = CGRect(
                        x: viewportX - viewportWidth / 2,
                        y: viewportY - viewportHeight / 2,
                        width: viewportWidth,
                        height: viewportHeight
                    )
                    
                    context.stroke(Path(viewport), with: .color(.yellow), lineWidth: 2)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                // Jump to tapped location
                let normalizedX = (location.x / geometry.size.width - 0.5) * 10
                let normalizedY = (location.y / geometry.size.height - 0.5) * 10
                
                withAnimation(.spring()) {
                    mainOffset = CGSize(width: normalizedX * 100, height: normalizedY * 100)
                }
                
                HapticManager.shared.impact(.light)
            }
        }
    }
}

// The actual Metal rendering view
struct MetalWorldMapView: UIViewRepresentable {
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @Binding var renderMode: EnhancedMetalMapView.RenderMode
    @Binding var timeOfDay: Double
    @Binding var weatherEnabled: Bool
    let onPortTapped: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        
        context.coordinator.renderer = EnhancedMapRenderer(device: device)
        mtkView.delegate = context.coordinator.renderer
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        
        // Add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        
        tapGesture.require(toFail: doubleTapGesture)
        
        mtkView.addGestureRecognizer(panGesture)
        mtkView.addGestureRecognizer(pinchGesture)
        mtkView.addGestureRecognizer(tapGesture)
        mtkView.addGestureRecognizer(doubleTapGesture)
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.zoom = Float(zoom)
        context.coordinator.renderer?.pan = SIMD2<Float>(Float(offset.width / 100), Float(offset.height / 100))
        context.coordinator.renderer?.dayNightCycle = Float(timeOfDay)
        context.coordinator.renderer?.weatherIntensity = weatherEnabled ? 1.0 : 0.0
        context.coordinator.renderer?.renderMode = renderMode
    }
    
    class Coordinator: NSObject {
        var parent: MetalWorldMapView
        var renderer: EnhancedMapRenderer?
        private var lastPanLocation: CGPoint = .zero
        
        init(_ parent: MetalWorldMapView) {
            self.parent = parent
            super.init()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            
            if gesture.state == .changed {
                parent.offset.width += translation.width
                parent.offset.height += translation.height
                gesture.setTranslation(.zero, in: gesture.view)
                
                // Add momentum-based scrolling
                if gesture.state == .ended {
                    let velocity = gesture.velocity(in: gesture.view)
                    withAnimation(.easeOut(duration: 0.3)) {
                        parent.offset.width += velocity.x * 0.1
                        parent.offset.height += velocity.y * 0.1
                    }
                }
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                parent.zoom *= gesture.scale
                parent.zoom = max(0.5, min(10.0, parent.zoom))
                gesture.scale = 1.0
                
                HapticManager.shared.impact(.light)
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view,
                  let renderer = renderer else { return }
            
            let location = gesture.location(in: view)
            let normalizedLocation = CGPoint(
                x: location.x / view.bounds.width,
                y: location.y / view.bounds.height
            )
            
            if let port = renderer.getPortAt(normalizedLocation) {
                parent.onPortTapped(port)
            }
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let centerX = view.bounds.width / 2
            let centerY = view.bounds.height / 2
            
            // Calculate offset to center on tapped location
            let offsetX = (location.x - centerX) * 2
            let offsetY = (location.y - centerY) * 2
            
            withAnimation(.spring()) {
                parent.zoom = min(parent.zoom * 2, 10.0)
                parent.offset.width -= offsetX
                parent.offset.height -= offsetY
            }
            
            HapticManager.shared.impact(.medium)
        }
    }
}

// Enhanced Metal renderer with advanced features
class EnhancedMapRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    var portBuffer: MTLBuffer?
    var shipBuffer: MTLBuffer?
    var weatherBuffer: MTLBuffer?
    
    // Render properties
    var zoom: Float = 1.0
    var pan: SIMD2<Float> = SIMD2<Float>(0, 0)
    var time: Float = 0.0
    var dayNightCycle: Float = 0.5
    var weatherIntensity: Float = 1.0
    var renderMode: EnhancedMetalMapView.RenderMode = .satellite
    
    // Port locations with real-world coordinates
    let ports: [(name: String, position: SIMD2<Float>, economicHealth: Float)] = [
        ("Singapore", SIMD2<Float>(0.73, 0.51), 0.9),
        ("Hong Kong", SIMD2<Float>(0.75, 0.38), 0.85),
        ("Shanghai", SIMD2<Float>(0.77, 0.33), 0.95),
        ("Los Angeles", SIMD2<Float>(0.18, 0.35), 0.8),
        ("New York", SIMD2<Float>(0.28, 0.28), 0.75),
        ("London", SIMD2<Float>(0.5, 0.18), 0.7),
        ("Dubai", SIMD2<Float>(0.62, 0.38), 0.88),
        ("Rotterdam", SIMD2<Float>(0.51, 0.19), 0.82),
        ("Hamburg", SIMD2<Float>(0.52, 0.17), 0.78),
        ("Tokyo", SIMD2<Float>(0.82, 0.31), 0.92),
        ("Sydney", SIMD2<Float>(0.85, 0.73), 0.65),
        ("Santos", SIMD2<Float>(0.35, 0.67), 0.6),
        ("Mumbai", SIMD2<Float>(0.65, 0.42), 0.7),
        ("Cape Town", SIMD2<Float>(0.55, 0.75), 0.55),
        ("Vancouver", SIMD2<Float>(0.15, 0.25), 0.75),
        ("Busan", SIMD2<Float>(0.78, 0.35), 0.8),
        ("Alexandria", SIMD2<Float>(0.58, 0.32), 0.65),
        ("Istanbul", SIMD2<Float>(0.57, 0.28), 0.7)
    ]
    
    // Ships for animation
    var ships: [(position: SIMD2<Float>, velocity: SIMD2<Float>, cargo: Float, type: Float)] = []
    
    // Weather systems
    var weatherSystems: [(center: SIMD2<Float>, radius: Float, intensity: Float, type: Float)] = []
    
    // Uniform structure matching shader
    struct Uniforms {
        var time: Float
        var zoom: Float
        var pan: SIMD2<Float>
        var screenSize: SIMD2<Float>
        var dayNightCycle: Float
        var weatherIntensity: Float
        var sunDirection: SIMD3<Float>
        var padding: Float // Padding for alignment
        var viewMatrix: float4x4
        var projectionMatrix: float4x4
    }
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        setupMetal()
        generateShips()
        generateWeatherSystems()
    }
    
    func setupMetal() {
        // Load shader library
        do {
            let library: MTLLibrary
            if let url = Bundle.main.url(forResource: "WorldMapShaders", withExtension: "metal") {
                library = try device.makeLibrary(URL: url)
            } else {
                // Fallback to default library
                library = device.makeDefaultLibrary()!
            }
            
            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_main")
            
            // Create vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()
            // Position
            vertexDescriptor.attributes[0].format = .float4
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            // TexCoord
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = 16
            vertexDescriptor.attributes[1].bufferIndex = 0
            // Normal
            vertexDescriptor.attributes[2].format = .float3
            vertexDescriptor.attributes[2].offset = 24
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.layouts[0].stride = 36
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            // Create depth stencil state
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.depthCompareFunction = .less
            depthDescriptor.isDepthWriteEnabled = true
            depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
            
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
        
        // Create vertex data for a grid mesh (for terrain elevation)
        createTerrainMesh()
        
        // Create uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])
        
        // Create port buffer
        updatePortBuffer()
        
        // Create weather buffer
        updateWeatherBuffer()
    }
    
    func createTerrainMesh() {
        let gridSize = 100
        var vertices: [Float] = []
        var indices: [UInt32] = []
        
        // Generate vertices
        for y in 0...gridSize {
            for x in 0...gridSize {
                let u = Float(x) / Float(gridSize)
                let v = Float(y) / Float(gridSize)
                
                // Position
                vertices.append((u - 0.5) * 2.0) // x
                vertices.append(0.0) // y (will be modified by elevation)
                vertices.append((v - 0.5) * 2.0) // z
                vertices.append(1.0) // w
                
                // TexCoord
                vertices.append(u)
                vertices.append(v)
                
                // Normal (pointing up, will be recalculated in shader)
                vertices.append(0.0)
                vertices.append(1.0)
                vertices.append(0.0)
            }
        }
        
        // Generate indices for triangle strips
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let topLeft = UInt32(y * (gridSize + 1) + x)
                let topRight = topLeft + 1
                let bottomLeft = topLeft + UInt32(gridSize + 1)
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
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride, options: [])
    }
    
    func generateShips() {
        ships.removeAll()
        
        // Create a diverse fleet of ships
        for i in 0..<50 {
            let startPort = ports.randomElement()!
            let endPort = ports.randomElement()!
            
            let t = Float(i) / 50.0
            let position = mix(startPort.position, endPort.position, t)
            let direction = normalize(endPort.position - startPort.position)
            let velocity = direction * (0.0005 + Float.random(in: 0...0.001))
            let cargo = Float.random(in: 0...1)
            let type = Float(Int.random(in: 0...2)) // 0: container, 1: tanker, 2: bulk
            
            ships.append((position: position, velocity: velocity, cargo: cargo, type: type))
        }
        
        updateShipBuffer()
    }
    
    func generateWeatherSystems() {
        weatherSystems.removeAll()
        
        // Create dynamic weather patterns
        for _ in 0..<5 {
            let center = SIMD2<Float>(Float.random(in: -1...1), Float.random(in: -0.8...0.8))
            let radius = Float.random(in: 0.1...0.3)
            let intensity = Float.random(in: 0.3...1.0)
            let type = Float(Int.random(in: 1...2)) // 1: storm, 2: fog
            
            weatherSystems.append((center: center, radius: radius, intensity: intensity, type: type))
        }
        
        updateWeatherBuffer()
    }
    
    func updatePortBuffer() {
        // Pack port data for shader
        var portData: [Float] = []
        for port in ports {
            portData.append(port.position.x)
            portData.append(port.position.y)
            portData.append(0.02) // size
            portData.append(Float.random(in: 0.3...1.0)) // activity
            portData.append(port.economicHealth)
            portData.append(0.0) // padding
            portData.append(0.0) // padding
            portData.append(0.0) // padding
        }
        
        portBuffer = device.makeBuffer(bytes: portData, length: portData.count * MemoryLayout<Float>.stride, options: [])
    }
    
    func updateShipBuffer() {
        // Pack ship data for shader
        var shipData: [Float] = []
        for ship in ships {
            shipData.append(ship.position.x)
            shipData.append(ship.position.y)
            shipData.append(ship.velocity.x)
            shipData.append(ship.velocity.y)
            shipData.append(0.01) // size
            shipData.append(ship.cargo)
            shipData.append(ship.type)
            shipData.append(0.0) // padding
        }
        
        if !shipData.isEmpty {
            shipBuffer = device.makeBuffer(bytes: shipData, length: shipData.count * MemoryLayout<Float>.stride, options: [])
        }
    }
    
    func updateWeatherBuffer() {
        // Pack weather data for shader
        var weatherData: [Float] = []
        for weather in weatherSystems {
            weatherData.append(weather.center.x)
            weatherData.append(weather.center.y)
            weatherData.append(weather.radius)
            weatherData.append(weather.intensity)
            weatherData.append(weather.type)
            weatherData.append(0.0) // padding
            weatherData.append(0.0) // padding
            weatherData.append(0.0) // padding
        }
        
        if !weatherData.isEmpty {
            weatherBuffer = device.makeBuffer(bytes: weatherData, length: weatherData.count * MemoryLayout<Float>.stride, options: [])
        }
    }
    
    func updateShipPositions() {
        // Update ship positions and handle routing
        for i in 0..<ships.count {
            ships[i].position += ships[i].velocity
            
            // Wrap around world
            if ships[i].position.x > 1.0 { ships[i].position.x -= 2.0 }
            if ships[i].position.x < -1.0 { ships[i].position.x += 2.0 }
            if ships[i].position.y > 1.0 { ships[i].position.y -= 2.0 }
            if ships[i].position.y < -1.0 { ships[i].position.y += 2.0 }
            
            // Check if ship reached a port
            for port in ports {
                let distance = simd_distance(ships[i].position, port.position)
                if distance < 0.02 {
                    // Ship reached port - pick new destination
                    let targetPort = ports.randomElement()!
                    let direction = normalize(targetPort.position - ships[i].position)
                    ships[i].velocity = direction * (0.0005 + Float.random(in: 0...0.001))
                    
                    // Update cargo status
                    ships[i].cargo = ships[i].cargo > 0.5 ? 0.0 : 1.0
                }
            }
        }
    }
    
    func updateWeatherSystems() {
        // Move weather systems
        for i in 0..<weatherSystems.count {
            // Weather systems drift slowly
            weatherSystems[i].center.x += sin(time * 0.1 + Float(i)) * 0.001
            weatherSystems[i].center.y += cos(time * 0.15 + Float(i) * 2) * 0.0005
            
            // Wrap around
            if weatherSystems[i].center.x > 1.5 { weatherSystems[i].center.x = -1.5 }
            if weatherSystems[i].center.x < -1.5 { weatherSystems[i].center.x = 1.5 }
            
            // Vary intensity
            weatherSystems[i].intensity = 0.5 + sin(time * 0.3 + Float(i) * 3) * 0.3
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uniformBuffer = uniformBuffer else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Update animation
        time += 0.016 // 60 FPS
        updateShipPositions()
        updateShipBuffer()
        updateWeatherSystems()
        updateWeatherBuffer()
        
        // Calculate sun direction based on day/night cycle
        let sunAngle = dayNightCycle * Float.pi
        let sunDirection = SIMD3<Float>(cos(sunAngle), sin(sunAngle) * 0.8 + 0.2, sin(sunAngle) * 0.3)
        
        // Create view and projection matrices
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = perspectiveProjection(fov: 60.0 * Float.pi / 180.0,
                                                     aspect: aspectRatio,
                                                     near: 0.1,
                                                     far: 100.0)
        
        let eye = SIMD3<Float>(0, 2, 3)
        let center = SIMD3<Float>(0, 0, 0)
        let up = SIMD3<Float>(0, 1, 0)
        let viewMatrix = lookAt(eye: eye, center: center, up: up)
        
        // Update uniforms
        var uniforms = Uniforms(
            time: time,
            zoom: zoom,
            pan: pan,
            screenSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            dayNightCycle: dayNightCycle,
            weatherIntensity: weatherIntensity,
            sunDirection: normalize(sunDirection),
            padding: 0,
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix
        )
        
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
        
        // Set buffers
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Set port data
        if let portBuffer = portBuffer {
            renderEncoder.setFragmentBuffer(portBuffer, offset: 0, index: 2)
            var portCount = UInt32(ports.count)
            renderEncoder.setFragmentBytes(&portCount, length: MemoryLayout<UInt32>.stride, index: 4)
        }
        
        // Set ship data
        if let shipBuffer = shipBuffer {
            renderEncoder.setFragmentBuffer(shipBuffer, offset: 0, index: 3)
            var shipCount = UInt32(ships.count)
            renderEncoder.setFragmentBytes(&shipCount, length: MemoryLayout<UInt32>.stride, index: 5)
        }
        
        // Set weather data
        if let weatherBuffer = weatherBuffer {
            renderEncoder.setFragmentBuffer(weatherBuffer, offset: 0, index: 6)
            var weatherCount = UInt32(weatherSystems.count)
            renderEncoder.setFragmentBytes(&weatherCount, length: MemoryLayout<UInt32>.stride, index: 7)
        }
        
        // Draw terrain mesh
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: 100 * 100 * 6,
                                          indexType: .uint32,
                                          indexBuffer: indexBuffer,
                                          indexBufferOffset: 0)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func getPortAt(_ normalizedLocation: CGPoint) -> String? {
        // Convert normalized location to world coordinates
        let worldX = (Float(normalizedLocation.x) - 0.5) / zoom + pan.x
        let worldY = (Float(normalizedLocation.y) - 0.5) / zoom + pan.y
        let worldPoint = SIMD2<Float>(worldX, worldY)
        
        // Find the nearest port
        for port in ports {
            let distance = simd_distance(worldPoint, port.position)
            if distance < 0.05 / zoom {
                return port.name
            }
        }
        
        return nil
    }
    
    // Matrix helper functions
    func perspectiveProjection(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fov * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2 * far * near / zRange
        
        return float4x4(
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        )
    }
    
    func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        return float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        )
    }
}

// Port details view with enhanced information
struct PortDetailsView: View {
    let portName: String
    let gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedGoodType = "General Cargo"
    @State private var routeProfitability: Double = 0.0
    
    let goodTypes = ["General Cargo", "Oil", "Grain", "Electronics", "Automobiles", "Chemicals"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Port header
                    VStack(spacing: 10) {
                        Text(portName)
                            .font(.largeTitle)
                            .bold()
                        
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Major International Port")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    Divider()
                    
                    // Port statistics
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label("Container Capacity", systemImage: "cube.box.fill")
                            Spacer()
                            Text("\(Int.random(in: 30000...80000)) TEU")
                                .bold()
                        }
                        
                        HStack {
                            Label("Ships in Port", systemImage: "ferry.fill")
                            Spacer()
                            Text("\(Int.random(in: 5...25))")
                                .bold()
                        }
                        
                        HStack {
                            Label("Available Berths", systemImage: "dock.rectangle")
                            Spacer()
                            Text("\(Int.random(in: 2...15))")
                                .bold()
                        }
                        
                        HStack {
                            Label("Port Efficiency", systemImage: "speedometer")
                            Spacer()
                            Text("\(Int.random(in: 70...95))%")
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Market information
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Market Conditions")
                            .font(.headline)
                        
                        ForEach(goodTypes.prefix(3), id: \.self) { good in
                            HStack {
                                Text(good)
                                Spacer()
                                Text("$\(Int.random(in: 100...500))/ton")
                                    .foregroundColor(.green)
                                Image(systemName: Int.random(in: 0...1) == 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundColor(Int.random(in: 0...1) == 0 ? .green : .red)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Trade route creation
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Create Trade Route")
                            .font(.headline)
                        
                        Picker("Cargo Type", selection: $selectedGoodType) {
                            ForEach(goodTypes, id: \.self) { good in
                                Text(good).tag(good)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        HStack {
                            Text("Estimated Profit Margin")
                            Spacer()
                            Text("\(Int(routeProfitability))%")
                                .bold()
                                .foregroundColor(routeProfitability > 15 ? .green : .orange)
                        }
                        
                        Button(action: createTradeRoute) {
                            Label("Establish Route", systemImage: "arrow.triangle.swap")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .onAppear {
            calculateRouteProfitability()
        }
        .onChange(of: selectedGoodType) { _ in
            calculateRouteProfitability()
        }
    }
    
    func calculateRouteProfitability() {
        // Simulate profitability calculation
        routeProfitability = Double.random(in: 10...35)
    }
    
    func createTradeRoute() {
        let newRoute = TradeRoute(
            id: UUID(),
            name: "Route to \(portName)",
            startPort: "Home Port",
            endPort: portName,
            assignedShips: [],
            goodsType: selectedGoodType,
            profitMargin: routeProfitability
        )
        
        gameManager.gameState.tradeRoutes.append(newRoute)
        HapticManager.shared.notification(.success)
        dismiss()
    }
}