import SwiftUI
import SceneKit
import Combine

/// Interactive 3D Port Visualization with detailed harbor models
struct Interactive3DPortView: View {
    let port: EnhancedPort
    @State private var sceneView = SCNView()
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var portNode = SCNNode()
    @State private var shipsNode = SCNNode()
    @State private var facilitiesNode = SCNNode()
    
    @State private var isLoading = true
    @State private var selectedFacility: PortFacility?
    @State private var animationTimer: Timer?
    @State private var shipAnimations: [SCNNode] = []
    
    @GestureState private var dragOffset = CGSize.zero
    @State private var lastRotation: CGFloat = 0
    @State private var currentRotation: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 3D Scene View
            SceneKitView(scene: scene, cameraNode: cameraNode)
                .onAppear {
                    setupScene()
                    startAnimations()
                }
                .onDisappear {
                    stopAnimations()
                }
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                            HapticManager.shared.playSelectionFeedback()
                        }
                        .onChanged { value in
                            let rotationSpeed: CGFloat = 0.01
                            currentRotation = lastRotation + value.translation.x * rotationSpeed
                            rotateCamera()
                        }
                        .onEnded { value in
                            lastRotation = currentRotation
                            HapticManager.shared.playImpactFeedback(.medium)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomCamera(scale: Float(value))
                            HapticManager.shared.playSelectionFeedback()
                        }
                )
            
            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    PremiumCard {
                        VStack(spacing: 16) {
                            PremiumProgressIndicator(
                                progress: 0.7,
                                color: .blue,
                                size: 60
                            )
                            
                            Text("Building 3D Port Model")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(port.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    .frame(width: 200, height: 150)
                }
                .transition(.opacity)
            }
            
            // Port Information Overlay
            VStack {
                HStack {
                    PremiumCard {
                        PortInfoPanel(port: port, selectedFacility: $selectedFacility)
                    }
                    .frame(width: 300)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Control Panel
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        PremiumFloatingActionButton(
                            icon: "camera.rotate",
                            color: .blue,
                            size: 50
                        ) {
                            resetCamera()
                        }
                        
                        PremiumFloatingActionButton(
                            icon: "play.fill",
                            color: .green,
                            size: 50
                        ) {
                            toggleShipAnimations()
                        }
                        
                        PremiumFloatingActionButton(
                            icon: "info.circle",
                            color: .orange,
                            size: 50
                        ) {
                            showPortDetails()
                        }
                    }
                    .padding()
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        scene.background.contents = createSkybox()
        scene.lightingEnvironment.contents = createSkybox()
        scene.lightingEnvironment.intensity = 0.3
        
        setupCamera()
        setupLighting()
        createPortInfrastructure()
        createWaterSurface()
        createShips()
        
        // Simulate loading time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
    
    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.automaticallyAdjustsZRange = true
        cameraNode.position = SCNVector3(x: 50, y: 30, z: 50)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func setupLighting() {
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.3, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Directional light (sun)
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = UIColor(white: 0.8, alpha: 1.0)
        sunLight.castsShadow = true
        sunLight.shadowRadius = 5
        sunLight.shadowColor = UIColor.black.withAlphaComponent(0.3)
        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.position = SCNVector3(x: 100, y: 100, z: 50)
        sunNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(sunNode)
    }
    
    private func createPortInfrastructure() {
        portNode.name = "PortInfrastructure"
        scene.rootNode.addChildNode(portNode)
        facilitiesNode.name = "Facilities"
        portNode.addChildNode(facilitiesNode)
        
        // Create main port structures
        createDocks()
        createWarehouses()
        createCranes()
        createContainerYards()
        createPortBuildings()
        
        // Create facilities based on port type and available facilities
        for facility in port.facilities {
            createFacility(facility)
        }
    }
    
    private func createDocks() {
        for i in 0..<5 {
            let dock = SCNNode()
            dock.name = "Dock_\\(i)"
            
            // Dock platform
            let platformGeometry = SCNBox(width: 200, height: 2, length: 20, chamferRadius: 0)
            platformGeometry.firstMaterial?.diffuse.contents = UIColor.gray
            platformGeometry.firstMaterial?.specular.contents = UIColor.white
            platformGeometry.firstMaterial?.shininess = 0.1
            
            dock.geometry = platformGeometry
            dock.position = SCNVector3(x: 0, y: 1, z: Float(i * 25 - 50))
            
            // Add dock details
            addDockDetails(to: dock)
            
            facilitiesNode.addChildNode(dock)
        }
    }
    
    private func addDockDetails(to dock: SCNNode) {
        // Bollards
        for j in 0..<10 {
            let bollard = SCNNode()
            let bollardGeometry = SCNCylinder(radius: 0.5, height: 3)
            bollardGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
            bollard.geometry = bollardGeometry
            bollard.position = SCNVector3(x: Float(j * 20 - 90), y: 2.5, z: 8)
            dock.addChildNode(bollard)
        }
        
        // Fenders
        for j in 0..<8 {
            let fender = SCNNode()
            let fenderGeometry = SCNBox(width: 3, height: 2, length: 8, chamferRadius: 0.5)
            fenderGeometry.firstMaterial?.diffuse.contents = UIColor.black
            fender.geometry = fenderGeometry
            fender.position = SCNVector3(x: Float(j * 25 - 87.5), y: 0, z: 10)
            dock.addChildNode(fender)
        }
    }
    
    private func createWarehouses() {
        for i in 0..<3 {
            let warehouse = SCNNode()
            warehouse.name = "Warehouse_\\(i)"
            
            let warehouseGeometry = SCNBox(width: 80, height: 15, length: 40, chamferRadius: 1)
            warehouseGeometry.firstMaterial?.diffuse.contents = UIColor.lightGray
            warehouseGeometry.firstMaterial?.normal.contents = UIImage(named: "metal_normal")
            
            warehouse.geometry = warehouseGeometry
            warehouse.position = SCNVector3(x: Float(i * 100 - 100), y: 7.5, z: -80)
            
            // Add warehouse details
            addWarehouseDetails(to: warehouse)
            
            facilitiesNode.addChildNode(warehouse)
        }
    }
    
    private func addWarehouseDetails(to warehouse: SCNNode) {
        // Roof details
        let roof = SCNNode()
        let roofGeometry = SCNBox(width: 82, height: 1, length: 42, chamferRadius: 0.5)
        roofGeometry.firstMaterial?.diffuse.contents = UIColor.red
        roof.geometry = roofGeometry
        roof.position = SCNVector3(x: 0, y: 8, z: 0)
        warehouse.addChildNode(roof)
        
        // Loading doors
        for j in 0..<4 {
            let door = SCNNode()
            let doorGeometry = SCNBox(width: 8, height: 12, length: 0.5, chamferRadius: 0)
            doorGeometry.firstMaterial?.diffuse.contents = UIColor.brown
            door.geometry = doorGeometry
            door.position = SCNVector3(x: Float(j * 15 - 22.5), y: -1.5, z: 20.25)
            warehouse.addChildNode(door)
        }
    }
    
    private func createCranes() {
        for i in 0..<3 {
            let crane = SCNNode()
            crane.name = "Crane_\\(i)"
            
            // Crane base
            let baseGeometry = SCNCylinder(radius: 3, height: 5)
            baseGeometry.firstMaterial?.diffuse.contents = UIColor.yellow
            let base = SCNNode(geometry: baseGeometry)
            base.position = SCNVector3(x: 0, y: 2.5, z: 0)
            crane.addChildNode(base)
            
            // Crane mast
            let mastGeometry = SCNCylinder(radius: 0.8, height: 60)
            mastGeometry.firstMaterial?.diffuse.contents = UIColor.yellow
            let mast = SCNNode(geometry: mastGeometry)
            mast.position = SCNVector3(x: 0, y: 32.5, z: 0)
            crane.addChildNode(mast)
            
            // Crane arm
            let armGeometry = SCNBox(width: 50, height: 2, length: 3, chamferRadius: 0)
            armGeometry.firstMaterial?.diffuse.contents = UIColor.yellow
            let arm = SCNNode(geometry: armGeometry)
            arm.position = SCNVector3(x: 0, y: 60, z: 0)
            crane.addChildNode(arm)
            
            // Position crane
            crane.position = SCNVector3(x: Float(i * 80 - 80), y: 0, z: 30)
            
            // Add crane animation
            let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20)
            let repeatAction = SCNAction.repeatForever(rotateAction)
            crane.runAction(repeatAction)
            
            facilitiesNode.addChildNode(crane)
        }
    }
    
    private func createContainerYards() {
        // Container stacks
        for row in 0..<8 {
            for col in 0..<12 {
                if Int.random(in: 0...100) < 70 { // 70% chance of container
                    let stackHeight = Int.random(in: 1...4)
                    
                    for level in 0..<stackHeight {
                        let container = SCNNode()
                        let containerGeometry = SCNBox(width: 6, height: 2.5, length: 12, chamferRadius: 0.1)
                        
                        // Random container colors
                        let colors = [UIColor.red, UIColor.blue, UIColor.green, UIColor.orange, UIColor.purple]
                        containerGeometry.firstMaterial?.diffuse.contents = colors.randomElement()
                        containerGeometry.firstMaterial?.specular.contents = UIColor.white
                        containerGeometry.firstMaterial?.shininess = 0.3
                        
                        container.geometry = containerGeometry
                        container.position = SCNVector3(
                            x: Float(col * 8 - 44),
                            y: Float(level) * 2.5 + 1.25,
                            z: Float(row * 8 - 120)
                        )
                        
                        facilitiesNode.addChildNode(container)
                    }
                }
            }
        }
    }
    
    private func createPortBuildings() {
        // Port authority building
        let portBuilding = SCNNode()
        portBuilding.name = "PortAuthority"
        
        let buildingGeometry = SCNBox(width: 30, height: 20, length: 20, chamferRadius: 1)
        buildingGeometry.firstMaterial?.diffuse.contents = UIColor.white
        buildingGeometry.firstMaterial?.specular.contents = UIColor.lightGray
        
        portBuilding.geometry = buildingGeometry
        portBuilding.position = SCNVector3(x: -120, y: 10, z: -60)
        
        // Add building details
        addBuildingDetails(to: portBuilding)
        
        facilitiesNode.addChildNode(portBuilding)
    }
    
    private func addBuildingDetails(to building: SCNNode) {
        // Windows
        for floor in 0..<3 {
            for window in 0..<6 {
                let windowNode = SCNNode()
                let windowGeometry = SCNBox(width: 3, height: 4, length: 0.2, chamferRadius: 0)
                windowGeometry.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.7)
                windowGeometry.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.3)
                windowNode.geometry = windowGeometry
                windowNode.position = SCNVector3(
                    x: Float(window * 4 - 10),
                    y: Float(floor * 6 - 4),
                    z: 10.1
                )
                building.addChildNode(windowNode)
            }
        }
    }
    
    private func createFacility(_ facility: PortFacility) {
        let facilityNode = SCNNode()
        facilityNode.name = facility.rawValue
        
        switch facility {
        case .containerTerminal:
            createContainerTerminal(facilityNode)
        case .bulkTerminal:
            createBulkTerminal(facilityNode)
        case .liquidBulkTerminal:
            createLiquidBulkTerminal(facilityNode)
        case .roroTerminal:
            createRoRoTerminal(facilityNode)
        case .cruiseTerminal:
            createCruiseTerminal(facilityNode)
        case .drydock:
            createDryDock(facilityNode)
        default:
            createGenericFacility(facilityNode, type: facility)
        }
        
        facilitiesNode.addChildNode(facilityNode)
    }
    
    private func createContainerTerminal(_ node: SCNNode) {
        // Already handled in createContainerYards
        node.position = SCNVector3(x: 0, y: 0, z: -120)
    }
    
    private func createBulkTerminal(_ node: SCNNode) {
        let terminal = SCNNode()
        let terminalGeometry = SCNCylinder(radius: 15, height: 30)
        terminalGeometry.firstMaterial?.diffuse.contents = UIColor.brown
        terminal.geometry = terminalGeometry
        terminal.position = SCNVector3(x: 150, y: 15, z: -50)
        node.addChildNode(terminal)
    }
    
    private func createLiquidBulkTerminal(_ node: SCNNode) {
        for i in 0..<3 {
            let tank = SCNNode()
            let tankGeometry = SCNCylinder(radius: 8, height: 20)
            tankGeometry.firstMaterial?.diffuse.contents = UIColor.silver
            tankGeometry.firstMaterial?.metalness.contents = UIColor.white
            tank.geometry = tankGeometry
            tank.position = SCNVector3(x: Float(i * 20 + 140), y: 10, z: 20)
            node.addChildNode(tank)
        }
    }
    
    private func createRoRoTerminal(_ node: SCNNode) {
        let ramp = SCNNode()
        let rampGeometry = SCNBox(width: 30, height: 2, length: 60, chamferRadius: 0)
        rampGeometry.firstMaterial?.diffuse.contents = UIColor.gray
        ramp.geometry = rampGeometry
        ramp.position = SCNVector3(x: -150, y: 1, z: 0)
        ramp.eulerAngles = SCNVector3(x: -0.1, y: 0, z: 0)
        node.addChildNode(ramp)
    }
    
    private func createCruiseTerminal(_ node: SCNNode) {
        let terminal = SCNNode()
        let terminalGeometry = SCNBox(width: 100, height: 12, length: 30, chamferRadius: 2)
        terminalGeometry.firstMaterial?.diffuse.contents = UIColor.white
        terminal.geometry = terminalGeometry
        terminal.position = SCNVector3(x: 0, y: 6, z: 80)
        node.addChildNode(terminal)
    }
    
    private func createDryDock(_ node: SCNNode) {
        // Dry dock basin
        let basin = SCNNode()
        let basinGeometry = SCNBox(width: 200, height: 20, length: 50, chamferRadius: 0)
        basinGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
        basin.geometry = basinGeometry
        basin.position = SCNVector3(x: 200, y: -10, z: 0)
        node.addChildNode(basin)
        
        // Dock gates
        let gate = SCNNode()
        let gateGeometry = SCNBox(width: 5, height: 25, length: 50, chamferRadius: 0)
        gateGeometry.firstMaterial?.diffuse.contents = UIColor.red
        gate.geometry = gateGeometry
        gate.position = SCNVector3(x: 100, y: 2.5, z: 0)
        node.addChildNode(gate)
    }
    
    private func createGenericFacility(_ node: SCNNode, type: PortFacility) {
        let facility = SCNNode()
        let facilityGeometry = SCNBox(width: 20, height: 10, length: 15, chamferRadius: 1)
        facilityGeometry.firstMaterial?.diffuse.contents = UIColor.lightGray
        facility.geometry = facilityGeometry
        facility.position = SCNVector3(x: Float.random(in: -100...100), y: 5, z: Float.random(in: -100...100))
        node.addChildNode(facility)
    }
    
    private func createWaterSurface() {
        let water = SCNNode()
        let waterGeometry = SCNPlane(width: 1000, height: 1000)
        
        // Create animated water material
        let waterMaterial = SCNMaterial()
        waterMaterial.diffuse.contents = UIColor.blue.withAlphaComponent(0.7)
        waterMaterial.specular.contents = UIColor.white
        waterMaterial.shininess = 0.8
        waterMaterial.transparency = 0.7
        waterMaterial.normal.contents = UIImage(named: "water_normal")
        waterMaterial.normal.intensity = 0.5
        
        waterGeometry.firstMaterial = waterMaterial
        water.geometry = waterGeometry
        water.position = SCNVector3(x: 0, y: -5, z: 0)
        water.eulerAngles = SCNVector3(x: -Float.pi/2, y: 0, z: 0)
        
        // Animate water
        let waveAction = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 2),
            SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 2)
        ])
        water.runAction(SCNAction.repeatForever(waveAction))
        
        scene.rootNode.addChildNode(water)
    }
    
    private func createShips() {
        shipsNode.name = "Ships"
        scene.rootNode.addChildNode(shipsNode)
        
        // Create various types of ships
        createContainerShip()
        createBulkCarrier()
        createTanker()
        createTugboat()
    }
    
    private func createContainerShip() {
        let ship = SCNNode()
        ship.name = "ContainerShip"
        
        // Hull
        let hullGeometry = SCNBox(width: 200, height: 20, length: 30, chamferRadius: 2)
        hullGeometry.firstMaterial?.diffuse.contents = UIColor.darkBlue
        let hull = SCNNode(geometry: hullGeometry)
        hull.position = SCNVector3(x: 0, y: 0, z: 0)
        ship.addChildNode(hull)
        
        // Superstructure
        let superstructureGeometry = SCNBox(width: 40, height: 30, length: 20, chamferRadius: 1)
        superstructureGeometry.firstMaterial?.diffuse.contents = UIColor.white
        let superstructure = SCNNode(geometry: superstructureGeometry)
        superstructure.position = SCNVector3(x: -60, y: 15, z: 0)
        ship.addChildNode(superstructure)
        
        // Containers on deck
        for row in 0..<6 {
            for col in 0..<12 {
                let container = SCNNode()
                let containerGeometry = SCNBox(width: 6, height: 2.5, length: 12, chamferRadius: 0.1)
                let colors = [UIColor.red, UIColor.blue, UIColor.green, UIColor.yellow]
                containerGeometry.firstMaterial?.diffuse.contents = colors.randomElement()
                container.geometry = containerGeometry
                container.position = SCNVector3(
                    x: Float(col * 7 - 35),
                    y: Float(row * 2.5 + 11.25),
                    z: Float((col % 2 == 0 ? -8 : 8))
                )
                ship.addChildNode(container)
            }
        }
        
        ship.position = SCNVector3(x: -200, y: -2, z: 20)
        shipAnimations.append(ship)
        shipsNode.addChildNode(ship)
    }
    
    private func createBulkCarrier() {
        let ship = SCNNode()
        ship.name = "BulkCarrier"
        
        let hullGeometry = SCNBox(width: 180, height: 18, length: 28, chamferRadius: 2)
        hullGeometry.firstMaterial?.diffuse.contents = UIColor.brown
        ship.geometry = hullGeometry
        ship.position = SCNVector3(x: 250, y: -2, z: -30)
        
        shipAnimations.append(ship)
        shipsNode.addChildNode(ship)
    }
    
    private func createTanker() {
        let ship = SCNNode()
        ship.name = "Tanker"
        
        let hullGeometry = SCNBox(width: 250, height: 22, length: 35, chamferRadius: 3)
        hullGeometry.firstMaterial?.diffuse.contents = UIColor.red
        ship.geometry = hullGeometry
        ship.position = SCNVector3(x: 0, y: -2, z: -100)
        
        shipAnimations.append(ship)
        shipsNode.addChildNode(ship)
    }
    
    private func createTugboat() {
        let tug = SCNNode()
        tug.name = "Tugboat"
        
        let hullGeometry = SCNBox(width: 25, height: 8, length: 12, chamferRadius: 1)
        hullGeometry.firstMaterial?.diffuse.contents = UIColor.orange
        tug.geometry = hullGeometry
        tug.position = SCNVector3(x: -50, y: -2, z: 50)
        
        shipAnimations.append(tug)
        shipsNode.addChildNode(tug)
    }
    
    private func createSkybox() -> UIImage? {
        // Create a simple gradient skybox
        let size = CGSize(width: 512, height: 512)
        UIGraphicsBeginImageContext(size)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.blue.cgColor, UIColor.cyan.cgColor]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)
        
        context.drawLinearGradient(gradient!, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    // MARK: - Camera Controls
    
    private func rotateCamera() {
        let rotation = SCNMatrix4MakeRotation(Float(currentRotation), 0, 1, 0)
        let currentTransform = cameraNode.transform
        let newTransform = SCNMatrix4Mult(rotation, currentTransform)
        cameraNode.transform = newTransform
    }
    
    private func zoomCamera(scale: Float) {
        let currentPosition = cameraNode.position
        let distance = sqrt(currentPosition.x * currentPosition.x + currentPosition.z * currentPosition.z)
        let newDistance = distance / scale
        let ratio = newDistance / distance
        
        cameraNode.position = SCNVector3(
            x: currentPosition.x * ratio,
            y: currentPosition.y,
            z: currentPosition.z * ratio
        )
    }
    
    private func resetCamera() {
        HapticManager.shared.playImpactFeedback(.medium)
        
        let resetAction = SCNAction.group([
            SCNAction.move(to: SCNVector3(x: 50, y: 30, z: 50), duration: 1.0),
            SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0)
        ])
        
        cameraNode.runAction(resetAction) {
            self.cameraNode.look(at: SCNVector3(0, 0, 0))
        }
        
        currentRotation = 0
        lastRotation = 0
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateAnimations()
        }
    }
    
    private func stopAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimations() {
        // Animate ships moving
        for ship in shipAnimations {
            let currentPosition = ship.position
            ship.position = SCNVector3(
                x: currentPosition.x + Float.random(in: -0.1...0.1),
                y: currentPosition.y + sin(Float(Date().timeIntervalSince1970)) * 0.2,
                z: currentPosition.z + Float.random(in: -0.1...0.1)
            )
        }
    }
    
    private func toggleShipAnimations() {
        HapticManager.shared.playImpactFeedback(.medium)
        
        if animationTimer != nil {
            stopAnimations()
        } else {
            startAnimations()
        }
    }
    
    private func showPortDetails() {
        HapticManager.shared.playNotificationFeedback(.success)
        // Implement detailed port information view
    }
}

