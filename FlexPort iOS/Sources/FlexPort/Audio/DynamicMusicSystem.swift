import Foundation
import AVFoundation
import simd
import Combine

/// Advanced dynamic music system that responds to gameplay, market conditions, and player actions
public class DynamicMusicSystem: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DynamicMusicSystem()
    
    // MARK: - Published Properties
    @Published public private(set) var currentMusicState: MusicState = .menu
    @Published public private(set) var currentIntensity: Float = 0.5
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTrack: MusicTrack?
    @Published public private(set) var adaptiveVolume: Float = 0.7
    
    // MARK: - Audio Engine Components
    private let audioEngine = AVAudioEngine()
    private let masterMixerNode = AVAudioMixerNode()
    
    // Music layers for adaptive composition
    private var musicLayers: [MusicLayer: MusicPlayerLayer] = [:]
    private var crossfadeNodes: [CrossfadeNode] = []
    
    // MARK: - Game State Monitoring
    private var gameStateSubscription: AnyCancellable?
    private var marketStateSubscription: AnyCancellable?
    private var playerActionSubscription: AnyCancellable?
    
    // MARK: - Music Composition
    private var currentComposition: AdaptiveComposition?
    private var transitionQueue: [MusicTransition] = []
    private var isTransitioning: Bool = false
    
    // MARK: - Configuration
    public struct Configuration {
        public var adaptiveVolumeEnabled: Bool = true
        public var crossfadeDuration: TimeInterval = 4.0
        public var intensityResponseTime: TimeInterval = 2.0
        public var marketSensitivity: Float = 0.3
        public var actionResponseSensitivity: Float = 0.5
        public var enableProcedualElements: Bool = true
        public var maxSimultaneousLayers: Int = 8
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - State Management
    private var currentMarketVolatility: Float = 0.0
    private var playerStressLevel: Float = 0.0
    private var gameProgressionLevel: Float = 0.0
    private var timeOfDay: Float = 0.5 // 0.0 = midnight, 0.5 = noon, 1.0 = midnight
    
    private var cancellables = Set<AnyCancellable>()
    private let musicQueue = DispatchQueue(label: "com.flexport.music", qos: .userInteractive)
    
    // MARK: - Initialization
    private init() {
        setupAudioEngine()
        setupGameStateMonitoring()
        loadMusicLibrary()
    }
    
    // MARK: - Public Interface
    
    /// Start the dynamic music system
    public func startMusicSystem() throws {
        guard !audioEngine.isRunning else { return }
        
        try audioEngine.start()
        isPlaying = true
        
        // Start with menu music
        transitionToMusicState(.menu, intensity: 0.3)
        
        print("Dynamic Music System started")
    }
    
    /// Stop the music system
    public func stopMusicSystem() {
        fadeOutAllLayers(duration: 2.0) { [weak self] in
            self?.audioEngine.stop()
            self?.isPlaying = false
        }
        
        print("Dynamic Music System stopped")
    }
    
    /// Transition to a new music state
    public func transitionToMusicState(_ state: MusicState, intensity: Float = 0.5, duration: TimeInterval? = nil) {
        let transition = MusicTransition(
            fromState: currentMusicState,
            toState: state,
            targetIntensity: intensity,
            duration: duration ?? configuration.crossfadeDuration,
            type: .smooth
        )
        
        queueTransition(transition)
    }
    
    /// Set music intensity (0.0 to 1.0)
    public func setMusicIntensity(_ intensity: Float, duration: TimeInterval = 2.0) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        musicQueue.async { [weak self] in
            self?.adjustCompositionIntensity(clampedIntensity, duration: duration)
        }
        
        currentIntensity = clampedIntensity
    }
    
    /// Trigger music response to player action
    public func triggerActionResponse(_ action: PlayerAction, intensity: Float = 1.0) {
        let responseIntensity = intensity * configuration.actionResponseSensitivity
        
        switch action {
        case .tradeSuccess:
            playStinger(.success, intensity: responseIntensity)
        case .tradeFailed:
            playStinger(.tension, intensity: responseIntensity)
        case .newRoute:
            playStinger(.discovery, intensity: responseIntensity)
        case .shipPurchase:
            playStinger(.achievement, intensity: responseIntensity)
        case .marketCrash:
            triggerEmergencyMusic(duration: 10.0)
        case .competitorThreat:
            increaseIntensity(by: responseIntensity, duration: 5.0)
        case .majorSuccess:
            playStinger(.triumph, intensity: responseIntensity)
            increaseIntensity(by: 0.3, duration: 8.0)
        }
    }
    
    /// Update music based on market conditions
    public func updateMarketConditions(volatility: Float, trend: MarketTrend, volume: Float) {
        currentMarketVolatility = volatility
        
        let marketIntensity = volatility * configuration.marketSensitivity
        let targetIntensity = currentIntensity + marketIntensity
        
        setMusicIntensity(targetIntensity, duration: configuration.intensityResponseTime)
        
        // Adjust harmonic content based on market trend
        adjustHarmonicContent(for: trend)
    }
    
    /// Set time of day for music adaptation
    public func setTimeOfDay(_ time: Float) {
        timeOfDay = max(0.0, min(1.0, time))
        updateTimeBasedElements()
    }
    
    /// Play a musical stinger for immediate feedback
    public func playStinger(_ type: StingerType, intensity: Float = 1.0) {
        guard let stingerSound = getStingerSound(for: type) else { return }
        
        let stingerNode = AVAudioPlayerNode()
        audioEngine.attach(stingerNode)
        audioEngine.connect(stingerNode, to: masterMixerNode, format: stingerSound.format)
        
        stingerNode.volume = intensity * adaptiveVolume
        stingerNode.scheduleBuffer(stingerSound, completionHandler: { [weak self] in
            self?.audioEngine.detach(stingerNode)
        })
        
        stingerNode.play()
    }
    
    /// Get current music metrics for analytics
    public func getMusicMetrics() -> MusicMetrics {
        return MusicMetrics(
            currentState: currentMusicState,
            intensity: currentIntensity,
            activeLayers: musicLayers.values.filter { $0.isActive }.count,
            marketVolatility: currentMarketVolatility,
            playerStress: playerStressLevel,
            timeOfDay: timeOfDay
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupAudioEngine() {
        // Attach master mixer
        audioEngine.attach(masterMixerNode)
        audioEngine.connect(masterMixerNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Configure audio session for background music
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for music: \(error)")
        }
        
        audioEngine.prepare()
    }
    
    private func setupGameStateMonitoring() {
        // Monitor game state changes
        gameStateSubscription = NotificationCenter.default
            .publisher(for: .gameStateChanged)
            .sink { [weak self] notification in
                self?.handleGameStateChange(notification)
            }
        
        // Monitor market changes
        marketStateSubscription = NotificationCenter.default
            .publisher(for: .marketStateChanged)
            .sink { [weak self] notification in
                self?.handleMarketStateChange(notification)
            }
        
        // Monitor player actions
        playerActionSubscription = NotificationCenter.default
            .publisher(for: .playerActionOccurred)
            .sink { [weak self] notification in
                self?.handlePlayerAction(notification)
            }
    }
    
    private func loadMusicLibrary() {
        // Initialize music layers for each composition element
        musicQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create different music layers
            self.createMusicLayer(.foundation, fileName: "music_foundation")
            self.createMusicLayer(.harmony, fileName: "music_harmony")
            self.createMusicLayer(.melody, fileName: "music_melody")
            self.createMusicLayer(.percussion, fileName: "music_percussion")
            self.createMusicLayer(.ambient, fileName: "music_ambient")
            self.createMusicLayer(.tension, fileName: "music_tension")
            self.createMusicLayer(.triumph, fileName: "music_triumph")
            self.createMusicLayer(.exploration, fileName: "music_exploration")
        }
    }
    
    private func createMusicLayer(_ layer: MusicLayer, fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "m4a") else {
            print("Music file not found: \(fileName)")
            return
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                        frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)
            
            let playerLayer = MusicPlayerLayer(
                layer: layer,
                audioBuffer: buffer,
                playerNode: AVAudioPlayerNode(),
                volumeNode: AVAudioMixerNode()
            )
            
            // Set up audio graph for this layer
            audioEngine.attach(playerLayer.playerNode)
            audioEngine.attach(playerLayer.volumeNode)
            
            audioEngine.connect(playerLayer.playerNode, to: playerLayer.volumeNode, format: buffer.format)
            audioEngine.connect(playerLayer.volumeNode, to: masterMixerNode, format: nil)
            
            musicLayers[layer] = playerLayer
            
            print("Loaded music layer: \(layer)")
        } catch {
            print("Failed to load music layer \(layer): \(error)")
        }
    }
    
    private func queueTransition(_ transition: MusicTransition) {
        musicQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isTransitioning {
                self.transitionQueue.append(transition)
            } else {
                self.executeTransition(transition)
            }
        }
    }
    
    private func executeTransition(_ transition: MusicTransition) {
        isTransitioning = true
        currentMusicState = transition.toState
        
        print("Transitioning music from \(transition.fromState) to \(transition.toState)")
        
        // Get composition for new state
        let newComposition = createComposition(for: transition.toState, intensity: transition.targetIntensity)
        
        // Cross-fade between compositions
        crossfadeToComposition(newComposition, duration: transition.duration) { [weak self] in
            self?.isTransitioning = false
            self?.processNextTransition()
        }
        
        currentComposition = newComposition
    }
    
    private func createComposition(for state: MusicState, intensity: Float) -> AdaptiveComposition {
        let composition = AdaptiveComposition(state: state, intensity: intensity)
        
        switch state {
        case .menu:
            composition.activeLayers = [.foundation, .ambient]
            composition.layerVolumes = [.foundation: 0.8, .ambient: 0.6]
            
        case .gameplay:
            composition.activeLayers = [.foundation, .harmony, .melody]
            composition.layerVolumes = [
                .foundation: 0.7,
                .harmony: 0.5 + intensity * 0.3,
                .melody: 0.3 + intensity * 0.4
            ]
            
        case .intense:
            composition.activeLayers = [.foundation, .harmony, .melody, .percussion, .tension]
            composition.layerVolumes = [
                .foundation: 0.8,
                .harmony: 0.6,
                .melody: 0.7,
                .percussion: 0.4 + intensity * 0.5,
                .tension: intensity * 0.8
            ]
            
        case .success:
            composition.activeLayers = [.foundation, .harmony, .melody, .triumph]
            composition.layerVolumes = [
                .foundation: 0.7,
                .harmony: 0.8,
                .melody: 0.9,
                .triumph: 0.6 + intensity * 0.4
            ]
            
        case .exploration:
            composition.activeLayers = [.foundation, .ambient, .exploration]
            composition.layerVolumes = [
                .foundation: 0.6,
                .ambient: 0.8,
                .exploration: 0.5 + intensity * 0.3
            ]
            
        case .crisis:
            composition.activeLayers = [.foundation, .percussion, .tension]
            composition.layerVolumes = [
                .foundation: 0.9,
                .percussion: 0.8 + intensity * 0.2,
                .tension: 0.7 + intensity * 0.3
            ]
        }
        
        return composition
    }
    
    private func crossfadeToComposition(_ composition: AdaptiveComposition, duration: TimeInterval, completion: @escaping () -> Void) {
        // Fade out inactive layers
        for (layer, playerLayer) in musicLayers {
            if !composition.activeLayers.contains(layer) && playerLayer.isActive {
                fadeOutLayer(layer, duration: duration)
            }
        }
        
        // Fade in active layers
        for layer in composition.activeLayers {
            guard let playerLayer = musicLayers[layer] else { continue }
            
            let targetVolume = composition.layerVolumes[layer] ?? 0.5
            
            if !playerLayer.isActive {
                startLayer(layer, volume: 0.0)
                fadeInLayer(layer, targetVolume: targetVolume, duration: duration)
            } else {
                adjustLayerVolume(layer, targetVolume: targetVolume, duration: duration)
            }
        }
        
        // Call completion after fade duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
    
    private func startLayer(_ layer: MusicLayer, volume: Float) {
        guard let playerLayer = musicLayers[layer] else { return }
        
        playerLayer.volumeNode.outputVolume = volume
        playerLayer.playerNode.scheduleBuffer(playerLayer.audioBuffer, at: nil, options: .loops, completionHandler: nil)
        playerLayer.playerNode.play()
        playerLayer.isActive = true
    }
    
    private func fadeInLayer(_ layer: MusicLayer, targetVolume: Float, duration: TimeInterval) {
        animateLayerVolume(layer, to: targetVolume, duration: duration)
    }
    
    private func fadeOutLayer(_ layer: MusicLayer, duration: TimeInterval) {
        animateLayerVolume(layer, to: 0.0, duration: duration) { [weak self] in
            self?.stopLayer(layer)
        }
    }
    
    private func stopLayer(_ layer: MusicLayer) {
        guard let playerLayer = musicLayers[layer] else { return }
        
        playerLayer.playerNode.stop()
        playerLayer.isActive = false
    }
    
    private func adjustLayerVolume(_ layer: MusicLayer, targetVolume: Float, duration: TimeInterval) {
        animateLayerVolume(layer, to: targetVolume, duration: duration)
    }
    
    private func animateLayerVolume(_ layer: MusicLayer, to targetVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let playerLayer = musicLayers[layer] else { return }
        
        let startVolume = playerLayer.volumeNode.outputVolume
        let volumeChange = targetVolume - startVolume
        let stepDuration = 0.1
        let steps = Int(duration / stepDuration)
        let stepSize = volumeChange / Float(steps)
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let newVolume = startVolume + stepSize * Float(currentStep)
            
            DispatchQueue.main.async {
                playerLayer.volumeNode.outputVolume = newVolume
            }
            
            if currentStep >= steps {
                timer.invalidate()
                DispatchQueue.main.async {
                    playerLayer.volumeNode.outputVolume = targetVolume
                    completion?()
                }
            }
        }
    }
    
    private func adjustCompositionIntensity(_ intensity: Float, duration: TimeInterval) {
        guard let composition = currentComposition else { return }
        
        composition.intensity = intensity
        
        // Recalculate layer volumes based on new intensity
        let newComposition = createComposition(for: composition.state, intensity: intensity)
        
        for layer in composition.activeLayers {
            if let targetVolume = newComposition.layerVolumes[layer] {
                adjustLayerVolume(layer, targetVolume: targetVolume, duration: duration)
            }
        }
    }
    
    private func increaseIntensity(by amount: Float, duration: TimeInterval) {
        let newIntensity = min(1.0, currentIntensity + amount)
        setMusicIntensity(newIntensity, duration: duration)
        
        // Schedule intensity reduction after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 2.0) { [weak self] in
            guard let self = self else { return }
            let reducedIntensity = max(0.0, self.currentIntensity - amount * 0.5)
            self.setMusicIntensity(reducedIntensity)
        }
    }
    
    private func triggerEmergencyMusic(duration: TimeInterval) {
        // Temporarily switch to crisis music
        let originalState = currentMusicState
        let originalIntensity = currentIntensity
        
        transitionToMusicState(.crisis, intensity: 0.9, duration: 1.0)
        
        // Return to previous state after emergency
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.transitionToMusicState(originalState, intensity: originalIntensity)
        }
    }
    
    private func adjustHarmonicContent(for trend: MarketTrend) {
        // Adjust EQ and harmonic content based on market trend
        // This would involve real-time audio processing
        
        switch trend {
        case .bullish:
            // Brighter, more optimistic harmonics
            break
        case .bearish:
            // Darker, more subdued harmonics
            break
        case .volatile:
            // More dissonant, unstable harmonics
            break
        case .stable:
            // Consonant, stable harmonics
            break
        }
    }
    
    private func updateTimeBasedElements() {
        // Adjust ambient layers based on time of day
        if let ambientLayer = musicLayers[.ambient] {
            let dayTimeVolume = sin(timeOfDay * .pi) * 0.3 + 0.2
            adjustLayerVolume(.ambient, targetVolume: Float(dayTimeVolume), duration: 5.0)
        }
    }
    
    private func processNextTransition() {
        guard !transitionQueue.isEmpty else { return }
        
        let nextTransition = transitionQueue.removeFirst()
        executeTransition(nextTransition)
    }
    
    private func fadeOutAllLayers(duration: TimeInterval, completion: @escaping () -> Void) {
        var layersToFade = musicLayers.values.filter { $0.isActive }.count
        
        if layersToFade == 0 {
            completion()
            return
        }
        
        for (layer, playerLayer) in musicLayers {
            if playerLayer.isActive {
                fadeOutLayer(layer, duration: duration)
                layersToFade -= 1
                
                if layersToFade == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        completion()
                    }
                }
            }
        }
    }
    
    private func getStingerSound(for type: StingerType) -> AVAudioPCMBuffer? {
        let fileName = "stinger_\(type.rawValue)"
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav") else {
            print("Stinger sound not found: \(fileName)")
            return nil
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                        frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)
            return buffer
        } catch {
            print("Failed to load stinger sound: \(error)")
            return nil
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleGameStateChange(_ notification: Notification) {
        guard let gameState = notification.userInfo?["gameState"] as? String else { return }
        
        switch gameState {
        case "mainMenu":
            transitionToMusicState(.menu)
        case "gameStarted":
            transitionToMusicState(.gameplay, intensity: 0.4)
        case "gameEnded":
            transitionToMusicState(.menu, intensity: 0.3)
        default:
            break
        }
    }
    
    private func handleMarketStateChange(_ notification: Notification) {
        guard let volatility = notification.userInfo?["volatility"] as? Float,
              let trendString = notification.userInfo?["trend"] as? String,
              let volume = notification.userInfo?["volume"] as? Float else { return }
        
        let trend = MarketTrend(rawValue: trendString) ?? .stable
        updateMarketConditions(volatility: volatility, trend: trend, volume: volume)
    }
    
    private func handlePlayerAction(_ notification: Notification) {
        guard let actionString = notification.userInfo?["action"] as? String,
              let action = PlayerAction(rawValue: actionString) else { return }
        
        let intensity = notification.userInfo?["intensity"] as? Float ?? 1.0
        triggerActionResponse(action, intensity: intensity)
    }
}

