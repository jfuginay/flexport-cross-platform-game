package com.flexport.assets.ecs

import com.flexport.ecs.core.Component
import com.flexport.assets.models.*
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.math.Vector3
import java.time.LocalDateTime

/**
 * Enhanced ECS components for FlexPort asset management system
 * Integrates with rendering engine and provides rich game mechanics
 */

/**
 * Core asset component with comprehensive asset data
 */
data class FlexPortAssetComponent(
    val assetId: String,
    val assetType: AssetType,
    val asset: FlexPortAsset,
    var isVisible: Boolean = true,
    var isSelectable: Boolean = true,
    var renderLayer: Int = 0,
    var scale: Float = 1.0f,
    var opacity: Float = 1.0f
) : Component

/**
 * Asset movement and pathfinding component
 */
data class AssetMovementComponent(
    var velocity: Vector2 = Vector2.ZERO,
    var acceleration: Vector2 = Vector2.ZERO,
    var maxSpeed: Float = 10.0f,
    var currentSpeed: Float = 0.0f,
    var heading: Float = 0.0f, // degrees
    var targetHeading: Float = 0.0f,
    var rotationSpeed: Float = 90.0f, // degrees per second
    var path: List<Vector2> = emptyList(),
    var currentPathIndex: Int = 0,
    var pathFollowingEnabled: Boolean = false,
    var arrivalThreshold: Float = 2.0f,
    var movementType: MovementType = MovementType.STRAIGHT_LINE
) : Component {
    
    fun hasPath(): Boolean = path.isNotEmpty() && currentPathIndex < path.size
    fun getCurrentTarget(): Vector2? = path.getOrNull(currentPathIndex)
    fun getNextWaypoint(): Vector2? = path.getOrNull(currentPathIndex + 1)
    fun getProgress(): Float = if (path.isEmpty()) 1.0f else currentPathIndex.toFloat() / path.size
}

/**
 * Asset animation and visual effects component
 */
data class AssetAnimationComponent(
    var currentAnimation: String = "idle",
    var animationSpeed: Float = 1.0f,
    var animationTime: Float = 0.0f,
    var isLooping: Boolean = true,
    var isPaused: Boolean = false,
    val animations: MutableMap<String, AssetAnimation> = mutableMapOf(),
    var queuedAnimations: MutableList<String> = mutableListOf(),
    var transitionTime: Float = 0.5f,
    var isTransitioning: Boolean = false,
    var transitionProgress: Float = 0.0f
) : Component {
    
    fun playAnimation(name: String, loop: Boolean = true, queue: Boolean = false) {
        if (queue) {
            queuedAnimations.add(name)
        } else {
            currentAnimation = name
            isLooping = loop
            animationTime = 0.0f
            isPaused = false
        }
    }
    
    fun hasAnimation(name: String): Boolean = animations.containsKey(name)
}

/**
 * Asset operation and activity component
 */
data class AssetOperationComponent(
    var currentOperation: AssetOperation? = null,
    var operationProgress: Float = 0.0f,
    var operationQueue: MutableList<AssetOperation> = mutableListOf(),
    var isOperating: Boolean = false,
    var efficiency: Float = 1.0f,
    var workCapacity: Float = 100.0f,
    var currentWorkload: Float = 0.0f,
    var fatigue: Float = 0.0f,
    var maintenanceTimer: Float = 0.0f,
    var nextMaintenanceTime: Float = 24.0f * 60.0f, // 24 hours in minutes
    var operationalState: OperationalState = OperationalState.READY
) : Component {
    
    fun addOperation(operation: AssetOperation) {
        if (currentOperation == null) {
            currentOperation = operation
            isOperating = true
            operationProgress = 0.0f
        } else {
            operationQueue.add(operation)
        }
    }
    
    fun completeCurrentOperation() {
        currentOperation = null
        operationProgress = 0.0f
        
        if (operationQueue.isNotEmpty()) {
            currentOperation = operationQueue.removeAt(0)
        } else {
            isOperating = false
        }
    }
    
    fun getUtilizationRate(): Float = currentWorkload / workCapacity
    fun needsMaintenance(): Boolean = maintenanceTimer >= nextMaintenanceTime
}

/**
 * Asset cargo and inventory management component
 */
