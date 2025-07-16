package com.flexport.assets.analytics

import com.flexport.assets.models.*
import com.flexport.assets.assignment.AssetAssignment
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*

/**
 * Advanced analytics engine for asset performance tracking and optimization insights
 */
class AssetAnalyticsEngine {
    
    private val _analyticsData = MutableStateFlow<Map<String, AssetAnalytics>>(emptyMap())
    val analyticsData: StateFlow<Map<String, AssetAnalytics>> = _analyticsData.asStateFlow()
    
    private val assetMetrics = ConcurrentHashMap<String, AssetPerformanceData>()
    private val historicalData = ConcurrentHashMap<String, MutableList<PerformanceSnapshot>>()
    private val benchmarkData = ConcurrentHashMap<AssetType, BenchmarkMetrics>()
    private val kpiTracker = ConcurrentHashMap<String, KPITracker>()
    
    // Real-time data collection
    private val realtimeMetrics = ConcurrentHashMap<String, RealtimeMetrics>()
    private val alertThresholds = ConcurrentHashMap<String, AlertThresholds>()
    
    /**
     * Initialize tracking for a new asset
     */
    fun initializeAssetTracking(asset: FlexPortAsset) {
        val performanceData = AssetPerformanceData(
            assetId = asset.id,
            assetType = asset.assetType,
            trackingStartDate = LocalDateTime.now(),
            totalOperatingHours = 0.0,
            totalRevenue = 0.0,
            totalOperatingCosts = 0.0,
            fuelConsumption = 0.0,
            maintenanceEvents = 0,
            utilizationHistory = mutableListOf(),
            efficiencyTrends = mutableListOf(),
            performanceAlerts = mutableListOf()
        )
        
        assetMetrics[asset.id] = performanceData
        historicalData[asset.id] = mutableListOf()
        
        // Initialize KPI tracker
        kpiTracker[asset.id] = KPITracker(
            assetId = asset.id,
            targetUtilization = getTargetUtilization(asset.assetType),
            targetEfficiency = getTargetEfficiency(asset.assetType),
            targetRevenue = calculateTargetRevenue(asset)
        )
        
        // Set up alert thresholds
        alertThresholds[asset.id] = createAlertThresholds(asset)
        
        updateAnalyticsState()
    }
    
    /**
     * Record real-time operational data
     */
    fun recordOperationalData(
        assetId: String,
        operationData: OperationalDataPoint
    ) {
        val performanceData = assetMetrics[assetId] ?: return
        
        // Update cumulative metrics
        performanceData.totalOperatingHours += operationData.operatingHours
        performanceData.totalRevenue += operationData.revenue
        performanceData.totalOperatingCosts += operationData.operatingCosts
        performanceData.fuelConsumption += operationData.fuelConsumed
        
        // Update real-time metrics
        realtimeMetrics[assetId] = RealtimeMetrics(
            assetId = assetId,
            currentUtilization = operationData.utilizationRate,
            currentEfficiency = calculateEfficiency(operationData),
            currentSpeed = operationData.averageSpeed,
            fuelEfficiency = operationData.fuelEfficiency,
            lastUpdated = LocalDateTime.now()
        )
        
        // Record utilization history
        performanceData.utilizationHistory.add(
            UtilizationDataPoint(
                timestamp = LocalDateTime.now(),
                utilizationRate = operationData.utilizationRate,
                loadFactor = operationData.loadFactor,
                operatingContext = operationData.context
            )
        )
        
        // Calculate and store efficiency trends
        val efficiency = calculateEfficiency(operationData)
        performanceData.efficiencyTrends.add(
            EfficiencyDataPoint(
                timestamp = LocalDateTime.now(),
                fuelEfficiency = operationData.fuelEfficiency,
                timeEfficiency = operationData.timeEfficiency,
                costEfficiency = if (operationData.operatingCosts > 0) 
                    operationData.revenue / operationData.operatingCosts else 0.0,
                overallEfficiency = efficiency
            )
        )
        
        // Check for performance alerts
        checkPerformanceAlerts(assetId, operationData)
        
        // Create periodic snapshots
        if (shouldCreateSnapshot(assetId)) {
            createPerformanceSnapshot(assetId)
        }
        
        updateAnalyticsState()
    }
    
    /**
     * Generate comprehensive asset analytics report
     */
    fun generateAssetReport(assetId: String): AssetAnalyticsReport? {
        val performanceData = assetMetrics[assetId] ?: return null
        val kpiData = kpiTracker[assetId] ?: return null
        val realtimeData = realtimeMetrics[assetId]
        val history = historicalData[assetId] ?: emptyList()
        
        val report = AssetAnalyticsReport(
            assetId = assetId,
            assetType = performanceData.assetType,
            reportPeriod = ReportPeriod.CURRENT,
            generatedAt = LocalDateTime.now(),
            performanceSummary = generatePerformanceSummary(performanceData, kpiData),
            utilizationAnalysis = generateUtilizationAnalysis(performanceData),
            efficiencyAnalysis = generateEfficiencyAnalysis(performanceData),
            financialMetrics = generateFinancialMetrics(performanceData),
            maintenanceInsights = generateMaintenanceInsights(assetId),
            riskAssessment = generateRiskAssessment(performanceData),
            recommendations = generateRecommendations(assetId, performanceData, kpiData),
            trendAnalysis = generateTrendAnalysis(history),
            benchmarkComparison = generateBenchmarkComparison(performanceData)
        )
        
        return report
    }
    
