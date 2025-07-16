import Foundation
import UIKit
import AVFoundation
import Combine

/// Comprehensive audio accessibility manager for inclusive gaming experience
public class AudioAccessibilityManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AudioAccessibilityManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isVoiceOverEnabled: Bool = false
    @Published public private(set) var isAudioDescriptionEnabled: Bool = true
    @Published public private(set) var isSoundReplacementEnabled: Bool = false
    @Published public private(set) var audioContrastLevel: AudioContrastLevel = .normal
    @Published public private(set) var spatialAudioSupport: Bool = true
    @Published public private(set) var accessibilityVolume: Float = 1.0
    
    // MARK: - Audio Description System
    private let voiceOverSystem = VoiceOverSystem.shared
    private var audioDescriptionQueue: [AudioDescription] = []
    private var currentAudioDescription: AudioDescription?
    
    // MARK: - Sound Replacement System
    private var soundReplacements: [String: SoundReplacement] = [:]
    private var visualToAudioMappings: [VisualElement: AudioCue] = [:]
    
    // MARK: - Accessibility Features
    private var screenReaderIntegration: ScreenReaderIntegration
    private var motionSensitivityManager: MotionSensitivityManager
    private var cognitiveAccessibilitySupport: CognitiveAccessibilitySupport
    
    // MARK: - Configuration
    public struct Configuration {
        public var enableAutoAudioDescription: Bool = true
        public var enableSoundReplacement: Bool = false
        public var enableHapticReinforcement: Bool = true
        public var enableCognitiveSupport: Bool = true
        public var respectSystemSettings: Bool = true
        public var audioDescriptionDelay: TimeInterval = 0.5
        public var maxDescriptionLength: Int = 200
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - State Management
    private var isProcessingDescription: Bool = false
    private var lastDescriptionTime: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private override init() {
        self.screenReaderIntegration = ScreenReaderIntegration()
        self.motionSensitivityManager = MotionSensitivityManager()
        self.cognitiveAccessibilitySupport = CognitiveAccessibilitySupport()
        
        super.init()
        
        setupAccessibilityMonitoring()
        setupSoundReplacements()
        setupVisualToAudioMappings()
        configureAccessibilityFeatures()
    }
    
    // MARK: - Public Interface
    
    /// Initialize accessibility features
    public func initializeAccessibilityFeatures() {
        updateAccessibilityStatus()
        setupAccessibilityNotifications()
        configureAudioDescriptions()
        
        print("Audio accessibility features initialized")
    }
    
    /// Describe visual element for screen reader users
    public func describeVisualElement(_ element: VisualElement, context: AccessibilityContext? = nil) {
        guard isAudioDescriptionEnabled else { return }
        
        let description = generateElementDescription(element, context: context)
        queueAudioDescription(description)
    }
    
    /// Describe game state change
    public func describeGameStateChange(_ change: GameStateChange, details: String? = nil) {
        guard isAudioDescriptionEnabled else { return }
        
        let description = generateStateChangeDescription(change, details: details)
        queueAudioDescription(description)
    }
    
    /// Describe UI interaction result
    public func describeInteractionResult(_ interaction: UIInteraction, success: Bool, details: String? = nil) {
        guard isAudioDescriptionEnabled else { return }
        
        let description = generateInteractionDescription(interaction, success: success, details: details)
        queueAudioDescription(description)
    }
    
    /// Replace visual feedback with audio cues
    public func playVisualReplacementAudio(for element: VisualElement, intensity: Float = 1.0) {
        guard isSoundReplacementEnabled else { return }
        
        if let audioCue = visualToAudioMappings[element] {
            playAudioCue(audioCue, intensity: intensity)
        }
    }
    
    /// Enable/disable audio descriptions
    public func setAudioDescriptionEnabled(_ enabled: Bool) {
        isAudioDescriptionEnabled = enabled
        
        if !enabled {
            clearAudioDescriptionQueue()
        }
    }
    
    /// Enable/disable sound replacement for visual elements
    public func setSoundReplacementEnabled(_ enabled: Bool) {
        isSoundReplacementEnabled = enabled
    }
    
    /// Set audio contrast level for better differentiation
    public func setAudioContrastLevel(_ level: AudioContrastLevel) {
        audioContrastLevel = level
        applyAudioContrast(level)
    }
    
    /// Set accessibility-specific volume
    public func setAccessibilityVolume(_ volume: Float) {
        accessibilityVolume = max(0.0, min(2.0, volume)) // Allow up to 200% for accessibility
        updateAccessibilityAudioLevels()
    }
    
    /// Announce important game event
    public func announceGameEvent(_ event: GameEvent, priority: AccessibilityPriority = .medium) {
        let announcement = generateGameEventAnnouncement(event)
        
        switch priority {
        case .low:
            queueAudioDescription(AudioDescription(text: announcement, priority: .low, delay: 1.0))
        case .medium:
            voiceOverSystem.announceAccessibilityDescription(announcement, priority: .medium)
        case .urgent:
            voiceOverSystem.announceAccessibilityDescription(announcement, priority: .urgent)
        }
    }
    
    /// Provide navigation assistance
    public func provideNavigationAssistance(from: CGPoint, to: CGPoint, obstacles: [CGRect] = []) {
        guard isAudioDescriptionEnabled else { return }
        
        let navigationDescription = generateNavigationDescription(from: from, to: to, obstacles: obstacles)
        queueAudioDescription(navigationDescription)
    }
    
    /// Describe current screen layout
    public func describeScreenLayout(_ layout: ScreenLayout) {
        guard isAudioDescriptionEnabled else { return }
        
        let layoutDescription = generateLayoutDescription(layout)
        queueAudioDescription(layoutDescription)
    }
    
    /// Get accessibility status for UI
    public func getAccessibilityStatus() -> AccessibilityStatus {
        return AccessibilityStatus(
            voiceOverEnabled: isVoiceOverEnabled,
            audioDescriptionEnabled: isAudioDescriptionEnabled,
            soundReplacementEnabled: isSoundReplacementEnabled,
            contrastLevel: audioContrastLevel,
            spatialAudioSupported: spatialAudioSupport,
            motionSensitivityEnabled: motionSensitivityManager.isEnabled,
            cognitiveSuportEnabled: cognitiveAccessibilitySupport.isEnabled
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupAccessibilityMonitoring() {
        // Monitor VoiceOver status
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateVoiceOverStatus()
            }
            .store(in: &cancellables)
        
        // Monitor other accessibility settings
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateMotionSettings()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.hearingDevicePairedEarDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateHearingDeviceSettings()
            }
            .store(in: &cancellables)
    }
    
    private func setupSoundReplacements() {
        // Configure sound replacements for visual elements
        soundReplacements["ship_movement"] = SoundReplacement(
            soundFile: "accessibility_movement_tone",
            frequency: 440.0,
            duration: 0.5,
            fadeIn: 0.1,
            fadeOut: 0.2
        )
        
        soundReplacements["cargo_loading"] = SoundReplacement(
            soundFile: "accessibility_cargo_tone",
            frequency: 660.0,
            duration: 1.0,
            fadeIn: 0.2,
            fadeOut: 0.3
        )
        
        soundReplacements["market_change"] = SoundReplacement(
            soundFile: "accessibility_market_tone",
            frequency: 880.0,
            duration: 0.3,
            fadeIn: 0.05,
            fadeOut: 0.1
        )
        
        soundReplacements["route_progress"] = SoundReplacement(
            soundFile: "accessibility_progress_tone",
            frequency: 550.0,
            duration: 0.8,
            fadeIn: 0.1,
            fadeOut: 0.2
        )
    }
    
    private func setupVisualToAudioMappings() {
        visualToAudioMappings[.shipMovement] = AudioCue(
            type: .tone,
            frequency: 440.0,
            duration: 0.5,
            pattern: .continuous,
            spatialPosition: .follow
        )
        
        visualToAudioMappings[.cargoLoading] = AudioCue(
            type: .rhythmic,
            frequency: 660.0,
            duration: 1.0,
            pattern: .pulse(interval: 0.3),
            spatialPosition: .fixed
        )
        
        visualToAudioMappings[.marketFluctuation] = AudioCue(
            type: .sweep,
            frequency: 880.0,
            duration: 0.8,
            pattern: .rising,
            spatialPosition: .none
        )
        
        visualToAudioMappings[.routeDrawing] = AudioCue(
            type: .tone,
            frequency: 550.0,
            duration: 0.2,
            pattern: .tap,
            spatialPosition: .follow
        )
        
        visualToAudioMappings[.buttonHighlight] = AudioCue(
            type: .click,
            frequency: 800.0,
            duration: 0.1,
            pattern: .single,
            spatialPosition: .none
        )
        
        visualToAudioMappings[.alertIcon] = AudioCue(
            type: .beep,
            frequency: 1000.0,
            duration: 0.3,
            pattern: .triple,
            spatialPosition: .none
        )
    }
    
    private func configureAccessibilityFeatures() {
        screenReaderIntegration.configure(
            announceButtonPress: true,
            announceViewChanges: true,
            announceDataUpdates: true
        )
        
        motionSensitivityManager.configure(
            reducedAnimations: UIAccessibility.isReduceMotionEnabled,
            staticVisualEffects: true,
            audioMotionCues: true
        )
        
        cognitiveAccessibilitySupport.configure(
            simplifiedLanguage: true,
            extendedTimeouts: true,
            repeatedInstructions: true,
            visualReminders: false // Use audio instead
        )
    }
    
    private func updateAccessibilityStatus() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        spatialAudioSupport = !UIAccessibility.isReduceMotionEnabled
        
        // Adjust features based on system settings
        if configuration.respectSystemSettings {
            isAudioDescriptionEnabled = isVoiceOverEnabled || UIAccessibility.isSpeakSelectionEnabled
            isSoundReplacementEnabled = isVoiceOverEnabled
        }
    }
    
    private func setupAccessibilityNotifications() {
        // Configure system to respect accessibility settings
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
    
    private func configureAudioDescriptions() {
        // Set up automatic audio description system
        if configuration.enableAutoAudioDescription {
            startAutoDescriptionSystem()
        }
    }
    
    private func generateElementDescription(_ element: VisualElement, context: AccessibilityContext?) -> AudioDescription {
        var description = ""
        
        switch element {
        case .shipMovement:
            description = "Ship moving"
            if let speed = context?.speed {
                description += " at \(Int(speed)) knots"
            }
            if let direction = context?.direction {
                description += " heading \(direction)"
            }
            
        case .cargoLoading:
            description = "Cargo loading"
            if let progress = context?.progress {
                description += " \(Int(progress * 100))% complete"
            }
            
        case .marketFluctuation:
            description = "Market update"
            if let change = context?.marketChange {
                description += ": \(change > 0 ? "prices rising" : "prices falling") by \(abs(change))%"
            }
            
        case .routeDrawing:
            description = "Drawing trade route"
            if let distance = context?.distance {
                description += " \(Int(distance)) nautical miles"
            }
            
        case .buttonHighlight:
            description = "Button highlighted"
            if let buttonName = context?.elementName {
                description = "\(buttonName) button highlighted"
            }
            
        case .alertIcon:
            description = "Alert notification"
            if let alertType = context?.alertType {
                description = "\(alertType) alert"
            }
        }
        
        return AudioDescription(
            text: description,
            priority: .medium,
            delay: configuration.audioDescriptionDelay
        )
    }
    
    private func generateStateChangeDescription(_ change: GameStateChange, details: String?) -> AudioDescription {
        var description = ""
        
        switch change {
        case .shipArrived:
            description = "Ship has arrived at port"
        case .routeCompleted:
            description = "Trade route completed successfully"
        case .marketOpened:
            description = "Market trading opened"
        case .marketClosed:
            description = "Market trading closed"
        case .weatherChange:
            description = "Weather conditions have changed"
        case .competitorAction:
            description = "Competitor has taken action"
        case .achievementUnlocked:
            description = "Achievement unlocked"
        case .emergencyEvent:
            description = "Emergency situation detected"
        }
        
        if let details = details {
            description += ": \(details)"
        }
        
        return AudioDescription(
            text: description,
            priority: .high,
            delay: 0.2
        )
    }
    
    private func generateInteractionDescription(_ interaction: UIInteraction, success: Bool, details: String?) -> AudioDescription {
        var description = ""
        
        switch interaction {
        case .buttonTap:
            description = success ? "Button activated" : "Button press failed"
        case .shipSelection:
            description = success ? "Ship selected" : "Ship selection failed"
        case .routeCreation:
            description = success ? "Route created" : "Route creation failed"
        case .marketTrade:
            description = success ? "Trade executed" : "Trade failed"
        case .menuNavigation:
            description = success ? "Menu opened" : "Menu navigation failed"
        }
        
        if let details = details {
            description += ": \(details)"
        }
        
        return AudioDescription(
            text: description,
            priority: .medium,
            delay: 0.1
        )
    }
    
    private func generateGameEventAnnouncement(_ event: GameEvent) -> String {
        switch event {
        case .gameStarted:
            return "Game started. Welcome to FlexPort logistics empire."
        case .levelCompleted:
            return "Level completed successfully."
        case .newShipAvailable:
            return "New ship available for purchase."
        case .marketCrash:
            return "Market crash detected. Prices falling rapidly."
        case .stormWarning:
            return "Storm warning issued. Ships should seek safe harbor."
        case .competitorThreat:
            return "Competitor threat detected. Defensive action may be required."
        case .achievementEarned:
            return "Achievement earned. Congratulations on your progress."
        case .emergencyAlert:
            return "Emergency alert. Immediate attention required."
        }
    }
    
    private func generateNavigationDescription(from: CGPoint, to: CGPoint, obstacles: [CGRect]) -> AudioDescription {
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let angle = atan2(to.y - from.y, to.x - from.x)
        
        let direction = getDirectionDescription(angle)
        
        var description = "Navigate \(direction)"
        
        if distance > 100 {
            description += " for long distance"
        } else if distance > 50 {
            description += " for medium distance"
        } else {
            description += " for short distance"
        }
        
        if !obstacles.isEmpty {
            description += ". \(obstacles.count) obstacle\(obstacles.count > 1 ? "s" : "") detected"
        }
        
        return AudioDescription(
            text: description,
            priority: .high,
            delay: 0.1
        )
    }
    
    private func generateLayoutDescription(_ layout: ScreenLayout) -> AudioDescription {
        var description = "Screen layout: "
        
        switch layout.type {
        case .mainMenu:
            description += "Main menu with \(layout.buttonCount) buttons"
        case .gameView:
            description += "Game view with map and \(layout.shipCount) ships"
        case .marketView:
            description += "Market view with \(layout.commodityCount) commodities"
        case .settingsView:
            description += "Settings view with configuration options"
        }
        
        if layout.hasAlerts {
            description += ". Alert notifications present"
        }
        
        return AudioDescription(
            text: description,
            priority: .low,
            delay: 0.5
        )
    }
    
    private func queueAudioDescription(_ description: AudioDescription) {
        guard !isProcessingDescription else {
            if audioDescriptionQueue.count < 5 {
                audioDescriptionQueue.append(description)
            }
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastDescriptionTime < description.delay {
            audioDescriptionQueue.append(description)
            return
        }
        
        playAudioDescription(description)
    }
    
    private func playAudioDescription(_ description: AudioDescription) {
        isProcessingDescription = true
        currentAudioDescription = description
        lastDescriptionTime = Date().timeIntervalSince1970
        
        voiceOverSystem.announceAccessibilityDescription(
            description.text,
            priority: description.priority == .urgent ? .urgent : .medium
        )
        
        // Process next description after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + description.delay + 0.5) { [weak self] in
            self?.isProcessingDescription = false
            self?.currentAudioDescription = nil
            self?.processNextAudioDescription()
        }
    }
    
    private func processNextAudioDescription() {
        guard !audioDescriptionQueue.isEmpty else { return }
        
        let nextDescription = audioDescriptionQueue.removeFirst()
        playAudioDescription(nextDescription)
    }
    
    private func clearAudioDescriptionQueue() {
        audioDescriptionQueue.removeAll()
        currentAudioDescription = nil
        isProcessingDescription = false
    }
    
    private func playAudioCue(_ cue: AudioCue, intensity: Float) {
        let spatialAudio = SpatialAudioEngine.shared
        
        switch cue.type {
        case .tone:
            generateTone(frequency: cue.frequency, duration: cue.duration, intensity: intensity)
        case .beep:
            generateBeep(frequency: cue.frequency, pattern: cue.pattern, intensity: intensity)
        case .click:
            generateClick(intensity: intensity)
        case .rhythmic:
            generateRhythmicPattern(cue: cue, intensity: intensity)
        case .sweep:
            generateFrequencySweep(cue: cue, intensity: intensity)
        }
    }
    
    private func generateTone(frequency: Float, duration: TimeInterval, intensity: Float) {
        // Generate simple tone - would use audio synthesis in real implementation
        print("Playing accessibility tone: \(frequency)Hz for \(duration)s at intensity \(intensity)")
    }
    
    private func generateBeep(frequency: Float, pattern: AudioPattern, intensity: Float) {
        // Generate beep pattern - would use audio synthesis in real implementation
        print("Playing accessibility beep: \(frequency)Hz with pattern \(pattern) at intensity \(intensity)")
    }
    
    private func generateClick(intensity: Float) {
        // Generate click sound - would use audio synthesis in real implementation
        print("Playing accessibility click at intensity \(intensity)")
    }
    
    private func generateRhythmicPattern(cue: AudioCue, intensity: Float) {
        // Generate rhythmic pattern - would use audio synthesis in real implementation
        print("Playing accessibility rhythmic pattern at \(cue.frequency)Hz")
    }
    
    private func generateFrequencySweep(cue: AudioCue, intensity: Float) {
        // Generate frequency sweep - would use audio synthesis in real implementation
        print("Playing accessibility frequency sweep from \(cue.frequency)Hz")
    }
    
    private func applyAudioContrast(_ level: AudioContrastLevel) {
        let contrastMultiplier: Float
        
        switch level {
        case .low:
            contrastMultiplier = 0.8
        case .normal:
            contrastMultiplier = 1.0
        case .high:
            contrastMultiplier = 1.3
        case .maximum:
            contrastMultiplier = 1.6
        }
        
        // Apply contrast to all accessibility audio
        updateAccessibilityAudioLevels()
    }
    
    private func updateAccessibilityAudioLevels() {
        // Update all accessibility audio volumes
        voiceOverSystem.setVoiceVolume(accessibilityVolume)
    }
    
    private func startAutoDescriptionSystem() {
        // Start monitoring for visual changes that need description
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForDescriptionOpportunities()
            }
            .store(in: &cancellables)
    }
    
    private func checkForDescriptionOpportunities() {
        // Check for visual changes that might need audio description
        // This would be integrated with the game's visual system
    }
    
    private func getDirectionDescription(_ angle: Float) -> String {
        let degrees = angle * 180 / .pi
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees
        
        switch normalizedDegrees {
        case 337.5...360, 0..<22.5:
            return "east"
        case 22.5..<67.5:
            return "northeast"
        case 67.5..<112.5:
            return "north"
        case 112.5..<157.5:
            return "northwest"
        case 157.5..<202.5:
            return "west"
        case 202.5..<247.5:
            return "southwest"
        case 247.5..<292.5:
            return "south"
        case 292.5..<337.5:
            return "southeast"
        default:
            return "unknown direction"
        }
    }
    
    // MARK: - Event Handlers
    
    private func updateVoiceOverStatus() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        
        if isVoiceOverEnabled && configuration.respectSystemSettings {
            isAudioDescriptionEnabled = true
            isSoundReplacementEnabled = true
        }
    }
    
    private func updateMotionSettings() {
        motionSensitivityManager.setReduceMotionEnabled(UIAccessibility.isReduceMotionEnabled)
        spatialAudioSupport = !UIAccessibility.isReduceMotionEnabled
    }
    
    private func updateHearingDeviceSettings() {
        // Update audio settings for hearing devices
        let hasHearingDevice = UIAccessibility.isOnOffSwitchLabelsEnabled
        
        if hasHearingDevice {
            // Adjust audio settings for hearing devices
            setAccessibilityVolume(accessibilityVolume * 1.2)
        }
    }
}

