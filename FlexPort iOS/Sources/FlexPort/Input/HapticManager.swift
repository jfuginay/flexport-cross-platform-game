import UIKit
import CoreHaptics
import AVFoundation
import Combine

/// Advanced haptic feedback manager using CoreHaptics for rich tactile experiences
public class HapticManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = HapticManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isHapticsAvailable: Bool = false
    @Published public private(set) var isHapticsEnabled: Bool = true
    @Published public private(set) var hapticIntensity: Float = 1.0
    
    // MARK: - Core Haptics
    private var hapticEngine: CHHapticEngine?
    private var engineStarted: Bool = false
    
    // MARK: - Legacy Haptics (for devices without CoreHaptics)
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator()
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Pattern Library
    private var patternLibrary: [HapticPattern: CHHapticPattern] = [:]
    
    // MARK: - Configuration
    public struct Configuration {
        public var defaultIntensity: Float = 1.0
        public var defaultSharpness: Float = 0.5
        public var enableAdaptiveHaptics: Bool = true
        public var enableLegacyFallback: Bool = true
        public var maxConcurrentPatterns: Int = 3
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - Private Properties
    private var activePatterns: Set<UUID> = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupHapticEngine()
        setupNotifications()
        prepareFeedbackGenerators()
    }
    
    // MARK: - Public Interface
    
    /// Enable or disable haptic feedback
    public func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        
        if enabled && isHapticsAvailable {
            startHapticEngine()
        } else {
            stopHapticEngine()
        }
    }
    
    /// Set global haptic intensity (0.0 - 1.0)
    public func setHapticIntensity(_ intensity: Float) {
        hapticIntensity = max(0.0, min(1.0, intensity))
    }
    
    /// Play simple impact feedback (legacy compatible)
    public func playImpactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isHapticsEnabled else { return }
        
        if isHapticsAvailable && engineStarted {
            playAdvancedImpact(style)
        } else {
            // Fallback to UIImpactFeedbackGenerator
            impactFeedbackGenerator.impactOccurred(intensity: CGFloat(hapticIntensity))
        }
    }
    
    /// Play selection feedback
    public func playSelectionFeedback() {
        guard isHapticsEnabled else { return }
        
        if isHapticsAvailable && engineStarted {
            playHapticPattern(.selection)
        } else {
            selectionFeedbackGenerator.selectionChanged()
        }
    }
    
    /// Play notification feedback
    public func playNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        guard isHapticsEnabled else { return }
        
        if isHapticsAvailable && engineStarted {
            let pattern: HapticPattern
            switch type {
            case .success:
                pattern = .success
            case .warning:
                pattern = .warning
            case .error:
                pattern = .error
            @unknown default:
                pattern = .success
            }
            playHapticPattern(pattern)
        } else {
            notificationFeedbackGenerator.notificationOccurred(type)
        }
    }
    
    /// Play advanced haptic pattern
    public func playHapticPattern(_ pattern: HapticPattern, intensity: Float? = nil) {
        guard isHapticsEnabled && isHapticsAvailable && engineStarted else { return }
        
        let effectiveIntensity = intensity ?? hapticIntensity
        
        if let hapticPattern = patternLibrary[pattern] {
            playPattern(hapticPattern, intensity: effectiveIntensity)
        } else {
            // Create pattern on demand
            createAndPlayPattern(pattern, intensity: effectiveIntensity)
        }
    }
    
    /// Play custom haptic sequence
    public func playHapticSequence(_ sequence: HapticSequence) {
        guard isHapticsEnabled && isHapticsAvailable && engineStarted else { return }
        
        Task {
            for item in sequence.items {
                await playSequenceItem(item)
                if item.delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(item.delay * 1_000_000_000))
                }
            }
        }
    }
    
    /// Create custom haptic pattern from events
    public func createCustomPattern(events: [HapticEvent]) -> CHHapticPattern? {
        guard isHapticsAvailable else { return nil }
        
        var hapticEvents: [CHHapticEvent] = []
        
        for event in events {
            let hapticEvent = createHapticEvent(from: event)
            hapticEvents.append(hapticEvent)
        }
        
        do {
            return try CHHapticPattern(events: hapticEvents, parameters: [])
        } catch {
            print("Failed to create custom haptic pattern: \(error)")
            return nil
        }
    }
    
    // MARK: - Game-Specific Haptics
    
    /// Haptic feedback for ship selection
    public func playShipSelectionFeedback() {
        playHapticPattern(.gameObjectSelect)
    }
    
    /// Haptic feedback for successful trade
    public func playTradeSuccessFeedback() {
        playHapticPattern(.tradeSuccess)
    }
    
    /// Haptic feedback for failed action
    public func playActionFailedFeedback() {
        playHapticPattern(.actionFailed)
    }
    
    /// Haptic feedback for route completion
    public func playRouteCompletionFeedback() {
        playHapticPattern(.routeComplete)
    }
    
    /// Haptic feedback for UI navigation
    public func playNavigationFeedback() {
        playHapticPattern(.uiNavigation)
    }
    
    /// Haptic feedback for drag and drop
    public func playDragDropFeedback(_ phase: DragDropPhase) {
        switch phase {
        case .began:
            playHapticPattern(.dragBegan)
        case .dropped:
            playHapticPattern(.dragDropped)
        case .cancelled:
            playHapticPattern(.dragCancelled)
        }
    }
    
    // MARK: - Logistics-Specific Haptic Feedback Methods
    
    /// Haptic feedback for ship engine operations
    public func playShipEngineFeedback(starting: Bool) {
        playHapticPattern(starting ? .shipEngineStart : .shipEngineStop)
    }
    
    /// Haptic feedback for cargo operations
    public func playCargoOperationFeedback(loading: Bool) {
        playHapticPattern(loading ? .cargoLoading : .cargoUnloading)
    }
    
    /// Haptic feedback for port operations
    public func playPortOperationFeedback(arriving: Bool) {
        playHapticPattern(arriving ? .portArrival : .portDeparture)
    }
    
    /// Haptic feedback for route drawing
    public func playRouteDrawingFeedback(completed: Bool = false) {
        playHapticPattern(completed ? .routeDrawingComplete : .routeDrawing)
    }
    
    /// Haptic feedback for market events
    public func playMarketFeedback(crash: Bool = false) {
        playHapticPattern(crash ? .marketCrash : .marketFluctuation)
    }
    
    /// Haptic feedback for competitive actions
    public func playCompetitorFeedback() {
        playHapticPattern(.competitorAction)
    }
    
    /// Haptic feedback for weather events
    public func playWeatherFeedback(severe: Bool = false) {
        playHapticPattern(severe ? .stormEncounter : .weatherWarning)
    }
    
    /// Haptic feedback for emergency situations
    public func playEmergencyFeedback(type: EmergencyType) {
        switch type {
        case .general:
            playHapticPattern(.emergencyAlert)
        case .collision:
            playHapticPattern(.shipCollision)
        case .pirate:
            playHapticPattern(.pirateAttack)
        case .navigation:
            playHapticPattern(.navigationHazard)
        }
    }
    
    /// Haptic feedback for contract operations
    public func playContractFeedback(signed: Bool) {
        playHapticPattern(signed ? .contractSigned : .contractFailed)
    }
    
    /// Haptic feedback for ship maintenance operations
    public func playMaintenanceFeedback(type: MaintenanceType) {
        switch type {
        case .general:
            playHapticPattern(.shipMaintenance)
        case .fuel:
            playHapticPattern(.fuelRefill)
        case .crew:
            playHapticPattern(.crewChange)
        }
    }
    
    /// Haptic feedback for financial operations
    public func playFinancialFeedback(profit: Bool) {
        playHapticPattern(profit ? .profitGain : .profitLoss)
    }
    
    /// Haptic feedback for warehouse operations
    public func playWarehouseFeedback() {
        playHapticPattern(.warehouseActivity)
    }
    
    /// Haptic feedback for delivery operations
    public func playDeliveryFeedback(success: Bool) {
        playHapticPattern(success ? .deliverySuccess : .deliveryDelay)
    }
    
    /// Haptic feedback for discovery and upgrades
    public func playDiscoveryFeedback(type: DiscoveryType) {
        switch type {
        case .resource:
            playHapticPattern(.resourceDiscovery)
        case .technology:
            playHapticPattern(.technologyUpgrade)
        }
    }
    
    /// Haptic feedback for alliance operations
    public func playAllianceFeedback(formed: Bool) {
        playHapticPattern(formed ? .allianceFormed : .allianceBroken)
    }
    
    /// Complex haptic feedback for ship movement based on speed and conditions
    public func playShipMovementFeedback(speed: Float, seaConditions: SeaCondition = .calm) {
        let baseIntensity = min(0.8, speed / 100.0) // Normalize speed to 0-0.8 intensity
        
        switch seaConditions {
        case .calm:
            // Gentle, rhythmic feedback
            let sequence = HapticSequence(items: [
                HapticSequenceItem(type: .pattern(.shipEngineStart), intensity: baseIntensity * 0.5, delay: 0),
                HapticSequenceItem(type: .pattern(.shipEngineStart), intensity: baseIntensity * 0.6, delay: 1.0),
                HapticSequenceItem(type: .pattern(.shipEngineStart), intensity: baseIntensity * 0.5, delay: 1.0)
            ])
            playHapticSequence(sequence)
            
        case .rough:
            // Irregular, more intense feedback
            let sequence = HapticSequence(items: [
                HapticSequenceItem(type: .pattern(.stormEncounter), intensity: baseIntensity * 0.8, delay: 0),
                HapticSequenceItem(type: .pattern(.weatherWarning), intensity: baseIntensity * 0.6, delay: 0.5),
                HapticSequenceItem(type: .pattern(.stormEncounter), intensity: baseIntensity * 0.9, delay: 0.8)
            ])
            playHapticSequence(sequence)
            
        case .stormy:
            // Chaotic, intense feedback
            let sequence = HapticSequence(items: [
                HapticSequenceItem(type: .pattern(.stormEncounter), intensity: baseIntensity, delay: 0),
                HapticSequenceItem(type: .pattern(.emergencyAlert), intensity: baseIntensity * 0.7, delay: 0.3),
                HapticSequenceItem(type: .pattern(.stormEncounter), intensity: baseIntensity, delay: 0.6),
                HapticSequenceItem(type: .pattern(.weatherWarning), intensity: baseIntensity * 0.8, delay: 0.9)
            ])
            playHapticSequence(sequence)
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isHapticsAvailable = false
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            isHapticsAvailable = true
            
            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.engineStarted = false
                print("Haptic engine stopped: \(reason)")
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartHapticEngine()
            }
            
            // Pre-load common patterns
            createPatternLibrary()
            
        } catch {
            print("Failed to create haptic engine: \(error)")
            isHapticsAvailable = false
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.startHapticEngine()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.stopHapticEngine()
            }
            .store(in: &cancellables)
    }
    
    private func prepareFeedbackGenerators() {
        impactFeedbackGenerator.prepare()
        selectionFeedbackGenerator.prepare()
        notificationFeedbackGenerator.prepare()
    }
    
    private func startHapticEngine() {
        guard let engine = hapticEngine, !engineStarted else { return }
        
        do {
            try engine.start()
            engineStarted = true
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    private func stopHapticEngine() {
        hapticEngine?.stop()
        engineStarted = false
        activePatterns.removeAll()
    }
    
    private func restartHapticEngine() {
        stopHapticEngine()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startHapticEngine()
        }
    }
    
    private func createPatternLibrary() {
        // Create common haptic patterns
        patternLibrary[.selection] = createSelectionPattern()
        patternLibrary[.success] = createSuccessPattern()
        patternLibrary[.warning] = createWarningPattern()
        patternLibrary[.error] = createErrorPattern()
        patternLibrary[.gameObjectSelect] = createGameObjectSelectPattern()
        patternLibrary[.tradeSuccess] = createTradeSuccessPattern()
        patternLibrary[.actionFailed] = createActionFailedPattern()
        patternLibrary[.routeComplete] = createRouteCompletePattern()
        patternLibrary[.uiNavigation] = createUINavigationPattern()
        patternLibrary[.dragBegan] = createDragBeganPattern()
        patternLibrary[.dragDropped] = createDragDroppedPattern()
        patternLibrary[.dragCancelled] = createDragCancelledPattern()
        
        // Create logistics-specific patterns
        createLogisticsPatterns()
    }
    
    private func createLogisticsPatterns() {
        patternLibrary[.shipEngineStart] = createShipEngineStartPattern()
        patternLibrary[.shipEngineStop] = createShipEngineStopPattern()
        patternLibrary[.cargoLoading] = createCargoLoadingPattern()
        patternLibrary[.cargoUnloading] = createCargoUnloadingPattern()
        patternLibrary[.portArrival] = createPortArrivalPattern()
        patternLibrary[.portDeparture] = createPortDeparturePattern()
        patternLibrary[.routeDrawing] = createRouteDrawingPattern()
        patternLibrary[.routeDrawingComplete] = createRouteDrawingCompletePattern()
        patternLibrary[.marketFluctuation] = createMarketFluctuationPattern()
        patternLibrary[.marketCrash] = createMarketCrashPattern()
        patternLibrary[.competitorAction] = createCompetitorActionPattern()
        patternLibrary[.weatherWarning] = createWeatherWarningPattern()
        patternLibrary[.emergencyAlert] = createEmergencyAlertPattern()
        patternLibrary[.contractSigned] = createContractSignedPattern()
        patternLibrary[.contractFailed] = createContractFailedPattern()
        patternLibrary[.shipMaintenance] = createShipMaintenancePattern()
        patternLibrary[.fuelRefill] = createFuelRefillPattern()
        patternLibrary[.crewChange] = createCrewChangePattern()
        patternLibrary[.navigationHazard] = createNavigationHazardPattern()
        patternLibrary[.profitGain] = createProfitGainPattern()
        patternLibrary[.profitLoss] = createProfitLossPattern()
        patternLibrary[.warehouseActivity] = createWarehouseActivityPattern()
        patternLibrary[.shipCollision] = createShipCollisionPattern()
        patternLibrary[.pirateAttack] = createPirateAttackPattern()
        patternLibrary[.stormEncounter] = createStormEncounterPattern()
        patternLibrary[.deliverySuccess] = createDeliverySuccessPattern()
        patternLibrary[.deliveryDelay] = createDeliveryDelayPattern()
        patternLibrary[.resourceDiscovery] = createResourceDiscoveryPattern()
        patternLibrary[.technologyUpgrade] = createTechnologyUpgradePattern()
        patternLibrary[.allianceFormed] = createAllianceFormedPattern()
        patternLibrary[.allianceBroken] = createAllianceBrokenPattern()
    }
    
    private func playAdvancedImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let intensity: Float
        let sharpness: Float
        
        switch style {
        case .light:
            intensity = 0.3
            sharpness = 0.3
        case .medium:
            intensity = 0.6
            sharpness = 0.5
        case .heavy:
            intensity = 1.0
            sharpness = 0.7
        case .soft:
            intensity = 0.4
            sharpness = 0.2
        case .rigid:
            intensity = 0.8
            sharpness = 0.9
        @unknown default:
            intensity = 0.6
            sharpness = 0.5
        }
        
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * hapticIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: 0)
        ]
        
        playEvents(events)
    }
    
    private func playPattern(_ pattern: CHHapticPattern, intensity: Float) {
        guard activePatterns.count < configuration.maxConcurrentPatterns else { return }
        
        do {
            let player = try hapticEngine?.makePlayer(with: pattern)
            let patternId = UUID()
            activePatterns.insert(patternId)
            
            player?.completionHandler = { [weak self] _ in
                self?.activePatterns.remove(patternId)
            }
            
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    private func createAndPlayPattern(_ pattern: HapticPattern, intensity: Float) {
        let events = createEventsForPattern(pattern, intensity: intensity)
        playEvents(events)
    }
    
    private func playEvents(_ events: [CHHapticEvent]) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic events: \(error)")
        }
    }
    
    private func createHapticEvent(from event: HapticEvent) -> CHHapticEvent {
        let eventType: CHHapticEvent.EventType = event.type == .transient ? .hapticTransient : .hapticContinuous
        
        var parameters: [CHHapticEventParameter] = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity * hapticIntensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
        ]
        
        if event.type == .continuous {
            parameters.append(CHHapticEventParameter(parameterID: .hapticAttackTime, value: event.attackTime))
            parameters.append(CHHapticEventParameter(parameterID: .hapticDecayTime, value: event.decayTime))
        }
        
        return CHHapticEvent(
            eventType: eventType,
            parameters: parameters,
            relativeTime: event.time,
            duration: event.duration
        )
    }
    
    private func playSequenceItem(_ item: HapticSequenceItem) async {
        switch item.type {
        case .pattern(let pattern):
            playHapticPattern(pattern, intensity: item.intensity)
        case .impact(let style):
            playImpactFeedback(style)
        case .selection:
            playSelectionFeedback()
        case .notification(let type):
            playNotificationFeedback(type)
        }
    }
}

