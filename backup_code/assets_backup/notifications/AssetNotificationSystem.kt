package com.flexport.assets.notifications

import com.flexport.assets.models.*
import com.flexport.assets.assignment.AssetAssignment
import com.flexport.assets.analytics.AssetPerformanceData
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs

/**
 * Real-time notification and update system for asset management
 * Provides live updates, alerts, and notifications for all asset-related events
 */
class AssetNotificationSystem(
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.Default)
) {
    
    // Real-time data streams
    private val _assetUpdates = MutableSharedFlow<AssetUpdate>(replay = 100)
    val assetUpdates: SharedFlow<AssetUpdate> = _assetUpdates.asSharedFlow()
    
    private val _performanceAlerts = MutableSharedFlow<PerformanceAlert>(replay = 50)
    val performanceAlerts: SharedFlow<PerformanceAlert> = _performanceAlerts.asSharedFlow()
    
    private val _maintenanceNotifications = MutableSharedFlow<MaintenanceNotification>(replay = 20)
    val maintenanceNotifications: SharedFlow<MaintenanceNotification> = _maintenanceNotifications.asSharedFlow()
    
    private val _operationalUpdates = MutableSharedFlow<OperationalUpdate>(replay = 200)
    val operationalUpdates: SharedFlow<OperationalUpdate> = _operationalUpdates.asSharedFlow()
    
    private val _economicImpacts = MutableSharedFlow<EconomicImpactNotification>(replay = 30)
    val economicImpacts: SharedFlow<EconomicImpactNotification> = _economicImpacts.asSharedFlow()
    
    // Notification subscriptions and preferences
    private val notificationSubscriptions = ConcurrentHashMap<String, NotificationSubscription>()
    private val alertThresholds = ConcurrentHashMap<String, AssetAlertThresholds>()
    private val notificationHistory = ConcurrentHashMap<String, MutableList<NotificationRecord>>()
    
    // Real-time tracking state
    private val assetStates = ConcurrentHashMap<String, AssetRealTimeState>()
    private val activeAlerts = ConcurrentHashMap<String, MutableSet<String>>()
    private val escalationTimers = ConcurrentHashMap<String, EscalationTimer>()
    
    // Update frequencies and batch processing
    private val updateBatches = ConcurrentHashMap<String, MutableList<AssetUpdate>>()
    private val lastUpdateTimes = ConcurrentHashMap<String, LocalDateTime>()
    
    init {
        startRealTimeProcessing()
    }
    
    /**
     * Subscribe to notifications for specific assets or asset types
     */
    fun subscribeToNotifications(
        subscriberId: String,
        subscription: NotificationSubscription
    ) {
        notificationSubscriptions[subscriberId] = subscription
        
        // Set up alert thresholds for subscribed assets
        subscription.assetIds.forEach { assetId ->
            if (!alertThresholds.containsKey(assetId)) {
                alertThresholds[assetId] = AssetAlertThresholds.default()
            }
        }
        
        // Initialize real-time state tracking
        subscription.assetIds.forEach { assetId ->
            if (!assetStates.containsKey(assetId)) {
                assetStates[assetId] = AssetRealTimeState.initial(assetId)
            }
        }
    }
    
    /**
     * Update alert thresholds for an asset
     */
    fun updateAlertThresholds(assetId: String, thresholds: AssetAlertThresholds) {
        alertThresholds[assetId] = thresholds
        
        // Re-evaluate current state against new thresholds
        assetStates[assetId]?.let { state ->
            evaluateThresholds(assetId, state, thresholds)
        }
    }
    
    /**
     * Process real-time asset data update
     */
    suspend fun processAssetUpdate(
        assetId: String,
        updateData: AssetUpdateData,
        source: UpdateSource = UpdateSource.SYSTEM
    ) {
        val timestamp = LocalDateTime.now()
        val previousState = assetStates[assetId]
        
        // Update real-time state
        val newState = updateAssetState(assetId, updateData, timestamp)
        assetStates[assetId] = newState
        
        // Create update event
        val update = AssetUpdate(
            assetId = assetId,
            timestamp = timestamp,
            updateType = determineUpdateType(updateData, previousState),
            data = updateData,
            source = source,
            priority = calculateUpdatePriority(updateData, previousState)
        )
        
        // Check for alerts and thresholds
        alertThresholds[assetId]?.let { thresholds ->
            evaluateThresholds(assetId, newState, thresholds)
        }
        
        // Batch or immediately emit update based on priority
        when (update.priority) {
            UpdatePriority.CRITICAL, UpdatePriority.HIGH -> {
                _assetUpdates.emit(update)
                processImmediateNotifications(update)
            }
            UpdatePriority.MEDIUM -> {
                batchUpdate(update)
            }
            UpdatePriority.LOW -> {
                batchUpdate(update, delay = 30000) // 30 second delay for low priority
            }
        }
        
        lastUpdateTimes[assetId] = timestamp
    }
    
    /**
     * Report performance metrics and trigger analytics
     */
    suspend fun reportPerformanceMetrics(
        assetId: String,
        metrics: PerformanceMetrics,
        analysisResults: PerformanceAnalysisResults? = null
    ) {
        val timestamp = LocalDateTime.now()
        
        // Update performance state
        assetStates[assetId]?.let { state ->
            val updatedState = state.copy(
                performanceMetrics = metrics,
                lastAnalysis = analysisResults,
                lastPerformanceUpdate = timestamp
            )
            assetStates[assetId] = updatedState
            
            // Check for performance alerts
            checkPerformanceAlerts(assetId, metrics, analysisResults)
        }
        
        // Emit operational update
        val operationalUpdate = OperationalUpdate(
            assetId = assetId,
            timestamp = timestamp,
            operationType = OperationType.PERFORMANCE_UPDATE,
            metrics = metrics,
            analysisResults = analysisResults,
            impactLevel = assessPerformanceImpact(metrics, analysisResults)
        )
        
        _operationalUpdates.emit(operationalUpdate)
    }
    
    /**
     * Report maintenance events and schedule updates
     */
    suspend fun reportMaintenanceEvent(
        assetId: String,
        event: MaintenanceEvent,
        impact: MaintenanceImpact
    ) {
        val timestamp = LocalDateTime.now()
        
        // Update maintenance state
        assetStates[assetId]?.let { state ->
            val updatedState = state.copy(
                maintenanceStatus = event.status,
                lastMaintenanceEvent = event,
                lastMaintenanceUpdate = timestamp
            )
            assetStates[assetId] = updatedState
        }
        
        // Create maintenance notification
        val notification = MaintenanceNotification(
            assetId = assetId,
            timestamp = timestamp,
            eventType = event.type,
            status = event.status,
            impact = impact,
            estimatedDuration = event.estimatedDuration,
            cost = event.estimatedCost,
            priority = determinePriority(event, impact),
            description = generateMaintenanceDescription(event, impact)
        )
        
        _maintenanceNotifications.emit(notification)
        
        // Set up escalation if needed
        if (notification.priority == NotificationPriority.CRITICAL) {
            setupEscalation(assetId, notification)
        }
        
        recordNotification(assetId, notification)
    }
    
    /**
     * Report economic impact events
     */
    suspend fun reportEconomicImpact(
        assetIds: List<String>,
        impactType: EconomicImpactType,
        magnitude: Double,
        description: String,
        projectedDuration: Int? = null
    ) {
        val timestamp = LocalDateTime.now()
        val affectedAssets = assetIds.filter { assetStates.containsKey(it) }
        
        if (affectedAssets.isEmpty()) return
        
        val notification = EconomicImpactNotification(
            affectedAssets = affectedAssets,
            timestamp = timestamp,
            impactType = impactType,
            magnitude = magnitude,
            description = description,
            projectedDuration = projectedDuration,
            severity = calculateEconomicSeverity(magnitude, affectedAssets.size),
            recommendations = generateEconomicRecommendations(impactType, magnitude, affectedAssets)
        )
        
        _economicImpacts.emit(notification)
        
        // Update asset states with economic impact
        affectedAssets.forEach { assetId ->
            assetStates[assetId]?.let { state ->
                val updatedState = state.copy(
                    economicImpacts = state.economicImpacts + notification,
                    lastEconomicUpdate = timestamp
                )
                assetStates[assetId] = updatedState
            }
        }
        
        recordNotification("ECONOMIC_IMPACT", notification)
    }
    
    /**
     * Generate real-time asset status dashboard data
     */
    fun getAssetDashboardData(assetIds: List<String>): Flow<AssetDashboardData> = flow {
        while (true) {
            val dashboardData = AssetDashboardData(
                timestamp = LocalDateTime.now(),
                assets = assetIds.mapNotNull { assetId ->
                    assetStates[assetId]?.let { state ->
                        AssetDashboardItem(
                            assetId = assetId,
                            currentStatus = state.status,
                            utilizationRate = state.performanceMetrics?.utilizationRate ?: 0.0,
                            efficiency = state.performanceMetrics?.efficiency ?: 0.0,
                            location = state.location,
                            activeAlerts = getActiveAlerts(assetId),
                            lastUpdate = state.lastUpdate,
                            trend = calculateTrend(assetId, state)
                        )
                    }
                },
                aggregateMetrics = calculateAggregateMetrics(assetIds),
                systemHealth = calculateSystemHealth(assetIds),
                activeAlertsCount = getTotalActiveAlerts(assetIds),
                criticalIssues = getCriticalIssues(assetIds)
            )
            
            emit(dashboardData)
            delay(5000) // Update every 5 seconds
        }
    }
    
    /**
     * Get filtered notifications based on criteria
     */
    fun getFilteredNotifications(
        filter: NotificationFilter
    ): Flow<List<NotificationRecord>> = flow {
        while (true) {
            val filteredNotifications = notificationHistory.values
                .flatten()
                .filter { record ->
                    matchesFilter(record, filter)
                }
                .sortedByDescending { it.timestamp }
                .take(filter.limit ?: 100)
            
            emit(filteredNotifications)
            delay(2000) // Update every 2 seconds
        }
    }
    
    /**
     * Get real-time asset location and movement tracking
     */
    fun getAssetLocationUpdates(assetId: String): Flow<AssetLocationUpdate> = flow {
        while (true) {
            assetStates[assetId]?.let { state ->
                val update = AssetLocationUpdate(
                    assetId = assetId,
                    timestamp = LocalDateTime.now(),
                    location = state.location,
                    speed = state.speed,
                    heading = state.heading,
                    destination = state.destination,
                    estimatedArrival = state.estimatedArrival,
                    routeProgress = state.routeProgress
                )
                emit(update)
            }
            delay(10000) // Update every 10 seconds for location
        }
    }
    
    /**
     * Acknowledge and resolve alerts
     */
    suspend fun acknowledgeAlert(
        assetId: String,
        alertId: String,
        acknowledgerId: String,
        resolution: AlertResolution? = null
    ) {
        activeAlerts[assetId]?.remove(alertId)
        
        val acknowledgment = AlertAcknowledgment(
            assetId = assetId,
            alertId = alertId,
            acknowledgerId = acknowledgerId,
            timestamp = LocalDateTime.now(),
            resolution = resolution
        )
        
        // Cancel escalation if exists
        escalationTimers.remove("${assetId}_${alertId}")
        
        // Emit acknowledgment notification
        val notification = createAcknowledgmentNotification(acknowledgment)
        recordNotification(assetId, notification)
    }
    
    /**
     * Set up custom alert rules
     */
    fun setupCustomAlerts(
        assetId: String,
        rules: List<CustomAlertRule>
    ) {
        val thresholds = alertThresholds[assetId] ?: AssetAlertThresholds.default()
        val updatedThresholds = thresholds.copy(customRules = rules)
        alertThresholds[assetId] = updatedThresholds
    }
    
    // Private helper methods
    private fun startRealTimeProcessing() {
        // Start batch processing for medium/low priority updates
        coroutineScope.launch {
            while (true) {
                delay(5000) // Process batches every 5 seconds
                processBatchedUpdates()
            }
        }
        
        // Start periodic health checks
        coroutineScope.launch {
            while (true) {
                delay(60000) // Health check every minute
                performPeriodicHealthChecks()
            }
        }
        
        // Start escalation monitoring
        coroutineScope.launch {
            while (true) {
                delay(30000) // Check escalations every 30 seconds
                processEscalations()
            }
        }
    }
    
    private fun updateAssetState(
        assetId: String,
        updateData: AssetUpdateData,
        timestamp: LocalDateTime
    ): AssetRealTimeState {
        val currentState = assetStates[assetId] ?: AssetRealTimeState.initial(assetId)
        
        return currentState.copy(
            status = updateData.status ?: currentState.status,
            location = updateData.location ?: currentState.location,
            speed = updateData.speed ?: currentState.speed,
            heading = updateData.heading ?: currentState.heading,
            destination = updateData.destination ?: currentState.destination,
            estimatedArrival = updateData.estimatedArrival ?: currentState.estimatedArrival,
            routeProgress = updateData.routeProgress ?: currentState.routeProgress,
            lastUpdate = timestamp
        )
    }
    
    private fun determineUpdateType(
        updateData: AssetUpdateData,
        previousState: AssetRealTimeState?
    ): UpdateType {
        return when {
            updateData.status != null && updateData.status != previousState?.status -> UpdateType.STATUS_CHANGE
            updateData.location != null -> UpdateType.LOCATION_UPDATE
            updateData.speed != null -> UpdateType.MOVEMENT_UPDATE
            updateData.destination != null -> UpdateType.ROUTE_CHANGE
            else -> UpdateType.GENERAL_UPDATE
        }
    }
    
    private fun calculateUpdatePriority(
        updateData: AssetUpdateData,
        previousState: AssetRealTimeState?
    ): UpdatePriority {
        return when {
            updateData.status == AssetStatus.EMERGENCY -> UpdatePriority.CRITICAL
            updateData.status == AssetStatus.MAINTENANCE_REQUIRED -> UpdatePriority.HIGH
            updateData.status != previousState?.status -> UpdatePriority.MEDIUM
            updateData.location != null -> UpdatePriority.LOW
            else -> UpdatePriority.LOW
        }
    }
    
    private fun evaluateThresholds(
        assetId: String,
        state: AssetRealTimeState,
        thresholds: AssetAlertThresholds
    ) {
        // Check utilization thresholds
        state.performanceMetrics?.let { metrics ->
            if (metrics.utilizationRate < thresholds.minUtilization) {
                triggerAlert(assetId, AlertType.LOW_UTILIZATION, metrics.utilizationRate, thresholds.minUtilization)
            }
            
            if (metrics.utilizationRate > thresholds.maxUtilization) {
                triggerAlert(assetId, AlertType.HIGH_UTILIZATION, metrics.utilizationRate, thresholds.maxUtilization)
            }
            
            if (metrics.efficiency < thresholds.minEfficiency) {
                triggerAlert(assetId, AlertType.LOW_EFFICIENCY, metrics.efficiency, thresholds.minEfficiency)
            }
        }
        
        // Check custom rules
        thresholds.customRules.forEach { rule ->
            if (evaluateCustomRule(rule, state)) {
                triggerCustomAlert(assetId, rule)
            }
        }
    }
    
    private suspend fun triggerAlert(
        assetId: String,
        alertType: AlertType,
        currentValue: Double,
        thresholdValue: Double
    ) {
        val alertId = "${alertType.name}_${assetId}_${System.currentTimeMillis()}"
        
        val alert = PerformanceAlert(
            id = alertId,
            assetId = assetId,
            alertType = alertType,
            severity = calculateAlertSeverity(alertType, currentValue, thresholdValue),
            message = generateAlertMessage(alertType, currentValue, thresholdValue),
            timestamp = LocalDateTime.now(),
            value = currentValue,
            threshold = thresholdValue
        )
        
        // Add to active alerts
        activeAlerts.getOrPut(assetId) { mutableSetOf() }.add(alertId)
        
        _performanceAlerts.emit(alert)
        recordNotification(assetId, alert)
    }
    
    private suspend fun batchUpdate(update: AssetUpdate, delay: Long = 5000) {
        updateBatches.getOrPut(update.assetId) { mutableListOf() }.add(update)
    }
    
    private suspend fun processBatchedUpdates() {
        updateBatches.forEach { (assetId, updates) ->
            if (updates.isNotEmpty()) {
                val batchUpdate = AssetUpdate(
                    assetId = assetId,
                    timestamp = LocalDateTime.now(),
                    updateType = UpdateType.BATCH_UPDATE,
                    data = AssetUpdateData.batch(updates.map { it.data }),
                    source = UpdateSource.BATCH_PROCESSOR,
                    priority = updates.maxOf { it.priority }
                )
                
                _assetUpdates.emit(batchUpdate)
                updates.clear()
            }
        }
    }
    
    private suspend fun processImmediateNotifications(update: AssetUpdate) {
        // Process high priority notifications immediately
        notificationSubscriptions.values.forEach { subscription ->
            if (update.assetId in subscription.assetIds && 
                subscription.notificationTypes.contains(update.updateType.toNotificationType())) {
                
                sendNotificationToSubscriber(subscription, update)
            }
        }
    }
    
    private suspend fun performPeriodicHealthChecks() {
        val now = LocalDateTime.now()
        
        assetStates.forEach { (assetId, state) ->
            // Check for stale data
            val timeSinceLastUpdate = ChronoUnit.MINUTES.between(state.lastUpdate, now)
            
            if (timeSinceLastUpdate > 30) { // No update for 30 minutes
                val alert = PerformanceAlert(
                    id = "STALE_DATA_${assetId}_${System.currentTimeMillis()}",
                    assetId = assetId,
                    alertType = AlertType.COMMUNICATION_LOSS,
                    severity = AlertSeverity.HIGH,
                    message = "No data received for $timeSinceLastUpdate minutes",
                    timestamp = now,
                    value = timeSinceLastUpdate.toDouble(),
                    threshold = 30.0
                )
                
                _performanceAlerts.emit(alert)
            }
        }
    }
    
    private suspend fun processEscalations() {
        val now = LocalDateTime.now()
        
        escalationTimers.values.forEach { timer ->
            if (now.isAfter(timer.escalationTime)) {
                escalateAlert(timer)
            }
        }
    }
    
    private fun checkPerformanceAlerts(
        assetId: String,
        metrics: PerformanceMetrics,
        analysisResults: PerformanceAnalysisResults?
    ) {
        alertThresholds[assetId]?.let { thresholds ->
            // Check for performance degradation
            if (analysisResults?.trend == PerformanceTrend.DECLINING && 
                analysisResults.severity > 0.5) {
                
                coroutineScope.launch {
                    val alert = PerformanceAlert(
                        id = "PERF_DECLINE_${assetId}_${System.currentTimeMillis()}",
                        assetId = assetId,
                        alertType = AlertType.PERFORMANCE_DEGRADATION,
                        severity = AlertSeverity.MEDIUM,
                        message = "Performance declining: ${analysisResults.description}",
                        timestamp = LocalDateTime.now(),
                        value = analysisResults.severity,
                        threshold = 0.5
                    )
                    
                    _performanceAlerts.emit(alert)
                }
            }
        }
    }
    
    private fun assessPerformanceImpact(
        metrics: PerformanceMetrics,
        analysisResults: PerformanceAnalysisResults?
    ): ImpactLevel {
        return when {
            metrics.efficiency < 0.5 -> ImpactLevel.HIGH
            metrics.utilizationRate < 0.3 -> ImpactLevel.HIGH
            analysisResults?.severity ?: 0.0 > 0.7 -> ImpactLevel.MEDIUM
            metrics.efficiency < 0.7 -> ImpactLevel.MEDIUM
            else -> ImpactLevel.LOW
        }
    }
    
    private fun determinePriority(event: MaintenanceEvent, impact: MaintenanceImpact): NotificationPriority {
        return when {
            event.type == MaintenanceEventType.EMERGENCY -> NotificationPriority.CRITICAL
            impact.operationalImpact > 0.8 -> NotificationPriority.HIGH
            impact.operationalImpact > 0.5 -> NotificationPriority.MEDIUM
            else -> NotificationPriority.LOW
        }
    }
    
    private fun generateMaintenanceDescription(event: MaintenanceEvent, impact: MaintenanceImpact): String {
        return buildString {
            append(event.type.name.lowercase().replace('_', ' ').capitalize())
            if (event.description.isNotEmpty()) {
                append(": ${event.description}")
            }
            if (impact.operationalImpact > 0) {
                append(" (${(impact.operationalImpact * 100).toInt()}% operational impact)")
            }
        }
    }
    
    private fun setupEscalation(assetId: String, notification: MaintenanceNotification) {
        val escalationTime = LocalDateTime.now().plusMinutes(30) // Escalate after 30 minutes
        val timerId = "${assetId}_${notification.timestamp}"
        
        escalationTimers[timerId] = EscalationTimer(
            id = timerId,
            assetId = assetId,
            notificationId = notification.toString(),
            escalationTime = escalationTime,
            level = 1
        )
    }
    
    private suspend fun escalateAlert(timer: EscalationTimer) {
        // Find higher level subscribers or send to management
        val escalationNotification = createEscalationNotification(timer)
        
        // Send to all critical subscribers
        notificationSubscriptions.values
            .filter { it.priority == SubscriptionPriority.CRITICAL }
            .forEach { subscription ->
                sendNotificationToSubscriber(subscription, escalationNotification)
            }
        
        // Update escalation level
        timer.level++
        if (timer.level < 3) { // Max 3 escalation levels
            timer.escalationTime = timer.escalationTime.plusMinutes(30)
        } else {
            escalationTimers.remove(timer.id)
        }
    }
    
    private fun calculateEconomicSeverity(magnitude: Double, affectedAssetsCount: Int): EconomicSeverity {
        val impact = abs(magnitude) * affectedAssetsCount
        return when {
            impact > 100000 -> EconomicSeverity.SEVERE
            impact > 50000 -> EconomicSeverity.HIGH
            impact > 10000 -> EconomicSeverity.MEDIUM
            else -> EconomicSeverity.LOW
        }
    }
    
    private fun generateEconomicRecommendations(
        impactType: EconomicImpactType,
        magnitude: Double,
        affectedAssets: List<String>
    ): List<String> {
        val recommendations = mutableListOf<String>()
        
        when (impactType) {
            EconomicImpactType.FUEL_PRICE_CHANGE -> {
                if (magnitude > 0) {
                    recommendations.add("Consider fuel hedging strategies")
                    recommendations.add("Optimize routes for fuel efficiency")
                }
            }
            EconomicImpactType.DEMAND_FLUCTUATION -> {
                if (magnitude < 0) {
                    recommendations.add("Reduce capacity utilization")
                    recommendations.add("Consider asset reallocation")
                } else {
                    recommendations.add("Increase operational capacity")
                    recommendations.add("Review pricing strategies")
                }
            }
            EconomicImpactType.REGULATORY_CHANGE -> {
                recommendations.add("Review compliance requirements")
                recommendations.add("Update operational procedures")
            }
            EconomicImpactType.MARKET_DISRUPTION -> {
                recommendations.add("Activate contingency plans")
                recommendations.add("Monitor market conditions closely")
            }
        }
        
        return recommendations
    }
    
    private fun getActiveAlerts(assetId: String): List<ActiveAlert> {
        return activeAlerts[assetId]?.map { alertId ->
            ActiveAlert(
                id = alertId,
                type = extractAlertType(alertId),
                severity = extractAlertSeverity(alertId),
                duration = calculateAlertDuration(alertId)
            )
        } ?: emptyList()
    }
    
    private fun calculateTrend(assetId: String, state: AssetRealTimeState): AssetTrend {
        // Simplified trend calculation
        return when {
            state.performanceMetrics?.efficiency ?: 0.0 > 0.8 -> AssetTrend.IMPROVING
            state.performanceMetrics?.efficiency ?: 0.0 < 0.6 -> AssetTrend.DECLINING
            else -> AssetTrend.STABLE
        }
    }
    
    private fun calculateAggregateMetrics(assetIds: List<String>): AggregateMetrics {
        val relevantStates = assetIds.mapNotNull { assetStates[it] }
        
        return AggregateMetrics(
            averageUtilization = relevantStates.mapNotNull { 
                it.performanceMetrics?.utilizationRate 
            }.average(),
            averageEfficiency = relevantStates.mapNotNull { 
                it.performanceMetrics?.efficiency 
            }.average(),
            operationalAssets = relevantStates.count { it.status == AssetStatus.OPERATIONAL },
            totalAssets = relevantStates.size
        )
    }
    
    private fun calculateSystemHealth(assetIds: List<String>): SystemHealth {
        val totalAssets = assetIds.size
        val operationalAssets = assetIds.count { 
            assetStates[it]?.status == AssetStatus.OPERATIONAL 
        }
        val alertCount = getTotalActiveAlerts(assetIds)
        
        val healthScore = when {
            operationalAssets.toDouble() / totalAssets > 0.95 && alertCount < 5 -> SystemHealthLevel.EXCELLENT
            operationalAssets.toDouble() / totalAssets > 0.9 && alertCount < 10 -> SystemHealthLevel.GOOD
            operationalAssets.toDouble() / totalAssets > 0.8 -> SystemHealthLevel.FAIR
            else -> SystemHealthLevel.POOR
        }
        
        return SystemHealth(
            level = healthScore,
            score = operationalAssets.toDouble() / totalAssets,
            operationalPercentage = (operationalAssets.toDouble() / totalAssets * 100).toInt(),
            criticalIssues = getCriticalIssues(assetIds).size
        )
    }
    
    private fun getTotalActiveAlerts(assetIds: List<String>): Int {
        return assetIds.sumOf { assetId ->
            activeAlerts[assetId]?.size ?: 0
        }
    }
    
    private fun getCriticalIssues(assetIds: List<String>): List<CriticalIssue> {
        return assetIds.flatMap { assetId ->
            assetStates[assetId]?.let { state ->
                val issues = mutableListOf<CriticalIssue>()
                
                if (state.status == AssetStatus.EMERGENCY) {
                    issues.add(CriticalIssue(
                        assetId = assetId,
                        type = "Emergency Status",
                        severity = IssueSeverity.CRITICAL,
                        description = "Asset in emergency state"
                    ))
                }
                
                if (state.status == AssetStatus.MAINTENANCE_REQUIRED) {
                    issues.add(CriticalIssue(
                        assetId = assetId,
                        type = "Maintenance Required",
                        severity = IssueSeverity.HIGH,
                        description = "Asset requires immediate maintenance"
                    ))
                }
                
                issues
            } ?: emptyList()
        }
    }
    
    private fun matchesFilter(record: NotificationRecord, filter: NotificationFilter): Boolean {
        return (filter.assetIds.isEmpty() || record.assetId in filter.assetIds) &&
               (filter.types.isEmpty() || record.type in filter.types) &&
               (filter.severities.isEmpty() || record.severity in filter.severities) &&
               (filter.startTime == null || record.timestamp.isAfter(filter.startTime)) &&
               (filter.endTime == null || record.timestamp.isBefore(filter.endTime))
    }
    
    private fun evaluateCustomRule(rule: CustomAlertRule, state: AssetRealTimeState): Boolean {
        // Simplified custom rule evaluation
        return when (rule.condition.metric) {
            "utilization" -> {
                val value = state.performanceMetrics?.utilizationRate ?: 0.0
                rule.condition.evaluate(value)
            }
            "efficiency" -> {
                val value = state.performanceMetrics?.efficiency ?: 0.0
                rule.condition.evaluate(value)
            }
            "status" -> {
                state.status.name == rule.condition.value.toString()
            }
            else -> false
        }
    }
    
    private suspend fun triggerCustomAlert(assetId: String, rule: CustomAlertRule) {
        val alertId = "${rule.id}_${assetId}_${System.currentTimeMillis()}"
        
        val alert = PerformanceAlert(
            id = alertId,
            assetId = assetId,
            alertType = AlertType.CUSTOM,
            severity = rule.severity,
            message = rule.message,
            timestamp = LocalDateTime.now(),
            value = 0.0, // Would extract actual value based on rule
            threshold = 0.0 // Would extract threshold based on rule
        )
        
        activeAlerts.getOrPut(assetId) { mutableSetOf() }.add(alertId)
        _performanceAlerts.emit(alert)
    }
    
    private fun calculateAlertSeverity(
        alertType: AlertType,
        currentValue: Double,
        thresholdValue: Double
    ): AlertSeverity {
        val deviation = abs(currentValue - thresholdValue) / thresholdValue
        
        return when {
            deviation > 0.5 -> AlertSeverity.CRITICAL
            deviation > 0.3 -> AlertSeverity.HIGH
            deviation > 0.1 -> AlertSeverity.MEDIUM
            else -> AlertSeverity.LOW
        }
    }
    
    private fun generateAlertMessage(
        alertType: AlertType,
        currentValue: Double,
        thresholdValue: Double
    ): String {
        val percentage = (currentValue * 100).toInt()
        val thresholdPercentage = (thresholdValue * 100).toInt()
        
        return when (alertType) {
            AlertType.LOW_UTILIZATION -> "Utilization $percentage% below threshold $thresholdPercentage%"
            AlertType.HIGH_UTILIZATION -> "Utilization $percentage% above threshold $thresholdPercentage%"
            AlertType.LOW_EFFICIENCY -> "Efficiency $percentage% below threshold $thresholdPercentage%"
            else -> "Alert: ${alertType.name.lowercase().replace('_', ' ')}"
        }
    }
    
    private fun recordNotification(assetId: String, notification: Any) {
        val record = NotificationRecord(
            id = System.currentTimeMillis().toString(),
            assetId = assetId,
            timestamp = LocalDateTime.now(),
            type = notification::class.simpleName ?: "Unknown",
            severity = extractSeverity(notification),
            message = extractMessage(notification),
            acknowledged = false
        )
        
        notificationHistory.getOrPut(assetId) { mutableListOf() }.add(record)
        
        // Keep only recent notifications (last 1000 per asset)
        notificationHistory[assetId]?.let { history ->
            if (history.size > 1000) {
                history.removeAt(0)
            }
        }
    }
    
    // Helper methods for extracting information from notifications
    private fun extractSeverity(notification: Any): String {
        return when (notification) {
            is PerformanceAlert -> notification.severity.name
            is MaintenanceNotification -> notification.priority.name
            else -> "UNKNOWN"
        }
    }
    
    private fun extractMessage(notification: Any): String {
        return when (notification) {
            is PerformanceAlert -> notification.message
            is MaintenanceNotification -> notification.description
            else -> notification.toString()
        }
    }
    
    private fun extractAlertType(alertId: String): String {
        return alertId.split("_").firstOrNull() ?: "UNKNOWN"
    }
    
    private fun extractAlertSeverity(alertId: String): AlertSeverity {
        // Simplified - would look up actual alert data
        return AlertSeverity.MEDIUM
    }
    
    private fun calculateAlertDuration(alertId: String): Long {
        // Simplified - would calculate based on alert creation time
        return 30 // minutes
    }
    
    private suspend fun sendNotificationToSubscriber(
        subscription: NotificationSubscription,
        update: Any
    ) {
        // Implementation would send notification via configured channels
        // (email, SMS, push notification, webhook, etc.)
    }
    
    private fun createAcknowledgmentNotification(acknowledgment: AlertAcknowledgment): Any {
        // Create appropriate notification for acknowledgment
        return acknowledgment
    }
    
    private fun createEscalationNotification(timer: EscalationTimer): Any {
        // Create escalation notification
        return timer
    }
    
    private fun UpdateType.toNotificationType(): NotificationType {
        return when (this) {
            UpdateType.STATUS_CHANGE -> NotificationType.STATUS_CHANGE
            UpdateType.LOCATION_UPDATE -> NotificationType.LOCATION_UPDATE
            UpdateType.MOVEMENT_UPDATE -> NotificationType.MOVEMENT_UPDATE
            UpdateType.ROUTE_CHANGE -> NotificationType.ROUTE_CHANGE
            else -> NotificationType.GENERAL_UPDATE
        }
    }
}

