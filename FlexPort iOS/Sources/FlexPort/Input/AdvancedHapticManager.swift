import UIKit
import CoreHaptics
import Combine

// MARK: - Advanced Haptic Manager

/// Advanced haptic feedback system for immersive disaster and gameplay events
public class AdvancedHapticManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AdvancedHapticManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isHapticsEnabled: Bool = true
    @Published public private(set) var hapticIntensity: Float = 1.0
    @Published public private(set) var isAdvancedHapticsSupported: Bool = false
    
    // MARK: - Core Haptics
    private var hapticEngine: CHHapticEngine?
    private var engineNeedsRestart = false
    
    // MARK: - Haptic Players
    private var continuousPlayers: [HapticPatternType: CHHapticAdvancedPatternPlayer] = [:]
    private var patternPlayers: [UUID: CHHapticPatternPlayer] = [:]
    
    // MARK: - Disaster Haptic Patterns
    private var disasterPatterns: [DisasterEffectComponent.DisasterType: CHHapticPattern] = [:]
    private var activeDisasterHaptics: [UUID: DisasterHapticInstance] = [:]
    
    // MARK: - Configuration
    public struct HapticConfiguration {
        public var enableDisasterHaptics: Bool = true
        public var enableEmergencyHaptics: Bool = true
        public var enableSuccessHaptics: Bool = true
        public var enableAmbientHaptics: Bool = false
        public var intensityMultiplier: Float = 1.0
        public var maxConcurrentPatterns: Int = 5
        
        public init() {}
    }
    
    public var configuration = HapticConfiguration()
    
    // MARK: - Notification Integration
    private let hapticEventSubject = PassthroughSubject<HapticEvent, Never>()
    public var hapticEvents: AnyPublisher<HapticEvent, Never> {
        hapticEventSubject.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupHapticEngine()
        setupNotificationObservers()
        createDisasterPatterns()
    }
    
    // MARK: - Public Interface
    
    /// Initialize and start the haptic engine
    public func startHapticEngine() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            throw HapticError.unsupportedDevice
        }
        
        if hapticEngine == nil {
            setupHapticEngine()
        }
        
        try hapticEngine?.start()
        isAdvancedHapticsSupported = true
        
        print("Advanced Haptic Engine started successfully")
    }
    
    /// Stop the haptic engine
    public func stopHapticEngine() {
        hapticEngine?.stop()
        stopAllContinuousHaptics()
        print("Advanced Haptic Engine stopped")
    }
    
    /// Enable or disable haptic feedback
    public func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        
        if !enabled {
            stopAllContinuousHaptics()
        }
    }
    
    /// Set global haptic intensity
    public func setHapticIntensity(_ intensity: Float) {
        hapticIntensity = max(0.0, min(1.0, intensity))
        configuration.intensityMultiplier = hapticIntensity
    }
    
    // MARK: - Disaster Haptic Effects
    
    /// Play haptic feedback for disaster events
    public func playDisasterHaptic(
        _ disasterType: DisasterEffectComponent.DisasterType,
        intensity: Float,
        duration: TimeInterval,
        position: CGPoint? = nil
    ) -> UUID? {
        guard isHapticsEnabled && configuration.enableDisasterHaptics else { return nil }
        
        let hapticId = UUID()
        let adjustedIntensity = intensity * configuration.intensityMultiplier
        
        switch disasterType {
        case .hurricane:
            playHurricaneHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .tsunami:
            playTsunamiHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .earthquake:
            playEarthquakeHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .storm:
            playStormHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .fire:
            playFireHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .piracy:
            playPiracyHaptic(id: hapticId, intensity: adjustedIntensity)
        case .cyberAttack:
            playCyberAttackHaptic(id: hapticId, intensity: adjustedIntensity)
        case .flooding:
            playFloodingHaptic(id: hapticId, intensity: adjustedIntensity, duration: duration)
        case .fog:
            // Fog doesn't typically have strong haptic feedback
            return nil
        }
        
        // Track active disaster haptic
        let disasterInstance = DisasterHapticInstance(
            id: hapticId,
            type: disasterType,
            intensity: adjustedIntensity,
            duration: duration,
            startTime: Date()
        )
        activeDisasterHaptics[hapticId] = disasterInstance
        
        // Schedule cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopDisasterHaptic(hapticId)
        }
        
        hapticEventSubject.send(.disasterStarted(disasterType, adjustedIntensity))
        
        return hapticId
    }
    
    /// Update ongoing disaster haptic intensity
    public func updateDisasterHaptic(_ hapticId: UUID, intensity: Float) {
        guard let disasterInstance = activeDisasterHaptics[hapticId] else { return }
        
        let adjustedIntensity = intensity * configuration.intensityMultiplier
        disasterInstance.intensity = adjustedIntensity
        
        // Update the haptic player if it's a continuous pattern
        updateContinuousHapticIntensity(for: disasterInstance.type, intensity: adjustedIntensity)
    }
    
    /// Stop a specific disaster haptic
    public func stopDisasterHaptic(_ hapticId: UUID) {
        guard let disasterInstance = activeDisasterHaptics.removeValue(forKey: hapticId) else { return }
        
        stopContinuousHaptic(for: disasterInstance.type)
        
        if let patternPlayer = patternPlayers.removeValue(forKey: hapticId) {
            try? patternPlayer.stop(atTime: CHHapticTimeImmediate)
        }
        
        hapticEventSubject.send(.disasterEnded(disasterInstance.type))
    }
    
    // MARK: - Emergency and Alert Haptics
    
    /// Play emergency alert haptic patterns
    public func playEmergencyAlert(_ alertType: EmergencyAlertType, severity: Float = 1.0) {
        guard isHapticsEnabled && configuration.enableEmergencyHaptics else { return }
        
        let adjustedSeverity = severity * configuration.intensityMultiplier
        
        switch alertType {
        case .collision:
            playCollisionHaptic(severity: adjustedSeverity)
        case .fire:
            playFireAlarmHaptic(severity: adjustedSeverity)
        case .flooding:
            playFloodingAlarmHaptic(severity: adjustedSeverity)
        case .piracy:
            playSecurityAlertHaptic(severity: adjustedSeverity)
        case .systemFailure:
            playSystemFailureHaptic(severity: adjustedSeverity)
        case .abandon:
            playAbandonShipHaptic(severity: adjustedSeverity)
        case .generalAlarm:
            playGeneralAlarmHaptic(severity: adjustedSeverity)
        }
        
        hapticEventSubject.send(.emergencyAlert(alertType, adjustedSeverity))
    }
    
    /// Play notification haptic for UI interactions
    public func playNotificationHaptic(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled else { return }
        
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(notificationType)
        
        hapticEventSubject.send(.notification(notificationType))
    }
    
    /// Play impact haptic for physical interactions
    public func playImpactHaptic(_ impactStyle: UIImpactFeedbackGenerator.FeedbackStyle, intensity: Float = 1.0) {
        guard isHapticsEnabled else { return }
        
        let adjustedIntensity = intensity * configuration.intensityMultiplier
        let feedbackGenerator = UIImpactFeedbackGenerator(style: impactStyle)
        
        if #available(iOS 13.0, *) {
            feedbackGenerator.impactOccurred(intensity: CGFloat(adjustedIntensity))
        } else {
            feedbackGenerator.impactOccurred()
        }
        
        hapticEventSubject.send(.impact(impactStyle, adjustedIntensity))
    }
    
    // MARK: - Success and Achievement Haptics
    
    /// Play success haptic patterns
    public func playSuccessHaptic(_ successType: SuccessHapticType) {
        guard isHapticsEnabled && configuration.enableSuccessHaptics else { return }
        
        switch successType {
        case .contractCompleted:
            playContractCompletionHaptic()
        case .levelUp:
            playLevelUpHaptic()
        case .achievement:
            playAchievementHaptic()
        case .profitGain:
            playProfitGainHaptic()
        case .routeOptimized:
            playRouteOptimizedHaptic()
        }
        
        hapticEventSubject.send(.success(successType))
    }
    
    // MARK: - Ambient and Environmental Haptics
    
    /// Start ambient haptic feedback for environmental immersion
    public func startAmbientHaptic(_ ambientType: AmbientHapticType, intensity: Float = 0.3) {
        guard isHapticsEnabled && configuration.enableAmbientHaptics else { return }
        
        let adjustedIntensity = intensity * configuration.intensityMultiplier
        
        switch ambientType {
        case .oceanWaves:
            startOceanWaveHaptic(intensity: adjustedIntensity)
        case .engineVibration:
            startEngineVibrationHaptic(intensity: adjustedIntensity)
        case .portActivity:
            startPortActivityHaptic(intensity: adjustedIntensity)
        }
        
        hapticEventSubject.send(.ambientStarted(ambientType, adjustedIntensity))
    }
    
    /// Stop ambient haptic feedback
    public func stopAmbientHaptic(_ ambientType: AmbientHapticType) {
        stopContinuousHaptic(for: ambientType.patternType)
        hapticEventSubject.send(.ambientStopped(ambientType))
    }
    
    // MARK: - Custom Haptic Patterns
    
    /// Play a custom haptic pattern from a file
    public func playCustomPattern(named patternName: String, intensity: Float = 1.0) -> UUID? {
        guard isHapticsEnabled,
              let patternURL = Bundle.main.url(forResource: patternName, withExtension: "ahap") else {
            return nil
        }
        
        do {
            let patternData = try Data(contentsOf: patternURL)
            let pattern = try CHHapticPattern(data: patternData)
            let player = try hapticEngine?.makePlayer(with: pattern)
            
            let hapticId = UUID()
            patternPlayers[hapticId] = player
            
            let adjustedIntensity = intensity * configuration.intensityMultiplier
            let intensityParameter = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: adjustedIntensity,
                relativeTime: 0
            )
            
            try player?.start(atTime: CHHapticTimeImmediate)
            try player?.sendParameters([intensityParameter], atTime: CHHapticTimeImmediate)
            
            return hapticId
        } catch {
            print("Failed to play custom haptic pattern: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("Device does not support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            
            // Set up engine state change handler
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.engineNeedsRestart = true
            }
            
            // Set up engine reset handler
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                    self?.engineNeedsRestart = false
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            isAdvancedHapticsSupported = true
        } catch {
            print("Failed to create haptic engine: \(error)")
            isAdvancedHapticsSupported = false
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for economic events to trigger haptics
        NotificationCenter.default.publisher(for: Notification.Name("EconomicEventGenerated"))
            .sink { [weak self] notification in
                if let event = notification.object as? EconomicEventComponent {
                    self?.handleEconomicEventHaptic(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen for disaster effects
        NotificationCenter.default.publisher(for: Notification.Name("DisasterEffectCreated"))
            .sink { [weak self] notification in
                if let disaster = notification.object as? DisasterEffectComponent {
                    self?.handleDisasterEffectHaptic(disaster)
                }
            }
            .store(in: &cancellables)
        
        // Listen for emergency haptic requests
        NotificationCenter.default.publisher(for: Notification.Name("TriggerHapticFeedback"))
            .sink { [weak self] notification in
                self?.handleHapticFeedbackRequest(notification)
            }
            .store(in: &cancellables)
    }
    
    private func createDisasterPatterns() {
        // Create haptic patterns for each disaster type
        // These would be loaded from .ahap files or created programmatically
        
        do {
            // Hurricane pattern - swirling, increasing intensity
            disasterPatterns[.hurricane] = try createHurricanePattern()
            
            // Tsunami pattern - building wave, massive impact
            disasterPatterns[.tsunami] = try createTsunamiPattern()
            
            // Earthquake pattern - rhythmic shaking, variable intensity
            disasterPatterns[.earthquake] = try createEarthquakePattern()
            
            // Fire pattern - crackling, spreading sensation
            disasterPatterns[.fire] = try createFirePattern()
            
            // Storm pattern - irregular impacts, wind gusts
            disasterPatterns[.storm] = try createStormPattern()
            
        } catch {
            print("Failed to create disaster haptic patterns: \(error)")
        }
    }
    
    // MARK: - Disaster-Specific Haptic Implementations
    
    private func playHurricaneHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create a swirling pattern that increases in intensity
            let pattern = try createHurricanePattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play hurricane haptic: \(error)")
        }
    }
    
    private func playTsunamiHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create a building wave pattern with massive impact
            let pattern = try createTsunamiPattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play tsunami haptic: \(error)")
        }
    }
    
    private func playEarthquakeHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create rhythmic shaking pattern
            let pattern = try createEarthquakePattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play earthquake haptic: \(error)")
        }
    }
    
    private func playStormHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create irregular storm pattern
            let pattern = try createStormPattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play storm haptic: \(error)")
        }
    }
    
    private func playFireHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create crackling fire pattern
            let pattern = try createFirePattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play fire haptic: \(error)")
        }
    }
    
    private func playPiracyHaptic(id: UUID, intensity: Float) {
        // Sharp, urgent alert pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                impactGenerator.impactOccurred(intensity: CGFloat(intensity))
            }
        }
    }
    
    private func playCyberAttackHaptic(id: UUID, intensity: Float) {
        // Electronic interference pattern
        let selectionGenerator = UISelectionFeedbackGenerator()
        
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                selectionGenerator.selectionChanged()
            }
        }
    }
    
    private func playFloodingHaptic(id: UUID, intensity: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        do {
            // Create water rushing pattern
            let pattern = try createFloodingPattern(intensity: intensity, duration: duration)
            let player = try engine.makePlayer(with: pattern)
            
            patternPlayers[id] = player
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Failed to play flooding haptic: \(error)")
        }
    }
    
    // MARK: - Emergency Alert Haptics
    
    private func playCollisionHaptic(severity: Float) {
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        
        // Triple impact for collision
        impactGenerator.impactOccurred(intensity: CGFloat(severity))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactGenerator.impactOccurred(intensity: CGFloat(severity * 0.8))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactGenerator.impactOccurred(intensity: CGFloat(severity * 0.6))
        }
    }
    
    private func playFireAlarmHaptic(severity: Float) {
        // Rapid pulsing pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                impactGenerator.impactOccurred(intensity: CGFloat(severity))
            }
        }
    }
    
    private func playFloodingAlarmHaptic(severity: Float) {
        // Wave-like pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        
        for i in 0..<6 {
            let delay = Double(i) * 0.3
            let intensity = severity * sin(Float(i) * .pi / 3) // Sine wave intensity
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impactGenerator.impactOccurred(intensity: CGFloat(abs(intensity)))
            }
        }
    }
    
    private func playSecurityAlertHaptic(severity: Float) {
        // Urgent, irregular pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        let delays = [0.0, 0.15, 0.25, 0.5, 0.65, 0.75, 1.0]
        
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impactGenerator.impactOccurred(intensity: CGFloat(severity))
            }
        }
    }
    
    private func playSystemFailureHaptic(severity: Float) {
        // Declining intensity pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        for i in 0..<5 {
            let delay = Double(i) * 0.4
            let intensity = severity * (1.0 - Float(i) * 0.2)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                impactGenerator.impactOccurred(intensity: CGFloat(intensity))
            }
        }
    }
    
    private func playAbandonShipHaptic(severity: Float) {
        // Continuous urgent pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        
        for i in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                impactGenerator.impactOccurred(intensity: CGFloat(severity))
            }
        }
    }
    
    private func playGeneralAlarmHaptic(severity: Float) {
        // Standard alarm pattern
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                impactGenerator.impactOccurred(intensity: CGFloat(severity))
            }
        }
    }
    
    // MARK: - Success Haptics
    
    private func playContractCompletionHaptic() {
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
        
        // Follow up with a celebratory pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.impactOccurred()
        }
    }
    
    private func playLevelUpHaptic() {
        // Ascending pattern
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .medium, .heavy]
        
        for (index, style) in styles.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        }
    }
    
    private func playAchievementHaptic() {
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(.success)
        
        // Triple celebration
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                impactGenerator.impactOccurred()
            }
        }
    }
    
    private func playProfitGainHaptic() {
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        
        // Quick double tap
        impactGenerator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactGenerator.impactOccurred()
        }
    }
    
    private func playRouteOptimizedHaptic() {
        let selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator.selectionChanged()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
        }
    }
    
    // MARK: - Ambient Haptics
    
    private func startOceanWaveHaptic(intensity: Float) {
        // Would create a continuous gentle wave pattern
        // This requires CHHapticAdvancedPatternPlayer for continuous patterns
    }
    
    private func startEngineVibrationHaptic(intensity: Float) {
        // Continuous engine rumble
        // This requires CHHapticAdvancedPatternPlayer for continuous patterns
    }
    
    private func startPortActivityHaptic(intensity: Float) {
        // Intermittent activity pattern
        // This requires CHHapticAdvancedPatternPlayer for continuous patterns
    }
    
    // MARK: - Continuous Haptic Management
    
    private func startContinuousHaptic(pattern: CHHapticPattern, type: HapticPatternType) {
        guard let engine = hapticEngine else { return }
        
        do {
            let player = try engine.makeAdvancedPlayer(with: pattern)
            continuousPlayers[type] = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to start continuous haptic: \(error)")
        }
    }
    
    private func stopContinuousHaptic(for type: HapticPatternType) {
        if let player = continuousPlayers.removeValue(forKey: type) {
            try? player.stop(atTime: CHHapticTimeImmediate)
        }
    }
    
    private func updateContinuousHapticIntensity(for disasterType: DisasterEffectComponent.DisasterType, intensity: Float) {
        let patternType = HapticPatternType.disaster(disasterType)
        
        if let player = continuousPlayers[patternType] {
            let intensityParameter = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: intensity,
                relativeTime: 0
            )
            
            try? player.sendParameters([intensityParameter], atTime: CHHapticTimeImmediate)
        }
    }
    
    private func stopAllContinuousHaptics() {
        for (_, player) in continuousPlayers {
            try? player.stop(atTime: CHHapticTimeImmediate)
        }
        continuousPlayers.removeAll()
    }
    
    // MARK: - Event Handlers
    
    private func handleEconomicEventHaptic(_ event: EconomicEventComponent) {
        guard event.triggerHapticFeedback else { return }
        
        let intensity = event.severity.hapticIntensity
        
        switch event.eventType {
        case .portStrike, .tradeWar:
            playNotificationHaptic(.warning)
        case .hurricaneWarning, .tsunami:
            playEmergencyAlert(.generalAlarm, severity: intensity)
        case .oilPriceSurge, .recession:
            playNotificationHaptic(.error)
        case .boom, .techBreakthrough:
            playNotificationHaptic(.success)
        default:
            playImpactHaptic(.medium, intensity: intensity)
        }
    }
    
    private func handleDisasterEffectHaptic(_ disaster: DisasterEffectComponent) {
        _ = playDisasterHaptic(
            disaster.disasterType,
            intensity: disaster.intensityLevel,
            duration: disaster.duration,
            position: nil
        )
    }
    
    private func handleHapticFeedbackRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let eventType = userInfo["eventType"] as? EconomicEventComponent.EconomicEventType,
           let severity = userInfo["severity"] as? EconomicEventComponent.EventSeverity,
           let intensity = userInfo["intensity"] as? Float {
            
            // Handle economic event haptic
            switch eventType {
            case .hurricaneWarning:
                _ = playDisasterHaptic(.hurricane, intensity: intensity, duration: 10.0)
            case .earthquake:
                _ = playDisasterHaptic(.earthquake, intensity: intensity, duration: 8.0)
            default:
                playImpactHaptic(.medium, intensity: intensity)
            }
        }
    }
    
    // MARK: - Pattern Creation Helpers
    
    private func createHurricanePattern(intensity: Float = 1.0, duration: TimeInterval = 10.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Create swirling pattern with increasing intensity
        let stepCount = Int(duration * 4) // 4 events per second
        
        for i in 0..<stepCount {
            let time = Double(i) / 4.0
            let progress = Float(i) / Float(stepCount)
            let swirl = sin(progress * .pi * 4) * 0.5 + 0.5 // Swirling effect
            let eventIntensity = intensity * (0.3 + progress * 0.7) * swirl
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: eventIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createTsunamiPattern(intensity: Float = 1.0, duration: TimeInterval = 8.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Building wave pattern with massive impact
        let buildupTime = duration * 0.7
        let impactTime = duration * 0.3
        
        // Build up
        let buildupSteps = Int(buildupTime * 3)
        for i in 0..<buildupSteps {
            let time = Double(i) / 3.0
            let progress = Float(i) / Float(buildupSteps)
            let eventIntensity = intensity * progress * 0.5
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: eventIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: time,
                duration: 0.3
            )
            events.append(event)
        }
        
        // Massive impact
        let impactEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: buildupTime
        )
        events.append(impactEvent)
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createEarthquakePattern(intensity: Float = 1.0, duration: TimeInterval = 12.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Rhythmic shaking with random variations
        let stepCount = Int(duration * 6) // 6 events per second
        
        for i in 0..<stepCount {
            let time = Double(i) / 6.0
            let rhythmicIntensity = intensity * (0.7 + sin(Float(time) * 3) * 0.3)
            let randomVariation = Float.random(in: 0.8...1.2)
            let eventIntensity = rhythmicIntensity * randomVariation
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: eventIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createFirePattern(intensity: Float = 1.0, duration: TimeInterval = 15.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Crackling pattern with spreading sensation
        let crackleCount = Int(duration * 8) // 8 crackles per second
        
        for i in 0..<crackleCount {
            let time = Double(i) / 8.0
            let crackleIntensity = intensity * Float.random(in: 0.3...0.8)
            let sharpness = Float.random(in: 0.2...0.9) // Varying sharpness for crackling
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: crackleIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createStormPattern(intensity: Float = 1.0, duration: TimeInterval = 20.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Irregular impacts with wind gusts
        let impactCount = Int(duration * 2) // 2 impacts per second
        
        for i in 0..<impactCount {
            let time = Double(i) / 2.0 + Double.random(in: -0.2...0.2) // Random timing
            let gustIntensity = intensity * Float.random(in: 0.4...1.0)
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: gustIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: max(0, time),
                duration: Double.random(in: 0.2...0.8)
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createFloodingPattern(intensity: Float = 1.0, duration: TimeInterval = 10.0) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Water rushing pattern
        let rushEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0,
            duration: duration
        )
        events.append(rushEvent)
        
        // Intermittent impacts
        let impactCount = Int(duration / 2)
        for i in 0..<impactCount {
            let time = Double(i) * 2.0
            let impactEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: time
            )
            events.append(impactEvent)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    deinit {
        stopHapticEngine()
    }
}

// MARK: - Supporting Types

class DisasterHapticInstance {
    let id: UUID
    let type: DisasterEffectComponent.DisasterType
    var intensity: Float
    let duration: TimeInterval
    let startTime: Date
    
    init(id: UUID, type: DisasterEffectComponent.DisasterType, intensity: Float, duration: TimeInterval, startTime: Date) {
        self.id = id
        self.type = type
        self.intensity = intensity
        self.duration = duration
        self.startTime = startTime
    }
}

public enum HapticPatternType: Hashable {
    case disaster(DisasterEffectComponent.DisasterType)
    case ambient(AmbientHapticType)
    case emergency(EmergencyAlertType)
    case success(SuccessHapticType)
}

public enum EmergencyAlertType {
    case collision
    case fire
    case flooding
    case piracy
    case systemFailure
    case abandon
    case generalAlarm
}

public enum SuccessHapticType {
    case contractCompleted
    case levelUp
    case achievement
    case profitGain
    case routeOptimized
}

public enum AmbientHapticType {
    case oceanWaves
    case engineVibration
    case portActivity
    
    var patternType: HapticPatternType {
        return .ambient(self)
    }
}

public enum HapticEvent {
    case disasterStarted(DisasterEffectComponent.DisasterType, Float)
    case disasterEnded(DisasterEffectComponent.DisasterType)
    case emergencyAlert(EmergencyAlertType, Float)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
    case impact(UIImpactFeedbackGenerator.FeedbackStyle, Float)
    case success(SuccessHapticType)
    case ambientStarted(AmbientHapticType, Float)
    case ambientStopped(AmbientHapticType)
}

public enum HapticError: Error {
    case unsupportedDevice
    case engineNotAvailable
    case patternCreationFailed
    case playbackFailed
}