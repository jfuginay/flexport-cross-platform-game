import Foundation
import Metal
import MetalKit
import CoreGraphics

/// Manages sprite loading, caching, and rendering
class SpriteManager {
    
    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    private var textureCache: [String: MTLTexture] = [:]
    private var programmaticTextures: [String: MTLTexture] = [:]
    
    // Sprite batches for efficient rendering
    private var shipBatch = SpriteBatch(maxSprites: 500)
    private var portBatch = SpriteBatch(maxSprites: 200)
    private var effectBatch = SpriteBatch(maxSprites: 1000)
    
    // Pipeline states
    private var spritePipelineState: MTLRenderPipelineState?
    private var particlePipelineState: MTLRenderPipelineState?
    
    // Uniform buffers
    private var spriteUniformBuffer: MTLBuffer?
    
    init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
        setupPipelines()
        generateProgrammaticTextures()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        // Sprite pipeline
        let spriteDescriptor = MTLRenderPipelineDescriptor()
        spriteDescriptor.vertexFunction = library.makeFunction(name: "spriteVertexShader")
        spriteDescriptor.fragmentFunction = library.makeFunction(name: "spriteFragmentShader")
        spriteDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending
        spriteDescriptor.colorAttachments[0].isBlendingEnabled = true
        spriteDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        spriteDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        spriteDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        spriteDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            spritePipelineState = try device.makeRenderPipelineState(descriptor: spriteDescriptor)
        } catch {
            print("Failed to create sprite pipeline state: \(error)")
        }
        
        // Create uniform buffer
        spriteUniformBuffer = device.makeBuffer(length: MemoryLayout<SpriteUniforms>.stride,
                                               options: [])
    }
    
    // MARK: - Texture Loading
    
    func loadTexture(named name: String) -> MTLTexture? {
        // Check cache first
        if let cached = textureCache[name] {
            return cached
        }
        
        // Check programmatic textures
        if let programmatic = programmaticTextures[name] {
            return programmatic
        }
        
        // Try to load from bundle
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .generateMipmaps: true
        ]
        
        do {
            if let url = Bundle.main.url(forResource: name, withExtension: "png") {
                let texture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
                textureCache[name] = texture
                return texture
            }
        } catch {
            print("Failed to load texture \(name): \(error)")
        }
        
        return nil
    }
    
    // MARK: - Programmatic Texture Generation
    
    private func generateProgrammaticTextures() {
        // Generate all ship type textures
        for shipType in ShipSpriteType.allCases {
            if let texture = generateShipTexture(type: shipType) {
                programmaticTextures[shipType.rawValue] = texture
            }
        }
        
        // Generate port infrastructure textures
        for portType in PortSpriteType.allCases {
            if let texture = generatePortTexture(type: portType) {
                programmaticTextures[portType.rawValue] = texture
            }
        }
        
        // Generate effect textures
        generateEffectTextures()
    }
    
    private func generateShipTexture(type: ShipSpriteType) -> MTLTexture? {
        let size = type.baseSize
        let width = Int(size.x * 2) // Higher resolution
        let height = Int(size.y * 2)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        // Create bitmap context
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        // Generate ship sprite based on type
        switch type {
        case .containerSmall, .containerMedium, .containerLarge, .containerMega, .containerFeeder:
            generateContainerShip(&pixelData, width: width, height: height, subtype: type)
            
        case .tankerCrude, .tankerProduct, .tankerChemical, .tankerLNG, .tankerLPG:
            generateTankerShip(&pixelData, width: width, height: height, subtype: type)
            
        case .bulkHandysize, .bulkHandymax, .bulkPanamax, .bulkCapesize, .bulkVLOC:
            generateBulkCarrier(&pixelData, width: width, height: height, subtype: type)
            
        case .carCarrier:
            generateCarCarrier(&pixelData, width: width, height: height)
            
        case .tugboat:
            generateTugboat(&pixelData, width: width, height: height)
            
        case .cruiseSmall, .cruiseLarge:
            generateCruiseShip(&pixelData, width: width, height: height, subtype: type)
            
        case .quantum, .singularity:
            generateFutureTechShip(&pixelData, width: width, height: height, subtype: type)
            
        default:
            generateGenericShip(&pixelData, width: width, height: height)
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: width, height: height, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: bytesPerRow)
        
        return texture
    }
    
    private func generateContainerShip(_ pixels: inout [UInt8], width: Int, height: Int, subtype: ShipSpriteType) {
        // Ship hull color
        let hullColor = SIMD4<UInt8>(60, 60, 80, 255) // Dark blue-gray
        let deckColor = SIMD4<UInt8>(200, 200, 200, 255) // Light gray
        let containerColors = [
            SIMD4<UInt8>(200, 50, 50, 255),   // Red
            SIMD4<UInt8>(50, 100, 200, 255),  // Blue
            SIMD4<UInt8>(50, 150, 50, 255),   // Green
            SIMD4<UInt8>(200, 150, 50, 255),  // Orange
            SIMD4<UInt8>(150, 50, 150, 255)   // Purple
        ]
        
        // Draw ship hull (elongated hexagon shape)
        let hullHeight = height * 3 / 5
        let bowStart = width / 6
        let bowPeak = width / 8
        let sternEnd = width * 5 / 6
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Hull shape
                if y > height - hullHeight {
                    let hullY = y - (height - hullHeight)
                    let hullProgress = Float(hullY) / Float(hullHeight)
                    
                    var leftEdge = bowStart
                    var rightEdge = sternEnd
                    
                    // Bow shape
                    if x < bowStart {
                        let bowProgress = Float(bowStart - x) / Float(bowStart - bowPeak)
                        if bowProgress < hullProgress {
                            setPixel(&pixels, index: index, color: hullColor)
                            continue
                        }
                    }
                    
                    // Main hull
                    if x >= leftEdge && x <= rightEdge {
                        setPixel(&pixels, index: index, color: hullColor)
                    }
                }
                
                // Deck and containers
                if y >= height * 2 / 5 && y < height - hullHeight + 10 {
                    if x >= bowStart + 10 && x <= sternEnd - 10 {
                        // Container stack pattern
                        let containerWidth = 20
                        let containerHeight = 15
                        let containerX = (x - bowStart - 10) / containerWidth
                        let containerY = (y - height * 2 / 5) / containerHeight
                        
                        if (x - bowStart - 10) % containerWidth < containerWidth - 2 &&
                           (y - height * 2 / 5) % containerHeight < containerHeight - 2 {
                            let colorIndex = (containerX + containerY) % containerColors.count
                            setPixel(&pixels, index: index, color: containerColors[colorIndex])
                        }
                    }
                }
                
                // Bridge structure
                let bridgeX = sternEnd - 20
                if x >= bridgeX - 15 && x <= bridgeX + 5 &&
                   y >= height / 4 && y <= height * 2 / 5 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(240, 240, 240, 255))
                }
            }
        }
    }
    
    private func generateTankerShip(_ pixels: inout [UInt8], width: Int, height: Int, subtype: ShipSpriteType) {
        // Tanker colors
        let hullColor = SIMD4<UInt8>(40, 40, 40, 255) // Black hull
        let deckColor = SIMD4<UInt8>(180, 60, 60, 255) // Red deck
        let pipeColor = SIMD4<UInt8>(150, 150, 150, 255) // Gray pipes
        
        // Draw rounded hull
        let centerY = height * 3 / 4
        let hullHeight = height / 2
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Elliptical hull shape
                let dx = Float(x - width / 2) / Float(width / 2)
                let dy = Float(y - centerY) / Float(hullHeight / 2)
                
                if dx * dx + dy * dy <= 1.0 && y > height / 2 {
                    setPixel(&pixels, index: index, color: hullColor)
                }
                
                // Deck area
                if y >= height / 2 && y < height * 3 / 4 {
                    let deckMargin = Int(Float(width) * 0.1)
                    if x >= deckMargin && x <= width - deckMargin {
                        // Rounded deck edges
                        let deckDx = Float(x - width / 2) / Float(width / 2 - deckMargin)
                        if abs(deckDx) <= 0.9 {
                            setPixel(&pixels, index: index, color: deckColor)
                            
                            // Pipe manifolds
                            if (x - deckMargin) % 30 < 5 && y % 20 < 15 {
                                setPixel(&pixels, index: index, color: pipeColor)
                            }
                        }
                    }
                }
                
                // Bridge at stern
                let bridgeX = width * 4 / 5
                if x >= bridgeX - 20 && x <= bridgeX &&
                   y >= height / 3 && y <= height / 2 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(220, 220, 220, 255))
                }
            }
        }
    }
    
    private func generateBulkCarrier(_ pixels: inout [UInt8], width: Int, height: Int, subtype: ShipSpriteType) {
        let hullColor = SIMD4<UInt8>(80, 60, 40, 255) // Brown hull
        let hatchColor = SIMD4<UInt8>(100, 100, 120, 255) // Blue-gray hatches
        let craneColor = SIMD4<UInt8>(200, 200, 50, 255) // Yellow cranes
        
        // Draw blocky hull
        let hullTop = height / 2
        let hullBottom = height * 4 / 5
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Hull with slight bow taper
                if y >= hullTop && y <= hullBottom {
                    let bowTaper = y < hullTop + 10 ? (y - hullTop) * 2 : 20
                    let sternTaper = y > hullBottom - 10 ? (hullBottom - y) * 2 : 20
                    
                    if x >= bowTaper && x <= width - sternTaper {
                        setPixel(&pixels, index: index, color: hullColor)
                    }
                }
                
                // Cargo hatches
                if y >= hullTop - 10 && y < hullTop {
                    let hatchSpacing = width / 6
                    for i in 1...5 {
                        let hatchX = i * hatchSpacing
                        if x >= hatchX - 20 && x <= hatchX + 20 {
                            setPixel(&pixels, index: index, color: hatchColor)
                        }
                    }
                }
                
                // Onboard cranes (for some bulk carriers)
                if subtype == .bulkHandysize || subtype == .bulkHandymax {
                    let craneSpacing = width / 4
                    for i in 1...3 {
                        let craneX = i * craneSpacing
                        if x >= craneX - 2 && x <= craneX + 2 &&
                           y >= hullTop - 30 && y <= hullTop {
                            setPixel(&pixels, index: index, color: craneColor)
                        }
                    }
                }
                
                // Bridge
                let bridgeX = width * 4 / 5
                if x >= bridgeX - 15 && x <= bridgeX + 5 &&
                   y >= height / 3 && y <= hullTop {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(200, 200, 200, 255))
                }
            }
        }
    }
    
    private func generateCarCarrier(_ pixels: inout [UInt8], width: Int, height: Int) {
        let hullColor = SIMD4<UInt8>(50, 50, 70, 255) // Dark blue hull
        let superstructureColor = SIMD4<UInt8>(240, 240, 240, 255) // White superstructure
        let windowColor = SIMD4<UInt8>(100, 150, 200, 255) // Blue windows
        
        // Car carriers have a distinctive boxy shape
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Lower hull
                if y >= height * 3 / 4 {
                    if x >= 10 && x <= width - 10 {
                        setPixel(&pixels, index: index, color: hullColor)
                    }
                }
                
                // Tall superstructure
                if y >= height / 4 && y < height * 3 / 4 {
                    if x >= 15 && x <= width - 15 {
                        setPixel(&pixels, index: index, color: superstructureColor)
                        
                        // Window rows
                        if y % 15 > 5 && y % 15 < 12 && x % 8 < 5 {
                            setPixel(&pixels, index: index, color: windowColor)
                        }
                    }
                }
                
                // Distinctive sloped stern ramp
                let rampStart = width * 4 / 5
                if x >= rampStart && y >= height / 2 {
                    let rampProgress = Float(x - rampStart) / Float(width - rampStart)
                    let rampY = Int(Float(height / 2) + rampProgress * Float(height / 4))
                    if y >= rampY {
                        setPixel(&pixels, index: index, color: superstructureColor)
                    }
                }
            }
        }
    }
    
    private func generateTugboat(_ pixels: inout [UInt8], width: Int, height: Int) {
        let hullColor = SIMD4<UInt8>(180, 50, 50, 255) // Red hull
        let superstructureColor = SIMD4<UInt8>(240, 240, 240, 255) // White
        let fenderColor = SIMD4<UInt8>(40, 40, 40, 255) // Black rubber fenders
        
        // Compact, powerful shape
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Rounded hull
                let centerX = width / 2
                let centerY = height * 2 / 3
                let radius = min(width, height) / 3
                
                let dx = x - centerX
                let dy = y - centerY
                let distance = sqrt(Float(dx * dx + dy * dy))
                
                if distance <= Float(radius) && y > height / 2 {
                    setPixel(&pixels, index: index, color: hullColor)
                    
                    // Fenders around the edge
                    if distance > Float(radius) - 5 {
                        setPixel(&pixels, index: index, color: fenderColor)
                    }
                }
                
                // Wheelhouse
                if x >= centerX - 10 && x <= centerX + 10 &&
                   y >= height / 3 && y <= height / 2 {
                    setPixel(&pixels, index: index, color: superstructureColor)
                }
                
                // Towing gear at stern
                if x >= centerX - 5 && x <= centerX + 5 &&
                   y >= centerY && y <= centerY + 10 {
                    setPixel(&pixels, index: index, color: SIMD4<UInt8>(100, 100, 100, 255))
                }
            }
        }
    }
    
    private func generateCruiseShip(_ pixels: inout [UInt8], width: Int, height: Int, subtype: ShipSpriteType) {
        let hullColor = SIMD4<UInt8>(30, 30, 50, 255) // Dark blue hull
        let superstructureColor = SIMD4<UInt8>(250, 250, 250, 255) // White
        let balconyColor = SIMD4<UInt8>(200, 200, 220, 255) // Light blue
        let lifeboatColor = SIMD4<UInt8>(255, 140, 0, 255) // Orange
        
        let decks = subtype == .cruiseLarge ? 12 : 8
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Sleek hull
                if y >= height * 4 / 5 {
                    let hullTaper = abs(x - width / 2) < width / 2 - 5
                    if hullTaper {
                        setPixel(&pixels, index: index, color: hullColor)
                    }
                }
                
                // Multiple deck levels
                let deckHeight = height * 3 / 5 / decks
                for deck in 0..<decks {
                    let deckY = height / 5 + deck * deckHeight
                    if y >= deckY && y < deckY + deckHeight - 2 {
                        let deckWidth = width - (deck * 4) // Each deck slightly narrower
                        let deckOffset = deck * 2
                        
                        if x >= deckOffset && x <= width - deckOffset {
                            setPixel(&pixels, index: index, color: superstructureColor)
                            
                            // Balconies
                            if x % 6 < 4 && y % deckHeight > 2 && y % deckHeight < deckHeight - 2 {
                                setPixel(&pixels, index: index, color: balconyColor)
                            }
                        }
                    }
                }
                
                // Lifeboats
                let lifeboatY = height * 3 / 5
                if y >= lifeboatY && y <= lifeboatY + 5 {
                    if (x - 10) % 20 < 10 && x > 10 && x < width - 10 {
                        setPixel(&pixels, index: index, color: lifeboatColor)
                    }
                }
            }
        }
    }
    
    private func generateFutureTechShip(_ pixels: inout [UInt8], width: Int, height: Int, subtype: ShipSpriteType) {
        let baseColor = subtype == .quantum ?
            SIMD4<UInt8>(100, 200, 255, 255) : // Quantum blue
            SIMD4<UInt8>(200, 100, 255, 255)   // Singularity purple
        
        let glowColor = subtype == .quantum ?
            SIMD4<UInt8>(150, 230, 255, 255) :
            SIMD4<UInt8>(255, 150, 255, 255)
        
        // Futuristic angular design
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Angular hull with energy field effect
                let centerX = width / 2
                let distFromCenter = abs(x - centerX)
                
                // Main hull
                if y >= height / 3 {
                    let hullWidth = width / 2 - (y - height / 3) / 2
                    if distFromCenter <= hullWidth {
                        setPixel(&pixels, index: index, color: baseColor)
                        
                        // Energy field edges
                        if distFromCenter >= hullWidth - 3 {
                            let alpha = UInt8(255 - (distFromCenter - hullWidth + 3) * 50)
                            setPixel(&pixels, index: index,
                                   color: SIMD4<UInt8>(glowColor.x, glowColor.y, glowColor.z, alpha))
                        }
                    }
                }
                
                // Quantum/Singularity core
                let coreY = height / 2
                let coreRadius = 15
                let dx = x - centerX
                let dy = y - coreY
                let coreDistance = sqrt(Float(dx * dx + dy * dy))
                
                if coreDistance <= Float(coreRadius) {
                    let intensity = 1.0 - coreDistance / Float(coreRadius)
                    let glowIntensity = UInt8(Float(255) * intensity)
                    setPixel(&pixels, index: index,
                           color: SIMD4<UInt8>(glowColor.x, glowColor.y, glowColor.z, glowIntensity))
                }
                
                // Energy streams
                if y >= height / 3 && y <= height * 2 / 3 {
                    let streamPhase = Float(y) * 0.1
                    let streamX = Int(sin(streamPhase) * 10) + centerX
                    if abs(x - streamX) <= 2 {
                        setPixel(&pixels, index: index, color: glowColor)
                    }
                }
            }
        }
    }
    
    private func generateGenericShip(_ pixels: inout [UInt8], width: Int, height: Int) {
        let hullColor = SIMD4<UInt8>(100, 100, 100, 255) // Gray
        let superstructureColor = SIMD4<UInt8>(200, 200, 200, 255) // Light gray
        
        // Simple ship shape
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Basic hull
                if y >= height / 2 && y <= height * 4 / 5 {
                    if x >= 10 && x <= width - 10 {
                        setPixel(&pixels, index: index, color: hullColor)
                    }
                }
                
                // Superstructure
                if y >= height / 3 && y < height / 2 {
                    let structureStart = width * 2 / 3
                    if x >= structureStart && x <= width - 15 {
                        setPixel(&pixels, index: index, color: superstructureColor)
                    }
                }
            }
        }
    }
    
    private func generatePortTexture(type: PortSpriteType) -> MTLTexture? {
        let size: (width: Int, height: Int)
        
        switch type {
        case .craneGantry, .craneSTS:
            size = (width: 100, height: 150)
        case .warehouseLarge, .tankFarm:
            size = (width: 120, height: 80)
        case .warehouseSmall:
            size = (width: 80, height: 60)
        case .lighthouse, .controlTower:
            size = (width: 60, height: 120)
        default:
            size = (width: 80, height: 80)
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size.width,
            height: size.height,
            mipmapped: false
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        var pixelData = [UInt8](repeating: 0, count: size.width * size.height * 4)
        
        switch type {
        case .craneGantry, .craneSTS, .craneMobile, .craneRTG:
            generateCrane(&pixelData, width: size.width, height: size.height, type: type)
            
        case .warehouseSmall, .warehouseLarge, .warehouseCold:
            generateWarehouse(&pixelData, width: size.width, height: size.height, type: type)
            
        case .tankFarm:
            generateTankFarm(&pixelData, width: size.width, height: size.height)
            
        case .lighthouse:
            generateLighthouse(&pixelData, width: size.width, height: size.height)
            
        case .controlTower:
            generateControlTower(&pixelData, width: size.width, height: size.height)
            
        case .containerYard:
            generateContainerYard(&pixelData, width: size.width, height: size.height)
            
        default:
            generateGenericBuilding(&pixelData, width: size.width, height: size.height)
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size.width, height: size.height, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size.width * 4)
        
        return texture
    }
    
    private func generateCrane(_ pixels: inout [UInt8], width: Int, height: Int, type: PortSpriteType) {
        let structureColor = SIMD4<UInt8>(255, 200, 0, 255) // Yellow
        let cabColor = SIMD4<UInt8>(100, 100, 100, 255) // Gray cab
        let cableColor = SIMD4<UInt8>(50, 50, 50, 255) // Dark cables
        
        // Crane legs
        let legWidth = 8
        let leg1X = width / 4
        let leg2X = width * 3 / 4
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Vertical legs
                if (x >= leg1X - legWidth/2 && x <= leg1X + legWidth/2) ||
                   (x >= leg2X - legWidth/2 && x <= leg2X + legWidth/2) {
                    if y >= height / 4 {
                        setPixel(&pixels, index: index, color: structureColor)
                    }
                }
                
                // Horizontal beam
                if y >= height / 4 && y <= height / 4 + 10 {
                    if x >= leg1X && x <= leg2X {
                        setPixel(&pixels, index: index, color: structureColor)
                    }
                }
                
                // Crane arm
                let armY = height / 4 + 5
                if y >= armY - 5 && y <= armY + 5 {
                    if x >= 10 && x <= width - 10 {
                        setPixel(&pixels, index: index, color: structureColor)
                    }
                }
                
                // Operator cab
                let cabX = width / 2
                if x >= cabX - 15 && x <= cabX + 15 &&
                   y >= armY + 10 && y <= armY + 30 {
                    setPixel(&pixels, index: index, color: cabColor)
                }
                
                // Cables
                if x % 20 < 2 && y >= armY && y <= height * 3 / 4 {
                    setPixel(&pixels, index: index, color: cableColor)
                }
            }
        }
    }
    
    private func generateWarehouse(_ pixels: inout [UInt8], width: Int, height: Int, type: PortSpriteType) {
        let wallColor = type == .warehouseCold ?
            SIMD4<UInt8>(200, 200, 255, 255) : // Blue for cold storage
            SIMD4<UInt8>(180, 180, 180, 255)   // Gray for regular
        
        let roofColor = SIMD4<UInt8>(100, 100, 100, 255)
        let doorColor = SIMD4<UInt8>(80, 80, 80, 255)
        
        // Building structure
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Walls
                if y >= height / 3 {
                    if x >= 5 && x <= width - 5 {
                        setPixel(&pixels, index: index, color: wallColor)
                    }
                }
                
                // Roof
                if y >= height / 4 && y < height / 3 {
                    let roofSlope = (y - height / 4) * 2
                    if x >= roofSlope && x <= width - roofSlope {
                        setPixel(&pixels, index: index, color: roofColor)
                    }
                }
                
                // Loading doors
                let doorSpacing = width / 4
                for i in 1...3 {
                    let doorX = i * doorSpacing
                    if x >= doorX - 10 && x <= doorX + 10 &&
                       y >= height * 2 / 3 {
                        setPixel(&pixels, index: index, color: doorColor)
                    }
                }
                
                // Windows (for office section)
                if type == .warehouseLarge {
                    if y >= height / 2 && y <= height * 2 / 3 {
                        if x % 15 > 5 && x % 15 < 12 {
                            setPixel(&pixels, index: index, color: SIMD4<UInt8>(150, 200, 255, 255))
                        }
                    }
                }
            }
        }
    }
    
    private func generateTankFarm(_ pixels: inout [UInt8], width: Int, height: Int) {
        let tankColor = SIMD4<UInt8>(220, 220, 220, 255) // Light gray
        let pipeColor = SIMD4<UInt8>(150, 150, 150, 255) // Medium gray
        let hazardColor = SIMD4<UInt8>(255, 255, 0, 255) // Yellow hazard stripes
        
        // Multiple cylindrical tanks
        let tankRadius = 15
        let tankSpacing = 35
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Draw 3 tanks
                for i in 0..<3 {
                    let tankCenterX = 25 + i * tankSpacing
                    let dx = x - tankCenterX
                    
                    // Cylindrical tank
                    if abs(dx) <= tankRadius && y >= height / 3 {
                        setPixel(&pixels, index: index, color: tankColor)
                        
                        // Hazard stripes
                        if y % 20 < 5 {
                            setPixel(&pixels, index: index, color: hazardColor)
                        }
                    }
                    
                    // Tank top
                    if y >= height / 3 - 5 && y < height / 3 {
                        let topRadius = tankRadius - (height / 3 - y)
                        if abs(dx) <= topRadius {
                            setPixel(&pixels, index: index, color: tankColor)
                        }
                    }
                }
                
                // Connecting pipes
                if y >= height - 10 && y <= height - 5 {
                    setPixel(&pixels, index: index, color: pipeColor)
                }
            }
        }
    }
    
    private func generateLighthouse(_ pixels: inout [UInt8], width: Int, height: Int) {
        let towerColor = SIMD4<UInt8>(240, 240, 240, 255) // White
        let stripeColor = SIMD4<UInt8>(200, 50, 50, 255) // Red stripes
        let lightColor = SIMD4<UInt8>(255, 255, 200, 255) // Yellow light
        let glassColor = SIMD4<UInt8>(150, 200, 255, 255) // Light blue glass
        
        let centerX = width / 2
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Tapered tower
                let towerWidth = 20 - (height - y) / 10
                let dx = abs(x - centerX)
                
                if dx <= towerWidth && y >= height / 5 {
                    // Alternating stripes
                    if (y / 15) % 2 == 0 {
                        setPixel(&pixels, index: index, color: towerColor)
                    } else {
                        setPixel(&pixels, index: index, color: stripeColor)
                    }
                }
                
                // Light room
                if y >= height / 8 && y < height / 5 {
                    if dx <= 12 {
                        setPixel(&pixels, index: index, color: glassColor)
                        
                        // Light beam
                        if dx <= 5 {
                            setPixel(&pixels, index: index, color: lightColor)
                        }
                    }
                }
                
                // Top cap
                if y < height / 8 {
                    let capRadius = 15 - y * 2
                    if dx <= capRadius {
                        setPixel(&pixels, index: index, color: stripeColor)
                    }
                }
            }
        }
    }
    
    private func generateControlTower(_ pixels: inout [UInt8], width: Int, height: Int) {
        let baseColor = SIMD4<UInt8>(150, 150, 150, 255) // Gray base
        let towerColor = SIMD4<UInt8>(200, 200, 200, 255) // Light gray tower
        let glassColor = SIMD4<UInt8>(100, 150, 200, 255) // Blue glass
        let antennaColor = SIMD4<UInt8>(100, 100, 100, 255) // Dark gray
        
        let centerX = width / 2
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Base building
                if y >= height * 3 / 4 {
                    if x >= centerX - 25 && x <= centerX + 25 {
                        setPixel(&pixels, index: index, color: baseColor)
                    }
                }
                
                // Tower shaft
                if y >= height / 3 && y < height * 3 / 4 {
                    if x >= centerX - 10 && x <= centerX + 10 {
                        setPixel(&pixels, index: index, color: towerColor)
                    }
                }
                
                // Control room (360-degree windows)
                if y >= height / 5 && y < height / 3 {
                    if x >= centerX - 20 && x <= centerX + 20 {
                        setPixel(&pixels, index: index, color: glassColor)
                    }
                }
                
                // Antennas and equipment
                if y < height / 5 {
                    // Main antenna
                    if x >= centerX - 2 && x <= centerX + 2 {
                        setPixel(&pixels, index: index, color: antennaColor)
                    }
                    
                    // Side antennas
                    if y < height / 10 {
                        if (x == centerX - 10 || x == centerX + 10) {
                            setPixel(&pixels, index: index, color: antennaColor)
                        }
                    }
                }
            }
        }
    }
    
    private func generateContainerYard(_ pixels: inout [UInt8], width: Int, height: Int) {
        let groundColor = SIMD4<UInt8>(100, 100, 100, 255) // Concrete
        let containerColors = [
            SIMD4<UInt8>(200, 50, 50, 255),   // Red
            SIMD4<UInt8>(50, 100, 200, 255),  // Blue
            SIMD4<UInt8>(50, 150, 50, 255),   // Green
            SIMD4<UInt8>(200, 150, 50, 255),  // Orange
            SIMD4<UInt8>(150, 50, 150, 255)   // Purple
        ]
        
        // Fill with ground
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                setPixel(&pixels, index: index, color: groundColor)
            }
        }
        
        // Stacked containers
        let containerWidth = 15
        let containerHeight = 8
        let stackHeight = 5
        
        for row in 0..<4 {
            for col in 0..<5 {
                let baseX = col * (containerWidth + 5) + 10
                let baseY = row * 20 + 10
                
                // Stack containers
                for stack in 0..<stackHeight - row {
                    let y = baseY + stack * containerHeight
                    if y + containerHeight < height {
                        for py in y..<y + containerHeight - 1 {
                            for px in baseX..<baseX + containerWidth - 1 {
                                if px < width && py < height {
                                    let index = (py * width + px) * 4
                                    let colorIndex = (row + col + stack) % containerColors.count
                                    setPixel(&pixels, index: index, color: containerColors[colorIndex])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func generateGenericBuilding(_ pixels: inout [UInt8], width: Int, height: Int) {
        let buildingColor = SIMD4<UInt8>(160, 160, 160, 255)
        let windowColor = SIMD4<UInt8>(100, 150, 200, 255)
        let doorColor = SIMD4<UInt8>(80, 80, 80, 255)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                
                // Building structure
                if y >= height / 3 {
                    if x >= 10 && x <= width - 10 {
                        setPixel(&pixels, index: index, color: buildingColor)
                        
                        // Windows
                        if y >= height / 2 && y <= height * 3 / 4 {
                            if x % 20 > 5 && x % 20 < 15 {
                                setPixel(&pixels, index: index, color: windowColor)
                            }
                        }
                        
                        // Door
                        if y >= height * 3 / 4 {
                            let doorX = width / 2
                            if x >= doorX - 10 && x <= doorX + 10 {
                                setPixel(&pixels, index: index, color: doorColor)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func generateEffectTextures() {
        // Generate wake texture
        generateWakeTexture()
        
        // Generate foam texture
        generateFoamTexture()
        
        // Generate smoke texture
        generateSmokeTexture()
        
        // Generate fire texture
        generateFireTexture()
        
        // Generate particle textures
        generateParticleTextures()
    }
    
    private func generateWakeTexture() {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                // Generate wake pattern
                let centerX = size / 2
                let dx = Float(x - centerX) / Float(size / 2)
                let dy = Float(y) / Float(size)
                
                // V-shaped wake
                let wakeIntensity = max(0, 1.0 - abs(dx) * 2) * (1.0 - dy)
                let foam = sin(dy * 10) * 0.3 + 0.7
                
                let alpha = UInt8(wakeIntensity * foam * 255)
                
                pixelData[index] = 255     // R
                pixelData[index + 1] = 255 // G
                pixelData[index + 2] = 255 // B
                pixelData[index + 3] = alpha
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        programmaticTextures["wake_effect"] = texture
    }
    
    private func generateFoamTexture() {
        let size = 128
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                // Noise-based foam
                let noise1 = sin(Float(x) * 0.1) * cos(Float(y) * 0.1)
                let noise2 = sin(Float(x + y) * 0.05)
                let foam = (noise1 + noise2) * 0.5 + 0.5
                
                let intensity = UInt8(foam * 255)
                
                pixelData[index] = 240         // R
                pixelData[index + 1] = 240     // G
                pixelData[index + 2] = 255     // B
                pixelData[index + 3] = intensity
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        programmaticTextures["foam_effect"] = texture
    }
    
    private func generateSmokeTexture() {
        let size = 128
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        let centerX = size / 2
        let centerY = size / 2
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = Float(x - centerX) / Float(size / 2)
                let dy = Float(y - centerY) / Float(size / 2)
                let distance = sqrt(dx * dx + dy * dy)
                
                // Soft circular gradient with noise
                let baseAlpha = max(0, 1.0 - distance)
                let noise = sin(Float(x) * 0.1) * sin(Float(y) * 0.1) * 0.2 + 0.8
                let alpha = UInt8(baseAlpha * noise * 255)
                
                pixelData[index] = 80      // R
                pixelData[index + 1] = 80  // G
                pixelData[index + 2] = 80  // B
                pixelData[index + 3] = alpha
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        programmaticTextures["smoke_effect"] = texture
    }
    
    private func generateFireTexture() {
        let size = 64
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let yNorm = Float(y) / Float(size)
                let xNorm = Float(x) / Float(size)
                
                // Fire shape (narrow at top, wide at bottom)
                let width = 0.5 + yNorm * 0.5
                let centerDist = abs(xNorm - 0.5)
                
                if centerDist < width * 0.5 {
                    let intensity = (1.0 - centerDist / (width * 0.5)) * (1.0 - yNorm)
                    
                    // Fire colors (yellow to red gradient)
                    let r = UInt8(255)
                    let g = UInt8(255 * (1.0 - yNorm * 0.5))
                    let b = UInt8(255 * (1.0 - yNorm))
                    let a = UInt8(intensity * 255)
                    
                    pixelData[index] = r
                    pixelData[index + 1] = g
                    pixelData[index + 2] = b
                    pixelData[index + 3] = a
                }
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        programmaticTextures["fire_effect"] = texture
    }
    
    private func generateParticleTextures() {
        // Generate various particle textures
        let particleTypes = ["circle", "star", "spark", "bubble"]
        
        for particleType in particleTypes {
            if let texture = generateParticleTexture(type: particleType) {
                programmaticTextures["particle_\(particleType)"] = texture
            }
        }
    }
    
    private func generateParticleTexture(type: String) -> MTLTexture? {
        let size = 32
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: true
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        let center = Float(size) / 2
        
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                
                let dx = Float(x) - center
                let dy = Float(y) - center
                let distance = sqrt(dx * dx + dy * dy) / center
                
                var alpha: Float = 0
                
                switch type {
                case "circle":
                    alpha = max(0, 1.0 - distance)
                    
                case "star":
                    let angle = atan2(dy, dx)
                    let star = abs(sin(angle * 5)) * 0.5 + 0.5
                    alpha = max(0, (1.0 - distance) * star)
                    
                case "spark":
                    alpha = distance < 0.2 ? 1.0 : 0
                    
                case "bubble":
                    alpha = distance > 0.7 && distance < 0.9 ? 1.0 : 0
                    
                default:
                    alpha = max(0, 1.0 - distance)
                }
                
                pixelData[index] = 255
                pixelData[index + 1] = 255
                pixelData[index + 2] = 255
                pixelData[index + 3] = UInt8(alpha * 255)
            }
        }
        
        texture.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                         size: MTLSize(width: size, height: size, depth: 1)),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: size * 4)
        
        return texture
    }
    
    // MARK: - Helper Functions
    
    private func setPixel(_ pixels: inout [UInt8], index: Int, color: SIMD4<UInt8>) {
        guard index + 3 < pixels.count else { return }
        pixels[index] = color.x
        pixels[index + 1] = color.y
        pixels[index + 2] = color.z
        pixels[index + 3] = color.w
    }
    
    // MARK: - Sprite Management
    
    func createShipSprite(type: ShipSpriteType, position: SIMD2<Float>) -> ShipSprite {
        var ship = ShipSprite(type: type, position: position)
        ship.sprite.texture = loadTexture(named: type.rawValue) ?? programmaticTextures[type.rawValue]
        return ship
    }
    
    func createPortSprite(type: PortSpriteType, position: SIMD2<Float>) -> PortSprite {
        var sprite = Sprite(position: position)
        sprite.texture = loadTexture(named: type.rawValue) ?? programmaticTextures[type.rawValue]
        
        return PortSprite(
            id: UUID(),
            sprite: sprite,
            type: type,
            activityLevel: 0,
            animations: [],
            connectedInfrastructure: []
        )
    }
    
    // MARK: - Batch Management
    
    func addShipToBatch(_ ship: ShipSprite) {
        shipBatch.add(ship.sprite)
    }
    
    func addPortToBatch(_ port: PortSprite) {
        portBatch.add(port.sprite)
    }
    
    func addEffectToBatch(_ effect: Sprite) {
        effectBatch.add(effect)
    }
    
    func clearBatches() {
        shipBatch.clear()
        portBatch.clear()
        effectBatch.clear()
    }
}

// MARK: - Sprite Uniforms

struct SpriteUniforms {
    var viewProjectionMatrix: matrix_float4x4
    var time: Float
}