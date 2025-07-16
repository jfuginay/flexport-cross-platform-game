import Foundation
import AVFoundation
import simd
import Metal
import MetalKit
import Combine

/// Advanced 3D spatial audio engine for immersive logistics gameplay
public class SpatialAudioEngine: NSObject, ObservableObject {
    
    // MARK: - Singleton
    public static let shared = SpatialAudioEngine()
    
    // MARK: - Published Properties
    @Published public private(set) var isEngineRunning: Bool = false
    @Published public private(set) var spatialAudioEnabled: Bool = true
    @Published public private(set) var listenerPosition: simd_float3 = simd_float3(0, 0, 0)
    @Published public private(set) var listenerOrientation: simd_float3 = simd_float3(0, 0, -1)
    @Published public private(set) var activeSources: Int = 0
    
    // MARK: - Core Audio Engine
    private let audioEngine = AVAudioEngine()
    private let environmentNode = AVAudioEnvironmentNode()
    private let reverbNode = AVAudioUnitReverb()
    private let masterEQNode = AVAudioUnitEQ(numberOfBands: 10)
    
    // MARK: - 3D Audio Sources
    private var audioSources: [UUID: SpatialAudioSource] = [:]
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var sourceQueue = DispatchQueue(label: "com.flexport.audio.sources", qos: .userInteractive)
    
    // MARK: - Metal Acceleration
    private var metalDevice: MTLDevice?
    private var metalCommandQueue: MTLCommandQueue?
    private var audioProcessingPipeline: MTLComputePipelineState?
    
    // MARK: - Audio Resources
    private var audioBuffers: [String: AVAudioPCMBuffer] = [:]
    private var loadedSounds: Set<String> = []
    
    // MARK: - Configuration
    public struct Configuration {
        public var maxConcurrentSources: Int = 64
        public var spatialBlendDistance: Float = 100.0
        public var dopplerFactor: Float = 1.0
        public var rolloffFactor: Float = 1.0
        public var environmentPreset: AVAudioEnvironmentNode.EnvironmentType = .largeHall
        public var reverbWetness: Float = 0.3
        public var enableMetalAcceleration: Bool = true
        public var spatialPrecision: SpatialPrecision = .high
        
        public init() {}
    }
    
    public var configuration = Configuration()
    
    // MARK: - Listener Properties
    private var cameraPosition: simd_float3 = simd_float3(0, 0, 0)
    private var cameraForward: simd_float3 = simd_float3(0, 0, -1)
    private var cameraUp: simd_float3 = simd_float3(0, 1, 0)
    private var cameraRight: simd_float3 = simd_float3(1, 0, 0)
    