    /**
     * Generate fleet-wide analytics
     */
    fun generateFleetAnalytics(assetType: AssetType? = null): FleetAnalyticsReport {
        val relevantAssets = if (assetType != null) {
            assetMetrics.values.filter { it.assetType == assetType }
        } else {
            assetMetrics.values
        }
        
        return FleetAnalyticsReport(
            reportType = assetType?.name ?: "ALL_ASSETS",
            totalAssets = relevantAssets.size,
            generatedAt = LocalDateTime.now(),
            fleetUtilization = calculateFleetUtilization(relevantAssets),
            fleetEfficiency = calculateFleetEfficiency(relevantAssets),
            totalRevenue = relevantAssets.sumOf { it.totalRevenue },
            totalOperatingCosts = relevantAssets.sumOf { it.totalOperatingCosts },
            fleetROI = calculateFleetROI(relevantAssets),
            topPerformers = identifyTopPerformers(relevantAssets),
            underPerformers = identifyUnderPerformers(relevantAssets),
            fleetTrends = generateFleetTrends(relevantAssets),
            maintenanceSchedule = generateFleetMaintenanceSchedule(relevantAssets),
            resourceOptimization = generateResourceOptimization(relevantAssets)
        )
    }
    
    /**
     * Predictive analytics for asset performance
     */
    fun generatePredictiveAnalytics(assetId: String): PredictiveAnalysis? {
        val performanceData = assetMetrics[assetId] ?: return null
        val history = historicalData[assetId] ?: return null
        
        if (history.size < 10) {
            return null // Need sufficient historical data
        }
        
        return PredictiveAnalysis(
            assetId = assetId,
            predictionHorizon = 90, // 90 days
            confidenceLevel = 0.85,
            predictedUtilization = predictUtilization(history),
            predictedMaintenanceNeeds = predictMaintenanceNeeds(assetId, history),
            predictedRevenue = predictRevenue(history),
            predictedCosts = predictCosts(history),
            riskFactors = identifyRiskFactors(performanceData, history),
            recommendations = generatePredictiveRecommendations(assetId, history)
        )
    }
    
    /**
     * Real-time performance dashboard data
     */
    fun getDashboardData(): AssetDashboardData {
        val allAssets = assetMetrics.values
        val activeAlerts = assetMetrics.values.flatMap { it.performanceAlerts }
            .filter { it.severity != AlertSeverity.RESOLVED }
        
        return AssetDashboardData(
            totalAssets = allAssets.size,
            operationalAssets = allAssets.count { realtimeMetrics[it.assetId]?.currentUtilization ?: 0.0 > 0.1 },
            averageUtilization = allAssets.mapNotNull { 
                realtimeMetrics[it.assetId]?.currentUtilization 
            }.average(),
            totalRevenue = allAssets.sumOf { it.totalRevenue },
            totalOperatingCosts = allAssets.sumOf { it.totalOperatingCosts },
            activeAlerts = activeAlerts.size,
            criticalAlerts = activeAlerts.count { it.severity == AlertSeverity.CRITICAL },
            fleetEfficiency = calculateFleetEfficiency(allAssets),
            topPerformingAssets = identifyTopPerformers(allAssets).take(5),
            recentAlerts = activeAlerts.sortedByDescending { it.timestamp }.take(10),
            utilizationTrend = calculateUtilizationTrend(),
            efficiencyTrend = calculateEfficiencyTrend()
        )
    }
    
    // Private calculation methods
    private fun calculateEfficiency(data: OperationalDataPoint): Double {
        // Composite efficiency score based on fuel, time, and cost efficiency
        val fuelWeight = 0.4
        val timeWeight = 0.3
        val costWeight = 0.3
        
        return (data.fuelEfficiency * fuelWeight) +
               (data.timeEfficiency * timeWeight) +
               (if (data.operatingCosts > 0) (data.revenue / data.operatingCosts) * costWeight else 0.0)
    }
    
