import Foundation
import Combine
import GameplayKit

// MARK: - Random Event Generator System
class RandomEventSystem: ObservableObject {
    @Published var activeEvents: [RandomEvent] = []
    @Published var eventQueue: [RandomEvent] = []
    @Published var dailyEventCount: Int = 0
    @Published var playerChoices: [EventChoice] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let eventGenerator = EventGenerator()
    private var eventTimer: Timer?
    private let maxActiveEvents = 5
    private let baseEventProbability = 0.15
    
    init() {
        setupEventGeneration()
    }
    
    private func setupEventGeneration() {
        // Generate events every game day (5 minutes real time)
        eventTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.generateDailyEvents()
        }
    }
    
    // MARK: - Event Generation
    private func generateDailyEvents() {
        dailyEventCount = 0
        
        // Determine number of events for today
        let eventCount = shouldGenerateEvent() ? Int.random(in: 1...3) : 0
        
        for _ in 0..<eventCount {
            if let event = eventGenerator.generateRandomEvent() {
                queueEvent(event)
                dailyEventCount += 1
            }
        }
        
        // Process queued events
        processEventQueue()
    }
    
    private func shouldGenerateEvent() -> Bool {
        // Adjust probability based on game state
        var probability = baseEventProbability
        
        // Increase probability if no recent events
        if activeEvents.isEmpty {
            probability += 0.2
        }
        
        // Decrease if too many active events
        if activeEvents.count >= maxActiveEvents {
            probability -= 0.3
        }
        
        // Increase with game progression (AI singularity approaching)
        let gameProgress = GameProgressTracker.shared.progressTowardsSingularity
        probability += gameProgress * 0.2
        
        return Double.random(in: 0...1) < probability
    }
    
    private func queueEvent(_ event: RandomEvent) {
        // Add random delay before event triggers
        let delay = TimeInterval.random(in: 0...86400) // 0-24 hours
        var delayedEvent = event
        delayedEvent.triggerDate = Date().addingTimeInterval(delay)
        
        eventQueue.append(delayedEvent)
        eventQueue.sort { $0.triggerDate < $1.triggerDate }
    }
    
    private func processEventQueue() {
        let now = Date()
        
        while !eventQueue.isEmpty && eventQueue.first!.triggerDate <= now {
            let event = eventQueue.removeFirst()
            triggerEvent(event)
        }
    }
    
    // MARK: - Event Triggering
    func triggerEvent(_ event: RandomEvent) {
        guard activeEvents.count < maxActiveEvents else { return }
        
        activeEvents.append(event)
        
        // Send notification to UI
        NotificationCenter.default.post(
            name: .randomEventTriggered,
            object: nil,
            userInfo: ["event": event]
        )
        
        // Apply immediate effects
        applyEventEffects(event)
        
        // If event requires player choice, add to choices
        if !event.choices.isEmpty {
            let choice = EventChoice(
                eventId: event.id,
                event: event,
                timeLimit: event.responseTimeLimit ?? TimeInterval.infinity,
                deadlineDate: Date().addingTimeInterval(event.responseTimeLimit ?? 86400)
            )
            playerChoices.append(choice)
        }
    }
    
    // MARK: - Player Interaction
    func makeChoice(for eventChoice: EventChoice, selectedOption: EventOption) -> EventOutcome {
        // Remove from pending choices
        playerChoices.removeAll { $0.eventId == eventChoice.eventId }
        
        // Calculate outcome based on choice and random factors
        let outcome = calculateOutcome(for: selectedOption, event: eventChoice.event)
        
        // Apply outcome effects
        applyOutcomeEffects(outcome)
        
        // Mark event as resolved
        if let index = activeEvents.firstIndex(where: { $0.id == eventChoice.eventId }) {
            activeEvents[index].status = .resolved
            activeEvents[index].outcome = outcome
            
            // Schedule cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.activeEvents.removeAll { $0.id == eventChoice.eventId }
            }
        }
        
        return outcome
    }
    
    func ignoreEvent(_ eventChoice: EventChoice) -> EventOutcome {
        // Apply default (usually negative) consequences for ignoring
        let outcome = EventOutcome(
            id: UUID(),
            success: false,
            description: "You chose to ignore the situation",
            effects: eventChoice.event.ignoreConsequences,
            experience: EventExperience(
                type: .neglect,
                category: eventChoice.event.category,
                severity: .minor,
                lesson: "Sometimes inaction has consequences"
            )
        )
        
        // Remove from choices and active events
        playerChoices.removeAll { $0.eventId == eventChoice.eventId }
        activeEvents.removeAll { $0.id == eventChoice.eventId }
        
        applyOutcomeEffects(outcome)
        
        return outcome
    }
    
    // MARK: - Event Processing
    private func applyEventEffects(_ event: RandomEvent) {
        for effect in event.immediateEffects {
            applyEffect(effect)
        }
    }
    
    private func calculateOutcome(for option: EventOption, event: RandomEvent) -> EventOutcome {
        // Base success probability from option
        var successProbability = option.successProbability
        
        // Modify based on player's relevant skills/experience
        let playerStats = PlayerStatsManager.shared
        
        switch event.category {
        case .operational:
            successProbability += playerStats.operationsExperience * 0.1
        case .financial:
            successProbability += playerStats.financialAcumen * 0.1
        case .diplomatic:
            successProbability += playerStats.diplomacySkill * 0.1
        case .crisis:
            successProbability += playerStats.crisisManagement * 0.15
        case .opportunity:
            successProbability += playerStats.opportunismSkill * 0.1
        case .regulatory:
            successProbability += playerStats.complianceKnowledge * 0.1
        case .technological:
            successProbability += playerStats.techAdaptability * 0.1
        case .environmental:
            successProbability += playerStats.sustainabilityKnowledge * 0.1
        }
        
        // Add some randomness
        let randomFactor = Double.random(in: -0.2...0.2)
        successProbability += randomFactor
        
        // Clamp between 0 and 1
        successProbability = max(0, min(1, successProbability))
        
        // Determine success
        let success = Double.random(in: 0...1) < successProbability
        
        // Generate outcome
        let effects = success ? option.successEffects : option.failureEffects
        let description = success ? option.successDescription : option.failureDescription
        
        // Create experience for learning
        let experience = EventExperience(
            type: success ? .success : .failure,
            category: event.category,
            severity: event.severity,
            lesson: option.lesson
        )
        
        return EventOutcome(
            id: UUID(),
            success: success,
            description: description,
            effects: effects,
            experience: experience
        )
    }
    
    private func applyOutcomeEffects(_ outcome: EventOutcome) {
        for effect in outcome.effects {
            applyEffect(effect)
        }
        
        // Add experience to player's learning
        PlayerStatsManager.shared.addExperience(outcome.experience)
    }
    
    private func applyEffect(_ effect: EventEffect) {
        switch effect {
        case .moneyChange(let amount):
            PlayerStatsManager.shared.adjustMoney(by: amount)
            
        case .reputationChange(let amount):
            PlayerStatsManager.shared.adjustReputation(by: amount)
            
        case .assetDamage(let assetId, let damage):
            AssetManager.shared.damageAsset(id: assetId, damage: damage)
            
        case .contractOffer(let contract):
            ContractManager.shared.offerContract(contract)
            
        case .marketImpact(let cargo, let priceChange):
            EconomicEventSystem.shared.adjustMarketPrice(cargo: cargo, change: priceChange)
            
        case .skillGain(let skill, let amount):
            PlayerStatsManager.shared.improveSkill(skill, by: amount)
            
        case .routeDisruption(let routeId, let duration):
            TradeRouteSystem.shared.disruptRoute(id: routeId, for: duration)
            
        case .relationshipChange(let entity, let change):
            DiplomacyManager.shared.adjustRelationship(with: entity, by: change)
            
        case .technologyUnlock(let tech):
            TechnologyManager.shared.unlockTechnology(tech)
            
        case .assetUpgrade(let assetId, let upgrade):
            AssetManager.shared.applyUpgrade(assetId: assetId, upgrade: upgrade)
            
        case .timeDelay(let duration):
            GameTimeManager.shared.addDelay(duration)
            
        case .weatherChange(let region, let condition):
            WeatherSystem.shared.setWeather(region: region, condition: condition)
        }
    }
    
    // MARK: - Event Cleanup
    func processActiveEvents() {
        let now = Date()
        
        // Remove expired events
        activeEvents = activeEvents.filter { event in
            if let expiry = event.expirationDate, now > expiry {
                // Apply expiration effects if any
                if let effects = event.expirationEffects {
                    for effect in effects {
                        applyEffect(effect)
                    }
                }
                return false
            }
            return true
        }
        
        // Remove expired choices
        playerChoices = playerChoices.filter { choice in
            if now > choice.deadlineDate {
                // Auto-ignore expired choices
                _ = ignoreEvent(choice)
                return false
            }
            return true
        }
    }
    
    // MARK: - Analytics
    func getEventHistory(category: EventCategory? = nil, timeframe: TimeInterval = 30 * 24 * 60 * 60) -> [RandomEvent] {
        let cutoffDate = Date().addingTimeInterval(-timeframe)
        
        return activeEvents.filter { event in
            event.triggerDate > cutoffDate &&
            (category == nil || event.category == category) &&
            event.status == .resolved
        }
    }
    
    func getPlayerPerformanceMetrics() -> PlayerEventPerformance {
        let history = getEventHistory()
        let successfulEvents = history.filter { $0.outcome?.success == true }
        let failedEvents = history.filter { $0.outcome?.success == false }
        
        let categoryStats = Dictionary(grouping: history, by: { $0.category })
            .mapValues { events in
                let successes = events.filter { $0.outcome?.success == true }.count
                return Double(successes) / Double(events.count)
            }
        
        return PlayerEventPerformance(
            totalEvents: history.count,
            successRate: Double(successfulEvents.count) / max(1, Double(history.count)),
            categoryPerformance: categoryStats,
            averageResponseTime: calculateAverageResponseTime(for: history),
            experienceGained: history.compactMap { $0.outcome?.experience }.count
        )
    }
    
    private func calculateAverageResponseTime(for events: [RandomEvent]) -> TimeInterval {
        let responseTimes = events.compactMap { event -> TimeInterval? in
            guard let outcome = event.outcome else { return nil }
            // This would require tracking when player made choice vs when event triggered
            return 0 // Placeholder
        }
        
        return responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
}

