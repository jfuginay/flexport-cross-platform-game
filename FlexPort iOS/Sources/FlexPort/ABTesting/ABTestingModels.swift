import Foundation

// MARK: - A/B Testing Models

/// A/B test experiment configuration
public struct ABTestExperiment: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let variants: [TestVariant]
    public let targetMetric: MetricType
    public let trafficAllocation: Double // Percentage of users to include (0.0 to 1.0)
    public let status: ExperimentStatus
    public let configuration: ExperimentConfiguration
    public let segmentation: PlayerSegmentation?
    public let createdDate: Date
    public var startDate: Date?
    public var endDate: Date?
    public var results: ExperimentResults?
    
    public init(name: String, description: String, variants: [TestVariant], 
                targetMetric: MetricType, trafficAllocation: Double = 1.0,
                configuration: ExperimentConfiguration = ExperimentConfiguration(),
                segmentation: PlayerSegmentation? = nil) {
        self.name = name
        self.description = description
        self.variants = variants
        self.targetMetric = targetMetric
        self.trafficAllocation = min(1.0, max(0.0, trafficAllocation))
        self.status = .draft
        self.configuration = configuration
        self.segmentation = segmentation
        self.createdDate = Date()
    }
    
    public var isActive: Bool {
        status == .running && 
        (startDate?.timeIntervalSinceNow ?? 0) <= 0 &&
        (endDate?.timeIntervalSinceNow ?? 0) >= 0
    }
    
    public var duration: TimeInterval? {
        guard let start = startDate, let end = endDate else { return nil }
        return end.timeIntervalSince(start)
    }
}

/// Individual test variant within an experiment
public struct TestVariant: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let weight: Double // Allocation weight (0.0 to 1.0)
    public let parameters: [String: ABTestValue]
    public let isControl: Bool
    public var participants: Set<UUID> = []
    public var metrics: VariantMetrics = VariantMetrics()
    
    public init(name: String, description: String, weight: Double = 0.5, 
                parameters: [String: ABTestValue] = [:], isControl: Bool = false) {
        self.name = name
        self.description = description
        self.weight = min(1.0, max(0.0, weight))
        self.parameters = parameters
        self.isControl = isControl
    }
    
    public var participantCount: Int {
        participants.count
    }
}

/// Type-safe value wrapper for A/B test parameters
public enum ABTestValue: Codable, Equatable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([ABTestValue])
    case dictionary([String: ABTestValue])
    
    public var rawValue: Any {
        switch self {
        case .string(let value): return value
        case .integer(let value): return value
        case .double(let value): return value
        case .boolean(let value): return value
        case .array(let values): return values.map { $0.rawValue }
        case .dictionary(let dict): return dict.mapValues { $0.rawValue }
        }
    }
    
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    public var intValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
}

/// Metrics that experiments are designed to optimize
public enum MetricType: String, Codable, CaseIterable {
    // Engagement metrics
    case sessionDuration = "session_duration"
    case sessionFrequency = "session_frequency"
    case screenTime = "screen_time"
    case featureUsage = "feature_usage"
    
    // Retention metrics
    case dayOneRetention = "day_1_retention"
    case daySevenRetention = "day_7_retention"
    case dayThirtyRetention = "day_30_retention"
    
    // Monetization metrics
    case conversionRate = "conversion_rate"
    case revenuePerUser = "revenue_per_user"
    case purchaseFrequency = "purchase_frequency"
    case averageOrderValue = "average_order_value"
    
    // Gameplay metrics
    case tutorialCompletion = "tutorial_completion"
    case levelProgression = "level_progression"
    case achievementUnlocks = "achievement_unlocks"
    
    // Social metrics
    case allianceParticipation = "alliance_participation"
    case playerInteractions = "player_interactions"
    case socialFeatureUsage = "social_feature_usage"
    
    // Performance metrics
    case crashRate = "crash_rate"
    case loadTime = "load_time"
    case errorRate = "error_rate"
    
