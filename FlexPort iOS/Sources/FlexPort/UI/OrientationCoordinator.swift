import SwiftUI
import Combine

// MARK: - Orientation Coordinator
class OrientationCoordinator: ObservableObject {
    @Published var currentOrientation: UIDeviceOrientation = .portrait
    @Published var isTransitioning = false
    @Published var gameState: GameStateSnapshot?
    
    private var orientationObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupOrientationObserver()
    }
    
    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupOrientationObserver() {
        // Listen for orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange()
        }
        
        // Set initial orientation
        currentOrientation = UIDevice.current.orientation
        if !currentOrientation.isValidInterfaceOrientation {
            currentOrientation = .portrait
        }
    }
    
    private func handleOrientationChange() {
        let newOrientation = UIDevice.current.orientation
        
        // Only handle valid interface orientations
        guard newOrientation.isValidInterfaceOrientation,
              newOrientation != currentOrientation else { return }
        
        // Save current state before transition
        saveGameState()
        
        // Begin transition
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isTransitioning = true
            currentOrientation = newOrientation
        }
        
        // End transition after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            withAnimation {
                self?.isTransitioning = false
            }
        }
    }
    
    private func saveGameState() {
        // Capture current view state
        gameState = GameStateSnapshot(
            selectedShipId: nil, // Would be passed from view
            selectedPortId: nil, // Would be passed from view
            mapCenter: nil, // Would be passed from view
            zoomLevel: 1.0
        )
    }
    
    func restoreGameState() -> GameStateSnapshot? {
        return gameState
    }
}

// MARK: - Game State Snapshot
struct GameStateSnapshot {
    let selectedShipId: String?
    let selectedPortId: String?
    let mapCenter: (latitude: Double, longitude: Double)?
    let zoomLevel: Double
}

// MARK: - Adaptive Game Container
struct AdaptiveGameContainer: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var orientationCoordinator = OrientationCoordinator()
    @State private var selectedShip: Ship?
    @State private var selectedPort: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Content based on orientation
                if orientationCoordinator.isTransitioning {
                    // Transition overlay
                    TransitionOverlay()
                        .transition(.opacity)
                } else {
                    if isLandscape(geometry: geometry) {
                        // Landscape - Full map view
                        LandscapeMapView()
                            .environmentObject(gameManager)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .onAppear {
                                restoreStateForLandscape()
                            }
                    } else {
                        // Portrait - Dashboard view
                        PortraitGameView()
                            .environmentObject(gameManager)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .onAppear {
                                restoreStateForPortrait()
                            }
                    }
                }
                
                // Rotation hint (shown briefly when appropriate)
                if shouldShowRotationHint {
                    RotationHintOverlay()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .environmentObject(orientationCoordinator)
        .statusBarHidden(isLandscape(geometry: UIScreen.main.bounds.size))
    }
    
    private func isLandscape(geometry: CGSize) -> Bool {
        return geometry.width > geometry.height
    }
    
    private func isLandscape(geometry: GeometryProxy) -> Bool {
        return geometry.size.width > geometry.size.height
    }
    
    private func restoreStateForLandscape() {
        if let snapshot = orientationCoordinator.restoreGameState() {
            // Restore selected items and map position
            if let shipId = snapshot.selectedShipId {
                selectedShip = gameManager.gameState.playerAssets.ships.first { $0.id.uuidString == shipId }
            }
            selectedPort = snapshot.selectedPortId
        }
    }
    
    private func restoreStateForPortrait() {
        if let snapshot = orientationCoordinator.restoreGameState() {
            // Restore selected items for portrait view
            if let shipId = snapshot.selectedShipId {
                selectedShip = gameManager.gameState.playerAssets.ships.first { $0.id.uuidString == shipId }
            }
        }
    }
    
    private var shouldShowRotationHint: Bool {
        // Show hint on first launch or after certain conditions
        return false // Implement logic based on user preferences
    }
}

// MARK: - Transition Overlay
struct TransitionOverlay: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Blur background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Rotating icon
                Image(systemName: "rotate.right")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 0.6)) {
                            rotation = 90
                        }
                    }
                
                Text("Switching View")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Rotation Hint Overlay
struct RotationHintOverlay: View {
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            VStack {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.title2)
                        
                        Image(systemName: "arrow.turn.up.right")
                            .font(.caption)
                        
                        Image(systemName: "iphone.landscape")
                            .font(.title2)
                        
                        Text("Rotate for map view")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                    )
                    .padding()
                }
                
                Spacer()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}

// MARK: - Orientation Lock Manager
class OrientationLockManager {
    static let shared = OrientationLockManager()
    
    private var currentLock: UIInterfaceOrientationMask = .all
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        currentLock = orientation
        
        // Force orientation update
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }
    
    func unlockOrientation() {
        lockOrientation(.all)
    }
    
    var supportedOrientations: UIInterfaceOrientationMask {
        return currentLock
    }
}

// MARK: - UIDevice Extension
extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        switch self {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }
}

// MARK: - Smooth Transition Modifier
struct SmoothOrientationTransition: ViewModifier {
    @EnvironmentObject var orientationCoordinator: OrientationCoordinator
    
    func body(content: Content) -> some View {
        content
            .animation(
                orientationCoordinator.isTransitioning ? .spring(response: 0.6, dampingFraction: 0.8) : .none,
                value: orientationCoordinator.currentOrientation
            )
    }
}

extension View {
    func smoothOrientationTransition() -> some View {
        modifier(SmoothOrientationTransition())
    }
}