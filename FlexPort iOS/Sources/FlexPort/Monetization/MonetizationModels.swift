import Foundation
import StoreKit

// MARK: - Ethical Monetization Models

/// Ethical in-app purchase item that enhances rather than gates gameplay
public struct PremiumItem: Identifiable, Codable {
    public let id = UUID()
    public let productId: String
    public let itemType: PremiumItemType
    public let name: String
    public let description: String
    public let price: Decimal
    public let currencyCode: String
    public let category: ItemCategory
    public let rarity: ItemRarity
    public let benefits: [PremiumBenefit]
    public let restrictions: [PurchaseRestriction]
    public let availability: ItemAvailability
    public let ethicalScore: EthicalScore
    
    public init(productId: String, itemType: PremiumItemType, name: String, description: String,
                price: Decimal, currencyCode: String, category: ItemCategory, rarity: ItemRarity,
                benefits: [PremiumBenefit], restrictions: [PurchaseRestriction] = [],
                availability: ItemAvailability = .always) {
        self.productId = productId
        self.itemType = itemType
        self.name = name
        self.description = description
        self.price = price
        self.currencyCode = currencyCode
        self.category = category
        self.rarity = rarity
        self.benefits = benefits
        self.restrictions = restrictions
        self.availability = availability
        self.ethicalScore = EthicalScore.calculate(for: itemType, benefits: benefits)
    }
}

/// Types of premium items that maintain game balance
public enum PremiumItemType: String, Codable, CaseIterable {
    // Cosmetic items (completely ethical)
    case shipSkin = "ship_skin"
    case portDecoration = "port_decoration"
    case uiTheme = "ui_theme"
    case avatarCustomization = "avatar_customization"
    
    // Quality of life improvements (ethical)
    case additionalSaveSlots = "additional_save_slots"
    case autoSave = "auto_save"
    case expandedStatistics = "expanded_statistics"
    case cloudSync = "cloud_sync"
    case notificationCustomization = "notification_customization"
    
    // Time-based conveniences (carefully balanced)
    case premiumSupport = "premium_support"
    case priorityMatching = "priority_matching"
    case extendedOfflineProgress = "extended_offline_progress"
    
    // Content expansions (value-adding)
    case additionalCampaigns = "additional_campaigns"
    case specialEvents = "special_events"
    case historicalScenarios = "historical_scenarios"
    
    // Convenience features (balanced)
    case bulkOperations = "bulk_operations"
    case advancedAnalytics = "advanced_analytics"
    case customAlerts = "custom_alerts"
    
    public var ethicalRating: EthicalRating {
        switch self {
        case .shipSkin, .portDecoration, .uiTheme, .avatarCustomization:
            return .fullyEthical
        case .additionalSaveSlots, .autoSave, .expandedStatistics, .cloudSync, .notificationCustomization:
            return .ethical
        case .premiumSupport, .priorityMatching, .extendedOfflineProgress:
            return .cautiouslyEthical
        case .additionalCampaigns, .specialEvents, .historicalScenarios:
            return .valueAdding
        case .bulkOperations, .advancedAnalytics, .customAlerts:
            return .convenient
        }
    }
}

public enum EthicalRating: String, Codable {
    case fullyEthical = "fully_ethical"         // Pure cosmetics, no gameplay impact
    case ethical = "ethical"                    // Quality of life, no competitive advantage
    case cautiouslyEthical = "cautiously_ethical" // Minor convenience, carefully balanced
    case valueAdding = "value_adding"           // Additional content, expands game
    case convenient = "convenient"              // Saves time but doesn't change outcomes
}

/// Categories for organizing premium items
public enum ItemCategory: String, Codable, CaseIterable {
    case cosmetics = "cosmetics"
    case convenience = "convenience"
    case content = "content"
    case features = "features"
    case support = "support"
}

/// Item rarity affects presentation but not power
public enum ItemRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    public var displayColor: String {
        switch self {
        case .common: return "#808080"
        case .uncommon: return "#00FF00"
        case .rare: return "#0080FF"
        case .epic: return "#8000FF"
        case .legendary: return "#FF8000"
        }
    }
}

/// Benefits that premium items provide
public struct PremiumBenefit: Codable, Identifiable {
    public let id = UUID()
    public let benefitType: BenefitType
    public let description: String
    public let magnitude: Double
    public let duration: BenefitDuration
    public let isCosmetic: Bool
    
    public init(benefitType: BenefitType, description: String, magnitude: Double = 1.0,
                duration: BenefitDuration = .permanent, isCosmetic: Bool = false) {
        self.benefitType = benefitType
        self.description = description
        self.magnitude = magnitude
        self.duration = duration
        self.isCosmetic = isCosmetic
    }
}

public enum BenefitType: String, Codable {
    // Pure cosmetic benefits
    case visualCustomization = "visual_customization"
    case soundCustomization = "sound_customization"
    case animationVariation = "animation_variation"
    