    private fun getTargetUtilization(assetType: AssetType): Double {
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> 0.75
            AssetType.CARGO_AIRCRAFT -> 0.85
            AssetType.WAREHOUSE -> 0.80
            else -> 0.70
        }
    }
    
    private fun getTargetEfficiency(assetType: AssetType): Double {
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> 0.80
            AssetType.CARGO_AIRCRAFT -> 0.85
            AssetType.WAREHOUSE -> 0.75
            else -> 0.70
        }
    }
    
    private fun calculateTargetRevenue(asset: FlexPortAsset): Double {
        // Simplified target revenue calculation
        return asset.currentValue * 0.15 // 15% annual return target
    }
    
    private fun createAlertThresholds(asset: FlexPortAsset): AlertThresholds {
        return AlertThresholds(
            lowUtilizationThreshold = 0.3,
            highMaintenanceCostThreshold = asset.calculateMaintenanceCost() * 1.5,
            lowEfficiencyThreshold = 0.5,
            highFuelConsumptionThreshold = when (asset) {
                is ContainerShip -> asset.specifications.fuelConsumption * 1.2
                is CargoAircraft -> asset.specifications.fuelConsumptionPerHour * 1.2
                else -> 0.0
            }
        )
    }
    
    private fun checkPerformanceAlerts(assetId: String, data: OperationalDataPoint) {
        val thresholds = alertThresholds[assetId] ?: return
        val performanceData = assetMetrics[assetId] ?: return
        
        // Check utilization alert
        if (data.utilizationRate < thresholds.lowUtilizationThreshold) {
            val alert = PerformanceAlert(
                id = "ALERT-${System.currentTimeMillis()}",
                assetId = assetId,
                alertType = AlertType.LOW_UTILIZATION,
                severity = AlertSeverity.MEDIUM,
                message = "Asset utilization below ${(thresholds.lowUtilizationThreshold * 100).toInt()}%",
                timestamp = LocalDateTime.now(),
                value = data.utilizationRate,
                threshold = thresholds.lowUtilizationThreshold
            )
            performanceData.performanceAlerts.add(alert)
        }
        
        // Check efficiency alert
        val efficiency = calculateEfficiency(data)
        if (efficiency < thresholds.lowEfficiencyThreshold) {
            val alert = PerformanceAlert(
                id = "ALERT-${System.currentTimeMillis()}",
                assetId = assetId,
                alertType = AlertType.LOW_EFFICIENCY,
                severity = AlertSeverity.HIGH,
                message = "Asset efficiency below acceptable threshold",
                timestamp = LocalDateTime.now(),
                value = efficiency,
                threshold = thresholds.lowEfficiencyThreshold
            )
            performanceData.performanceAlerts.add(alert)
        }
        
        // Check fuel consumption alert
        if (data.fuelConsumed > thresholds.highFuelConsumptionThreshold) {
            val alert = PerformanceAlert(
                id = "ALERT-${System.currentTimeMillis()}",
                assetId = assetId,
                alertType = AlertType.HIGH_FUEL_CONSUMPTION,
                severity = AlertSeverity.MEDIUM,
                message = "Fuel consumption above normal levels",
                timestamp = LocalDateTime.now(),
                value = data.fuelConsumed,
                threshold = thresholds.highFuelConsumptionThreshold
            )
            performanceData.performanceAlerts.add(alert)
        }
        
        // Trim old alerts (keep last 50)
        if (performanceData.performanceAlerts.size > 50) {
            performanceData.performanceAlerts.removeAt(0)
        }
    }
    
    private fun shouldCreateSnapshot(assetId: String): Boolean {
        val history = historicalData[assetId] ?: return true
        if (history.isEmpty()) return true
        
        val lastSnapshot = history.lastOrNull()?.timestamp ?: return true
        val hoursSinceLastSnapshot = ChronoUnit.HOURS.between(lastSnapshot, LocalDateTime.now())
        
        return hoursSinceLastSnapshot >= 24 // Create daily snapshots
    }
    
    private fun createPerformanceSnapshot(assetId: String) {
        val performanceData = assetMetrics[assetId] ?: return
        val realtimeData = realtimeMetrics[assetId]
        
        val snapshot = PerformanceSnapshot(
            timestamp = LocalDateTime.now(),
            utilizationRate = realtimeData?.currentUtilization ?: 0.0,
            efficiency = realtimeData?.currentEfficiency ?: 0.0,
            revenue = performanceData.totalRevenue,
            operatingCosts = performanceData.totalOperatingCosts,
            maintenanceEvents = performanceData.maintenanceEvents,
            fuelConsumption = performanceData.fuelConsumption,
            operatingHours = performanceData.totalOperatingHours
        )
        
        historicalData[assetId]?.add(snapshot)
        
        // Keep only last 365 days of snapshots
        historicalData[assetId]?.let { history ->
            if (history.size > 365) {
                history.removeAt(0)
            }
        }
    }
    
    private fun generatePerformanceSummary(
        performanceData: AssetPerformanceData,
        kpiData: KPITracker
    ): PerformanceSummary {
        val currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0
        val currentEfficiency = realtimeMetrics[performanceData.assetId]?.currentEfficiency ?: 0.0
        
        return PerformanceSummary(
            overallScore = calculateOverallScore(currentUtilization, currentEfficiency, performanceData),
            utilizationScore = (currentUtilization / kpiData.targetUtilization) * 100,
            efficiencyScore = (currentEfficiency / kpiData.targetEfficiency) * 100,
            revenueScore = (performanceData.totalRevenue / kpiData.targetRevenue) * 100,
            maintenanceScore = calculateMaintenanceScore(performanceData),
            trend = calculatePerformanceTrend(performanceData.assetId)
        )
    }
    
    private fun calculateOverallScore(
        utilization: Double,
        efficiency: Double,
        performanceData: AssetPerformanceData
    ): Double {
        val utilizationWeight = 0.3
        val efficiencyWeight = 0.3
        val revenueWeight = 0.2
        val maintenanceWeight = 0.2
        
        val utilizationScore = min(utilization, 1.0) * 100
        val efficiencyScore = min(efficiency, 1.0) * 100
        val revenueScore = if (performanceData.totalOperatingCosts > 0) {
            min(performanceData.totalRevenue / performanceData.totalOperatingCosts, 2.0) * 50
        } else 0.0
        val maintenanceScore = calculateMaintenanceScore(performanceData)
        
        return (utilizationScore * utilizationWeight) +
               (efficiencyScore * efficiencyWeight) +
               (revenueScore * revenueWeight) +
               (maintenanceScore * maintenanceWeight)
    }
    
    private fun calculateMaintenanceScore(performanceData: AssetPerformanceData): Double {
        // Higher score for fewer maintenance events relative to operating hours
        val maintenanceRate = if (performanceData.totalOperatingHours > 0) {
            performanceData.maintenanceEvents / (performanceData.totalOperatingHours / 1000.0)
        } else 0.0
        
        return max(0.0, 100.0 - (maintenanceRate * 20.0))
    }
    
    private fun calculatePerformanceTrend(assetId: String): TrendDirection {
        val history = historicalData[assetId] ?: return TrendDirection.STABLE
        if (history.size < 7) return TrendDirection.STABLE
        
        val recent = history.takeLast(7)
        val older = history.takeLast(14).take(7)
        
        val recentAvg = recent.map { it.efficiency }.average()
        val olderAvg = older.map { it.efficiency }.average()
        
        return when {
            recentAvg > olderAvg * 1.05 -> TrendDirection.IMPROVING
            recentAvg < olderAvg * 0.95 -> TrendDirection.DECLINING
            else -> TrendDirection.STABLE
        }
    }
    
    private fun generateUtilizationAnalysis(performanceData: AssetPerformanceData): UtilizationAnalysis {
        val history = performanceData.utilizationHistory
        
        return UtilizationAnalysis(
            currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0,
            averageUtilization = history.map { it.utilizationRate }.average(),
            peakUtilization = history.maxOfOrNull { it.utilizationRate } ?: 0.0,
            lowUtilizationPeriods = history.count { it.utilizationRate < 0.3 },
            utilizationTrend = calculateUtilizationTrend(history),
            seasonalPatterns = identifySeasonalPatterns(history)
        )
    }
    
    private fun calculateUtilizationTrend(history: List<UtilizationDataPoint>): TrendDirection {
        if (history.size < 10) return TrendDirection.STABLE
        
        val recent = history.takeLast(5).map { it.utilizationRate }.average()
        val older = history.takeLast(10).take(5).map { it.utilizationRate }.average()
        
        return when {
            recent > older * 1.1 -> TrendDirection.IMPROVING
            recent < older * 0.9 -> TrendDirection.DECLINING
            else -> TrendDirection.STABLE
        }
    }
    
    private fun identifySeasonalPatterns(history: List<UtilizationDataPoint>): List<String> {
        // Simplified seasonal pattern detection
        // In a real implementation, this would use more sophisticated time series analysis
        return listOf("No significant seasonal patterns detected")
    }
    
    private fun generateEfficiencyAnalysis(performanceData: AssetPerformanceData): EfficiencyAnalysis {
        val trends = performanceData.efficiencyTrends
        
        return EfficiencyAnalysis(
            currentFuelEfficiency = realtimeMetrics[performanceData.assetId]?.fuelEfficiency ?: 0.0,
            averageFuelEfficiency = trends.map { it.fuelEfficiency }.average(),
            timeEfficiency = trends.map { it.timeEfficiency }.average(),
            costEfficiency = trends.map { it.costEfficiency }.average(),
            overallEfficiency = trends.map { it.overallEfficiency }.average(),
            efficiencyTrend = calculateEfficiencyTrend(trends),
            improvementOpportunities = identifyEfficiencyImprovements(trends)
        )
    }
    
    private fun calculateEfficiencyTrend(trends: List<EfficiencyDataPoint>): TrendDirection {
        if (trends.size < 10) return TrendDirection.STABLE
        
        val recent = trends.takeLast(5).map { it.overallEfficiency }.average()
        val older = trends.takeLast(10).take(5).map { it.overallEfficiency }.average()
        
        return when {
            recent > older * 1.05 -> TrendDirection.IMPROVING
            recent < older * 0.95 -> TrendDirection.DECLINING
            else -> TrendDirection.STABLE
        }
    }
    
    private fun identifyEfficiencyImprovements(trends: List<EfficiencyDataPoint>): List<String> {
        val improvements = mutableListOf<String>()
        
        val avgFuelEfficiency = trends.map { it.fuelEfficiency }.average()
        val avgTimeEfficiency = trends.map { it.timeEfficiency }.average()
        val avgCostEfficiency = trends.map { it.costEfficiency }.average()
        
        if (avgFuelEfficiency < 0.7) {
            improvements.add("Fuel efficiency optimization needed")
        }
        if (avgTimeEfficiency < 0.8) {
            improvements.add("Route optimization could improve time efficiency")
        }
        if (avgCostEfficiency < 1.2) {
            improvements.add("Cost management improvements recommended")
        }
        
        return improvements.ifEmpty { listOf("Performance within acceptable parameters") }
    }
    
    private fun generateFinancialMetrics(performanceData: AssetPerformanceData): FinancialMetrics {
        val roi = if (performanceData.totalOperatingCosts > 0) {
            (performanceData.totalRevenue - performanceData.totalOperatingCosts) / performanceData.totalOperatingCosts
        } else 0.0
        
        return FinancialMetrics(
            totalRevenue = performanceData.totalRevenue,
            totalOperatingCosts = performanceData.totalOperatingCosts,
            netProfit = performanceData.totalRevenue - performanceData.totalOperatingCosts,
            roi = roi,
            revenuePerHour = if (performanceData.totalOperatingHours > 0) {
                performanceData.totalRevenue / performanceData.totalOperatingHours
            } else 0.0,
            costPerHour = if (performanceData.totalOperatingHours > 0) {
                performanceData.totalOperatingCosts / performanceData.totalOperatingHours
            } else 0.0
        )
    }
    
    private fun generateMaintenanceInsights(assetId: String): MaintenanceInsights {
        val performanceData = assetMetrics[assetId] ?: return MaintenanceInsights.empty()
        
        return MaintenanceInsights(
            totalMaintenanceEvents = performanceData.maintenanceEvents,
            averageTimeBetweenMaintenance = if (performanceData.maintenanceEvents > 0) {
                performanceData.totalOperatingHours / performanceData.maintenanceEvents
            } else 0.0,
            maintenanceCostRatio = if (performanceData.totalOperatingCosts > 0) {
                // Estimate maintenance costs as 20% of operating costs
                (performanceData.totalOperatingCosts * 0.2) / performanceData.totalOperatingCosts
            } else 0.0,
            predictedNextMaintenance = LocalDateTime.now().plusDays(30), // Simplified prediction
            maintenanceEffectiveness = 0.85 // Simplified metric
        )
    }
    
    private fun generateRiskAssessment(performanceData: AssetPerformanceData): RiskAssessment {
        val riskFactors = mutableListOf<RiskFactor>()
        var overallRisk = RiskLevel.LOW
        
        // Analyze utilization risk
        val currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0
        if (currentUtilization < 0.3) {
            riskFactors.add(RiskFactor(
                type = "Low Utilization",
                severity = RiskLevel.MEDIUM,
                description = "Asset underutilized, affecting profitability",
                mitigation = "Consider route optimization or reassignment"
            ))
            overallRisk = RiskLevel.MEDIUM
        }
        
        // Analyze maintenance risk
        if (performanceData.maintenanceEvents > performanceData.totalOperatingHours / 500) {
            riskFactors.add(RiskFactor(
                type = "High Maintenance Frequency",
                severity = RiskLevel.HIGH,
                description = "Above-average maintenance requirements",
                mitigation = "Consider asset upgrade or replacement evaluation"
            ))
            overallRisk = RiskLevel.HIGH
        }
        
        return RiskAssessment(
            overallRisk = overallRisk,
            riskFactors = riskFactors,
            riskScore = calculateRiskScore(riskFactors),
            recommendations = generateRiskRecommendations(riskFactors)
        )
    }
    
    private fun calculateRiskScore(riskFactors: List<RiskFactor>): Double {
        if (riskFactors.isEmpty()) return 0.0
        
        val weightedScore = riskFactors.sumOf { factor ->
            when (factor.severity) {
                RiskLevel.LOW -> 1.0
                RiskLevel.MEDIUM -> 3.0
                RiskLevel.HIGH -> 7.0
                RiskLevel.CRITICAL -> 10.0
            }
        }
        
        return min(weightedScore / riskFactors.size, 10.0)
    }
    
    private fun generateRiskRecommendations(riskFactors: List<RiskFactor>): List<String> {
        return riskFactors.map { it.mitigation }
    }
    
    private fun generateRecommendations(
        assetId: String,
        performanceData: AssetPerformanceData,
        kpiData: KPITracker
    ): List<AssetRecommendation> {
        val recommendations = mutableListOf<AssetRecommendation>()
        val currentUtilization = realtimeMetrics[assetId]?.currentUtilization ?: 0.0
        val currentEfficiency = realtimeMetrics[assetId]?.currentEfficiency ?: 0.0
        
        // Utilization recommendations
        if (currentUtilization < kpiData.targetUtilization) {
            recommendations.add(AssetRecommendation(
                type = "Utilization Improvement",
                priority = RecommendationPriority.HIGH,
                description = "Current utilization below target",
                action = "Consider route optimization or additional cargo assignments",
                expectedImpact = "Increase revenue by ${((kpiData.targetUtilization - currentUtilization) * 100).toInt()}%"
            ))
        }
        
        // Efficiency recommendations
        if (currentEfficiency < kpiData.targetEfficiency) {
            recommendations.add(AssetRecommendation(
                type = "Efficiency Optimization",
                priority = RecommendationPriority.MEDIUM,
                description = "Efficiency below optimal levels",
                action = "Review operational procedures and maintenance schedule",
                expectedImpact = "Reduce operating costs by 5-10%"
            ))
        }
        
        // Maintenance recommendations
        if (performanceData.maintenanceEvents > 5) {
            recommendations.add(AssetRecommendation(
                type = "Maintenance Strategy",
                priority = RecommendationPriority.LOW,
                description = "High maintenance frequency detected",
                action = "Implement predictive maintenance program",
                expectedImpact = "Reduce maintenance costs by 15-20%"
            ))
        }
        
        return recommendations
    }
    
    private fun generateTrendAnalysis(history: List<PerformanceSnapshot>): TrendAnalysis {
        if (history.size < 30) {
            return TrendAnalysis.insufficient()
        }
        
        val recent30 = history.takeLast(30)
        val previous30 = history.takeLast(60).take(30)
        
        return TrendAnalysis(
            utilizationTrend = comparePeriods(
                recent30.map { it.utilizationRate },
                previous30.map { it.utilizationRate }
            ),
            efficiencyTrend = comparePeriods(
                recent30.map { it.efficiency },
                previous30.map { it.efficiency }
            ),
            revenueTrend = comparePeriods(
                recent30.map { it.revenue },
                previous30.map { it.revenue }
            ),
            costTrend = comparePeriods(
                recent30.map { it.operatingCosts },
                previous30.map { it.operatingCosts }
            ),
            dataPoints = recent30.size
        )
    }
    
    private fun comparePeriods(recent: List<Double>, previous: List<Double>): TrendDirection {
        val recentAvg = recent.average()
        val previousAvg = previous.average()
        
        return when {
            recentAvg > previousAvg * 1.05 -> TrendDirection.IMPROVING
            recentAvg < previousAvg * 0.95 -> TrendDirection.DECLINING
            else -> TrendDirection.STABLE
        }
    }
    
    private fun generateBenchmarkComparison(performanceData: AssetPerformanceData): BenchmarkComparison {
        val benchmark = benchmarkData[performanceData.assetType] ?: createDefaultBenchmark(performanceData.assetType)
        
        val currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0
        val currentEfficiency = realtimeMetrics[performanceData.assetId]?.currentEfficiency ?: 0.0
        
        return BenchmarkComparison(
            utilizationVsBenchmark = (currentUtilization / benchmark.averageUtilization - 1.0) * 100,
            efficiencyVsBenchmark = (currentEfficiency / benchmark.averageEfficiency - 1.0) * 100,
            revenueVsBenchmark = if (performanceData.totalOperatingHours > 0) {
                val revenuePerHour = performanceData.totalRevenue / performanceData.totalOperatingHours
                (revenuePerHour / benchmark.averageRevenuePerHour - 1.0) * 100
            } else 0.0,
            rankingPercentile = calculatePercentileRanking(performanceData)
        )
    }
    
    private fun createDefaultBenchmark(assetType: AssetType): BenchmarkMetrics {
        return when (assetType) {
            AssetType.CONTAINER_SHIP -> BenchmarkMetrics(
                assetType = assetType,
                averageUtilization = 0.75,
                averageEfficiency = 0.80,
                averageRevenuePerHour = 5000.0,
                averageOperatingCostPerHour = 3000.0
            )
            AssetType.CARGO_AIRCRAFT -> BenchmarkMetrics(
                assetType = assetType,
                averageUtilization = 0.85,
                averageEfficiency = 0.85,
                averageRevenuePerHour = 15000.0,
                averageOperatingCostPerHour = 8000.0
            )
            AssetType.WAREHOUSE -> BenchmarkMetrics(
                assetType = assetType,
                averageUtilization = 0.80,
                averageEfficiency = 0.75,
                averageRevenuePerHour = 100.0,
                averageOperatingCostPerHour = 50.0
            )
            else -> BenchmarkMetrics(
                assetType = assetType,
                averageUtilization = 0.70,
                averageEfficiency = 0.70,
                averageRevenuePerHour = 1000.0,
                averageOperatingCostPerHour = 600.0
            )
        }
    }
    
    private fun calculatePercentileRanking(performanceData: AssetPerformanceData): Double {
        // Simplified percentile calculation
        val similarAssets = assetMetrics.values.filter { it.assetType == performanceData.assetType }
        if (similarAssets.size < 2) return 50.0
        
        val currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0
        val betterAssets = similarAssets.count { asset ->
            val otherUtilization = realtimeMetrics[asset.assetId]?.currentUtilization ?: 0.0
            otherUtilization < currentUtilization
        }
        
        return (betterAssets.toDouble() / similarAssets.size) * 100.0
    }
    
    private fun calculateFleetUtilization(assets: Collection<AssetPerformanceData>): Double {
        return assets.mapNotNull { asset ->
            realtimeMetrics[asset.assetId]?.currentUtilization
        }.average()
    }
    
    private fun calculateFleetEfficiency(assets: Collection<AssetPerformanceData>): Double {
        return assets.mapNotNull { asset ->
            realtimeMetrics[asset.assetId]?.currentEfficiency
        }.average()
    }
    
    private fun calculateFleetROI(assets: Collection<AssetPerformanceData>): Double {
        val totalRevenue = assets.sumOf { it.totalRevenue }
        val totalCosts = assets.sumOf { it.totalOperatingCosts }
        
        return if (totalCosts > 0) {
            (totalRevenue - totalCosts) / totalCosts
        } else 0.0
    }
    
    private fun identifyTopPerformers(assets: Collection<AssetPerformanceData>): List<TopPerformer> {
        return assets.mapNotNull { asset ->
            val realtime = realtimeMetrics[asset.assetId]
            if (realtime != null) {
                TopPerformer(
                    assetId = asset.assetId,
                    assetType = asset.assetType,
                    score = realtime.currentEfficiency * realtime.currentUtilization,
                    metric = "Overall Performance"
                )
            } else null
        }.sortedByDescending { it.score }.take(10)
    }
    
    private fun identifyUnderPerformers(assets: Collection<AssetPerformanceData>): List<UnderPerformer> {
        return assets.mapNotNull { asset ->
            val realtime = realtimeMetrics[asset.assetId]
            if (realtime != null && realtime.currentUtilization < 0.5) {
                UnderPerformer(
                    assetId = asset.assetId,
                    assetType = asset.assetType,
                    issue = "Low Utilization",
                    severity = if (realtime.currentUtilization < 0.3) RiskLevel.HIGH else RiskLevel.MEDIUM,
                    recommendation = "Review assignment strategy"
                )
            } else null
        }.sortedBy { it.severity }
    }
    
    private fun generateFleetTrends(assets: Collection<AssetPerformanceData>): FleetTrends {
        // Simplified fleet trends calculation
        return FleetTrends(
            utilizationTrend = TrendDirection.STABLE,
            efficiencyTrend = TrendDirection.IMPROVING,
            revenueTrend = TrendDirection.IMPROVING,
            costTrend = TrendDirection.STABLE
        )
    }
    
    private fun generateFleetMaintenanceSchedule(assets: Collection<AssetPerformanceData>): FleetMaintenanceSchedule {
        val upcomingMaintenance = assets.map { asset ->
            MaintenanceItem(
                assetId = asset.assetId,
                assetType = asset.assetType,
                scheduledDate = LocalDateTime.now().plusDays((Math.random() * 30).toLong()),
                maintenanceType = MaintenanceType.ROUTINE,
                estimatedCost = 5000.0,
                priority = MaintenancePriority.MEDIUM
            )
        }.sortedBy { it.scheduledDate }
        
        return FleetMaintenanceSchedule(
            upcomingMaintenance = upcomingMaintenance,
            totalScheduledCost = upcomingMaintenance.sumOf { it.estimatedCost },
            criticalMaintenance = upcomingMaintenance.filter { it.priority == MaintenancePriority.CRITICAL }
        )
    }
    
    private fun generateResourceOptimization(assets: Collection<AssetPerformanceData>): ResourceOptimization {
        return ResourceOptimization(
            underutilizedAssets = assets.filter { asset ->
                (realtimeMetrics[asset.assetId]?.currentUtilization ?: 0.0) < 0.5
            }.map { it.assetId },
            optimizationOpportunities = listOf(
                "Consolidate routes for better utilization",
                "Reassign underperforming assets to high-demand routes",
                "Consider fleet capacity adjustments"
            ),
            potentialSavings = assets.size * 10000.0 // Simplified calculation
        )
    }
    
    private fun predictUtilization(history: List<PerformanceSnapshot>): UtilizationPrediction {
        // Simplified linear trend prediction
        val utilizationValues = history.map { it.utilizationRate }
        val trend = utilizationValues.takeLast(10).average() - utilizationValues.take(10).average()
        
        return UtilizationPrediction(
            predicted30Days = utilizationValues.last() + (trend * 30),
            predicted60Days = utilizationValues.last() + (trend * 60),
            predicted90Days = utilizationValues.last() + (trend * 90),
            confidence = 0.75
        )
    }
    
    private fun predictMaintenanceNeeds(assetId: String, history: List<PerformanceSnapshot>): MaintenanceNeeds {
        // Simplified maintenance prediction
        return MaintenanceNeeds(
            nextMaintenanceDate = LocalDateTime.now().plusDays(45),
            maintenanceType = MaintenanceType.ROUTINE,
            estimatedCost = 8000.0,
            urgency = MaintenancePriority.MEDIUM
        )
    }
    
    private fun predictRevenue(history: List<PerformanceSnapshot>): RevenuePrediction {
        val revenueValues = history.map { it.revenue }
        val recentAverage = revenueValues.takeLast(30).average()
        
        return RevenuePrediction(
            predicted30Days = recentAverage * 30,
            predicted60Days = recentAverage * 60,
            predicted90Days = recentAverage * 90,
            confidence = 0.80
        )
    }
    
    private fun predictCosts(history: List<PerformanceSnapshot>): CostPrediction {
        val costValues = history.map { it.operatingCosts }
        val recentAverage = costValues.takeLast(30).average()
        
        return CostPrediction(
            predicted30Days = recentAverage * 30,
            predicted60Days = recentAverage * 60,
            predicted90Days = recentAverage * 90,
            confidence = 0.80
        )
    }
    
    private fun identifyRiskFactors(
        performanceData: AssetPerformanceData,
        history: List<PerformanceSnapshot>
    ): List<String> {
        val risks = mutableListOf<String>()
        
        val currentUtilization = realtimeMetrics[performanceData.assetId]?.currentUtilization ?: 0.0
        if (currentUtilization < 0.3) {
            risks.add("Consistently low utilization")
        }
        
        if (performanceData.maintenanceEvents > 10) {
            risks.add("High maintenance frequency")
        }
        
        val recentEfficiency = history.takeLast(7).map { it.efficiency }.average()
        if (recentEfficiency < 0.6) {
            risks.add("Declining operational efficiency")
        }
        
        return risks.ifEmpty { listOf("No significant risk factors identified") }
    }
    
    private fun generatePredictiveRecommendations(assetId: String, history: List<PerformanceSnapshot>): List<String> {
        val recommendations = mutableListOf<String>()
        
        val utilizationTrend = calculateUtilizationTrend(assetMetrics[assetId]?.utilizationHistory ?: emptyList())
        if (utilizationTrend == TrendDirection.DECLINING) {
            recommendations.add("Investigate causes of declining utilization and consider route reassignment")
        }
        
        val efficiencyTrend = calculateEfficiencyTrend(assetMetrics[assetId]?.efficiencyTrends ?: emptyList())
        if (efficiencyTrend == TrendDirection.DECLINING) {
            recommendations.add("Schedule efficiency audit and potential equipment upgrades")
        }
        
        recommendations.add("Continue monitoring performance metrics for early intervention opportunities")
        
        return recommendations
    }
    
    private fun calculateUtilizationTrend(): TrendDirection {
        // Simplified fleet-wide utilization trend
        return TrendDirection.STABLE
    }
    
    private fun calculateEfficiencyTrend(): TrendDirection {
        // Simplified fleet-wide efficiency trend
        return TrendDirection.IMPROVING
    }
    
    private fun updateAnalyticsState() {
        val analytics = assetMetrics.mapValues { (assetId, performanceData) ->
            AssetAnalytics(
                assetId = assetId,
                lastUpdated = LocalDateTime.now(),
                performanceScore = calculateOverallScore(
                    realtimeMetrics[assetId]?.currentUtilization ?: 0.0,
                    realtimeMetrics[assetId]?.currentEfficiency ?: 0.0,
                    performanceData
                ),
                utilizationRate = realtimeMetrics[assetId]?.currentUtilization ?: 0.0,
                efficiency = realtimeMetrics[assetId]?.currentEfficiency ?: 0.0,
                recentAlerts = performanceData.performanceAlerts.takeLast(5)
            )
        }
        
        _analyticsData.value = analytics
    }
}