// MARK: - Event Generator
class EventGenerator {
    private let templates = EventTemplateLibrary()
    
    func generateRandomEvent() -> RandomEvent? {
        // Select random category weighted by current game state
        let category = selectEventCategory()
        
        // Get templates for that category
        let categoryTemplates = templates.getTemplates(for: category)
        guard !categoryTemplates.isEmpty else { return nil }
        
        // Select random template
        let template = categoryTemplates.randomElement()!
        
        // Generate event from template
        return generateEvent(from: template)
    }
    
    private func selectEventCategory() -> EventCategory {
        let weights: [EventCategory: Double] = [
            .operational: 0.25,
            .financial: 0.15,
            .diplomatic: 0.1,
            .crisis: 0.15,
            .opportunity: 0.2,
            .regulatory: 0.05,
            .technological: 0.05,
            .environmental: 0.05
        ]
        
        let totalWeight = weights.values.reduce(0, +)
        let random = Double.random(in: 0...totalWeight)
        
        var cumulative = 0.0
        for (category, weight) in weights {
            cumulative += weight
            if random <= cumulative {
                return category
            }
        }
        
        return .operational
    }
    
    private func generateEvent(from template: EventTemplate) -> RandomEvent {
        // Customize template with current game state
        let context = GameContextProvider.shared.getCurrentContext()
        
        let customizedTitle = template.title.replacingVariables(with: context)
        let customizedDescription = template.description.replacingVariables(with: context)
        
        return RandomEvent(
            id: UUID(),
            title: customizedTitle,
            description: customizedDescription,
            category: template.category,
            severity: template.severity,
            triggerDate: Date(),
            responseTimeLimit: template.responseTimeLimit,
            expirationDate: template.duration.map { Date().addingTimeInterval($0) },
            choices: template.choices,
            immediateEffects: template.immediateEffects,
            ignoreConsequences: template.ignoreConsequences,
            expirationEffects: template.expirationEffects,
            status: .active,
            outcome: nil
        )
    }
}