// MARK: - Pattern Creation Methods

extension HapticManager {
    
    private func createSelectionPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createSuccessPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.1)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createWarningPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createErrorPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createGameObjectSelectPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createTradeSuccessPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.15),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ], relativeTime: 0.3)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createActionFailedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0, duration: 0.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createRouteCompletePattern() -> CHHapticPattern? {
        let events = createEventsForPattern(.tradeSuccess, intensity: 1.0)
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createUINavigationPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createDragBeganPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createDragDroppedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createDragCancelledPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createEventsForPattern(_ pattern: HapticPattern, intensity: Float) -> [CHHapticEvent] {
        // This would contain specific event sequences for each pattern type
        // For now, return a default event
        return [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0)
        ]
    }
}

// MARK: - Logistics-Specific Haptic Patterns

extension HapticManager {
    
    // MARK: - Ship Operations
    
    private func createShipEngineStartPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0, duration: 0.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0.6),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.8, duration: 1.0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createShipEngineStopPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0, duration: 1.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 1.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Cargo Operations
    
    private func createCargoLoadingPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate rhythmic loading with 5 pulses
        for i in 0..<5 {
            let time = Double(i) * 0.3
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createCargoUnloadingPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate unloading with decreasing intensity
        for i in 0..<4 {
            let time = Double(i) * 0.4
            let intensity = 0.7 - Float(i) * 0.15
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Port Operations
    
    private func createPortArrivalPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0, duration: 0.8),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 1.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 1.3)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createPortDeparturePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.3, duration: 1.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Route Operations
    
    private func createRouteDrawingPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0, duration: 0.1)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createRouteDrawingCompletePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0.15),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.3)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Market Operations
    
    private func createMarketFluctuationPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate market volatility with irregular pulses
        let timings: [Double] = [0, 0.2, 0.35, 0.6, 0.8]
        let intensities: [Float] = [0.3, 0.6, 0.4, 0.7, 0.5]
        
        for (time, intensity) in zip(timings, intensities) {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createMarketCrashPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.1, duration: 0.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.7),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0.9, duration: 1.0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Competition & Threats
    
    private func createCompetitorActionPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0.1)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createPirateAttackPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate aggressive attack with sharp, erratic pulses
        let timings: [Double] = [0, 0.1, 0.15, 0.3, 0.4, 0.5, 0.7, 0.9]
        
        for time in timings {
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Weather & Environment
    
    private func createWeatherWarningPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 1.0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createStormEncounterPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate chaotic storm with random pulses
        for i in 0..<8 {
            let time = Double(i) * 0.2 + Double.random(in: 0...0.1)
            let intensity = Float.random(in: 0.6...1.0)
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Contracts & Business
    
    private func createContractSignedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.2, duration: 0.8)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createContractFailedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0, duration: 0.3),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0.4, duration: 0.5)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Ship Maintenance & Operations
    
    private func createShipMaintenancePattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate maintenance work with steady rhythm
        for i in 0..<6 {
            let time = Double(i) * 0.4
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: time))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createFuelRefillPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0, duration: 2.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 2.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createCrewChangePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0.3),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0.6)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Hazards & Emergencies
    
    private func createNavigationHazardPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.2)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createEmergencyAlertPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate emergency siren pattern
        for i in 0..<4 {
            let time = Double(i) * 0.4
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: time))
            
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: time + 0.15))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createShipCollisionPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.1, duration: 1.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 1.3)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Financial Operations
    
    private func createProfitGainPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.2),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ], relativeTime: 0.4, duration: 0.6)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createProfitLossPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0, duration: 0.8),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 1.0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Warehouse & Storage
    
    private func createWarehouseActivityPattern() -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        
        // Simulate warehouse machinery
        for i in 0..<3 {
            let time = Double(i) * 0.6
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: time, duration: 0.4))
        }
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Delivery Operations
    
    private func createDeliverySuccessPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.15),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.3)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createDeliveryDelayPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.2, duration: 0.8)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Discovery & Upgrades
    
    private func createResourceDiscoveryPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.3, duration: 1.0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 1.5)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createTechnologyUpgradePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0, duration: 1.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 1.7),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 2.0, duration: 0.8)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Alliance Operations
    
    private func createAllianceFormedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0.3),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.6, duration: 1.0)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
    
    private func createAllianceBrokenPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0, duration: 0.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.6),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0.8, duration: 0.8)
        ]
        
        return try? CHHapticPattern(events: events, parameters: [])
    }
}

