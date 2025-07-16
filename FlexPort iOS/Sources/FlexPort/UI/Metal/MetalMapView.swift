import SwiftUI
import MetalKit

struct MetalMapView: UIViewRepresentable {
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedPort: String?
    @State private var showingPortDetails = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        mtkView.delegate = context.coordinator.renderer
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        
        // Add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        
        mtkView.addGestureRecognizer(panGesture)
        mtkView.addGestureRecognizer(pinchGesture)
        mtkView.addGestureRecognizer(tapGesture)
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer.zoom = Float(zoom)
        context.coordinator.renderer.pan = SIMD2<Float>(Float(offset.width / 100), Float(offset.height / 100))
    }
    
    class Coordinator: NSObject {
        var parent: MetalMapView
        let renderer: MetalMapRenderer
        var lastPanLocation: CGPoint = .zero
        
        init(_ parent: MetalMapView) {
            self.parent = parent
            self.renderer = MetalMapRenderer()
            super.init()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            
            if gesture.state == .changed {
                parent.offset.width += translation.width
                parent.offset.height += translation.height
                gesture.setTranslation(.zero, in: gesture.view)
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                parent.zoom *= gesture.scale
                parent.zoom = max(0.5, min(10.0, parent.zoom))
                gesture.scale = 1.0
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            // Convert tap location to world coordinates and check for port selection
            // This is simplified - in production would need proper coordinate transformation
            
            // For now, just demonstrate the tap handling
            if let nearestPort = findNearestPort(at: location) {
                parent.selectedPort = nearestPort
                parent.showingPortDetails = true
            }
        }
        
        private func findNearestPort(at screenPoint: CGPoint) -> String? {
            // Simplified port detection - would need proper coordinate transformation
            // For demo purposes, return a random port when tapping
            let ports = ["Hong Kong", "Singapore", "Shanghai", "London", "New York"]
            return ports.randomElement()
        }
    }
}

// Simple Metal renderer for the basic map view
class MetalMapRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    
    var zoom: Float = 1.0
    var pan: SIMD2<Float> = SIMD2<Float>(0, 0)
    var time: Float = 0.0
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        setupMetal()
    }
    
    func setupMetal() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        
        // Simple ocean blue background
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        time += 0.016
    }
}