// MARK: - Event Models
struct RandomEvent: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: EventCategory
    let severity: EventSeverity
    let triggerDate: Date
    var responseTimeLimit: TimeInterval?
    var expirationDate: Date?
    let choices: [EventOption]
    let immediateEffects: [EventEffect]
    let ignoreConsequences: [EventEffect]
    let expirationEffects: [EventEffect]?
    var status: EventStatus
    var outcome: EventOutcome?
}

enum EventCategory: CaseIterable {
    case operational    // Ship breakdowns, delays, logistics issues
    case financial     // Investment opportunities, cost overruns
    case diplomatic    // Government relations, trade negotiations
    case crisis        // Emergencies, disasters, urgent situations
    case opportunity   // New markets, partnerships, innovations
    case regulatory    // Law changes, compliance issues
    case technological // New tech adoption, system upgrades
    case environmental // Weather, climate, sustainability
}

enum EventSeverity {
    case minor
    case moderate
    case major
    case critical
    
    var impactMultiplier: Double {
        switch self {
        case .minor: return 0.5
        case .moderate: return 1.0
        case .major: return 2.0
        case .critical: return 3.0
        }
    }
}

enum EventStatus {
    case pending
    case active
    case resolved
    case expired
}

struct EventOption {
    let id: UUID = UUID()
    let title: String
    let description: String
    let successProbability: Double
    let successEffects: [EventEffect]
    let failureEffects: [EventEffect]
    let successDescription: String
    let failureDescription: String
    let lesson: String
    let cost: Double?
    let timeRequired: TimeInterval?
    let riskLevel: Double
}

