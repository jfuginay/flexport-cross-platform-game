import Foundation
import Combine
import os.log

/// Comprehensive A/B testing framework for feature optimization
@MainActor
public class ABTestingManager: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "ABTesting")
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var activeExperiments: [ABTestExperiment] = []
    @Published public private(set) var userAssignments: [UUID: [ExperimentAssignment]] = [:]
    @Published public private(set) var experimentResults: [UUID: ExperimentResults] = [:]
    
    private let analyticsEngine: AnalyticsEngine
    private let playerBehaviorAnalyzer: PlayerBehaviorAnalyzer
    private let statisticalAnalyzer: StatisticalAnalyzer
    private let assignmentStorage: AssignmentStorage
    
    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    public init(analyticsEngine: AnalyticsEngine, playerBehaviorAnalyzer: PlayerBehaviorAnalyzer) {
        self.analyticsEngine = analyticsEngine
        self.playerBehaviorAnalyzer = playerBehaviorAnalyzer
        self.statisticalAnalyzer = StatisticalAnalyzer()
        self.assignmentStorage = AssignmentStorage()
        
        setupExperimentMonitoring()
        loadActiveExperiments()
        logger.info("A/B Testing Manager initialized")
    }
    
    deinit {
        monitoringTimer?.invalidate()
    }
    
    // MARK: - Experiment Management
    
    /// Create a new A/B test experiment
    public func createExperiment(_ experiment: ABTestExperiment) {
        guard validateExperiment(experiment) else {
            logger.error("Failed to create experiment: validation failed")
            return
        }
        
        activeExperiments.append(experiment)
        logger.info("Created experiment: \(experiment.name)")
        
        analyticsEngine.trackEvent(.experimentViewed, parameters: [
            "experiment_id": .string(experiment.id.uuidString),
            "experiment_name": .string(experiment.name),
            "action": .string("created")
        ])
    }
    
    /// Start an experiment
    public func startExperiment(_ experimentId: UUID) {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            logger.error("Experiment not found: \(experimentId)")
            return
        }
        
        guard activeExperiments[index].status.canStart else {
            logger.warning("Cannot start experiment in current status: \(activeExperiments[index].status)")
            return
        }
        
        activeExperiments[index].status = .running
        activeExperiments[index].startDate = Date()
        
        // Set end date based on configuration
        let maxDuration = activeExperiments[index].configuration.maximumDuration
        activeExperiments[index].endDate = Date().addingTimeInterval(maxDuration)
        
        logger.info("Started experiment: \(activeExperiments[index].name)")
        
        analyticsEngine.trackEvent(.experimentViewed, parameters: [
            "experiment_id": .string(experimentId.uuidString),
            "action": .string("started")
        ])
    }
    
    /// Stop an experiment
    public func stopExperiment(_ experimentId: UUID, reason: String = "Manual stop") {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            logger.error("Experiment not found: \(experimentId)")
            return
        }
        
        guard activeExperiments[index].status.canComplete else {
            logger.warning("Cannot stop experiment in current status: \(activeExperiments[index].status)")
            return
        }
        
        // Analyze results before stopping
        let results = analyzeExperimentResults(activeExperiments[index])
        activeExperiments[index].results = results
        experimentResults[experimentId] = results
        
        activeExperiments[index].status = .completed
        activeExperiments[index].endDate = Date()
        
        logger.info("Stopped experiment: \(activeExperiments[index].name) - Reason: \(reason)")
        
        analyticsEngine.trackEvent(.experimentViewed, parameters: [
            "experiment_id": .string(experimentId.uuidString),
            "action": .string("stopped"),
            "reason": .string(reason)
        ])
    }
    
    // MARK: - User Assignment
    
    /// Get variant assignment for a user and experiment
    public func getVariant(for userId: UUID, experiment experimentId: UUID) -> TestVariant? {
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }) else {
            return nil
        }
        
        guard experiment.isActive else {
            return nil
        }
        
        // Check if user is already assigned
        if let assignment = getUserAssignment(userId: userId, experimentId: experimentId) {
            return experiment.variants.first { $0.id == assignment.variantId }
        }
        
        // Check if user qualifies for the experiment
        guard shouldIncludeUser(userId, in: experiment) else {
            return nil
        }
        
        // Assign user to a variant
        let variant = assignUserToVariant(userId: userId, experiment: experiment)
        
        analyticsEngine.trackEvent(.experimentViewed, parameters: [
            "experiment_id": .string(experimentId.uuidString),
            "variant_id": .string(variant.id.uuidString),
            "user_id": .string(userId.uuidString),
            "action": .string("assigned")
        ])
        
        return variant
    }
    
    /// Get all active experiments for a user
    public func getActiveExperiments(for userId: UUID) -> [ABTestExperiment] {
        return activeExperiments.filter { experiment in
            experiment.isActive && shouldIncludeUser(userId, in: experiment)
        }
    }
    
    /// Get variant parameter value
    public func getVariantValue<T>(_ key: String, for userId: UUID, experiment experimentId: UUID, defaultValue: T) -> T {
        guard let variant = getVariant(for: userId, experiment: experimentId) else {
            return defaultValue
        }
        
        guard let testValue = variant.parameters[key] else {
            return defaultValue
        }
        
        // Convert ABTestValue to expected type
        switch (testValue, T.self) {
        case (.string(let value), _ as String.Type):
            return value as! T
        case (.integer(let value), _ as Int.Type):
            return value as! T
        case (.double(let value), _ as Double.Type):
            return value as! T
        case (.boolean(let value), _ as Bool.Type):
            return value as! T
        default:
            return defaultValue
        }
    }
    
    // MARK: - Metrics Collection
    
    /// Record a conversion for a user in an experiment
    public func recordConversion(userId: UUID, experimentId: UUID, value: Double = 1.0) {
        guard let experimentIndex = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            return
        }
        
        guard let assignment = getUserAssignment(userId: userId, experimentId: experimentId) else {
            return
        }
        
        guard let variantIndex = activeExperiments[experimentIndex].variants.firstIndex(where: { $0.id == assignment.variantId }) else {
            return
        }
        
        activeExperiments[experimentIndex].variants[variantIndex].metrics.conversionCount += 1
        activeExperiments[experimentIndex].variants[variantIndex].metrics.totalRevenue += value
        
        analyticsEngine.trackEvent(.experimentInteraction, parameters: [
            "experiment_id": .string(experimentId.uuidString),
            "variant_id": .string(assignment.variantId.uuidString),
            "user_id": .string(userId.uuidString),
            "action": .string("conversion"),
            "value": .double(value)
        ])
    }
    
    /// Record a session for metrics calculation
    public func recordSession(userId: UUID, duration: TimeInterval) {
        let userAssignmentList = userAssignments[userId] ?? []
        
        for assignment in userAssignmentList.filter({ $0.isActive }) {
            guard let experimentIndex = activeExperiments.firstIndex(where: { $0.id == assignment.experimentId }) else {
                continue
            }
            
            guard let variantIndex = activeExperiments[experimentIndex].variants.firstIndex(where: { $0.id == assignment.variantId }) else {
                continue
            }
            
            activeExperiments[experimentIndex].variants[variantIndex].metrics.totalSessions += 1
            activeExperiments[experimentIndex].variants[variantIndex].metrics.totalSessionDuration += duration
        }
    }
    
    /// Record retention for a user
    public func recordRetention(userId: UUID, day: Int) {
        let userAssignmentList = userAssignments[userId] ?? []
        
        for assignment in userAssignmentList.filter({ $0.isActive }) {
            guard let experimentIndex = activeExperiments.firstIndex(where: { $0.id == assignment.experimentId }) else {
                continue
            }
            
            guard let variantIndex = activeExperiments[experimentIndex].variants.firstIndex(where: { $0.id == assignment.variantId }) else {
                continue
            }
            
            let currentCount = activeExperiments[experimentIndex].variants[variantIndex].metrics.retainedUsers[day] ?? 0
            activeExperiments[experimentIndex].variants[variantIndex].metrics.retainedUsers[day] = currentCount + 1
        }
    }
    
    // MARK: - Analysis and Reporting
    
    /// Get experiment results
    public func getExperimentResults(_ experimentId: UUID) -> ExperimentResults? {
        return experimentResults[experimentId]
    }
    
    /// Get real-time experiment statistics
    public func getExperimentStatistics(_ experimentId: UUID) -> ExperimentStatistics? {
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }) else {
            return nil
        }
        
        let totalParticipants = experiment.variants.reduce(0) { $0 + $1.participantCount }
        let variantStats = experiment.variants.map { variant in
            VariantStatistics(
                variantId: variant.id,
                variantName: variant.name,
                participantCount: variant.participantCount,
                conversionRate: variant.metrics.conversionRate,
                revenuePerUser: variant.metrics.revenuePerUser,
                averageSessionDuration: variant.metrics.averageSessionDuration
            )
        }
        
        return ExperimentStatistics(
            experimentId: experimentId,
            experimentName: experiment.name,
            status: experiment.status,
            totalParticipants: totalParticipants,
            duration: experiment.duration ?? 0,
            variantStatistics: variantStats
        )
    }
    
    // MARK: - Private Methods
    
    private func setupExperimentMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.monitorActiveExperiments()
            }
        }
    }
    
    private func monitorActiveExperiments() {
        for experiment in activeExperiments.filter({ $0.isActive }) {
            // Check if experiment should be stopped
            if shouldStopExperiment(experiment) {
                stopExperiment(experiment.id, reason: "Automatic stop - criteria met")
            }
            
            // Check for early stopping if enabled
            if experiment.configuration.earlyStoppingEnabled {
                if shouldStopEarly(experiment) {
                    stopExperiment(experiment.id, reason: "Early stop - statistical significance reached")
                }
            }
        }
    }
    
    private func shouldStopExperiment(_ experiment: ABTestExperiment) -> Bool {
        // Check if experiment has reached its end date
        if let endDate = experiment.endDate, Date() >= endDate {
            return true
        }
        
        // Check if minimum sample size is reached and enough time has passed
        let totalParticipants = experiment.variants.reduce(0) { $0 + $1.participantCount }
        if totalParticipants >= experiment.configuration.minimumSampleSize {
            if let startDate = experiment.startDate,
               Date().timeIntervalSince(startDate) >= experiment.configuration.monitoringInterval * 7 { // At least 7 monitoring periods
                return true
            }
        }
        
        return false
    }
    
    private func shouldStopEarly(_ experiment: ABTestExperiment) -> Bool {
        // Perform statistical analysis to check for early significance
        let results = analyzeExperimentResults(experiment)
        return results.statisticalSignificance == .significant && results.confidence >= experiment.configuration.confidenceLevel
    }
    
    private func validateExperiment(_ experiment: ABTestExperiment) -> Bool {
        // Validate that variant weights sum to approximately 1.0
        let totalWeight = experiment.variants.reduce(0) { $0 + $1.weight }
        guard abs(totalWeight - 1.0) < 0.01 else {
            logger.error("Variant weights must sum to 1.0")
            return false
        }
        
        // Validate that at least one variant is marked as control
        guard experiment.variants.contains(where: { $0.isControl }) else {
            logger.error("At least one variant must be marked as control")
            return false
        }
        
        // Validate traffic allocation
        guard experiment.trafficAllocation > 0 && experiment.trafficAllocation <= 1.0 else {
            logger.error("Traffic allocation must be between 0 and 1")
            return false
        }
        
        return true
    }
    
    private func shouldIncludeUser(_ userId: UUID, in experiment: ABTestExperiment) -> Bool {
        // Check traffic allocation
        let userHash = abs(userId.hashValue)
        let allocation = Double(userHash % 10000) / 10000.0
        if allocation >= experiment.trafficAllocation {
            return false
        }
        
        // Check segmentation criteria
        if let segmentation = experiment.segmentation {
            guard let profile = playerBehaviorAnalyzer.getProfile(for: userId) else {
                return false
            }
            
            if !segmentation.matches(profile: profile) {
                return false
            }
        }
        
        // Check for conflicting experiments if overlap is not allowed
        if !experiment.configuration.allowOverlap {
            let userExperiments = userAssignments[userId] ?? []
            if userExperiments.contains(where: { $0.isActive && $0.experimentId != experiment.id }) {
                return false
            }
        }
        
        return true
    }
    
    private func assignUserToVariant(userId: UUID, experiment: ABTestExperiment) -> TestVariant {
        // Use deterministic assignment based on user ID hash
        let userHash = abs(userId.hashValue)
        let random = Double(userHash % 10000) / 10000.0
        
        var cumulativeWeight = 0.0
        for variant in experiment.variants {
            cumulativeWeight += variant.weight
            if random <= cumulativeWeight {
                // Create assignment record
                let assignment = ExperimentAssignment(
                    userId: userId,
                    experimentId: experiment.id,
                    variantId: variant.id,
                    assignmentMethod: .deterministic
                )
                
                // Store assignment
                userAssignments[userId, default: []].append(assignment)
                assignmentStorage.saveAssignment(assignment)
                
                // Update variant participant count
                if let experimentIndex = activeExperiments.firstIndex(where: { $0.id == experiment.id }),
                   let variantIndex = activeExperiments[experimentIndex].variants.firstIndex(where: { $0.id == variant.id }) {
                    activeExperiments[experimentIndex].variants[variantIndex].participants.insert(userId)
                    activeExperiments[experimentIndex].variants[variantIndex].metrics.participantCount += 1
                }
                
                return variant
            }
        }
        
        // Fallback to first variant (should not happen if weights are correct)
        return experiment.variants[0]
    }
    
    private func getUserAssignment(userId: UUID, experimentId: UUID) -> ExperimentAssignment? {
        return userAssignments[userId]?.first { 
            $0.experimentId == experimentId && $0.isActive 
        }
    }
    
    private func analyzeExperimentResults(_ experiment: ABTestExperiment) -> ExperimentResults {
        let controlVariant = experiment.variants.first { $0.isControl }
        var variantResults: [UUID: VariantResults] = [:]
        
        for variant in experiment.variants {
            let primaryMetricValue = getPrimaryMetricValue(variant, metricType: experiment.targetMetric)
            let improvement = calculateImprovement(variant, control: controlVariant, metricType: experiment.targetMetric)
            let confidenceInterval = calculateConfidenceInterval(variant, control: controlVariant, metricType: experiment.targetMetric)
            
            variantResults[variant.id] = VariantResults(
                variantId: variant.id,
                variantName: variant.name,
                participantCount: variant.participantCount,
                primaryMetricValue: primaryMetricValue,
                primaryMetricImprovement: improvement,
                confidenceInterval: confidenceInterval
            )
        }
        
        let significance = statisticalAnalyzer.calculateSignificance(experiment.variants, targetMetric: experiment.targetMetric)
        let recommendation = generateRecommendation(experiment, variantResults: variantResults, significance: significance)
        
        return ExperimentResults(
            experimentId: experiment.id,
            totalParticipants: experiment.variants.reduce(0) { $0 + $1.participantCount },
            variantResults: variantResults,
            statisticalSignificance: significance,
            recommendation: recommendation,
            confidence: experiment.configuration.confidenceLevel,
            summary: generateResultsSummary(experiment, variantResults: variantResults, significance: significance)
        )
    }
    
    private func getPrimaryMetricValue(_ variant: TestVariant, metricType: MetricType) -> Double {
        switch metricType {
        case .conversionRate:
            return variant.metrics.conversionRate
        case .revenuePerUser:
            return variant.metrics.revenuePerUser
        case .sessionDuration:
            return variant.metrics.averageSessionDuration
        case .dayOneRetention:
            return variant.metrics.retentionRate(day: 1)
        case .daySevenRetention:
            return variant.metrics.retentionRate(day: 7)
        default:
            return 0.0
        }
    }
    
    private func calculateImprovement(_ variant: TestVariant, control: TestVariant?, metricType: MetricType) -> Double {
        guard let control = control else { return 0.0 }
        
        let variantValue = getPrimaryMetricValue(variant, metricType: metricType)
        let controlValue = getPrimaryMetricValue(control, metricType: metricType)
        
        guard controlValue > 0 else { return 0.0 }
        
        return ((variantValue - controlValue) / controlValue) * 100.0
    }
    
    private func calculateConfidenceInterval(_ variant: TestVariant, control: TestVariant?, metricType: MetricType) -> ConfidenceInterval {
        // Simplified confidence interval calculation
        let value = getPrimaryMetricValue(variant, metricType: metricType)
        let margin = value * 0.1 // 10% margin for demonstration
        
        return ConfidenceInterval(
            lowerBound: value - margin,
            upperBound: value + margin,
            confidenceLevel: 0.95
        )
    }
    
    private func generateRecommendation(_ experiment: ABTestExperiment, variantResults: [UUID: VariantResults], significance: StatisticalSignificance) -> ExperimentRecommendation {
        switch significance {
        case .significant:
            // Find the best performing non-control variant
            let nonControlResults = variantResults.values.filter { result in
                !experiment.variants.first { $0.id == result.variantId }?.isControl ?? false
            }
            
            if let bestVariant = nonControlResults.max(by: { $0.primaryMetricImprovement < $1.primaryMetricImprovement }),
               bestVariant.primaryMetricImprovement > 5.0 { // At least 5% improvement
                return .adoptTreatment
            } else {
                return .keepControl
            }
            
        case .notSignificant:
            return .runLonger
            
        case .inconclusive:
            return .redesignExperiment
            
        case .underpowered:
            return .runLonger
        }
    }
    
    private func generateResultsSummary(_ experiment: ABTestExperiment, variantResults: [UUID: VariantResults], significance: StatisticalSignificance) -> String {
        let totalParticipants = variantResults.values.reduce(0) { $0 + $1.participantCount }
        let bestVariant = variantResults.values.max { $0.primaryMetricImprovement < $1.primaryMetricImprovement }
        
        var summary = "Experiment '\(experiment.name)' completed with \(totalParticipants) participants. "
        
        if let best = bestVariant {
            summary += "Best performing variant '\(best.variantName)' showed \(String(format: "%.1f", best.primaryMetricImprovement))% improvement. "
        }
        
        summary += significance.description
        
        return summary
    }
    
    private func loadActiveExperiments() {
        // Load experiments from persistent storage
        // This would typically load from Core Data or a remote service
        logger.info("Loaded active experiments")
    }
}

