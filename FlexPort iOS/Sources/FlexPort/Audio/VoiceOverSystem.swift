import Foundation
import AVFoundation
import Speech
import Combine

/// Advanced voice-over system for narrative events, AI competitor interactions, and accessibility
public class VoiceOverSystem: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VoiceOverSystem()
    
    // MARK: - Published Properties
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var currentNarrative: NarrativeEvent?
    @Published public private(set) var voiceVolume: Float = 0.8
    @Published public private(set) var speechRate: Float = 0.5
    @Published public private(set) var selectedVoice: VoiceProfile = .narrator
    
    // MARK: - Speech Synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var narrativeQueue: [NarrativeEvent] = []
    private var currentUtterance: AVSpeechUtterance?
    
    // MARK: - Voice Profiles
    private var voiceProfiles: [VoiceProfile: VoiceConfiguration] = [:]
    private var narrativeLibrary: [NarrativeType: [NarrativeScript]] = [:]
    
    // MARK: - AI Competitor Voices
    private var competitorVoices: [String: VoiceProfile] = [:] // CompetitorID -> VoiceProfile
    private var competitorPersonalities: [String: CompetitorPersonality] = [:]
    
    // MARK: - Configuration
    public struct Configuration {
        public var enableNarrative: Bool = true
        public var enableCompetitorVoices: Bool = true
        public var enableAccessibilityVoice: Bool = true
        public var autoPlayNarrative: Bool = true
        public var respectSystemVoiceOverSettings: Bool = true
        public var maxQueuedNarratives: Int = 5
        public var interruptionBehavior: InterruptionBehavior = .queue
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - State Management
    private var isQueueProcessing: Bool = false
    private var currentLanguage: String = "en-US"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupVoiceProfiles()
        setupNarrativeLibrary()
        setupSpeechSynthesizer()
        setupAccessibilityMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Initialize the voice-over system
    public func initializeVoiceSystem() {
        guard !isInitialized else { return }
        
        requestSpeechPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.configureAudioSession()
                    self?.isInitialized = true
                    print("Voice-over system initialized successfully")
                } else {
                    print("Speech permissions denied")
                }
            }
        }
    }
    
    /// Play narrative for a specific event
    public func playNarrative(_ type: NarrativeType, context: NarrativeContext? = nil, priority: NarrativePriority = .normal) {
        guard configuration.enableNarrative else { return }
        
        let narrative = createNarrativeEvent(type: type, context: context, priority: priority)
        queueNarrative(narrative)
    }
    
    /// Play AI competitor dialogue
    public func playCompetitorDialogue(competitorId: String, message: String, emotion: EmotionalTone = .neutral) {
        guard configuration.enableCompetitorVoices else { return }
        
        let voice = competitorVoices[competitorId] ?? .competitor1
        let personality = competitorPersonalities[competitorId] ?? CompetitorPersonality()
        
        let dialogue = CompetitorDialogue(
            competitorId: competitorId,
            message: message,
            voice: voice,
            emotion: emotion,
            personality: personality
        )
        
        playCompetitorMessage(dialogue)
    }
    
    /// Play accessibility description
    public func announceAccessibilityDescription(_ description: String, priority: AccessibilityPriority = .medium) {
        guard configuration.enableAccessibilityVoice else { return }
        
        let accessibilityEvent = AccessibilityAnnouncement(
            description: description,
            priority: priority,
            interruptCurrent: priority == .urgent
        )
        
        playAccessibilityAnnouncement(accessibilityEvent)
    }
    
    /// Set voice volume (0.0 to 1.0)
    public func setVoiceVolume(_ volume: Float) {
        voiceVolume = max(0.0, min(1.0, volume))
    }
    
    /// Set speech rate (0.0 to 1.0)
    public func setSpeechRate(_ rate: Float) {
        speechRate = max(0.0, min(1.0, rate))
    }
    
    /// Change the selected voice profile
    public func setVoiceProfile(_ profile: VoiceProfile) {
        selectedVoice = profile
    }
    
    /// Stop current speech and clear queue
    public func stopSpeech() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        narrativeQueue.removeAll()
        currentNarrative = nil
        isSpeaking = false
    }
    
    /// Pause current speech
    public func pauseSpeech() {
        speechSynthesizer.pauseSpeaking(at: .word)
    }
    
    /// Resume paused speech
    public func resumeSpeech() {
        speechSynthesizer.continueSpeaking()
    }
    
    /// Register a new AI competitor with voice profile
    public func registerCompetitor(id: String, name: String, voiceProfile: VoiceProfile, personality: CompetitorPersonality) {
        competitorVoices[id] = voiceProfile
        competitorPersonalities[id] = personality
        
        print("Registered competitor voice: \(name) with profile \(voiceProfile)")
    }
    
    /// Get narrative progress for UI
    public func getNarrativeProgress() -> NarrativeProgress {
        return NarrativeProgress(
            currentEvent: currentNarrative,
            queueLength: narrativeQueue.count,
            isPlaying: isSpeaking,
            estimatedDuration: getEstimatedDuration()
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupVoiceProfiles() {
        // Configure different voice profiles for various characters
        voiceProfiles[.narrator] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.siri_female_en-US_compact",
            rate: 0.5,
            pitch: 1.0,
            volume: 0.8,
            language: "en-US"
        )
        
        voiceProfiles[.competitor1] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.Samantha-compact",
            rate: 0.45,
            pitch: 0.9,
            volume: 0.7,
            language: "en-US"
        )
        
        voiceProfiles[.competitor2] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.Alex-compact",
            rate: 0.55,
            pitch: 1.1,
            volume: 0.75,
            language: "en-US"
        )
        
        voiceProfiles[.systemAdvisor] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.siri_male_en-US_compact",
            rate: 0.6,
            pitch: 1.0,
            volume: 0.8,
            language: "en-US"
        )
        
        voiceProfiles[.newsReporter] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.Daniel-compact",
            rate: 0.65,
            pitch: 1.0,
            volume: 0.9,
            language: "en-US"
        )
        
        voiceProfiles[.accessibility] = VoiceConfiguration(
            voiceIdentifier: "com.apple.ttsbundle.siri_female_en-US_compact",
            rate: 0.55,
            pitch: 1.0,
            volume: 1.0,
            language: "en-US"
        )
    }
    
    private func setupNarrativeLibrary() {
        // Game Start Narratives
        narrativeLibrary[.gameStart] = [
            NarrativeScript(
                text: "Welcome to FlexPort, captain. The global shipping industry awaits your command. Build your fleet, establish trade routes, and compete with AI rivals in this dynamic logistics empire.",
                duration: 8.0,
                voiceProfile: .narrator
            )
        ]
        
        // Market Events
        narrativeLibrary[.marketCrash] = [
            NarrativeScript(
                text: "Breaking news: Global commodity markets are experiencing significant volatility. Oil prices have dropped 15% in the last hour, affecting shipping costs worldwide.",
                duration: 6.0,
                voiceProfile: .newsReporter
            ),
            NarrativeScript(
                text: "Market turbulence detected, captain. This could be an opportunity to secure cheaper fuel contracts or a threat to your current investments.",
                duration: 5.0,
                voiceProfile: .systemAdvisor
            )
        ]
        
        // Ship Events
        narrativeLibrary[.shipPurchase] = [
            NarrativeScript(
                text: "Congratulations on your new vessel acquisition. This addition to your fleet opens new possibilities for expanded trade operations.",
                duration: 4.0,
                voiceProfile: .narrator
            )
        ]
        
        // Route Events
        narrativeLibrary[.routeCompleted] = [
            NarrativeScript(
                text: "Route completed successfully. Your cargo has been delivered on time, earning you reputation points and profit.",
                duration: 4.0,
                voiceProfile: .systemAdvisor
            )
        ]
        
        // Weather Events
        narrativeLibrary[.stormWarning] = [
            NarrativeScript(
                text: "Storm warning issued for the North Atlantic shipping lanes. Vessels in the area should seek safe harbor or adjust their routes immediately.",
                duration: 5.0,
                voiceProfile: .newsReporter
            )
        ]
        
        // Competitor Actions
        narrativeLibrary[.competitorThreat] = [
            NarrativeScript(
                text: "Intelligence reports suggest a rival shipping company is targeting your most profitable routes. Stay vigilant, captain.",
                duration: 4.0,
                voiceProfile: .systemAdvisor
            )
        ]
        
        // Achievement Events
        narrativeLibrary[.majorAchievement] = [
            NarrativeScript(
                text: "Outstanding achievement unlocked! Your shipping empire has reached a significant milestone. The maritime industry takes notice of your success.",
                duration: 5.0,
                voiceProfile: .narrator
            )
        ]
    }
    
    private func setupSpeechSynthesizer() {
        speechSynthesizer.delegate = self
    }
    
    private func setupAccessibilityMonitoring() {
        // Monitor VoiceOver settings
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleVoiceOverStatusChange()
            }
            .store(in: &cancellables)
    }
    
    private func requestSpeechPermissions(completion: @escaping (Bool) -> Void) {
        // Request speech recognition permissions
        SFSpeechRecognizer.requestAuthorization { status in
            completion(status == .authorized)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for speech: \(error)")
        }
    }
    
    private func createNarrativeEvent(type: NarrativeType, context: NarrativeContext?, priority: NarrativePriority) -> NarrativeEvent {
        let scripts = narrativeLibrary[type] ?? []
        let selectedScript = scripts.randomElement() ?? NarrativeScript(
            text: "Narrative not available.",
            duration: 2.0,
            voiceProfile: .narrator
        )
        
        // Customize script based on context
        let customizedText = customizeNarrativeText(selectedScript.text, context: context)
        
        return NarrativeEvent(
            id: UUID(),
            type: type,
            script: NarrativeScript(
                text: customizedText,
                duration: selectedScript.duration,
                voiceProfile: selectedScript.voiceProfile
            ),
            priority: priority,
            context: context,
            timestamp: Date()
        )
    }
    
    private func customizeNarrativeText(_ text: String, context: NarrativeContext?) -> String {
        guard let context = context else { return text }
        
        var customizedText = text
        
        // Replace placeholders with context data
        if let playerName = context.playerName {
            customizedText = customizedText.replacingOccurrences(of: "{player}", with: playerName)
        }
        
        if let shipName = context.shipName {
            customizedText = customizedText.replacingOccurrences(of: "{ship}", with: shipName)
        }
        
        if let routeName = context.routeName {
            customizedText = customizedText.replacingOccurrences(of: "{route}", with: routeName)
        }
        
        if let value = context.monetaryValue {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            let formattedValue = formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
            customizedText = customizedText.replacingOccurrences(of: "{value}", with: formattedValue)
        }
        
        return customizedText
    }
    
    private func queueNarrative(_ narrative: NarrativeEvent) {
        switch configuration.interruptionBehavior {
        case .interrupt:
            stopSpeech()
            narrativeQueue = [narrative]
            
        case .queue:
            if narrativeQueue.count < configuration.maxQueuedNarratives {
                narrativeQueue.append(narrative)
            }
            
        case .skip:
            if !isSpeaking {
                narrativeQueue.append(narrative)
            }
        }
        
        if !isQueueProcessing {
            processNarrativeQueue()
        }
    }
    
    private func processNarrativeQueue() {
        guard !narrativeQueue.isEmpty && !isQueueProcessing else { return }
        
        isQueueProcessing = true
        let nextNarrative = narrativeQueue.removeFirst()
        currentNarrative = nextNarrative
        
        speakNarrative(nextNarrative)
    }
    
    private func speakNarrative(_ narrative: NarrativeEvent) {
        let voiceConfig = voiceProfiles[narrative.script.voiceProfile] ?? voiceProfiles[.narrator]!
        
        let utterance = AVSpeechUtterance(string: narrative.script.text)
        
        // Configure voice
        if let voice = AVSpeechSynthesisVoice(identifier: voiceConfig.voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: voiceConfig.language)
        }
        
        // Configure speech parameters
        utterance.rate = voiceConfig.rate * speechRate
        utterance.pitchMultiplier = voiceConfig.pitch
        utterance.volume = voiceConfig.volume * voiceVolume
        
        currentUtterance = utterance
        isSpeaking = true
        
        speechSynthesizer.speak(utterance)
        
        print("Speaking narrative: \(narrative.script.text)")
    }
    
    private func playCompetitorMessage(_ dialogue: CompetitorDialogue) {
        let voiceConfig = voiceProfiles[dialogue.voice] ?? voiceProfiles[.competitor1]!
        
        // Modify voice based on emotion
        var adjustedConfig = voiceConfig
        switch dialogue.emotion {
        case .aggressive:
            adjustedConfig.rate *= 1.2
            adjustedConfig.pitch *= 1.1
        case .confident:
            adjustedConfig.rate *= 0.9
            adjustedConfig.pitch *= 1.05
        case .nervous:
            adjustedConfig.rate *= 1.1
            adjustedConfig.pitch *= 1.15
        case .friendly:
            adjustedConfig.rate *= 0.95
            adjustedConfig.pitch *= 0.95
        case .neutral:
            break
        }
        
        let utterance = AVSpeechUtterance(string: dialogue.message)
        
        if let voice = AVSpeechSynthesisVoice(identifier: adjustedConfig.voiceIdentifier) {
            utterance.voice = voice
        }
        
        utterance.rate = adjustedConfig.rate * speechRate
        utterance.pitchMultiplier = adjustedConfig.pitch
        utterance.volume = adjustedConfig.volume * voiceVolume
        
        speechSynthesizer.speak(utterance)
        
        print("Competitor \(dialogue.competitorId) says: \(dialogue.message)")
    }
    
    private func playAccessibilityAnnouncement(_ announcement: AccessibilityAnnouncement) {
        guard configuration.enableAccessibilityVoice else { return }
        
        if announcement.interruptCurrent && isSpeaking {
            stopSpeech()
        }
        
        let voiceConfig = voiceProfiles[.accessibility]!
        let utterance = AVSpeechUtterance(string: announcement.description)
        
        if let voice = AVSpeechSynthesisVoice(identifier: voiceConfig.voiceIdentifier) {
            utterance.voice = voice
        }
        
        utterance.rate = voiceConfig.rate * speechRate
        utterance.pitchMultiplier = voiceConfig.pitch
        utterance.volume = voiceConfig.volume * voiceVolume
        
        speechSynthesizer.speak(utterance)
        
        print("Accessibility announcement: \(announcement.description)")
    }
    
    private func getEstimatedDuration() -> TimeInterval {
        var totalDuration: TimeInterval = 0
        
        if let current = currentNarrative {
            totalDuration += current.script.duration
        }
        
        for narrative in narrativeQueue {
            totalDuration += narrative.script.duration
        }
        
        return totalDuration
    }
    
    private func handleVoiceOverStatusChange() {
        if UIAccessibility.isVoiceOverRunning && configuration.respectSystemVoiceOverSettings {
            // Adjust voice-over behavior when system VoiceOver is active
            configuration.enableAccessibilityVoice = false
        } else {
            configuration.enableAccessibilityVoice = true
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceOverSystem: AVSpeechSynthesizerDelegate {
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentUtterance = nil
        currentNarrative = nil
        isQueueProcessing = false
        
        // Process next item in queue
        if !narrativeQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.processNarrativeQueue()
            }
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Handle pause
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        // Handle resume
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentUtterance = nil
        currentNarrative = nil
        isQueueProcessing = false
    }
}

