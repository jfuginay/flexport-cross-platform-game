import Foundation
import AVFoundation
import simd
import Combine

/// Advanced ship audio effects system with realistic maritime sound generation
public class ShipAudioEffectsSystem: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ShipAudioEffectsSystem()
    
    // MARK: - Published Properties
    @Published public private(set) var activeShipSounds: Int = 0
    @Published public private(set) var engineSoundsEnabled: Bool = true
    @Published public private(set) var ambientShipSoundsEnabled: Bool = true
    @Published public private(set) var masterShipVolume: Float = 0.7
    
    // MARK: - Audio Engine Components
    private let spatialAudio = SpatialAudioEngine.shared
    private var shipAudioSources: [UUID: ShipAudioSource] = [:]
    private var engineGenerators: [UUID: EngineAudioGenerator] = [:]
    
    // MARK: - Ship Audio Tracking
    private var shipStates: [UUID: ShipAudioState] = [:]
    private var shipEngineProfiles: [ShipClass: EngineProfile] = [:]
    
    // MARK: - Configuration
    public struct Configuration {
        public var enableRealisticEngines: Bool = true
        public var enableDopplerEffect: Bool = true
        public var enableEnvironmentalMuffling: Bool = true
        public var maxConcurrentShipSounds: Int = 16
        public var engineAudioQuality: AudioQuality = .high
        public var distanceAttenuation: Float = 1.0
        public var underwaterMuffling: Float = 0.3
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - Audio Processing
    private var audioProcessingQueue = DispatchQueue(label: "com.flexport.ship-audio", qos: .userInteractive)
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupEngineProfiles()
        setupShipAudioLibrary()
        startAudioUpdateLoop()
    }
    
    // MARK: - Public Interface
    
    /// Create audio source for a ship
    public func createShipAudioSource(shipId: UUID, shipClass: ShipClass, position: simd_float3) -> Bool {
        guard shipAudioSources.count < configuration.maxConcurrentShipSounds else {
            print("Maximum concurrent ship sounds reached")
            return false
        }
        
        let audioSource = ShipAudioSource(
            shipId: shipId,
            shipClass: shipClass,
            position: position,
            isActive: false
        )
        
        let audioState = ShipAudioState(
            shipId: shipId,
            engineRunning: false,
            speed: 0.0,
            throttle: 0.0,
            seaState: .calm,
            underwaterDepth: 0.0
        )
        
        shipAudioSources[shipId] = audioSource
        shipStates[shipId] = audioState
        activeShipSounds = shipAudioSources.count
        
        print("Created ship audio source for ship \(shipId)")
        return true
    }
    
    /// Update ship engine state and audio
    public func updateShipEngine(shipId: UUID, running: Bool, throttle: Float, speed: Float) {
        guard var audioState = shipStates[shipId],
              let audioSource = shipAudioSources[shipId] else { return }
        
        let previousEngineState = audioState.engineRunning
        
        audioState.engineRunning = running
        audioState.throttle = max(0.0, min(1.0, throttle))
        audioState.speed = max(0.0, speed)
        
        shipStates[shipId] = audioState
        
        // Handle engine state changes
        if running && !previousEngineState {
            startEngineAudio(for: shipId)
        } else if !running && previousEngineState {
            stopEngineAudio(for: shipId)
        } else if running {
            updateEngineAudio(for: shipId)
        }
    }
    
    /// Update ship position and velocity for spatial audio
    public func updateShipPosition(shipId: UUID, position: simd_float3, velocity: simd_float3 = simd_float3(0, 0, 0)) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        audioSource.position = position
        audioSource.velocity = velocity
        
        // Update all spatial audio sources for this ship
        updateSpatialAudioPositions(for: shipId)
        
        // Update underwater effects if applicable
        if position.y < 0 {
            updateUnderwaterEffects(for: shipId, depth: abs(position.y))
        }
    }
    
    /// Update environmental conditions affecting ship audio
    public func updateEnvironmentalConditions(shipId: UUID, seaState: SeaState, weather: WeatherCondition = .clear, windSpeed: Float = 0.0) {
        guard var audioState = shipStates[shipId] else { return }
        
        audioState.seaState = seaState
        audioState.windSpeed = windSpeed
        audioState.weatherCondition = weather
        
        shipStates[shipId] = audioState
        
        updateEnvironmentalAudio(for: shipId)
    }
    
    /// Play ship horn sound
    public func playShipHorn(shipId: UUID, hornType: HornType = .standard, intensity: Float = 1.0) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        let hornSoundName = getHornSoundName(for: audioSource.shipClass, hornType: hornType)
        let hornPosition = audioSource.position + simd_float3(0, 5, 0) // Horn is above ship
        
        spatialAudio.playSound(hornSoundName, at: hornPosition, volume: intensity * masterShipVolume)
        
        print("Ship \(shipId) horn sounded: \(hornType)")
    }
    
    /// Play ship mechanical sounds (anchor, cargo, etc.)
    public func playShipMechanicalSound(shipId: UUID, soundType: MechanicalSoundType, intensity: Float = 1.0) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        let soundName = getMechanicalSoundName(for: soundType)
        
        // Position sound at appropriate location on ship
        let soundOffset = getMechanicalSoundOffset(for: soundType, shipClass: audioSource.shipClass)
        let soundPosition = audioSource.position + soundOffset
        
        spatialAudio.playSound(soundName, at: soundPosition, volume: intensity * masterShipVolume)
    }
    
    /// Remove ship audio source
    public func removeShipAudioSource(shipId: UUID) {
        stopAllShipAudio(for: shipId)
        
        shipAudioSources.removeValue(forKey: shipId)
        shipStates.removeValue(forKey: shipId)
        engineGenerators.removeValue(forKey: shipId)
        
        activeShipSounds = shipAudioSources.count
        
        print("Removed ship audio source for ship \(shipId)")
    }
    
    /// Set master volume for all ship sounds
    public func setMasterShipVolume(_ volume: Float) {
        masterShipVolume = max(0.0, min(1.0, volume))
        updateAllShipVolumes()
    }
    
    /// Enable/disable engine sounds
    public func setEngineSoundsEnabled(_ enabled: Bool) {
        engineSoundsEnabled = enabled
        
        if !enabled {
            stopAllEngineAudio()
        } else {
            restartActiveEngineAudio()
        }
    }
    
    /// Get ship audio metrics for performance monitoring
    public func getShipAudioMetrics() -> ShipAudioMetrics {
        return ShipAudioMetrics(
            activeShipSources: activeShipSounds,
            activeEngineGenerators: engineGenerators.count,
            totalAudioSources: shipAudioSources.values.reduce(0) { $0 + $1.activeSources.count },
            memoryUsage: calculateMemoryUsage()
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupEngineProfiles() {
        // Bulk Carrier - Large, slow, deep engine
        shipEngineProfiles[.bulkCarrier] = EngineProfile(
            baseFrequency: 45.0,
            cylinderCount: 8,
            displacement: 15000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 80, maxRPM: 120, peakTorqueRPM: 95),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 0.9,
                midRangeClarity: 0.6,
                highEndCrisp: 0.3,
                roughness: 0.7
            )
        )
        
        // Container Ship - Efficient, medium-pitched engine
        shipEngineProfiles[.containerShip] = EngineProfile(
            baseFrequency: 60.0,
            cylinderCount: 12,
            displacement: 18000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 90, maxRPM: 140, peakTorqueRPM: 115),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 0.8,
                midRangeClarity: 0.8,
                highEndCrisp: 0.4,
                roughness: 0.5
            )
        )
        
        // Tanker - Deep, powerful engine
        shipEngineProfiles[.tanker] = EngineProfile(
            baseFrequency: 40.0,
            cylinderCount: 10,
            displacement: 20000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 75, maxRPM: 110, peakTorqueRPM: 90),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 1.0,
                midRangeClarity: 0.5,
                highEndCrisp: 0.2,
                roughness: 0.8
            )
        )
        
        // General Cargo - Moderate engine
        shipEngineProfiles[.generalCargo] = EngineProfile(
            baseFrequency: 55.0,
            cylinderCount: 6,
            displacement: 8000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 100, maxRPM: 160, peakTorqueRPM: 130),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 0.7,
                midRangeClarity: 0.7,
                highEndCrisp: 0.5,
                roughness: 0.6
            )
        )
        
        // RoRo - Higher-pitched, faster engine
        shipEngineProfiles[.roro] = EngineProfile(
            baseFrequency: 70.0,
            cylinderCount: 8,
            displacement: 10000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 120, maxRPM: 180, peakTorqueRPM: 150),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 0.6,
                midRangeClarity: 0.8,
                highEndCrisp: 0.6,
                roughness: 0.4
            )
        )
        
        // Refrigerated Cargo - Quiet, efficient engine
        shipEngineProfiles[.refrigeratedCargo] = EngineProfile(
            baseFrequency: 65.0,
            cylinderCount: 6,
            displacement: 9000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 110, maxRPM: 170, peakTorqueRPM: 140),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 0.7,
                midRangeClarity: 0.9,
                highEndCrisp: 0.5,
                roughness: 0.3
            )
        )
        
        // Heavy Lift - Massive, powerful engine
        shipEngineProfiles[.heavyLift] = EngineProfile(
            baseFrequency: 35.0,
            cylinderCount: 16,
            displacement: 25000.0,
            engineType: .diesel,
            powerCurve: PowerCurve(minRPM: 60, maxRPM: 100, peakTorqueRPM: 80),
            soundCharacteristics: SoundCharacteristics(
                lowEndEmphasis: 1.2,
                midRangeClarity: 0.4,
                highEndCrisp: 0.2,
                roughness: 0.9
            )
        )
    }
    
    private func setupShipAudioLibrary() {
        // Load base engine sounds
        let engineSounds = [
            "engine_diesel_idle", "engine_diesel_low", "engine_diesel_medium", "engine_diesel_high",
            "engine_turbine_idle", "engine_turbine_low", "engine_turbine_medium", "engine_turbine_high"
        ]
        
        // Load horn sounds
        let hornSounds = [
            "ship_horn_standard", "ship_horn_deep", "ship_horn_high", "ship_horn_fog"
        ]
        
        // Load mechanical sounds
        let mechanicalSounds = [
            "anchor_winch", "cargo_crane", "deck_machinery", "ventilation_fans",
            "generator_hum", "pump_operation", "chain_rattle", "metal_stress"
        ]
        
        // Load ambient ship sounds
        let ambientSounds = [
            "ship_hull_creaking", "water_flow", "wind_through_rigging", "deck_footsteps"
        ]
        
        let allSounds = engineSounds + hornSounds + mechanicalSounds + ambientSounds
        
        for soundName in allSounds {
            spatialAudio.loadAudioFile(named: soundName)
        }
    }
    
    private func startAudioUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAllShipAudio()
        }
    }
    
    private func startEngineAudio(for shipId: UUID) {
        guard engineSoundsEnabled,
              let audioSource = shipAudioSources[shipId],
              let audioState = shipStates[shipId],
              let engineProfile = shipEngineProfiles[audioSource.shipClass] else { return }
        
        let generator = EngineAudioGenerator(
            shipId: shipId,
            engineProfile: engineProfile,
            position: audioSource.position
        )
        
        engineGenerators[shipId] = generator
        generator.start()
        
        audioSource.activeSources.insert(generator.engineSourceId)
        
        print("Started engine audio for ship \(shipId)")
    }
    
    private func stopEngineAudio(for shipId: UUID) {
        guard let generator = engineGenerators[shipId],
              let audioSource = shipAudioSources[shipId] else { return }
        
        generator.stop()
        audioSource.activeSources.remove(generator.engineSourceId)
        engineGenerators.removeValue(forKey: shipId)
        
        print("Stopped engine audio for ship \(shipId)")
    }
    
    private func updateEngineAudio(for shipId: UUID) {
        guard let generator = engineGenerators[shipId],
              let audioState = shipStates[shipId] else { return }
        
        generator.updateEngine(
            throttle: audioState.throttle,
            speed: audioState.speed,
            seaState: audioState.seaState
        )
    }
    
    private func updateSpatialAudioPositions(for shipId: UUID) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        // Update engine position
        if let generator = engineGenerators[shipId] {
            spatialAudio.update3DPosition(
                for: generator.engineSourceId,
                position: audioSource.position,
                velocity: audioSource.velocity
            )
        }
        
        // Update other ship audio sources
        for sourceId in audioSource.activeSources {
            spatialAudio.update3DPosition(
                for: sourceId,
                position: audioSource.position,
                velocity: audioSource.velocity
            )
        }
    }
    
    private func updateEnvironmentalAudio(for shipId: UUID) {
        guard let audioState = shipStates[shipId],
              let audioSource = shipAudioSources[shipId] else { return }
        
        // Update sea state effects
        updateSeaStateEffects(for: shipId, seaState: audioState.seaState)
        
        // Update weather effects
        updateWeatherEffects(for: shipId, weather: audioState.weatherCondition)
        
        // Update wind effects
        updateWindEffects(for: shipId, windSpeed: audioState.windSpeed)
    }
    
    private func updateSeaStateEffects(for shipId: UUID, seaState: SeaState) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        // Calculate hull stress sounds based on sea state
        let hullStressIntensity = getHullStressIntensity(for: seaState)
        
        if hullStressIntensity > 0.3 {
            let hullPosition = audioSource.position + simd_float3(0, -2, 0) // Below waterline
            
            if let existingId = audioSource.activeSources.first(where: { _ in true }) {
                // Update existing hull stress audio
                spatialAudio.audioSources[existingId]?.volume = hullStressIntensity
            } else {
                // Create new hull stress audio
                if let sourceId = spatialAudio.playAmbientSound("ship_hull_creaking", at: hullPosition, volume: hullStressIntensity) {
                    audioSource.activeSources.insert(sourceId)
                }
            }
        }
    }
    
    private func updateWeatherEffects(for shipId: UUID, weather: WeatherCondition) {
        // Weather effects would modify audio processing parameters
        // This could involve real-time filtering of ship audio
    }
    
    private func updateWindEffects(for shipId: UUID, windSpeed: Float) {
        guard let audioSource = shipAudioSources[shipId] else { return }
        
        if windSpeed > 10.0 { // Above 10 m/s
            let windPosition = audioSource.position + simd_float3(0, 10, 0) // Above ship
            let windIntensity = min(1.0, windSpeed / 30.0) // Max at 30 m/s
            
            if let sourceId = spatialAudio.playAmbientSound("wind_through_rigging", at: windPosition, volume: windIntensity * 0.3) {
                audioSource.activeSources.insert(sourceId)
            }
        }
    }
    
    private func updateUnderwaterEffects(for shipId: UUID, depth: Float) {
        guard var audioState = shipStates[shipId] else { return }
        
        audioState.underwaterDepth = depth
        shipStates[shipId] = audioState
        
        // Apply underwater muffling to all ship audio sources
        let mufflingFactor = min(1.0, depth / 10.0) * configuration.underwaterMuffling
        
        if let audioSource = shipAudioSources[shipId] {
            for sourceId in audioSource.activeSources {
                if let source = spatialAudio.audioSources[sourceId] {
                    source.volume *= (1.0 - mufflingFactor)
                }
            }
        }
    }
    
    private func updateAllShipAudio() {
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            for shipId in self.shipAudioSources.keys {
                self.updateEngineAudio(for: shipId)
                self.updateEnvironmentalAudio(for: shipId)
            }
        }
    }
    
    private func stopAllShipAudio(for shipId: UUID) {
        stopEngineAudio(for: shipId)
        
        if let audioSource = shipAudioSources[shipId] {
            for sourceId in audioSource.activeSources {
                spatialAudio.stopAudioSource(id: sourceId)
            }
            audioSource.activeSources.removeAll()
        }
    }
    
    private func stopAllEngineAudio() {
        for shipId in engineGenerators.keys {
            stopEngineAudio(for: shipId)
        }
    }
    
    private func restartActiveEngineAudio() {
        for (shipId, audioState) in shipStates {
            if audioState.engineRunning {
                startEngineAudio(for: shipId)
            }
        }
    }
    
    private func updateAllShipVolumes() {
        for audioSource in shipAudioSources.values {
            for sourceId in audioSource.activeSources {
                if let source = spatialAudio.audioSources[sourceId] {
                    source.volume *= masterShipVolume
                }
            }
        }
    }
    
    private func calculateMemoryUsage() -> Float {
        // Calculate memory usage of ship audio system
        let baseUsage = Float(shipAudioSources.count * 1024) // Rough estimate per ship
        let generatorUsage = Float(engineGenerators.count * 2048) // Rough estimate per generator
        
        return (baseUsage + generatorUsage) / (1024 * 1024) // Convert to MB
    }
    
    // MARK: - Utility Methods
    
    private func getHornSoundName(for shipClass: ShipClass, hornType: HornType) -> String {
        switch hornType {
        case .standard:
            return shipClass.isLargeVessel ? "ship_horn_deep" : "ship_horn_standard"
        case .fog:
            return "ship_horn_fog"
        case .emergency:
            return "ship_horn_emergency"
        }
    }
    
    private func getMechanicalSoundName(for soundType: MechanicalSoundType) -> String {
        switch soundType {
        case .anchorWindlass:
            return "anchor_winch"
        case .cargoCrane:
            return "cargo_crane"
        case .deckMachinery:
            return "deck_machinery"
        case .ventilationFans:
            return "ventilation_fans"
        case .generator:
            return "generator_hum"
        case .pumps:
            return "pump_operation"
        case .chainRattle:
            return "chain_rattle"
        case .hullStress:
            return "metal_stress"
        }
    }
    
    private func getMechanicalSoundOffset(for soundType: MechanicalSoundType, shipClass: ShipClass) -> simd_float3 {
        let shipLength = shipClass.approximateLength
        
        switch soundType {
        case .anchorWindlass:
            return simd_float3(shipLength * 0.4, 3, 0) // Forward, on deck
        case .cargoCrane:
            return simd_float3(0, 8, 0) // Midship, elevated
        case .deckMachinery:
            return simd_float3(0, 2, 0) // Midship, on deck
        case .ventilationFans:
            return simd_float3(0, 6, 0) // Midship, superstructure
        case .generator:
            return simd_float3(-shipLength * 0.3, -2, 0) // Aft, below deck
        case .pumps:
            return simd_float3(-shipLength * 0.2, -3, 0) // Aft, engine room
        case .chainRattle:
            return simd_float3(shipLength * 0.35, 1, 0) // Forward, chain locker
        case .hullStress:
            return simd_float3(0, -1, 0) // Midship, at waterline
        }
    }
    
    private func getHullStressIntensity(for seaState: SeaState) -> Float {
        switch seaState {
        case .calm:
            return 0.1
        case .slight:
            return 0.2
        case .moderate:
            return 0.4
        case .rough:
            return 0.7
        case .veryRough:
            return 0.9
        case .high:
            return 1.0
        }
    }
}

