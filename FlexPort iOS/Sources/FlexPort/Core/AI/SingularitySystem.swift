import Foundation
import Combine

/// AI Singularity Progress Tracking System
/// Monitors technological advancement and AI development across the game world
public class SingularitySystem: ObservableObject {
    @Published public var singularityProgress: Double = 0.0
    @Published public var currentPhase: SingularityPhase = .early
    @Published public var researchInvestment: Double = 0.0
    @Published public var aiCapabilities: AICapabilities
    @Published public var technologicalMilestones: [TechnologicalMilestone] = []
    @Published public var globalResearchEfficiency: Double = 1.0
    
    private var cancellables = Set<AnyCancellable>()
    private let progressionRate: Double = 0.001 // Base progression per update
    
    public init() {
        self.aiCapabilities = AICapabilities()
        setupProgressionMonitoring()
        initializeMilestones()
    }
    
    private func setupProgressionMonitoring() {
        // Monitor research investment effects
        $researchInvestment
            .sink { [weak self] investment in
                self?.updateResearchEfficiency(investment)
            }
            .store(in: &cancellables)
        
        // Monitor phase transitions
        $singularityProgress
            .sink { [weak self] progress in
                self?.updatePhase(progress)
            }
            .store(in: &cancellables)
    }
    
    private func initializeMilestones() {
        technologicalMilestones = [
            TechnologicalMilestone(
                name: "Advanced Logistics AI",
                requiredProgress: 0.1,
                impact: MilestoneImpact(efficiency: 0.15, automation: 0.1, cost: 0.05),
                category: .logistics
            ),
            TechnologicalMilestone(
                name: "Predictive Market Analysis",
                requiredProgress: 0.25,
                impact: MilestoneImpact(efficiency: 0.2, automation: 0.15, cost: 0.1),
                category: .economics
            ),
            TechnologicalMilestone(
                name: "Autonomous Ship Navigation",
                requiredProgress: 0.4,
                impact: MilestoneImpact(efficiency: 0.3, automation: 0.25, cost: 0.2),
                category: .transportation
            ),
            TechnologicalMilestone(
                name: "Quantum Computing Integration",
                requiredProgress: 0.6,
                impact: MilestoneImpact(efficiency: 0.5, automation: 0.4, cost: 0.3),
                category: .computing
            ),
            TechnologicalMilestone(
                name: "Artificial General Intelligence",
                requiredProgress: 0.8,
                impact: MilestoneImpact(efficiency: 1.0, automation: 0.8, cost: 0.5),
                category: .ai
            ),
            TechnologicalMilestone(
                name: "The Singularity",
                requiredProgress: 1.0,
                impact: MilestoneImpact(efficiency: 2.0, automation: 1.0, cost: 0.9),
                category: .singularity
            )
        ]
    }
    
    /// Update singularity progress based on various factors
    public func update(deltaTime: TimeInterval, economicSystem: RyanEconomicSystem, competitors: [AICompetitor]) {
        // Calculate progress from research investment
        let researchContribution = calculateResearchContribution()
        
        // Calculate progress from AI competitor activities
        let competitorContribution = calculateCompetitorContribution(competitors)
        
        // Calculate progress from economic complexity
        let economicContribution = calculateEconomicContribution(economicSystem)
        
        // Calculate progress from technological advancement
        let techContribution = calculateTechnologicalContribution()
        
        // Total progress this update
        let totalContribution = (researchContribution + competitorContribution + economicContribution + techContribution) * progressionRate * deltaTime
        
        // Apply research efficiency multiplier
        let adjustedContribution = totalContribution * globalResearchEfficiency
        
        // Update progress with diminishing returns near singularity
        let diminishingFactor = 1.0 - pow(singularityProgress, 2.0)
        singularityProgress += adjustedContribution * diminishingFactor
        
        // Clamp to [0, 1]
        singularityProgress = max(0.0, min(1.0, singularityProgress))
        
        // Check for milestone achievements
        checkMilestoneAchievements()
        
        // Update AI capabilities
        updateAICapabilities()
    }
    
    private func calculateResearchContribution() -> Double {
        // Research investment contributes logarithmically
        guard researchInvestment > 0 else { return 0 }
        return log(1 + researchInvestment / 1_000_000) * 0.1
    }
    