    public var displayName: String {
        switch self {
        case .sessionDuration: return "Session Duration"
        case .sessionFrequency: return "Session Frequency"
        case .screenTime: return "Screen Time"
        case .featureUsage: return "Feature Usage"
        case .dayOneRetention: return "Day 1 Retention"
        case .daySevenRetention: return "Day 7 Retention"
        case .dayThirtyRetention: return "Day 30 Retention"
        case .conversionRate: return "Conversion Rate"
        case .revenuePerUser: return "Revenue per User"
        case .purchaseFrequency: return "Purchase Frequency"
        case .averageOrderValue: return "Average Order Value"
        case .tutorialCompletion: return "Tutorial Completion"
        case .levelProgression: return "Level Progression"
        case .achievementUnlocks: return "Achievement Unlocks"
        case .allianceParticipation: return "Alliance Participation"
        case .playerInteractions: return "Player Interactions"
        case .socialFeatureUsage: return "Social Feature Usage"
        case .crashRate: return "Crash Rate"
        case .loadTime: return "Load Time"
        case .errorRate: return "Error Rate"
        }
    }
}

/// Experiment status lifecycle
public enum ExperimentStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case approved = "approved"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    public var canStart: Bool {
        self == .approved || self == .paused
    }
    
    public var canPause: Bool {
        self == .running
    }
    
    public var canComplete: Bool {
        self == .running || self == .paused
    }
}

/// Configuration options for experiments
public struct ExperimentConfiguration: Codable {
    public var minimumSampleSize: Int
    public var maximumDuration: TimeInterval
    public var confidenceLevel: Double
    public var statisticalPower: Double
    public var minimumDetectableEffect: Double
    public var earlyStoppingEnabled: Bool
    public var monitoringInterval: TimeInterval
    public var allowOverlap: Bool
    
    public init(minimumSampleSize: Int = 1000,
                maximumDuration: TimeInterval = 30 * 24 * 3600, // 30 days
                confidenceLevel: Double = 0.95,
                statisticalPower: Double = 0.8,
                minimumDetectableEffect: Double = 0.05,
                earlyStoppingEnabled: Bool = false,
                monitoringInterval: TimeInterval = 24 * 3600, // Daily
                allowOverlap: Bool = false) {
        self.minimumSampleSize = minimumSampleSize
        self.maximumDuration = maximumDuration
        self.confidenceLevel = confidenceLevel
        self.statisticalPower = statisticalPower
        self.minimumDetectableEffect = minimumDetectableEffect
        self.earlyStoppingEnabled = earlyStoppingEnabled
        self.monitoringInterval = monitoringInterval
        self.allowOverlap = allowOverlap
    }
}

/// Player segmentation criteria for targeted experiments
public struct PlayerSegmentation: Codable {
    public let segments: [SegmentCriteria]
    public let operator: SegmentOperator
    
    public init(segments: [SegmentCriteria], operator: SegmentOperator = .and) {
        self.segments = segments
        self.operator = operator
    }
    
    public func matches(profile: PlayerBehaviorProfile) -> Bool {
        switch operator {
        case .and:
            return segments.allSatisfy { $0.matches(profile: profile) }
        case .or:
            return segments.contains { $0.matches(profile: profile) }
        case .not:
            return !segments.allSatisfy { $0.matches(profile: profile) }
        }
    }
}

public enum SegmentOperator: String, Codable {
    case and = "and"
    case or = "or"
    case not = "not"
}

public struct SegmentCriteria: Codable, Identifiable {
    public let id = UUID()
    public let criteriaType: SegmentCriteriaType
    public let operator: ComparisonOperator
    public let value: ABTestValue
    public let description: String
    
    public init(criteriaType: SegmentCriteriaType, operator: ComparisonOperator, 
                value: ABTestValue, description: String) {
        self.criteriaType = criteriaType
        self.operator = operator
        self.value = value
        self.description = description
    }
    
    public func matches(profile: PlayerBehaviorProfile) -> Bool {
        let profileValue = criteriaType.getValue(from: profile)
        return operator.compare(profileValue, to: value)
    }
}