// MARK: - Supporting Types

public enum VoiceProfile: String, CaseIterable {
    case narrator
    case competitor1
    case competitor2
    case systemAdvisor
    case newsReporter
    case accessibility
}

public enum NarrativeType: String, CaseIterable {
    case gameStart
    case marketCrash
    case marketBoom
    case shipPurchase
    case routeCompleted
    case routeFailed
    case stormWarning
    case competitorThreat
    case majorAchievement
    case tradeDeal
    case emergencyEvent
    case tutorialStep
}

public enum NarrativePriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
}

public enum InterruptionBehavior {
    case interrupt
    case queue
    case skip
}

public enum EmotionalTone {
    case neutral
    case aggressive
    case confident
    case nervous
    case friendly
}

public enum AccessibilityPriority {
    case low
    case medium
    case urgent
}

public struct VoiceConfiguration {
    public let voiceIdentifier: String
    public var rate: Float
    public var pitch: Float
    public var volume: Float
    public let language: String
    
    public init(voiceIdentifier: String, rate: Float, pitch: Float, volume: Float, language: String) {
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.language = language
    }
}

public struct NarrativeScript {
    public let text: String
    public let duration: TimeInterval
    public let voiceProfile: VoiceProfile
    
    public init(text: String, duration: TimeInterval, voiceProfile: VoiceProfile) {
        self.text = text
        self.duration = duration
        self.voiceProfile = voiceProfile
    }
}