// Data classes for real-time notifications
data class AssetUpdate(
    val assetId: String,
    val timestamp: LocalDateTime,
    val updateType: UpdateType,
    val data: AssetUpdateData,
    val source: UpdateSource,
    val priority: UpdatePriority
)

data class AssetUpdateData(
    val status: AssetStatus? = null,
    val location: AssetLocation? = null,
    val speed: Double? = null,
    val heading: Double? = null,
    val destination: String? = null,
    val estimatedArrival: LocalDateTime? = null,
    val routeProgress: Double? = null,
    val performanceUpdate: PerformanceMetrics? = null
) {
    companion object {
        fun batch(dataList: List<AssetUpdateData>): AssetUpdateData {
            return AssetUpdateData(
                status = dataList.mapNotNull { it.status }.lastOrNull(),
                location = dataList.mapNotNull { it.location }.lastOrNull(),
                speed = dataList.mapNotNull { it.speed }.lastOrNull(),
                heading = dataList.mapNotNull { it.heading }.lastOrNull()
                // ... merge other fields
            )
        }
    }
}

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

data class MaintenanceNotification(
    val assetId: String,
    val timestamp: LocalDateTime,
    val eventType: MaintenanceEventType,
    val status: MaintenanceStatus,
    val impact: MaintenanceImpact,
    val estimatedDuration: Int?,
    val cost: Double?,
    val priority: NotificationPriority,
    val description: String
)