    // Quality of life benefits
    case interfaceImprovement = "interface_improvement"
    case dataAnalysis = "data_analysis"
    case automationFeature = "automation_feature"
    
    // Content benefits
    case additionalContent = "additional_content"
    case earlyAccess = "early_access"
    case exclusiveScenarios = "exclusive_scenarios"
    
    // Convenience benefits (carefully balanced)
    case timeEfficiency = "time_efficiency"
    case bulkActions = "bulk_actions"
    case enhancedNotifications = "enhanced_notifications"
}

public enum BenefitDuration: Codable {
    case permanent
    case temporary(TimeInterval)
    case subscription(TimeInterval)
    
    public var isPermanent: Bool {
        if case .permanent = self { return true }
        return false
    }
}

/// Restrictions to maintain ethical standards
public struct PurchaseRestriction: Codable, Identifiable {
    public let id = UUID()
    public let restrictionType: RestrictionType
    public let description: String
    public let value: Double?
    
    public init(restrictionType: RestrictionType, description: String, value: Double? = nil) {
        self.restrictionType = restrictionType
        self.description = description
        self.value = value
    }
}

public enum RestrictionType: String, Codable {
    case dailyLimit = "daily_limit"
    case weeklyLimit = "weekly_limit"
    case monthlyLimit = "monthly_limit"
    case totalSpendingCap = "total_spending_cap"
    case newPlayerProtection = "new_player_protection"
    case parentalControl = "parental_control"
    case cooldownPeriod = "cooldown_period"
}

/// Item availability controls
public struct ItemAvailability: Codable {
    public let availabilityType: AvailabilityType
    public let startDate: Date?
    public let endDate: Date?
    public let requirements: [AvailabilityRequirement]
    
    public static let always = ItemAvailability(
        availabilityType: .always,
        startDate: nil,
        endDate: nil,
        requirements: []
    )
    
    public init(availabilityType: AvailabilityType, startDate: Date? = nil, endDate: Date? = nil,
                requirements: [AvailabilityRequirement] = []) {
        self.availabilityType = availabilityType
        self.startDate = startDate
        self.endDate = endDate
        self.requirements = requirements
    }
    
    public var isCurrentlyAvailable: Bool {
        let now = Date()
        
        if let start = startDate, now < start { return false }
        if let end = endDate, now > end { return false }
        
        return true
    }
}

public enum AvailabilityType: String, Codable {
    case always = "always"
    case limited = "limited"
    case seasonal = "seasonal"
    case event = "event"
    case achievement = "achievement"
}

public struct AvailabilityRequirement: Codable, Identifiable {
    public let id = UUID()
    public let requirementType: RequirementType
    public let description: String
    public let value: Double
    
    public init(requirementType: RequirementType, description: String, value: Double) {
        self.requirementType = requirementType
        self.description = description
        self.value = value
    }
}

public enum RequirementType: String, Codable {
    case minimumLevel = "minimum_level"
    case achievementUnlocked = "achievement_unlocked"
    case campaignProgress = "campaign_progress"
    case playTime = "play_time"
    case socialRank = "social_rank"
}

/// Ethical scoring system for monetization items
public struct EthicalScore: Codable {
    public let score: Double // 0.0 to 1.0, where 1.0 is most ethical
    public let reasoning: [String]
    public let concerns: [EthicalConcern]
    
    public init(score: Double, reasoning: [String], concerns: [EthicalConcern] = []) {
        self.score = max(0.0, min(1.0, score))
        self.reasoning = reasoning
        self.concerns = concerns
    }
    
    public static func calculate(for itemType: PremiumItemType, benefits: [PremiumBenefit]) -> EthicalScore {
        var score = 1.0
        var reasoning: [String] = []
        var concerns: [EthicalConcern] = []
        
        // Base score from item type
        switch itemType.ethicalRating {
        case .fullyEthical:
            score = 1.0
            reasoning.append("Pure cosmetic item with no gameplay impact")
        case .ethical:
            score = 0.9
            reasoning.append("Quality of life improvement without competitive advantage")
        case .cautiouslyEthical:
            score = 0.8
            reasoning.append("Minor convenience feature with careful balancing")
        case .valueAdding:
            score = 0.85
            reasoning.append("Additional content that expands the game experience")
        case .convenient:
            score = 0.75
            reasoning.append("Convenience feature that saves time but doesn't change outcomes")
        }
        
        // Analyze benefits for potential ethical issues
        for benefit in benefits {
            if !benefit.isCosmetic && benefit.magnitude > 2.0 {
                score -= 0.1
                concerns.append(.significantGameplayAdvantage)
            }
            
            if case .temporary(_) = benefit.duration {
                score += 0.05 // Temporary benefits are more ethical
                reasoning.append("Temporary effect reduces long-term impact")
            }
        }
        
        return EthicalScore(score: score, reasoning: reasoning, concerns: concerns)
    }
}

