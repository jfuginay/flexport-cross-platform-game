import SwiftUI
import MetalKit
import Combine

/// Integrated map view with advanced gesture controls and camera system
public struct IntegratedGestureMapView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var gestureManager = AdvancedGestureManager()
    @StateObject private var cameraController = CameraController()
    
    @State private var showContextMenu = false
    @State private var contextMenuItems: [ContextMenuItem] = []
    @State private var selectedEntity: SelectedEntity?
    @State private var showGestureHelp = false
    @State private var debugOverlay = false
    
    // Gesture state
    @State private var lastPanValue: CGSize = .zero
    @State private var lastZoomValue: CGFloat = 1.0
    @State private var lastRotationValue: Angle = .zero
    
    public var body: some View {
        ZStack {
            // Main map view with Metal rendering
            EnhancedMetalMapViewIntegrated(
                cameraController: cameraController,
                gestureManager: gestureManager,
                gameManager: gameManager
            )
            .gesture(createCombinedGesture())
            .onReceive(gestureManager.$currentPanMomentum) { momentum in
                applyPanMomentum(momentum)
            }
            .onReceive(gestureManager.$currentZoomMomentum) { momentum in
                applyZoomMomentum(momentum)
            }
            .onReceive(gestureManager.$currentRotationMomentum) { momentum in
                applyRotationMomentum(momentum)
            }
            .onReceive(gestureManager.$currentEdgeScrollVelocity) { velocity in
                applyEdgeScroll(velocity)
            }
            
            // UI Overlays
            overlayControls
            
            // Context menu
            if showContextMenu, let location = gestureManager.contextMenuLocation {
                contextMenuView(at: location)
            }
            
            // Minimap
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MinimapView(cameraController: cameraController)
                        .padding()
                }
            }
            
            // Debug overlay
            if debugOverlay {
                debugOverlayView
            }
            
            // Gesture help
            if showGestureHelp {
                gestureHelpOverlay
            }
        }
        .background(Color.black)
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Gesture Creation
    
    private func createCombinedGesture() -> some Gesture {
        SimultaneousGesture(
            SimultaneousGesture(
                createDragGesture(),
                createMagnificationGesture()
            ),
            SimultaneousGesture(
                createRotationGesture(),
                createTapGestures()
            )
        )
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastPanValue.width,
                    height: value.translation.height - lastPanValue.height
                )
                
                gestureManager.handlePanChanged(
                    at: value.location,
                    translation: value.translation
                )
                
                cameraController.pan(
                    by: CGVector(dx: -delta.width, dy: -delta.height),
                    screenSize: UIScreen.main.bounds.size
                )
                
                lastPanValue = value.translation
            }
            .onEnded { _ in
                gestureManager.handlePanEnded()
                lastPanValue = .zero
            }
    }
    
    private func createMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastZoomValue
                
                gestureManager.handlePinchChanged(scale: value)
                cameraController.zoom(
                    by: Float(delta),
                    focusPoint: nil,
                    screenSize: UIScreen.main.bounds.size
                )
                
                lastZoomValue = value
            }
            .onEnded { value in
                gestureManager.handlePinchEnded(finalScale: value)
                lastZoomValue = 1.0
            }
    }
    
    private func createRotationGesture() -> some Gesture {
        RotationGesture()
            .onChanged { value in
                let delta = value - lastRotationValue
                
                gestureManager.handleRotationChanged(angle: value)
                
                if cameraController.is3DMode {
                    cameraController.rotate(by: SIMD2<Float>(Float(delta.radians), 0))
                }
                
                lastRotationValue = value
            }
            .onEnded { value in
                gestureManager.handleRotationEnded(finalAngle: value)
                lastRotationValue = .zero
            }
    }
    
    private func createTapGestures() -> some Gesture {
        SimultaneousGesture(
            TapGesture(count: 2)
                .onEnded { handleDoubleTap() },
            SimultaneousGesture(
                TapGesture(count: 3)
                    .onEnded { handleTripleTap() },
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in handleLongPress() }
            )
        )
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDoubleTap() {
        let location = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        let action = gestureManager.handleDoubleTap(at: location, in: UIScreen.main.bounds.size)
        
        switch action {
        case .focusEntity(let entity):
            focusOnEntity(entity)
        case .resetView:
            cameraController.resetView(animated: true)
        }
    }
    
    private func handleTripleTap() {
        gestureManager.handleTripleTap()
        cameraController.toggle3DMode()
    }
    
    private func handleLongPress() {
        // Get touch location and show context menu
        if let touchLocation = getTouchLocation() {
            gestureManager.handleLongPress(at: touchLocation)
            showContextMenuAt(touchLocation)
        }
    }
    
    // MARK: - Momentum Application
    
    private func applyPanMomentum(_ momentum: CGVector) {
        guard momentum.magnitude > 0.1 else { return }
        
        cameraController.pan(
            by: CGVector(dx: -momentum.dx / 60, dy: -momentum.dy / 60),
            screenSize: UIScreen.main.bounds.size
        )
    }
    
    private func applyZoomMomentum(_ momentum: CGFloat) {
        guard abs(momentum) > 0.001 else { return }
        
        let factor = 1.0 + Float(momentum) / 60
        cameraController.zoom(
            by: factor,
            focusPoint: nil,
            screenSize: UIScreen.main.bounds.size
        )
    }
    
    private func applyRotationMomentum(_ momentum: CGFloat) {
        guard abs(momentum) > 0.001 else { return }
        
        if cameraController.is3DMode {
            cameraController.rotate(by: SIMD2<Float>(Float(momentum) / 60, 0))
        }
    }
    
    private func applyEdgeScroll(_ velocity: CGVector) {
        guard velocity.magnitude > 0.1 else { return }
        
        cameraController.pan(
            by: CGVector(dx: -velocity.dx / 60, dy: -velocity.dy / 60),
            screenSize: UIScreen.main.bounds.size
        )
    }
    
    // MARK: - Context Menu
    
    private func showContextMenuAt(_ location: CGPoint) {
        // Determine what's at the location
        if let entity = findEntityAt(location) {
            contextMenuItems = createContextMenuItems(for: entity)
            selectedEntity = entity
            showContextMenu = true
        }
    }
    
    private func createContextMenuItems(for entity: SelectedEntity) -> [ContextMenuItem] {
        switch entity.type {
        case .port:
            return [
                ContextMenuItem(title: "Port Details", icon: "info.circle") {
                    showPortDetails(entity.id)
                },
                ContextMenuItem(title: "Create Route", icon: "arrow.triangle.swap") {
                    startRouteCreation(from: entity.id)
                },
                ContextMenuItem(title: "View Market", icon: "chart.line.uptrend.xyaxis") {
                    showMarketData(for: entity.id)
                }
            ]
        case .ship:
            return [
                ContextMenuItem(title: "Ship Details", icon: "ferry") {
                    showShipDetails(entity.id)
                },
                ContextMenuItem(title: "Assign Route", icon: "map") {
                    assignRoute(to: entity.id)
                },
                ContextMenuItem(title: "Follow Ship", icon: "location.viewfinder") {
                    followShip(entity.id)
                }
            ]
        case .ocean:
            return [
                ContextMenuItem(title: "Place Waypoint", icon: "mappin.and.ellipse") {
                    placeWaypoint(at: entity.position)
                },
                ContextMenuItem(title: "Measure Distance", icon: "ruler") {
                    startDistanceMeasurement(from: entity.position)
                }
            ]
        }
    }
    
    // MARK: - UI Overlays
    
    private var overlayControls: some View {
        VStack {
            // Top controls
            HStack {
                // View mode selector
                viewModeSelector
                
                Spacer()
                
                // Quick actions
                quickActionButtons
            }
            .padding()
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Speed controls
                speedControls
                
                Spacer()
                
                // Camera controls
                cameraControls
            }
            .padding()
        }
    }
    
    private var viewModeSelector: some View {
        Picker("View Mode", selection: $cameraController.is3DMode) {
            Text("2D").tag(false)
            Text("3D").tag(true)
        }
        .pickerStyle(SegmentedPickerStyle())
        .frame(width: 100)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showGestureHelp.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
            }
            
            Button(action: { debugOverlay.toggle() }) {
                Image(systemName: "ant.circle")
                    .font(.title2)
            }
            
            Button(action: { cameraController.resetView() }) {
                Image(systemName: "location.circle")
                    .font(.title2)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var speedControls: some View {
        HStack(spacing: 16) {
            Button(action: { gameManager.decreaseSpeed() }) {
                Image(systemName: "backward.fill")
            }
            
            Text("\(gameManager.gameSpeed)x")
                .font(.headline)
                .frame(width: 40)
            
            Button(action: { gameManager.increaseSpeed() }) {
                Image(systemName: "forward.fill")
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var cameraControls: some View {
        VStack(spacing: 8) {
            // Zoom controls
            Button(action: { cameraController.zoom(by: 1.5, screenSize: UIScreen.main.bounds.size) }) {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 40, height: 40)
            }
            
            Button(action: { cameraController.zoom(by: 0.67, screenSize: UIScreen.main.bounds.size) }) {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 40, height: 40)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private func contextMenuView(at location: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(contextMenuItems) { item in
                Button(action: {
                    item.action()
                    dismissContextMenu()
                }) {
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                        Text(item.title)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.primary)
                .background(Color.gray.opacity(0.1))
                
                if item.id != contextMenuItems.last?.id {
                    Divider()
                }
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
        .position(x: location.x, y: location.y)
    }
    
    private var debugOverlayView: some View {
        VStack(alignment: .leading) {
            Text("Debug Info")
                .font(.headline)
            
            Group {
                Text("Camera Pos: \(String(format: "%.1f, %.1f, %.1f", cameraController.position.x, cameraController.position.y, cameraController.position.z))")
                Text("Zoom: \(String(format: "%.2f", cameraController.zoom))")
                Text("FPS: 60") // Would be updated with actual FPS
                Text("Entities: \(gameManager.gameState.playerAssets.ships.count) ships")
                Text("Gesture: \(gestureManager.currentGesture.debugDescription)")
            }
            .font(.caption)
            .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .frame(width: 200, alignment: .leading)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    private var gestureHelpOverlay: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Gesture Controls")
                    .font(.headline)
                
                gestureHelpRow(icon: "hand.draw", title: "Pan", description: "Drag to move")
                gestureHelpRow(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Pinch", description: "Zoom in/out")
                gestureHelpRow(icon: "arrow.clockwise", title: "Rotate", description: "Two-finger twist (3D mode)")
                gestureHelpRow(icon: "hand.tap", title: "Double Tap", description: "Focus on entity or reset")
                gestureHelpRow(icon: "hand.tap", title: "Triple Tap", description: "Toggle 2D/3D mode")
                gestureHelpRow(icon: "hand.point.up.left", title: "Long Press", description: "Context menu")
                
                Button("Dismiss") {
                    showGestureHelp = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding()
        }
    }
    
    private func gestureHelpRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Configure camera for initial view
        cameraController.constraints.aspectRatio = Float(UIScreen.main.bounds.width / UIScreen.main.bounds.height)
        cameraController.position = SIMD3<Float>(0, 20, 0)
        cameraController.rotation = SIMD3<Float>(-.pi / 2, 0, 0)
        
        // Configure gesture manager
        gestureManager.config.edgeScrollEnabled = true
    }
    
    private func findEntityAt(_ location: CGPoint) -> SelectedEntity? {
        // This would use hit testing against the game entities
        // For now, return a mock entity
        return SelectedEntity(
            id: UUID(),
            type: .ocean,
            position: location,
            name: "Ocean"
        )
    }
    
    private func getTouchLocation() -> CGPoint? {
        // Get current touch location
        return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
    }
    
    private func focusOnEntity(_ entity: FocusableEntity) {
        let worldPos = SIMD3<Float>(
            Float(entity.position.x),
            cameraController.position.y,
            Float(entity.position.y)
        )
        cameraController.focusOn(position: worldPos, zoom: entity.recommendedZoom)
    }
    
    private func dismissContextMenu() {
        showContextMenu = false
        contextMenuItems = []
        gestureManager.dismissContextMenu()
    }
    
    // MARK: - Action Handlers
    
    private func showPortDetails(_ id: UUID) {
        // Implement port details view
    }
    
    private func startRouteCreation(from id: UUID) {
        // Implement route creation
    }
    
    private func showMarketData(for id: UUID) {
        // Implement market data view
    }
    
    private func showShipDetails(_ id: UUID) {
        // Implement ship details view
    }
    
    private func assignRoute(to id: UUID) {
        // Implement route assignment
    }
    
    private func followShip(_ id: UUID) {
        // Implement ship following
        if let ship = gameManager.gameState.playerAssets.ships.first(where: { $0.id == id }) {
            let target = FollowTarget(
                position: SIMD3<Float>(0, 0, 0), // Convert ship position
                velocity: nil,
                rotation: nil
            )
            cameraController.followEntity(target)
        }
    }
    
    private func placeWaypoint(at position: CGPoint) {
        // Implement waypoint placement
    }
    
    private func startDistanceMeasurement(from position: CGPoint) {
        // Implement distance measurement
    }
}

// MARK: - Supporting Types

struct ContextMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

struct SelectedEntity {
    let id: UUID
    let type: EntityType
    let position: CGPoint
    let name: String
    
    enum EntityType {
        case port
        case ship
        case ocean
    }
}

extension GestureType {
    var debugDescription: String {
        switch self {
        case .none: return "None"
        case .pan: return "Pan"
        case .zoom: return "Zoom"
        case .rotation: return "Rotation"
        case .edgeScroll: return "Edge Scroll"
        }
    }
}

// MARK: - Enhanced Metal Map View Integration

struct EnhancedMetalMapViewIntegrated: UIViewRepresentable {
    let cameraController: CameraController
    let gestureManager: AdvancedGestureManager
    let gameManager: GameManager
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported")
        }
        
        metalView.device = device
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 60
        metalView.clearColor = MTLClearColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0)
        
        context.coordinator.renderer = EnhancedMapRenderer(device: device)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update renderer with latest state
        context.coordinator.renderer?.zoom = cameraController.zoom
        context.coordinator.renderer?.pan = SIMD2<Float>(
            cameraController.position.x / 100,
            cameraController.position.z / 100
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: EnhancedMapRenderer?
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes
        }
        
        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}