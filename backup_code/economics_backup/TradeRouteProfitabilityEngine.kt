package com.flexport.economics

import com.flexport.economics.models.*
import com.flexport.economics.markets.*
import kotlin.math.*

/**
 * Engine for calculating trade route profitability and optimization
 */
class TradeRouteProfitabilityEngine {
    
    // Market references for price lookups
    private val goodsMarkets = mutableMapOf<CommodityType, GoodsMarket>()
    private val assetMarket: AssetMarket? = null
    private val laborMarket: LaborMarket? = null
    
    // Route performance cache
    private val routePerformanceCache = mutableMapOf<String, RoutePerformance>()
    private val lastCalculationTime = mutableMapOf<String, Long>()
    
    /**
     * Calculate comprehensive profitability for a trade route
     */
    fun calculateRouteProfitability(route: TradeRoute): RouteProfitability {
        val revenues = calculateRevenues(route)
        val costs = calculateCosts(route)
        val risks = calculateRisks(route)
        val timing = calculateTiming(route)
        
        val grossProfit = revenues.totalRevenue - costs.totalCost
        val netProfit = grossProfit - (grossProfit * risks.totalRiskAdjustment)
        val roi = if (costs.totalCost > 0) (netProfit / costs.totalCost) * 100 else 0.0
        val profitMargin = if (revenues.totalRevenue > 0) (netProfit / revenues.totalRevenue) * 100 else 0.0
        
        return RouteProfitability(
            route = route,
            revenues = revenues,
            costs = costs,
            risks = risks,
            timing = timing,
            grossProfit = grossProfit,
            netProfit = netProfit,
            roi = roi,
            profitMargin = profitMargin,
            calculationTime = System.currentTimeMillis()
        )
    }
    
    /**
     * Calculate revenues for a trade route
     */
    private fun calculateRevenues(route: TradeRoute): RouteRevenues {
        var totalRevenue = 0.0
        val commodityRevenues = mutableMapOf<CommodityType, Double>()
        
        route.cargo.forEach { cargoItem ->
            val market = goodsMarkets[cargoItem.commodityType]
            val marketStats = market?.getMarketStats()
            val currentPrice = marketStats?.currentPrice ?: cargoItem.purchasePrice
            
            // Apply destination price premium/discount
            val destinationMultiplier = getDestinationPriceMultiplier(
                cargoItem.commodityType, 
                route.destination
            )
            val destinationPrice = currentPrice * destinationMultiplier
            
            // Calculate revenue for this commodity
            val commodityRevenue = cargoItem.quantity * destinationPrice
            commodityRevenues[cargoItem.commodityType] = commodityRevenue
            totalRevenue += commodityRevenue
        }
        
        // Apply seasonal adjustments
        val seasonalMultiplier = getSeasonalMultiplier(route.destination)
        totalRevenue *= seasonalMultiplier
        
        // Calculate additional revenue streams
        val backhaul = calculateBackhaulRevenue(route)
        val express = calculateExpressShippingPremium(route)
        val insurance = calculateInsuranceRevenue(route)
        
        return RouteRevenues(
            commodityRevenues = commodityRevenues,
            totalCommodityRevenue = totalRevenue,
            backhaulRevenue = backhaul,
            expressShippingPremium = express,
            insuranceRevenue = insurance,
            totalRevenue = totalRevenue + backhaul + express + insurance
        )
    }
    
    /**
     * Calculate costs for a trade route
     */
    private fun calculateCosts(route: TradeRoute): RouteCosts {
        val fuelCosts = calculateFuelCosts(route)
        val laborCosts = calculateLaborCosts(route)
        val maintenance = calculateMaintenanceCosts(route)
        val portFees = calculatePortFees(route)
        val insurance = calculateInsuranceCosts(route)
        val opportunity = calculateOpportunityCosts(route)
        val overhead = calculateOverheadCosts(route)
        val procurement = calculateProcurementCosts(route)
        
        return RouteCosts(
            fuelCosts = fuelCosts,
            laborCosts = laborCosts,
            maintenanceCosts = maintenance,
            portFees = portFees,
            insuranceCosts = insurance,
            opportunityCosts = opportunity,
            overheadCosts = overhead,
            procurementCosts = procurement,
            totalCost = fuelCosts + laborCosts + maintenance + portFees + 
                       insurance + opportunity + overhead + procurement
        )
    }
    