data class AssetCargoComponent(
    val maxCapacity: CargoCapacity,
    var currentCargo: MutableList<CargoItem> = mutableListOf(),
    var reservedCapacity: CargoCapacity = CargoCapacity.empty(),
    val cargoTypes: List<CargoType> = listOf(CargoType.GENERAL),
    val specialCapabilities: List<CargoCapability> = emptyList(),
    var loadingSpeed: Float = 10.0f, // units per minute
    var unloadingSpeed: Float = 10.0f,
    var isLoading: Boolean = false,
    var isUnloading: Boolean = false,
    var loadingProgress: Float = 0.0f
) : Component {
    
    fun getAvailableCapacity(): CargoCapacity {
        val used = getCurrentUsedCapacity()
        val reserved = reservedCapacity
        return CargoCapacity(
            weight = maxCapacity.weight - used.weight - reserved.weight,
            volume = maxCapacity.volume - used.volume - reserved.volume,
            units = maxCapacity.units - used.units - reserved.units
        )
    }
    
    fun getCurrentUsedCapacity(): CargoCapacity {
        return currentCargo.fold(CargoCapacity.empty()) { acc, item ->
            acc + item.capacity
        }
    }
    
    fun canAccommodate(item: CargoItem): Boolean {
        val available = getAvailableCapacity()
        return available.weight >= item.capacity.weight &&
               available.volume >= item.capacity.volume &&
               available.units >= item.capacity.units &&
               cargoTypes.contains(item.type)
    }
    
    fun getUtilizationRate(): Float {
        val used = getCurrentUsedCapacity()
        return minOf(
            used.weight / maxCapacity.weight,
            used.volume / maxCapacity.volume,
            used.units / maxCapacity.units
        )
    }
}

/**
 * Asset economics and financial tracking component
 */
data class AssetEconomicsComponent(
    var purchasePrice: Double,
    var currentValue: Double,
    var dailyOperatingCost: Double = 0.0,
    var dailyRevenue: Double = 0.0,
    var maintenanceCost: Double = 0.0,
    var fuelCost: Double = 0.0,
    var totalRevenue: Double = 0.0,
    var totalCosts: Double = 0.0,
    var profitability: Double = 0.0,
    var roi: Double = 0.0,
    var depreciationRate: Double = 0.05, // 5% annual
    var insuranceCost: Double = 0.0,
    var taxRate: Double = 0.0,
    var lastFinancialUpdate: LocalDateTime = LocalDateTime.now(),
    val costBreakdown: MutableMap<String, Double> = mutableMapOf(),
    val revenueBreakdown: MutableMap<String, Double> = mutableMapOf()
) : Component {
    
    fun updateDailyFinancials(deltaTime: Float) {
        val dayFraction = deltaTime / (24.0f * 60.0f) // deltaTime in minutes
        
        totalCosts += dailyOperatingCost * dayFraction
        totalRevenue += dailyRevenue * dayFraction
        profitability = totalRevenue - totalCosts
        roi = if (totalCosts > 0) profitability / totalCosts else 0.0
        
        // Update depreciation
        val yearFraction = deltaTime / (365.0f * 24.0f * 60.0f)
        currentValue *= (1.0 - depreciationRate * yearFraction)
    }
    
    fun addCost(category: String, amount: Double) {
        costBreakdown[category] = (costBreakdown[category] ?: 0.0) + amount
        totalCosts += amount
    }
    
    fun addRevenue(category: String, amount: Double) {
        revenueBreakdown[category] = (revenueBreakdown[category] ?: 0.0) + amount
        totalRevenue += amount
    }
}

/**
 * Asset health and condition monitoring component
 */