// MARK: - Port Information Panel

struct PortInfoPanel: View {
    let port: EnhancedPort
    @Binding var selectedFacility: PortFacility?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Port header
            HStack {
                VStack(alignment: .leading) {
                    Text(port.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(port.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                VStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // Port statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Port Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Importance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        PremiumProgressIndicator(
                            progress: Double(port.importance),
                            color: .blue,
                            size: 40
                        )
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        PremiumProgressIndicator(
                            progress: Double(port.activity),
                            color: .green,
                            size: 40
                        )
                    }
                }
            }
            
            Divider()
            
            // Facilities
            VStack(alignment: .leading, spacing: 8) {
                Text("Facilities")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(port.facilities), id: \\.rawValue) { facility in
                        PremiumFacilityBadge(
                            facility: facility,
                            isSelected: selectedFacility == facility
                        ) {
                            selectedFacility = facility
                            HapticManager.shared.playSelectionFeedback()
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PremiumFacilityBadge: View {
    let facility: PortFacility
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: facilityIcon(facility))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(facility.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
    
    private func facilityIcon(_ facility: PortFacility) -> String {
        switch facility {
        case .containerTerminal: return "shippingbox"
        case .bulkTerminal: return "pyramid"
        case .liquidBulkTerminal: return "drop.circle"
        case .roroTerminal: return "car"
        case .cruiseTerminal: return "ferry"
        case .drydock: return "wrench.and.screwdriver"
        case .pilotage: return "location.circle"
        case .tugboats: return "boat"
        case .bunkerFueling: return "fuelpump"
        case .wasteDisposal: return "trash.circle"
        }
    }
}

// MARK: - SceneKit View Wrapper

struct SceneKitView: UIViewRepresentable {
    let scene: SCNScene
    let cameraNode: SCNNode
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = cameraNode
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor.clear
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update the view if needed
    }
}