// MARK: - Engine Audio Generator

public class EngineAudioGenerator: ObservableObject {
    public let shipId: UUID
    public let engineProfile: EngineProfile
    public let engineSourceId: UUID = UUID()
    
    @Published public var isRunning: Bool = false
    @Published public var currentRPM: Float = 0.0
    @Published public var currentLoad: Float = 0.0
    
    private var position: simd_float3
    private var spatialAudio = SpatialAudioEngine.shared
    
    public init(shipId: UUID, engineProfile: EngineProfile, position: simd_float3) {
        self.shipId = shipId
        self.engineProfile = engineProfile
        self.position = position
    }
    
    public func start() {
        guard !isRunning else { return }
        
        let engineSoundName = getEngineSoundName()
        
        if spatialAudio.createAudioSource(
            id: engineSourceId,
            soundName: engineSoundName,
            position: position,
            looping: true
        ) {
            isRunning = true
            currentRPM = engineProfile.powerCurve.minRPM
            
            spatialAudio.playAudioSource(id: engineSourceId)
            
            print("Engine audio generator started for ship \(shipId)")
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        
        spatialAudio.stopAudioSource(id: engineSourceId, fadeOutDuration: 2.0)
        isRunning = false
        currentRPM = 0.0
        currentLoad = 0.0
        
        print("Engine audio generator stopped for ship \(shipId)")
    }
    
    public func updateEngine(throttle: Float, speed: Float, seaState: SeaState) {
        guard isRunning else { return }
        
        // Calculate RPM based on throttle
        let targetRPM = engineProfile.powerCurve.minRPM + 
                       (engineProfile.powerCurve.maxRPM - engineProfile.powerCurve.minRPM) * throttle
        
        // Smooth RPM changes
        currentRPM = currentRPM + (targetRPM - currentRPM) * 0.1
        
        // Calculate load based on speed and sea conditions
        let seaResistance = getSeaResistance(for: seaState)
        currentLoad = (speed / 30.0) * seaResistance // Normalize speed and apply resistance
        
        // Update audio parameters
        updateAudioParameters()
    }
    
    private func updateAudioParameters() {
        guard let audioSource = spatialAudio.audioSources[engineSourceId] else { return }
        
        // Calculate volume based on RPM and load
        let baseVolume = (currentRPM - engineProfile.powerCurve.minRPM) / 
                        (engineProfile.powerCurve.maxRPM - engineProfile.powerCurve.minRPM)
        let loadVolume = 0.5 + currentLoad * 0.5
        
        audioSource.volume = baseVolume * loadVolume * 0.8
        
        // Calculate pitch based on RPM
        let pitchFactor = 0.8 + (currentRPM / engineProfile.powerCurve.maxRPM) * 0.4
        audioSource.pitch = pitchFactor
    }
    
    private func getEngineSoundName() -> String {
        switch engineProfile.engineType {
        case .diesel:
            return "engine_diesel_medium"
        case .turbine:
            return "engine_turbine_medium"
        case .electric:
            return "engine_electric_medium"
        }
    }
    
    private func getSeaResistance(for seaState: SeaState) -> Float {
        switch seaState {
        case .calm: return 1.0
        case .slight: return 1.1
        case .moderate: return 1.3
        case .rough: return 1.6
        case .veryRough: return 2.0
        case .high: return 2.5
        }
    }
}

// MARK: - Supporting Types

public enum AudioQuality {
    case low
    case medium
    case high
    case ultra
}

public enum HornType {
    case standard
    case fog
    case emergency
}

public enum MechanicalSoundType {
    case anchorWindlass
    case cargoCrane
    case deckMachinery
    case ventilationFans
    case generator
    case pumps
    case chainRattle
    case hullStress
}

public enum SeaState {
    case calm
    case slight
    case moderate
    case rough
    case veryRough
    case high
}

public enum EngineType {
    case diesel
    case turbine
    case electric
}

public class ShipAudioSource: ObservableObject {
    public let shipId: UUID
    public let shipClass: ShipClass
    @Published public var position: simd_float3
    @Published public var velocity: simd_float3 = simd_float3(0, 0, 0)
    @Published public var isActive: Bool
    