    private func calculateCompetitorContribution(_ competitors: [AICompetitor]) -> Double {
        let totalLearning = competitors.reduce(0) { sum, competitor in
            sum + competitor.learningRate * competitor.singularityContribution
        }
        return totalLearning * 0.05
    }
    
    private func calculateEconomicContribution(_ economicSystem: RyanEconomicSystem) -> Double {
        // More complex economies drive technological advancement
        let marketComplexity = calculateMarketComplexity(economicSystem)
        let tradeVolume = calculateTradeVolume(economicSystem)
        return (marketComplexity + tradeVolume) * 0.02
    }
    
    private func calculateMarketComplexity(_ economicSystem: RyanEconomicSystem) -> Double {
        let commodityCount = Double(economicSystem.goodsMarket.commodities.count)
        let priceVolatility = economicSystem.goodsMarket.commodities.reduce(0) { sum, commodity in
            sum + commodity.volatility
        } / commodityCount
        
        return (commodityCount / 10.0) * (1.0 + priceVolatility)
    }
    
    private func calculateTradeVolume(_ economicSystem: RyanEconomicSystem) -> Double {
        let totalValue = economicSystem.goodsMarket.commodities.reduce(0) { sum, commodity in
            sum + commodity.currentPrice * commodity.supply
        }
        return min(totalValue / 10_000_000, 1.0) // Normalize to 0-1
    }
    
    private func calculateTechnologicalContribution() -> Double {
        // Achieved milestones contribute to further advancement
        let achievedMilestones = technologicalMilestones.filter { $0.isAchieved }
        let totalImpact = achievedMilestones.reduce(0) { sum, milestone in
            sum + milestone.impact.efficiency + milestone.impact.automation
        }
        return totalImpact * 0.01
    }
    
    private func updateResearchEfficiency(_ investment: Double) {
        // Higher investment improves research efficiency with diminishing returns
        globalResearchEfficiency = 1.0 + log(1 + investment / 5_000_000) * 0.5
    }
    
    private func updatePhase(_ progress: Double) {
        let newPhase: SingularityPhase
        
        switch progress {
        case 0.0..<0.2:
            newPhase = .early
        case 0.2..<0.4:
            newPhase = .acceleration
        case 0.4..<0.6:
            newPhase = .breakthrough
        case 0.6..<0.8:
            newPhase = .convergence
        case 0.8..<1.0:
            newPhase = .approaching
        default:
            newPhase = .singularity
        }
        
        if newPhase != currentPhase {
            currentPhase = newPhase
            triggerPhaseTransitionEvent()
        }
    }
    
    private func checkMilestoneAchievements() {
        for i in 0..<technologicalMilestones.count {
            if !technologicalMilestones[i].isAchieved && 
               singularityProgress >= technologicalMilestones[i].requiredProgress {
                technologicalMilestones[i].isAchieved = true
                technologicalMilestones[i].achievementDate = Date()
                triggerMilestoneEvent(technologicalMilestones[i])
            }
        }
    }
    
    private func updateAICapabilities() {
        // Update AI capabilities based on progress and milestones
        let achievedMilestones = technologicalMilestones.filter { $0.isAchieved }
        
        aiCapabilities.automationLevel = min(1.0, achievedMilestones.reduce(0) { sum, milestone in
            sum + milestone.impact.automation
        })
        
        aiCapabilities.decisionMakingSpeed = 1.0 + singularityProgress * 4.0
        aiCapabilities.learningEfficiency = 1.0 + singularityProgress * 2.0
        aiCapabilities.predictionAccuracy = 0.5 + singularityProgress * 0.4
        
        // Special capabilities unlock at certain milestones
        aiCapabilities.quantumProcessing = technologicalMilestones.contains { 
            $0.category == .computing && $0.isAchieved 
        }
        
        aiCapabilities.generalIntelligence = technologicalMilestones.contains { 
            $0.category == .ai && $0.isAchieved 
        }
    }
    
    private func triggerPhaseTransitionEvent() {
        // Notify game systems of phase transition
        NotificationCenter.default.post(
            name: .singularityPhaseChanged,
            object: currentPhase
        )
    }
    
    private func triggerMilestoneEvent(_ milestone: TechnologicalMilestone) {
        // Notify game systems of milestone achievement
        NotificationCenter.default.post(
            name: .singularityMilestoneAchieved,
            object: milestone
        )
    }
    