    /**
     * Calculate fuel costs for the route
     */
    private fun calculateFuelCosts(route: TradeRoute): Double {
        val distance = calculateRouteDistance(route.origin, route.destination)
        
        return when (route.transportMethod) {
            TransportMethod.SHIP -> {
                val fuelConsumption = distance * 0.05 // liters per km (average)
                val fuelPrice = getCurrentFuelPrice()
                fuelConsumption * fuelPrice
            }
            TransportMethod.AIRCRAFT -> {
                val fuelConsumption = distance * 0.15 // liters per km (higher for aircraft)
                val fuelPrice = getCurrentFuelPrice() * 1.2 // Aviation fuel premium
                fuelConsumption * fuelPrice
            }
            TransportMethod.TRUCK -> {
                val fuelConsumption = distance * 0.08 // liters per km
                val fuelPrice = getCurrentFuelPrice()
                fuelConsumption * fuelPrice
            }
            TransportMethod.RAIL -> {
                val fuelConsumption = distance * 0.03 // liters per km (efficient)
                val fuelPrice = getCurrentFuelPrice()
                fuelConsumption * fuelPrice
            }
        }
    }
    
    /**
     * Calculate labor costs for the route
     */
    private fun calculateLaborCosts(route: TradeRoute): Double {
        val routeDuration = calculateRouteDuration(route)
        val crewSize = getRequiredCrewSize(route.transportMethod)
        
        val dailyWagePerCrew = when (route.transportMethod) {
            TransportMethod.SHIP -> 300.0 // Ship crew daily wage
            TransportMethod.AIRCRAFT -> 800.0 // Pilot daily wage
            TransportMethod.TRUCK -> 250.0 // Truck driver daily wage
            TransportMethod.RAIL -> 200.0 // Train operator daily wage
        }
        
        return crewSize * dailyWagePerCrew * (routeDuration / 86400000.0) // Convert to days
    }
    
    /**
     * Calculate maintenance costs
     */
    private fun calculateMaintenanceCosts(route: TradeRoute): Double {
        val distance = calculateRouteDistance(route.origin, route.destination)
        
        return when (route.transportMethod) {
            TransportMethod.SHIP -> distance * 0.50 // $0.50 per km
            TransportMethod.AIRCRAFT -> distance * 2.00 // $2.00 per km
            TransportMethod.TRUCK -> distance * 0.30 // $0.30 per km
            TransportMethod.RAIL -> distance * 0.20 // $0.20 per km
        }
    }
    
    /**
     * Calculate port/terminal fees
     */
    private fun calculatePortFees(route: TradeRoute): Double {
        val originFee = getPortFee(route.origin, route.transportMethod)
        val destinationFee = getPortFee(route.destination, route.transportMethod)
        
        // Add cargo handling fees
        val cargoWeight = route.cargo.sumOf { it.quantity * getCommodityWeight(it.commodityType) }
        val handlingFee = cargoWeight * 2.0 // $2 per kg handling
        
        return originFee + destinationFee + handlingFee
    }
    
    /**
     * Calculate insurance costs
     */
    private fun calculateInsuranceCosts(route: TradeRoute): Double {
        val cargoValue = route.cargo.sumOf { it.quantity * it.purchasePrice }
        val riskMultiplier = getRouteRiskMultiplier(route)
        val baseInsuranceRate = 0.005 // 0.5% of cargo value
        
        return cargoValue * baseInsuranceRate * riskMultiplier
    }
    
    /**
     * Calculate opportunity costs
     */
    private fun calculateOpportunityCosts(route: TradeRoute): Double {
        val routeDuration = calculateRouteDuration(route)
        val assetValue = getAssetValue(route.transportMethod)
        val alternativeRouteROI = getBestAlternativeRouteROI(route)
        
        // Opportunity cost = asset value * alternative ROI * time factor
        return assetValue * alternativeRouteROI * (routeDuration / (365.0 * 24 * 60 * 60 * 1000))
    }
    
