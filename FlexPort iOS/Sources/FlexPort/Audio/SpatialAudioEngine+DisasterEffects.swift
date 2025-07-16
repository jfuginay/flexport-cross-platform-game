import Foundation
import AVFoundation
import simd
import AudioToolbox
import Combine

// MARK: - Disaster Audio Effects Extension

extension SpatialAudioEngine {
    
    // MARK: - Disaster Audio System
    
    /// Play disaster-specific audio effects with environmental impact
    public func playDisasterEffect(
        _ disasterType: DisasterEffectComponent.DisasterType,
        at position: simd_float3,
        intensity: Float,
        radius: Float,
        duration: TimeInterval
    ) -> UUID? {
        let id = UUID()
        let disasterSource = DisasterAudioSource(
            id: id,
            type: disasterType,
            position: position,
            intensity: intensity,
            radius: radius,
            duration: duration
        )
        
        // Store disaster source for tracking
        DisasterAudioManager.shared.addDisasterSource(disasterSource)
        
        // Play primary disaster sound
        let primarySoundName = getDisasterSoundName(for: disasterType)
        if let soundId = playSound(primarySoundName, at: position, volume: intensity) {
            disasterSource.primarySoundId = soundId
        }
        
        // Add environmental effects
        addDisasterEnvironmentalEffects(for: disasterSource)
        
        // Apply environmental audio changes
        applyDisasterEnvironmentalChanges(for: disasterType, intensity: intensity)
        
        // Schedule cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.removeDisasterEffect(id)
        }
        
        print("Started disaster audio effect: \(disasterType) at intensity \(intensity)")
        
