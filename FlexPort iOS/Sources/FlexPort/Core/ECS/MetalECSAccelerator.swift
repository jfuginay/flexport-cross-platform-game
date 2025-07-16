import Foundation
import Metal
import simd

/// Metal compute shader accelerator for ECS processing
public class MetalECSAccelerator {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipelines for different ECS operations
    private var transformPipeline: MTLComputePipelineState?
    private var physicsPipeline: MTLComputePipelineState?
    private var aiDecisionPipeline: MTLComputePipelineState?
    private var economicPipeline: MTLComputePipelineState?
    
    // Buffers for component data
    private var transformBuffer: MTLBuffer?
    private var physicsBuffer: MTLBuffer?
    private var aiStateBuffer: MTLBuffer?
    private var economicDataBuffer: MTLBuffer?
    
    // Buffer pool for dynamic allocation
    private var bufferPool: [MTLBuffer] = []
    private let maxBufferCount = 16
    
    public init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return nil
        }
        self.library = library
        
        setupComputePipelines()
        setupBufferPool()
    }
    
    private func setupComputePipelines() {
        // Transform processing pipeline
        if let transformFunction = library.makeFunction(name: "transformKernel") {
            do {
                transformPipeline = try device.makeComputePipelineState(function: transformFunction)
            } catch {
                print("Failed to create transform pipeline: \(error)")
            }
        }
        
        // Physics processing pipeline
        if let physicsFunction = library.makeFunction(name: "physicsKernel") {
            do {
                physicsPipeline = try device.makeComputePipelineState(function: physicsFunction)
            } catch {
                print("Failed to create physics pipeline: \(error)")
            }
        }
        
        // AI decision pipeline
        if let aiFunction = library.makeFunction(name: "aiDecisionKernel") {
            do {
                aiDecisionPipeline = try device.makeComputePipelineState(function: aiFunction)
            } catch {
                print("Failed to create AI pipeline: \(error)")
            }
        }
        
        // Economic simulation pipeline
        if let economicFunction = library.makeFunction(name: "economicSimulationKernel") {
            do {
                economicPipeline = try device.makeComputePipelineState(function: economicFunction)
            } catch {
                print("Failed to create economic pipeline: \(error)")
            }
        }
    }
    
    private func setupBufferPool() {
        for _ in 0..<maxBufferCount {
            if let buffer = device.makeBuffer(length: 1024 * 1024, options: .storageModeShared) {
                bufferPool.append(buffer)
            }
        }
    }
    
    /// Process transform components using Metal compute shaders
    public func processTransforms(_ transforms: [TransformComponent], entities: [Entity], deltaTime: Float) -> [TransformComponent] {
        guard let pipeline = transformPipeline,
              transforms.count > 0 else {
            return transforms
        }
        
        let transformDataSize = MemoryLayout<TransformData>.stride * transforms.count
        
        guard let inputBuffer = device.makeBuffer(length: transformDataSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: transformDataSize, options: .storageModeShared),
              let deltaTimeBuffer = device.makeBuffer(bytes: [deltaTime], length: MemoryLayout<Float>.size, options: .storageModeShared) else {
            return transforms
        }
        
        // Convert SwiftUI components to Metal-compatible format
        let transformData = transforms.map { transform in
            TransformData(
                position: transform.position,
                rotation: transform.rotation,
                scale: transform.scale,
                velocity: SIMD3<Float>(0, 0, 0), // Would be part of velocity component
                padding: 0
            )
        }
        
        inputBuffer.contents().copyMemory(from: transformData, byteCount: transformDataSize)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return transforms
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(deltaTimeBuffer, offset: 0, index: 2)
        
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let groupCount = MTLSize(width: (transforms.count + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupCount, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Convert back to TransformComponent format
        let resultPointer = outputBuffer.contents().bindMemory(to: TransformData.self, capacity: transforms.count)
        let resultData = Array(UnsafeBufferPointer(start: resultPointer, count: transforms.count))
        
        return resultData.map { data in
            TransformComponent(
                position: data.position,
                rotation: data.rotation,
                scale: data.scale
            )
        }
    }
    
    /// Process physics components using Metal compute shaders
    public func processPhysics(_ physicsData: [ShipPhysicsData], weather: [WeatherData], oceanCurrents: [OceanCurrentData], deltaTime: Float) -> [ShipPhysicsData] {
        guard let pipeline = physicsPipeline,
              physicsData.count > 0 else {
            return physicsData
        }
        
        let physicsDataSize = MemoryLayout<ShipPhysicsData>.stride * physicsData.count
        let weatherDataSize = MemoryLayout<WeatherData>.stride * weather.count
        let currentDataSize = MemoryLayout<OceanCurrentData>.stride * oceanCurrents.count
        
        guard let physicsBuffer = device.makeBuffer(bytes: physicsData, length: physicsDataSize, options: .storageModeShared),
              let weatherBuffer = device.makeBuffer(bytes: weather, length: weatherDataSize, options: .storageModeShared),
              let currentBuffer = device.makeBuffer(bytes: oceanCurrents, length: currentDataSize, options: .storageModeShared),
              let deltaTimeBuffer = device.makeBuffer(bytes: [deltaTime], length: MemoryLayout<Float>.size, options: .storageModeShared),
              let countBuffer = device.makeBuffer(bytes: [UInt32(physicsData.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return physicsData
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return physicsData
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(physicsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(weatherBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(currentBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(deltaTimeBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 4)
        
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let groupCount = MTLSize(width: (physicsData.count + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupCount, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let resultPointer = physicsBuffer.contents().bindMemory(to: ShipPhysicsData.self, capacity: physicsData.count)
        return Array(UnsafeBufferPointer(start: resultPointer, count: physicsData.count))
    }
    
    /// Process AI decisions using Metal compute shaders
    public func processAIDecisions(_ aiStates: [AIStateData], marketData: [Float]) -> [Float] {
        guard let pipeline = aiDecisionPipeline,
              aiStates.count > 0 else {
            return Array(repeating: 0.0, count: aiStates.count)
        }
        
        let aiDataSize = MemoryLayout<AIStateData>.stride * aiStates.count
        let marketDataSize = MemoryLayout<Float>.stride * marketData.count
        let decisionsSize = MemoryLayout<Float>.stride * aiStates.count
        
        guard let aiBuffer = device.makeBuffer(bytes: aiStates, length: aiDataSize, options: .storageModeShared),
              let marketBuffer = device.makeBuffer(bytes: marketData, length: marketDataSize, options: .storageModeShared),
              let decisionsBuffer = device.makeBuffer(length: decisionsSize, options: .storageModeShared),
              let countBuffer = device.makeBuffer(bytes: [UInt32(aiStates.count)], length: MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            return Array(repeating: 0.0, count: aiStates.count)
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return Array(repeating: 0.0, count: aiStates.count)
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(aiBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(marketBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(decisionsBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 3)
        
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let groupCount = MTLSize(width: (aiStates.count + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(groupCount, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let resultPointer = decisionsBuffer.contents().bindMemory(to: Float.self, capacity: aiStates.count)
        return Array(UnsafeBufferPointer(start: resultPointer, count: aiStates.count))
    }
    
    /// Batch process multiple ECS operations in parallel
    public func processBatch(operations: [MetalECSOperation], completion: @escaping ([MetalECSResult]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results: [MetalECSResult] = []
        results.reserveCapacity(operations.count)
        
        for (index, operation) in operations.enumerated() {
            dispatchGroup.enter()
            
            DispatchQueue.global(qos: .userInteractive).async {
                let result = self.processOperation(operation, index: index)
                
                DispatchQueue.main.async {
                    results.append(result)
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(results.sorted { $0.index < $1.index })
        }
    }
    
    private func processOperation(_ operation: MetalECSOperation, index: Int) -> MetalECSResult {
        switch operation.type {
        case .transform:
            // Process transform operation
            return MetalECSResult(index: index, type: .transform, data: nil)
        case .physics:
            // Process physics operation
            return MetalECSResult(index: index, type: .physics, data: nil)
        case .ai:
            // Process AI operation
            return MetalECSResult(index: index, type: .ai, data: nil)
        case .economic:
            // Process economic operation
            return MetalECSResult(index: index, type: .economic, data: nil)
        }
    }
    
    /// Get Metal device capabilities for optimization
    public func getCapabilities() -> MetalCapabilities {
        return MetalCapabilities(
            supportsNonUniformThreadgroups: device.supportsFeatureSet(.iOS_GPUFamily4_v1),
            maxThreadgroupMemory: device.maxThreadgroupMemoryLength,
            maxThreadsPerThreadgroup: device.maxThreadsPerThreadgroup,
            recommendedThreadgroupSize: 64
        )
    }
}

// MARK: - Supporting Data Structures

/// Metal-compatible transform data structure
public struct TransformData {
    var position: SIMD3<Float>
    var rotation: SIMD4<Float>
    var scale: SIMD3<Float>
    var velocity: SIMD3<Float>
    var padding: Float
}

/// AI state data for Metal processing
public struct AIStateData {
    var money: Float
    var reputation: Float
    var riskTolerance: Float
    var learningRate: Float
}

/// Metal ECS operation types
public enum MetalECSOperationType {
    case transform
    case physics
    case ai
    case economic
}

/// Metal ECS operation
public struct MetalECSOperation {
    let type: MetalECSOperationType
    let data: Any
    let entityCount: Int
}

/// Metal ECS result
public struct MetalECSResult {
    let index: Int
    let type: MetalECSOperationType
    let data: Any?
}

/// Metal device capabilities
public struct MetalCapabilities {
    let supportsNonUniformThreadgroups: Bool
    let maxThreadgroupMemory: Int
    let maxThreadsPerThreadgroup: MTLSize
    let recommendedThreadgroupSize: Int
}