// Data classes for analytics
data class AssetPerformanceData(
    val assetId: String,
    val assetType: AssetType,
    val trackingStartDate: LocalDateTime,
    var totalOperatingHours: Double,
    var totalRevenue: Double,
    var totalOperatingCosts: Double,
    var fuelConsumption: Double,
    var maintenanceEvents: Int,
    val utilizationHistory: MutableList<UtilizationDataPoint>,
    val efficiencyTrends: MutableList<EfficiencyDataPoint>,
    val performanceAlerts: MutableList<PerformanceAlert>
)

data class OperationalDataPoint(
    val operatingHours: Double,
    val revenue: Double,
    val operatingCosts: Double,
    val fuelConsumed: Double,
    val utilizationRate: Double,
    val loadFactor: Double,
    val averageSpeed: Double,
    val fuelEfficiency: Double,
    val timeEfficiency: Double,
    val context: String
)

data class UtilizationDataPoint(
    val timestamp: LocalDateTime,
    val utilizationRate: Double,
    val loadFactor: Double,
    val operatingContext: String
)

data class EfficiencyDataPoint(
    val timestamp: LocalDateTime,
    val fuelEfficiency: Double,
    val timeEfficiency: Double,
    val costEfficiency: Double,
    val overallEfficiency: Double
)