        return id
    }
    
    /// Update disaster effect intensity and position
    public func updateDisasterEffect(_ id: UUID, position: simd_float3?, intensity: Float?) {
        guard let disaster = DisasterAudioManager.shared.getDisasterSource(id) else { return }
        
        if let newPosition = position {
            disaster.position = newPosition
            if let soundId = disaster.primarySoundId {
                update3DPosition(for: soundId, position: newPosition)
            }
            
            // Update secondary effects positions
            for (index, effectId) in disaster.secondaryEffects.enumerated() {
                let offset = getSecondaryEffectOffset(for: disaster.type, index: index)
                update3DPosition(for: effectId, position: newPosition + offset)
            }
        }
        
        if let newIntensity = intensity {
            disaster.intensity = newIntensity
            updateDisasterIntensity(for: disaster)
        }
    }
    
    private func removeDisasterEffect(_ id: UUID) {
        guard let disaster = DisasterAudioManager.shared.removeDisasterSource(id) else { return }
        
        // Stop primary sound
        if let soundId = disaster.primarySoundId {
            stopAudioSource(id: soundId, fadeOutDuration: 2.0)
        }
        
        // Stop secondary effects
        for effectId in disaster.secondaryEffects {
            stopAudioSource(id: effectId, fadeOutDuration: 1.0)
        }
        
        print("Removed disaster audio effect: \(disaster.type)")
    }
    
    // MARK: - Weather and Environmental Audio
    
    /// Update weather conditions and adjust audio accordingly
    public func updateWeatherConditions(
        _ weatherType: WeatherType,
        intensity: Float,
        windDirection: simd_float2,
        windSpeed: Float
    ) {
        let weatherManager = WeatherAudioManager.shared
        
        // Update weather audio
        weatherManager.updateWeather(
            type: weatherType,
            intensity: intensity,
            windDirection: windDirection,
            windSpeed: windSpeed,
            audioEngine: self
        )
        
        // Update ocean ambience based on weather
        updateOceanAmbience(weatherType: weatherType, intensity: intensity)
        
        // Update reverb based on weather conditions
        updateEnvironmentalReverb(for: weatherType, intensity: intensity)
        
        print("Updated weather audio: \(weatherType) intensity: \(intensity)")
    }
    
    /// Play port-specific audio with activity level
    public func playPortAudio(at position: simd_float3, activityLevel: Float, portType: String) {
        let portManager = PortAudioManager.shared
        portManager.playPortAudio(
            at: position,
            activityLevel: activityLevel,
            portType: portType,
            audioEngine: self
        )
    }
    
    /// Play ship-specific audio with dynamic parameters
    public func playShipAudio(
        shipId: UUID,
        position: simd_float3,
        velocity: simd_float3,
        enginePower: Float,
        shipType: String,
        isPlayerShip: Bool = false
    ) {
        let shipManager = ShipAudioManager.shared
        shipManager.playShipAudio(
            shipId: shipId,
            position: position,
            velocity: velocity,
            enginePower: enginePower,
            shipType: shipType,
            isPlayerShip: isPlayerShip,
            audioEngine: self
        )
    }
    
    // MARK: - Emergency and Alert Audio
    
    /// Play emergency alert with haptic feedback coordination
    public func playEmergencyAlert(
        _ alertType: EmergencyAlertType,
        at position: simd_float3,
        severity: Float = 1.0
    ) {
        let emergencyManager = EmergencyAudioManager.shared
        emergencyManager.playAlert(
            alertType,
            at: position,
            severity: severity,
            audioEngine: self
        )
    }
    
    /// Play voice announcement with priority queuing
    public func playVoiceAnnouncement(_ message: String, priority: VoicePriority = .normal) {
        let emergencyManager = EmergencyAudioManager.shared
        emergencyManager.queueVoiceMessage(message, priority: priority)
    }
    
    // MARK: - Dynamic Music Integration
    
    /// Update music tension based on game events
    public func updateMusicTension(_ tension: Float) {
        let musicManager = DynamicMusicManager.shared
        musicManager.updateTension(tension)
    }
    
    /// Trigger musical stinger for dramatic moments
    public func playMusicStinger(_ stingerType: MusicStingerType) {
        let musicManager = DynamicMusicManager.shared
        musicManager.playStinger(stingerType, audioEngine: self)
    }
    
    // MARK: - Private Implementation
    
    private func addDisasterEnvironmentalEffects(for disaster: DisasterAudioSource) {
        switch disaster.type {
        case .hurricane:
            addHurricaneEffects(for: disaster)
        case .tsunami:
            addTsunamiEffects(for: disaster)
        case .earthquake:
            addEarthquakeEffects(for: disaster)
        case .fire:
            addFireEffects(for: disaster)
        case .storm:
            addStormEffects(for: disaster)
        case .fog:
            addFogEffects(for: disaster)
        case .piracy:
            addPiracyEffects(for: disaster)
        case .cyberAttack:
            addCyberAttackEffects(for: disaster)
        case .flooding:
            addFloodingEffects(for: disaster)
        }
    }
    
    private func addHurricaneEffects(for disaster: DisasterAudioSource) {
        // Multiple wind layers at different positions
        let windPositions = [
            disaster.position + simd_float3(20, 0, 0),
            disaster.position + simd_float3(-15, 0, 10),
            disaster.position + simd_float3(0, 5, -20)
        ]
        
        for (index, position) in windPositions.enumerated() {
            let volume = disaster.intensity * (0.8 - Float(index) * 0.1)
            let pitch = 1.0 + Float(index) * 0.2
            
            if let windId = playSound(\"hurricane_wind_layer\", at: position, volume: volume) {
                if let playerNode = playerNodes[windId] {
                    playerNode.rate = pitch
                }
                disaster.secondaryEffects.append(windId)
            }
        }
        
        // Add debris sounds
        if disaster.intensity > 0.7 {
            let debrisId = playSound(\"debris_impacts\", at: disaster.position, volume: disaster.intensity * 0.6)
            if let id = debrisId { disaster.secondaryEffects.append(id) }
        }
    }
    
    private func addTsunamiEffects(for disaster: DisasterAudioSource) {
        // Water rush from multiple directions
        let wavePositions = [
            disaster.position + simd_float3(0, 0, 50),  // Approaching wave
            disaster.position + simd_float3(-30, 0, 20), // Side wave
            disaster.position + simd_float3(30, 0, 20)   // Other side
        ]
        
        for position in wavePositions {
            if let waveId = playSound(\"tsunami_water_rush\", at: position, volume: disaster.intensity * 0.9) {
                disaster.secondaryEffects.append(waveId)
            }
        }
        
        // Add structural stress sounds
        if disaster.intensity > 0.5 {
            let stressId = playSound(\"metal_stress\", at: disaster.position, volume: disaster.intensity * 0.5)
            if let id = stressId { disaster.secondaryEffects.append(id) }
        }
    }
    
    private func addEarthquakeEffects(for disaster: DisasterAudioSource) {
        // Ground rumbling at different frequencies
        let rumbleId1 = playSound(\"earthquake_rumble_low\", at: disaster.position, volume: disaster.intensity * 0.8)
        let rumbleId2 = playSound(\"earthquake_rumble_high\", at: disaster.position + simd_float3(10, 0, 0), volume: disaster.intensity * 0.6)
        
        if let id1 = rumbleId1 { disaster.secondaryEffects.append(id1) }
        if let id2 = rumbleId2 { disaster.secondaryEffects.append(id2) }
        
        // Add structural creaking
        if disaster.intensity > 0.6 {
            let creakId = playSound(\"structural_creaking\", at: disaster.position, volume: disaster.intensity * 0.4)
            if let id = creakId { disaster.secondaryEffects.append(id) }
        }
    }
    
    private func addFireEffects(for disaster: DisasterAudioSource) {
        // Fire crackling
        let crackleId = playSound(\"fire_crackling\", at: disaster.position, volume: disaster.intensity * 0.7)
        if let id = crackleId { disaster.secondaryEffects.append(id) }
        
        // Smoke and air movement
        let smokeId = playSound(\"fire_smoke_rush\", at: disaster.position + simd_float3(0, 5, 0), volume: disaster.intensity * 0.5)
        if let id = smokeId { disaster.secondaryEffects.append(id) }
        
        // Explosions for intense fires
        if disaster.intensity > 0.8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...8)) {
                _ = self.playSound(\"fire_explosion\", at: disaster.position, volume: disaster.intensity * 0.9)
            }
        }
    }
    
    private func addStormEffects(for disaster: DisasterAudioSource) {
        // Thunder at random intervals
        let thunderDelay = Double.random(in: 1...5)
        DispatchQueue.main.asyncAfter(deadline: .now() + thunderDelay) {
            _ = self.playSound(\"thunder_crack\", at: disaster.position, volume: disaster.intensity * 0.8)
        }
        
        // Rain sounds
        let rainId = playSound(\"heavy_rain\", at: disaster.position, volume: disaster.intensity * 0.6)
        if let id = rainId { disaster.secondaryEffects.append(id) }
        
        // Wind gusts
        let windId = playSound(\"storm_wind\", at: disaster.position, volume: disaster.intensity * 0.7)
        if let id = windId { disaster.secondaryEffects.append(id) }
    }
    
    private func addFogEffects(for disaster: DisasterAudioSource) {
        // Fog horn sounds
        let hornId = playSound(\"fog_horn_distant\", at: disaster.position, volume: disaster.intensity * 0.5)
        if let id = hornId { disaster.secondaryEffects.append(id) }
        
        // Muffled ambient sounds
        // This would require filtering existing ambient sounds
    }
    
    private func addPiracyEffects(for disaster: DisasterAudioSource) {
        // Engine sounds of approaching vessels
        let engineId = playSound(\"speedboat_engine\", at: disaster.position, volume: disaster.intensity * 0.7)
        if let id = engineId { disaster.secondaryEffects.append(id) }
        
        // Radio chatter
        let radioId = playSound(\"hostile_radio_chatter\", at: disaster.position, volume: disaster.intensity * 0.4)
        if let id = radioId { disaster.secondaryEffects.append(id) }
    }
    
    private func addCyberAttackEffects(for disaster: DisasterAudioSource) {
        // Electronic interference
        let staticId = playSound(\"electronic_static\", at: disaster.position, volume: disaster.intensity * 0.6)
        if let id = staticId { disaster.secondaryEffects.append(id) }
        
        // System failure sounds
        let failureId = playSound(\"system_shutdown\", at: disaster.position, volume: disaster.intensity * 0.5)
        if let id = failureId { disaster.secondaryEffects.append(id) }
    }
    
    private func addFloodingEffects(for disaster: DisasterAudioSource) {
        // Water rushing into compartments
        let rushId = playSound(\"water_flooding\", at: disaster.position, volume: disaster.intensity * 0.8)
        if let id = rushId { disaster.secondaryEffects.append(id) }
        
        // Emergency pump activation
        if disaster.intensity > 0.5 {
            let pumpId = playSound(\"emergency_pumps\", at: disaster.position, volume: disaster.intensity * 0.6)
            if let id = pumpId { disaster.secondaryEffects.append(id) }
        }
    }
    
    private func applyDisasterEnvironmentalChanges(for disasterType: DisasterEffectComponent.DisasterType, intensity: Float) {
        switch disasterType {
        case .hurricane, .storm:
            // Increase reverb to simulate enclosed feeling during storm
            reverbNode.wetDryMix = min(80.0, reverbNode.wetDryMix + intensity * 20.0)
            
        case .fog:
            // Reduce overall audio clarity
            setMasterVolume(audioEngine.mainMixerNode.outputVolume * (1.0 - intensity * 0.3))
            
        case .underwater, .flooding:
            // Apply underwater effect
            applyUnderwaterEffect(enabled: true, intensity: intensity)
            
        default:
            break
        }
    }
    
    private func updateDisasterIntensity(for disaster: DisasterAudioSource) {
        // Update volume of all disaster-related sounds
        if let primaryId = disaster.primarySoundId,
           let playerNode = playerNodes[primaryId] {
            playerNode.volume = disaster.intensity
        }
        
        for effectId in disaster.secondaryEffects {
            if let playerNode = playerNodes[effectId] {
                playerNode.volume = disaster.intensity * 0.7
            }
        }
    }
    
    private func updateOceanAmbience(weatherType: WeatherType, intensity: Float) {
        // This would update existing ocean ambient sound based on weather
        // Implementation depends on how ocean ambience is managed
    }
    
    private func updateEnvironmentalReverb(for weatherType: WeatherType, intensity: Float) {
        let targetWetMix: Float
        
        switch weatherType {
        case .storm, .hurricane:
            targetWetMix = 40.0 + intensity * 30.0
        case .fog:
            targetWetMix = 50.0 + intensity * 20.0
        case .calm:
            targetWetMix = 15.0
        default:
            targetWetMix = 25.0 + intensity * 10.0
        }
        
        // Gradually adjust reverb
        let currentMix = reverbNode.wetDryMix
        let adjustment = (targetWetMix - currentMix) * 0.1
        reverbNode.wetDryMix = currentMix + adjustment
    }
    
    private func applyUnderwaterEffect(enabled: Bool, intensity: Float = 1.0) {
        if enabled {
            // Apply low-pass filter for underwater effect
            let cutoffFrequency = 2000.0 * (1.0 - intensity * 0.7) // Reduce high frequencies
            
            // This would require additional audio unit setup
            // For now, just adjust EQ
            let highFreqBand = masterEQNode.bands[8] // High frequency band
            highFreqBand.gain = -12.0 * intensity
        } else {
            // Restore normal audio
            let highFreqBand = masterEQNode.bands[8]
            highFreqBand.gain = 0.0
        }
    }
    
    private func getSecondaryEffectOffset(for disasterType: DisasterEffectComponent.DisasterType, index: Int) -> simd_float3 {
        switch disasterType {
        case .hurricane:
            let angle = Float(index) * 120.0 * .pi / 180.0 // 120 degrees apart
            return simd_float3(cos(angle) * 20.0, 0, sin(angle) * 20.0)
        case .tsunami:
            return simd_float3(Float(index - 1) * 30.0, 0, 20.0)
        default:
            return simd_float3(Float(index) * 10.0, 0, 0)
        }
    }
    
    private func getDisasterSoundName(for disasterType: DisasterEffectComponent.DisasterType) -> String {
        switch disasterType {
        case .hurricane: return \"hurricane_wind_main\"
        case .tsunami: return \"tsunami_wave_main\"
        case .earthquake: return \"earthquake_rumble_main\"
        case .storm: return \"storm_thunder_main\"
        case .fire: return \"fire_main\"
        case .piracy: return \"alarm_security\"
        case .cyberAttack: return \"alarm_technical\"
        case .flooding: return \"flooding_main\"
        case .fog: return \"fog_ambient\"
        }
    }
}

// MARK: - Supporting Classes

public class DisasterAudioSource {
    let id: UUID
    let type: DisasterEffectComponent.DisasterType
    var position: simd_float3
    var intensity: Float
    let radius: Float
    let duration: TimeInterval
    var primarySoundId: UUID?
    var secondaryEffects: [UUID] = []
    
    init(id: UUID, type: DisasterEffectComponent.DisasterType, position: simd_float3, intensity: Float, radius: Float, duration: TimeInterval) {
        self.id = id
        self.type = type
        self.position = position
        self.intensity = intensity
        self.radius = radius
        self.duration = duration
    }
}

// MARK: - Audio Manager Classes

class DisasterAudioManager {
    static let shared = DisasterAudioManager()
    
    private var disasterSources: [UUID: DisasterAudioSource] = [:]
    private let queue = DispatchQueue(label: \"com.flexport.disaster.audio\", qos: .userInteractive)
    
    private init() {}
    
    func addDisasterSource(_ source: DisasterAudioSource) {
        queue.async {
            self.disasterSources[source.id] = source
        }
    }
    
    func getDisasterSource(_ id: UUID) -> DisasterAudioSource? {
        return queue.sync {
            return disasterSources[id]
        }
    }
    
    func removeDisasterSource(_ id: UUID) -> DisasterAudioSource? {
        return queue.sync {
            return disasterSources.removeValue(forKey: id)
        }
    }
}

class WeatherAudioManager {
    static let shared = WeatherAudioManager()
    
    private var currentWeather: WeatherType = .calm
    private var weatherSoundId: UUID?
    
    private init() {}
    
    func updateWeather(
        type: WeatherType,
        intensity: Float,
        windDirection: simd_float2,
        windSpeed: Float,
        audioEngine: SpatialAudioEngine
    ) {
        // Stop current weather sound
        if let currentId = weatherSoundId {
            audioEngine.stopAudioSource(id: currentId, fadeOutDuration: 2.0)
        }
        
        // Start new weather sound
        let weatherSoundName = getWeatherSoundName(for: type)
        weatherSoundId = audioEngine.playAmbientSound(
            weatherSoundName,
            at: audioEngine.listenerPosition,
            volume: intensity * 0.6
        )
        
        currentWeather = type
    }
    
    private func getWeatherSoundName(for weatherType: WeatherType) -> String {
        switch weatherType {
        case .storm: return \"storm_ambient\"
        case .hurricane: return \"hurricane_ambient\"
        case .fog: return \"fog_ambient\"
        case .rain: return \"rain_ambient\"
        case .snow: return \"snow_ambient\"
        default: return \"wind_light\"
        }
    }
}

class PortAudioManager {
    static let shared = PortAudioManager()
    
    private init() {}
    
    func playPortAudio(
        at position: simd_float3,
        activityLevel: Float,
        portType: String,
        audioEngine: SpatialAudioEngine
    ) {
        let craneVolume = activityLevel * 0.7
        let machineryVolume = activityLevel * 0.5
        let humanVolume = activityLevel * 0.3
        
        // Crane operations
        _ = audioEngine.playSound(\"crane_operations\", at: position, volume: craneVolume)
        
        // Port machinery
        _ = audioEngine.playAmbientSound(
            \"port_machinery\",
            at: position + simd_float3(10, 0, 0),
            volume: machineryVolume
        )
        
        // Human activity
        _ = audioEngine.playSound(
            \"port_chatter\",
            at: position + simd_float3(-5, 0, 5),
            volume: humanVolume
        )
        
        // Seagulls for coastal ports
        if portType.contains(\"coastal\") && Float.random(in: 0...1) < activityLevel * 0.4 {
            let seagullPosition = position + simd_float3(
                Float.random(in: -20...20),
                Float.random(in: 5...15),
                Float.random(in: -20...20)
            )
            _ = audioEngine.playSound(\"seagulls\", at: seagullPosition, volume: 0.3)
        }
    }
}

class ShipAudioManager {
    static let shared = ShipAudioManager()
    
    private var shipEngineSounds: [UUID: UUID] = [:]
    
    private init() {}
    
    func playShipAudio(
        shipId: UUID,
        position: simd_float3,
        velocity: simd_float3,
        enginePower: Float,
        shipType: String,
        isPlayerShip: Bool,
        audioEngine: SpatialAudioEngine
    ) {
        let speed = length(velocity)
        let baseVolume: Float = isPlayerShip ? 0.8 : 0.5
        let engineVolume = baseVolume * (0.3 + enginePower * 0.7)
        let enginePitch = 0.8 + speed * 0.3 + enginePower * 0.2
        
        // Stop existing engine sound
        if let existingEngineId = shipEngineSounds[shipId] {
            audioEngine.stopAudioSource(id: existingEngineId)
        }
        
        // Start new engine sound
        let engineSoundName = getShipEngineSoundName(for: shipType)
        if let engineId = audioEngine.playAmbientSound(engineSoundName, at: position, volume: engineVolume) {
            shipEngineSounds[shipId] = engineId
            
            if let playerNode = audioEngine.playerNodes[engineId] {
                playerNode.rate = enginePitch
            }
        }
        
        // Water displacement (bow wave)
        if speed > 0.5 {
            let waveVolume = min(speed * 0.2, 0.6)
            _ = audioEngine.playSound(
                \"bow_wave\",
                at: position + simd_float3(0, -2, 5),
                volume: waveVolume
            )
        }
        
        // Horn/whistle for large ships
        if shipType.contains(\"container\") || shipType.contains(\"tanker\") {
            if Float.random(in: 0...1) < 0.001 { // Rare horn blast
                _ = audioEngine.playSound(\"ship_horn\", at: position, volume: 0.8)
            }
        }
    }
    
    private func getShipEngineSoundName(for shipType: String) -> String {
        switch shipType.lowercased() {
        case let type where type.contains(\"container\"):
            return \"engine_container\"
        case let type where type.contains(\"tanker\"):
            return \"engine_tanker\"
        case let type where type.contains(\"bulk\"):
            return \"engine_bulk\"
        default:
            return \"engine_diesel\"
        }
    }
}

class EmergencyAudioManager {
    static let shared = EmergencyAudioManager()
    
    private var voiceQueue: [VoiceMessage] = []
    private var currentVoiceMessage: VoiceMessage?
    
    private init() {}
    
    struct VoiceMessage {
        let message: String
        let priority: VoicePriority
        let timestamp: Date
    }
    
    func playAlert(
        _ alertType: EmergencyAlertType,
        at position: simd_float3,
        severity: Float,
        audioEngine: SpatialAudioEngine
    ) {
        let alertSound = getAlertSoundName(for: alertType)
        _ = audioEngine.playSound(alertSound, at: position, volume: severity)
        
        // Queue voice announcement
        let message = getVoiceMessage(for: alertType)
        queueVoiceMessage(message, priority: .emergency)
    }
    
    func queueVoiceMessage(_ message: String, priority: VoicePriority) {
        let voiceMessage = VoiceMessage(message: message, priority: priority, timestamp: Date())
        
        if priority == .emergency {
            voiceQueue.insert(voiceMessage, at: 0)
        } else {
            voiceQueue.append(voiceMessage)
        }
        
        processVoiceQueue()
    }
    
    private func processVoiceQueue() {
        guard currentVoiceMessage == nil, !voiceQueue.isEmpty else { return }
        
        currentVoiceMessage = voiceQueue.removeFirst()
        // Implement text-to-speech here
        
        // Simulate voice completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.currentVoiceMessage = nil
            self.processVoiceQueue()
        }
    }
    
    private func getAlertSoundName(for alertType: EmergencyAlertType) -> String {
        switch alertType {
        case .collision: return \"alarm_collision\"
        case .fire: return \"alarm_fire\"
        case .flooding: return \"alarm_general\"
        case .piracy: return \"alarm_security\"
        case .systemFailure: return \"alarm_technical\"
        case .abandon: return \"alarm_abandon\"
        case .generalAlarm: return \"alarm_general\"
        }
    }
    
    private func getVoiceMessage(for alertType: EmergencyAlertType) -> String {
        switch alertType {
        case .collision: return \"Collision alert. All stop. Assess damage.\"
        case .fire: return \"Fire alarm. Emergency stations. Activate suppression systems.\"
        case .flooding: return \"Flooding detected. Seal compartments.\"
        case .piracy: return \"Security alert. Potential piracy threat.\"
        case .systemFailure: return \"System failure detected. Switch to manual control.\"
        case .abandon: return \"Abandon ship. All hands to lifeboats.\"
        case .generalAlarm: return \"General alarm. All hands to emergency stations.\"
        }
    }
}

class DynamicMusicManager {
    static let shared = DynamicMusicManager()
    
    private var currentTension: Float = 0.0
    private var targetTension: Float = 0.0
    
    private init() {}
    
    func updateTension(_ tension: Float) {
        targetTension = max(0.0, min(1.0, tension))
        
        // Gradually adjust current tension
        let adjustment = (targetTension - currentTension) * 0.1
        currentTension += adjustment
        
        adjustMusicLayers()
    }
    
    func playStinger(_ stingerType: MusicStingerType, audioEngine: SpatialAudioEngine) {
        let stingerName = getStingerName(for: stingerType)
        _ = audioEngine.playSound(stingerName, at: audioEngine.listenerPosition, volume: 0.7)
    }
    
    private func adjustMusicLayers() {
        // Implement dynamic music layer mixing based on tension
        // This would control volume of different musical elements
    }
    
    private func getStingerName(for stingerType: MusicStingerType) -> String {
        switch stingerType {
        case .success: return \"stinger_success\"
        case .failure: return \"stinger_failure\"
        case .danger: return \"stinger_danger\"
        case .discovery: return \"stinger_discovery\"
        case .achievement: return \"stinger_achievement\"
        }
    }
}

// MARK: - Supporting Enums and Types

public enum WeatherType {
    case calm
    case rain
    case storm
    case hurricane
    case fog
    case snow
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

public enum VoicePriority {
    case low
    case normal
    case high
    case emergency
}

public enum MusicStingerType {
    case success
    case failure
    case danger
    case discovery
    case achievement
}