data class OperationalUpdate(
    val assetId: String,
    val timestamp: LocalDateTime,
    val operationType: OperationType,
    val metrics: PerformanceMetrics?,
    val analysisResults: PerformanceAnalysisResults?,
    val impactLevel: ImpactLevel
)

data class EconomicImpactNotification(
    val affectedAssets: List<String>,
    val timestamp: LocalDateTime,
    val impactType: EconomicImpactType,
    val magnitude: Double,
    val description: String,
    val projectedDuration: Int?,
    val severity: EconomicSeverity,
    val recommendations: List<String>
)

data class AssetRealTimeState(
    val assetId: String,
    val status: AssetStatus,
    val location: AssetLocation,
    val speed: Double,
    val heading: Double,
    val destination: String?,
    val estimatedArrival: LocalDateTime?,
    val routeProgress: Double,
    val performanceMetrics: PerformanceMetrics?,
    val maintenanceStatus: MaintenanceStatus,
    val lastMaintenanceEvent: MaintenanceEvent?,
    val lastAnalysis: PerformanceAnalysisResults?,
    val economicImpacts: List<EconomicImpactNotification>,
    val lastUpdate: LocalDateTime,
    val lastPerformanceUpdate: LocalDateTime,
    val lastMaintenanceUpdate: LocalDateTime,
    val lastEconomicUpdate: LocalDateTime
) {
    companion object {
        fun initial(assetId: String): AssetRealTimeState {
            return AssetRealTimeState(
                assetId = assetId,
                status = AssetStatus.OPERATIONAL,
                location = AssetLocation(0.0, 0.0, null, null, null, "UNKNOWN", "UNKNOWN"),
                speed = 0.0,
                heading = 0.0,
                destination = null,
                estimatedArrival = null,
                routeProgress = 0.0,
                performanceMetrics = null,
                maintenanceStatus = MaintenanceStatus.OK,
                lastMaintenanceEvent = null,
                lastAnalysis = null,
                economicImpacts = emptyList(),
                lastUpdate = LocalDateTime.now(),
                lastPerformanceUpdate = LocalDateTime.now(),
                lastMaintenanceUpdate = LocalDateTime.now(),
                lastEconomicUpdate = LocalDateTime.now()
            )
        }
    }
}

