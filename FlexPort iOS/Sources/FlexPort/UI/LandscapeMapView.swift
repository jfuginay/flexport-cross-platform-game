import SwiftUI
import MapKit
import MetalKit
import Combine

// MARK: - Landscape Map View
struct LandscapeMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694), // Hong Kong
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
    )
    @State private var selectedShip: Ship?
    @State private var selectedPort: Port?
    @State private var showingActionMenu = false
    @State private var zoomLevel: Double = 1.0
    @State private var showingMultiplayerOverlay = false
    @State private var otherPlayerShips: [String: [ShipPosition]] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enhanced Metal Ocean Background
                EnhancedOceanMapView()
                    .ignoresSafeArea()
                
                // Interactive Map Layer
                InteractiveMapLayer(
                    selectedShip: $selectedShip,
                    selectedPort: $selectedPort,
                    otherPlayerShips: otherPlayerShips
                )
                .scaleEffect(zoomLevel)
                .gesture(magnificationGesture)
                .gesture(dragGesture)
                
                // UI Overlays
                VStack {
                    // Top Bar
                    TopControlBar(showingMultiplayerOverlay: $showingMultiplayerOverlay)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // Bottom Action Bar
                    if selectedShip != nil || selectedPort != nil {
                        BottomActionBar(
                            selectedShip: $selectedShip,
                            selectedPort: $selectedPort,
                            showingActionMenu: $showingActionMenu
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Multiplayer Overlay
                if showingMultiplayerOverlay {
                    MultiplayerOverlay()
                        .transition(.opacity)
                }
                
                // Mini Map
                MiniMapView(mapRegion: $mapRegion)
                    .frame(width: 180, height: 120)
                    .position(x: geometry.size.width - 100, y: geometry.size.height - 80)
            }
            .onReceive(multiplayerShipPositions) { positions in
                otherPlayerShips = positions
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
    
    // MARK: - Gestures
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / zoomLevel
                zoomLevel = min(max(0.5, zoomLevel * delta), 3.0)
            }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Update map region based on drag
                let deltaLat = Double(value.translation.height) * 0.01 / zoomLevel
                let deltaLon = Double(-value.translation.width) * 0.01 / zoomLevel
                
                mapRegion.center.latitude += deltaLat
                mapRegion.center.longitude += deltaLon
            }
    }
    
    // Multiplayer ship positions publisher
    var multiplayerShipPositions: AnyPublisher<[String: [ShipPosition]], Never> {
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .map { _ in
                // In real implementation, this would come from MultiplayerManager
                return generateMockMultiplayerShips()
            }
            .eraseToAnyPublisher()
    }
    
    func generateMockMultiplayerShips() -> [String: [ShipPosition]] {
        var ships: [String: [ShipPosition]] = [:]
        
        for playerId in multiplayerManager.connectedPlayers {
            ships[playerId] = (0..<3).map { index in
                ShipPosition(
                    id: "\(playerId)_ship_\(index)",
                    latitude: 22.3193 + Double.random(in: -5...5),
                    longitude: 114.1694 + Double.random(in: -10...10),
                    heading: Double.random(in: 0...360),
                    speed: Double.random(in: 15...25)
                )
            }
        }
        
        return ships
    }
}

// MARK: - Enhanced Ocean Map View
struct EnhancedOceanMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return mtkView
        }
        
        mtkView.device = device
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.1, blue: 0.2, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        
        let renderer = AdvancedOceanRenderer(device: device)
        mtkView.delegate = renderer
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update if needed
    }
}

