import Foundation
import StoreKit
import Combine
import os.log

/// Ethical monetization manager that prioritizes player experience over revenue
@MainActor
public class EthicalMonetizationManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "Monetization")
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var availableItems: [PremiumItem] = []
    @Published public private(set) var purchaseHistory: PurchaseHistory?
    @Published public private(set) var isStoreLoaded = false
    @Published public private(set) var purchaseInProgress = false
    
    private let analyticsEngine: AnalyticsEngine
    private let playerBehaviorAnalyzer: PlayerBehaviorAnalyzer
    private var storeProducts: [String: Product] = [:]
    
    // Ethical constraints
    private let maxDailySpending: Decimal = 50.0
    private let maxMonthlySpending: Decimal = 200.0
    private let newPlayerProtectionDays = 7
    private let cooldownBetweenPurchases: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    public init(analyticsEngine: AnalyticsEngine, playerBehaviorAnalyzer: PlayerBehaviorAnalyzer) {
        self.analyticsEngine = analyticsEngine
        self.playerBehaviorAnalyzer = playerBehaviorAnalyzer
        super.init()
        
        setupStoreObserver()
        setupEthicalMonitoring()
        loadAvailableItems()
    }
    
    // MARK: - Store Management
    
    /// Load available premium items from the store
    public func loadStore() async {
        do {
            let productIds = availableItems.map { $0.productId }
            let products = try await Product.products(for: productIds)
            
            for product in products {
                storeProducts[product.id] = product
            }
            
            isStoreLoaded = true
            analyticsEngine.trackEvent(.storeViewed)
            logger.info("Store loaded with \(products.count) products")
            
        } catch {
            logger.error("Failed to load store: \(error.localizedDescription)")
            analyticsEngine.trackError(error, context: "store_loading")
        }
    }
    
    /// Get filtered items based on ethical constraints and player profile
    public func getRecommendedItems(for playerId: UUID) -> [PremiumItem] {
        guard let profile = playerBehaviorAnalyzer.getProfile(for: playerId) else {
            return getNewPlayerSafeItems()
        }
        
        let history = purchaseHistory ?? PurchaseHistory(playerId: playerId)
        
        return availableItems.filter { item in
            isItemEthicalForPlayer(item, profile: profile, history: history)
        }
    }
    
    /// Purchase an item with ethical validation
    public func purchaseItem(_ item: PremiumItem, playerId: UUID) async -> PurchaseResult {
        guard !purchaseInProgress else {
            return .failure(.purchaseInProgress)
        }
        
        // Validate ethical constraints
        let validationResult = validatePurchase(item, playerId: playerId)
        if case .failure(let reason) = validationResult {
            analyticsEngine.trackEvent(.purchaseCancelled, parameters: [
                "item_id": .string(item.productId),
                "cancellation_reason": .string(reason.description)
            ])
            return .failure(reason)
        }
        
        purchaseInProgress = true
        analyticsEngine.trackEvent(.purchaseInitiated, parameters: [
            "item_id": .string(item.productId),
            "item_type": .string(item.itemType.rawValue),
            "price": .double(item.price.doubleValue)
        ])
        
        do {
            guard let product = storeProducts[item.productId] else {
                throw PurchaseError.productNotFound
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                return await handleSuccessfulPurchase(verification, item: item, playerId: playerId)
                
            case .userCancelled:
                purchaseInProgress = false
                analyticsEngine.trackEvent(.purchaseCancelled, parameters: [
                    "item_id": .string(item.productId),
                    "cancellation_reason": .string("user_cancelled")
                ])
                return .failure(.userCancelled)
                
            case .pending:
                purchaseInProgress = false
                return .failure(.purchasePending)
                
            @unknown default:
                purchaseInProgress = false
                return .failure(.unknown)
            }
            
        } catch {
            purchaseInProgress = false
            analyticsEngine.trackError(error, context: "purchase_attempt")
            return .failure(.systemError(error))
        }
    }
    
    /// Get purchase recommendations based on player behavior
    public func getPersonalizedRecommendations(for playerId: UUID) -> [ItemRecommendation] {
        guard let profile = playerBehaviorAnalyzer.getProfile(for: playerId) else {
            return []
        }
        
        var recommendations: [ItemRecommendation] = []
        
        // Recommend based on gameplay style
        switch profile.gameplayStyle {
        case .economic:
            recommendations.append(contentsOf: getEconomicPlayerRecommendations())
        case .social:
            recommendations.append(contentsOf: getSocialPlayerRecommendations())
        case .casual:
            recommendations.append(contentsOf: getCasualPlayerRecommendations())
        case .hardcore:
            recommendations.append(contentsOf: getHardcorePlayerRecommendations())
        default:
            recommendations.append(contentsOf: getGenericRecommendations())
        }
        
        // Filter by ethical constraints
        let history = purchaseHistory ?? PurchaseHistory(playerId: playerId)
        return recommendations.filter { recommendation in
            isItemEthicalForPlayer(recommendation.item, profile: profile, history: history)
        }
    }
    
    // MARK: - Ethical Validation
    
    private func validatePurchase(_ item: PremiumItem, playerId: UUID) -> Result<Void, PurchaseError> {
        let history = purchaseHistory ?? PurchaseHistory(playerId: playerId)
        
        // Check spending limits
        if let dailySpending = getDailySpending(history) {
            if dailySpending + item.price > maxDailySpending {
                return .failure(.dailyLimitExceeded)
            }
        }
        
        if let monthlySpending = getMonthlySpending(history) {
            if monthlySpending + item.price > maxMonthlySpending {
                return .failure(.monthlyLimitExceeded)
            }
        }
        
        // Check new player protection
        if let profile = playerBehaviorAnalyzer.getProfile(for: playerId) {
            let daysSinceStart = Date().timeIntervalSince(profile.lastActive) / 86400
            if daysSinceStart < Double(newPlayerProtectionDays) && item.price > 10 {
                return .failure(.newPlayerProtection)
            }
        }
        
        // Check cooldown period
        if let lastPurchase = history.purchases.last {
            let timeSinceLastPurchase = Date().timeIntervalSince(lastPurchase.purchaseDate)
            if timeSinceLastPurchase < cooldownBetweenPurchases {
                return .failure(.cooldownActive)
            }
        }
        
        // Check protection flags
        if history.protectionFlags.contains(.rapidSpending) {
            return .failure(.protectionFlagActive)
        }
        
        // Validate item-specific restrictions
        for restriction in item.restrictions {
            switch restriction.restrictionType {
            case .dailyLimit:
                if let limit = restriction.value {
                    let todayPurchases = getTodayPurchases(for: item.productId, history: history)
                    if Double(todayPurchases) >= limit {
                        return .failure(.itemLimitExceeded)
                    }
                }
            case .totalSpendingCap:
                if let cap = restriction.value {
                    if history.totalSpent.doubleValue >= cap {
                        return .failure(.spendingCapReached)
                    }
                }
            default:
                break
            }
        }
        
        return .success(())
    }
    
    private func isItemEthicalForPlayer(_ item: PremiumItem, profile: PlayerBehaviorProfile, history: PurchaseHistory) -> Bool {
        // Always allow cosmetic items
        if item.ethicalScore.score >= 0.9 {
            return true
        }
        
        // Check if player might be vulnerable
        if profile.retentionRisk == .critical && item.price > 20 {
            return false
        }
        
        // Check spending pattern
        if history.spendingPattern == .whale && item.price > 50 {
            return false
        }
        
        // Check protection flags
        if !history.protectionFlags.isEmpty && item.price > 10 {
            return false
        }
        
        return true
    }
    
    // MARK: - Purchase Processing
    
    private func handleSuccessfulPurchase(_ verification: VerificationResult<Transaction>, item: PremiumItem, playerId: UUID) async -> PurchaseResult {
        
        switch verification {
        case .verified(let transaction):
            // Record the purchase
            let purchaseRecord = PurchaseRecord(
                productId: item.productId,
                itemName: item.name,
                amount: item.price,
                currencyCode: item.currencyCode,
                transactionId: transaction.id.description,
                purchaseType: .oneTime
            )
            
            if purchaseHistory == nil {
                purchaseHistory = PurchaseHistory(playerId: playerId)
            }
            purchaseHistory?.addPurchase(purchaseRecord)
            
            // Grant the item benefits
            grantItemBenefits(item, to: playerId)
            
            // Track analytics
            analyticsEngine.trackEvent(.purchaseCompleted, parameters: [
                "item_id": .string(item.productId),
                "item_type": .string(item.itemType.rawValue),
                "price": .double(item.price.doubleValue),
                "transaction_id": .string(transaction.id.description)
            ])
            
            // Finish the transaction
            await transaction.finish()
            
            purchaseInProgress = false
            logger.info("Purchase completed: \(item.name)")
            
            return .success(purchaseRecord)
            
        case .unverified(let transaction, let error):
            purchaseInProgress = false
            analyticsEngine.trackError(error, context: "purchase_verification")
            await transaction.finish()
            return .failure(.verificationFailed)
        }
    }
    
    private func grantItemBenefits(_ item: PremiumItem, to playerId: UUID) {
        // Implementation would grant the actual benefits
        // This could involve updating player data, unlocking features, etc.
        logger.info("Granted benefits for \(item.name) to player \(playerId)")
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableItems() {
        // Load from configuration or server
        availableItems = createDefaultItems()
    }
    
    private func createDefaultItems() -> [PremiumItem] {
        return [
            // Cosmetic items (fully ethical)
            PremiumItem(
                productId: "ship_skin_golden",
                itemType: .shipSkin,
                name: "Golden Ship Skin",
                description: "Make your ships gleam with this luxurious golden finish",
                price: 4.99,
                currencyCode: "USD",
                category: .cosmetics,
                rarity: .epic,
                benefits: [
                    PremiumBenefit(
                        benefitType: .visualCustomization,
                        description: "Golden visual effect for all ships",
                        isCosmetic: true
                    )
                ]
            ),
            
            // Quality of life improvements
            PremiumItem(
                productId: "auto_save_plus",
                itemType: .autoSave,
                name: "Auto-Save Plus",
                description: "Never lose progress with enhanced auto-save every 30 seconds",
                price: 2.99,
                currencyCode: "USD",
                category: .features,
                rarity: .common,
                benefits: [
                    PremiumBenefit(
                        benefitType: .automationFeature,
                        description: "Automatic save every 30 seconds"
                    )
                ]
            ),
            
            // Content expansion
            PremiumItem(
                productId: "historical_scenarios",
                itemType: .historicalScenarios,
                name: "Historical Trade Routes",
                description: "Experience famous trade routes from maritime history",
                price: 9.99,
                currencyCode: "USD",
                category: .content,
                rarity: .legendary,
                benefits: [
                    PremiumBenefit(
                        benefitType: .additionalContent,
                        description: "Access to 12 historical scenarios"
                    )
                ]
            )
        ]
    }
    
    private func setupStoreObserver() {
        // Set up StoreKit transaction observer
        Task {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Handle updated transaction
                    await transaction.finish()
                case .unverified(_, let error):
                    logger.error("Unverified transaction: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setupEthicalMonitoring() {
        // Monitor for concerning patterns every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performEthicalAudit()
            }
            .store(in: &cancellables)
    }
    
    private func performEthicalAudit() {
        guard let history = purchaseHistory else { return }
        
        // Check for concerning patterns and flag if necessary
        var auditFlags: [String] = []
        
        if history.protectionFlags.contains(.rapidSpending) {
            auditFlags.append("rapid_spending_detected")
        }
        
        if history.totalSpent > 500 {
            auditFlags.append("high_lifetime_spending")
        }
        
        if !auditFlags.isEmpty {
            analyticsEngine.trackEvent(.featureUsed, parameters: [
                "feature_name": .string("ethical_audit"),
                "flags": .array(auditFlags.map { .string($0) })
            ])
        }
    }
    
    // MARK: - Recommendation Helpers
    
    private func getEconomicPlayerRecommendations() -> [ItemRecommendation] {
        return [
            ItemRecommendation(
                item: availableItems.first { $0.itemType == .advancedAnalytics } ?? availableItems[0],
                reason: "Enhanced analytics for strategic economic decisions",
                confidence: 0.8
            )
        ]
    }
    
    private func getSocialPlayerRecommendations() -> [ItemRecommendation] {
        return [
            ItemRecommendation(
                item: availableItems.first { $0.itemType == .avatarCustomization } ?? availableItems[0],
                reason: "Stand out in multiplayer interactions",
                confidence: 0.7
            )
        ]
    }
    
    private func getCasualPlayerRecommendations() -> [ItemRecommendation] {
        return [
            ItemRecommendation(
                item: availableItems.first { $0.itemType == .autoSave } ?? availableItems[0],
                reason: "Never lose progress during casual play sessions",
                confidence: 0.9
            )
        ]
    }
    
    private func getHardcorePlayerRecommendations() -> [ItemRecommendation] {
        return [
            ItemRecommendation(
                item: availableItems.first { $0.itemType == .additionalCampaigns } ?? availableItems[0],
                reason: "New challenges for experienced players",
                confidence: 0.85
            )
        ]
    }
    
    private func getGenericRecommendations() -> [ItemRecommendation] {
        return availableItems.filter { $0.ethicalScore.score >= 0.9 }.map { item in
            ItemRecommendation(
                item: item,
                reason: "Popular cosmetic enhancement",
                confidence: 0.5
            )
        }
    }
    
    private func getNewPlayerSafeItems() -> [PremiumItem] {
        return availableItems.filter { 
            $0.ethicalScore.score >= 0.9 && $0.price <= 5.0 
        }
    }
    
    private func getDailySpending(_ history: PurchaseHistory) -> Decimal? {
        let today = Calendar.current.startOfDay(for: Date())
        let todayPurchases = history.purchases.filter { 
            Calendar.current.isDate($0.purchaseDate, inSameDayAs: today)
        }
        
        return todayPurchases.reduce(0) { $0 + $1.amount }
    }
    
    private func getMonthlySpending(_ history: PurchaseHistory) -> Decimal? {
        let currentMonth = DateFormatter.monthYear.string(from: Date())
        return history.monthlySpending[currentMonth]
    }
    
    private func getTodayPurchases(for productId: String, history: PurchaseHistory) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return history.purchases.filter { 
            $0.productId == productId && 
            Calendar.current.isDate($0.purchaseDate, inSameDayAs: today)
        }.count
    }
}