public enum SegmentCriteriaType: String, Codable {
    case totalSessions = "total_sessions"
    case totalPlayTime = "total_play_time"
    case averageSessionDuration = "average_session_duration"
    case sessionFrequency = "session_frequency"
    case gameplayStyle = "gameplay_style"
    case spendingBehavior = "spending_behavior"
    case retentionRisk = "retention_risk"
    case daysSinceLastActive = "days_since_last_active"
    
    public func getValue(from profile: PlayerBehaviorProfile) -> ABTestValue {
        switch self {
        case .totalSessions:
            return .integer(profile.totalSessions)
        case .totalPlayTime:
            return .double(profile.totalPlayTime)
        case .averageSessionDuration:
            return .double(profile.averageSessionDuration)
        case .sessionFrequency:
            return .string(profile.sessionFrequency.rawValue)
        case .gameplayStyle:
            return .string(profile.gameplayStyle.rawValue)
        case .spendingBehavior:
            return .string(profile.spendingBehavior.rawValue)
        case .retentionRisk:
            return .string(profile.retentionRisk.rawValue)
        case .daysSinceLastActive:
            let days = Date().timeIntervalSince(profile.lastActive) / 86400
            return .double(days)
        }
    }
}

public enum ComparisonOperator: String, Codable {
    case equals = "equals"
    case notEquals = "not_equals"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThanOrEqual = "less_than_or_equal"
    case contains = "contains"
    case notContains = "not_contains"
    
    public func compare(_ left: ABTestValue, to right: ABTestValue) -> Bool {
        switch (left, right) {
        case (.integer(let l), .integer(let r)):
            return compareIntegers(l, r)
        case (.double(let l), .double(let r)):
            return compareDoubles(l, r)
        case (.string(let l), .string(let r)):
            return compareStrings(l, r)
        case (.boolean(let l), .boolean(let r)):
            return compareBooleans(l, r)
        default:
            return false
        }
    }
    
    private func compareIntegers(_ left: Int, _ right: Int) -> Bool {
        switch self {
        case .equals: return left == right
        case .notEquals: return left != right
        case .greaterThan: return left > right
        case .lessThan: return left < right
        case .greaterThanOrEqual: return left >= right
        case .lessThanOrEqual: return left <= right
        default: return false
        }
    }
    
    private func compareDoubles(_ left: Double, _ right: Double) -> Bool {
        switch self {
        case .equals: return abs(left - right) < 0.001
        case .notEquals: return abs(left - right) >= 0.001
        case .greaterThan: return left > right
        case .lessThan: return left < right
        case .greaterThanOrEqual: return left >= right
        case .lessThanOrEqual: return left <= right
        default: return false
        }
    }
    
    private func compareStrings(_ left: String, _ right: String) -> Bool {
        switch self {
        case .equals: return left == right
        case .notEquals: return left != right
        case .contains: return left.contains(right)
        case .notContains: return !left.contains(right)
        default: return false
        }
    }
    
    private func compareBooleans(_ left: Bool, _ right: Bool) -> Bool {
        switch self {
        case .equals: return left == right
        case .notEquals: return left != right
        default: return false
        }
    }
}

/// Metrics collected for each variant
public struct VariantMetrics: Codable {
    public var participantCount: Int = 0
    public var conversionCount: Int = 0
    public var totalRevenue: Double = 0.0
    public var totalSessionDuration: TimeInterval = 0.0
    public var totalSessions: Int = 0
    public var retainedUsers: [Int: Int] = [:] // Day -> Count
    public var customMetrics: [String: Double] = [:]
    
    public init() {}
    
    public var conversionRate: Double {
        guard participantCount > 0 else { return 0.0 }
        return Double(conversionCount) / Double(participantCount)
    }
    
    public var revenuePerUser: Double {
        guard participantCount > 0 else { return 0.0 }
        return totalRevenue / Double(participantCount)
    }
    
    public var averageSessionDuration: TimeInterval {
        guard totalSessions > 0 else { return 0.0 }
        return totalSessionDuration / Double(totalSessions)
    }
    
    public func retentionRate(day: Int) -> Double {
        guard participantCount > 0 else { return 0.0 }
        let retained = retainedUsers[day] ?? 0
        return Double(retained) / Double(participantCount)
    }
}

