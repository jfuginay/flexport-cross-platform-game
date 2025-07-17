import Metal
import MetalKit
import simd

// MARK: - Metal Ocean Renderer

public class MetalOceanRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let advancedOceanRenderer: AdvancedOceanRenderer
    private let shipSpriteManager: ShipSpriteManager
    
    // Performance Management
    private var qualityLevel: QualityLevel = .high
    private var targetFPS: Int = 60
    private var frameTime: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    
    // Ocean Parameters
    private var oceanTime: Float = 0
    private var timeOfDay: Float = 0.5 // 0 = midnight, 0.5 = noon, 1 = midnight
    private var weatherIntensity: Float = 0
    private var currentWeather: AdvancedOceanRenderer.WeatherType = .clear
    
    public enum QualityLevel: Int {
        case low = 0
        case medium = 1
        case high = 2
        case ultra = 3
        
        var oceanResolution: Int {
            switch self {
            case .low: return 128
            case .medium: return 256
            case .high: return 512
            case .ultra: return 1024
            }
        }
        
        var waveComplexity: Int {
            switch self {
            case .low: return 2
            case .medium: return 4
            case .high: return 6
            case .ultra: return 8
            }
        }
        
        var particleCount: Int {
            switch self {
            case .low: return 100
            case .medium: return 500
            case .high: return 1000
            case .ultra: return 2000
            }
        }
    }
    
    public init?(device: MTLDevice) {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        guard let oceanRenderer = AdvancedOceanRenderer(device: device) else {
            return nil
        }
        self.advancedOceanRenderer = oceanRenderer
        
        self.shipSpriteManager = ShipSpriteManager(device: device)
        
        setupQualitySettings()
    }
    
    // MARK: - Setup
    
    private func setupQualitySettings() {
        // Detect device capabilities and set appropriate quality
        if device.supportsFamily(.apple7) {
            qualityLevel = .ultra
        } else if device.supportsFamily(.apple6) {
            qualityLevel = .high
        } else if device.supportsFamily(.apple5) {
            qualityLevel = .medium
        } else {
            qualityLevel = .low
        }
    }
    
    // MARK: - Rendering
    
    public func render(
        in view: MTKView,
        projectionMatrix: matrix_float4x4,
        viewMatrix: matrix_float4x4,
        deltaTime: TimeInterval
    ) {
        frameTime = CACurrentMediaTime()
        oceanTime += Float(deltaTime)
        
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Update time of day for dynamic lighting
        updateTimeOfDay(deltaTime)
        
        // Configure render pass
        renderPassDescriptor.colorAttachments[0].clearColor = getClearColor()
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Render ocean with advanced effects
        advancedOceanRenderer.render(
            in: renderEncoder,
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix,
            deltaTime: Float(deltaTime)
        )
        
        // Render ships with optimized batching
        shipSpriteManager.render(
            encoder: renderEncoder,
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix,
            oceanTime: oceanTime
        )
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Performance monitoring
        updatePerformanceMetrics(deltaTime)
    }
    
    // MARK: - Time of Day
    
    private func updateTimeOfDay(_ deltaTime: TimeInterval) {
        // Slowly cycle through day/night (24 minute real-time = 24 hour game time)
        timeOfDay += Float(deltaTime) / (24.0 * 60.0)
        if timeOfDay > 1.0 {
            timeOfDay -= 1.0
        }
    }
    
    private func getClearColor() -> MTLClearColor {
        // Dynamic sky color based on time of day
        let sunAngle = timeOfDay * 2 * Float.pi
        let sunHeight = sin(sunAngle - Float.pi / 2)
        
        // Dawn/Dusk detection
        let isDawnDusk = abs(sunHeight) < 0.3
        
        var r: Float, g: Float, b: Float
        
        if sunHeight > 0 {
            // Daytime
            if isDawnDusk {
                // Sunrise/Sunset colors
                r = 0.9 + sunHeight * 0.1
                g = 0.4 + sunHeight * 0.4
                b = 0.2 + sunHeight * 0.6
            } else {
                // Blue sky
                r = 0.3 + sunHeight * 0.2
                g = 0.5 + sunHeight * 0.3
                b = 0.8 + sunHeight * 0.2
            }
        } else {
            // Nighttime
            r = 0.05 - sunHeight * 0.03
            g = 0.05 - sunHeight * 0.03
            b = 0.15 - sunHeight * 0.1
        }
        
        // Weather influence
        let weatherDarkness = weatherIntensity * 0.3
        r *= (1.0 - weatherDarkness)
        g *= (1.0 - weatherDarkness)
        b *= (1.0 - weatherDarkness)
        
        return MTLClearColor(red: Double(r), green: Double(g), blue: Double(b), alpha: 1.0)
    }
    
    // MARK: - Weather Control
    
    public func setWeather(_ weather: AdvancedOceanRenderer.WeatherType, intensity: Float) {
        currentWeather = weather
        weatherIntensity = intensity
        advancedOceanRenderer.setWeather(weather, intensity: intensity)
        
        // Adjust ship rendering for weather
        shipSpriteManager.setWeatherConditions(weather: weather, intensity: intensity)
    }
    
    public func addStorm(at position: SIMD3<Float>, radius: Float, intensity: Float) {
        advancedOceanRenderer.setStormCenter(position)
        
        // Create storm disaster effect
        let stormEffect = AdvancedOceanRenderer.DisasterEffect(
            type: .storm,
            position: position,
            radius: radius,
            intensity: intensity,
            duration: 30.0 // 30 second storm
        )
        advancedOceanRenderer.addDisasterEffect(stormEffect)
    }
    
    // MARK: - Ship Management
    
    public func addShip(id: String, type: ShipType, position: SIMD2<Float>) {
        shipSpriteManager.addShip(id: id, type: type, position: position)
    }
    
    public func updateShip(id: String, position: SIMD2<Float>, rotation: Float) {
        shipSpriteManager.updateShip(id: id, position: position, rotation: rotation)
    }
    
    public func removeShip(id: String) {
        shipSpriteManager.removeShip(id: id)
    }
    
    public func highlightShip(id: String, color: SIMD4<Float>) {
        shipSpriteManager.highlightShip(id: id, color: color)
    }
    
    // MARK: - Performance
    
    public func setQualityLevel(_ level: QualityLevel) {
        qualityLevel = level
        
        // Update renderer settings
        switch level {
        case .low:
            advancedOceanRenderer.waveAmplitude = 0.5
            advancedOceanRenderer.waveFrequency = 0.01
            shipSpriteManager.enableParticleEffects = false
            shipSpriteManager.enableDynamicLighting = false
            
        case .medium:
            advancedOceanRenderer.waveAmplitude = 0.8
            advancedOceanRenderer.waveFrequency = 0.015
            shipSpriteManager.enableParticleEffects = true
            shipSpriteManager.enableDynamicLighting = false
            
        case .high:
            advancedOceanRenderer.waveAmplitude = 1.0
            advancedOceanRenderer.waveFrequency = 0.02
            shipSpriteManager.enableParticleEffects = true
            shipSpriteManager.enableDynamicLighting = true
            
        case .ultra:
            advancedOceanRenderer.waveAmplitude = 1.2
            advancedOceanRenderer.waveFrequency = 0.025
            shipSpriteManager.enableParticleEffects = true
            shipSpriteManager.enableDynamicLighting = true
            shipSpriteManager.enableAdvancedEffects = true
        }
    }
    
    private func updatePerformanceMetrics(_ deltaTime: TimeInterval) {
        let currentFPS = 1.0 / deltaTime
        
        // Adaptive quality adjustment
        if currentFPS < Double(targetFPS) * 0.9 && qualityLevel.rawValue > 0 {
            // Downgrade quality if performance is poor
            if let lowerQuality = QualityLevel(rawValue: qualityLevel.rawValue - 1) {
                setQualityLevel(lowerQuality)
            }
        } else if currentFPS > Double(targetFPS) * 1.1 && qualityLevel.rawValue < QualityLevel.ultra.rawValue {
            // Consider upgrading quality if performance is good
            if let higherQuality = QualityLevel(rawValue: qualityLevel.rawValue + 1) {
                // Only upgrade after sustained good performance
                if frameTime - lastFrameTime > 5.0 {
                    setQualityLevel(higherQuality)
                    lastFrameTime = frameTime
                }
            }
        }
    }
    
    // MARK: - Special Effects
    
    public func createExplosion(at position: SIMD3<Float>, size: Float) {
        let explosionEffect = AdvancedOceanRenderer.DisasterEffect(
            type: .fire,
            position: position,
            radius: size,
            intensity: 1.0,
            duration: 3.0
        )
        advancedOceanRenderer.addDisasterEffect(explosionEffect)
        
        // Add ship damage effects
        shipSpriteManager.createExplosionEffect(at: SIMD2<Float>(position.x, position.z))
    }
    
    public func createWakeEffect(shipId: String, intensity: Float) {
        shipSpriteManager.setWakeIntensity(for: shipId, intensity: intensity)
    }
    
    // MARK: - Camera Controls
    
    public func getCameraMatrix(
        position: SIMD3<Float>,
        rotation: SIMD3<Float>,
        zoom: Float
    ) -> matrix_float4x4 {
        // Create view matrix with smooth camera movement
        let eye = position
        let center = position + SIMD3<Float>(
            sin(rotation.y) * cos(rotation.x),
            sin(rotation.x),
            cos(rotation.y) * cos(rotation.x)
        )
        let up = SIMD3<Float>(0, 1, 0)
        
        return matrix_look_at(eye: eye, center: center, up: up)
    }
    
    // MARK: - Utility
    
    private func matrix_look_at(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        
        let P = SIMD4<Float>(x.x, y.x, z.x, 0)
        let Q = SIMD4<Float>(x.y, y.y, z.y, 0)
        let R = SIMD4<Float>(x.z, y.z, z.z, 0)
        let S = SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        
        return matrix_float4x4(P, Q, R, S)
    }
}

// MARK: - Shader Types Extension

extension AdvancedOceanRenderer {
    public var waveAmplitude: Float {
        get { return self.waveAmplitude }
        set { self.waveAmplitude = newValue }
    }
    
    public var waveFrequency: Float {
        get { return self.waveFrequency }
        set { self.waveFrequency = newValue }
    }
}