// MARK: - Advanced Ocean Renderer
class AdvancedOceanRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var time: Float = 0
    var pipelineState: MTLRenderPipelineState?
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        setupPipeline()
    }
    
    func setupPipeline() {
        // In a real implementation, this would load custom Metal shaders
        // For now, we'll use the clear color effect
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        time += 0.016 // 60 FPS
        
        // Create wave effect with multiple layers
        let wave1 = sin(time * 0.5) * 0.05
        let wave2 = sin(time * 0.8 + 1.5) * 0.03
        let wave3 = sin(time * 1.2 + 3.0) * 0.02
        let combinedWave = wave1 + wave2 + wave3
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        // Dynamic ocean color with depth variation
        let depthFactor = (sin(time * 0.3) + 1.0) / 2.0
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(0.05 + combinedWave * 0.1),
            green: Double(0.15 + combinedWave * 0.15 + depthFactor * 0.1),
            blue: Double(0.35 + combinedWave * 0.2 + depthFactor * 0.15),
            alpha: 1.0
        )
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Here we would render ocean waves, foam, etc. with custom shaders
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Interactive Map Layer
struct InteractiveMapLayer: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var selectedShip: Ship?
    @Binding var selectedPort: Port?
    let otherPlayerShips: [String: [ShipPosition]]
    
    let ports = [
        Port(id: "singapore", name: "Singapore", latitude: 1.3521, longitude: 103.8198),
        Port(id: "hongkong", name: "Hong Kong", latitude: 22.3193, longitude: 114.1694),
        Port(id: "shanghai", name: "Shanghai", latitude: 31.2304, longitude: 121.4737),
        Port(id: "losangeles", name: "Los Angeles", latitude: 33.7490, longitude: -118.2500),
        Port(id: "newyork", name: "New York", latitude: 40.7128, longitude: -74.0060),
        Port(id: "london", name: "London", latitude: 51.5074, longitude: -0.1278),
        Port(id: "dubai", name: "Dubai", latitude: 25.2048, longitude: 55.2708)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Trade Routes
                ForEach(gameManager.gameState.tradeRoutes) { route in
                    if let startPort = ports.first(where: { $0.name == route.startPort }),
                       let endPort = ports.first(where: { $0.name == route.endPort }) {
                        TradeRoutePath(
                            start: coordinateToPoint(startPort.coordinate, in: geometry.size),
                            end: coordinateToPoint(endPort.coordinate, in: geometry.size)
                        )
                    }
                }
                
                // Ports
                ForEach(ports) { port in
                    PortMarker(
                        port: port,
                        isSelected: selectedPort?.id == port.id,
                        position: coordinateToPoint(port.coordinate, in: geometry.size)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPort = port
                            selectedShip = nil
                        }
                    }
                }
                
                // Player Ships
                ForEach(gameManager.gameState.playerAssets.ships) { ship in
                    ShipSprite(
                        ship: ship,
                        isSelected: selectedShip?.id == ship.id,
                        position: randomShipPosition(for: ship, in: geometry.size),
                        isOwnShip: true
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedShip = ship
                            selectedPort = nil
                        }
                    }
                }
                
                // Other Players' Ships
                ForEach(Array(otherPlayerShips.keys), id: \.self) { playerId in
                    if let ships = otherPlayerShips[playerId] {
                        ForEach(ships) { shipPosition in
                            OtherPlayerShipSprite(
                                position: coordinateToPoint(
                                    CLLocationCoordinate2D(
                                        latitude: shipPosition.latitude,
                                        longitude: shipPosition.longitude
                                    ),
                                    in: geometry.size
                                ),
                                playerId: playerId,
                                heading: shipPosition.heading
                            )
                        }
                    }
                }
            }
        }
    }
    
    func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        // Simple mercator projection
        let x = (coordinate.longitude + 180) / 360 * size.width
        let y = (90 - coordinate.latitude) / 180 * size.height
        return CGPoint(x: x, y: y)
    }
    
    func randomShipPosition(for ship: Ship, in size: CGSize) -> CGPoint {
        // In a real implementation, this would use actual ship positions
        let index = gameManager.gameState.playerAssets.ships.firstIndex(where: { $0.id == ship.id }) ?? 0
        let baseX = size.width * 0.3 + CGFloat(index) * 50
        let baseY = size.height * 0.4 + CGFloat(index) * 30
        return CGPoint(x: baseX, y: baseY)
    }
}

// MARK: - Ship Sprite
struct ShipSprite: View {
    let ship: Ship
    let isSelected: Bool
    let position: CGPoint
    let isOwnShip: Bool
    @State private var wakeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Wake effect
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.white.opacity(0.3 - Double(index) * 0.1), lineWidth: 1)
                    .frame(width: 20 + CGFloat(index) * 15, height: 20 + CGFloat(index) * 15)
                    .offset(x: -CGFloat(index) * 10 - wakeOffset, y: 0)
            }
            
            // Ship body
            Image(systemName: "ferry.fill")
                .font(.system(size: isSelected ? 28 : 24))
                .foregroundColor(isOwnShip ? .blue : .gray)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.2)
                    .opacity(0.8)
            }
            
            // Ship name
            Text(ship.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .offset(y: 20)
        }
        .position(position)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wakeOffset = 20
            }
        }
    }
}

// MARK: - Other Player Ship Sprite
struct OtherPlayerShipSprite: View {
    let position: CGPoint
    let playerId: String
    let heading: Double
    
    var body: some View {
        ZStack {
            // Ship icon
            Image(systemName: "ferry.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(heading))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            
            // Player indicator
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .offset(y: -12)
            
            // Player ID
            Text(playerId.prefix(4).uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.orange)
                .cornerRadius(3)
                .offset(y: 16)
        }
        .position(position)
    }
}

// MARK: - Port Marker
struct PortMarker: View {
    let port: Port
    let isSelected: Bool
    let position: CGPoint
    
    var body: some View {
        ZStack {
            // Port ring animation
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(1.3)
                    .opacity(0.6)
            }
            
            // Port icon
            Circle()
                .fill(Color.yellow)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.orange, lineWidth: 3)
                )
            
            // Port name
            Text(port.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.8))
                .cornerRadius(6)
                .offset(y: 20)
        }
        .position(position)
    }
}