enum EventEffect {
    case moneyChange(Double)
    case reputationChange(Double)
    case assetDamage(UUID, Double)
    case contractOffer(Contract)
    case marketImpact(CargoType, Double)
    case skillGain(SkillType, Double)
    case routeDisruption(UUID, TimeInterval)
    case relationshipChange(Entity, Double)
    case technologyUnlock(Technology)
    case assetUpgrade(UUID, AssetUpgrade)
    case timeDelay(TimeInterval)
    case weatherChange(Region, WeatherCondition)
}

struct EventChoice {
    let eventId: UUID
    let event: RandomEvent
    let timeLimit: TimeInterval
    let deadlineDate: Date
}

struct EventOutcome: Identifiable {
    let id: UUID
    let success: Bool
    let description: String
    let effects: [EventEffect]
    let experience: EventExperience
}

struct EventExperience {
    let type: ExperienceType
    let category: EventCategory
    let severity: EventSeverity
    let lesson: String
}

enum ExperienceType {
    case success
    case failure
    case learning
    case neglect
}

enum SkillType {
    case operations
    case finance
    case diplomacy
    case crisis
    case technology
    case sustainability
}

enum Entity {
    case government(String)
    case corporation(String)
    case ngo(String)
    case port(String)
}

struct Technology {
    let name: String
    let category: String
    let benefits: [String]
}

enum WeatherCondition {
    case clear
    case stormy
    case foggy
    case extreme
}

