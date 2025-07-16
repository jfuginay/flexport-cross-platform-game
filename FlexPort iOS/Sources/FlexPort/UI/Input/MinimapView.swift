import SwiftUI
import MetalKit
import simd

/// Advanced minimap view with real-time rendering and tap-to-jump
public struct MinimapView: View {
    @ObservedObject var cameraController: CameraController
    @EnvironmentObject var gameManager: GameManager
    
    let size: CGSize
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    @State private var isExpanded = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    public init(
        cameraController: CameraController,
        size: CGSize = CGSize(width: 150, height: 100),
        cornerRadius: CGFloat = 10,
        borderWidth: CGFloat = 2
    ) {
        self.cameraController = cameraController
        self.size = size
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
    }
    
    public var body: some View {
        ZStack {
            // Minimap content
            minimapContent
                .frame(width: currentSize.width, height: currentSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderGradient, lineWidth: borderWidth)
                )
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            
            // Controls overlay
            controlsOverlay
        }
        .scaleEffect(isExpanded ? 2.0 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .gesture(dragGesture)
        .gesture(tapGesture)
        .gesture(longPressGesture)
    }
    
    // MARK: - Minimap Content
    
    private var minimapContent: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.02, green: 0.05, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Metal-rendered minimap
            MinimapMetalView(
                cameraController: cameraController,
                gameManager: gameManager,
                size: currentSize
            )
            .allowsHitTesting(false)
            
            // Viewport indicator
            viewportIndicator
            
            // Additional overlays
            if isExpanded {
                expandedOverlays
            }
        }
    }
    
    private var viewportIndicator: some View {
        GeometryReader { geometry in
            let viewport = calculateViewport(in: geometry.size)
            
            Rectangle()
                .stroke(Color.yellow, lineWidth: 2)
                .background(
                    Color.yellow.opacity(0.1)
                )
                .frame(width: viewport.width, height: viewport.height)
                .position(x: viewport.midX, y: viewport.midY)
                .shadow(color: .yellow.opacity(0.5), radius: 3)
                .animation(.easeInOut(duration: 0.1), value: viewport)
        }
    }
    
    private var expandedOverlays: some View {
        VStack {
            HStack {
                // Coordinate display
                Text(coordinateText)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                
                Spacer()
                
                // Zoom level
                Text("Zoom: \(Int(cameraController.zoom * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
            }
            .padding(8)
            
            Spacer()
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                
                // Expand/collapse button
                Button(action: toggleExpanded) {
                    Image(systemName: isExpanded ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(4)
            
            Spacer()
        }
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    HapticManager.shared.playSelectionFeedback()
                }
                dragOffset = value.translation
            }
            .onEnded { _ in
                isDragging = false
                dragOffset = .zero
                HapticManager.shared.playImpactFeedback(.light)
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                // Tap gesture is handled by the onTapGesture modifier in MinimapMetalView
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                toggleExpanded()
            }
    }
    
    // MARK: - Actions
    
    private func toggleExpanded() {
        withAnimation(.spring()) {
            isExpanded.toggle()
        }
        HapticManager.shared.playNotificationFeedback(isExpanded ? .success : .warning)
    }
    
    // MARK: - Calculations
    
    private func calculateViewport(in size: CGSize) -> CGRect {
        let worldBounds = CGRect(x: -50, y: -50, width: 100, height: 100) // World bounds
        let cameraPos = CGPoint(x: CGFloat(cameraController.position.x), y: CGFloat(cameraController.position.z))
        let zoom = CGFloat(cameraController.zoom)
        
        // Calculate viewport size based on zoom
        let viewportWorldWidth = worldBounds.width / zoom
        let viewportWorldHeight = worldBounds.height / zoom
        
        // Convert to minimap coordinates
        let minimapScale = size.width / worldBounds.width
        let viewportWidth = viewportWorldWidth * minimapScale
        let viewportHeight = viewportWorldHeight * minimapScale
        
        // Calculate position
        let normalizedX = (cameraPos.x - worldBounds.minX) / worldBounds.width
        let normalizedY = (cameraPos.y - worldBounds.minY) / worldBounds.height
        let viewportX = normalizedX * size.width
        let viewportY = normalizedY * size.height
        
        return CGRect(
            x: viewportX - viewportWidth / 2,
            y: viewportY - viewportHeight / 2,
            width: viewportWidth,
            height: viewportHeight
        )
    }
    
    // MARK: - Computed Properties
    
    private var currentSize: CGSize {
        isExpanded ? CGSize(width: size.width * 2, height: size.height * 2) : size
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.6),
                Color.white.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var coordinateText: String {
        let x = Int(cameraController.position.x)
        let z = Int(cameraController.position.z)
        return "X: \(x), Z: \(z)"
    }
}