// MARK: - Supporting Types

public enum HapticPattern: String, CaseIterable {
    case selection
    case success
    case warning
    case error
    case gameObjectSelect
    case tradeSuccess
    case actionFailed
    case routeComplete
    case uiNavigation
    case dragBegan
    case dragDropped
    case dragCancelled
    
    // MARK: - Logistics-Specific Patterns
    case shipEngineStart
    case shipEngineStop
    case cargoLoading
    case cargoUnloading
    case portArrival
    case portDeparture
    case routeDrawing
    case routeDrawingComplete
    case marketFluctuation
    case marketCrash
    case competitorAction
    case weatherWarning
    case emergencyAlert
    case contractSigned
    case contractFailed
    case shipMaintenance
    case fuelRefill
    case crewChange
    case navigationHazard
    case profitGain
    case profitLoss
    case warehouseActivity
    case shipCollision
    case pirateAttack
    case stormEncounter
    case deliverySuccess
    case deliveryDelay
    case resourceDiscovery
    case technologyUpgrade
    case allianceFormed
    case allianceBroken
}

public enum DragDropPhase {
    case began
    case dropped
    case cancelled
}

public struct HapticEvent {
    public let type: HapticEventType
    public let time: TimeInterval
    public let duration: TimeInterval
    public let intensity: Float
    public let sharpness: Float
    public let attackTime: Float
    public let decayTime: Float
    
