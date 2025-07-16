import SwiftUI
import MetalKit
import simd

struct SimpleMetalMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedPort: String?
    @State private var showingPortDetails = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Metal-rendered background
                MetalMapViewRepresentable()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Overlay ports - keeping the same port system as BasicWorldMapView
                ForEach(majorPorts, id: \.name) { port in
                    Button(action: {
                        selectedPort = port.name
                        showingPortDetails = true
                    }) {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 2)
                                        .scaleEffect(1.5)
                                        .opacity(0.6)
                                )
                            
                            Text(port.name)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .position(x: port.x, y: port.y)
                }
                
                // Ships - using the same ship rendering as BasicWorldMapView
                ForEach(gameManager.gameState.playerAssets.ships.indices, id: \.self) { index in
                    let ship = gameManager.gameState.playerAssets.ships[index]
                    SimpleShipView(ship: ship)
                        .position(x: CGFloat.random(in: 50...350), y: CGFloat.random(in: 50...250))
                }
                
                // Trade routes - using the same route rendering as BasicWorldMapView
                ForEach(gameManager.gameState.tradeRoutes.indices, id: \.self) { index in
                    let route = gameManager.gameState.tradeRoutes[index]
                    SimpleTradeRouteView(route: route)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .sheet(isPresented: $showingPortDetails) {
            if let portName = selectedPort {
                SimplePortDetailsView(portName: portName, gameManager: gameManager)
            }
        }
    }
    
    // Port positions - same as BasicWorldMapView
    let majorPorts = [
        (name: "Singapore", x: CGFloat(280), y: CGFloat(180)),
        (name: "Hong Kong", x: CGFloat(290), y: CGFloat(120)),
        (name: "Shanghai", x: CGFloat(300), y: CGFloat(100)),
        (name: "Los Angeles", x: CGFloat(60), y: CGFloat(140)),
        (name: "New York", x: CGFloat(120), y: CGFloat(100)),
        (name: "London", x: CGFloat(180), y: CGFloat(80)),
        (name: "Dubai", x: CGFloat(220), y: CGFloat(140))
    ]
}

// Simple Metal view representable
struct MetalMapViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        // Check if Metal is available
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Fallback to simple colored view if Metal is not available
            let fallbackView = UIView()
            fallbackView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
            return MTKView() // Return empty MTKView for type safety
        }
        
        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = false
        
        let renderer = SimpleMetalRenderer(device: device)
        mtkView.delegate = renderer
        mtkView.preferredFramesPerSecond = 60
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update any view properties here
    }
}

// Simple Metal renderer
class SimpleMetalRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var time: Float = 0
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        // Dynamic ocean color based on time
        time += 0.016 // 60 FPS
        let waveEffect = sin(time) * 0.1 + 0.5
        let oceanColor = MTLClearColor(
            red: 0.05 + Double(waveEffect) * 0.1,
            green: 0.15 + Double(waveEffect) * 0.2,
            blue: 0.3 + Double(waveEffect) * 0.3,
            alpha: 1.0
        )
        
        renderPassDescriptor.colorAttachments[0].clearColor = oceanColor
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// Simple ship view - same as BasicWorldMapView
struct SimpleShipView: View {
    let ship: Ship
    
    var body: some View {
        VStack(spacing: 1) {
            // Ship hull
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray)
                .frame(width: 20, height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
            
            // Ship name
            Text(ship.name)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(1)
                .background(Color.black.opacity(0.7))
                .cornerRadius(3)
        }
    }
}

// Simple trade route view - same as BasicWorldMapView
struct SimpleTradeRouteView: View {
    let route: TradeRoute
    
    var body: some View {
        Path { path in
            // Simple line representing trade route
            path.move(to: CGPoint(x: 100, y: 100))
            path.addLine(to: CGPoint(x: 200, y: 150))
        }
        .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
    }
}

// Simple port details view - same as BasicWorldMapView
struct SimplePortDetailsView: View {
    let portName: String
    let gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(portName)
                    .font(.largeTitle)
                    .bold()
                
                Image(systemName: "building.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Major shipping hub")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Container Capacity: 50,000 TEU", systemImage: "cube.box.fill")
                    Label("Ships in Port: \(Int.random(in: 5...20))", systemImage: "ferry.fill")
                    Label("Available Goods: \(Int.random(in: 10000...50000)) tons", systemImage: "shippingbox.fill")
                }
                .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Create a trade route to this port
                    let newRoute = TradeRoute(
                        id: UUID(),
                        name: "Route to \(portName)",
                        startPort: "Home Port",
                        endPort: portName,
                        assignedShips: [],
                        goodsType: "General Cargo",
                        profitMargin: Double.random(in: 15...30)
                    )
                    gameManager.gameState.tradeRoutes.append(newRoute)
                    dismiss()
                }) {
                    Label("Create Trade Route", systemImage: "arrow.triangle.swap")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}