    /**
     * Calculate overhead costs
     */
    private fun calculateOverheadCosts(route: TradeRoute): Double {
        val cargoValue = route.cargo.sumOf { it.quantity * it.purchasePrice }
        return cargoValue * 0.02 // 2% overhead rate
    }
    
    /**
     * Calculate procurement costs (buying the cargo)
     */
    private fun calculateProcurementCosts(route: TradeRoute): Double {
        return route.cargo.sumOf { it.quantity * it.purchasePrice }
    }
    
    /**
     * Calculate risks for the route
     */
    private fun calculateRisks(route: TradeRoute): RouteRisks {
        val weather = calculateWeatherRisk(route)
        val political = calculatePoliticalRisk(route)
        val market = calculateMarketRisk(route)
        val operational = calculateOperationalRisk(route)
        val currency = calculateCurrencyRisk(route)
        val piracy = calculatePiracyRisk(route)
        
        val totalRisk = weather + political + market + operational + currency + piracy
        val riskAdjustment = calculateRiskAdjustment(totalRisk)
        
        return RouteRisks(
            weatherRisk = weather,
            politicalRisk = political,
            marketVolatilityRisk = market,
            operationalRisk = operational,
            currencyRisk = currency,
            piracyRisk = piracy,
            totalRisk = totalRisk,
            totalRiskAdjustment = riskAdjustment
        )
    }
    
    /**
     * Calculate timing analysis for the route
     */
    private fun calculateTiming(route: TradeRoute): RouteTiming {
        val transitTime = calculateTransitTime(route)
        val loadingTime = calculateLoadingTime(route)
        val unloadingTime = calculateUnloadingTime(route)
        val customsTime = calculateCustomsTime(route)
        val totalTime = transitTime + loadingTime + unloadingTime + customsTime
        
        val timeValue = calculateTimeValue(route)
        val timeSensitivity = calculateTimeSensitivity(route)
        
        return RouteTiming(
            transitTime = transitTime,
            loadingTime = loadingTime,
            unloadingTime = unloadingTime,
            customsTime = customsTime,
            totalTime = totalTime,
            timeValueMultiplier = timeValue,
            timeSensitivity = timeSensitivity
        )
    }
    
    /**
     * Find optimal routes based on profitability
     */
    fun findOptimalRoutes(
        origin: Location,
        availableCargo: List<CargoItem>,
        maxRoutes: Int = 10
    ): List<RouteProfitability> {
        val potentialDestinations = getPotentialDestinations(origin, availableCargo)
        val routeProfitabilities = mutableListOf<RouteProfitability>()
        
        potentialDestinations.forEach { destination ->
            TransportMethod.values().forEach { method ->
                val route = TradeRoute(
                    id = "OPT-${System.currentTimeMillis()}-${method.name}",
                    origin = origin,
                    destination = destination,
                    cargo = availableCargo,
                    transportMethod = method,
                    priority = RoutePriority.STANDARD
                )
                
                val profitability = calculateRouteProfitability(route)
                routeProfitabilities.add(profitability)
            }
        }
        
        return routeProfitabilities
            .sortedByDescending { it.roi }
            .take(maxRoutes)
    }
    