data class NotificationSubscription(
    val subscriberId: String,
    val assetIds: List<String>,
    val assetTypes: List<AssetType>,
    val notificationTypes: List<NotificationType>,
    val priority: SubscriptionPriority,
    val channels: List<NotificationChannel>,
    val filters: NotificationFilters
)

data class AssetAlertThresholds(
    val minUtilization: Double,
    val maxUtilization: Double,
    val minEfficiency: Double,
    val maxMaintenanceCost: Double,
    val maxDowntime: Int, // hours
    val customRules: List<CustomAlertRule>
) {
    companion object {
        fun default(): AssetAlertThresholds {
            return AssetAlertThresholds(
                minUtilization = 0.3,
                maxUtilization = 0.95,
                minEfficiency = 0.6,
                maxMaintenanceCost = 10000.0,
                maxDowntime = 24,
                customRules = emptyList()
            )
        }
    }
}

data class CustomAlertRule(
    val id: String,
    val name: String,
    val condition: AlertCondition,
    val severity: AlertSeverity,
    val message: String,
    val enabled: Boolean = true
)

data class AlertCondition(
    val metric: String,
    val operator: ComparisonOperator,
    val value: Any,
    val duration: Int? = null // minutes condition must be true
) {
    fun evaluate(actualValue: Double): Boolean {
        val targetValue = when (value) {
            is Number -> value.toDouble()
            else -> return false
        }
        
        return when (operator) {
            ComparisonOperator.GREATER_THAN -> actualValue > targetValue
            ComparisonOperator.LESS_THAN -> actualValue < targetValue
            ComparisonOperator.EQUALS -> actualValue == targetValue
            ComparisonOperator.GREATER_THAN_OR_EQUAL -> actualValue >= targetValue
            ComparisonOperator.LESS_THAN_OR_EQUAL -> actualValue <= targetValue
            ComparisonOperator.NOT_EQUALS -> actualValue != targetValue
        }
    }
}