// MARK: - Supporting Types

public enum MusicState: String, CaseIterable {
    case menu
    case gameplay
    case intense
    case success
    case exploration
    case crisis
}

public enum MusicLayer: String, CaseIterable {
    case foundation
    case harmony
    case melody
    case percussion
    case ambient
    case tension
    case triumph
    case exploration
}

public enum PlayerAction: String, CaseIterable {
    case tradeSuccess
    case tradeFailed
    case newRoute
    case shipPurchase
    case marketCrash
    case competitorThreat
    case majorSuccess
}

public enum MarketTrend: String, CaseIterable {
    case bullish
    case bearish
    case volatile
    case stable
}

public enum StingerType: String, CaseIterable {
    case success
    case tension
    case discovery
    case achievement
    case triumph
}

public class MusicPlayerLayer: ObservableObject {
    public let layer: MusicLayer
    public let audioBuffer: AVAudioPCMBuffer
    public let playerNode: AVAudioPlayerNode
    public let volumeNode: AVAudioMixerNode
    
    @Published public var isActive: Bool = false
    @Published public var currentVolume: Float = 0.0
    
    public init(layer: MusicLayer, audioBuffer: AVAudioPCMBuffer, playerNode: AVAudioPlayerNode, volumeNode: AVAudioMixerNode) {
        self.layer = layer
        self.audioBuffer = audioBuffer
        self.playerNode = playerNode
        self.volumeNode = volumeNode
    }
}