    /// Add research investment
    public func investInResearch(_ amount: Double) {
        researchInvestment += amount
    }
    
    /// Get impact of singularity on game mechanics
    public func getSingularityImpact() -> SingularityImpact {
        let achievedMilestones = technologicalMilestones.filter { $0.isAchieved }
        
        let totalEfficiency = achievedMilestones.reduce(1.0) { result, milestone in
            result + milestone.impact.efficiency
        }
        
        let totalAutomation = achievedMilestones.reduce(0.0) { result, milestone in
            result + milestone.impact.automation
        }
        
        let totalCostReduction = achievedMilestones.reduce(0.0) { result, milestone in
            result + milestone.impact.cost
        }
        
        return SingularityImpact(
            operationalEfficiency: totalEfficiency,
            automationLevel: totalAutomation,
            costReduction: totalCostReduction,
            competitiveAdvantage: singularityProgress * 0.5
        )
    }
}

/// Singularity progression phases
public enum SingularityPhase: String, CaseIterable {
    case early = "Early Development"
    case acceleration = "Accelerating Growth"
    case breakthrough = "Major Breakthroughs"
    case convergence = "Technology Convergence"
    case approaching = "Approaching Singularity"
    case singularity = "The Singularity"
    
    var description: String {
        switch self {
        case .early:
            return "Basic AI systems are improving efficiency"
        case .acceleration:
            return "AI development is accelerating rapidly"
        case .breakthrough:
            return "Major technological breakthroughs are occurring"
        case .convergence:
            return "Multiple technologies are converging"
        case .approaching:
            return "The singularity is imminent"
        case .singularity:
            return "The technological singularity has been achieved"
        }
    }
}

/// AI capabilities tracking
public struct AICapabilities {
    public var automationLevel: Double = 0.0
    public var decisionMakingSpeed: Double = 1.0
    public var learningEfficiency: Double = 1.0
    public var predictionAccuracy: Double = 0.5
    public var quantumProcessing: Bool = false
    public var generalIntelligence: Bool = false
}

/// Technological milestones
public struct TechnologicalMilestone: Identifiable {
    public let id = UUID()
    public var name: String
    public var requiredProgress: Double
    public var impact: MilestoneImpact
    public var category: MilestoneCategory
    public var isAchieved: Bool = false
    public var achievementDate: Date?
    
    public enum MilestoneCategory {
        case logistics
        case economics
        case transportation
        case computing
        case ai
        case singularity
    }
}

/// Impact of achieving a milestone
public struct MilestoneImpact {
    public var efficiency: Double
    public var automation: Double
    public var cost: Double
}

/// Overall impact of singularity on game
public struct SingularityImpact {
    public var operationalEfficiency: Double
    public var automationLevel: Double
    public var costReduction: Double
    public var competitiveAdvantage: Double
}

/// Notification names for singularity events
public extension Notification.Name {
    static let singularityPhaseChanged = Notification.Name("singularityPhaseChanged")
    static let singularityMilestoneAchieved = Notification.Name("singularityMilestoneAchieved")
}

/// Enhanced AI Competitor model
public struct AICompetitor: Identifiable {
    public let id = UUID()
    public var name: String
    public var assets: PlayerAssets
    public var learningRate: Double
    public var singularityContribution: Double
    public var researchInvestment: Double = 0.0
    public var technologicalAdvantage: Double = 0.0
    public var behaviorProfile: AIBehaviorProfile
    
    public init(name: String, assets: PlayerAssets, learningRate: Double, singularityContribution: Double) {
        self.name = name
        self.assets = assets
        self.learningRate = learningRate
        self.singularityContribution = singularityContribution
        self.behaviorProfile = AIBehaviorProfile()
    }
}

/// AI behavior profiling
public struct AIBehaviorProfile {
    public var aggressiveness: Double = 0.5
    public var riskTolerance: Double = 0.5
    public var innovationFocus: Double = 0.5
    public var collaborationTendency: Double = 0.5
    public var resourceAllocation: ResourceAllocation = ResourceAllocation()
}

public struct ResourceAllocation {
    public var research: Double = 0.1
    public var expansion: Double = 0.3
    public var operations: Double = 0.4
    public var defense: Double = 0.2
}