// Performance and analytics data classes
data class PerformanceMetrics(
    val utilizationRate: Double,
    val efficiency: Double,
    val fuelConsumption: Double,
    val revenue: Double,
    val operatingCosts: Double,
    val maintenanceRatio: Double
)

data class PerformanceAnalysisResults(
    val trend: PerformanceTrend,
    val severity: Double,
    val description: String,
    val recommendations: List<String>
)

data class MaintenanceEvent(
    val type: MaintenanceEventType,
    val status: MaintenanceStatus,
    val description: String,
    val estimatedDuration: Int?,
    val estimatedCost: Double?
)

data class MaintenanceImpact(
    val operationalImpact: Double, // 0.0 to 1.0
    val financialImpact: Double,
    val scheduleImpact: Int, // hours of delay
    val safetyImpact: SafetyLevel
)

// Dashboard and UI data classes
data class AssetDashboardData(
    val timestamp: LocalDateTime,
    val assets: List<AssetDashboardItem>,
    val aggregateMetrics: AggregateMetrics,
    val systemHealth: SystemHealth,
    val activeAlertsCount: Int,
    val criticalIssues: List<CriticalIssue>
)

data class AssetDashboardItem(
    val assetId: String,
    val currentStatus: AssetStatus,
    val utilizationRate: Double,
    val efficiency: Double,
    val location: AssetLocation,
    val activeAlerts: List<ActiveAlert>,
    val lastUpdate: LocalDateTime,
    val trend: AssetTrend
)