// MARK: - Supporting Classes

/// Statistical analysis for A/B tests
private class StatisticalAnalyzer {
    
    func calculateSignificance(_ variants: [TestVariant], targetMetric: MetricType) -> StatisticalSignificance {
        // Simplified statistical significance calculation
        // In a real implementation, this would use proper statistical tests
        
        guard variants.count >= 2 else { return .underpowered }
        
        let controlVariant = variants.first { $0.isControl }
        guard let control = controlVariant else { return .inconclusive }
        
        let controlValue = getPrimaryMetricValue(control, metricType: targetMetric)
        
        for variant in variants where !variant.isControl {
            let variantValue = getPrimaryMetricValue(variant, metricType: targetMetric)
            let improvement = abs(variantValue - controlValue) / controlValue
            
            // Simple significance check - in reality would use t-test, chi-square, etc.
            if improvement > 0.05 && variant.participantCount > 100 && control.participantCount > 100 {
                return .significant
            }
        }
        
        return .notSignificant
    }
    
    private func getPrimaryMetricValue(_ variant: TestVariant, metricType: MetricType) -> Double {
        switch metricType {
        case .conversionRate:
            return variant.metrics.conversionRate
        case .revenuePerUser:
            return variant.metrics.revenuePerUser
        case .sessionDuration:
            return variant.metrics.averageSessionDuration
        default:
            return 0.0
        }
    }
}

/// Storage for experiment assignments
private class AssignmentStorage {
    
    func saveAssignment(_ assignment: ExperimentAssignment) {
        // Save to Core Data or other persistent storage
    }
    
    func loadAssignments(for userId: UUID) -> [ExperimentAssignment] {
        // Load from persistent storage
        return []
    }
}

// MARK: - Supporting Types

public struct ExperimentStatistics {
    public let experimentId: UUID
    public let experimentName: String
    public let status: ExperimentStatus
    public let totalParticipants: Int
    public let duration: TimeInterval
    public let variantStatistics: [VariantStatistics]
}

public struct VariantStatistics {
    public let variantId: UUID
    public let variantName: String
    public let participantCount: Int
    public let conversionRate: Double
    public let revenuePerUser: Double
    public let averageSessionDuration: TimeInterval
}