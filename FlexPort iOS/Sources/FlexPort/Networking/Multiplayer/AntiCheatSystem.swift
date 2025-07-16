import Foundation
import CryptoKit

/// Comprehensive anti-cheat system for multiplayer integrity
class AntiCheatSystem {
    
    // Detection thresholds
    private let maxActionsPerSecond: Double = 10.0
    private let maxMovementSpeed: Float = 100.0 // units per second
    private let maxTransactionAmount: Double = 10_000_000.0
    private let suspiciousPatternThreshold = 5 // Violations before ban
    
    // Tracking
    private var playerViolations: [UUID: [Violation]] = [:]
    private var bannedPlayers: Set<UUID> = []
    private var suspiciousPatterns: [UUID: [SuspiciousPattern]] = [:]
    
    // Validation rules
    private let validationRules = ValidationRules()
    private let integrityChecker = IntegrityChecker()
    
    // Logging
    private let securityLog = SecurityLogger()
    
    // MARK: - Client Validation
    
    /// Validate client connection and authentication
    func validateClient(_ client: ClientConnection) -> Bool {
        // Check if banned
        if bannedPlayers.contains(client.id) {
            securityLog.log(.banned, playerId: client.id, reason: "Previously banned player")
            return false
        }
        
        // Validate client version
        guard validateClientVersion(client) else {
            recordViolation(client.id, type: .invalidVersion)
            return false
        }
        
        // Check authentication token
        guard validateAuthToken(client) else {
            recordViolation(client.id, type: .authenticationFailure)
            return false
        }
        
        return true
    }
    
    /// Validate incoming message
    func validateMessage(_ message: GameMessage, from client: ClientConnection) -> Bool {
        // Check message integrity
        guard integrityChecker.verifyMessage(message) else {
            recordViolation(client.id, type: .tamperedMessage)
            return false
        }
        
        // Check rate limiting
        guard checkRateLimit(client.id, message: message) else {
            recordViolation(client.id, type: .rateLimitExceeded)
            return false
        }
        
        // Validate based on message type
        switch message.payload {
        case .action(let action):
            return validateAction(action, from: client)
            
        case .stateUpdate(let update):
            return validateStateUpdate(update, from: client)
            
        default:
            return true
        }
    }
    
    // MARK: - Action Validation
    
    private func validateAction(_ action: GameAction, from client: ClientConnection) -> Bool {
        // Check action timestamp
        let timeDelta = abs(Date().timeIntervalSince(action.timestamp))
        if timeDelta > 5.0 { // Action is more than 5 seconds old or in future
            recordViolation(client.id, type: .invalidTimestamp)
            return false
        }
        
        // Validate based on action type
        switch action.actionType {
        case "move_ship":
            return validateMovementAction(action, from: client)
            
        case "buy_cargo", "sell_cargo":
            return validateTransactionAction(action, from: client)
            
        case "attack":
            return validateCombatAction(action, from: client)
            
        default:
            return validationRules.validateGenericAction(action)
        }
    }
    
    private func validateMovementAction(_ action: GameAction, from client: ClientConnection) -> Bool {
        guard let currentX = action.parameters["currentX"]?.value as? Double,
              let currentY = action.parameters["currentY"]?.value as? Double,
              let targetX = action.parameters["targetX"]?.value as? Double,
              let targetY = action.parameters["targetY"]?.value as? Double else {
            return false
        }
        
        let current = SIMD2<Float>(Float(currentX), Float(currentY))
        let target = SIMD2<Float>(Float(targetX), Float(targetY))
        let distance = simd_distance(current, target)
        
        // Check speed hack
        let timeSinceLastMove = getTimeSinceLastMove(client.id)
        let speed = distance / Float(timeSinceLastMove)
        
        if speed > maxMovementSpeed {
            recordViolation(client.id, type: .speedHack, severity: .high)
            detectPattern(client.id, pattern: .consistentSpeedHack)
            return false
        }
        
        // Check teleportation
        if distance > 1000.0 && timeSinceLastMove < 1.0 {
            recordViolation(client.id, type: .teleportation, severity: .critical)
            return false
        }
        
        return true
    }
    