data class AssetHealthComponent(
    var condition: AssetCondition = AssetCondition.EXCELLENT,
    var healthPercentage: Float = 100.0f,
    var wearRate: Float = 1.0f, // Wear per operating hour
    var maintenanceLevel: Float = 100.0f,
    var reliability: Float = 0.95f,
    var criticalSystems: MutableMap<String, SystemHealth> = mutableMapOf(),
    var alerts: MutableList<HealthAlert> = mutableListOf(),
    var maintenanceHistory: MutableList<MaintenanceRecord> = mutableListOf(),
    var lastInspection: LocalDateTime? = null,
    var nextScheduledMaintenance: LocalDateTime? = null,
    var breakdownProbability: Float = 0.0f
) : Component {
    
    fun updateHealth(deltaTime: Float, operatingIntensity: Float = 1.0f) {
        // Calculate wear based on operating time and intensity
        val hourlyWear = wearRate * operatingIntensity * (deltaTime / 60.0f)
        healthPercentage = (healthPercentage - hourlyWear).coerceAtLeast(0.0f)
        maintenanceLevel = (maintenanceLevel - hourlyWear * 0.5f).coerceAtLeast(0.0f)
        
        // Update condition based on health
        condition = when {
            healthPercentage >= 90.0f -> AssetCondition.EXCELLENT
            healthPercentage >= 75.0f -> AssetCondition.GOOD
            healthPercentage >= 50.0f -> AssetCondition.FAIR
            healthPercentage >= 25.0f -> AssetCondition.POOR
            else -> AssetCondition.NEEDS_REPAIR
        }
        
        // Update breakdown probability
        breakdownProbability = (100.0f - healthPercentage) / 100.0f * 0.1f
        
        // Check for critical system failures
        checkCriticalSystems()
    }
    
    fun performMaintenance(maintenanceType: MaintenanceType, effectiveness: Float = 0.8f) {
        when (maintenanceType) {
            MaintenanceType.ROUTINE -> {
                maintenanceLevel = (maintenanceLevel + 20.0f * effectiveness).coerceAtMost(100.0f)
            }
            MaintenanceType.PREVENTIVE -> {
                healthPercentage = (healthPercentage + 15.0f * effectiveness).coerceAtMost(100.0f)
                maintenanceLevel = (maintenanceLevel + 30.0f * effectiveness).coerceAtMost(100.0f)
            }
            MaintenanceType.OVERHAUL -> {
                healthPercentage = (healthPercentage + 40.0f * effectiveness).coerceAtMost(100.0f)
                maintenanceLevel = 100.0f
            }
            MaintenanceType.EMERGENCY -> {
                // Fix critical issues
                healthPercentage = (healthPercentage + 10.0f * effectiveness).coerceAtMost(100.0f)
            }
            MaintenanceType.SCHEDULED -> {
                healthPercentage = (healthPercentage + 25.0f * effectiveness).coerceAtMost(100.0f)
                maintenanceLevel = (maintenanceLevel + 35.0f * effectiveness).coerceAtMost(100.0f)
            }
        }
        
        reliability = 0.5f + (healthPercentage / 100.0f) * 0.45f
        lastInspection = LocalDateTime.now()
    }
    
    private fun checkCriticalSystems() {
        criticalSystems.forEach { (system, health) ->
            if (health.status == SystemStatus.CRITICAL && !alerts.any { it.system == system }) {
                alerts.add(HealthAlert(
                    system = system,
                    severity = AlertSeverity.CRITICAL,
                    message = "Critical system failure: $system",
                    timestamp = LocalDateTime.now()
                ))
            }
        }
    }
}

/**
 * Asset route and navigation component
 */
data class AssetRouteComponent(
    var currentRoute: TradeRoute? = null,
    var routeProgress: Float = 0.0f,
    var nextWaypoint: String? = null,
    var waypointProgress: Float = 0.0f,
    var estimatedArrival: LocalDateTime? = null,
    var routeStartTime: LocalDateTime? = null,
    var delays: MutableList<RouteDelay> = mutableListOf(),
    var navigationMode: NavigationMode = NavigationMode.AUTOMATIC,
    var speedProfile: SpeedProfile = SpeedProfile.ECONOMIC,
    var routeOptimization: RouteOptimization = RouteOptimization.SHORTEST,
    var weatherImpact: Float = 1.0f,
    var trafficImpact: Float = 1.0f
) : Component {
    
    fun getEstimatedTimeRemaining(): Float? {
        return estimatedArrival?.let { arrival ->
            val now = LocalDateTime.now()
            if (arrival.isAfter(now)) {
                java.time.Duration.between(now, arrival).toMinutes().toFloat()
            } else 0.0f
        }
    }
    
    fun addDelay(reason: String, delayMinutes: Float) {
        delays.add(RouteDelay(
            reason = reason,
            delayMinutes = delayMinutes,
            timestamp = LocalDateTime.now()
        ))
        
        // Update estimated arrival
        estimatedArrival = estimatedArrival?.plusMinutes(delayMinutes.toLong())
    }
    
    fun getTotalDelay(): Float = delays.sumOf { it.delayMinutes.toDouble() }.toFloat()
}

/**
 * Asset interaction and selection component
 */