// MARK: - Supporting Types

public enum AudioContrastLevel: String, CaseIterable {
    case low
    case normal
    case high
    case maximum
}

public enum VisualElement {
    case shipMovement
    case cargoLoading
    case marketFluctuation
    case routeDrawing
    case buttonHighlight
    case alertIcon
}

public enum GameStateChange {
    case shipArrived
    case routeCompleted
    case marketOpened
    case marketClosed
    case weatherChange
    case competitorAction
    case achievementUnlocked
    case emergencyEvent
}

public enum UIInteraction {
    case buttonTap
    case shipSelection
    case routeCreation
    case marketTrade
    case menuNavigation
}

public enum GameEvent {
    case gameStarted
    case levelCompleted
    case newShipAvailable
    case marketCrash
    case stormWarning
    case competitorThreat
    case achievementEarned
    case emergencyAlert
}

public enum AccessibilityPriority {
    case low
    case medium
    case urgent
}

public enum AudioCueType {
    case tone
    case beep
    case click
    case rhythmic
    case sweep
}

public enum AudioPattern {
    case single
    case double
    case triple
    case pulse(interval: TimeInterval)
    case continuous
    case rising
    case falling
    case tap
}

public enum SpatialPosition {
    case none
    case fixed
    case follow
}

public struct SoundReplacement {
    public let soundFile: String
    public let frequency: Float
    public let duration: TimeInterval
    public let fadeIn: TimeInterval
    public let fadeOut: TimeInterval
    