    private func validateTransactionAction(_ action: GameAction, from client: ClientConnection) -> Bool {
        guard let amount = action.parameters["amount"]?.value as? Double else {
            return false
        }
        
        // Check for impossible amounts
        if amount > maxTransactionAmount || amount < 0 {
            recordViolation(client.id, type: .impossibleTransaction, severity: .high)
            return false
        }
        
        // Check for rapid transactions (possible dupe exploit)
        if isRapidTransaction(client.id) {
            recordViolation(client.id, type: .duplicationAttempt, severity: .critical)
            detectPattern(client.id, pattern: .rapidTransactions)
            return false
        }
        
        return true
    }
    
    private func validateCombatAction(_ action: GameAction, from client: ClientConnection) -> Bool {
        // Validate combat-specific rules
        guard let damage = action.parameters["damage"]?.value as? Double,
              let targetId = action.parameters["targetId"]?.value as? String else {
            return false
        }
        
        // Check for impossible damage values
        if damage > 10000.0 || damage < 0 {
            recordViolation(client.id, type: .impossibleDamage, severity: .high)
            return false
        }
        
        // Check for invalid targets
        if !isValidTarget(targetId, attacker: client.id) {
            recordViolation(client.id, type: .invalidTarget, severity: .medium)
            return false
        }
        
        return true
    }
    
    // MARK: - State Validation
    