/// Results and statistical analysis of an experiment
public struct ExperimentResults: Codable {
    public let experimentId: UUID
    public let completionDate: Date
    public let totalParticipants: Int
    public let variantResults: [UUID: VariantResults]
    public let statisticalSignificance: StatisticalSignificance
    public let recommendation: ExperimentRecommendation
    public let confidence: Double
    public let summary: String
    
    public init(experimentId: UUID, totalParticipants: Int, 
                variantResults: [UUID: VariantResults],
                statisticalSignificance: StatisticalSignificance,
                recommendation: ExperimentRecommendation,
                confidence: Double, summary: String) {
        self.experimentId = experimentId
        self.completionDate = Date()
        self.totalParticipants = totalParticipants
        self.variantResults = variantResults
        self.statisticalSignificance = statisticalSignificance
        self.recommendation = recommendation
        self.confidence = confidence
        self.summary = summary
    }
}

public struct VariantResults: Codable {
    public let variantId: UUID
    public let variantName: String
    public let participantCount: Int
    public let primaryMetricValue: Double
    public let primaryMetricImprovement: Double // Percentage improvement over control
    public let secondaryMetrics: [String: Double]
    public let confidenceInterval: ConfidenceInterval
    
    public init(variantId: UUID, variantName: String, participantCount: Int,
                primaryMetricValue: Double, primaryMetricImprovement: Double,
                secondaryMetrics: [String: Double] = [:],
                confidenceInterval: ConfidenceInterval) {
        self.variantId = variantId
        self.variantName = variantName
        self.participantCount = participantCount
        self.primaryMetricValue = primaryMetricValue
        self.primaryMetricImprovement = primaryMetricImprovement
        self.secondaryMetrics = secondaryMetrics
        self.confidenceInterval = confidenceInterval
    }
}

public struct ConfidenceInterval: Codable {
    public let lowerBound: Double
    public let upperBound: Double
    public let confidenceLevel: Double
    
    public init(lowerBound: Double, upperBound: Double, confidenceLevel: Double) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.confidenceLevel = confidenceLevel
    }
    
    public var width: Double {
        upperBound - lowerBound
    }
    
    public var includesZero: Bool {
        lowerBound <= 0 && upperBound >= 0
    }
}

public enum StatisticalSignificance: String, Codable {
    case significant = "significant"
    case notSignificant = "not_significant"
    case inconclusive = "inconclusive"
    case underpowered = "underpowered"
    
    public var description: String {
        switch self {
        case .significant:
            return "Results are statistically significant"
        case .notSignificant:
            return "Results are not statistically significant"
        case .inconclusive:
            return "Results are inconclusive"
        case .underpowered:
            return "Experiment was underpowered to detect differences"
        }
    }
}

public enum ExperimentRecommendation: String, Codable {
    case adoptTreatment = "adopt_treatment"
    case keepControl = "keep_control"
    case runLonger = "run_longer"
    case redesignExperiment = "redesign_experiment"
    case noRecommendation = "no_recommendation"
    
    public var description: String {
        switch self {
        case .adoptTreatment:
            return "Adopt the treatment variant"
        case .keepControl:
            return "Keep the current control version"
        case .runLonger:
            return "Run the experiment longer for more data"
        case .redesignExperiment:
            return "Redesign the experiment with different parameters"
        case .noRecommendation:
            return "No clear recommendation"
        }
    }
}

/// Assignment record for tracking which users are in which experiments
public struct ExperimentAssignment: Codable {
    public let userId: UUID
    public let experimentId: UUID
    public let variantId: UUID
    public let assignmentDate: Date
    public let assignmentMethod: AssignmentMethod
    public var isActive: Bool
    
    public init(userId: UUID, experimentId: UUID, variantId: UUID, 
                assignmentMethod: AssignmentMethod = .random) {
        self.userId = userId
        self.experimentId = experimentId
        self.variantId = variantId
        self.assignmentDate = Date()
        self.assignmentMethod = assignmentMethod
        self.isActive = true
    }
}

public enum AssignmentMethod: String, Codable {
    case random = "random"
    case deterministic = "deterministic"
    case manual = "manual"
}