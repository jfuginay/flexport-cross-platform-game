import Foundation

/// Handles lag compensation for smooth multiplayer gameplay
class LagCompensationSystem {
    
    // Time synchronization
    private var serverTimeOffset: TimeInterval = 0
    private var timeSyncSamples: [TimeInterval] = []
    private let maxSyncSamples = 10
    
    // Interpolation settings
    private let interpolationDelay: TimeInterval = 0.1 // 100ms
    private let extrapolationLimit: TimeInterval = 0.2 // 200ms
    
    // History buffers
    private var stateHistory: [TimestampedState] = []
    private let historyDuration: TimeInterval = 2.0 // Keep 2 seconds of history
    
    // MARK: - Action Compensation
    
    /// Compensate for client latency when processing actions
    func compensate(action: GameAction, clientLatency: TimeInterval, serverTime: Date) -> GameAction {
        // Calculate when the action actually happened on the client
        let actualActionTime = serverTime.addingTimeInterval(-clientLatency)
        
        // Create compensated action with adjusted timestamp
        var compensatedAction = action
        compensatedAction.timestamp = actualActionTime
        
        // Adjust position-based actions for movement prediction
        if action.actionType == "move_ship" {
            compensatedAction = compensateMovement(action: compensatedAction, latency: clientLatency)
        }
        
        return compensatedAction
    }
    
    /// Compensate for movement during latency
    private func compensateMovement(action: GameAction, latency: TimeInterval) -> GameAction {
        var compensated = action
        
        // Extract movement parameters
        guard let targetX = action.parameters["targetX"]?.value as? Double,
              let targetY = action.parameters["targetY"]?.value as? Double,
              let velocity = action.parameters["velocity"]?.value as? Double else {
            return action
        }
        
        // Extrapolate position based on velocity and latency
        let extrapolationTime = min(latency, extrapolationLimit)
        let deltaX = velocity * cos(action.parameters["heading"]?.value as? Double ?? 0) * extrapolationTime
        let deltaY = velocity * sin(action.parameters["heading"]?.value as? Double ?? 0) * extrapolationTime
        
        // Update target position
        compensated.parameters["targetX"] = AnyCodable(targetX + deltaX)
        compensated.parameters["targetY"] = AnyCodable(targetY + deltaY)
        
        return compensated
    }
    
    // MARK: - Time Synchronization
    
    /// Synchronize client time with server time
    func syncTime(clientTime: Date, serverTime: Date, roundTripTime: TimeInterval) {
        // Calculate one-way latency (assuming symmetric)
        let oneWayLatency = roundTripTime / 2.0
        
        // Calculate time offset
        let offset = serverTime.timeIntervalSince(clientTime) - oneWayLatency
        
        // Add to samples
        timeSyncSamples.append(offset)
        if timeSyncSamples.count > maxSyncSamples {
            timeSyncSamples.removeFirst()
        }
        
        // Update server time offset (use median for stability)
        serverTimeOffset = calculateMedian(timeSyncSamples)
    }
    
    /// Get synchronized server time
    func getServerTime() -> Date {
        return Date().addingTimeInterval(serverTimeOffset)
    }
    
    /// Convert client time to server time
    func clientToServerTime(_ clientTime: Date) -> Date {
        return clientTime.addingTimeInterval(serverTimeOffset)
    }
    
    /// Convert server time to client time
    func serverToClientTime(_ serverTime: Date) -> Date {
        return serverTime.addingTimeInterval(-serverTimeOffset)
    }
    
    // MARK: - State History
    
    /// Record state for historical lookup
    func recordState(_ state: GameState, at serverTime: Date) {
        let timestampedState = TimestampedState(
            timestamp: serverTime,
            state: state
        )
        
        stateHistory.append(timestampedState)
        
        // Clean old history
        let cutoffTime = serverTime.addingTimeInterval(-historyDuration)
        stateHistory.removeAll { $0.timestamp < cutoffTime }
    }
    