data class AssetInteractionComponent(
    var isSelected: Boolean = false,
    var isHighlighted: Boolean = false,
    var isHovered: Boolean = false,
    var selectionPriority: Int = 0,
    var clickable: Boolean = true,
    var draggable: Boolean = false,
    var contextMenuEnabled: Boolean = true,
    var tooltipEnabled: Boolean = true,
    var tooltipText: String = "",
    val interactionCallbacks: MutableMap<InteractionType, () -> Unit> = mutableMapOf(),
    var lastInteractionTime: LocalDateTime = LocalDateTime.now(),
    var selectionRadius: Float = 5.0f,
    var interactionCooldown: Float = 0.0f
) : Component {
    
    fun canInteract(): Boolean = clickable && interactionCooldown <= 0.0f
    
    fun triggerInteraction(type: InteractionType) {
        if (canInteract()) {
            interactionCallbacks[type]?.invoke()
            lastInteractionTime = LocalDateTime.now()
            interactionCooldown = 0.5f // 0.5 second cooldown
        }
    }
}

/**
 * Asset UI overlay component for displaying information
 */
data class AssetUIComponent(
    var showHealthBar: Boolean = true,
    var showProgressBar: Boolean = false,
    var showLabel: Boolean = true,
    var showStatus: Boolean = true,
    var labelText: String = "",
    var statusText: String = "",
    var progressValue: Float = 0.0f,
    var healthBarColor: UIColor = UIColor.GREEN,
    var labelOffset: Vector2 = Vector2(0.0f, -20.0f),
    var uiScale: Float = 1.0f,
    var fadeDistance: Float = 100.0f,
    var minimumVisibleScale: Float = 0.1f,
    var alwaysVisible: Boolean = false,
    val customElements: MutableList<UIElement> = mutableListOf()
) : Component {
    
    fun updateHealthBarColor(healthPercentage: Float) {
        healthBarColor = when {
            healthPercentage >= 75.0f -> UIColor.GREEN
            healthPercentage >= 50.0f -> UIColor.YELLOW
            healthPercentage >= 25.0f -> UIColor.ORANGE
            else -> UIColor.RED
        }
    }
}

/**
 * Asset environmental interaction component
 */
data class AssetEnvironmentComponent(
    var currentWeather: WeatherCondition = WeatherCondition.CLEAR,
    var weatherImpact: Float = 1.0f,
    var seaState: SeaState? = null,
    var windSpeed: Float = 0.0f,
    var windDirection: Float = 0.0f,
    var visibility: Float = 100.0f, // km
    var temperature: Float = 20.0f, // Celsius
    var environmentalEfficiency: Float = 1.0f,
    var hazardousConditions: MutableList<EnvironmentalHazard> = mutableListOf(),
    var adaptationLevel: Float = 1.0f
) : Component {
    
    fun updateWeatherImpact() {
        weatherImpact = when (currentWeather) {
            WeatherCondition.CLEAR -> 1.0f
            WeatherCondition.CLOUDY -> 0.98f
            WeatherCondition.RAINY -> 0.9f
            WeatherCondition.STORMY -> 0.7f
            WeatherCondition.FOGGY -> 0.8f
            WeatherCondition.SNOW -> 0.75f
        }
        
        // Adjust for wind
        val windImpact = when {
            windSpeed > 30.0f -> 0.8f
            windSpeed > 20.0f -> 0.9f
            windSpeed > 10.0f -> 0.95f
            else -> 1.0f
        }
        
        environmentalEfficiency = weatherImpact * windImpact * adaptationLevel
    }
}

/**
 * Asset performance tracking component
 */
data class AssetPerformanceComponent(
    var currentEfficiency: Float = 1.0f,
    var averageEfficiency: Float = 1.0f,
    var fuelConsumptionRate: Float = 0.0f,
    var speedEfficiency: Float = 1.0f,
    var loadEfficiency: Float = 1.0f,
    var timeEfficiency: Float = 1.0f,
    val performanceHistory: MutableList<PerformanceSnapshot> = mutableListOf(),
    var performanceTrend: PerformanceTrend = PerformanceTrend.STABLE,
    var benchmarkScore: Float = 100.0f,
    var kpiMetrics: MutableMap<String, Float> = mutableMapOf(),
    var lastPerformanceUpdate: LocalDateTime = LocalDateTime.now()
) : Component {
    
    fun updatePerformance(deltaTime: Float) {
        // Calculate overall efficiency
        currentEfficiency = (speedEfficiency + loadEfficiency + timeEfficiency) / 3.0f
        
        // Update moving average
        averageEfficiency = (averageEfficiency * 0.9f) + (currentEfficiency * 0.1f)
        
        // Add to history (limit to last 100 snapshots)
        if (performanceHistory.size >= 100) {
            performanceHistory.removeAt(0)
        }
        
        performanceHistory.add(PerformanceSnapshot(
            timestamp = LocalDateTime.now(),
            efficiency = currentEfficiency,
            fuelConsumption = fuelConsumptionRate,
            utilization = loadEfficiency
        ))
        
        // Update trend
        updatePerformanceTrend()
    }
    
    private fun updatePerformanceTrend() {
        if (performanceHistory.size >= 10) {
            val recent = performanceHistory.takeLast(5).map { it.efficiency }.average()
            val older = performanceHistory.dropLast(5).takeLast(5).map { it.efficiency }.average()
            
            performanceTrend = when {
                recent > older * 1.05 -> PerformanceTrend.IMPROVING
                recent < older * 0.95 -> PerformanceTrend.DECLINING
                else -> PerformanceTrend.STABLE
            }
        }
    }
}