    public init(type: HapticEventType, 
                time: TimeInterval, 
                duration: TimeInterval = 0, 
                intensity: Float = 1.0, 
                sharpness: Float = 0.5,
                attackTime: Float = 0.1,
                decayTime: Float = 0.1) {
        self.type = type
        self.time = time
        self.duration = duration
        self.intensity = intensity
        self.sharpness = sharpness
        self.attackTime = attackTime
        self.decayTime = decayTime
    }
}

public enum HapticEventType {
    case transient
    case continuous
}

public struct HapticSequence {
    public let items: [HapticSequenceItem]
    
    public init(items: [HapticSequenceItem]) {
        self.items = items
    }
}

public struct HapticSequenceItem {
    public let type: HapticSequenceItemType
    public let intensity: Float
    public let delay: TimeInterval
    
    public init(type: HapticSequenceItemType, intensity: Float = 1.0, delay: TimeInterval = 0) {
        self.type = type
        self.intensity = intensity
        self.delay = delay
    }
}

public enum HapticSequenceItemType {
    case pattern(HapticPattern)
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case selection
    case notification(UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - Logistics-Specific Enums

public enum EmergencyType {
    case general
    case collision
    case pirate
    case navigation
}

public enum MaintenanceType {
    case general
    case fuel
    case crew
}

public enum DiscoveryType {
    case resource
    case technology
}

public enum SeaCondition {
    case calm
    case rough
    case stormy
    
    public var hapticIntensityMultiplier: Float {
        switch self {
        case .calm: return 0.5
        case .rough: return 0.8
        case .stormy: return 1.0
        }
    }
    
    public var hapticFrequencyMultiplier: Float {
        switch self {
        case .calm: return 0.5
        case .rough: return 1.0
        case .stormy: return 1.5
        }
    }
}