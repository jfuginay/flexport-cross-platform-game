import SwiftUI
import Combine

/// Advanced gesture control system with comprehensive haptic feedback
struct AdvancedGestureMapView: View {
    @StateObject private var gestureManager = GestureManager()
    @StateObject private var mapController = MapController()
    @Binding var selectedPorts: Set<UUID>
    @Binding var selectedShips: Set<UUID>
    
    let ports: [EnhancedPort]
    let ships: [ShipVisualization]
    let onPortSelected: (UUID) -> Void
    let onShipSelected: (UUID) -> Void
    let onRouteCreated: (UUID, UUID) -> Void
    
    @State private var showingGestureHelper = false
    @State private var lastHapticTime: Date = Date()
    
    var body: some View {
        ZStack {
            // Main map view
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    
                    // Map content
                    mapContent(in: geometry)
                        .scaleEffect(mapController.zoomLevel)
                        .offset(mapController.panOffset)
                        .rotationEffect(mapController.rotationAngle)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: mapController.panOffset)
                        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.9), value: mapController.zoomLevel)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: mapController.rotationAngle)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .gesture(
                    createAdvancedGesture(in: geometry)
                )
                .onReceive(gestureManager.$currentGesture) { gesture in
                    handleGestureChange(gesture)
                }
            }
            
            // Gesture indicator overlay
            if gestureManager.showIndicator {
                gestureIndicatorOverlay
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Gesture helper
            if showingGestureHelper {
                gestureHelperOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Control buttons
            controlButtonsOverlay
        }
        .onAppear {
            setupGestureDetection()
        }
    }
    
    // MARK: - Map Content
    
    private func mapContent(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Ocean background with animated waves
            animatedOceanBackground(in: geometry)
            
            // Trade routes
            tradeRoutesLayer
            
            // Ports
            portsLayer(in: geometry)
            
            // Ships
            shipsLayer(in: geometry)
            
            // Selection indicators
            selectionIndicators(in: geometry)
            
            // Route creation preview
            if let routePreview = gestureManager.routePreview {
                routeCreationPreview(routePreview, in: geometry)
            }
        }
    }
    
    private func animatedOceanBackground(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Base ocean color
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.cyan.opacity(0.6),
                    Color.blue.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated wave patterns
            ForEach(0..<3, id: \\.self) { layer in
                WavePattern(
                    amplitude: 20 + CGFloat(layer) * 10,
                    frequency: 0.8 + Double(layer) * 0.3,
                    speed: 1.0 + Double(layer) * 0.5,
                    opacity: 0.1 - Double(layer) * 0.02
                )
                .offset(y: CGFloat(layer) * 5)
            }
        }
    }
    
    private var tradeRoutesLayer: some View {
        ForEach(mapController.tradeRoutes, id: \\.id) { route in
            AnimatedTradeRoute(
                route: route,
                isActive: mapController.activeRoutes.contains(route.id)
            )
        }
    }
    
    private func portsLayer(in geometry: GeometryProxy) -> some View {
        ForEach(ports, id: \\.id) { port in
            AdvancedPortMarker(
                port: port,
                isSelected: selectedPorts.contains(port.id),
                scale: mapController.zoomLevel,
                onTap: {
                    handlePortTap(port.id)
                },
                onLongPress: {
                    handlePortLongPress(port.id)
                }
            )
            .position(
                x: geometry.size.width * CGFloat(port.normalizedPosition.x + 1) / 2,
                y: geometry.size.height * CGFloat(port.normalizedPosition.y + 1) / 2
            )
        }
    }
    
    private func shipsLayer(in geometry: GeometryProxy) -> some View {
        ForEach(ships, id: \\.id) { ship in
            AdvancedShipMarker(
                ship: ship,
                isSelected: selectedShips.contains(ship.id),
                scale: mapController.zoomLevel,
                onTap: {
                    handleShipTap(ship.id)
                }
            )
            .position(
                x: geometry.size.width * CGFloat(ship.position.x + 1) / 2,
                y: geometry.size.height * CGFloat(ship.position.z + 1) / 2
            )
        }
    }
    
    private func selectionIndicators(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Port selection rings
            ForEach(selectedPorts.compactMap { id in ports.first { $0.id == id } }, id: \\.id) { port in
                SelectionRing(
                    radius: 40,
                    color: .blue,
                    pulseSpeed: 1.5
                )
                .position(
                    x: geometry.size.width * CGFloat(port.normalizedPosition.x + 1) / 2,
                    y: geometry.size.height * CGFloat(port.normalizedPosition.y + 1) / 2
                )
            }
            
            // Ship selection rings
            ForEach(selectedShips.compactMap { id in ships.first { $0.id == id } }, id: \\.id) { ship in
                SelectionRing(
                    radius: 30,
                    color: .green,
                    pulseSpeed: 2.0
                )
                .position(
                    x: geometry.size.width * CGFloat(ship.position.x + 1) / 2,
                    y: geometry.size.height * CGFloat(ship.position.z + 1) / 2
                )
            }
        }
    }
    
    private func routeCreationPreview(_ preview: RoutePreview, in geometry: GeometryProxy) -> some View {
        Path { path in
            let startPos = CGPoint(
                x: geometry.size.width * CGFloat(preview.startPosition.x + 1) / 2,
                y: geometry.size.height * CGFloat(preview.startPosition.y + 1) / 2
            )
            let endPos = CGPoint(
                x: geometry.size.width * CGFloat(preview.endPosition.x + 1) / 2,
                y: geometry.size.height * CGFloat(preview.endPosition.y + 1) / 2
            )
            
            path.move(to: startPos)
            path.addLine(to: endPos)
        }
        .stroke(
            Color.yellow.opacity(0.8),
            style: StrokeStyle(
                lineWidth: 3,
                lineCap: .round,
                dash: [10, 5]
            )
        )
        .shadow(color: .yellow.opacity(0.3), radius: 3)
    }
    
    // MARK: - Gesture System
    
    private func createAdvancedGesture(in geometry: GeometryProxy) -> some Gesture {
        SimultaneousGesture(
            createPanGesture(),
            SimultaneousGesture(
                createZoomGesture(),
                SimultaneousGesture(
                    createRotationGesture(),
                    createTapGestures(in: geometry)
                )
            )
        )
    }
    
    private func createPanGesture() -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                gestureManager.currentGesture = .pan
                mapController.panOffset = value.translation
                
                // Haptic feedback for significant movement
                let now = Date()
                if now.timeIntervalSince(lastHapticTime) > 0.1 {
                    HapticManager.shared.playSelectionFeedback()
                    lastHapticTime = now
                }
            }
            .onEnded { value in
                mapController.commitPan(value.translation)
                gestureManager.currentGesture = .none
                HapticManager.shared.playImpactFeedback(.light)
            }
    }
    
    private func createZoomGesture() -> some Gesture {
        MagnificationGesture(minimumScaleDelta: 0.1)
            .onChanged { scale in
                gestureManager.currentGesture = .zoom
                mapController.setZoom(scale)
                
                // Haptic feedback for zoom milestones
                let zoomLevel = mapController.zoomLevel
                if abs(zoomLevel - 1.0) < 0.05 || abs(zoomLevel - 2.0) < 0.05 {
                    HapticManager.shared.playImpactFeedback(.medium)
                }
            }
            .onEnded { scale in
                mapController.commitZoom()
                gestureManager.currentGesture = .none
                HapticManager.shared.playImpactFeedback(.medium)
            }
    }
    
    private func createRotationGesture() -> some Gesture {
        RotationGesture(minimumAngleDelta: .degrees(5))
            .onChanged { angle in
                gestureManager.currentGesture = .rotation\n                mapController.setRotation(angle)\n                \n                // Haptic feedback for cardinal directions\n                let normalizedAngle = angle.degrees.truncatingRemainder(dividingBy: 360)\n                if abs(normalizedAngle).truncatingRemainder(dividingBy: 90) < 5 {\n                    HapticManager.shared.playImpactFeedback(.rigid)\n                }\n            }\n            .onEnded { angle in\n                mapController.commitRotation()\n                gestureManager.currentGesture = .none\n                HapticManager.shared.playImpactFeedback(.medium)\n            }\n    }\n    \n    private func createTapGestures(in geometry: GeometryProxy) -> some Gesture {\n        SimultaneousGesture(\n            createSingleTapGesture(in: geometry),\n            SimultaneousGesture(\n                createDoubleTapGesture(in: geometry),\n                createLongPressGesture(in: geometry)\n            )\n        )\n    }\n    \n    private func createSingleTapGesture(in geometry: GeometryProxy) -> some Gesture {\n        TapGesture(count: 1)\n            .onEnded { \n                handleSingleTap()\n            }\n    }\n    \n    private func createDoubleTapGesture(in geometry: GeometryProxy) -> some Gesture {\n        TapGesture(count: 2)\n            .onEnded {\n                handleDoubleTap()\n            }\n    }\n    \n    private func createLongPressGesture(in geometry: GeometryProxy) -> some Gesture {\n        LongPressGesture(minimumDuration: 0.5)\n            .onEnded { _ in\n                handleLongPress()\n            }\n    }\n    \n    // MARK: - Gesture Handlers\n    \n    private func handleGestureChange(_ gesture: GestureType) {\n        switch gesture {\n        case .pan:\n            gestureManager.showPanIndicator()\n        case .zoom:\n            gestureManager.showZoomIndicator()\n        case .rotation:\n            gestureManager.showRotationIndicator()\n        case .none:\n            gestureManager.hideIndicators()\n        }\n    }\n    \n    private func handleSingleTap() {\n        // Clear selections\n        selectedPorts.removeAll()\n        selectedShips.removeAll()\n        HapticManager.shared.playSelectionFeedback()\n    }\n    \n    private func handleDoubleTap() {\n        // Reset view to default\n        mapController.resetView()\n        HapticManager.shared.playImpactFeedback(.heavy)\n    }\n    \n    private func handleLongPress() {\n        // Show gesture helper\n        withAnimation(.spring()) {\n            showingGestureHelper.toggle()\n        }\n        HapticManager.shared.playNotificationFeedback(.success)\n    }\n    \n    private func handlePortTap(_ portId: UUID) {\n        if selectedPorts.contains(portId) {\n            selectedPorts.remove(portId)\n        } else {\n            selectedPorts.insert(portId)\n        }\n        onPortSelected(portId)\n        HapticManager.shared.playGameObjectSelectFeedback()\n    }\n    \n    private func handlePortLongPress(_ portId: UUID) {\n        // Start route creation mode\n        gestureManager.startRouteCreation(from: portId)\n        HapticManager.shared.playActionPattern(.longPress)\n    }\n    \n    private func handleShipTap(_ shipId: UUID) {\n        if selectedShips.contains(shipId) {\n            selectedShips.remove(shipId)\n        } else {\n            selectedShips.insert(shipId)\n        }\n        onShipSelected(shipId)\n        HapticManager.shared.playGameObjectSelectFeedback()\n    }\n    \n    private func setupGestureDetection() {\n        // Configure advanced gesture recognition\n        gestureManager.configureAdvancedGestures()\n    }\n    \n    // MARK: - Overlay Views\n    \n    private var gestureIndicatorOverlay: some View {\n        VStack {\n            Spacer()\n            \n            HStack {\n                Spacer()\n                \n                GestureIndicator(type: gestureManager.currentGesture)\n                    .padding(.trailing, 20)\n                    .padding(.bottom, 20)\n            }\n        }\n    }\n    \n    private var gestureHelperOverlay: some View {\n        VStack {\n            Spacer()\n            \n            PremiumCard {\n                GestureHelperView {\n                    withAnimation(.spring()) {\n                        showingGestureHelper = false\n                    }\n                }\n            }\n            .padding()\n        }\n    }\n    \n    private var controlButtonsOverlay: some View {\n        VStack {\n            HStack {\n                Spacer()\n                \n                VStack(spacing: 12) {\n                    PremiumFloatingActionButton(\n                        icon: \"location.fill\",\n                        color: .blue,\n                        size: 44\n                    ) {\n                        mapController.centerOnPorts()\n                    }\n                    \n                    PremiumFloatingActionButton(\n                        icon: \"questionmark.circle\",\n                        color: .orange,\n                        size: 44\n                    ) {\n                        withAnimation(.spring()) {\n                            showingGestureHelper.toggle()\n                        }\n                    }\n                }\n                .padding(.trailing)\n            }\n            .padding(.top)\n            \n            Spacer()\n        }\n    }\n}\n\n// MARK: - Supporting Views\n\nstruct WavePattern: View {\n    let amplitude: CGFloat\n    let frequency: Double\n    let speed: Double\n    let opacity: Double\n    \n    @State private var phase: Double = 0\n    \n    var body: some View {\n        GeometryReader { geometry in\n            Path { path in\n                let width = geometry.size.width\n                let height = geometry.size.height\n                let midY = height / 2\n                \n                path.move(to: CGPoint(x: 0, y: midY))\n                \n                for x in stride(from: 0, through: width, by: 2) {\n                    let relativeX = x / width\n                    let sine = sin(relativeX * frequency * 2 * .pi + phase)\n                    let y = midY + sine * amplitude\n                    path.addLine(to: CGPoint(x: x, y: y))\n                }\n            }\n            .stroke(\n                Color.white.opacity(opacity),\n                style: StrokeStyle(lineWidth: 2, lineCap: .round)\n            )\n        }\n        .onAppear {\n            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {\n                phase = 2 * .pi\n            }\n        }\n    }\n}\n\nstruct AnimatedTradeRoute: View {\n    let route: TradeRouteVisualization\n    let isActive: Bool\n    \n    @State private var animationPhase: Double = 0\n    \n    var body: some View {\n        Path { path in\n            if route.waypoints.count > 1 {\n                let firstPoint = CGPoint(x: CGFloat(route.waypoints[0].x), y: CGFloat(route.waypoints[0].z))\n                path.move(to: firstPoint)\n                \n                for i in 1..<route.waypoints.count {\n                    let point = CGPoint(x: CGFloat(route.waypoints[i].x), y: CGFloat(route.waypoints[i].z))\n                    path.addLine(to: point)\n                }\n            }\n        }\n        .trim(from: 0, to: isActive ? 1 : 0.3)\n        .stroke(\n            LinearGradient(\n                colors: [\n                    Color(red: route.color.x, green: route.color.y, blue: route.color.z).opacity(0.8),\n                    Color(red: route.color.x, green: route.color.y, blue: route.color.z).opacity(0.4)\n                ],\n                startPoint: .leading,\n                endPoint: .trailing\n            ),\n            style: StrokeStyle(\n                lineWidth: isActive ? 4 : 2,\n                lineCap: .round,\n                dash: isActive ? [] : [10, 5]\n            )\n        )\n        .shadow(\n            color: Color(red: route.color.x, green: route.color.y, blue: route.color.z).opacity(0.3),\n            radius: isActive ? 6 : 2\n        )\n        .onAppear {\n            if isActive {\n                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {\n                    animationPhase = 1\n                }\n            }\n        }\n    }\n}\n\nstruct AdvancedPortMarker: View {\n    let port: EnhancedPort\n    let isSelected: Bool\n    let scale: CGFloat\n    let onTap: () -> Void\n    let onLongPress: () -> Void\n    \n    @State private var isAnimating = false\n    \n    var body: some View {\n        ZStack {\n            // Main port marker\n            Circle()\n                .fill(\n                    RadialGradient(\n                        colors: [\n                            portColor.opacity(0.9),\n                            portColor.opacity(0.6)\n                        ],\n                        center: .topLeading,\n                        startRadius: 2,\n                        endRadius: 15\n                    )\n                )\n                .frame(width: markerSize, height: markerSize)\n                .overlay(\n                    Circle()\n                        .stroke(\n                            Color.white.opacity(0.8),\n                            lineWidth: 2\n                        )\n                )\n                .shadow(\n                    color: portColor.opacity(0.4),\n                    radius: isSelected ? 8 : 4,\n                    x: 0,\n                    y: 2\n                )\n            \n            // Port icon\n            Image(systemName: portIcon)\n                .font(.system(size: iconSize, weight: .semibold))\n                .foregroundColor(.white)\n            \n            // Activity indicator\n            if port.activity > 0.7 {\n                Circle()\n                    .fill(Color.green)\n                    .frame(width: 8, height: 8)\n                    .offset(x: markerSize/2 - 4, y: -markerSize/2 + 4)\n                    .scaleEffect(isAnimating ? 1.2 : 0.8)\n                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)\n            }\n        }\n        .scaleEffect(isSelected ? 1.3 : 1.0)\n        .scaleEffect(scale > 1.5 ? 1.0 : max(0.5, scale))\n        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)\n        .onTapGesture {\n            onTap()\n        }\n        .onLongPressGesture {\n            onLongPress()\n        }\n        .onAppear {\n            isAnimating = true\n        }\n    }\n    \n    private var markerSize: CGFloat {\n        let baseSize: CGFloat = 24\n        let importanceMultiplier = 1 + (port.importance - 0.5) * 0.5\n        return baseSize * importanceMultiplier\n    }\n    \n    private var iconSize: CGFloat {\n        markerSize * 0.5\n    }\n    \n    private var portColor: Color {\n        switch port.type {\n        case .sea: return .blue\n        case .air: return .orange\n        case .rail: return .brown\n        case .multimodal: return .purple\n        default: return .gray\n        }\n    }\n    \n    private var portIcon: String {\n        switch port.type {\n        case .sea: return \"ferry.fill\"\n        case .air: return \"airplane\"\n        case .rail: return \"tram.fill\"\n        case .multimodal: return \"point.3.connected.trianglepath.dotted\"\n        default: return \"location.fill\"\n        }\n    }\n}\n\nstruct AdvancedShipMarker: View {\n    let ship: ShipVisualization\n    let isSelected: Bool\n    let scale: CGFloat\n    let onTap: () -> Void\n    \n    @State private var rotationAngle: Double = 0\n    \n    var body: some View {\n        ZStack {\n            // Ship wake trail\n            Ellipse()\n                .fill(\n                    LinearGradient(\n                        colors: [\n                            Color.white.opacity(0.4),\n                            Color.clear\n                        ],\n                        startPoint: .leading,\n                        endPoint: .trailing\n                    )\n                )\n                .frame(width: 30, height: 8)\n                .offset(x: -15)\n            \n            // Ship marker\n            RoundedRectangle(cornerRadius: 4)\n                .fill(\n                    LinearGradient(\n                        colors: [shipColor, shipColor.opacity(0.7)],\n                        startPoint: .topLeading,\n                        endPoint: .bottomTrailing\n                    )\n                )\n                .frame(width: shipSize.width, height: shipSize.height)\n                .overlay(\n                    RoundedRectangle(cornerRadius: 4)\n                        .stroke(Color.white.opacity(0.8), lineWidth: 1)\n                )\n                .shadow(\n                    color: shipColor.opacity(0.3),\n                    radius: isSelected ? 6 : 3,\n                    x: 0,\n                    y: 2\n                )\n            \n            // Ship icon\n            Image(systemName: shipIcon)\n                .font(.system(size: 10, weight: .bold))\n                .foregroundColor(.white)\n        }\n        .rotationEffect(.degrees(rotationAngle))\n        .scaleEffect(isSelected ? 1.2 : 1.0)\n        .scaleEffect(scale > 1.5 ? 1.0 : max(0.6, scale))\n        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)\n        .onTapGesture {\n            onTap()\n        }\n        .onAppear {\n            // Animate ship movement\n            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {\n                rotationAngle = 360\n            }\n        }\n    }\n    \n    private var shipSize: CGSize {\n        let baseWidth: CGFloat = 16\n        let baseHeight: CGFloat = 8\n        let scaleMultiplier = ship.scale\n        return CGSize(\n            width: baseWidth * scaleMultiplier,\n            height: baseHeight * scaleMultiplier\n        )\n    }\n    \n    private var shipColor: Color {\n        switch ship.shipType {\n        case .container: return .blue\n        case .bulk: return .brown\n        case .tanker: return .red\n        case .general: return .green\n        }\n    }\n    \n    private var shipIcon: String {\n        switch ship.shipType {\n        case .container: return \"shippingbox.fill\"\n        case .bulk: return \"cube.fill\"\n        case .tanker: return \"drop.fill\"\n        case .general: return \"ferry.fill\"\n        }\n    }\n}\n\nstruct SelectionRing: View {\n    let radius: CGFloat\n    let color: Color\n    let pulseSpeed: Double\n    \n    @State private var isPulsing = false\n    \n    var body: some View {\n        Circle()\n            .stroke(\n                color.opacity(0.6),\n                style: StrokeStyle(lineWidth: 3, dash: [8, 4])\n            )\n            .frame(width: radius * 2, height: radius * 2)\n            .scaleEffect(isPulsing ? 1.1 : 0.9)\n            .opacity(isPulsing ? 0.8 : 0.4)\n            .animation(\n                .easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true),\n                value: isPulsing\n            )\n            .onAppear {\n                isPulsing = true\n            }\n    }\n}\n\nstruct GestureIndicator: View {\n    let type: GestureType\n    \n    var body: some View {\n        Group {\n            switch type {\n            case .pan:\n                panIndicator\n            case .zoom:\n                zoomIndicator\n            case .rotation:\n                rotationIndicator\n            case .none:\n                EmptyView()\n            }\n        }\n        .transition(.scale.combined(with: .opacity))\n    }\n    \n    private var panIndicator: some View {\n        HStack(spacing: 8) {\n            Image(systemName: \"hand.draw\")\n                .font(.system(size: 16, weight: .semibold))\n            Text(\"Pan\")\n                .font(.caption)\n        }\n        .padding(.horizontal, 12)\n        .padding(.vertical, 6)\n        .background(\n            Capsule()\n                .fill(.ultraThinMaterial)\n        )\n        .foregroundColor(.primary)\n    }\n    \n    private var zoomIndicator: some View {\n        HStack(spacing: 8) {\n            Image(systemName: \"magnifyingglass\")\n                .font(.system(size: 16, weight: .semibold))\n            Text(\"Zoom\")\n                .font(.caption)\n        }\n        .padding(.horizontal, 12)\n        .padding(.vertical, 6)\n        .background(\n            Capsule()\n                .fill(.ultraThinMaterial)\n        )\n        .foregroundColor(.primary)\n    }\n    \n    private var rotationIndicator: some View {\n        HStack(spacing: 8) {\n            Image(systemName: \"rotate.right\")\n                .font(.system(size: 16, weight: .semibold))\n            Text(\"Rotate\")\n                .font(.caption)\n        }\n        .padding(.horizontal, 12)\n        .padding(.vertical, 6)\n        .background(\n            Capsule()\n                .fill(.ultraThinMaterial)\n        )\n        .foregroundColor(.primary)\n    }\n}\n\nstruct GestureHelperView: View {\n    let onDismiss: () -> Void\n    \n    var body: some View {\n        VStack(alignment: .leading, spacing: 16) {\n            HStack {\n                Text(\"Gesture Controls\")\n                    .font(.headline)\n                    .fontWeight(.bold)\n                \n                Spacer()\n                \n                Button(action: onDismiss) {\n                    Image(systemName: \"xmark.circle.fill\")\n                        .font(.title2)\n                        .foregroundColor(.secondary)\n                }\n            }\n            \n            VStack(alignment: .leading, spacing: 12) {\n                gestureHelpItem(\n                    icon: \"hand.draw\",\n                    title: \"Pan\",\n                    description: \"Drag to move the map\"\n                )\n                \n                gestureHelpItem(\n                    icon: \"magnifyingglass\",\n                    title: \"Zoom\",\n                    description: \"Pinch to zoom in/out\"\n                )\n                \n                gestureHelpItem(\n                    icon: \"rotate.right\",\n                    title: \"Rotate\",\n                    description: \"Two-finger twist to rotate\"\n                )\n                \n                gestureHelpItem(\n                    icon: \"hand.tap\",\n                    title: \"Select\",\n                    description: \"Tap ports or ships to select\"\n                )\n                \n                gestureHelpItem(\n                    icon: \"hand.point.up.left\",\n                    title: \"Route Creation\",\n                    description: \"Long press port to start route\"\n                )\n                \n                gestureHelpItem(\n                    icon: \"hand.tap.fill\",\n                    title: \"Reset View\",\n                    description: \"Double tap to reset view\"\n                )\n            }\n        }\n        .padding()\n    }\n    \n    private func gestureHelpItem(icon: String, title: String, description: String) -> some View {\n        HStack(spacing: 12) {\n            Image(systemName: icon)\n                .font(.system(size: 16, weight: .semibold))\n                .foregroundColor(.blue)\n                .frame(width: 24)\n            \n            VStack(alignment: .leading, spacing: 2) {\n                Text(title)\n                    .font(.subheadline)\n                    .fontWeight(.semibold)\n                \n                Text(description)\n                    .font(.caption)\n                    .foregroundColor(.secondary)\n            }\n            \n            Spacer()\n        }\n    }\n}\n\n// MARK: - Supporting Classes\n\nclass GestureManager: ObservableObject {\n    @Published var currentGesture: GestureType = .none\n    @Published var showIndicator = false\n    @Published var routePreview: RoutePreview?\n    \n    private var indicatorTimer: Timer?\n    \n    func showPanIndicator() {\n        showGestureIndicator()\n    }\n    \n    func showZoomIndicator() {\n        showGestureIndicator()\n    }\n    \n    func showRotationIndicator() {\n        showGestureIndicator()\n    }\n    \n    private func showGestureIndicator() {\n        showIndicator = true\n        indicatorTimer?.invalidate()\n        indicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in\n            DispatchQueue.main.async {\n                self.hideIndicators()\n            }\n        }\n    }\n    \n    func hideIndicators() {\n        showIndicator = false\n        indicatorTimer?.invalidate()\n    }\n    \n    func startRouteCreation(from portId: UUID) {\n        // Implementation for route creation\n    }\n    \n    func configureAdvancedGestures() {\n        // Configure advanced gesture recognition\n    }\n}\n\nclass MapController: ObservableObject {\n    @Published var zoomLevel: CGFloat = 1.0\n    @Published var panOffset: CGSize = .zero\n    @Published var rotationAngle: Angle = .zero\n    @Published var tradeRoutes: [TradeRouteVisualization] = []\n    @Published var activeRoutes: Set<UUID> = []\n    \n    private var baseZoom: CGFloat = 1.0\n    private var basePan: CGSize = .zero\n    private var baseRotation: Angle = .zero\n    \n    func setZoom(_ scale: CGFloat) {\n        zoomLevel = baseZoom * scale\n    }\n    \n    func commitZoom() {\n        baseZoom = zoomLevel\n    }\n    \n    func commitPan(_ translation: CGSize) {\n        basePan.width += translation.width\n        basePan.height += translation.height\n        panOffset = basePan\n    }\n    \n    func setRotation(_ angle: Angle) {\n        rotationAngle = baseRotation + angle\n    }\n    \n    func commitRotation() {\n        baseRotation = rotationAngle\n    }\n    \n    func resetView() {\n        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {\n            zoomLevel = 1.0\n            panOffset = .zero\n            rotationAngle = .zero\n        }\n        baseZoom = 1.0\n        basePan = .zero\n        baseRotation = .zero\n    }\n    \n    func centerOnPorts() {\n        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {\n            panOffset = .zero\n            zoomLevel = 1.2\n        }\n        basePan = .zero\n        baseZoom = 1.2\n    }\n}\n\n// MARK: - Supporting Types\n\nenum GestureType {\n    case none\n    case pan\n    case zoom\n    case rotation\n}\n\nstruct RoutePreview {\n    let startPosition: SIMD2<Float>\n    let endPosition: SIMD2<Float>\n}\n\n// MARK: - HapticManager Extensions\n\nextension HapticManager {\n    func playGameObjectSelectFeedback() {\n        playHapticPattern(.gameObjectSelect)\n    }\n    \n    func playActionPattern(_ action: ActionType) {\n        switch action {\n        case .longPress:\n            playHapticPattern(.dragBegan)\n        case .routeCreation:\n            playHapticPattern(.tradeSuccess)\n        case .selection:\n            playHapticPattern(.selection)\n        }\n    }\n}\n\nenum ActionType {\n    case longPress\n    case routeCreation\n    case selection\n}