import Foundation
import AVFoundation
import Combine

/// Comprehensive audio settings and user preferences manager for personalized audio experience
public class AudioSettingsManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AudioSettingsManager()
    
    // MARK: - Published Properties
    @Published public var masterVolume: Float = 0.8 {
        didSet { applyMasterVolume() }
    }
    
    @Published public var musicVolume: Float = 0.7 {
        didSet { applyMusicVolume() }
    }
    
    @Published public var effectsVolume: Float = 0.8 {
        didSet { applyEffectsVolume() }
    }
    
    @Published public var voiceVolume: Float = 0.9 {
        didSet { applyVoiceVolume() }
    }
    
    @Published public var ambientVolume: Float = 0.6 {
        didSet { applyAmbientVolume() }
    }
    
    @Published public var hapticsEnabled: Bool = true {
        didSet { applyHapticsSettings() }
    }
    
    @Published public var spatialAudioEnabled: Bool = true {
        didSet { applySpatialAudioSettings() }
    }
    
    @Published public var audioQuality: AudioQualityLevel = .high {
        didSet { applyAudioQuality() }
    }
    
    @Published public var audioProfile: AudioProfile = .balanced {
        didSet { applyAudioProfile() }
    }
    
    @Published public var accessibilityMode: Bool = false {
        didSet { applyAccessibilityMode() }
    }
    
    // MARK: - Audio System References
    private let spatialAudioEngine = SpatialAudioEngine.shared
    private let dynamicMusicSystem = DynamicMusicSystem.shared
    private let environmentalAudio = EnvironmentalAudioGenerator.shared
    private let voiceOverSystem = VoiceOverSystem.shared
    private let hapticManager = HapticManager.shared
    private let accessibilityManager = AudioAccessibilityManager.shared
    private let shipAudioSystem = ShipAudioEffectsSystem.shared
    
    // MARK: - User Preferences
    @Published public var userPreferences = UserAudioPreferences()
    @Published public var customEQSettings = EqualizerSettings()
    @Published public var audioDeviceSettings = AudioDeviceSettings()
    
    // MARK: - Configuration
    public struct Configuration {
        public var saveSettingsAutomatically: Bool = true
        public var applySettingsImmediately: Bool = true
        public var enableCustomEQ: Bool = true
        public var enableAudioProfilePresets: Bool = true
        public var enableHardwareAcceleration: Bool = true
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - State Management
    private var cancellables = Set<AnyCancellable>()
    private var settingsUpdateQueue = DispatchQueue(label: "com.flexport.audio-settings", qos: .userInitiated)
    
    // MARK: - Initialization
    private init() {
        loadSavedSettings()
        setupSettingsObservers()
        detectAudioHardware()
    }
    
    // MARK: - Public Interface
    
    /// Apply all current settings to audio systems
    public func applyAllSettings() {
        settingsUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.applyMasterVolume()
            self.applyMusicVolume()
            self.applyEffectsVolume()
            self.applyVoiceVolume()
            self.applyAmbientVolume()
            self.applyHapticsSettings()
            self.applySpatialAudioSettings()
            self.applyAudioQuality()
            self.applyAudioProfile()
            self.applyAccessibilityMode()
            self.applyCustomEQSettings()
            self.applyAudioDeviceSettings()
        }
        
        print("Applied all audio settings")
    }
    
    /// Reset all settings to defaults
    public func resetToDefaults() {
        masterVolume = 0.8
        musicVolume = 0.7
        effectsVolume = 0.8
        voiceVolume = 0.9
        ambientVolume = 0.6
        hapticsEnabled = true
        spatialAudioEnabled = true
        audioQuality = .high
        audioProfile = .balanced
        accessibilityMode = false
        
        userPreferences = UserAudioPreferences()
        customEQSettings = EqualizerSettings()
        audioDeviceSettings = AudioDeviceSettings()
        
        saveSettings()
        
        print("Reset all audio settings to defaults")
    }
    
    /// Set audio profile with predefined settings
    public func setAudioProfile(_ profile: AudioProfile) {
        audioProfile = profile
        
        switch profile {
        case .balanced:
            setBalancedProfile()
        case .cinematic:
            setCinematicProfile()
        case .competitive:
            setCompetitiveProfile()
        case .casual:
            setCasualProfile()
        case .accessibility:
            setAccessibilityProfile()
        case .custom:
            // Keep current custom settings
            break
        }
        
        saveSettings()
    }
    
    /// Configure equalizer settings
    public func setEqualizerSettings(_ settings: EqualizerSettings) {
        customEQSettings = settings
        audioProfile = .custom
        applyCustomEQSettings()
        saveSettings()
    }
    
    /// Set volume for specific audio category
    public func setCategoryVolume(_ category: AudioCategory, volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        
        switch category {
        case .master:
            masterVolume = clampedVolume
        case .music:
            musicVolume = clampedVolume
        case .effects:
            effectsVolume = clampedVolume
        case .voice:
            voiceVolume = clampedVolume
        case .ambient:
            ambientVolume = clampedVolume
        }
    }
    
    /// Enable/disable specific audio feature
    public func setAudioFeature(_ feature: AudioFeature, enabled: Bool) {
        switch feature {
        case .haptics:
            hapticsEnabled = enabled
        case .spatialAudio:
            spatialAudioEnabled = enabled
        case .accessibility:
            accessibilityMode = enabled
        case .environmentalAudio:
            userPreferences.environmentalAudioEnabled = enabled
        case .dynamicMusic:
            userPreferences.dynamicMusicEnabled = enabled
        case .voiceNarration:
            userPreferences.voiceNarrationEnabled = enabled
        case .shipAudio:
            userPreferences.shipAudioEnabled = enabled
        }
        
        applyAllSettings()
        saveSettings()
    }
    
    /// Get current audio metrics for display
    public func getAudioMetrics() -> AudioSystemMetrics {
        return AudioSystemMetrics(
            masterVolume: masterVolume,
            activeAudioSources: getTotalActiveAudioSources(),
            memoryUsage: getTotalMemoryUsage(),
            cpuUsage: getAudioCPUUsage(),
            latency: getAudioLatency(),
            spatialAudioActive: spatialAudioEnabled,
            hapticsActive: hapticsEnabled
        )
    }
    
    /// Save current settings to persistent storage
    public func saveSettings() {
        guard configuration.saveSettingsAutomatically else { return }
        
        let settings = AudioSettings(
            volumes: VolumeSettings(
                master: masterVolume,
                music: musicVolume,
                effects: effectsVolume,
                voice: voiceVolume,
                ambient: ambientVolume
            ),
            features: FeatureSettings(
                hapticsEnabled: hapticsEnabled,
                spatialAudioEnabled: spatialAudioEnabled,
                accessibilityMode: accessibilityMode
            ),
            quality: audioQuality,
            profile: audioProfile,
            userPreferences: userPreferences,
            customEQ: customEQSettings,
            deviceSettings: audioDeviceSettings
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "FlexPortAudioSettings")
            print("Audio settings saved")
        }
    }
    
    /// Load settings from persistent storage
    public func loadSavedSettings() {
        guard let data = UserDefaults.standard.data(forKey: "FlexPortAudioSettings"),
              let settings = try? JSONDecoder().decode(AudioSettings.self, from: data) else {
            print("No saved audio settings found, using defaults")
            return
        }
        
        // Apply loaded settings
        masterVolume = settings.volumes.master
        musicVolume = settings.volumes.music
        effectsVolume = settings.volumes.effects
        voiceVolume = settings.volumes.voice
        ambientVolume = settings.volumes.ambient
        
        hapticsEnabled = settings.features.hapticsEnabled
        spatialAudioEnabled = settings.features.spatialAudioEnabled
        accessibilityMode = settings.features.accessibilityMode
        
        audioQuality = settings.quality
        audioProfile = settings.profile
        userPreferences = settings.userPreferences
        customEQSettings = settings.customEQ
        audioDeviceSettings = settings.deviceSettings
        
        print("Audio settings loaded")
    }
    
    // MARK: - Private Implementation
    
    private func setupSettingsObservers() {
        // Monitor audio session changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.handleAudioRouteChange()
            }
            .store(in: &cancellables)
        
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    private func detectAudioHardware() {
        let audioSession = AVAudioSession.sharedInstance()
        
        audioDeviceSettings.hasHeadphones = isHeadphonesConnected()
        audioDeviceSettings.hasExternalSpeakers = hasExternalSpeakers()
        audioDeviceSettings.supportsSpatialAudio = audioSession.availableCategories.contains(.playback)
        audioDeviceSettings.supportsHaptics = HapticManager.shared.isHapticsAvailable
        
        print("Audio hardware detected: \(audioDeviceSettings)")
    }
    
    private func applyMasterVolume() {
        spatialAudioEngine.setMasterVolume(masterVolume)
        dynamicMusicSystem.setMasterVolume(masterVolume)
    }
    
    private func applyMusicVolume() {
        dynamicMusicSystem.setMasterVolume(musicVolume * masterVolume)
    }
    
    private func applyEffectsVolume() {
        shipAudioSystem.setMasterShipVolume(effectsVolume * masterVolume)
        // Apply to other effect systems
    }
    
    private func applyVoiceVolume() {
        voiceOverSystem.setVoiceVolume(voiceVolume * masterVolume)
    }
    
    private func applyAmbientVolume() {
        environmentalAudio.setAmbientVolume(ambientVolume * masterVolume)
    }
    
    private func applyHapticsSettings() {
        hapticManager.setHapticsEnabled(hapticsEnabled)
    }
    
    private func applySpatialAudioSettings() {
        spatialAudioEngine.configuration.enableMetalAcceleration = spatialAudioEnabled
        // Additional spatial audio configuration
    }
    
    private func applyAudioQuality() {
        switch audioQuality {
        case .low:
            spatialAudioEngine.configuration.maxConcurrentSources = 16
            shipAudioSystem.configuration.maxConcurrentShipSounds = 4
        case .medium:
            spatialAudioEngine.configuration.maxConcurrentSources = 32
            shipAudioSystem.configuration.maxConcurrentShipSounds = 8
        case .high:
            spatialAudioEngine.configuration.maxConcurrentSources = 64
            shipAudioSystem.configuration.maxConcurrentShipSounds = 16
        case .ultra:
            spatialAudioEngine.configuration.maxConcurrentSources = 128
            shipAudioSystem.configuration.maxConcurrentShipSounds = 32
        }
    }
    
    private func applyAudioProfile() {
        // Audio profiles are applied in setAudioProfile method
    }
    
    private func applyAccessibilityMode() {
        accessibilityManager.setAudioDescriptionEnabled(accessibilityMode)
        accessibilityManager.setSoundReplacementEnabled(accessibilityMode)
        
        if accessibilityMode {
            // Boost important audio categories
            setCategoryVolume(.voice, volume: min(1.0, voiceVolume * 1.2))
            setCategoryVolume(.effects, volume: min(1.0, effectsVolume * 1.1))
        }
    }
    
    private func applyCustomEQSettings() {
        guard configuration.enableCustomEQ else { return }
        
        // Apply EQ settings to audio systems
        // This would involve real-time audio processing
        print("Applied custom EQ settings: \(customEQSettings)")
    }
    
    private func applyAudioDeviceSettings() {
        if audioDeviceSettings.hasHeadphones {
            // Optimize for headphone playback
            spatialAudioEngine.configuration.spatialPrecision = .high
        } else {
            // Optimize for speaker playback
            spatialAudioEngine.configuration.spatialPrecision = .medium
        }
    }
    
    // MARK: - Audio Profile Presets
    
    private func setBalancedProfile() {
        musicVolume = 0.7
        effectsVolume = 0.8
        voiceVolume = 0.9
        ambientVolume = 0.6
        
        userPreferences.environmentalAudioEnabled = true
        userPreferences.dynamicMusicEnabled = true
        userPreferences.voiceNarrationEnabled = true
        userPreferences.shipAudioEnabled = true
    }
    
    private func setCinematicProfile() {
        musicVolume = 0.9
        effectsVolume = 0.9
        voiceVolume = 1.0
        ambientVolume = 0.8
        
        spatialAudioEnabled = true
        userPreferences.environmentalAudioEnabled = true
        userPreferences.dynamicMusicEnabled = true
        userPreferences.immersiveExperienceLevel = .maximum
    }
    
    private func setCompetitiveProfile() {
        musicVolume = 0.3
        effectsVolume = 1.0
        voiceVolume = 0.8
        ambientVolume = 0.4
        
        userPreferences.competitiveAudioMode = true
        userPreferences.importantSoundsOnly = true
        userPreferences.immersiveExperienceLevel = .minimal
    }
    
    private func setCasualProfile() {
        musicVolume = 0.8
        effectsVolume = 0.6
        voiceVolume = 0.7
        ambientVolume = 0.7
        
        userPreferences.relaxedAudioMode = true
        userPreferences.immersiveExperienceLevel = .moderate
    }
    
    private func setAccessibilityProfile() {
        musicVolume = 0.4
        effectsVolume = 0.9
        voiceVolume = 1.0
        ambientVolume = 0.3
        
        accessibilityMode = true
        userPreferences.voiceNarrationEnabled = true
        userPreferences.audioDescriptionsEnabled = true
        userPreferences.soundReplacementEnabled = true
    }
    
    // MARK: - Hardware Detection
    
    private func isHeadphonesConnected() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        for output in audioSession.currentRoute.outputs {
            if output.portType == .headphones || output.portType == .bluetoothA2DP {
                return true
            }
        }
        return false
    }
    
    private func hasExternalSpeakers() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        for output in audioSession.currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .airPlay {
                return true
            }
        }
        return false
    }
    
    // MARK: - Metrics
    
    private func getTotalActiveAudioSources() -> Int {
        let spatialSources = spatialAudioEngine.activeSources
        let shipSources = shipAudioSystem.activeShipSounds
        let environmentalSources = environmentalAudio.activeAudioSources
        
        return spatialSources + shipSources + environmentalSources
    }
    
    private func getTotalMemoryUsage() -> Float {
        let spatialMemory = spatialAudioEngine.getPerformanceMetrics().memoryUsage
        let shipMemory = shipAudioSystem.getShipAudioMetrics().memoryUsage
        
        return spatialMemory + shipMemory
    }
    
    private func getAudioCPUUsage() -> Float {
        // Would measure actual CPU usage in real implementation
        return 0.15 // 15% placeholder
    }
    
    private func getAudioLatency() -> Float {
        // Would measure actual audio latency in real implementation
        return 0.02 // 20ms placeholder
    }
    
    // MARK: - Event Handlers
    
    private func handleAudioRouteChange() {
        detectAudioHardware()
        applyAudioDeviceSettings()
        
        print("Audio route changed, reapplying device settings")
    }
}