// Supporting data classes
data class AssetAnimation(
    val name: String,
    val frames: List<String>,
    val frameDuration: Float,
    val loop: Boolean = true
)

data class AssetOperation(
    val id: String,
    val type: OperationType,
    val description: String,
    val duration: Float, // minutes
    val requiredCapacity: Float,
    val priority: OperationPriority = OperationPriority.NORMAL
)

data class CargoCapacity(
    val weight: Float, // tons
    val volume: Float, // cubic meters
    val units: Int     // number of items
) {
    operator fun plus(other: CargoCapacity): CargoCapacity {
        return CargoCapacity(
            weight = this.weight + other.weight,
            volume = this.volume + other.volume,
            units = this.units + other.units
        )
    }
    
    companion object {
        fun empty(): CargoCapacity = CargoCapacity(0.0f, 0.0f, 0)
    }
}

data class CargoItem(
    val id: String,
    val type: CargoType,
    val capacity: CargoCapacity,
    val value: Double,
    val origin: String,
    val destination: String,
    val priority: CargoPriority = CargoPriority.STANDARD,
    val hazardous: Boolean = false,
    val perishable: Boolean = false,
    val specialRequirements: List<String> = emptyList()
)

data class SystemHealth(
    val name: String,
    val status: SystemStatus,
    val healthPercentage: Float,
    val lastMaintenance: LocalDateTime?,
    val criticalThreshold: Float = 20.0f
)

data class HealthAlert(
    val system: String,
    val severity: AlertSeverity,
    val message: String,
    val timestamp: LocalDateTime
)

data class RouteDelay(
    val reason: String,
    val delayMinutes: Float,
    val timestamp: LocalDateTime
)

data class UIElement(
    val type: UIElementType,
    val position: Vector2,
    val size: Vector2,
    val content: String,
    val color: UIColor,
    val visible: Boolean = true
)

data class EnvironmentalHazard(
    val type: HazardType,
    val severity: Float,
    val impact: String,
    val duration: Float? = null
)

data class PerformanceSnapshot(
    val timestamp: LocalDateTime,
    val efficiency: Float,
    val fuelConsumption: Float,
    val utilization: Float
)

// Enums
enum class MovementType {
    STRAIGHT_LINE, BEZIER_CURVE, SPLINE, PHYSICS_BASED
}

enum class OperationalState {
    READY, OPERATING, MAINTENANCE, OFFLINE, EMERGENCY
}

enum class CargoCapability {
    REFRIGERATED, HAZMAT, HEAVY_LIFT, LIQUID, BULK, CONTAINERIZED
}

enum class SystemStatus {
    OPTIMAL, GOOD, WARNING, CRITICAL, FAILED
}

enum class NavigationMode {
    MANUAL, AUTOMATIC, ASSISTED
}

enum class SpeedProfile {
    ECONOMIC, STANDARD, FAST, EMERGENCY
}

enum class RouteOptimization {
    SHORTEST, FASTEST, MOST_ECONOMICAL, SAFEST
}

enum class InteractionType {
    CLICK, DOUBLE_CLICK, RIGHT_CLICK, HOVER, DRAG_START, DRAG_END
}

enum class UIColor {
    RED, GREEN, YELLOW, ORANGE, BLUE, WHITE, BLACK, GRAY
}

enum class UIElementType {
    TEXT, PROGRESS_BAR, HEALTH_BAR, ICON, BADGE
}

enum class WeatherCondition {
    CLEAR, CLOUDY, RAINY, STORMY, FOGGY, SNOW
}

enum class SeaState {
    CALM, SLIGHT, MODERATE, ROUGH, VERY_ROUGH, HIGH, VERY_HIGH, PHENOMENAL
}

enum class HazardType {
    STORM, FOG, ICE, PIRACY, TECHNICAL_FAILURE, COLLISION_RISK
}

enum class OperationPriority {
    LOW, NORMAL, HIGH, CRITICAL
}