struct Contract {
    let id: UUID
    let type: ContractType
    let value: Double
    let duration: TimeInterval
    let requirements: [String]
}

enum ContractType {
    case delivery
    case exclusive
    case emergency
    case longTerm
}

// MARK: - Event Templates
struct EventTemplate {
    let title: String
    let description: String
    let category: EventCategory
    let severity: EventSeverity
    let responseTimeLimit: TimeInterval?
    let duration: TimeInterval?
    let choices: [EventOption]
    let immediateEffects: [EventEffect]
    let ignoreConsequences: [EventEffect]
    let expirationEffects: [EventEffect]?
}

class EventTemplateLibrary {
    private let templates: [EventCategory: [EventTemplate]]
    
    init() {
        self.templates = Self.createTemplateLibrary()
    }
    
    func getTemplates(for category: EventCategory) -> [EventTemplate] {
        return templates[category] ?? []
    }
    
    private static func createTemplateLibrary() -> [EventCategory: [EventTemplate]] {
        var library: [EventCategory: [EventTemplate]] = [:]
        
        // Operational Events
        library[.operational] = [
            EventTemplate(
                title: "Ship Engine Failure",
                description: "One of your cargo ships has experienced engine trouble in the middle of the Pacific. The crew is safe but the ship is stranded.",
                category: .operational,
                severity: .major,
                responseTimeLimit: 3600, // 1 hour
                duration: nil,
                choices: [
                    EventOption(
                        title: "Send Rescue Tugboat",
                        description: "Dispatch our fastest tugboat to tow the ship to the nearest port",
                        successProbability: 0.8,
                        successEffects: [.moneyChange(-50000), .reputationChange(5)],
                        failureEffects: [.moneyChange(-100000), .reputationChange(-10)],
                        successDescription: "Rescue successful! Ship safely reaches port with minimal delay.",
                        failureDescription: "Tugboat arrives too late. Cargo spoils and customers are furious.",
                        lesson: "Quick response is crucial in maritime emergencies",
                        cost: 50000,
                        timeRequired: 3600,
                        riskLevel: 0.3
                    ),
                    EventOption(
                        title: "Wait for Coast Guard",
                        description: "Contact local authorities and wait for official rescue",
                        successProbability: 0.6,
                        successEffects: [.moneyChange(-20000), .reputationChange(0)],
                        failureEffects: [.moneyChange(-80000), .reputationChange(-15)],
                        successDescription: "Coast Guard assists. Delays are minimal.",
                        failureDescription: "Coast Guard is overwhelmed. Long delays damage business relationships.",
                        lesson: "Government assistance may not always be timely",
                        cost: 20000,
                        timeRequired: 7200,
                        riskLevel: 0.5
                    )
                ],
                immediateEffects: [.routeDisruption(UUID(), 86400)],
                ignoreConsequences: [.moneyChange(-150000), .reputationChange(-25)],
                expirationEffects: [.moneyChange(-200000), .reputationChange(-30)]
            ),
            
            EventTemplate(
                title: "Port Strike",
                description: "Dock workers at {PORT_NAME} have gone on strike, affecting cargo operations for the next {DURATION} days.",
                category: .operational,
                severity: .moderate,
                responseTimeLimit: nil,
                duration: 7 * 24 * 60 * 60, // 7 days
                choices: [
                    EventOption(
                        title: "Reroute to Alternative Port",
                        description: "Find another port and adjust shipping routes",
                        successProbability: 0.7,
                        successEffects: [.moneyChange(-30000)],
                        failureEffects: [.moneyChange(-60000), .timeDelay(172800)],
                        successDescription: "Successfully rerouted operations with minimal impact.",
                        failureDescription: "Alternative port is also experiencing issues. Significant delays occur.",
                        lesson: "Always have backup plans for critical infrastructure",
                        cost: 30000,
                        timeRequired: 1800,
                        riskLevel: 0.4
                    ),
                    EventOption(
                        title: "Negotiate with Union",
                        description: "Attempt to mediate and find a quick resolution",
                        successProbability: 0.4,
                        successEffects: [.moneyChange(-10000), .reputationChange(10)],
                        failureEffects: [.moneyChange(-5000), .timeDelay(432000)],
                        successDescription: "Successful mediation ends strike early. Workers appreciate your intervention.",
                        failureDescription: "Negotiations fail. Strike continues for full duration.",
                        lesson: "Diplomacy can be more effective than force",
                        cost: 10000,
                        timeRequired: 3600,
                        riskLevel: 0.6
                    )
                ],
                immediateEffects: [],
                ignoreConsequences: [.moneyChange(-80000), .timeDelay(604800)],
                expirationEffects: nil
            )
        ]
        
        // Financial Events
        library[.financial] = [
            EventTemplate(
                title: "Investment Opportunity",
                description: "A startup developing autonomous cargo drones is seeking investors. They claim to have revolutionary technology.",
                category: .financial,
                severity: .moderate,
                responseTimeLimit: 48 * 60 * 60, // 48 hours
                duration: nil,
                choices: [
                    EventOption(
                        title: "Invest $500K",
                        description: "Make a significant investment for potential high returns",
                        successProbability: 0.3,
                        successEffects: [.moneyChange(-500000), .technologyUnlock(Technology(name: "Autonomous Drones", category: "Transportation", benefits: ["Reduced labor costs", "24/7 operations"]))],
                        failureEffects: [.moneyChange(-500000)],
                        successDescription: "Investment pays off! You gain early access to game-changing technology.",
                        failureDescription: "Startup fails. Your investment is lost.",
                        lesson: "High-risk investments can yield breakthrough advantages",
                        cost: 500000,
                        timeRequired: 300,
                        riskLevel: 0.7
                    ),
                    EventOption(
                        title: "Small Investment $100K",
                        description: "Make a modest investment to test the waters",
                        successProbability: 0.5,
                        successEffects: [.moneyChange(-100000), .skillGain(.technology, 5)],
                        failureEffects: [.moneyChange(-100000)],
                        successDescription: "Modest gains and valuable insights into emerging tech.",
                        failureDescription: "Investment doesn't pay off, but loss is manageable.",
                        lesson: "Sometimes smaller, calculated risks are wiser",
                        cost: 100000,
                        timeRequired: 300,
                        riskLevel: 0.5
                    )
                ],
                immediateEffects: [],
                ignoreConsequences: [],
                expirationEffects: []
            )
        ]
        
        // Crisis Events
        library[.crisis] = [
            EventTemplate(
                title: "Typhoon Warning",
                description: "A massive typhoon is heading toward your major shipping routes in the Pacific. All vessels in the area are at risk.",
                category: .crisis,
                severity: .critical,
                responseTimeLimit: 1800, // 30 minutes
                duration: 72 * 60 * 60, // 3 days
                choices: [
                    EventOption(
                        title: "Emergency Evacuation",
                        description: "Order all ships to immediately seek shelter in nearest safe harbors",
                        successProbability: 0.9,
                        successEffects: [.moneyChange(-200000), .reputationChange(5)],
                        failureEffects: [.moneyChange(-1000000), .reputationChange(-20)],
                        successDescription: "All ships reach safety. Customers appreciate your responsible decision-making.",
                        failureDescription: "Some ships didn't make it to safety in time. Significant damage and cargo loss.",
                        lesson: "Safety should always be the top priority",
                        cost: 200000,
                        timeRequired: 1800,
                        riskLevel: 0.1
                    ),
                    EventOption(
                        title: "Continue Operations",
                        description: "Risk it and try to complete deliveries before the storm hits",
                        successProbability: 0.2,
                        successEffects: [.moneyChange(500000), .reputationChange(10)],
                        failureEffects: [.moneyChange(-2000000), .reputationChange(-50)],
                        successDescription: "Incredible luck! All ships complete their routes just in time.",
                        failureDescription: "Disaster strikes. Multiple ships damaged, cargo lost, crew endangered.",
                        lesson: "Greed can lead to catastrophic consequences",
                        cost: 0,
                        timeRequired: 0,
                        riskLevel: 0.8
                    )
                ],
                immediateEffects: [.weatherChange(.asia, .extreme)],
                ignoreConsequences: [.moneyChange(-3000000), .reputationChange(-75)],
                expirationEffects: [.moneyChange(-3000000), .reputationChange(-75)]
            )
        ]
        
        // Add more categories as needed...
        library[.opportunity] = []
        library[.diplomatic] = []
        library[.regulatory] = []
        library[.technological] = []
        library[.environmental] = []
        
        return library
    }
}