    // MARK: - Performance Monitoring
    private var frameTime: TimeInterval = 0
    private var processingLoad: Float = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioEngine()
        setupMetalAcceleration()
        setupNotifications()
    }
    
    // MARK: - Public Interface
    
    /// Start the spatial audio engine
    public func startEngine() throws {
        guard !audioEngine.isRunning else { return }
        
        try audioEngine.start()
        isEngineRunning = true
        
        print("Spatial Audio Engine started successfully")
    }
    
    /// Stop the spatial audio engine
    public func stopEngine() {
        audioEngine.stop()
        isEngineRunning = false
        
        print("Spatial Audio Engine stopped")
    }
    
    /// Update listener position and orientation (camera/player position)
    public func updateListener(position: simd_float3, forward: simd_float3, up: simd_float3) {
        listenerPosition = position
        listenerOrientation = forward
        
        cameraPosition = position
        cameraForward = normalize(forward)
        cameraUp = normalize(up)
        cameraRight = normalize(cross(cameraForward, cameraUp))
        
        // Update environment node
        let listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: atan2(forward.x, forward.z) * 180 / .pi,
            pitch: asin(forward.y) * 180 / .pi,
            roll: 0
        )
        
        environmentNode.listenerPosition = AVAudio3DPoint(
            x: position.x,
            y: position.y,
            z: position.z
        )
        
        environmentNode.listenerAngularOrientation = listenerAngularOrientation
    }
    
    /// Create a new spatial audio source
    public func createAudioSource(id: UUID, soundName: String, position: simd_float3, looping: Bool = false) -> Bool {
        guard audioSources.count < configuration.maxConcurrentSources else {
            print("Maximum concurrent audio sources reached")
            return false
        }
        
        guard let audioBuffer = getAudioBuffer(for: soundName) else {
            print("Audio buffer not found for sound: \(soundName)")
            return false
        }
        
        sourceQueue.sync {
            let playerNode = AVAudioPlayerNode()
            let source = SpatialAudioSource(
                id: id,
                playerNode: playerNode,
                audioBuffer: audioBuffer,
                position: position,
                soundName: soundName,
                isLooping: looping
            )
            
            audioSources[id] = source
            playerNodes[id] = playerNode
            
            // Connect to audio graph
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: environmentNode, format: audioBuffer.format)
            
            // Configure 3D positioning
            update3DPosition(for: id, position: position)
            
            activeSources = audioSources.count
        }
        
        return true
    }
    
    /// Play audio source
    public func playAudioSource(id: UUID, fadeInDuration: TimeInterval = 0.0) {
        guard let source = audioSources[id],
              let playerNode = playerNodes[id] else { return }
        
        sourceQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !playerNode.isPlaying {
                if source.isLooping {
                    playerNode.scheduleBuffer(source.audioBuffer, at: nil, options: .loops, completionHandler: nil)
                } else {
                    playerNode.scheduleBuffer(source.audioBuffer, at: nil, options: [], completionHandler: { [weak self] in
                        self?.sourceQueue.async {
                            self?.removeAudioSource(id: id)
                        }
                    })
                }
                
                if fadeInDuration > 0 {
                    playerNode.volume = 0.0
                    playerNode.play()
                    self.fadeVolume(for: id, to: source.volume, duration: fadeInDuration)
                } else {
                    playerNode.volume = source.volume
                    playerNode.play()
                }
            }
        }
    }
    
    /// Stop audio source
    public func stopAudioSource(id: UUID, fadeOutDuration: TimeInterval = 0.0) {
        guard let playerNode = playerNodes[id] else { return }
        
        if fadeOutDuration > 0 {
            fadeVolume(for: id, to: 0.0, duration: fadeOutDuration) { [weak self] in
                self?.removeAudioSource(id: id)
            }
        } else {
            removeAudioSource(id: id)
        }
    }
    
    /// Update 3D position of audio source
    public func update3DPosition(for id: UUID, position: simd_float3, velocity: simd_float3 = simd_float3(0, 0, 0)) {
        guard let source = audioSources[id],
              let playerNode = playerNodes[id] else { return }
        
        sourceQueue.async {
            // Update source position
            source.position = position
            source.velocity = velocity
            
            // Calculate 3D audio parameters
            let distance = length(position - self.cameraPosition)
            let direction = normalize(position - self.cameraPosition)
            
            // Apply distance-based attenuation
            let attenuation = self.calculateAttenuation(distance: distance)
            let volume = source.baseVolume * attenuation
            
            // Calculate doppler shift if enabled
            var dopplerShift: Float = 1.0
            if self.configuration.dopplerFactor > 0 {
                let relativeVelocity = dot(velocity, direction)
                dopplerShift = self.calculateDopplerShift(relativeVelocity: relativeVelocity)
            }
            
            // Apply to player node
            DispatchQueue.main.async {
                playerNode.volume = volume
                if dopplerShift != 1.0 {
                    playerNode.rate = dopplerShift
                }
                
                // Update 3D positioning on environment node
                if let mixer = playerNode.engine?.outputNode as? AVAudioMixerNode {
                    // Set the source position in 3D space
                    source.playerNode.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
                }
            }
        }
    }
    
    /// Remove audio source
    public func removeAudioSource(id: UUID) {
        sourceQueue.sync {
            guard let playerNode = playerNodes[id] else { return }
            
            if playerNode.isPlaying {
                playerNode.stop()
            }
            
            audioEngine.detach(playerNode)
            audioSources.removeValue(forKey: id)
            playerNodes.removeValue(forKey: id)
            
            activeSources = audioSources.count
        }
    }
    
    /// Load audio file into buffer cache
    public func loadAudioFile(named fileName: String, fileExtension: String = "wav") -> Bool {
        guard !loadedSounds.contains(fileName) else { return true }
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("Audio file not found: \(fileName).\(fileExtension)")
            return false
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, 
                                        frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)
            
            audioBuffers[fileName] = buffer
            loadedSounds.insert(fileName)
            
            print("Loaded audio file: \(fileName)")
            return true
        } catch {
            print("Failed to load audio file \(fileName): \(error)")
            return false
        }
    }
    
    /// Set environment preset
    public func setEnvironmentPreset(_ preset: AVAudioEnvironmentNode.EnvironmentType) {
        configuration.environmentPreset = preset
        environmentNode.applicableRenderingAlgorithm = .sphericalHead
        // Note: Environment presets would be implemented with custom reverb settings
        updateEnvironmentSettings()
    }
    
    /// Set master volume
    public func setMasterVolume(_ volume: Float) {
        audioEngine.mainMixerNode.outputVolume = max(0.0, min(1.0, volume))
    }
    
    /// Get processing performance metrics
    public func getPerformanceMetrics() -> AudioPerformanceMetrics {
        return AudioPerformanceMetrics(
            frameTime: frameTime,
            processingLoad: processingLoad,
            activeSources: activeSources,
            memoryUsage: calculateMemoryUsage()
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupAudioEngine() {
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .gameChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Attach nodes to engine
        audioEngine.attach(environmentNode)
        audioEngine.attach(reverbNode)
        audioEngine.attach(masterEQNode)
        
        // Connect audio graph
        audioEngine.connect(environmentNode, to: reverbNode, format: nil)
        audioEngine.connect(reverbNode, to: masterEQNode, format: nil)
        audioEngine.connect(masterEQNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Configure environment node
        environmentNode.applicableRenderingAlgorithm = .sphericalHead
        environmentNode.sourceMode = .spatializedPointSource
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        
        // Configure reverb
        reverbNode.loadFactoryPreset(.largeHall)
        reverbNode.wetDryMix = configuration.reverbWetness * 100
        
        // Configure EQ
        setupMasterEQ()
        
        // Prepare engine
        audioEngine.prepare()
    }
    
    private func setupMetalAcceleration() {
        guard configuration.enableMetalAcceleration else { return }
        
        metalDevice = MTLCreateSystemDefaultDevice()
        metalCommandQueue = metalDevice?.makeCommandQueue()
        
        guard let device = metalDevice else {
            print("Metal device not available")
            return
        }
        
        // Create compute pipeline for audio processing
        guard let library = device.makeDefaultLibrary() else {
            print("Metal library not available")
            return
        }
        
        do {
            if let function = library.makeFunction(name: "spatialAudioProcessor") {
                audioProcessingPipeline = try device.makeComputePipelineState(function: function)
                print("Metal acceleration initialized for spatial audio")
            }
        } catch {
            print("Failed to create Metal pipeline: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupMasterEQ() {
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        for (index, frequency) in frequencies.enumerated() {
            let band = masterEQNode.bands[index]
            band.frequency = frequency
            band.filterType = .parametric
            band.bandwidth = 0.5
            band.gain = 0.0
            band.bypass = false
        }
    }
    
    private func updateEnvironmentSettings() {
        // Update reverb settings based on environment
        switch configuration.environmentPreset {
        case .bathroom:
            reverbNode.wetDryMix = 60
        case .largeHall:
            reverbNode.wetDryMix = 40
        case .mediumHall:
            reverbNode.wetDryMix = 30
        case .plate:
            reverbNode.wetDryMix = 25
        case .smallRoom:
            reverbNode.wetDryMix = 20
        default:
            reverbNode.wetDryMix = configuration.reverbWetness * 100
        }
    }
    
    private func getAudioBuffer(for soundName: String) -> AVAudioPCMBuffer? {
        if let buffer = audioBuffers[soundName] {
            return buffer
        }
        
        // Try to load the file if not already loaded
        if loadAudioFile(named: soundName) {
            return audioBuffers[soundName]
        }
        
        return nil
    }
    
    private func calculateAttenuation(distance: Float) -> Float {
        let rolloff = configuration.rolloffFactor
        let reference = 1.0
        let maxDistance = configuration.spatialBlendDistance
        
        if distance <= reference {
            return 1.0
        }
        
        if distance >= maxDistance {
            return 0.0
        }
        
        // Logarithmic rolloff
        return reference / (reference + rolloff * (distance - reference))
    }
    
    private func calculateDopplerShift(relativeVelocity: Float) -> Float {
        let speedOfSound: Float = 343.0 // m/s
        let dopplerFactor = configuration.dopplerFactor
        
        return (speedOfSound + dopplerFactor * relativeVelocity) / speedOfSound
    }
    
    private func fadeVolume(for id: UUID, to targetVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let playerNode = playerNodes[id] else { return }
        
        let startVolume = playerNode.volume
        let volumeChange = targetVolume - startVolume
        let frameRate = 60.0
        let steps = Int(duration * frameRate)
        let stepSize = volumeChange / Float(steps)
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0 / frameRate, repeats: true) { timer in
            currentStep += 1
            let newVolume = startVolume + stepSize * Float(currentStep)
            
            DispatchQueue.main.async {
                playerNode.volume = newVolume
            }
            
            if currentStep >= steps {
                timer.invalidate()
                DispatchQueue.main.async {
                    playerNode.volume = targetVolume
                    completion?()
                }
            }
        }
    }
    
    private func calculateMemoryUsage() -> Float {
        // Calculate memory usage of loaded audio buffers
        var totalBytes: Int = 0
        
        for buffer in audioBuffers.values {
            let frameCount = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)
            let bytesPerFrame = 4 // Float32
            totalBytes += frameCount * channelCount * bytesPerFrame
        }
        
        return Float(totalBytes) / (1024 * 1024) // MB
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            print("Audio interruption began")
            if audioEngine.isRunning {
                audioEngine.pause()
            }
        case .ended:
            print("Audio interruption ended")
            do {
                try startEngine()
            } catch {
                print("Failed to restart audio engine: \(error)")
            }
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        print("Audio route changed")
        // Handle audio route changes (headphones, speakers, etc.)
    }
}

// MARK: - Supporting Types

public class SpatialAudioSource: ObservableObject {
    public let id: UUID
    public let playerNode: AVAudioPlayerNode
    public let audioBuffer: AVAudioPCMBuffer
    public let soundName: String
    public let isLooping: Bool
    
    @Published public var position: simd_float3
    @Published public var velocity: simd_float3 = simd_float3(0, 0, 0)
    @Published public var volume: Float = 1.0
    @Published public var pitch: Float = 1.0
    @Published public var isPlaying: Bool = false
    
    public let baseVolume: Float
    public var lastUpdateTime: TimeInterval = 0
    
    public init(id: UUID, playerNode: AVAudioPlayerNode, audioBuffer: AVAudioPCMBuffer, 
                position: simd_float3, soundName: String, isLooping: Bool) {
        self.id = id
        self.playerNode = playerNode
        self.audioBuffer = audioBuffer
        self.position = position
        self.soundName = soundName
        self.isLooping = isLooping
        self.baseVolume = 1.0
        self.volume = 1.0
    }
}

public enum SpatialPrecision {
    case low
    case medium
    case high
    case ultra
    
    public var updateFrequency: TimeInterval {
        switch self {
        case .low: return 1.0/30.0    // 30 FPS
        case .medium: return 1.0/60.0  // 60 FPS
        case .high: return 1.0/120.0   // 120 FPS
        case .ultra: return 1.0/240.0  // 240 FPS
        }
    }
}

public struct AudioPerformanceMetrics {
    public let frameTime: TimeInterval
    public let processingLoad: Float
    public let activeSources: Int
    public let memoryUsage: Float // MB
    
    public init(frameTime: TimeInterval, processingLoad: Float, activeSources: Int, memoryUsage: Float) {
        self.frameTime = frameTime
        self.processingLoad = processingLoad
        self.activeSources = activeSources
        self.memoryUsage = memoryUsage
    }
}

// MARK: - Audio Source Management Extensions

extension SpatialAudioEngine {
    
    /// Convenience method for playing one-shot sounds
    public func playSound(_ soundName: String, at position: simd_float3, volume: Float = 1.0) -> UUID? {
        let id = UUID()
        
        if createAudioSource(id: id, soundName: soundName, position: position, looping: false) {
            if let source = audioSources[id] {
                source.volume = volume
            }
            playAudioSource(id: id)
            return id
        }
        
        return nil
    }
    
    /// Convenience method for playing looping ambient sounds
    public func playAmbientSound(_ soundName: String, at position: simd_float3, volume: Float = 0.5) -> UUID? {
        let id = UUID()
        
        if createAudioSource(id: id, soundName: soundName, position: position, looping: true) {
            if let source = audioSources[id] {
                source.volume = volume
            }
            playAudioSource(id: id, fadeInDuration: 2.0)
            return id
        }
        
        return nil
    }
    
    /// Update all audio sources with new listener position efficiently
    public func updateAllSources() {
        sourceQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (id, source) in self.audioSources {
                self.update3DPosition(for: id, position: source.position, velocity: source.velocity)
            }
        }
    }
    
    /// Stop all audio sources
    public func stopAllSources(fadeOutDuration: TimeInterval = 1.0) {
        sourceQueue.async { [weak self] in
            guard let self = self else { return }
            
            let sourceIds = Array(self.audioSources.keys)
            for id in sourceIds {
                self.stopAudioSource(id: id, fadeOutDuration: fadeOutDuration)
            }
        }
    }
}