// MARK: - Metal Minimap View

struct MinimapMetalView: UIViewRepresentable {
    let cameraController: CameraController
    let gameManager: GameManager
    let size: CGSize
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return metalView
        }
        
        metalView.device = device
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 30 // Lower FPS for minimap
        metalView.clearColor = MTLClearColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        metalView.isUserInteractionEnabled = true
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        metalView.addGestureRecognizer(tapGesture)
        
        context.coordinator.renderer = MinimapRenderer(device: device)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.cameraController = cameraController
        context.coordinator.gameManager = gameManager
        context.coordinator.renderer?.updateCamera(cameraController)
        context.coordinator.renderer?.updateGameState(gameManager.gameState)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraController: cameraController, gameManager: gameManager)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var cameraController: CameraController
        var gameManager: GameManager
        var renderer: MinimapRenderer?
        
        init(cameraController: CameraController, gameManager: GameManager) {
            self.cameraController = cameraController
            self.gameManager = gameManager
            super.init()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            let normalizedLocation = CGPoint(
                x: location.x / view.bounds.width,
                y: location.y / view.bounds.height
            )
            
            // Convert tap location to world coordinates
            let worldBounds = CGRect(x: -50, y: -50, width: 100, height: 100)
            let worldX = Float(worldBounds.minX + normalizedLocation.x * worldBounds.width)
            let worldZ = Float(worldBounds.minY + normalizedLocation.y * worldBounds.height)
            
            // Jump camera to location
            cameraController.focusOn(
                position: SIMD3<Float>(worldX, cameraController.position.y, worldZ),
                animated: true
            )
            
            HapticManager.shared.playImpactFeedback(.medium)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.updateSize(size)
        }
        
        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}

// MARK: - Minimap Renderer

class MinimapRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    
    private var camera: CameraController?
    private var gameState: GameState?
    private var viewportSize: CGSize = .zero
    
    struct MinimapUniforms {
        var viewMatrix: float4x4
        var projectionMatrix: float4x4
        var viewportIndicator: SIMD4<Float> // x, y, width, height
    }
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        setupPipeline()
        createBuffers()
    }
    
    private func setupPipeline() {
        // Create simple pipeline for minimap rendering
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "minimap_vertex")
        let fragmentFunction = library?.makeFunction(name: "minimap_fragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create minimap pipeline state: \(error)")
        }
    }
    
    private func createBuffers() {
        // Create vertex buffer for minimap quad
        let vertices: [Float] = [
            -1, -1, 0, 1,  0, 1,  // Bottom left
             1, -1, 0, 1,  1, 1,  // Bottom right
             1,  1, 0, 1,  1, 0,  // Top right
            -1,  1, 0, 1,  0, 0   // Top left
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
        uniformBuffer = device.makeBuffer(length: MemoryLayout<MinimapUniforms>.stride, options: [])
    }
    
    func updateCamera(_ camera: CameraController) {
        self.camera = camera
    }
    
    func updateGameState(_ state: GameState) {
        self.gameState = state
    }
    
    func updateSize(_ size: CGSize) {
        self.viewportSize = size
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState,
              let camera = camera else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Update uniforms
        var uniforms = MinimapUniforms(
            viewMatrix: float4x4(1), // Top-down view for minimap
            projectionMatrix: float4x4(orthographicProjection:
                left: -50, right: 50,
                bottom: -50, top: 50,
                near: 0.1, far: 100
            ),
            viewportIndicator: SIMD4<Float>(
                Float(camera.position.x),
                Float(camera.position.z),
                20.0 / Float(camera.zoom),
                20.0 / Float(camera.zoom)
            )
        )
        
        uniformBuffer?.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<MinimapUniforms>.stride)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Draw minimap quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}