    public init(soundFile: String, frequency: Float, duration: TimeInterval, fadeIn: TimeInterval, fadeOut: TimeInterval) {
        self.soundFile = soundFile
        self.frequency = frequency
        self.duration = duration
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
    }
}

public struct AudioCue {
    public let type: AudioCueType
    public let frequency: Float
    public let duration: TimeInterval
    public let pattern: AudioPattern
    public let spatialPosition: SpatialPosition
    
    public init(type: AudioCueType, frequency: Float, duration: TimeInterval, pattern: AudioPattern, spatialPosition: SpatialPosition) {
        self.type = type
        self.frequency = frequency
        self.duration = duration
        self.pattern = pattern
        self.spatialPosition = spatialPosition
    }
}

public struct AudioDescription {
    public let text: String
    public let priority: AccessibilityPriority
    public let delay: TimeInterval
    
    public init(text: String, priority: AccessibilityPriority, delay: TimeInterval) {
        self.text = text
        self.priority = priority
        self.delay = delay
    }
}

public struct AccessibilityContext {
    public let speed: Float?
    public let direction: String?
    public let progress: Float?
    public let marketChange: Float?
    public let distance: Float?
    public let elementName: String?
    public let alertType: String?
    
    public init(speed: Float? = nil, direction: String? = nil, progress: Float? = nil, 
                marketChange: Float? = nil, distance: Float? = nil, elementName: String? = nil, alertType: String? = nil) {
        self.speed = speed
        self.direction = direction
        self.progress = progress
        self.marketChange = marketChange
        self.distance = distance
        self.elementName = elementName
        self.alertType = alertType
    }
}

