package com.flexport.assets.economics

import com.flexport.assets.models.*
import com.flexport.assets.assignment.AssetAssignment
import com.flexport.assets.analytics.AssetPerformanceData
import com.flexport.economics.models.AssetCondition
import com.flexport.economics.EconomicEngine
import com.flexport.economics.markets.AssetMarket
import kotlinx.coroutines.flow.*
import java.time.LocalDateTime
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*

/**
 * Integrates asset management with the economic engine for realistic market dynamics,
 * cost calculations, revenue optimization, and economic event impacts
 */
class AssetEconomicIntegration(
    private val economicEngine: EconomicEngine,
    private val assetMarket: AssetMarket
) {
    
    private val economicImpacts = ConcurrentHashMap<String, EconomicImpactData>()
    private val marketInfluences = ConcurrentHashMap<String, MarketInfluenceData>()
    private val revenueModels = ConcurrentHashMap<AssetType, RevenueModel>()
    private val costModels = ConcurrentHashMap<AssetType, CostModel>()
    
    // Economic factors that affect asset operations
    private val _economicFactors = MutableStateFlow(EconomicFactors.default())
    val economicFactors: StateFlow<EconomicFactors> = _economicFactors.asStateFlow()
    
    init {
        initializeRevenueModels()
        initializeCostModels()
        
        // Subscribe to economic events
        economicEngine.economicEvents.onEach { event ->
            processEconomicEvent(event)
        }.launchIn(kotlinx.coroutines.GlobalScope)
    }
    
    /**
     * Calculate real-time operating costs for an asset
     */
    fun calculateOperatingCosts(
        asset: FlexPortAsset,
        operationContext: OperationContext
    ): OperatingCostBreakdown {
        val costModel = costModels[asset.assetType] ?: getDefaultCostModel(asset.assetType)
        val factors = _economicFactors.value
        
        val baseCosts = when (asset) {
            is ContainerShip -> calculateShipOperatingCosts(asset, operationContext, factors)
            is CargoAircraft -> calculateAircraftOperatingCosts(asset, operationContext, factors)
            is Warehouse -> calculateWarehouseOperatingCosts(asset, operationContext, factors)
            else -> OperatingCostBreakdown.empty()
        }
        
        // Apply market conditions and economic factors
        val adjustedCosts = applyMarketAdjustments(baseCosts, asset, factors)
        
        // Apply asset-specific multipliers
        val finalCosts = applyAssetConditionMultipliers(adjustedCosts, asset)
        
        return finalCosts
    }
    
    /**
     * Calculate potential revenue for an asset assignment
     */
    fun calculatePotentialRevenue(
        asset: FlexPortAsset,
        assignment: AssetAssignment,
        marketConditions: MarketConditions
    ): RevenueProjection {
        val revenueModel = revenueModels[asset.assetType] ?: getDefaultRevenueModel(asset.assetType)
        val factors = _economicFactors.value
        
        val baseRevenue = when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> calculateShipRevenue(asset as ContainerShip, assignment, marketConditions)
            AssetType.CARGO_AIRCRAFT -> calculateAircraftRevenue(asset as CargoAircraft, assignment, marketConditions)
            AssetType.WAREHOUSE -> calculateWarehouseRevenue(asset as Warehouse, assignment, marketConditions)
            else -> 0.0
        }
        
        // Apply economic factors
        val adjustedRevenue = baseRevenue * factors.demandMultiplier * factors.inflationFactor
        
        // Calculate risk-adjusted revenue
        val riskAdjustment = calculateRiskAdjustment(asset, assignment, marketConditions)
        val finalRevenue = adjustedRevenue * riskAdjustment
        
        return RevenueProjection(
            baseRevenue = baseRevenue,
            adjustedRevenue = adjustedRevenue,
            riskAdjustedRevenue = finalRevenue,
            riskFactor = riskAdjustment,
            confidence = calculateRevenueConfidence(asset, assignment, marketConditions),
            timeHorizon = assignment.estimatedDuration ?: 24,
            marketFactors = extractRevenueFactors(factors, marketConditions)
        )
    }
    
    /**
     * Evaluate asset ROI considering economic conditions
     */
    fun evaluateAssetROI(
        asset: FlexPortAsset,
        performanceData: AssetPerformanceData,
        timeHorizonMonths: Int
    ): ROIAnalysis {
        val factors = _economicFactors.value
        
        // Historical performance
        val historicalROI = if (performanceData.totalOperatingCosts > 0) {
            (performanceData.totalRevenue - performanceData.totalOperatingCosts) / 
            performanceData.totalOperatingCosts
        } else 0.0
        
        // Future projections
        val projectedAnnualRevenue = projectAnnualRevenue(asset, performanceData, factors)
        val projectedAnnualCosts = projectAnnualCosts(asset, performanceData, factors)
        val projectedROI = if (projectedAnnualCosts > 0) {
            (projectedAnnualRevenue - projectedAnnualCosts) / projectedAnnualCosts
        } else 0.0
        
        // Risk-adjusted ROI
        val riskProfile = assessAssetRiskProfile(asset, performanceData)
        val riskAdjustedROI = projectedROI * (1.0 - riskProfile.overallRisk)
        
        // Time value adjustments
        val discountRate = factors.interestRate + riskProfile.overallRisk
        val netPresentValue = calculateNPV(
            asset.currentValue,
            projectedAnnualRevenue - projectedAnnualCosts,
            discountRate,
            timeHorizonMonths / 12.0
        )
        
        return ROIAnalysis(
            historicalROI = historicalROI,
            projectedROI = projectedROI,
            riskAdjustedROI = riskAdjustedROI,
            netPresentValue = netPresentValue,
            paybackPeriod = calculatePaybackPeriod(asset, projectedAnnualRevenue - projectedAnnualCosts),
            internalRateOfReturn = calculateIRR(asset, projectedAnnualRevenue - projectedAnnualCosts, timeHorizonMonths),
            riskProfile = riskProfile,
            economicSensitivity = calculateEconomicSensitivity(asset, factors)
        )
    }
    
    /**
     * Optimize asset portfolio for economic conditions
     */
    fun optimizeAssetPortfolio(
        assets: List<FlexPortAsset>,
        optimizationObjective: OptimizationObjective,
        constraints: PortfolioConstraints
    ): PortfolioOptimization {
        val factors = _economicFactors.value
        
        // Calculate efficiency scores for each asset
        val assetScores = assets.map { asset ->
            val score = when (optimizationObjective) {
                OptimizationObjective.MAXIMIZE_ROI -> calculateROIScore(asset, factors)
                OptimizationObjective.MINIMIZE_RISK -> calculateRiskScore(asset, factors)
                OptimizationObjective.MAXIMIZE_UTILIZATION -> calculateUtilizationScore(asset, factors)
                OptimizationObjective.BALANCED -> calculateBalancedScore(asset, factors)
            }
            AssetScore(asset.id, asset.assetType, score)
        }.sortedByDescending { it.score }
        
        // Apply portfolio optimization algorithm
        val optimizedAllocation = optimizeAllocation(assetScores, constraints, factors)
        
        // Generate recommendations
        val recommendations = generatePortfolioRecommendations(assets, assetScores, optimizedAllocation, factors)
        
        return PortfolioOptimization(
            objective = optimizationObjective,
            assetScores = assetScores,
            optimizedAllocation = optimizedAllocation,
            recommendations = recommendations,
            expectedReturn = optimizedAllocation.values.sum(),
            riskLevel = calculatePortfolioRisk(optimizedAllocation, assets, factors),
            economicJustification = generateEconomicJustification(optimizedAllocation, factors)
        )
    }
    
    /**
     * Calculate asset valuation using economic models
     */
    fun calculateAssetValuation(
        asset: FlexPortAsset,
        valuationMethod: ValuationMethod,
        marketData: MarketData
    ): AssetValuation {
        val factors = _economicFactors.value
        
        val valuations = when (valuationMethod) {
            ValuationMethod.BOOK_VALUE -> calculateBookValue(asset)
            ValuationMethod.MARKET_VALUE -> calculateMarketValue(asset, marketData, factors)
            ValuationMethod.INCOME_APPROACH -> calculateIncomeValue(asset, factors)
            ValuationMethod.REPLACEMENT_COST -> calculateReplacementCost(asset, factors)
            ValuationMethod.LIQUIDATION_VALUE -> calculateLiquidationValue(asset, factors)
            ValuationMethod.COMPREHENSIVE -> calculateComprehensiveValue(asset, marketData, factors)
        }
        
        return valuations
    }
    
    /**
     * Analyze market timing for asset transactions
     */
    fun analyzeMarketTiming(
        assetType: AssetType,
        transactionType: TransactionType,
        timeHorizon: Int
    ): MarketTimingAnalysis {
        val factors = _economicFactors.value
        val marketCycles = analyzeMarketCycles(assetType, factors)
        
        val currentPhase = determineMarketPhase(assetType, factors)
        val optimalTiming = calculateOptimalTiming(assetType, transactionType, marketCycles, factors)
        val riskFactors = identifyTimingRisks(assetType, transactionType, factors)
        
        return MarketTimingAnalysis(
            assetType = assetType,
            transactionType = transactionType,
            currentMarketPhase = currentPhase,
            optimalTimingWindow = optimalTiming,
            marketCycles = marketCycles,
            riskFactors = riskFactors,
            confidence = calculateTimingConfidence(assetType, factors),
            economicIndicators = extractTimingIndicators(factors)
        )
    }
    
    /**
     * Process economic events and update asset impacts
     */
    private fun processEconomicEvent(event: EconomicEvent) {
        when (event) {
            is FuelPriceEvent -> updateFuelPriceImpacts(event)
            is InterestRateEvent -> updateInterestRateImpacts(event)
            is InflationEvent -> updateInflationImpacts(event)
            is TradeEvent -> updateTradeImpacts(event)
            is CommodityEvent -> updateCommodityImpacts(event)
            is GeopoliticalEvent -> updateGeopoliticalImpacts(event)
            is RegulatoryEvent -> updateRegulatoryImpacts(event)
        }
        
        // Update economic factors
        updateEconomicFactors()
    }
    
    // Private calculation methods
    private fun calculateShipOperatingCosts(
        ship: ContainerShip,
        context: OperationContext,
        factors: EconomicFactors
    ): OperatingCostBreakdown {
        val fuelCost = ship.specifications.fuelConsumption * 
                      factors.fuelPrice * 
                      context.operatingHours *
                      factors.carbonTaxMultiplier
        
        val crewCost = (ship.crewAssignment?.getTotalDailyCost() ?: 0.0) * 
                      factors.laborCostMultiplier *
                      (context.operatingHours / 24.0)
        
        val portFees = if (context.inPort) {
            ship.specifications.deadweightTonnage * 
            factors.portFeeMultiplier * 
            2.0 // Base rate per DWT
        } else 0.0
        
        val maintenanceCost = ship.calculateMaintenanceCost() * 
                            factors.maintenanceCostMultiplier *
                            (context.operatingHours / 8760.0) // Annualized
        
        val insuranceCost = ship.currentValue * 
                          factors.insuranceRateMultiplier * 
                          0.02 * // 2% base rate
                          (context.operatingHours / 8760.0)
        
        return OperatingCostBreakdown(
            fuelCost = fuelCost,
            crewCost = crewCost,
            maintenanceCost = maintenanceCost,
            insuranceCost = insuranceCost,
            portFees = portFees,
            regulatoryCosts = calculateRegulatoryComplianceCosts(ship, factors),
            otherCosts = 0.0
        )
    }
    
    private fun calculateAircraftOperatingCosts(
        aircraft: CargoAircraft,
        context: OperationContext,
        factors: EconomicFactors
    ): OperatingCostBreakdown {
        val fuelCost = aircraft.specifications.fuelConsumptionPerHour * 
                      factors.aviationFuelPrice * 
                      context.operatingHours *
                      factors.carbonTaxMultiplier
        
        val crewCost = (aircraft.crewAssignment?.getTotalDailyCost() ?: 0.0) * 
                      factors.laborCostMultiplier *
                      (context.operatingHours / 24.0)
        
        val landingFees = if (context.inPort) {
            aircraft.specifications.maxTakeoffWeight * 
            factors.airportFeeMultiplier * 
            0.05 // Base rate per kg
        } else 0.0
        
        val maintenanceCost = aircraft.calculateMaintenanceCost() * 
                            factors.maintenanceCostMultiplier *
                            (context.operatingHours / 8760.0)
        
        val insuranceCost = aircraft.currentValue * 
                          factors.insuranceRateMultiplier * 
                          0.025 * // 2.5% base rate for aircraft
                          (context.operatingHours / 8760.0)
        
        return OperatingCostBreakdown(
            fuelCost = fuelCost,
            crewCost = crewCost,
            maintenanceCost = maintenanceCost,
            insuranceCost = insuranceCost,
            portFees = landingFees,
            regulatoryCosts = calculateRegulatoryComplianceCosts(aircraft, factors),
            otherCosts = 0.0
        )
    }
    
    private fun calculateWarehouseOperatingCosts(
        warehouse: Warehouse,
        context: OperationContext,
        factors: EconomicFactors
    ): OperatingCostBreakdown {
        val utilityCost = warehouse.specifications.floorArea * 
                         factors.energyCostMultiplier * 
                         3.0 * // Base rate per sqm per day
                         (context.operatingHours / 24.0)
        
        val staffCost = (warehouse.staffing?.getTotalMonthlyCost() ?: 0.0) * 
                       factors.laborCostMultiplier *
                       (context.operatingHours / (24.0 * 30.0))
        
        val maintenanceCost = warehouse.calculateMaintenanceCost() * 
                            factors.maintenanceCostMultiplier *
                            (context.operatingHours / 8760.0)
        
        val insuranceCost = warehouse.currentValue * 
                          factors.insuranceRateMultiplier * 
                          0.01 * // 1% base rate for real estate
                          (context.operatingHours / 8760.0)
        
        return OperatingCostBreakdown(
            fuelCost = 0.0,
            crewCost = staffCost,
            maintenanceCost = maintenanceCost,
            insuranceCost = insuranceCost,
            portFees = 0.0,
            regulatoryCosts = calculateRegulatoryComplianceCosts(warehouse, factors),
            otherCosts = utilityCost
        )
    }
    
    private fun calculateShipRevenue(
        ship: ContainerShip,
        assignment: AssetAssignment,
        conditions: MarketConditions
    ): Double {
        val baseRate = conditions.containerRates[ship.specifications.containerCapacity.toInt()] ?: 2000.0
        val utilizationRate = ship.getCargoCapacityUtilization()
        val distanceMultiplier = conditions.distanceMultiplier
        val seasonalMultiplier = conditions.seasonalMultiplier
        
        return baseRate * utilizationRate * distanceMultiplier * seasonalMultiplier * ship.specifications.containerCapacity
    }
    
    private fun calculateAircraftRevenue(
        aircraft: CargoAircraft,
        assignment: AssetAssignment,
        conditions: MarketConditions
    ): Double {
        val baseRatePerKg = conditions.airCargoRatePerKg
        val utilizationRate = aircraft.getUtilizationRate()
        val urgencyMultiplier = conditions.urgencyMultiplier
        val distanceMultiplier = conditions.distanceMultiplier
        
        return baseRatePerKg * aircraft.specifications.maxCargoWeight * utilizationRate * 
               urgencyMultiplier * distanceMultiplier
    }
    
    private fun calculateWarehouseRevenue(
        warehouse: Warehouse,
        assignment: AssetAssignment,
        conditions: MarketConditions
    ): Double {
        val baseRatePerCubicMeter = conditions.storageRatePerCubicMeter
        val utilizationRate = warehouse.getUtilizationRate()
        val locationMultiplier = conditions.locationMultiplier
        val demandMultiplier = conditions.demandMultiplier
        
        return baseRatePerCubicMeter * warehouse.specifications.storageVolume * utilizationRate * 
               locationMultiplier * demandMultiplier
    }
    
    private fun calculateRegulatoryComplianceCosts(asset: FlexPortAsset, factors: EconomicFactors): Double {
        return when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> asset.currentValue * 0.001 * factors.regulatoryComplianceMultiplier
            AssetType.CARGO_AIRCRAFT -> asset.currentValue * 0.002 * factors.regulatoryComplianceMultiplier
            AssetType.WAREHOUSE -> asset.currentValue * 0.0005 * factors.regulatoryComplianceMultiplier
            else -> 0.0
        }
    }
    
    private fun initializeRevenueModels() {
        revenueModels[AssetType.CONTAINER_SHIP] = RevenueModel(
            baseRateFunction = { utilization, market -> 2000.0 * utilization * market.demandMultiplier },
            utilizationImpact = 0.8,
            marketSensitivity = 0.6,
            seasonalVariance = 0.2
        )
        
        revenueModels[AssetType.CARGO_AIRCRAFT] = RevenueModel(
            baseRateFunction = { utilization, market -> 5.0 * utilization * market.urgencyMultiplier },
            utilizationImpact = 0.9,
            marketSensitivity = 0.8,
            seasonalVariance = 0.15
        )
        
        revenueModels[AssetType.WAREHOUSE] = RevenueModel(
            baseRateFunction = { utilization, market -> 15.0 * utilization * market.locationMultiplier },
            utilizationImpact = 0.7,
            marketSensitivity = 0.4,
            seasonalVariance = 0.1
        )
    }
    
    private fun initializeCostModels() {
        costModels[AssetType.CONTAINER_SHIP] = CostModel(
            fuelIntensity = 0.8,
            laborIntensity = 0.3,
            maintenanceIntensity = 0.4,
            regulatoryImpact = 0.2
        )
        
        costModels[AssetType.CARGO_AIRCRAFT] = CostModel(
            fuelIntensity = 0.9,
            laborIntensity = 0.4,
            maintenanceIntensity = 0.6,
            regulatoryImpact = 0.3
        )
        
        costModels[AssetType.WAREHOUSE] = CostModel(
            fuelIntensity = 0.1,
            laborIntensity = 0.6,
            maintenanceIntensity = 0.2,
            regulatoryImpact = 0.15
        )
    }
    
    private fun getDefaultRevenueModel(assetType: AssetType): RevenueModel {
        return RevenueModel(
            baseRateFunction = { utilization, _ -> 1000.0 * utilization },
            utilizationImpact = 0.7,
            marketSensitivity = 0.5,
            seasonalVariance = 0.15
        )
    }
    
    private fun getDefaultCostModel(assetType: AssetType): CostModel {
        return CostModel(
            fuelIntensity = 0.5,
            laborIntensity = 0.4,
            maintenanceIntensity = 0.3,
            regulatoryImpact = 0.2
        )
    }
    
    private fun applyMarketAdjustments(
        costs: OperatingCostBreakdown,
        asset: FlexPortAsset,
        factors: EconomicFactors
    ): OperatingCostBreakdown {
        return costs.copy(
            fuelCost = costs.fuelCost * factors.fuelPriceVolatility,
            crewCost = costs.crewCost * factors.laborMarketTightness,
            maintenanceCost = costs.maintenanceCost * factors.supplyChainDisruption,
            insuranceCost = costs.insuranceCost * factors.riskPremium
        )
    }
    
    private fun applyAssetConditionMultipliers(
        costs: OperatingCostBreakdown,
        asset: FlexPortAsset
    ): OperatingCostBreakdown {
        val conditionMultiplier = when (asset.condition) {
            AssetCondition.EXCELLENT -> 0.9
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 1.2
            AssetCondition.POOR -> 1.5
            AssetCondition.NEEDS_REPAIR -> 2.0
        }
        
        return costs.copy(
            maintenanceCost = costs.maintenanceCost * conditionMultiplier,
            fuelCost = costs.fuelCost * (1.0 + (conditionMultiplier - 1.0) * 0.5),
            insuranceCost = costs.insuranceCost * conditionMultiplier
        )
    }
    
    private fun calculateRiskAdjustment(
        asset: FlexPortAsset,
        assignment: AssetAssignment,
        conditions: MarketConditions
    ): Double {
        val baseRisk = 0.95 // 5% base risk discount
        val conditionRisk = when (asset.condition) {
            AssetCondition.EXCELLENT -> 1.0
            AssetCondition.GOOD -> 0.98
            AssetCondition.FAIR -> 0.95
            AssetCondition.POOR -> 0.90
            AssetCondition.NEEDS_REPAIR -> 0.80
        }
        val marketRisk = 1.0 - conditions.volatility * 0.1
        val assignmentRisk = when (assignment.priority) {
            AssignmentPriority.CRITICAL -> 1.05
            AssignmentPriority.HIGH -> 1.02
            AssignmentPriority.NORMAL -> 1.0
            AssignmentPriority.LOW -> 0.95
        }
        
        return baseRisk * conditionRisk * marketRisk * assignmentRisk
    }
    
    private fun calculateRevenueConfidence(
        asset: FlexPortAsset,
        assignment: AssetAssignment,
        conditions: MarketConditions
    ): Double {
        val assetReliability = when (asset.condition) {
            AssetCondition.EXCELLENT -> 0.95
            AssetCondition.GOOD -> 0.90
            AssetCondition.FAIR -> 0.80
            AssetCondition.POOR -> 0.65
            AssetCondition.NEEDS_REPAIR -> 0.40
        }
        
        val marketStability = 1.0 - conditions.volatility
        val assignmentCertainty = when (assignment.status) {
            AssignmentStatus.ACTIVE -> 0.90
            AssignmentStatus.PLANNED -> 0.75
            else -> 0.50
        }
        
        return (assetReliability + marketStability + assignmentCertainty) / 3.0
    }
    
    private fun extractRevenueFactors(factors: EconomicFactors, conditions: MarketConditions): List<String> {
        val factorList = mutableListOf<String>()
        
        if (factors.demandMultiplier > 1.1) factorList.add("High demand")
        if (factors.inflationFactor > 1.05) factorList.add("Inflationary pressure")
        if (conditions.volatility > 0.2) factorList.add("Market volatility")
        if (factors.fuelPrice > 1.2) factorList.add("High fuel costs")
        
        return factorList
    }
    
    private fun projectAnnualRevenue(
        asset: FlexPortAsset,
        performanceData: AssetPerformanceData,
        factors: EconomicFactors
    ): Double {
        val historicalAnnualRevenue = if (performanceData.totalOperatingHours > 0) {
            performanceData.totalRevenue * (8760.0 / performanceData.totalOperatingHours)
        } else 0.0
        
        return historicalAnnualRevenue * factors.demandMultiplier * factors.inflationFactor
    }
    
    private fun projectAnnualCosts(
        asset: FlexPortAsset,
        performanceData: AssetPerformanceData,
        factors: EconomicFactors
    ): Double {
        val historicalAnnualCosts = if (performanceData.totalOperatingHours > 0) {
            performanceData.totalOperatingCosts * (8760.0 / performanceData.totalOperatingHours)
        } else 0.0
        
        val costInflation = (factors.fuelPrice + factors.laborCostMultiplier + factors.maintenanceCostMultiplier) / 3.0
        return historicalAnnualCosts * costInflation
    }
    
    private fun assessAssetRiskProfile(asset: FlexPortAsset, performanceData: AssetPerformanceData): RiskProfile {
        val ageRisk = calculateAgeRisk(asset)
        val utilizationRisk = calculateUtilizationRisk(performanceData)
        val maintenanceRisk = calculateMaintenanceRisk(asset, performanceData)
        val marketRisk = calculateMarketRisk(asset.assetType)
        
        val overallRisk = (ageRisk + utilizationRisk + maintenanceRisk + marketRisk) / 4.0
        
        return RiskProfile(
            overallRisk = overallRisk,
            ageRisk = ageRisk,
            utilizationRisk = utilizationRisk,
            maintenanceRisk = maintenanceRisk,
            marketRisk = marketRisk,
            riskLevel = when {
                overallRisk < 0.2 -> "Low"
                overallRisk < 0.4 -> "Medium"
                overallRisk < 0.7 -> "High"
                else -> "Critical"
            }
        )
    }
    
    private fun calculateAgeRisk(asset: FlexPortAsset): Double {
        val age = java.time.Period.between(asset.purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        return when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> min(age / 25.0, 1.0)
            AssetType.CARGO_AIRCRAFT -> min(age / 20.0, 1.0)
            AssetType.WAREHOUSE -> min(age / 50.0, 1.0)
            else -> min(age / 15.0, 1.0)
        }
    }
    
    private fun calculateUtilizationRisk(performanceData: AssetPerformanceData): Double {
        // Calculate based on utilization variance and trends
        return if (performanceData.utilizationHistory.isNotEmpty()) {
            val avgUtilization = performanceData.utilizationHistory.map { it.utilizationRate }.average()
            max(0.0, 1.0 - avgUtilization * 2.0) // Higher risk for low utilization
        } else 0.5
    }
    
    private fun calculateMaintenanceRisk(asset: FlexPortAsset, performanceData: AssetPerformanceData): Double {
        val maintenanceFrequency = if (performanceData.totalOperatingHours > 0) {
            performanceData.maintenanceEvents / (performanceData.totalOperatingHours / 1000.0)
        } else 0.0
        
        return min(maintenanceFrequency / 2.0, 1.0) // Normalize to 0-1 range
    }
    
    private fun calculateMarketRisk(assetType: AssetType): Double {
        val factors = _economicFactors.value
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> factors.tradeVolatility * 0.8
            AssetType.CARGO_AIRCRAFT -> factors.fuelPriceVolatility * 0.9
            AssetType.WAREHOUSE -> factors.realEstateVolatility * 0.6
            else -> 0.3
        }
    }
    
    private fun calculateNPV(
        initialInvestment: Double,
        annualCashFlow: Double,
        discountRate: Double,
        years: Double
    ): Double {
        var npv = -initialInvestment
        val periods = (years * 12).toInt() // Monthly periods
        val monthlyRate = discountRate / 12.0
        val monthlyCashFlow = annualCashFlow / 12.0
        
        for (period in 1..periods) {
            npv += monthlyCashFlow / (1.0 + monthlyRate).pow(period)
        }
        
        return npv
    }
    
    private fun calculatePaybackPeriod(asset: FlexPortAsset, annualCashFlow: Double): Double {
        return if (annualCashFlow > 0) {
            asset.currentValue / annualCashFlow
        } else Double.POSITIVE_INFINITY
    }
    
    private fun calculateIRR(asset: FlexPortAsset, annualCashFlow: Double, months: Int): Double {
        // Simplified IRR calculation
        val guess = 0.1 // 10% initial guess
        val tolerance = 0.0001
        var rate = guess
        
        // Newton-Raphson method (simplified)
        for (i in 0..100) {
            val npv = calculateNPV(asset.currentValue, annualCashFlow, rate, months / 12.0)
            if (abs(npv) < tolerance) break
            
            val npvDerivative = calculateNPVDerivative(asset.currentValue, annualCashFlow, rate, months / 12.0)
            if (abs(npvDerivative) < tolerance) break
            
            rate = rate - npv / npvDerivative
        }
        
        return rate
    }
    
    private fun calculateNPVDerivative(
        initialInvestment: Double,
        annualCashFlow: Double,
        rate: Double,
        years: Double
    ): Double {
        var derivative = 0.0
        val periods = (years * 12).toInt()
        val monthlyRate = rate / 12.0
        val monthlyCashFlow = annualCashFlow / 12.0
        
        for (period in 1..periods) {
            derivative -= period * monthlyCashFlow / (1.0 + monthlyRate).pow(period + 1)
        }
        
        return derivative / 12.0 // Convert to annual
    }
    
    private fun calculateEconomicSensitivity(asset: FlexPortAsset, factors: EconomicFactors): EconomicSensitivity {
        return EconomicSensitivity(
            fuelPriceSensitivity = calculateFuelSensitivity(asset),
            interestRateSensitivity = calculateInterestRateSensitivity(asset),
            demandSensitivity = calculateDemandSensitivity(asset),
            inflationSensitivity = calculateInflationSensitivity(asset)
        )
    }
    
    private fun calculateFuelSensitivity(asset: FlexPortAsset): Double {
        return when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> 0.7
            AssetType.CARGO_AIRCRAFT -> 0.9
            AssetType.WAREHOUSE -> 0.1
            else -> 0.3
        }
    }
    
    private fun calculateInterestRateSensitivity(asset: FlexPortAsset): Double {
        // Higher sensitivity for capital-intensive assets
        return asset.currentValue / 1000000.0 // Normalize by million
    }
    
    private fun calculateDemandSensitivity(asset: FlexPortAsset): Double {
        return when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> 0.8
            AssetType.CARGO_AIRCRAFT -> 0.9
            AssetType.WAREHOUSE -> 0.6
            else -> 0.5
        }
    }
    
    private fun calculateInflationSensitivity(asset: FlexPortAsset): Double {
        // Real assets generally have good inflation protection
        return when (asset.assetType) {
            AssetType.WAREHOUSE -> 0.3 // Real estate is inflation hedge
            AssetType.CONTAINER_SHIP -> 0.6
            AssetType.CARGO_AIRCRAFT -> 0.7
            else -> 0.5
        }
    }
    
    private fun calculateROIScore(asset: FlexPortAsset, factors: EconomicFactors): Double {
        // Simplified ROI scoring
        return asset.currentValue * factors.demandMultiplier / (factors.fuelPrice * factors.maintenanceCostMultiplier)
    }
    
    private fun calculateRiskScore(asset: FlexPortAsset, factors: EconomicFactors): Double {
        val ageRisk = calculateAgeRisk(asset)
        val marketRisk = calculateMarketRisk(asset.assetType)
        return 1.0 - (ageRisk + marketRisk) / 2.0 // Invert so higher score = lower risk
    }
    
    private fun calculateUtilizationScore(asset: FlexPortAsset, factors: EconomicFactors): Double {
        return asset.getUtilizationRate() * factors.demandMultiplier
    }
    
    private fun calculateBalancedScore(asset: FlexPortAsset, factors: EconomicFactors): Double {
        val roiScore = calculateROIScore(asset, factors)
        val riskScore = calculateRiskScore(asset, factors)
        val utilizationScore = calculateUtilizationScore(asset, factors)
        
        return (roiScore * 0.4 + riskScore * 0.3 + utilizationScore * 0.3)
    }
    
    private fun optimizeAllocation(
        assetScores: List<AssetScore>,
        constraints: PortfolioConstraints,
        factors: EconomicFactors
    ): Map<String, Double> {
        // Simplified portfolio optimization
        val allocation = mutableMapOf<String, Double>()
        var remainingBudget = constraints.maxInvestment
        
        for (score in assetScores) {
            if (remainingBudget <= 0) break
            
            val allocationAmount = min(remainingBudget, constraints.maxPerAsset)
            allocation[score.assetId] = allocationAmount
            remainingBudget -= allocationAmount
        }
        
        return allocation
    }
    
    private fun generatePortfolioRecommendations(
        assets: List<FlexPortAsset>,
        scores: List<AssetScore>,
        allocation: Map<String, Double>,
        factors: EconomicFactors
    ): List<PortfolioRecommendation> {
        val recommendations = mutableListOf<PortfolioRecommendation>()
        
        // Top performers
        scores.take(3).forEach { score ->
            recommendations.add(
                PortfolioRecommendation(
                    type = RecommendationType.INCREASE_ALLOCATION,
                    assetId = score.assetId,
                    reasoning = "Top performer with score ${score.score.format(2)}",
                    impact = RecommendationImpact.HIGH,
                    urgency = RecommendationUrgency.MEDIUM
                )
            )
        }
        
        // Underperformers
        scores.takeLast(2).forEach { score ->
            recommendations.add(
                PortfolioRecommendation(
                    type = RecommendationType.REDUCE_ALLOCATION,
                    assetId = score.assetId,
                    reasoning = "Underperforming with score ${score.score.format(2)}",
                    impact = RecommendationImpact.MEDIUM,
                    urgency = RecommendationUrgency.LOW
                )
            )
        }
        
        return recommendations
    }
    
    private fun calculatePortfolioRisk(
        allocation: Map<String, Double>,
        assets: List<FlexPortAsset>,
        factors: EconomicFactors
    ): Double {
        val assetMap = assets.associateBy { it.id }
        var totalRisk = 0.0
        var totalAllocation = allocation.values.sum()
        
        allocation.forEach { (assetId, amount) ->
            val asset = assetMap[assetId]
            if (asset != null) {
                val weight = amount / totalAllocation
                val assetRisk = calculateMarketRisk(asset.assetType)
                totalRisk += weight * assetRisk
            }
        }
        
        return totalRisk
    }
    
    private fun generateEconomicJustification(
        allocation: Map<String, Double>,
        factors: EconomicFactors
    ): String {
        return buildString {
            append("Portfolio optimization based on current economic conditions: ")
            if (factors.demandMultiplier > 1.1) append("High demand environment favors capacity expansion. ")
            if (factors.fuelPrice > 1.2) append("High fuel costs favor efficient assets. ")
            if (factors.interestRate > 0.05) append("Higher interest rates favor income-generating assets. ")
            append("Allocation optimized for risk-adjusted returns.")
        }
    }
    
    private fun calculateBookValue(asset: FlexPortAsset): AssetValuation {
        val age = java.time.Period.between(asset.purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        val annualDepreciationRate = when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> 0.05
            AssetType.CARGO_AIRCRAFT -> 0.07
            AssetType.WAREHOUSE -> 0.02
            else -> 0.04
        }
        
        val depreciatedValue = asset.purchasePrice * (1.0 - annualDepreciationRate).pow(age)
        
        return AssetValuation(
            method = ValuationMethod.BOOK_VALUE,
            primaryValue = depreciatedValue,
            lowEstimate = depreciatedValue * 0.9,
            highEstimate = depreciatedValue * 1.1,
            confidence = 0.95,
            assumptions = listOf("Straight-line depreciation", "No residual value adjustments"),
            marketFactors = emptyList()
        )
    }
    
    private fun calculateMarketValue(asset: FlexPortAsset, marketData: MarketData, factors: EconomicFactors): AssetValuation {
        val baseMarketValue = marketData.getAveragePrice(asset.assetType) ?: asset.currentValue
        val conditionAdjustment = when (asset.condition) {
            AssetCondition.EXCELLENT -> 1.1
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 0.85
            AssetCondition.POOR -> 0.6
            AssetCondition.NEEDS_REPAIR -> 0.4
        }
        
        val marketValue = baseMarketValue * conditionAdjustment * factors.assetPriceInflation
        
        return AssetValuation(
            method = ValuationMethod.MARKET_VALUE,
            primaryValue = marketValue,
            lowEstimate = marketValue * 0.8,
            highEstimate = marketValue * 1.2,
            confidence = 0.75,
            assumptions = listOf("Market comparables available", "Liquid market conditions"),
            marketFactors = listOf("Asset price inflation: ${(factors.assetPriceInflation - 1.0) * 100}%")
        )
    }
    
    private fun calculateIncomeValue(asset: FlexPortAsset, factors: EconomicFactors): AssetValuation {
        val projectedAnnualRevenue = when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> asset.currentValue * 0.15 * factors.demandMultiplier
            AssetType.CARGO_AIRCRAFT -> asset.currentValue * 0.2 * factors.demandMultiplier
            AssetType.WAREHOUSE -> asset.currentValue * 0.08 * factors.realEstateAppreciation
            else -> asset.currentValue * 0.1
        }
        
        val projectedAnnualCosts = projectedAnnualRevenue * 0.6 // Assume 60% cost ratio
        val netIncome = projectedAnnualRevenue - projectedAnnualCosts
        val capitalizationRate = factors.interestRate + calculateMarketRisk(asset.assetType)
        
        val incomeValue = netIncome / capitalizationRate
        
        return AssetValuation(
            method = ValuationMethod.INCOME_APPROACH,
            primaryValue = incomeValue,
            lowEstimate = incomeValue * 0.7,
            highEstimate = incomeValue * 1.3,
            confidence = 0.65,
            assumptions = listOf("Stable income stream", "Current market rates", "60% cost ratio"),
            marketFactors = listOf("Capitalization rate: ${(capitalizationRate * 100).format(2)}%")
        )
    }
    
    private fun calculateReplacementCost(asset: FlexPortAsset, factors: EconomicFactors): AssetValuation {
        val newAssetCost = asset.purchasePrice * factors.inflationFactor * factors.constructionCostInflation
        val age = java.time.Period.between(asset.purchaseDate.toLocalDate(), LocalDateTime.now().toLocalDate()).years
        val functionalObsolescence = age * 0.02 // 2% per year
        val replacementCost = newAssetCost * (1.0 - functionalObsolescence)
        
        return AssetValuation(
            method = ValuationMethod.REPLACEMENT_COST,
            primaryValue = replacementCost,
            lowEstimate = replacementCost * 0.85,
            highEstimate = replacementCost * 1.15,
            confidence = 0.8,
            assumptions = listOf("Current construction costs", "Linear obsolescence", "Technology unchanged"),
            marketFactors = listOf("Construction cost inflation: ${(factors.constructionCostInflation - 1.0) * 100}%")
        )
    }
    
    private fun calculateLiquidationValue(asset: FlexPortAsset, factors: EconomicFactors): AssetValuation {
        val marketValue = asset.currentValue
        val liquidationDiscounts = when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> 0.4 // 40% discount for forced sale
            AssetType.CARGO_AIRCRAFT -> 0.5 // 50% discount
            AssetType.WAREHOUSE -> 0.25 // 25% discount
            else -> 0.35
        }
        
        val liquidationValue = marketValue * (1.0 - liquidationDiscounts) * factors.assetLiquidity
        
        return AssetValuation(
            method = ValuationMethod.LIQUIDATION_VALUE,
            primaryValue = liquidationValue,
            lowEstimate = liquidationValue * 0.8,
            highEstimate = liquidationValue * 1.0,
            confidence = 0.7,
            assumptions = listOf("Forced sale conditions", "90-day liquidation period"),
            marketFactors = listOf("Market liquidity: ${(factors.assetLiquidity * 100).format(0)}%")
        )
    }
    
    private fun calculateComprehensiveValue(asset: FlexPortAsset, marketData: MarketData, factors: EconomicFactors): AssetValuation {
        val bookValue = calculateBookValue(asset)
        val marketValue = calculateMarketValue(asset, marketData, factors)
        val incomeValue = calculateIncomeValue(asset, factors)
        val replacementValue = calculateReplacementCost(asset, factors)
        
        // Weighted average of different valuation methods
        val weights = mapOf(
            bookValue.primaryValue to 0.2,
            marketValue.primaryValue to 0.3,
            incomeValue.primaryValue to 0.3,
            replacementValue.primaryValue to 0.2
        )
        
        val comprehensiveValue = weights.map { (value, weight) -> value * weight }.sum()
        
        return AssetValuation(
            method = ValuationMethod.COMPREHENSIVE,
            primaryValue = comprehensiveValue,
            lowEstimate = comprehensiveValue * 0.8,
            highEstimate = comprehensiveValue * 1.2,
            confidence = 0.85,
            assumptions = listOf("Multiple valuation methods", "Weighted average approach"),
            marketFactors = listOf("Comprehensive market analysis")
        )
    }
    
    private fun analyzeMarketCycles(assetType: AssetType, factors: EconomicFactors): MarketCycleData {
        // Simplified market cycle analysis
        return MarketCycleData(
            currentPhase = MarketPhase.EXPANSION,
            cycleLength = 60, // months
            positionInCycle = 0.6, // 60% through current cycle
            volatility = calculateMarketRisk(assetType),
            trendStrength = factors.demandMultiplier - 1.0
        )
    }
    
    private fun determineMarketPhase(assetType: AssetType, factors: EconomicFactors): MarketPhase {
        return when {
            factors.demandMultiplier > 1.2 && factors.assetPriceInflation > 1.1 -> MarketPhase.PEAK
            factors.demandMultiplier > 1.1 -> MarketPhase.EXPANSION
            factors.demandMultiplier < 0.9 && factors.assetPriceInflation < 0.95 -> MarketPhase.TROUGH
            factors.demandMultiplier < 0.95 -> MarketPhase.CONTRACTION
            else -> MarketPhase.EXPANSION
        }
    }
    
    private fun calculateOptimalTiming(
        assetType: AssetType,
        transactionType: TransactionType,
        cycles: MarketCycleData,
        factors: EconomicFactors
    ): OptimalTimingWindow {
        val currentPhase = cycles.currentPhase
        
        val optimalMonths = when (transactionType) {
            TransactionType.BUY -> {
                when (currentPhase) {
                    MarketPhase.TROUGH -> 0 // Buy now
                    MarketPhase.CONTRACTION -> 6 // Wait for trough
                    MarketPhase.EXPANSION -> 18 // Wait for next cycle
                    MarketPhase.PEAK -> 12 // Wait for contraction
                }
            }
            TransactionType.SELL -> {
                when (currentPhase) {
                    MarketPhase.PEAK -> 0 // Sell now
                    MarketPhase.EXPANSION -> 6 // Wait for peak
                    MarketPhase.CONTRACTION -> 18 // Wait for next cycle
                    MarketPhase.TROUGH -> 12 // Wait for expansion
                }
            }
        }
        
        return OptimalTimingWindow(
            startMonth = optimalMonths,
            endMonth = optimalMonths + 3,
            expectedPriceMovement = calculateExpectedPriceMovement(currentPhase, transactionType),
            confidence = 0.7
        )
    }
    
    private fun calculateExpectedPriceMovement(phase: MarketPhase, transactionType: TransactionType): Double {
        return when (phase) {
            MarketPhase.TROUGH -> if (transactionType == TransactionType.BUY) 0.15 else -0.05
            MarketPhase.EXPANSION -> if (transactionType == TransactionType.BUY) 0.1 else 0.08
            MarketPhase.PEAK -> if (transactionType == TransactionType.BUY) -0.1 else 0.05
            MarketPhase.CONTRACTION -> if (transactionType == TransactionType.BUY) -0.05 else -0.15
        }
    }
    
    private fun identifyTimingRisks(assetType: AssetType, transactionType: TransactionType, factors: EconomicFactors): List<String> {
        val risks = mutableListOf<String>()
        
        if (factors.fuelPriceVolatility > 0.2) risks.add("High fuel price volatility")
        if (factors.interestRate > 0.06) risks.add("Rising interest rates")
        if (factors.tradeVolatility > 0.15) risks.add("Trade disruption risk")
        if (factors.regulatoryComplianceMultiplier > 1.2) risks.add("Regulatory changes")
        
        return risks
    }
    
    private fun calculateTimingConfidence(assetType: AssetType, factors: EconomicFactors): Double {
        val volatility = calculateMarketRisk(assetType)
        return max(0.5, 1.0 - volatility * 2.0) // Higher volatility = lower confidence
    }
    
    private fun extractTimingIndicators(factors: EconomicFactors): List<String> {
        val indicators = mutableListOf<String>()
        
        indicators.add("Demand multiplier: ${factors.demandMultiplier.format(2)}")
        indicators.add("Fuel price index: ${factors.fuelPrice.format(2)}")
        indicators.add("Interest rate: ${(factors.interestRate * 100).format(1)}%")
        indicators.add("Asset price inflation: ${(factors.assetPriceInflation * 100 - 100).format(1)}%")
        
        return indicators
    }
    
    private fun updateFuelPriceImpacts(event: FuelPriceEvent) {
        val newFactors = _economicFactors.value.copy(
            fuelPrice = event.newPrice / event.baselinePrice,
            fuelPriceVolatility = event.volatility,
            aviationFuelPrice = event.newPrice * 1.8 / event.baselinePrice // Aviation fuel premium
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateInterestRateImpacts(event: InterestRateEvent) {
        val newFactors = _economicFactors.value.copy(
            interestRate = event.newRate,
            assetPriceInflation = 1.0 / (1.0 + event.newRate), // Inverse relationship
            constructionCostInflation = _economicFactors.value.constructionCostInflation * (1.0 + event.newRate * 0.5)
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateInflationImpacts(event: InflationEvent) {
        val newFactors = _economicFactors.value.copy(
            inflationFactor = 1.0 + event.inflationRate,
            laborCostMultiplier = _economicFactors.value.laborCostMultiplier * (1.0 + event.inflationRate),
            maintenanceCostMultiplier = _economicFactors.value.maintenanceCostMultiplier * (1.0 + event.inflationRate * 0.8)
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateTradeImpacts(event: TradeEvent) {
        val newFactors = _economicFactors.value.copy(
            demandMultiplier = when (event.impact) {
                TradeImpact.POSITIVE -> _economicFactors.value.demandMultiplier * 1.1
                TradeImpact.NEGATIVE -> _economicFactors.value.demandMultiplier * 0.9
                TradeImpact.NEUTRAL -> _economicFactors.value.demandMultiplier
            },
            tradeVolatility = event.volatility
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateCommodityImpacts(event: CommodityEvent) {
        val newFactors = _economicFactors.value.copy(
            demandMultiplier = _economicFactors.value.demandMultiplier * (1.0 + event.priceChange * 0.3),
            supplyChainDisruption = if (event.priceChange > 0.2) 1.3 else 1.0
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateGeopoliticalImpacts(event: GeopoliticalEvent) {
        val newFactors = _economicFactors.value.copy(
            riskPremium = _economicFactors.value.riskPremium * (1.0 + event.riskIncrease),
            fuelPriceVolatility = _economicFactors.value.fuelPriceVolatility * (1.0 + event.riskIncrease * 0.5),
            tradeVolatility = _economicFactors.value.tradeVolatility * (1.0 + event.riskIncrease * 0.7)
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateRegulatoryImpacts(event: RegulatoryEvent) {
        val newFactors = _economicFactors.value.copy(
            regulatoryComplianceMultiplier = event.complianceCostMultiplier,
            carbonTaxMultiplier = if (event.type == "Environmental") event.complianceCostMultiplier else _economicFactors.value.carbonTaxMultiplier
        )
        _economicFactors.value = newFactors
    }
    
    private fun updateEconomicFactors() {
        // Trigger recalculation of dependent systems
        // This would notify other systems of economic factor changes
    }
    
    // Helper extension functions
    private fun Double.format(decimals: Int): String = "%.${decimals}f".format(this)
}

// Data classes for economic integration
data class EconomicFactors(
    val demandMultiplier: Double,
    val inflationFactor: Double,
    val fuelPrice: Double,
    val aviationFuelPrice: Double,
    val interestRate: Double,
    val laborCostMultiplier: Double,
    val maintenanceCostMultiplier: Double,
    val insuranceRateMultiplier: Double,
    val portFeeMultiplier: Double,
    val airportFeeMultiplier: Double,
    val energyCostMultiplier: Double,
    val regulatoryComplianceMultiplier: Double,
    val carbonTaxMultiplier: Double,
    val assetPriceInflation: Double,
    val constructionCostInflation: Double,
    val realEstateAppreciation: Double,
    val assetLiquidity: Double,
    val riskPremium: Double,
    val fuelPriceVolatility: Double,
    val tradeVolatility: Double,
    val realEstateVolatility: Double,
    val laborMarketTightness: Double,
    val supplyChainDisruption: Double
) {
    companion object {
        fun default() = EconomicFactors(
            demandMultiplier = 1.0,
            inflationFactor = 1.0,
            fuelPrice = 1.0,
            aviationFuelPrice = 1.0,
            interestRate = 0.05,
            laborCostMultiplier = 1.0,
            maintenanceCostMultiplier = 1.0,
            insuranceRateMultiplier = 1.0,
            portFeeMultiplier = 1.0,
            airportFeeMultiplier = 1.0,
            energyCostMultiplier = 1.0,
            regulatoryComplianceMultiplier = 1.0,
            carbonTaxMultiplier = 1.0,
            assetPriceInflation = 1.0,
            constructionCostInflation = 1.0,
            realEstateAppreciation = 1.0,
            assetLiquidity = 1.0,
            riskPremium = 1.0,
            fuelPriceVolatility = 0.1,
            tradeVolatility = 0.1,
            realEstateVolatility = 0.05,
            laborMarketTightness = 1.0,
            supplyChainDisruption = 1.0
        )
    }
}

data class OperationContext(
    val operatingHours: Double,
    val inPort: Boolean,
    val weatherConditions: String,
    val trafficDensity: Double,
    val urgencyLevel: String
)

data class OperatingCostBreakdown(
    val fuelCost: Double,
    val crewCost: Double,
    val maintenanceCost: Double,
    val insuranceCost: Double,
    val portFees: Double,
    val regulatoryCosts: Double,
    val otherCosts: Double
) {
    val totalCost: Double get() = fuelCost + crewCost + maintenanceCost + insuranceCost + portFees + regulatoryCosts + otherCosts
    
    companion object {
        fun empty() = OperatingCostBreakdown(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    }
}

data class MarketConditions(
    val containerRates: Map<Int, Double>,
    val airCargoRatePerKg: Double,
    val storageRatePerCubicMeter: Double,
    val distanceMultiplier: Double,
    val seasonalMultiplier: Double,
    val urgencyMultiplier: Double,
    val locationMultiplier: Double,
    val demandMultiplier: Double,
    val volatility: Double
)

data class RevenueProjection(
    val baseRevenue: Double,
    val adjustedRevenue: Double,
    val riskAdjustedRevenue: Double,
    val riskFactor: Double,
    val confidence: Double,
    val timeHorizon: Int,
    val marketFactors: List<String>
)

data class ROIAnalysis(
    val historicalROI: Double,
    val projectedROI: Double,
    val riskAdjustedROI: Double,
    val netPresentValue: Double,
    val paybackPeriod: Double,
    val internalRateOfReturn: Double,
    val riskProfile: RiskProfile,
    val economicSensitivity: EconomicSensitivity
)

data class RiskProfile(
    val overallRisk: Double,
    val ageRisk: Double,
    val utilizationRisk: Double,
    val maintenanceRisk: Double,
    val marketRisk: Double,
    val riskLevel: String
)

data class EconomicSensitivity(
    val fuelPriceSensitivity: Double,
    val interestRateSensitivity: Double,
    val demandSensitivity: Double,
    val inflationSensitivity: Double
)

data class PortfolioOptimization(
    val objective: OptimizationObjective,
    val assetScores: List<AssetScore>,
    val optimizedAllocation: Map<String, Double>,
    val recommendations: List<PortfolioRecommendation>,
    val expectedReturn: Double,
    val riskLevel: Double,
    val economicJustification: String
)

data class AssetScore(
    val assetId: String,
    val assetType: AssetType,
    val score: Double
)

data class PortfolioConstraints(
    val maxInvestment: Double,
    val maxPerAsset: Double,
    val minDiversification: Double,
    val riskTolerance: Double
)

data class PortfolioRecommendation(
    val type: RecommendationType,
    val assetId: String,
    val reasoning: String,
    val impact: RecommendationImpact,
    val urgency: RecommendationUrgency
)

data class AssetValuation(
    val method: ValuationMethod,
    val primaryValue: Double,
    val lowEstimate: Double,
    val highEstimate: Double,
    val confidence: Double,
    val assumptions: List<String>,
    val marketFactors: List<String>
)

data class MarketData(
    val assetPrices: Map<AssetType, Double>,
    val transactionVolumes: Map<AssetType, Int>,
    val priceHistory: Map<AssetType, List<Double>>,
    val marketTrends: Map<AssetType, Double>
) {
    fun getAveragePrice(assetType: AssetType): Double? = assetPrices[assetType]
}

data class MarketTimingAnalysis(
    val assetType: AssetType,
    val transactionType: TransactionType,
    val currentMarketPhase: MarketPhase,
    val optimalTimingWindow: OptimalTimingWindow,
    val marketCycles: MarketCycleData,
    val riskFactors: List<String>,
    val confidence: Double,
    val economicIndicators: List<String>
)

data class MarketCycleData(
    val currentPhase: MarketPhase,
    val cycleLength: Int,
    val positionInCycle: Double,
    val volatility: Double,
    val trendStrength: Double
)

data class OptimalTimingWindow(
    val startMonth: Int,
    val endMonth: Int,
    val expectedPriceMovement: Double,
    val confidence: Double
)

data class RevenueModel(
    val baseRateFunction: (Double, MarketConditions) -> Double,
    val utilizationImpact: Double,
    val marketSensitivity: Double,
    val seasonalVariance: Double
)

data class CostModel(
    val fuelIntensity: Double,
    val laborIntensity: Double,
    val maintenanceIntensity: Double,
    val regulatoryImpact: Double
)

data class EconomicImpactData(
    val assetId: String,
    val impactFactors: Map<String, Double>,
    val lastUpdated: LocalDateTime
)

data class MarketInfluenceData(
    val assetType: AssetType,
    val influenceFactors: Map<String, Double>,
    val correlation: Double
)

// Economic event data classes
sealed class EconomicEvent {
    abstract val timestamp: LocalDateTime
    abstract val impact: EconomicImpact
}

data class FuelPriceEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val newPrice: Double,
    val baselinePrice: Double,
    val volatility: Double
) : EconomicEvent()

data class InterestRateEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val newRate: Double,
    val previousRate: Double
) : EconomicEvent()

data class InflationEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val inflationRate: Double
) : EconomicEvent()

data class TradeEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val tradeChange: Double,
    val volatility: Double
) : EconomicEvent()

data class CommodityEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val commodity: String,
    val priceChange: Double
) : EconomicEvent()

data class GeopoliticalEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val region: String,
    val riskIncrease: Double
) : EconomicEvent()

data class RegulatoryEvent(
    override val timestamp: LocalDateTime,
    override val impact: EconomicImpact,
    val type: String,
    val complianceCostMultiplier: Double
) : EconomicEvent()

// Enums
enum class OptimizationObjective {
    MAXIMIZE_ROI, MINIMIZE_RISK, MAXIMIZE_UTILIZATION, BALANCED
}

enum class ValuationMethod {
    BOOK_VALUE, MARKET_VALUE, INCOME_APPROACH, REPLACEMENT_COST, LIQUIDATION_VALUE, COMPREHENSIVE
}

enum class TransactionType {
    BUY, SELL
}

enum class MarketPhase {
    EXPANSION, PEAK, CONTRACTION, TROUGH
}

enum class RecommendationType {
    INCREASE_ALLOCATION, REDUCE_ALLOCATION, HOLD, DIVEST, ACQUIRE
}

enum class RecommendationImpact {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class RecommendationUrgency {
    LOW, MEDIUM, HIGH, IMMEDIATE
}

enum class EconomicImpact {
    MINIMAL, LOW, MEDIUM, HIGH, SEVERE
}

enum class TradeImpact {
    POSITIVE, NEUTRAL, NEGATIVE
}