public class AdaptiveComposition: ObservableObject {
    public let state: MusicState
    @Published public var intensity: Float
    @Published public var activeLayers: Set<MusicLayer> = []
    @Published public var layerVolumes: [MusicLayer: Float] = [:]
    
    public init(state: MusicState, intensity: Float) {
        self.state = state
        self.intensity = intensity
    }
}

public struct MusicTransition {
    public let fromState: MusicState
    public let toState: MusicState
    public let targetIntensity: Float
    public let duration: TimeInterval
    public let type: TransitionType
    
    public enum TransitionType {
        case smooth
        case immediate
        case dramatic
    }
}

public class CrossfadeNode: ObservableObject {
    public let inputA: AVAudioMixerNode
    public let inputB: AVAudioMixerNode
    public let output: AVAudioMixerNode
    
    @Published public var crossfadePosition: Float = 0.0 // 0.0 = A, 1.0 = B
    
    public init() {
        self.inputA = AVAudioMixerNode()
        self.inputB = AVAudioMixerNode()
        self.output = AVAudioMixerNode()
    }
    
    public func setCrossfade(_ position: Float) {
        let clampedPosition = max(0.0, min(1.0, position))
        crossfadePosition = clampedPosition
        
        inputA.outputVolume = cos(clampedPosition * .pi / 2)
        inputB.outputVolume = sin(clampedPosition * .pi / 2)
    }
}

public struct MusicMetrics {
    public let currentState: MusicState
    public let intensity: Float
    public let activeLayers: Int
    public let marketVolatility: Float
    public let playerStress: Float
    public let timeOfDay: Float
    
    public init(currentState: MusicState, intensity: Float, activeLayers: Int, 
                marketVolatility: Float, playerStress: Float, timeOfDay: Float) {
        self.currentState = currentState
        self.intensity = intensity
        self.activeLayers = activeLayers
        self.marketVolatility = marketVolatility
        self.playerStress = playerStress
        self.timeOfDay = timeOfDay
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let gameStateChanged = Notification.Name("gameStateChanged")
    static let marketStateChanged = Notification.Name("marketStateChanged")
    static let playerActionOccurred = Notification.Name("playerActionOccurred")
}