// MARK: - Supporting Systems
class PlayerStatsManager {
    static let shared = PlayerStatsManager()
    
    var operationsExperience: Double = 0.5
    var financialAcumen: Double = 0.5
    var diplomacySkill: Double = 0.5
    var crisisManagement: Double = 0.5
    var opportunismSkill: Double = 0.5
    var complianceKnowledge: Double = 0.5
    var techAdaptability: Double = 0.5
    var sustainabilityKnowledge: Double = 0.5
    
    func adjustMoney(by amount: Double) {
        // Implementation would integrate with financial system
    }
    
    func adjustReputation(by amount: Double) {
        // Implementation would integrate with reputation system
    }
    
    func improveSkill(_ skill: SkillType, by amount: Double) {
        // Implementation would improve relevant skill
    }
    
    func addExperience(_ experience: EventExperience) {
        // Add experience points and potentially improve skills
    }
}

class GameProgressTracker {
    static let shared = GameProgressTracker()
    
    var progressTowardsSingularity: Double = 0.0
}

class GameContextProvider {
    static let shared = GameContextProvider()
    
    func getCurrentContext() -> [String: String] {
        return [
            "PORT_NAME": ["Hong Kong", "Singapore", "Los Angeles", "Rotterdam"].randomElement() ?? "Singapore",
            "DURATION": String(Int.random(in: 3...14)),
            "COMPANY_NAME": "FlexPort Logistics",
            "CURRENT_SEASON": getCurrentSeason()
        ]
    }
    
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return "winter"
        case 3, 4, 5: return "spring"
        case 6, 7, 8: return "summer"
        case 9, 10, 11: return "autumn"
        default: return "unknown"
        }
    }
}

