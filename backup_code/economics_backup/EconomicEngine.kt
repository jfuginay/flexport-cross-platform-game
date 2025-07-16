package com.flexport.economics

import com.flexport.economics.state.EconomicStateManager
import com.flexport.economics.models.*
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.SharedFlow

/**
 * Main economic engine for the FlexPort game
 * Provides a high-level API for all economic operations
 */
class EconomicEngine {
    
    private val stateManager = EconomicStateManager()
    
    // Public API for economic state observation
    val economicState: StateFlow<EconomicState> = stateManager.economicState
    val marketUpdates: SharedFlow<MarketUpdate> = stateManager.marketUpdates
    val economicEvents: SharedFlow<EconomicEventNotification> = stateManager.economicEvents
    
    /**
     * Initialize the economic engine
     */
    fun initialize() {
        // Economic engine starts automatically when created
        println("Economic Engine initialized successfully")
    }
    
    // Market Operations
    
    /**
     * Place a buy order for a commodity
     */
    fun placeBuyOrder(
        commodityType: CommodityType,
        quantity: Double,
        pricePerUnit: Double,
        buyerId: String
    ): String? {
        return stateManager.getGoodsMarket(commodityType)?.addBuyOrder(
            quantity, pricePerUnit, buyerId
        )
    }
    
    /**
     * Place a sell order for a commodity
     */
    fun placeSellOrder(
        commodityType: CommodityType,
        quantity: Double,
        pricePerUnit: Double,
        sellerId: String
    ): String? {
        return stateManager.getGoodsMarket(commodityType)?.addSellOrder(
            quantity, pricePerUnit, sellerId
        )
    }
    
    /**
     * Cancel an order
     */
    fun cancelOrder(commodityType: CommodityType, orderId: String): Boolean {
        return stateManager.getGoodsMarket(commodityType)?.cancelOrder(orderId) ?: false
    }
    
    /**
     * Get current commodity price
     */
    fun getCommodityPrice(commodityType: CommodityType): Double {
        return stateManager.getGoodsMarket(commodityType)?.getMarketStats()?.currentPrice ?: 0.0
    }
    
    /**
     * Get market statistics for a commodity
     */
    fun getCommodityMarketStats(commodityType: CommodityType): MarketStats? {
        return stateManager.getGoodsMarket(commodityType)?.getMarketStats()
    }
    
    // Capital Market Operations
    
    /**
     * Issue a bond
     */
    fun issueBond(
        issuerId: String,
        principal: Double,
        couponRate: Double,
        maturityYears: Int,
        rating: CreditRating = CreditRating.BBB
    ): Bond {
        return stateManager.getCapitalMarket().issueBond(
            issuerId, principal, couponRate, maturityYears, rating
        )
    }
    
    /**
     * Issue equity (IPO)
     */
    fun issueEquity(
        companyId: String,
        shares: Long,
        initialPrice: Double,
        sector: String,
        beta: Double = 1.0
    ): Equity {
        return stateManager.getCapitalMarket().issueEquity(
            companyId, shares, initialPrice, sector, beta
        )
    }
    
    /**
     * Create a loan
     */
    fun createLoan(
        lenderId: String,
        borrowerId: String,
        principal: Double,
        interestRate: Double,
        termMonths: Int,
        collateral: String? = null
    ): Loan {
        return stateManager.getCapitalMarket().createLoan(
            lenderId, borrowerId, principal, interestRate, termMonths, collateral
        )
    }
    
    /**
     * Get current market conditions
     */
    fun getMarketConditions(): MarketConditions {
        return stateManager.getCapitalMarket().getMarketConditions()
    }
    
    // Asset Market Operations
    
    /**
     * List a ship for sale
     */
    fun listShip(
        ownerId: String,
        model: String,
        capacity: Double,
        age: Int,
        condition: AssetCondition,
        specifications: ShipSpecifications
    ): Ship {
        return stateManager.getAssetMarket().listShip(
            ownerId, model, capacity, age, condition, specifications
        )
    }
    