    private func validateStateUpdate(_ update: GameStateUpdate, from client: ClientConnection) -> Bool {
        // Only certain clients can send state updates (e.g., room host)
        guard hasStateUpdatePermission(client) else {
            recordViolation(client.id, type: .unauthorizedStateUpdate, severity: .critical)
            return false
        }
        
        // Validate state consistency
        for (playerId, state) in update.playerStates {
            if state.money < 0 || state.reputation < 0 || state.reputation > 100 {
                recordViolation(client.id, type: .invalidStateValues, severity: .high)
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Pattern Detection
    
    private func detectPattern(_ playerId: UUID, pattern: SuspiciousPattern) {
        if suspiciousPatterns[playerId] == nil {
            suspiciousPatterns[playerId] = []
        }
        
        suspiciousPatterns[playerId]?.append(pattern)
        
        // Check if pattern threshold exceeded
        let patternCount = suspiciousPatterns[playerId]?.filter { $0 == pattern }.count ?? 0
        
        if patternCount >= 3 {
            // Escalate to ban
            banPlayer(playerId, reason: "Repeated suspicious pattern: \(pattern)")
        }
    }
    
    // MARK: - Violation Management
    
    private func recordViolation(_ playerId: UUID, type: ViolationType, severity: ViolationSeverity = .low) {
        let violation = Violation(
            type: type,
            severity: severity,
            timestamp: Date()
        )
        
        if playerViolations[playerId] == nil {
            playerViolations[playerId] = []
        }
        
        playerViolations[playerId]?.append(violation)
        
        // Log violation
        securityLog.log(.violation, playerId: playerId, reason: "\(type)")
        
        // Check if ban threshold reached
        let severityScore = calculateSeverityScore(playerId)
        if severityScore >= suspiciousPatternThreshold {
            banPlayer(playerId, reason: "Severity threshold exceeded")
        }
    }
    
    private func calculateSeverityScore(_ playerId: UUID) -> Int {
        let violations = playerViolations[playerId] ?? []
        
        return violations.reduce(0) { score, violation in
            switch violation.severity {
            case .low: return score + 1
            case .medium: return score + 2
            case .high: return score + 3
            case .critical: return score + 5
            }
        }
    }
    
    func banPlayer(_ playerId: UUID, reason: String) {
        bannedPlayers.insert(playerId)
        securityLog.log(.ban, playerId: playerId, reason: reason)
        
        // Notify game server to disconnect player
        NotificationCenter.default.post(
            name: .playerBanned,
            object: playerId,
            userInfo: ["reason": reason]
        )
    }
    
    // MARK: - Incident Logging
    
    func logIncident(clientId: UUID, reason: String) {
        securityLog.log(.incident, playerId: clientId, reason: reason)
    }
    
    // MARK: - Helper Methods
    
    private func validateClientVersion(_ client: ClientConnection) -> Bool {
        // Check client version compatibility
        return true // Simplified
    }
    
    private func validateAuthToken(_ client: ClientConnection) -> Bool {
        // Validate authentication token
        return true // Simplified
    }
    
    private func checkRateLimit(_ playerId: UUID, message: GameMessage) -> Bool {
        // Check message rate limits
        return true // Simplified
    }
    
    private func getTimeSinceLastMove(_ playerId: UUID) -> TimeInterval {
        // Get time since last movement action
        return 1.0 // Simplified
    }
    
    private func isRapidTransaction(_ playerId: UUID) -> Bool {
        // Check for rapid transaction pattern
        return false // Simplified
    }
    
    private func isValidTarget(_ targetId: String, attacker: UUID) -> Bool {
        // Validate combat target
        return true // Simplified
    }
    
    private func hasStateUpdatePermission(_ client: ClientConnection) -> Bool {
        // Check if client has permission to update state
        return true // Simplified
    }
}

// MARK: - Supporting Types

enum ViolationType {
    case invalidVersion
    case authenticationFailure
    case tamperedMessage
    case rateLimitExceeded
    case invalidTimestamp
    case speedHack
    case teleportation
    case impossibleTransaction
    case duplicationAttempt
    case impossibleDamage
    case invalidTarget
    case unauthorizedStateUpdate
    case invalidStateValues
}

enum ViolationSeverity {
    case low
    case medium
    case high
    case critical
}

struct Violation {
    let type: ViolationType
    let severity: ViolationSeverity
    let timestamp: Date
}

enum SuspiciousPattern: Equatable {
    case consistentSpeedHack
    case rapidTransactions
    case unusualWinRate
    case exploitAttempts
}

// MARK: - Validation Rules

class ValidationRules {
    
    func validateGenericAction(_ action: GameAction) -> Bool {
        // Generic validation rules
        guard !action.playerId.isEmpty else { return false }
        guard action.parameters.count <= 20 else { return false } // Prevent parameter flooding
        
        return true
    }
}

// MARK: - Integrity Checker

class IntegrityChecker {
    
    private let hashingKey = SymmetricKey(size: .bits256)
    
    func verifyMessage(_ message: GameMessage) -> Bool {
        // Verify message hasn't been tampered with
        // In production, would check cryptographic signature
        return true
    }
    
    func generateMessageHash(_ message: GameMessage) -> String {
        guard let data = try? JSONEncoder().encode(message) else {
            return ""
        }
        
        let hash = HMAC<SHA256>.authenticationCode(for: data, using: hashingKey)
        return Data(hash).base64EncodedString()
    }
}

// MARK: - Security Logger

class SecurityLogger {
    
    enum LogType {
        case violation
        case incident
        case ban
        case banned
    }
    
    private let logQueue = DispatchQueue(label: "security.logger", qos: .utility)
    private var logs: [SecurityLogEntry] = []
    
    func log(_ type: LogType, playerId: UUID, reason: String) {
        let entry = SecurityLogEntry(
            type: type,
            playerId: playerId,
            reason: reason,
            timestamp: Date()
        )
        
        logQueue.async {
            self.logs.append(entry)
            
            // In production, would persist to secure storage
            print("[SECURITY] \(type): Player \(playerId.uuidString) - \(reason)")
            
            // Keep only recent logs in memory
            if self.logs.count > 1000 {
                self.logs.removeFirst(100)
            }
        }
    }
    
    func getRecentLogs(for playerId: UUID? = nil, limit: Int = 100) -> [SecurityLogEntry] {
        return logQueue.sync {
            let filtered = playerId != nil ? logs.filter { $0.playerId == playerId } : logs
            return Array(filtered.suffix(limit))
        }
    }
}

struct SecurityLogEntry {
    let type: SecurityLogger.LogType
    let playerId: UUID
    let reason: String
    let timestamp: Date
}

// MARK: - Notifications

extension Notification.Name {
    static let playerBanned = Notification.Name("PlayerBanned")
}

// MARK: - Anti-Cheat Analytics

class AntiCheatAnalytics {
    
    private var detectionStats: [ViolationType: Int] = [:]
    private var banStats: [String: Int] = [:] // Reason to count
    
    func recordDetection(type: ViolationType) {
        detectionStats[type, default: 0] += 1
    }
    
    func recordBan(reason: String) {
        banStats[reason, default: 0] += 1
    }
    
    func getStatistics() -> AntiCheatStatistics {
        return AntiCheatStatistics(
            totalDetections: detectionStats.values.reduce(0, +),
            detectionsByType: detectionStats,
            totalBans: banStats.values.reduce(0, +),
            bansByReason: banStats
        )
    }
}

struct AntiCheatStatistics {
    let totalDetections: Int
    let detectionsByType: [ViolationType: Int]
    let totalBans: Int
    let bansByReason: [String: Int]
}