data class PerformanceAlert(
    val id: String,
    val assetId: String,
    val alertType: AlertType,
    val severity: AlertSeverity,
    val message: String,
    val timestamp: LocalDateTime,
    val value: Double,
    val threshold: Double
)

data class PerformanceSnapshot(
    val timestamp: LocalDateTime,
    val utilizationRate: Double,
    val efficiency: Double,
    val revenue: Double,
    val operatingCosts: Double,
    val maintenanceEvents: Int,
    val fuelConsumption: Double,
    val operatingHours: Double
)

data class RealtimeMetrics(
    val assetId: String,
    val currentUtilization: Double,
    val currentEfficiency: Double,
    val currentSpeed: Double,
    val fuelEfficiency: Double,
    val lastUpdated: LocalDateTime
)

data class AlertThresholds(
    val lowUtilizationThreshold: Double,
    val highMaintenanceCostThreshold: Double,
    val lowEfficiencyThreshold: Double,
    val highFuelConsumptionThreshold: Double
)

data class KPITracker(
    val assetId: String,
    val targetUtilization: Double,
    val targetEfficiency: Double,
    val targetRevenue: Double
)

data class BenchmarkMetrics(
    val assetType: AssetType,
    val averageUtilization: Double,
    val averageEfficiency: Double,
    val averageRevenuePerHour: Double,
    val averageOperatingCostPerHour: Double
)