data class AggregateMetrics(
    val averageUtilization: Double,
    val averageEfficiency: Double,
    val operationalAssets: Int,
    val totalAssets: Int
)

data class SystemHealth(
    val level: SystemHealthLevel,
    val score: Double,
    val operationalPercentage: Int,
    val criticalIssues: Int
)

data class AssetLocationUpdate(
    val assetId: String,
    val timestamp: LocalDateTime,
    val location: AssetLocation,
    val speed: Double,
    val heading: Double,
    val destination: String?,
    val estimatedArrival: LocalDateTime?,
    val routeProgress: Double
)

data class NotificationFilter(
    val assetIds: List<String> = emptyList(),
    val types: List<String> = emptyList(),
    val severities: List<String> = emptyList(),
    val startTime: LocalDateTime? = null,
    val endTime: LocalDateTime? = null,
    val limit: Int? = null
)

data class NotificationRecord(
    val id: String,
    val assetId: String,
    val timestamp: LocalDateTime,
    val type: String,
    val severity: String,
    val message: String,
    val acknowledged: Boolean
)

data class ActiveAlert(
    val id: String,
    val type: String,
    val severity: AlertSeverity,
    val duration: Long // minutes
)

data class CriticalIssue(
    val assetId: String,
    val type: String,
    val severity: IssueSeverity,
    val description: String
)