// MARK: - Supporting Types

public enum AudioQualityLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium" 
    case high = "High"
    case ultra = "Ultra"
}

public enum AudioProfile: String, CaseIterable, Codable {
    case balanced = "Balanced"
    case cinematic = "Cinematic"
    case competitive = "Competitive"
    case casual = "Casual"
    case accessibility = "Accessibility"
    case custom = "Custom"
}

public enum AudioCategory {
    case master
    case music
    case effects
    case voice
    case ambient
}

public enum AudioFeature {
    case haptics
    case spatialAudio
    case accessibility
    case environmentalAudio
    case dynamicMusic
    case voiceNarration
    case shipAudio
}

public struct UserAudioPreferences: Codable {
    public var environmentalAudioEnabled: Bool = true
    public var dynamicMusicEnabled: Bool = true
    public var voiceNarrationEnabled: Bool = true
    public var shipAudioEnabled: Bool = true
    public var audioDescriptionsEnabled: Bool = false
    public var soundReplacementEnabled: Bool = false
    public var competitiveAudioMode: Bool = false
    public var relaxedAudioMode: Bool = false
    public var importantSoundsOnly: Bool = false
    public var immersiveExperienceLevel: ImmersionLevel = .moderate
    
    public init() {}
}

public enum ImmersionLevel: String, CaseIterable, Codable {
    case minimal = "Minimal"
    case moderate = "Moderate"
    case high = "High"
    case maximum = "Maximum"
}