// MARK: - Trade Route Path
struct TradeRoutePath: View {
    let start: CGPoint
    let end: CGPoint
    @State private var dashPhase: CGFloat = 0
    
    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(Color.green.opacity(0.6), style: StrokeStyle(
            lineWidth: 2,
            dash: [10, 5],
            dashPhase: dashPhase
        ))
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                dashPhase = 15
            }
        }
    }
}

// MARK: - Top Control Bar
struct TopControlBar: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @Binding var showingMultiplayerOverlay: Bool
    
    var body: some View {
        HStack {
            // Game Info
            HStack(spacing: 16) {
                InfoBadge(
                    icon: "dollarsign.circle.fill",
                    value: "$\(Int(gameManager.gameState.playerAssets.money / 1000))K",
                    color: .green
                )
                
                InfoBadge(
                    icon: "ferry.fill",
                    value: "\(gameManager.gameState.playerAssets.ships.count)",
                    color: .blue
                )
                
                InfoBadge(
                    icon: "star.fill",
                    value: "\(Int(gameManager.gameState.playerAssets.reputation))",
                    color: .purple
                )
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 12) {
                // Multiplayer Status
                Button(action: {
                    withAnimation {
                        showingMultiplayerOverlay.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(multiplayerManager.connectionState == .connected ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("\(multiplayerManager.connectedPlayers.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
                
                // Menu Button
                Button(action: {
                    // Show menu
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    @Binding var selectedShip: Ship?
    @Binding var selectedPort: Port?
    @Binding var showingActionMenu: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection Info
            VStack(alignment: .leading, spacing: 4) {
                if let ship = selectedShip {
                    Text(ship.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(ship.capacity) TEU • \(Int(ship.speed)) knots")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                } else if let port = selectedPort {
                    Text(port.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Major Shipping Hub")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.leading, 16)
            
            Spacer()
            
            // Action Buttons
            if selectedShip != nil {
                ActionButton(icon: "map", label: "Route") {
                    // Change route
                }
                
                ActionButton(icon: "info.circle", label: "Details") {
                    showingActionMenu = true
                }
            } else if selectedPort != nil {
                ActionButton(icon: "arrow.triangle.swap", label: "Trade") {
                    // Create trade route
                }
                
                ActionButton(icon: "building.2", label: "Invest") {
                    // Invest in port
                }
            }
            
            // Close Button
            Button(action: {
                withAnimation {
                    selectedShip = nil
                    selectedPort = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.trailing, 8)
        }
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 60, height: 50)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

// MARK: - Mini Map View
struct MiniMapView: View {
    @Binding var mapRegion: MKCoordinateRegion
    
    var body: some View {
        ZStack {
            // Map background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            // Simplified world map
            GeometryReader { geometry in
                // Continents (simplified)
                Path { path in
                    // Add simplified continent outlines
                    path.addRect(CGRect(x: 20, y: 30, width: 40, height: 20)) // Europe/Africa
                    path.addRect(CGRect(x: 80, y: 25, width: 50, height: 30)) // Asia
                    path.addRect(CGRect(x: 140, y: 40, width: 30, height: 25)) // Americas
                }
                .fill(Color.green.opacity(0.5))
                
                // Current view indicator
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 40, height: 30)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .padding(8)
        }
    }
}

// MARK: - Multiplayer Overlay
struct MultiplayerOverlay: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    // Connection Status
                    HStack(spacing: 8) {
                        Text("Connected Players")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("\(multiplayerManager.connectedPlayers.count)/16")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    
                    // Player List
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(multiplayerManager.connectedPlayers.prefix(5), id: \.self) { playerId in
                            PlayerTag(playerId: playerId)
                        }
                        
                        if multiplayerManager.connectedPlayers.count > 5 {
                            Text("+\(multiplayerManager.connectedPlayers.count - 5) more")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Network Stats
                    if multiplayerManager.connectionState == .connected {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "network")
                                    .font(.caption2)
                                Text("\(Int(multiplayerManager.networkMetrics.latency * 1000))ms")
                                    .font(.caption2)
                            }
                            .foregroundColor(latencyColor)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.caption2)
                                Text("\(Int(multiplayerManager.networkMetrics.bandwidth)) KB/s")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .background(Color.clear)
    }
    
    var latencyColor: Color {
        let latency = multiplayerManager.networkMetrics.latency * 1000
        if latency < 50 {
            return .green
        } else if latency < 150 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Player Tag
struct PlayerTag: View {
    let playerId: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange)
                .frame(width: 20, height: 20)
                .overlay(
                    Text(String(playerId.prefix(2)).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text("Player \(playerId.prefix(6))")
                .font(.caption)
                .foregroundColor(.white)
                
            Image(systemName: "ferry.fill")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text("5")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
    }
}

// MARK: - Supporting Types
struct Port: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ShipPosition: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let heading: Double
    let speed: Double
}