// MARK: - Supporting Types

public struct ItemRecommendation: Identifiable {
    public let id = UUID()
    public let item: PremiumItem
    public let reason: String
    public let confidence: Double // 0.0 to 1.0
    
    public init(item: PremiumItem, reason: String, confidence: Double) {
        self.item = item
        self.reason = reason
        self.confidence = confidence
    }
}

public enum PurchaseResult {
    case success(PurchaseRecord)
    case failure(PurchaseError)
}

public enum PurchaseError: Error, CustomStringConvertible {
    case purchaseInProgress
    case productNotFound
    case userCancelled
    case purchasePending
    case systemError(Error)
    case verificationFailed
    case dailyLimitExceeded
    case monthlyLimitExceeded
    case newPlayerProtection
    case cooldownActive
    case protectionFlagActive
    case itemLimitExceeded
    case spendingCapReached
    case unknown
    
    public var description: String {
        switch self {
        case .purchaseInProgress:
            return "Another purchase is already in progress"
        case .productNotFound:
            return "Product not found in store"
        case .userCancelled:
            return "Purchase cancelled by user"
        case .purchasePending:
            return "Purchase is pending approval"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .verificationFailed:
            return "Purchase verification failed"
        case .dailyLimitExceeded:
            return "Daily spending limit exceeded"
        case .monthlyLimitExceeded:
            return "Monthly spending limit exceeded"
        case .newPlayerProtection:
            return "New player protection active"
        case .cooldownActive:
            return "Please wait before making another purchase"
        case .protectionFlagActive:
            return "Purchase protection active"
        case .itemLimitExceeded:
            return "Item purchase limit exceeded"
        case .spendingCapReached:
            return "Spending cap reached"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}