public struct NarrativeEvent {
    public let id: UUID
    public let type: NarrativeType
    public let script: NarrativeScript
    public let priority: NarrativePriority
    public let context: NarrativeContext?
    public let timestamp: Date
    
    public init(id: UUID, type: NarrativeType, script: NarrativeScript, priority: NarrativePriority, context: NarrativeContext?, timestamp: Date) {
        self.id = id
        self.type = type
        self.script = script
        self.priority = priority
        self.context = context
        self.timestamp = timestamp
    }
}

public struct NarrativeContext {
    public let playerName: String?
    public let shipName: String?
    public let routeName: String?
    public let monetaryValue: Double?
    public let competitorName: String?
    public let locationName: String?
    
    public init(playerName: String? = nil, shipName: String? = nil, routeName: String? = nil, 
                monetaryValue: Double? = nil, competitorName: String? = nil, locationName: String? = nil) {
        self.playerName = playerName
        self.shipName = shipName
        self.routeName = routeName
        self.monetaryValue = monetaryValue
        self.competitorName = competitorName
        self.locationName = locationName
    }
}

public struct CompetitorDialogue {
    public let competitorId: String
    public let message: String
    public let voice: VoiceProfile
    public let emotion: EmotionalTone
    public let personality: CompetitorPersonality
    