    /**
     * Optimize cargo mix for a given route
     */
    fun optimizeCargoMix(
        route: TradeRoute,
        availableCargo: List<CargoItem>,
        capacityConstraint: Double
    ): CargoOptimization {
        // Use knapsack algorithm for cargo optimization
        val items = availableCargo.map { cargo ->
            val profitPerUnit = calculateProfitPerUnit(cargo, route.destination)
            val weightPerUnit = getCommodityWeight(cargo.commodityType)
            
            OptimizationItem(
                cargoItem = cargo,
                profitPerUnit = profitPerUnit,
                weightPerUnit = weightPerUnit,
                valueToWeightRatio = profitPerUnit / weightPerUnit
            )
        }.sortedByDescending { it.valueToWeightRatio }
        
        val optimizedCargo = mutableListOf<CargoItem>()
        var remainingCapacity = capacityConstraint
        var totalProfit = 0.0
        
        items.forEach { item ->
            val maxQuantity = min(item.cargoItem.quantity, remainingCapacity / item.weightPerUnit)
            if (maxQuantity > 0) {
                val optimizedItem = item.cargoItem.copy(quantity = maxQuantity)
                optimizedCargo.add(optimizedItem)
                remainingCapacity -= maxQuantity * item.weightPerUnit
                totalProfit += maxQuantity * item.profitPerUnit
            }
        }
        
        return CargoOptimization(
            originalCargo = availableCargo,
            optimizedCargo = optimizedCargo,
            capacityUtilization = (capacityConstraint - remainingCapacity) / capacityConstraint,
            totalProfitImprovement = totalProfit
        )
    }
    
    /**
     * Analyze route performance over time
     */
    fun analyzeRoutePerformance(routeId: String, timeWindow: Long): RoutePerformanceAnalysis {
        val performances = getHistoricalPerformance(routeId, timeWindow)
        
        if (performances.isEmpty()) {
            return RoutePerformanceAnalysis.empty(routeId)
        }
        
        val profits = performances.map { it.netProfit }
        val avgProfit = profits.average()
        val profitVolatility = sqrt(profits.map { (it - avgProfit).pow(2) }.average())
        
        val successRate = performances.count { it.netProfit > 0 }.toDouble() / performances.size
        val avgRoi = performances.map { it.roi }.average()
        
        val trend = calculateTrend(profits)
        val seasonality = calculateSeasonality(performances)
        
        return RoutePerformanceAnalysis(
            routeId = routeId,
            timeWindow = timeWindow,
            totalExecutions = performances.size,
            averageProfit = avgProfit,
            profitVolatility = profitVolatility,
            successRate = successRate,
            averageROI = avgRoi,
            profitTrend = trend,
            seasonalityFactor = seasonality,
            recommendations = generateRouteRecommendations(performances)
        )
    }
    
    // Helper methods (simplified implementations)
    
    private fun calculateRouteDistance(origin: Location, destination: Location): Double {
        // Haversine formula for great circle distance
        val lat1Rad = Math.toRadians(origin.latitude)
        val lat2Rad = Math.toRadians(destination.latitude)
        val deltaLatRad = Math.toRadians(destination.latitude - origin.latitude)
        val deltaLonRad = Math.toRadians(destination.longitude - origin.longitude)
        
        val a = sin(deltaLatRad / 2).pow(2) + cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return 6371.0 * c // Earth's radius in km
    }
    
    private fun calculateRouteDuration(route: TradeRoute): Long {
        val distance = calculateRouteDistance(route.origin, route.destination)
        val speed = when (route.transportMethod) {
            TransportMethod.SHIP -> 25.0 // km/h
            TransportMethod.AIRCRAFT -> 800.0 // km/h
            TransportMethod.TRUCK -> 80.0 // km/h
            TransportMethod.RAIL -> 100.0 // km/h
        }
        
        return ((distance / speed) * 3600 * 1000).toLong() // milliseconds
    }
    
    private fun getCurrentFuelPrice(): Double = 1.5 // $1.50 per liter
    
    private fun getDestinationPriceMultiplier(commodity: CommodityType, destination: Location): Double {
        // Simplified: some destinations have price premiums
        return when (destination.name) {
            "Tokyo" -> 1.2
            "New York" -> 1.15
            "London" -> 1.1
            else -> 1.0
        }
    }
    
    private fun getSeasonalMultiplier(destination: Location): Double = 1.0 // Simplified
    
    private fun calculateBackhaulRevenue(route: TradeRoute): Double = 0.0 // Simplified
    
    private fun calculateExpressShippingPremium(route: TradeRoute): Double {
        return if (route.priority == RoutePriority.EXPRESS) {
            route.cargo.sumOf { it.quantity * it.purchasePrice } * 0.1 // 10% express premium
        } else 0.0
    }
    