data class AssetAnalytics(
    val assetId: String,
    val lastUpdated: LocalDateTime,
    val performanceScore: Double,
    val utilizationRate: Double,
    val efficiency: Double,
    val recentAlerts: List<PerformanceAlert>
)

// Report data classes
data class AssetAnalyticsReport(
    val assetId: String,
    val assetType: AssetType,
    val reportPeriod: ReportPeriod,
    val generatedAt: LocalDateTime,
    val performanceSummary: PerformanceSummary,
    val utilizationAnalysis: UtilizationAnalysis,
    val efficiencyAnalysis: EfficiencyAnalysis,
    val financialMetrics: FinancialMetrics,
    val maintenanceInsights: MaintenanceInsights,
    val riskAssessment: RiskAssessment,
    val recommendations: List<AssetRecommendation>,
    val trendAnalysis: TrendAnalysis,
    val benchmarkComparison: BenchmarkComparison
)

data class FleetAnalyticsReport(
    val reportType: String,
    val totalAssets: Int,
    val generatedAt: LocalDateTime,
    val fleetUtilization: Double,
    val fleetEfficiency: Double,
    val totalRevenue: Double,
    val totalOperatingCosts: Double,
    val fleetROI: Double,
    val topPerformers: List<TopPerformer>,
    val underPerformers: List<UnderPerformer>,
    val fleetTrends: FleetTrends,
    val maintenanceSchedule: FleetMaintenanceSchedule,
    val resourceOptimization: ResourceOptimization
)