    /// Get interpolated state at a specific time
    func getStateAt(serverTime: Date) -> GameState? {
        // Find surrounding states
        guard let beforeState = stateHistory.last(where: { $0.timestamp <= serverTime }),
              let afterState = stateHistory.first(where: { $0.timestamp > serverTime }) else {
            // Return extrapolated state if needed
            return getExtrapolatedState(at: serverTime)
        }
        
        // Interpolate between states
        return interpolateStates(
            before: beforeState,
            after: afterState,
            at: serverTime
        )
    }
    
    /// Rewind to a specific time for lag compensation
    func rewindTo(serverTime: Date) -> GameState? {
        return getStateAt(serverTime: serverTime)
    }
    
    // MARK: - Interpolation
    
    private func interpolateStates(before: TimestampedState, after: TimestampedState, at time: Date) -> GameState {
        let totalDuration = after.timestamp.timeIntervalSince(before.timestamp)
        let elapsed = time.timeIntervalSince(before.timestamp)
        let t = Float(elapsed / totalDuration)
        
        // Create interpolated state
        let interpolated = before.state.copy()
        
        // Interpolate entity positions
        for (entityId, beforeEntity) in before.state.entities {
            if let afterEntity = after.state.entities[entityId] {
                let interpolatedPosition = simd_mix(
                    beforeEntity.position,
                    afterEntity.position,
                    SIMD2<Float>(repeating: t)
                )
                interpolated.entities[entityId]?.position = interpolatedPosition
            }
        }
        
        return interpolated
    }
    
    private func getExtrapolatedState(at time: Date) -> GameState? {
        guard let lastState = stateHistory.last else { return nil }
        
        let timeDelta = time.timeIntervalSince(lastState.timestamp)
        
        // Don't extrapolate too far into the future
        if timeDelta > extrapolationLimit {
            return lastState.state
        }
        
        // Extrapolate based on velocity
        let extrapolated = lastState.state.copy()
        
        // Extrapolate entity positions
        for (entityId, entity) in extrapolated.entities {
            if let velocity = entity.velocity {
                let deltaPosition = velocity * Float(timeDelta)
                extrapolated.entities[entityId]?.position += deltaPosition
            }
        }
        
        return extrapolated
    }
    
    // MARK: - Helper Methods
    
    private func calculateMedian(_ values: [TimeInterval]) -> TimeInterval {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count == 0 {
            return 0
        } else if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2.0
        } else {
            return sorted[count/2]
        }
    }
}

// MARK: - Client Prediction

class ClientPredictionSystem {
    
    private var predictedStates: [PredictedState] = []
    private var confirmedStateVersion: Int = 0
    private let predictionLimit = 50 // Maximum number of predicted states
    
    /// Apply client-side prediction
    func predict(action: GameAction, currentState: GameState) -> GameState {
        // Create predicted state
        let predicted = currentState.copy()
        let result = predicted.applyAction(action)
        
        if result.success {
            // Store prediction for later reconciliation
            let predictionId = UUID().uuidString
            let predictedState = PredictedState(
                id: predictionId,
                action: action,
                resultState: predicted,
                timestamp: Date()
            )
            
            predictedStates.append(predictedState)
            
            // Limit prediction buffer size
            if predictedStates.count > predictionLimit {
                predictedStates.removeFirst()
            }
            
            return predicted
        }
        
        return currentState
    }
    
    /// Reconcile predictions with server state
    func reconcile(serverState: GameState, serverStateVersion: Int) {
        // Remove predictions that have been confirmed
        predictedStates.removeAll { prediction in
            prediction.timestamp < serverState.timestamp
        }
        
        confirmedStateVersion = serverStateVersion
        
        // Re-apply remaining predictions on top of server state
        var reconciledState = serverState
        
        for prediction in predictedStates {
            let result = reconciledState.applyAction(prediction.action)
            if !result.success {
                // Prediction was invalid, remove it
                predictedStates.removeAll { $0.id == prediction.id }
            }
        }
    }
    