public struct ScreenLayout {
    public let type: ScreenType
    public let buttonCount: Int
    public let shipCount: Int
    public let commodityCount: Int
    public let hasAlerts: Bool
    
    public enum ScreenType {
        case mainMenu
        case gameView
        case marketView
        case settingsView
    }
    
    public init(type: ScreenType, buttonCount: Int = 0, shipCount: Int = 0, commodityCount: Int = 0, hasAlerts: Bool = false) {
        self.type = type
        self.buttonCount = buttonCount
        self.shipCount = shipCount
        self.commodityCount = commodityCount
        self.hasAlerts = hasAlerts
    }
}

public struct AccessibilityStatus {
    public let voiceOverEnabled: Bool
    public let audioDescriptionEnabled: Bool
    public let soundReplacementEnabled: Bool
    public let contrastLevel: AudioContrastLevel
    public let spatialAudioSupported: Bool
    public let motionSensitivityEnabled: Bool
    public let cognitiveSuportEnabled: Bool
    
    public init(voiceOverEnabled: Bool, audioDescriptionEnabled: Bool, soundReplacementEnabled: Bool, 
                contrastLevel: AudioContrastLevel, spatialAudioSupported: Bool, motionSensitivityEnabled: Bool, cognitiveSuportEnabled: Bool) {
        self.voiceOverEnabled = voiceOverEnabled
        self.audioDescriptionEnabled = audioDescriptionEnabled
        self.soundReplacementEnabled = soundReplacementEnabled
        self.contrastLevel = contrastLevel
        self.spatialAudioSupported = spatialAudioSupported
        self.motionSensitivityEnabled = motionSensitivityEnabled
        self.cognitiveSuportEnabled = cognitiveSuportEnabled
    }
}