data class PredictiveAnalysis(
    val assetId: String,
    val predictionHorizon: Int,
    val confidenceLevel: Double,
    val predictedUtilization: UtilizationPrediction,
    val predictedMaintenanceNeeds: MaintenanceNeeds,
    val predictedRevenue: RevenuePrediction,
    val predictedCosts: CostPrediction,
    val riskFactors: List<String>,
    val recommendations: List<String>
)

data class AssetDashboardData(
    val totalAssets: Int,
    val operationalAssets: Int,
    val averageUtilization: Double,
    val totalRevenue: Double,
    val totalOperatingCosts: Double,
    val activeAlerts: Int,
    val criticalAlerts: Int,
    val fleetEfficiency: Double,
    val topPerformingAssets: List<TopPerformer>,
    val recentAlerts: List<PerformanceAlert>,
    val utilizationTrend: TrendDirection,
    val efficiencyTrend: TrendDirection
)

// Component data classes
data class PerformanceSummary(
    val overallScore: Double,
    val utilizationScore: Double,
    val efficiencyScore: Double,
    val revenueScore: Double,
    val maintenanceScore: Double,
    val trend: TrendDirection
)

data class UtilizationAnalysis(
    val currentUtilization: Double,
    val averageUtilization: Double,
    val peakUtilization: Double,
    val lowUtilizationPeriods: Int,
    val utilizationTrend: TrendDirection,
    val seasonalPatterns: List<String>
)

