import SwiftUI
import Combine
import simd
import MetalKit

// Import statements - these types are part of the FlexPort module
// No additional imports needed as they're in the same module

struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var gameStarted = false
    
    var body: some View {
        // Temporary simple game view
        VStack {
            Text("🚢 FlexPort: The Video Game")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(gameStarted ? "🎮 Game Running!" : "iOS Version - Ready to Play")
                .font(.title2)
                .foregroundColor(gameStarted ? .green : .secondary)
            
            Spacer()
            
            HStack {
                VStack {
                    Text("💰 Cash")
                    Text("$1,000,000")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack {
                    Text("🚢 Ships")
                    Text("5")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack {
                    Text("🏗️ Ports")
                    Text("12")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            
            Spacer()
            
            Button(gameStarted ? "Game Running ✅" : "Start Game") {
                // Initialize the game
                gameManager.startNewGame()
                gameStarted = true
                print("🎮 Game Started!")
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)
            .disabled(gameStarted)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    // MARK: - Touch Input Setup
    
    /*
    private func setupTouchInput() {
        // Set up touch input bindings
        touchInputIntegration.entitySelected
            .receive(on: DispatchQueue.main)
            .sink { selectionEvent in
                selectedEntities.insert(selectionEvent.entity)
            }
            .store(in: &cancellables)
        
        touchInputIntegration.entityDeselected
            .receive(on: DispatchQueue.main)
            .sink { entity in
                selectedEntities.remove(entity)
            }
            .store(in: &cancellables)
        
        touchInputIntegration.worldTapped
            .receive(on: DispatchQueue.main)
            .sink { worldTapEvent in
                if !worldTapEvent.isDoubleTap && !worldTapEvent.isLongPress {
                    selectedEntities.removeAll()
                }
                
                if worldTapEvent.isDoubleTap {
                    // Show entity details or game map
                    showingEntityDetails = true
                }
            }
            .store(in: &cancellables)
        
        // Set world bounds for touch input
        touchInputIntegration.setWorldBounds(
            min: SIMD2<Float>(-500, -500),
            max: SIMD2<Float>(500, 500)
        )
    }
    
    private func cleanupTouchInput() {
        touchInputManager.detachFromCurrentView()
    }
    */
}

// MARK: - TouchEnabledWorldView

/*
struct TouchEnabledWorldView: UIViewRepresentable {
    let touchInputManager: TouchInputManager
    @Binding var selectedEntities: Set<Entity>
    
    func makeUIView(context: Context) -> TouchInteractiveView {
        let view = TouchInteractiveView()
        touchInputManager.attachToView(view)
        return view
    }
    
    func updateUIView(_ uiView: TouchInteractiveView, context: Context) {
        uiView.updateSelectedEntities(selectedEntities)
    }
}

// MARK: - TouchInteractiveView

class TouchInteractiveView: UIView {
    private var selectedEntities: Set<Entity> = []
    private var mockEntities: [(Entity, CGPoint)] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        createMockEntities()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        createMockEntities()
    }
    
    private func setupView() {
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
    }
    
    private func createMockEntities() {
        // Create some mock entities for demonstration
        for i in 0..<5 {
            let entity = Entity()
            let x = CGFloat.random(in: 50...(bounds.width - 50))
            let y = CGFloat.random(in: 50...(bounds.height - 50))
            mockEntities.append((entity, CGPoint(x: x, y: y)))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if mockEntities.isEmpty {
            createMockEntities()
        }
    }
    
    func updateSelectedEntities(_ entities: Set<Entity>) {
        selectedEntities = entities
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw mock game world
        drawOcean(in: context, rect: rect)
        drawEntities(in: context)
    }
    
    private func drawOcean(in context: CGContext, rect: CGRect) {
        // Draw ocean background with some waves
        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.3).cgColor)
        context.fill(rect)
        
        // Draw some wave lines
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(2.0)
        
        for i in stride(from: 0, to: Int(rect.height), by: 40) {
            context.move(to: CGPoint(x: 0, y: CGFloat(i)))
            for x in stride(from: 0, to: Int(rect.width), by: 20) {
                let y = CGFloat(i) + sin(CGFloat(x) * 0.1) * 5
                context.addLine(to: CGPoint(x: CGFloat(x), y: y))
            }
            context.strokePath()
        }
    }
    
    private func drawEntities(in context: CGContext) {
        for (entity, position) in mockEntities {
            let isSelected = selectedEntities.contains(entity)
            
            // Draw ship/port entity
            let size: CGFloat = isSelected ? 25 : 20
            let rect = CGRect(
                x: position.x - size/2,
                y: position.y - size/2,
                width: size,
                height: size
            )
            
            // Fill color based on selection
            if isSelected {
                context.setFillColor(UIColor.systemYellow.cgColor)
                context.setStrokeColor(UIColor.systemOrange.cgColor)
            } else {
                context.setFillColor(UIColor.systemGreen.cgColor)
                context.setStrokeColor(UIColor.darkGreen.cgColor)
            }
            
            context.setLineWidth(2.0)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
            
            // Draw selection ring if selected
            if isSelected {
                let ringRect = rect.insetBy(dx: -10, dy: -10)
                context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.6).cgColor)
                context.setLineWidth(3.0)
                context.strokeEllipse(in: ringRect)
            }
            
            // Draw entity label
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white
            ]
            let labelText = "Entity \(entity.id.uuidString.prefix(4))"
            let labelSize = labelText.size(withAttributes: attributes)
            let labelRect = CGRect(
                x: position.x - labelSize.width/2,
                y: position.y + size/2 + 5,
                width: labelSize.width,
                height: labelSize.height
            )
            labelText.draw(in: labelRect, withAttributes: attributes)
        }
    }
}
*/

// MARK: - Navigation Button

struct NavigationButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.8), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

// Temporarily commented out until Entity type is available
/*
struct EntityDetailsView: View {
    let selectedEntities: Set<Entity>
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Selected Entities") {
                    if selectedEntities.isEmpty {
                        Text("No entities selected")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(Array(selectedEntities), id: \.id) { entity in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Text("Entity \(entity.id.uuidString.prefix(4))")
                                        .font(.headline)
                                    Text("Type: Ship/Port")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Move Selected") {
                        // Move action
                    }
                    Button("Trade Route") {
                        // Trade route action
                    }
                    Button("Inspect") {
                        // Inspect action
                    }
                }
            }
            .navigationTitle("Entity Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
*/

// MARK: - BasicWorldMapView

struct BasicWorldMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedPort: String?
    @State private var showingPortDetails = false
    
    var body: some View {
        ZStack {
            // Ocean background
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.6),
                            Color.blue.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Animated waves
            WaveView()
                .opacity(0.3)
            
            // Major ports
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
            
            // Ships
            ForEach(gameManager.gameState.playerAssets.ships.indices, id: \.self) { index in
                let ship = gameManager.gameState.playerAssets.ships[index]
                BasicShipView(ship: ship)
                    .position(x: CGFloat.random(in: 50...350), y: CGFloat.random(in: 50...250))
            }
            
            // Trade routes
            ForEach(gameManager.gameState.tradeRoutes.indices, id: \.self) { index in
                let route = gameManager.gameState.tradeRoutes[index]
                BasicTradeRouteView(route: route)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .sheet(isPresented: $showingPortDetails) {
            if let portName = selectedPort {
                BasicPortDetailsView(portName: portName, gameManager: gameManager)
            }
        }
    }
    
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

// MARK: - Supporting Views

struct WaveView: View {
    @State private var waveOffset = 0.0
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    waveOffset = 2 * .pi
                }
            }
    }
}

struct BasicShipView: View {
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

struct BasicTradeRouteView: View {
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

struct BasicPortDetailsView: View {
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

// MARK: - EnhancedMetalMapView with Advanced Ocean Rendering

struct EnhancedMetalMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedPort: String?
    @State private var showingPortDetails = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced Metal-rendered ocean background
                EnhancedMetalMapViewRepresentable()
                    .environmentObject(gameManager)
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
                    SimpleShipViewInline(ship: ship)
                        .position(x: CGFloat.random(in: 50...350), y: CGFloat.random(in: 50...250))
                }
                
                // Trade routes - using the same route rendering as BasicWorldMapView
                ForEach(gameManager.gameState.tradeRoutes.indices, id: \.self) { index in
                    let route = gameManager.gameState.tradeRoutes[index]
                    SimpleTradeRouteViewInline(route: route)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .sheet(isPresented: $showingPortDetails) {
            if let portName = selectedPort {
                BasicPortDetailsView(portName: portName, gameManager: gameManager)
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

// Enhanced Metal view with AdvancedOceanRenderer
struct EnhancedMetalMapViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var gameManager: GameManager
    
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
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.1, blue: 0.2, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = false
        mtkView.preferredFramesPerSecond = 60
        
        // Use simple metal renderer for now
        let simpleRenderer = SimpleMetalRendererInline(device: device)
        mtkView.delegate = simpleRenderer
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Simple renderer doesn't need updates
    }
}

// Simple Metal renderer (inline)
class SimpleMetalRendererInline: NSObject, MTKViewDelegate {
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

// Simple ship view (inline)
struct SimpleShipViewInline: View {
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

// Simple trade route view (inline)
struct SimpleTradeRouteViewInline: View {
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