    public var activeSources: Set<UUID> = []
    
    public init(shipId: UUID, shipClass: ShipClass, position: simd_float3, isActive: Bool) {
        self.shipId = shipId
        self.shipClass = shipClass
        self.position = position
        self.isActive = isActive
    }
}

public struct ShipAudioState {
    public let shipId: UUID
    public var engineRunning: Bool
    public var speed: Float
    public var throttle: Float
    public var seaState: SeaState
    public var underwaterDepth: Float
    public var windSpeed: Float = 0.0
    public var weatherCondition: WeatherCondition = .clear
    
    public init(shipId: UUID, engineRunning: Bool, speed: Float, throttle: Float, seaState: SeaState, underwaterDepth: Float) {
        self.shipId = shipId
        self.engineRunning = engineRunning
        self.speed = speed
        self.throttle = throttle
        self.seaState = seaState
        self.underwaterDepth = underwaterDepth
    }
}

public struct EngineProfile {
    public let baseFrequency: Float
    public let cylinderCount: Int
    public let displacement: Float // Liters
    public let engineType: EngineType
    public let powerCurve: PowerCurve
    public let soundCharacteristics: SoundCharacteristics
    
    public init(baseFrequency: Float, cylinderCount: Int, displacement: Float, engineType: EngineType, powerCurve: PowerCurve, soundCharacteristics: SoundCharacteristics) {
        self.baseFrequency = baseFrequency
        self.cylinderCount = cylinderCount
        self.displacement = displacement
        self.engineType = engineType
        self.powerCurve = powerCurve
        self.soundCharacteristics = soundCharacteristics
    }
}

public struct PowerCurve {
    public let minRPM: Float
    public let maxRPM: Float
    public let peakTorqueRPM: Float
    