data class EfficiencyAnalysis(
    val currentFuelEfficiency: Double,
    val averageFuelEfficiency: Double,
    val timeEfficiency: Double,
    val costEfficiency: Double,
    val overallEfficiency: Double,
    val efficiencyTrend: TrendDirection,
    val improvementOpportunities: List<String>
)

data class FinancialMetrics(
    val totalRevenue: Double,
    val totalOperatingCosts: Double,
    val netProfit: Double,
    val roi: Double,
    val revenuePerHour: Double,
    val costPerHour: Double
)

data class MaintenanceInsights(
    val totalMaintenanceEvents: Int,
    val averageTimeBetweenMaintenance: Double,
    val maintenanceCostRatio: Double,
    val predictedNextMaintenance: LocalDateTime,
    val maintenanceEffectiveness: Double
) {
    companion object {
        fun empty() = MaintenanceInsights(0, 0.0, 0.0, LocalDateTime.now(), 0.0)
    }
}

data class RiskAssessment(
    val overallRisk: RiskLevel,
    val riskFactors: List<RiskFactor>,
    val riskScore: Double,
    val recommendations: List<String>
)

data class RiskFactor(
    val type: String,
    val severity: RiskLevel,
    val description: String,
    val mitigation: String
)

data class AssetRecommendation(
    val type: String,
    val priority: RecommendationPriority,
    val description: String,
    val action: String,
    val expectedImpact: String
)

data class TrendAnalysis(
    val utilizationTrend: TrendDirection,
    val efficiencyTrend: TrendDirection,
    val revenueTrend: TrendDirection,
    val costTrend: TrendDirection,
    val dataPoints: Int
) {
    companion object {
        fun insufficient() = TrendAnalysis(
            TrendDirection.STABLE, TrendDirection.STABLE,
            TrendDirection.STABLE, TrendDirection.STABLE, 0
        )
    }
}

data class BenchmarkComparison(
    val utilizationVsBenchmark: Double,
    val efficiencyVsBenchmark: Double,
    val revenueVsBenchmark: Double,
    val rankingPercentile: Double
)

data class TopPerformer(
    val assetId: String,
    val assetType: AssetType,
    val score: Double,
    val metric: String
)

data class UnderPerformer(
    val assetId: String,
    val assetType: AssetType,
    val issue: String,
    val severity: RiskLevel,
    val recommendation: String
)

data class FleetTrends(
    val utilizationTrend: TrendDirection,
    val efficiencyTrend: TrendDirection,
    val revenueTrend: TrendDirection,
    val costTrend: TrendDirection
)

data class FleetMaintenanceSchedule(
    val upcomingMaintenance: List<MaintenanceItem>,
    val totalScheduledCost: Double,
    val criticalMaintenance: List<MaintenanceItem>
)

data class MaintenanceItem(
    val assetId: String,
    val assetType: AssetType,
    val scheduledDate: LocalDateTime,
    val maintenanceType: MaintenanceType,
    val estimatedCost: Double,
    val priority: MaintenancePriority
)

data class ResourceOptimization(
    val underutilizedAssets: List<String>,
    val optimizationOpportunities: List<String>,
    val potentialSavings: Double
)

// Prediction data classes
data class UtilizationPrediction(
    val predicted30Days: Double,
    val predicted60Days: Double,
    val predicted90Days: Double,
    val confidence: Double
)

data class MaintenanceNeeds(
    val nextMaintenanceDate: LocalDateTime,
    val maintenanceType: MaintenanceType,
    val estimatedCost: Double,
    val urgency: MaintenancePriority
)

data class RevenuePrediction(
    val predicted30Days: Double,
    val predicted60Days: Double,
    val predicted90Days: Double,
    val confidence: Double
)

data class CostPrediction(
    val predicted30Days: Double,
    val predicted60Days: Double,
    val predicted90Days: Double,
    val confidence: Double
)

// Enums
enum class AlertType {
    LOW_UTILIZATION, HIGH_FUEL_CONSUMPTION, LOW_EFFICIENCY, 
    MAINTENANCE_DUE, PERFORMANCE_DEGRADATION, ROUTE_INEFFICIENCY
}

enum class AlertSeverity {
    LOW, MEDIUM, HIGH, CRITICAL, RESOLVED
}

enum class TrendDirection {
    IMPROVING, STABLE, DECLINING
}

enum class RecommendationPriority {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class ReportPeriod {
    DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY, CURRENT
}

enum class MaintenancePriority {
    LOW, MEDIUM, HIGH, CRITICAL
}