    private fun calculateInsuranceRevenue(route: TradeRoute): Double = 0.0 // Simplified
    
    private fun getRequiredCrewSize(method: TransportMethod): Int = when (method) {
        TransportMethod.SHIP -> 20
        TransportMethod.AIRCRAFT -> 2
        TransportMethod.TRUCK -> 1
        TransportMethod.RAIL -> 2
    }
    
    private fun getCommodityWeight(type: CommodityType): Double = 1.0 // Simplified: 1 kg per unit
    
    private fun getPortFee(location: Location, method: TransportMethod): Double = 5000.0 // Simplified
    
    private fun getRouteRiskMultiplier(route: TradeRoute): Double = 1.0 // Simplified
    
    private fun getAssetValue(method: TransportMethod): Double = when (method) {
        TransportMethod.SHIP -> 50000000.0
        TransportMethod.AIRCRAFT -> 100000000.0
        TransportMethod.TRUCK -> 100000.0
        TransportMethod.RAIL -> 5000000.0
    }
    
    private fun getBestAlternativeRouteROI(route: TradeRoute): Double = 0.15 // 15% annual ROI
    
    private fun calculateWeatherRisk(route: TradeRoute): Double = 0.05 // 5% risk
    private fun calculatePoliticalRisk(route: TradeRoute): Double = 0.03 // 3% risk
    private fun calculateMarketRisk(route: TradeRoute): Double = 0.08 // 8% risk
    private fun calculateOperationalRisk(route: TradeRoute): Double = 0.02 // 2% risk
    private fun calculateCurrencyRisk(route: TradeRoute): Double = 0.04 // 4% risk
    private fun calculatePiracyRisk(route: TradeRoute): Double = 0.01 // 1% risk
    
    private fun calculateRiskAdjustment(totalRisk: Double): Double = totalRisk * 0.5 // 50% of risk as adjustment
    
    private fun calculateTransitTime(route: TradeRoute): Long = calculateRouteDuration(route)
    private fun calculateLoadingTime(route: TradeRoute): Long = 2 * 60 * 60 * 1000 // 2 hours
    private fun calculateUnloadingTime(route: TradeRoute): Long = 2 * 60 * 60 * 1000 // 2 hours
    private fun calculateCustomsTime(route: TradeRoute): Long = 4 * 60 * 60 * 1000 // 4 hours
    
    private fun calculateTimeValue(route: TradeRoute): Double = 1.0 // Simplified
    private fun calculateTimeSensitivity(route: TradeRoute): Double = 0.5 // Simplified
    
    private fun getPotentialDestinations(origin: Location, cargo: List<CargoItem>): List<Location> {
        // Simplified: return some major ports/cities
        return listOf(
            Location("Tokyo", 35.6762, 139.6503),
            Location("New York", 40.7128, -74.0060),
            Location("London", 51.5074, -0.1278),
            Location("Singapore", 1.3521, 103.8198),
            Location("Rotterdam", 51.9244, 4.4777)
        )
    }
    
    private fun calculateProfitPerUnit(cargo: CargoItem, destination: Location): Double {
        val destinationPrice = cargo.purchasePrice * getDestinationPriceMultiplier(cargo.commodityType, destination)
        return destinationPrice - cargo.purchasePrice
    }
    
    private fun getHistoricalPerformance(routeId: String, timeWindow: Long): List<RouteProfitability> {
        // Simplified: return cached performance data
        return emptyList()
    }
    
    private fun calculateTrend(profits: List<Double>): Double {
        // Simple linear trend calculation
        if (profits.size < 2) return 0.0
        
        val x = profits.indices.map { it.toDouble() }
        val y = profits
        val n = profits.size
        
        val sumX = x.sum()
        val sumY = y.sum()
        val sumXY = x.zip(y) { xi, yi -> xi * yi }.sum()
        val sumX2 = x.map { it * it }.sum()
        
        return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
    }
    
    private fun calculateSeasonality(performances: List<RouteProfitability>): Double = 0.1 // Simplified
    