public struct EqualizerSettings: Codable {
    public var enabled: Bool = false
    public var preampGain: Float = 0.0
    public var band32Hz: Float = 0.0
    public var band64Hz: Float = 0.0
    public var band125Hz: Float = 0.0
    public var band250Hz: Float = 0.0
    public var band500Hz: Float = 0.0
    public var band1kHz: Float = 0.0
    public var band2kHz: Float = 0.0
    public var band4kHz: Float = 0.0
    public var band8kHz: Float = 0.0
    public var band16kHz: Float = 0.0
    
    public init() {}
    
    public var allBands: [Float] {
        return [band32Hz, band64Hz, band125Hz, band250Hz, band500Hz, 
                band1kHz, band2kHz, band4kHz, band8kHz, band16kHz]
    }
}

public struct AudioDeviceSettings: Codable {
    public var hasHeadphones: Bool = false
    public var hasExternalSpeakers: Bool = false
    public var supportsSpatialAudio: Bool = false
    public var supportsHaptics: Bool = false
    public var deviceType: AudioDeviceType = .builtin
    public var sampleRate: Double = 44100.0
    public var bufferSize: Int = 512
    
    public init() {}
}

public enum AudioDeviceType: String, CaseIterable, Codable {
    case builtin = "Built-in"
    case headphones = "Headphones"
    case bluetooth = "Bluetooth"
    case airplay = "AirPlay"
    case external = "External"
}