    public init(minRPM: Float, maxRPM: Float, peakTorqueRPM: Float) {
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.peakTorqueRPM = peakTorqueRPM
    }
}

public struct SoundCharacteristics {
    public let lowEndEmphasis: Float // 0.0 to 1.0+
    public let midRangeClarity: Float // 0.0 to 1.0
    public let highEndCrisp: Float // 0.0 to 1.0
    public let roughness: Float // 0.0 to 1.0
    
    public init(lowEndEmphasis: Float, midRangeClarity: Float, highEndCrisp: Float, roughness: Float) {
        self.lowEndEmphasis = lowEndEmphasis
        self.midRangeClarity = midRangeClarity
        self.highEndCrisp = highEndCrisp
        self.roughness = roughness
    }
}

public struct ShipAudioMetrics {
    public let activeShipSources: Int
    public let activeEngineGenerators: Int
    public let totalAudioSources: Int
    public let memoryUsage: Float // MB
    
    public init(activeShipSources: Int, activeEngineGenerators: Int, totalAudioSources: Int, memoryUsage: Float) {
        self.activeShipSources = activeShipSources
        self.activeEngineGenerators = activeEngineGenerators
        self.totalAudioSources = totalAudioSources
        self.memoryUsage = memoryUsage
    }
}

// MARK: - Ship Class Extensions

extension ShipClass {
    public var isLargeVessel: Bool {
        switch self {
        case .bulkCarrier, .containerShip, .tanker, .heavyLift:
            return true
        case .generalCargo, .roro, .refrigeratedCargo:
            return false
        }
    }
    
    public var approximateLength: Float {
        switch self {
        case .bulkCarrier: return 250.0
        case .containerShip: return 300.0
        case .tanker: return 280.0
        case .generalCargo: return 150.0
        case .roro: return 180.0
        case .refrigeratedCargo: return 160.0
        case .heavyLift: return 200.0
        }
    }
}