data class AlertAcknowledgment(
    val assetId: String,
    val alertId: String,
    val acknowledgerId: String,
    val timestamp: LocalDateTime,
    val resolution: AlertResolution?
)

data class AlertResolution(
    val action: String,
    val description: String,
    val resolved: Boolean
)

data class EscalationTimer(
    val id: String,
    val assetId: String,
    val notificationId: String,
    val escalationTime: LocalDateTime,
    var level: Int
)

data class NotificationFilters(
    val severityLevels: List<AlertSeverity>,
    val timeWindows: List<TimeWindow>,
    val assetCategories: List<String>
)

data class TimeWindow(
    val start: LocalDateTime,
    val end: LocalDateTime
)

// Enums
enum class UpdateType {
    STATUS_CHANGE, LOCATION_UPDATE, MOVEMENT_UPDATE, ROUTE_CHANGE, 
    PERFORMANCE_UPDATE, MAINTENANCE_UPDATE, GENERAL_UPDATE, BATCH_UPDATE
}

enum class UpdateSource {
    SENSOR, GPS, MANUAL, SYSTEM, BATCH_PROCESSOR, EXTERNAL_API
}

enum class UpdatePriority {
    CRITICAL, HIGH, MEDIUM, LOW
}

enum class AssetStatus {
    OPERATIONAL, MAINTENANCE_REQUIRED, IN_MAINTENANCE, 
    EMERGENCY, OFFLINE, DECOMMISSIONED
}

