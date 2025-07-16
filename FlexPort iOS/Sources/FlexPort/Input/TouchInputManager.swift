import UIKit
import Combine
import simd

/// Main touch input manager that handles all touch interactions using UIGestureRecognizer
public class TouchInputManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentTouches: Set<TouchData> = []
    @Published public private(set) var activeGestures: Set<GestureType> = []
    @Published public private(set) var touchState: TouchState = .idle
    
    // MARK: - Publishers for reactive programming
    public let touchBegan = PassthroughSubject<TouchEvent, Never>()
    public let touchMoved = PassthroughSubject<TouchEvent, Never>()
    public let touchEnded = PassthroughSubject<TouchEvent, Never>()
    public let gestureBegan = PassthroughSubject<GestureEvent, Never>()
    public let gestureChanged = PassthroughSubject<GestureEvent, Never>()
    public let gestureEnded = PassthroughSubject<GestureEvent, Never>()
    
    // MARK: - Dependencies
    private let gestureDetector: GestureDetector
    private let hapticManager: HapticManager
    private let inputOptimizer: InputOptimizer
    
    // MARK: - Internal State
    private var targetView: UIView?
    private var cancellables = Set<AnyCancellable>()
    private var touchHistory: [TouchData] = []
    private let maxTouchHistory = 60 // Store last 60 touch events for gesture recognition
    
    // MARK: - Gesture Recognizers
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        return tap
    }()
    
    private lazy var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delegate = self
        return longPress
    }()
    
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        return pan
    }()
    
    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        return pinch
    }()
    
    // MARK: - Initialization
    public init(hapticManager: HapticManager = HapticManager.shared,
                gestureDetector: GestureDetector = GestureDetector(),
                inputOptimizer: InputOptimizer = InputOptimizer()) {
        self.hapticManager = hapticManager
        self.gestureDetector = gestureDetector
        self.inputOptimizer = inputOptimizer
        
        setupGestureDetectorBindings()
        setupOptimization()
    }
    
    // MARK: - Public Interface
    
    /// Attach touch input handling to a specific view
    public func attachToView(_ view: UIView) {
        detachFromCurrentView()
        
        targetView = view
        view.addGestureRecognizer(tapGestureRecognizer)
        view.addGestureRecognizer(longPressGestureRecognizer)
        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(pinchGestureRecognizer)
        
        // Enable simultaneous gestures where appropriate
        tapGestureRecognizer.require(toFail: longPressGestureRecognizer)
        
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
    }
    
    /// Detach from current view
    public func detachFromCurrentView() {
        guard let view = targetView else { return }
        
        view.removeGestureRecognizer(tapGestureRecognizer)
        view.removeGestureRecognizer(longPressGestureRecognizer)
        view.removeGestureRecognizer(panGestureRecognizer)
        view.removeGestureRecognizer(pinchGestureRecognizer)
        
        targetView = nil
        clearTouchState()
    }
    
    /// Convert screen coordinates to world coordinates
    public func screenToWorld(_ screenPoint: CGPoint, in view: UIView) -> SIMD2<Float> {
        return inputOptimizer.convertScreenToWorld(screenPoint, in: view)
    }
    
    /// Convert world coordinates to screen coordinates
    public func worldToScreen(_ worldPoint: SIMD2<Float>, in view: UIView) -> CGPoint {
        return inputOptimizer.convertWorldToScreen(worldPoint, in: view)
    }
    
    // MARK: - Private Methods
    
    private func setupGestureDetectorBindings() {
        gestureDetector.complexGestureDetected
            .sink { [weak self] gestureEvent in
                self?.handleComplexGesture(gestureEvent)
            }
            .store(in: &cancellables)
    }
    
    private func setupOptimization() {
        inputOptimizer.optimizedTouchEvent
            .sink { [weak self] touchEvent in
                self?.processTouchEvent(touchEvent)
            }
            .store(in: &cancellables)
    }
    
    private func clearTouchState() {
        currentTouches.removeAll()
        activeGestures.removeAll()
        touchState = .idle
        touchHistory.removeAll()
    }
    
    private func processTouchEvent(_ event: TouchEvent) {
        // Update touch history for gesture recognition
        if touchHistory.count >= maxTouchHistory {
            touchHistory.removeFirst()
        }
        touchHistory.append(event.touchData)
        
        // Pass to gesture detector for complex gesture analysis
        gestureDetector.processTouchData(event.touchData, history: touchHistory)
        
        // Update current touches
        switch event.phase {
        case .began:
            currentTouches.insert(event.touchData)
            touchBegan.send(event)
            
        case .moved:
            if let existingTouch = currentTouches.first(where: { $0.id == event.touchData.id }) {
                currentTouches.remove(existingTouch)
                currentTouches.insert(event.touchData)
            }
            touchMoved.send(event)
            
        case .ended, .cancelled:
            currentTouches.remove(event.touchData)
            touchEnded.send(event)
        }
        
        // Update touch state
        updateTouchState()
    }
    
    private func updateTouchState() {
        if currentTouches.isEmpty {
            touchState = .idle
        } else if currentTouches.count == 1 {
            touchState = .singleTouch
        } else {
            touchState = .multiTouch
        }
    }
    
    private func handleComplexGesture(_ gestureEvent: GestureEvent) {
        activeGestures.insert(gestureEvent.type)
        
        switch gestureEvent.state {
        case .began:
            gestureBegan.send(gestureEvent)
            hapticManager.playSelectionFeedback()
            
        case .changed:
            gestureChanged.send(gestureEvent)
            
        case .ended:
            gestureEnded.send(gestureEvent)
            activeGestures.remove(gestureEvent.type)
            hapticManager.playImpactFeedback(.light)
            
        case .cancelled:
            activeGestures.remove(gestureEvent.type)
            
        case .failed:
            activeGestures.remove(gestureEvent.type)
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        let worldPos = screenToWorld(location, in: recognizer.view!)
        
        let gestureEvent = GestureEvent(
            type: .tap,
            state: recognizer.state == .ended ? .ended : .began,
            location: worldPos,
            timestamp: Date(),
            properties: [
                "tapCount": recognizer.numberOfTapsRequired,
                "screenLocation": location
            ]
        )
        
        handleComplexGesture(gestureEvent)
    }
    
    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        let worldPos = screenToWorld(location, in: recognizer.view!)
        
        let gestureEvent = GestureEvent(
            type: .longPress,
            state: recognizer.state,
            location: worldPos,
            timestamp: Date(),
            properties: [
                "duration": Date().timeIntervalSince(recognizer.minimumPressDuration.timeInterval),
                "screenLocation": location
            ]
        )
        
        handleComplexGesture(gestureEvent)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        let worldPos = screenToWorld(location, in: recognizer.view!)
        
        let gestureEvent = GestureEvent(
            type: .pan,
            state: recognizer.state,
            location: worldPos,
            timestamp: Date(),
            properties: [
                "translation": translation,
                "velocity": velocity,
                "numberOfTouches": recognizer.numberOfTouches,
                "screenLocation": location
            ]
        )
        
        handleComplexGesture(gestureEvent)
    }
    
    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        let location = recognizer.location(in: recognizer.view)
        let worldPos = screenToWorld(location, in: recognizer.view!)
        
        let gestureEvent = GestureEvent(
            type: .pinch,
            state: recognizer.state,
            location: worldPos,
            timestamp: Date(),
            properties: [
                "scale": recognizer.scale,
                "velocity": recognizer.velocity,
                "numberOfTouches": recognizer.numberOfTouches,
                "screenLocation": location
            ]
        )
        
        handleComplexGesture(gestureEvent)
        
        // Reset scale to get incremental changes
        recognizer.scale = 1.0
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TouchInputManager: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan and pinch to work together
        if (gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == pinchGestureRecognizer) ||
           (gestureRecognizer == pinchGestureRecognizer && otherGestureRecognizer == panGestureRecognizer) {
            return true
        }
        
        return false
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow input optimizer to filter gestures if needed
        return inputOptimizer.shouldAllowGesture(gestureRecognizer)
    }
}