    private fun generateRouteRecommendations(performances: List<RouteProfitability>): List<String> {
        val recommendations = mutableListOf<String>()
        
        if (performances.isNotEmpty()) {
            val avgProfit = performances.map { it.netProfit }.average()
            
            if (avgProfit < 0) {
                recommendations.add("Consider alternative routes or cargo mix")
            }
            
            val avgRoi = performances.map { it.roi }.average()
            if (avgRoi < 10) {
                recommendations.add("ROI below target, optimize costs or pricing")
            }
            
            recommendations.add("Monitor fuel price trends for cost optimization")
        }
        
        return recommendations
    }
}

// Data classes for the trade route system

data class TradeRoute(
    val id: String,
    val origin: Location,
    val destination: Location,
    val cargo: List<CargoItem>,
    val transportMethod: TransportMethod,
    val priority: RoutePriority
)

data class Location(
    val name: String,
    val latitude: Double,
    val longitude: Double
)

data class CargoItem(
    val commodityType: CommodityType,
    val quantity: Double,
    val purchasePrice: Double
)

enum class TransportMethod {
    SHIP,
    AIRCRAFT,
    TRUCK,
    RAIL
}

enum class RoutePriority {
    STANDARD,
    EXPRESS,
    ECONOMY
}

data class RouteProfitability(
    val route: TradeRoute,
    val revenues: RouteRevenues,
    val costs: RouteCosts,
    val risks: RouteRisks,
    val timing: RouteTiming,
    val grossProfit: Double,
    val netProfit: Double,
    val roi: Double,
    val profitMargin: Double,
    val calculationTime: Long
)

data class RouteRevenues(
    val commodityRevenues: Map<CommodityType, Double>,
    val totalCommodityRevenue: Double,
    val backhaulRevenue: Double,
    val expressShippingPremium: Double,
    val insuranceRevenue: Double,
    val totalRevenue: Double
)

data class RouteCosts(
    val fuelCosts: Double,
    val laborCosts: Double,
    val maintenanceCosts: Double,
    val portFees: Double,
    val insuranceCosts: Double,
    val opportunityCosts: Double,
    val overheadCosts: Double,
    val procurementCosts: Double,
    val totalCost: Double
)

data class RouteRisks(
    val weatherRisk: Double,
    val politicalRisk: Double,
    val marketVolatilityRisk: Double,
    val operationalRisk: Double,
    val currencyRisk: Double,
    val piracyRisk: Double,
    val totalRisk: Double,
    val totalRiskAdjustment: Double
)

data class RouteTiming(
    val transitTime: Long,
    val loadingTime: Long,
    val unloadingTime: Long,
    val customsTime: Long,
    val totalTime: Long,
    val timeValueMultiplier: Double,
    val timeSensitivity: Double
)

data class CargoOptimization(
    val originalCargo: List<CargoItem>,
    val optimizedCargo: List<CargoItem>,
    val capacityUtilization: Double,
    val totalProfitImprovement: Double
)

data class OptimizationItem(
    val cargoItem: CargoItem,
    val profitPerUnit: Double,
    val weightPerUnit: Double,
    val valueToWeightRatio: Double
)

data class RoutePerformance(
    val routeId: String,
    val executionTime: Long,
    val netProfit: Double,
    val roi: Double
)

data class RoutePerformanceAnalysis(
    val routeId: String,
    val timeWindow: Long,
    val totalExecutions: Int,
    val averageProfit: Double,
    val profitVolatility: Double,
    val successRate: Double,
    val averageROI: Double,
    val profitTrend: Double,
    val seasonalityFactor: Double,
    val recommendations: List<String>
) {
    companion object {
        fun empty(routeId: String) = RoutePerformanceAnalysis(
            routeId = routeId,
            timeWindow = 0,
            totalExecutions = 0,
            averageProfit = 0.0,
            profitVolatility = 0.0,
            successRate = 0.0,
            averageROI = 0.0,
            profitTrend = 0.0,
            seasonalityFactor = 0.0,
            recommendations = emptyList()
        )
    }
}