    public init(competitorId: String, message: String, voice: VoiceProfile, emotion: EmotionalTone, personality: CompetitorPersonality) {
        self.competitorId = competitorId
        self.message = message
        self.voice = voice
        self.emotion = emotion
        self.personality = personality
    }
}

public struct CompetitorPersonality {
    public let aggressiveness: Float // 0.0 to 1.0
    public let verbosity: Float // 0.0 to 1.0
    public let formality: Float // 0.0 to 1.0
    public let confidence: Float // 0.0 to 1.0
    
    public init(aggressiveness: Float = 0.5, verbosity: Float = 0.5, formality: Float = 0.5, confidence: Float = 0.5) {
        self.aggressiveness = aggressiveness
        self.verbosity = verbosity
        self.formality = formality
        self.confidence = confidence
    }
}

public struct AccessibilityAnnouncement {
    public let description: String
    public let priority: AccessibilityPriority
    public let interruptCurrent: Bool
    
    public init(description: String, priority: AccessibilityPriority, interruptCurrent: Bool) {
        self.description = description
        self.priority = priority
        self.interruptCurrent = interruptCurrent
    }
}

public struct NarrativeProgress {
    public let currentEvent: NarrativeEvent?
    public let queueLength: Int
    public let isPlaying: Bool
    public let estimatedDuration: TimeInterval
    
    public init(currentEvent: NarrativeEvent?, queueLength: Int, isPlaying: Bool, estimatedDuration: TimeInterval) {
        self.currentEvent = currentEvent
        self.queueLength = queueLength
        self.isPlaying = isPlaying
        self.estimatedDuration = estimatedDuration
    }
}