// MARK: - Helper Classes

public class ScreenReaderIntegration: ObservableObject {
    @Published public var announceButtonPress: Bool = true
    @Published public var announceViewChanges: Bool = true
    @Published public var announceDataUpdates: Bool = true
    
    public func configure(announceButtonPress: Bool, announceViewChanges: Bool, announceDataUpdates: Bool) {
        self.announceButtonPress = announceButtonPress
        self.announceViewChanges = announceViewChanges
        self.announceDataUpdates = announceDataUpdates
    }
}

public class MotionSensitivityManager: ObservableObject {
    @Published public var isEnabled: Bool = false
    @Published public var reducedAnimations: Bool = false
    @Published public var staticVisualEffects: Bool = false
    @Published public var audioMotionCues: Bool = false
    
    public func configure(reducedAnimations: Bool, staticVisualEffects: Bool, audioMotionCues: Bool) {
        self.reducedAnimations = reducedAnimations
        self.staticVisualEffects = staticVisualEffects
        self.audioMotionCues = audioMotionCues
        self.isEnabled = reducedAnimations || staticVisualEffects || audioMotionCues
    }
    
    public func setReduceMotionEnabled(_ enabled: Bool) {
        reducedAnimations = enabled
        isEnabled = enabled || staticVisualEffects || audioMotionCues
    }
}

public class CognitiveAccessibilitySupport: ObservableObject {
    @Published public var isEnabled: Bool = false
    @Published public var simplifiedLanguage: Bool = false
    @Published public var extendedTimeouts: Bool = false
    @Published public var repeatedInstructions: Bool = false
    @Published public var visualReminders: Bool = false
    
    public func configure(simplifiedLanguage: Bool, extendedTimeouts: Bool, repeatedInstructions: Bool, visualReminders: Bool) {
        self.simplifiedLanguage = simplifiedLanguage
        self.extendedTimeouts = extendedTimeouts
        self.repeatedInstructions = repeatedInstructions
        self.visualReminders = visualReminders
        self.isEnabled = simplifiedLanguage || extendedTimeouts || repeatedInstructions || visualReminders
    }
}