public enum EthicalConcern: String, Codable, CaseIterable {
    case significantGameplayAdvantage = "significant_gameplay_advantage"
    case potentialPayToWin = "potential_pay_to_win"
    case excessivePricing = "excessive_pricing"
    case targetingVulnerableUsers = "targeting_vulnerable_users"
    case limitedTimeManipulation = "limited_time_manipulation"
}

/// Purchase history and spending tracking
public struct PurchaseHistory: Codable {
    public let playerId: UUID
    public var purchases: [PurchaseRecord]
    public var totalSpent: Decimal
    public var monthlySpending: [String: Decimal] // Month key -> Amount
    public var spendingPattern: SpendingPattern
    public var protectionFlags: [ProtectionFlag]
    
    public init(playerId: UUID) {
        self.playerId = playerId
        self.purchases = []
        self.totalSpent = 0
        self.monthlySpending = [:]
        self.spendingPattern = .none
        self.protectionFlags = []
    }
    
    public mutating func addPurchase(_ purchase: PurchaseRecord) {
        purchases.append(purchase)
        totalSpent += purchase.amount
        
        let monthKey = DateFormatter.monthYear.string(from: purchase.purchaseDate)
        monthlySpending[monthKey, default: 0] += purchase.amount
        
        updateSpendingPattern()
        updateProtectionFlags()
    }
    
    private mutating func updateSpendingPattern() {
        let recentPurchases = purchases.suffix(10)
        let averageAmount = recentPurchases.map { $0.amount }.reduce(0, +) / Decimal(max(1, recentPurchases.count))
        
        if totalSpent >= 500 {
            spendingPattern = .whale
        } else if totalSpent >= 100 {
            spendingPattern = .dolphin
        } else if totalSpent >= 10 {
            spendingPattern = .minnow
        } else if !purchases.isEmpty {
            spendingPattern = .minimal
        } else {
            spendingPattern = .none
        }
    }
    
    private mutating func updateProtectionFlags() {
        protectionFlags.removeAll()
        
        // Check for rapid spending
        let last24Hours = purchases.filter { 
            Date().timeIntervalSince($0.purchaseDate) < 86400 
        }
        
        if last24Hours.count >= 5 {
            protectionFlags.append(.rapidSpending)
        }
        
        // Check for high spending amounts
        let currentMonth = DateFormatter.monthYear.string(from: Date())
        if let monthlyAmount = monthlySpending[currentMonth], monthlyAmount >= 200 {
            protectionFlags.append(.highMonthlySpending)
        }
        
        // Check for unusual patterns
        if purchases.count >= 3 {
            let recentAmounts = Array(purchases.suffix(3)).map { $0.amount }
            if recentAmounts.allSatisfy({ $0 >= 50 }) {
                protectionFlags.append(.unusualSpendingPattern)
            }
        }
    }
}

public struct PurchaseRecord: Codable, Identifiable {
    public let id = UUID()
    public let productId: String
    public let itemName: String
    public let amount: Decimal
    public let currencyCode: String
    public let purchaseDate: Date
    public let transactionId: String
    public let purchaseType: PurchaseType
    public let wasRefunded: Bool
    
    public init(productId: String, itemName: String, amount: Decimal, currencyCode: String,
                transactionId: String, purchaseType: PurchaseType) {
        self.productId = productId
        self.itemName = itemName
        self.amount = amount
        self.currencyCode = currencyCode
        self.purchaseDate = Date()
        self.transactionId = transactionId
        self.purchaseType = purchaseType
        self.wasRefunded = false
    }
}

public enum PurchaseType: String, Codable {
    case oneTime = "one_time"
    case subscription = "subscription"
    case seasonPass = "season_pass"
}

public enum SpendingPattern: String, Codable {
    case none = "none"
    case minimal = "minimal"    // $1-10
    case minnow = "minnow"      // $10-50
    case dolphin = "dolphin"    // $50-200
    case whale = "whale"        // $200+
}

public enum ProtectionFlag: String, Codable, CaseIterable {
    case rapidSpending = "rapid_spending"
    case highMonthlySpending = "high_monthly_spending"
    case unusualSpendingPattern = "unusual_spending_pattern"
    case newPlayerSpending = "new_player_spending"
    case parentalControlNeeded = "parental_control_needed"
    
    public var description: String {
        switch self {
        case .rapidSpending:
            return "Multiple purchases made in a short time period"
        case .highMonthlySpending:
            return "Monthly spending exceeds recommended limits"
        case .unusualSpendingPattern:
            return "Spending pattern differs significantly from typical behavior"
        case .newPlayerSpending:
            return "New player making purchases before understanding game mechanics"
        case .parentalControlNeeded:
            return "Spending pattern suggests parental oversight may be needed"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}