    /// Check if a prediction matches server result
    func validatePrediction(action: GameAction, serverResult: GameState) -> Bool {
        guard let prediction = predictedStates.first(where: { $0.action.id == action.id }) else {
            return false
        }
        
        // Compare predicted state with server result
        return prediction.resultState.checksum == serverResult.checksum
    }
}

// MARK: - Client Prediction Validator (Server-side)

class ClientPredictionValidator {
    
    private let tolerance: Float = 0.1 // Position tolerance for validation
    
    /// Validate client prediction against server state
    func validate(action: GameAction, room: GameRoom) -> Bool {
        // Check action timestamp is reasonable
        let now = Date()
        let actionAge = now.timeIntervalSince(action.timestamp)
        
        // Reject actions that are too old or in the future
        if actionAge > 2.0 || actionAge < -0.5 {
            return false
        }
        
        // Validate based on action type
        switch action.actionType {
        case "move_ship":
            return validateMovement(action: action, room: room)
        case "buy_cargo", "sell_cargo":
            return validateTransaction(action: action, room: room)
        default:
            return true
        }
    }
    
    private func validateMovement(action: GameAction, room: GameRoom) -> Bool {
        guard let shipId = action.parameters["shipId"]?.value as? String,
              let targetX = action.parameters["targetX"]?.value as? Double,
              let targetY = action.parameters["targetY"]?.value as? Double else {
            return false
        }
        
        // Check if movement is within reasonable bounds
        let targetPosition = SIMD2<Float>(Float(targetX), Float(targetY))
        
        // Verify ship exists and belongs to player
        guard let ship = room.gameState.getEntity(shipId),
              ship.ownerId == action.playerId else {
            return false
        }
        
        // Check movement speed is realistic
        let distance = simd_distance(ship.position, targetPosition)
        let maxSpeed: Float = 50.0 // units per second
        let timeDelta = Date().timeIntervalSince(action.timestamp)
        let maxDistance = maxSpeed * Float(timeDelta)
        
        return distance <= maxDistance + tolerance
    }
    
    private func validateTransaction(action: GameAction, room: GameRoom) -> Bool {
        guard let playerId = action.parameters["playerId"]?.value as? String,
              let quantity = action.parameters["quantity"]?.value as? Int else {
            return false
        }
        
        // Verify player exists
        guard let playerState = room.gameState.getPlayerState(playerId) else {
            return false
        }
        
        // Check transaction limits
        if action.actionType == "buy_cargo" {
            let commodity = action.parameters["commodity"]?.value as? String ?? ""
            let price = room.gameState.marketState.getPrice(for: commodity) * Double(quantity)
            return playerState.money >= price
        }
        
        return true
    }
}

// MARK: - Supporting Types

struct TimestampedState {
    let timestamp: Date
    let state: GameState
}

struct PredictedState {
    let id: String
    let action: GameAction
    let resultState: GameState
    let timestamp: Date
}

// MARK: - Extensions

extension GameState {
    var timestamp: Date {
        return Date() // Would be properly implemented with state timestamps
    }
    
    var checksum: String {
        // Simple checksum implementation
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        return data.base64EncodedString().suffix(8).description
    }
    
    var entities: [String: Entity] {
        get { return [:] } // Would be properly implemented
        set { }
    }
    
    func getEntity(_ id: String) -> Entity? {
        return entities[id]
    }
    
    func getPlayerState(_ playerId: String) -> PlayerGameState? {
        return nil // Would be properly implemented
    }
    
    var marketState: MarketState {
        return MarketState()
    }
}

extension GameAction {
    var id: String {
        return parameters["actionId"]?.value as? String ?? UUID().uuidString
    }
    
    var timestamp: Date {
        return Date() // Would be extracted from action data
    }
}

extension Entity {
    var velocity: SIMD2<Float>? {
        // Would be extracted from physics component
        return nil
    }