public struct VolumeSettings: Codable {
    public let master: Float
    public let music: Float
    public let effects: Float
    public let voice: Float
    public let ambient: Float
    
    public init(master: Float, music: Float, effects: Float, voice: Float, ambient: Float) {
        self.master = master
        self.music = music
        self.effects = effects
        self.voice = voice
        self.ambient = ambient
    }
}

public struct FeatureSettings: Codable {
    public let hapticsEnabled: Bool
    public let spatialAudioEnabled: Bool
    public let accessibilityMode: Bool
    
    public init(hapticsEnabled: Bool, spatialAudioEnabled: Bool, accessibilityMode: Bool) {
        self.hapticsEnabled = hapticsEnabled
        self.spatialAudioEnabled = spatialAudioEnabled
        self.accessibilityMode = accessibilityMode
    }
}

public struct AudioSettings: Codable {
    public let volumes: VolumeSettings
    public let features: FeatureSettings
    public let quality: AudioQualityLevel
    public let profile: AudioProfile
    public let userPreferences: UserAudioPreferences
    public let customEQ: EqualizerSettings
    public let deviceSettings: AudioDeviceSettings
    
    public init(volumes: VolumeSettings, features: FeatureSettings, quality: AudioQualityLevel, 
                profile: AudioProfile, userPreferences: UserAudioPreferences, 
                customEQ: EqualizerSettings, deviceSettings: AudioDeviceSettings) {
        self.volumes = volumes
        self.features = features
        self.quality = quality
        self.profile = profile
        self.userPreferences = userPreferences
        self.customEQ = customEQ
        self.deviceSettings = deviceSettings
    }
}

public struct AudioSystemMetrics {
    public let masterVolume: Float
    public let activeAudioSources: Int
    public let memoryUsage: Float // MB
    public let cpuUsage: Float // Percentage
    public let latency: Float // Seconds
    public let spatialAudioActive: Bool
    public let hapticsActive: Bool
    
    public init(masterVolume: Float, activeAudioSources: Int, memoryUsage: Float, 
                cpuUsage: Float, latency: Float, spatialAudioActive: Bool, hapticsActive: Bool) {
        self.masterVolume = masterVolume
        self.activeAudioSources = activeAudioSources
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.latency = latency
        self.spatialAudioActive = spatialAudioActive
        self.hapticsActive = hapticsActive
    }
}