// MARK: - Supporting Types

public struct TouchData: Hashable, Identifiable {
    public let id: UUID
    public let screenPosition: CGPoint
    public let worldPosition: SIMD2<Float>
    public let timestamp: Date
    public let force: Float
    public let radius: Float
    
    public init(id: UUID = UUID(), 
                screenPosition: CGPoint, 
                worldPosition: SIMD2<Float>, 
                timestamp: Date = Date(),
                force: Float = 1.0,
                radius: Float = 10.0) {
        self.id = id
        self.screenPosition = screenPosition
        self.worldPosition = worldPosition
        self.timestamp = timestamp
        self.force = force
        self.radius = radius
    }
}

public struct TouchEvent {
    public let touchData: TouchData
    public let phase: TouchPhase
    public let timestamp: Date
    
    public init(touchData: TouchData, phase: TouchPhase, timestamp: Date = Date()) {
        self.touchData = touchData
        self.phase = phase
        self.timestamp = timestamp
    }
}

public enum TouchPhase {
    case began
    case moved
    case ended
    case cancelled
}

public enum TouchState {
    case idle
    case singleTouch
    case multiTouch
}

public struct GestureEvent {
    public let type: GestureType
    public let state: UIGestureRecognizer.State
    public let location: SIMD2<Float>
    public let timestamp: Date
    public let properties: [String: Any]
    
    public init(type: GestureType, 
                state: UIGestureRecognizer.State, 
                location: SIMD2<Float>, 
                timestamp: Date = Date(),
                properties: [String: Any] = [:]) {
        self.type = type
        self.state = state
        self.location = location
        self.timestamp = timestamp
        self.properties = properties
    }
}

public enum GestureType: String, CaseIterable, Hashable {
    case tap
    case longPress
    case pan
    case pinch
    case swipe
    case rotation
    case twoFingerTap
    case threeFingerTap
    case fourFingerTap
    case edgePan
    case hover
    
    public var priority: Int {
        switch self {
        case .tap: return 1
        case .longPress: return 2
        case .pan: return 3
        case .pinch: return 4
        case .swipe: return 2
        case .rotation: return 4
        case .twoFingerTap: return 2
        case .threeFingerTap: return 2
        case .fourFingerTap: return 2
        case .edgePan: return 3
        case .hover: return 1
        }
    }
}

// MARK: - Extensions

private extension TimeInterval {
    var timeInterval: TimeInterval { return self }
}