    /**
     * List an aircraft for sale
     */
    fun listAircraft(
        ownerId: String,
        model: String,
        cargoCapacity: Double,
        passengerCapacity: Int,
        range: Double,
        age: Int,
        condition: AssetCondition,
        specifications: AircraftSpecifications
    ): Aircraft {
        return stateManager.getAssetMarket().listAircraft(
            ownerId, model, cargoCapacity, passengerCapacity, range, age, condition, specifications
        )
    }
    
    /**
     * List a warehouse for sale
     */
    fun listWarehouse(
        ownerId: String,
        location: String,
        storageCapacity: Double,
        specifications: WarehouseSpecifications
    ): Warehouse {
        return stateManager.getAssetMarket().listWarehouse(
            ownerId, location, storageCapacity, specifications
        )
    }
    
    /**
     * Create a lease agreement
     */
    fun createLeaseAgreement(
        assetId: String,
        lesseeId: String,
        monthlyPayment: Double,
        termMonths: Int,
        maintenanceIncluded: Boolean = false
    ): LeaseAgreement {
        return stateManager.getAssetMarket().createLeaseAgreement(
            assetId, lesseeId, monthlyPayment, termMonths, maintenanceIncluded
        )
    }
    
    /**
     * Get asset market statistics
     */
    fun getAssetMarketStats(assetType: AssetType): AssetMarketStats {
        return stateManager.getAssetMarket().getAssetTypeStats(assetType)
    }
    
    // Labor Market Operations
    
    /**
     * Post a job opening
     */
    fun postJobOpening(
        employerId: String,
        type: EmployeeType,
        requiredSkillLevel: SkillLevel,
        offeredSalary: Double,
        benefits: Benefits,
        jobDescription: String
    ): JobPosting {
        return stateManager.getLaborMarket().postJobOpening(
            employerId, type, requiredSkillLevel, offeredSalary, benefits, jobDescription
        )
    }
    
    /**
     * Hire a worker
     */
    fun hireWorker(
        employerId: String,
        workerId: String,
        agreedSalary: Double,
        contractType: ContractType,
        contractDuration: Int? = null
    ): EmploymentContract {
        return stateManager.getLaborMarket().hireWorker(
            employerId, workerId, agreedSalary, contractType, contractDuration
        )
    }
    
    /**
     * Terminate employment contract
     */
    fun terminateContract(
        contractId: String,
        reason: TerminationReason,
        severanceMultiplier: Double = 1.0
    ) {
        stateManager.getLaborMarket().terminateContract(contractId, reason, severanceMultiplier)
    }
    
    /**
     * Create a training program
     */
    fun createTrainingProgram(
        organizerId: String,
        targetType: EmployeeType,
        fromLevel: SkillLevel,
        toLevel: SkillLevel,
        durationWeeks: Int,
        costPerParticipant: Double
    ): TrainingProgram {
        return stateManager.getLaborMarket().createTrainingProgram(
            organizerId, targetType, fromLevel, toLevel, durationWeeks, costPerParticipant
        )
    }
    
    /**
     * Get labor market statistics
     */
    fun getLaborMarketStats(): LaborMarketStats {
        return stateManager.getLaborMarket().getLaborMarketStats()
    }
    
    // Trade Route Operations
    
    /**
     * Calculate route profitability
     */
    fun calculateRouteProfitability(route: TradeRoute): RouteProfitability {
        return stateManager.getProfitabilityEngine().calculateRouteProfitability(route)
    }
    
    /**
     * Find optimal routes
     */
    fun findOptimalRoutes(
        origin: Location,
        availableCargo: List<CargoItem>,
        maxRoutes: Int = 10
    ): List<RouteProfitability> {
        return stateManager.getProfitabilityEngine().findOptimalRoutes(
            origin, availableCargo, maxRoutes
        )
    }
    
    /**
     * Optimize cargo mix
     */
    fun optimizeCargoMix(
        route: TradeRoute,
        availableCargo: List<CargoItem>,
        capacityConstraint: Double
    ): CargoOptimization {
        return stateManager.getProfitabilityEngine().optimizeCargoMix(
            route, availableCargo, capacityConstraint
        )
    }
    