struct PlayerEventPerformance {
    let totalEvents: Int
    let successRate: Double
    let categoryPerformance: [EventCategory: Double]
    let averageResponseTime: TimeInterval
    let experienceGained: Int
}

// MARK: - Extensions
extension String {
    func replacingVariables(with context: [String: String]) -> String {
        var result = self
        for (key, value) in context {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let randomEventTriggered = Notification.Name("randomEventTriggered")
    static let eventChoiceMade = Notification.Name("eventChoiceMade")
    static let eventExpired = Notification.Name("eventExpired")
}

// MARK: - Manager Placeholders
// These would be implemented in their respective systems
class AssetManager {
    static let shared = AssetManager()
    func damageAsset(id: UUID, damage: Double) {}
    func applyUpgrade(assetId: UUID, upgrade: AssetUpgrade) {}
}

class ContractManager {
    static let shared = ContractManager()
    func offerContract(_ contract: Contract) {}
}

class DiplomacyManager {
    static let shared = DiplomacyManager()
    func adjustRelationship(with entity: Entity, by change: Double) {}
}

class TechnologyManager {
    static let shared = TechnologyManager()
    func unlockTechnology(_ tech: Technology) {}
}

class GameTimeManager {
    static let shared = GameTimeManager()
    func addDelay(_ duration: TimeInterval) {}
}

class WeatherSystem {
    static let shared = WeatherSystem()
    func setWeather(region: Region, condition: WeatherCondition) {}
}