enum class AlertType {
    LOW_UTILIZATION, HIGH_UTILIZATION, LOW_EFFICIENCY,
    PERFORMANCE_DEGRADATION, COMMUNICATION_LOSS, CUSTOM
}

enum class AlertSeverity {
    LOW, MEDIUM, HIGH, CRITICAL, RESOLVED
}

enum class NotificationType {
    STATUS_CHANGE, LOCATION_UPDATE, MOVEMENT_UPDATE, ROUTE_CHANGE,
    PERFORMANCE_ALERT, MAINTENANCE_ALERT, ECONOMIC_IMPACT, GENERAL_UPDATE
}

enum class NotificationPriority {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class SubscriptionPriority {
    STANDARD, HIGH, CRITICAL
}

enum class NotificationChannel {
    EMAIL, SMS, PUSH_NOTIFICATION, WEBHOOK, IN_APP
}

enum class OperationType {
    PERFORMANCE_UPDATE, LOCATION_CHANGE, STATUS_CHANGE, MAINTENANCE_EVENT
}

enum class ImpactLevel {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class EconomicImpactType {
    FUEL_PRICE_CHANGE, DEMAND_FLUCTUATION, REGULATORY_CHANGE, MARKET_DISRUPTION
}

enum class EconomicSeverity {
    LOW, MEDIUM, HIGH, SEVERE
}

enum class MaintenanceEventType {
    SCHEDULED, UNSCHEDULED, EMERGENCY, INSPECTION, REPAIR
}

enum class MaintenanceStatus {
    OK, WARNING, MAINTENANCE_DUE, IN_MAINTENANCE, NEEDS_REPAIR
}

enum class PerformanceTrend {
    IMPROVING, STABLE, DECLINING, VOLATILE
}

enum class SafetyLevel {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class AssetTrend {
    IMPROVING, STABLE, DECLINING
}

enum class SystemHealthLevel {
    EXCELLENT, GOOD, FAIR, POOR
}

enum class IssueSeverity {
    LOW, MEDIUM, HIGH, CRITICAL
}

enum class ComparisonOperator {
    GREATER_THAN, LESS_THAN, EQUALS, GREATER_THAN_OR_EQUAL, LESS_THAN_OR_EQUAL, NOT_EQUALS
}