    /**
     * Analyze route performance
     */
    fun analyzeRoutePerformance(routeId: String, timeWindow: Long): RoutePerformanceAnalysis {
        return stateManager.getProfitabilityEngine().analyzeRoutePerformance(routeId, timeWindow)
    }
    
    // System Operations
    
    /**
     * Get current economic indicators
     */
    fun getEconomicIndicators(): EconomicIndicators {
        return stateManager.economicState.value.economicIndicators
    }
    
    /**
     * Get system performance metrics
     */
    fun getPerformanceMetrics(): PerformanceMetrics {
        return stateManager.getPerformanceMetrics()
    }
    
    /**
     * Set update frequency
     */
    fun setUpdateInterval(intervalMs: Long) {
        stateManager.setUpdateInterval(intervalMs)
    }
    
    /**
     * Save current economic state
     */
    suspend fun saveState(): Boolean {
        return stateManager.saveState()
    }
    
    /**
     * Load economic state
     */
    suspend fun loadState(): Boolean {
        return stateManager.loadState()
    }
    
    /**
     * Get summary of all markets
     */
    fun getMarketSummary(): MarketSummary {
        val currentState = stateManager.economicState.value
        
        return MarketSummary(
            commodityMarkets = currentState.commodityPrices.map { (commodity, price) ->
                CommodityMarketSummary(
                    commodity = commodity,
                    currentPrice = price,
                    priceChange24h = getCommodityMarketStats(
                        CommodityType.valueOf(commodity)
                    )?.priceChange24h ?: 0.0
                )
            },
            capitalMarket = CapitalMarketSummary(
                interestRate = currentState.marketConditions.baseInterestRate,
                marketIndex = currentState.marketConditions.marketIndex,
                volatility = currentState.marketConditions.marketVolatility
            ),
            laborMarket = LaborMarketSummary(
                averageUnemployment = currentState.laborStatistics.unemploymentRates.values.average(),
                totalEmployed = currentState.laborStatistics.totalEmployed,
                totalUnemployed = currentState.laborStatistics.totalUnemployed
            ),
            economicHealth = EconomicHealthIndicator(
                gdpGrowth = currentState.economicIndicators.gdpGrowthRate,
                inflation = currentState.economicIndicators.inflationRate,
                unemployment = currentState.economicIndicators.unemploymentRate,
                confidence = currentState.economicIndicators.marketConfidenceIndex
            )
        )
    }
    
    /**
     * Shutdown the economic engine
     */
    fun shutdown() {
        stateManager.shutdown()
        println("Economic Engine shut down")
    }
}

// Summary data classes

data class MarketSummary(
    val commodityMarkets: List<CommodityMarketSummary>,
    val capitalMarket: CapitalMarketSummary,
    val laborMarket: LaborMarketSummary,
    val economicHealth: EconomicHealthIndicator
)

data class CommodityMarketSummary(
    val commodity: String,
    val currentPrice: Double,
    val priceChange24h: Double
)

data class CapitalMarketSummary(
    val interestRate: Double,
    val marketIndex: Double,
    val volatility: Double
)

data class LaborMarketSummary(
    val averageUnemployment: Double,
    val totalEmployed: Int,
    val totalUnemployed: Int
)

data class EconomicHealthIndicator(
    val gdpGrowth: Double,
    val inflation: Double,
    val unemployment: Double,
    val confidence: Double
) {
    val overallHealth: HealthStatus
        get() = when {
            gdpGrowth > 3.0 && inflation < 3.0 && unemployment < 5.0 && confidence > 70.0 -> HealthStatus.EXCELLENT
            gdpGrowth > 1.0 && inflation < 5.0 && unemployment < 8.0 && confidence > 50.0 -> HealthStatus.GOOD
            gdpGrowth > -1.0 && inflation < 8.0 && unemployment < 12.0 && confidence > 30.0 -> HealthStatus.FAIR
            else -> HealthStatus.POOR
        }
}

enum class HealthStatus {
    EXCELLENT,
    GOOD,
    FAIR,
    POOR
}