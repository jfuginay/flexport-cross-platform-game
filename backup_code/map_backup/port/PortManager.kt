package com.flexport.map.port

import com.flexport.economics.models.Commodity
import com.flexport.economics.models.CommodityType
import com.flexport.map.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.time.LocalDateTime
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Manages port operations, capacity, and logistics
 */
class PortManager {
    
    private val _portStates = ConcurrentHashMap<String, PortState>()
    private val _portEvents = MutableSharedFlow<PortEvent>()
    private val _cargoInventory = ConcurrentHashMap<String, MutableMap<CommodityType, Double>>()
    private val _vesselSchedule = ConcurrentHashMap<String, MutableList<VesselScheduleEntry>>()
    private val _portOperations = ConcurrentHashMap<String, MutableList<PortOperation>>()
    
    /**
     * Observable flow of port events
     */
    val portEvents: SharedFlow<PortEvent> = _portEvents.asSharedFlow()
    
    /**
     * Initialize a port for management
     */
    suspend fun initializePort(port: Port): Result<PortState> = withContext(Dispatchers.Default) {
        try {
            val initialState = PortState(
                port = port,
                currentUtilization = PortUtilization(),
                weather = getCurrentWeather(port),
                operationalStatus = OperationalStatus.OPERATIONAL,
                lastUpdated = LocalDateTime.now()
            )
            
            _portStates[port.id] = initialState
            _cargoInventory[port.id] = port.specializations.associateWith { 0.0 }.toMutableMap()
            _vesselSchedule[port.id] = mutableListOf()
            _portOperations[port.id] = mutableListOf()
            
            _portEvents.emit(PortEvent.PortInitialized(initialState))
            
            Result.success(initialState)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Get current port state
     */
    fun getPortState(portId: String): PortState? {
        return _portStates[portId]
    }
    
    /**
     * Get all managed ports
     */
    fun getAllPortStates(): List<PortState> {
        return _portStates.values.toList()
    }
    
    /**
     * Request berth allocation for a vessel
     */
    suspend fun requestBerthAllocation(
        portId: String,
        vessel: Vessel,
        arrivalTime: LocalDateTime,
        departureTime: LocalDateTime,
        operations: List<PlannedOperation>
    ): Result<BerthAllocation> = withContext(Dispatchers.Default) {
        
        try {
            val portState = _portStates[portId] 
                ?: return@withContext Result.failure(PortNotFoundException(portId))
            
            val port = portState.port
            
            // Check if port can accommodate vessel
            val compatibilityCheck = checkVesselCompatibility(port, vessel)
            if (!compatibilityCheck.compatible) {
                return@withContext Result.failure(
                    IncompatibleVesselException(compatibilityCheck.issues)
                )
            }
            
            // Find available berth
            val availableBerth = findAvailableBerth(port, vessel, arrivalTime, departureTime)
                ?: return@withContext Result.failure(
                    NoAvailableBerthException("No berth available for requested time period")
                )
            
            val allocation = BerthAllocation(
                id = UUID.randomUUID().toString(),
                portId = portId,
                vessel = vessel,
                berthNumber = availableBerth,
                arrivalTime = arrivalTime,
                departureTime = departureTime,
                operations = operations,
                status = AllocationStatus.CONFIRMED,
                estimatedCost = calculateBerthingCost(port, vessel, arrivalTime, departureTime, operations)
            )
            
            // Add to vessel schedule
            val scheduleEntry = VesselScheduleEntry(
                allocation = allocation,
                actualArrival = null,
                actualDeparture = null,
                delays = mutableListOf()
            )
            
            _vesselSchedule[portId]?.add(scheduleEntry)
            
            // Update port utilization
            updatePortUtilization(portId)
            
            _portEvents.emit(PortEvent.BerthAllocated(allocation))
            
            Result.success(allocation)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Process vessel arrival
     */
    suspend fun processVesselArrival(
        portId: String,
        allocationId: String,
        actualArrivalTime: LocalDateTime
    ): Result<VesselArrivalResult> = withContext(Dispatchers.Default) {
        
        try {
            val scheduleEntry = findScheduleEntry(portId, allocationId)
                ?: return@withContext Result.failure(AllocationNotFoundException(allocationId))
            
            scheduleEntry.actualArrival = actualArrivalTime
            
            // Calculate delay if any
            val plannedArrival = scheduleEntry.allocation.arrivalTime
            if (actualArrivalTime.isAfter(plannedArrival)) {
                val delayMinutes = java.time.Duration.between(plannedArrival, actualArrivalTime).toMinutes()
                scheduleEntry.delays.add(
                    OperationDelay(
                        type = DelayType.ARRIVAL,
                        durationMinutes = delayMinutes,
                        reason = "Late arrival",
                        timestamp = actualArrivalTime
                    )
                )
            }
            
            // Start port operations
            val operations = scheduleEntry.allocation.operations.map { plannedOp ->
                PortOperation(
                    id = UUID.randomUUID().toString(),
                    allocationId = allocationId,
                    type = plannedOp.type,
                    commodity = plannedOp.commodity,
                    quantity = plannedOp.quantity,
                    status = OperationStatus.WAITING,
                    scheduledStart = actualArrivalTime,
                    estimatedDuration = calculateOperationDuration(portId, plannedOp),
                    actualStart = null,
                    actualEnd = null,
                    efficiency = 1.0
                )
            }
            
            _portOperations[portId]?.addAll(operations)
            
            val result = VesselArrivalResult(
                allocationId = allocationId,
                arrivalDelay = scheduleEntry.delays.firstOrNull { it.type == DelayType.ARRIVAL },
                queuePosition = calculateQueuePosition(portId, allocationId),
                estimatedWaitTime = calculateWaitTime(portId, allocationId),
                operations = operations
            )
            
            updatePortUtilization(portId)
            _portEvents.emit(PortEvent.VesselArrived(scheduleEntry.allocation.vessel, actualArrivalTime))
            
            Result.success(result)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Start a port operation (loading/unloading)
     */
    suspend fun startOperation(
        portId: String,
        operationId: String
    ): Result<PortOperation> = withContext(Dispatchers.Default) {
        
        try {
            val operation = findOperation(portId, operationId)
                ?: return@withContext Result.failure(OperationNotFoundException(operationId))
            
            val portState = _portStates[portId]
                ?: return@withContext Result.failure(PortNotFoundException(portId))
            
            // Check if operation can start
            val canStart = checkOperationPreconditions(portState, operation)
            if (!canStart.success) {
                return@withContext Result.failure(
                    OperationCannotStartException(canStart.issues)
                )
            }
            
            val updatedOperation = operation.copy(
                status = OperationStatus.IN_PROGRESS,
                actualStart = LocalDateTime.now()
            )
            
            updateOperation(portId, updatedOperation)
            
            _portEvents.emit(PortEvent.OperationStarted(updatedOperation))
            
            Result.success(updatedOperation)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Complete a port operation
     */
    suspend fun completeOperation(
        portId: String,
        operationId: String,
        actualQuantity: Double? = null
    ): Result<PortOperation> = withContext(Dispatchers.Default) {
        
        try {
            val operation = findOperation(portId, operationId)
                ?: return@withContext Result.failure(OperationNotFoundException(operationId))
            
            val finalQuantity = actualQuantity ?: operation.quantity
            val completionTime = LocalDateTime.now()
            
            val updatedOperation = operation.copy(
                status = OperationStatus.COMPLETED,
                actualEnd = completionTime,
                quantity = finalQuantity,
                efficiency = calculateOperationEfficiency(operation, completionTime)
            )
            
            updateOperation(portId, updatedOperation)
            
            // Update cargo inventory
            updateCargoInventory(portId, operation.type, operation.commodity, finalQuantity)
            
            // Update port utilization
            updatePortUtilization(portId)
            
            _portEvents.emit(PortEvent.OperationCompleted(updatedOperation))
            
            Result.success(updatedOperation)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Process vessel departure
     */
    suspend fun processVesselDeparture(
        portId: String,
        allocationId: String,
        actualDepartureTime: LocalDateTime
    ): Result<VesselDepartureResult> = withContext(Dispatchers.Default) {
        
        try {
            val scheduleEntry = findScheduleEntry(portId, allocationId)
                ?: return@withContext Result.failure(AllocationNotFoundException(allocationId))
            
            scheduleEntry.actualDeparture = actualDepartureTime
            
            // Calculate delay if any
            val plannedDeparture = scheduleEntry.allocation.departureTime
            if (actualDepartureTime.isAfter(plannedDeparture)) {
                val delayMinutes = java.time.Duration.between(plannedDeparture, actualDepartureTime).toMinutes()
                scheduleEntry.delays.add(
                    OperationDelay(
                        type = DelayType.DEPARTURE,
                        durationMinutes = delayMinutes,
                        reason = "Late departure",
                        timestamp = actualDepartureTime
                    )
                )
            }
            
            // Mark all operations as completed or cancelled
            val operations = _portOperations[portId]?.filter { it.allocationId == allocationId } ?: emptyList()
            operations.forEach { operation ->
                if (operation.status == OperationStatus.IN_PROGRESS || operation.status == OperationStatus.WAITING) {
                    updateOperation(portId, operation.copy(
                        status = if (operation.actualStart != null) OperationStatus.COMPLETED else OperationStatus.CANCELLED,
                        actualEnd = actualDepartureTime
                    ))
                }
            }
            
            val result = VesselDepartureResult(
                allocationId = allocationId,
                departureDelay = scheduleEntry.delays.firstOrNull { it.type == DelayType.DEPARTURE },
                totalPortTime = java.time.Duration.between(
                    scheduleEntry.actualArrival ?: scheduleEntry.allocation.arrivalTime,
                    actualDepartureTime
                ).toMinutes(),
                completedOperations = operations.filter { it.status == OperationStatus.COMPLETED },
                totalCost = calculateActualCost(scheduleEntry)
            )
            
            // Free up the berth
            updatePortUtilization(portId)
            
            _portEvents.emit(PortEvent.VesselDeparted(scheduleEntry.allocation.vessel, actualDepartureTime))
            
            Result.success(result)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Get port cargo inventory
     */
    fun getCargoInventory(portId: String): Map<CommodityType, Double> {
        return _cargoInventory[portId]?.toMap() ?: emptyMap()
    }
    
    /**
     * Get vessel schedule for a port
     */
    fun getVesselSchedule(portId: String, from: LocalDateTime, to: LocalDateTime): List<VesselScheduleEntry> {
        return _vesselSchedule[portId]?.filter { entry ->
            entry.allocation.arrivalTime.isBefore(to) && entry.allocation.departureTime.isAfter(from)
        } ?: emptyList()
    }
    
    /**
     * Get active operations at a port
     */
    fun getActiveOperations(portId: String): List<PortOperation> {
        return _portOperations[portId]?.filter { 
            it.status == OperationStatus.IN_PROGRESS || it.status == OperationStatus.WAITING 
        } ?: emptyList()
    }
    
    /**
     * Get port performance metrics
     */
    fun getPortPerformance(portId: String, period: TimePeriod): PortPerformanceMetrics {
        val operations = _portOperations[portId] ?: emptyList()
        val scheduleEntries = _vesselSchedule[portId] ?: emptyList()
        
        val periodStart = period.start
        val periodEnd = period.end
        
        val periodOperations = operations.filter { operation ->
            operation.actualStart?.let { start ->
                start.isAfter(periodStart) && start.isBefore(periodEnd)
            } ?: false
        }
        
        val periodArrivals = scheduleEntries.filter { entry ->
            entry.actualArrival?.let { arrival ->
                arrival.isAfter(periodStart) && arrival.isBefore(periodEnd)
            } ?: false
        }
        
        return PortPerformanceMetrics(
            portId = portId,
            period = period,
            totalVessels = periodArrivals.size,
            onTimeArrivals = periodArrivals.count { entry ->
                entry.actualArrival?.let { actual ->
                    !actual.isAfter(entry.allocation.arrivalTime.plusMinutes(30))
                } ?: false
            },
            averageTurnaroundTime = calculateAverageTurnaroundTime(periodArrivals),
            totalCargoHandled = periodOperations.sumOf { it.quantity },
            operationalEfficiency = calculateOperationalEfficiency(periodOperations),
            revenueGenerated = calculatePortRevenue(periodArrivals),
            utilizationRate = calculateUtilizationRate(portId, period)
        )
    }
    
    // Helper functions
    
    private fun checkVesselCompatibility(port: Port, vessel: Vessel): CompatibilityResult {
        val issues = mutableListOf<String>()
        
        if (vessel.draft > port.infrastructure.waterDepth) {
            issues.add("Vessel draft (${vessel.draft}m) exceeds port water depth (${port.infrastructure.waterDepth}m)")
        }
        
        if (vessel.length > port.infrastructure.berthLength) {
            issues.add("Vessel length (${vessel.length}m) exceeds maximum berth length (${port.infrastructure.berthLength}m)")
        }
        
        // Check if port has required facilities for vessel type
        val requiredFacilities = getRequiredFacilities(vessel.type)
        val missingFacilities = requiredFacilities - port.facilities
        if (missingFacilities.isNotEmpty()) {
            issues.add("Missing required facilities: ${missingFacilities.joinToString()}")
        }
        
        return CompatibilityResult(issues.isEmpty(), issues)
    }
    
    private fun findAvailableBerth(
        port: Port,
        vessel: Vessel,
        arrivalTime: LocalDateTime,
        departureTime: LocalDateTime
    ): Int? {
        val schedule = _vesselSchedule[port.id] ?: return 1
        
        // Simple berth allocation - check conflicts
        val maxBerths = port.capacity.maxVessels
        
        for (berthNumber in 1..maxBerths) {
            val hasConflict = schedule.any { entry ->
                entry.allocation.berthNumber == berthNumber &&
                !(departureTime.isBefore(entry.allocation.arrivalTime) || 
                  arrivalTime.isAfter(entry.allocation.departureTime))
            }
            
            if (!hasConflict) {
                return berthNumber
            }
        }
        
        return null
    }
    
    private fun calculateBerthingCost(
        port: Port,
        vessel: Vessel,
        arrivalTime: LocalDateTime,
        departureTime: LocalDateTime,
        operations: List<PlannedOperation>
    ): Double {
        val durationHours = java.time.Duration.between(arrivalTime, departureTime).toHours()
        val berthingCost = port.costs.berthingFee * (durationHours / 24.0)
        val handlingCost = operations.sumOf { operation ->
            (port.costs.handlingCost[operation.commodity.type] ?: 0.0) * operation.quantity
        }
        
        return berthingCost + handlingCost + port.costs.pilotage + port.costs.towage + port.costs.agencyFees
    }
    
    private fun updatePortUtilization(portId: String) {
        val portState = _portStates[portId] ?: return
        val schedule = _vesselSchedule[portId] ?: return
        
        val now = LocalDateTime.now()
        val currentVessels = schedule.count { entry ->
            entry.actualArrival?.let { arrival ->
                arrival.isBefore(now) && (entry.actualDeparture?.isAfter(now) ?: true)
            } ?: false
        }
        
        val berthUtilization = currentVessels.toDouble() / portState.port.capacity.maxVessels * 100.0
        
        val operations = _portOperations[portId] ?: emptyList()
        val activeOperations = operations.count { it.status == OperationStatus.IN_PROGRESS }
        val craneUtilization = activeOperations.toDouble() / portState.port.infrastructure.numberOfCranes * 100.0
        
        val updatedUtilization = PortUtilization(
            berthUtilization = berthUtilization,
            craneUtilization = craneUtilization,
            storageUtilization = calculateStorageUtilization(portId),
            overallUtilization = (berthUtilization + craneUtilization) / 2.0
        )
        
        _portStates[portId] = portState.copy(
            currentUtilization = updatedUtilization,
            lastUpdated = LocalDateTime.now()
        )
    }
    
    private fun calculateStorageUtilization(portId: String): Double {
        val inventory = _cargoInventory[portId] ?: return 0.0
        val portState = _portStates[portId] ?: return 0.0
        
        val totalStored = inventory.values.sum()
        val totalCapacity = portState.port.capacity.storageCapacity.values.sum()
        
        return if (totalCapacity > 0) (totalStored / totalCapacity) * 100.0 else 0.0
    }
    
    private fun getCurrentWeather(port: Port): WeatherCondition {
        val month = LocalDateTime.now().monthValue
        return port.weatherConditions.averageConditions[month] ?: WeatherCondition.MODERATE
    }
    
    private fun getRequiredFacilities(vesselType: VesselType): Set<PortFacility> {
        return when (vesselType) {
            VesselType.CONTAINER_SHIP -> setOf(PortFacility.CONTAINER_TERMINAL, PortFacility.HEAVY_LIFT_CRANES)
            VesselType.BULK_CARRIER -> setOf(PortFacility.BULK_TERMINAL)
            VesselType.TANKER -> setOf(PortFacility.LIQUID_TERMINAL)
            VesselType.RORO -> setOf(PortFacility.RORO_TERMINAL)
            else -> setOf(PortFacility.GENERAL_CARGO_TERMINAL)
        }
    }
    
    private fun findScheduleEntry(portId: String, allocationId: String): VesselScheduleEntry? {
        return _vesselSchedule[portId]?.find { it.allocation.id == allocationId }
    }
    
    private fun findOperation(portId: String, operationId: String): PortOperation? {
        return _portOperations[portId]?.find { it.id == operationId }
    }
    
    private fun updateOperation(portId: String, operation: PortOperation) {
        val operations = _portOperations[portId] ?: return
        val index = operations.indexOfFirst { it.id == operation.id }
        if (index >= 0) {
            operations[index] = operation
        }
    }
    
    private fun updateCargoInventory(
        portId: String,
        operationType: OperationType,
        commodity: Commodity,
        quantity: Double
    ) {
        val inventory = _cargoInventory[portId] ?: return
        val currentAmount = inventory[commodity.type] ?: 0.0
        
        val newAmount = when (operationType) {
            OperationType.LOADING -> currentAmount - quantity
            OperationType.UNLOADING -> currentAmount + quantity
            else -> currentAmount
        }
        
        inventory[commodity.type] = maxOf(0.0, newAmount)
    }
    
    private fun calculateOperationDuration(portId: String, operation: PlannedOperation): Long {
        val portState = _portStates[portId] ?: return 60L
        val efficiency = portState.port.getEfficiencyFactor()
        val baseTime = when (operation.type) {
            OperationType.LOADING -> 30L // minutes per unit
            OperationType.UNLOADING -> 20L
            else -> 60L
        }
        return ((baseTime * operation.quantity) / efficiency).toLong()
    }
    
    private fun calculateQueuePosition(portId: String, allocationId: String): Int {
        val operations = _portOperations[portId] ?: return 1
        val waitingOperations = operations.filter { it.status == OperationStatus.WAITING }
        val targetOperation = operations.find { it.allocationId == allocationId }
        
        return if (targetOperation != null) {
            waitingOperations.indexOf(targetOperation) + 1
        } else 1
    }
    
    private fun calculateWaitTime(portId: String, allocationId: String): Long {
        val queuePosition = calculateQueuePosition(portId, allocationId)
        return (queuePosition * 30L) // 30 minutes per position estimate
    }
    
    private fun checkOperationPreconditions(portState: PortState, operation: PortOperation): PreconditionResult {
        val issues = mutableListOf<String>()
        
        // Check weather conditions
        if (portState.weather == WeatherCondition.SEVERE) {
            issues.add("Severe weather conditions prevent operations")
        }
        
        // Check port operational status
        if (portState.operationalStatus != OperationalStatus.OPERATIONAL) {
            issues.add("Port is not operational")
        }
        
        // Check crane availability
        val activeOperations = getActiveOperations(portState.port.id)
        if (activeOperations.size >= portState.port.infrastructure.numberOfCranes) {
            issues.add("No cranes available")
        }
        
        return PreconditionResult(issues.isEmpty(), issues)
    }
    
    private fun calculateOperationEfficiency(operation: PortOperation, completionTime: LocalDateTime): Double {
        val actualDuration = operation.actualStart?.let { start ->
            java.time.Duration.between(start, completionTime).toMinutes()
        } ?: return 1.0
        
        val plannedDuration = operation.estimatedDuration
        return if (actualDuration > 0) {
            (plannedDuration.toDouble() / actualDuration).coerceIn(0.1, 2.0)
        } else 1.0
    }
    
    private fun calculateActualCost(scheduleEntry: VesselScheduleEntry): Double {
        // Calculate actual cost based on actual time spent and operations completed
        val allocation = scheduleEntry.allocation
        val actualDuration = scheduleEntry.actualArrival?.let { arrival ->
            scheduleEntry.actualDeparture?.let { departure ->
                java.time.Duration.between(arrival, departure).toHours()
            }
        } ?: 0L
        
        return allocation.estimatedCost * (actualDuration / 24.0)
    }
    
    private fun calculateAverageTurnaroundTime(arrivals: List<VesselScheduleEntry>): Double {
        val turnaroundTimes = arrivals.mapNotNull { entry ->
            entry.actualArrival?.let { arrival ->
                entry.actualDeparture?.let { departure ->
                    java.time.Duration.between(arrival, departure).toMinutes().toDouble()
                }
            }
        }
        
        return turnaroundTimes.average().takeIf { !it.isNaN() } ?: 0.0
    }
    
    private fun calculateOperationalEfficiency(operations: List<PortOperation>): Double {
        val completedOperations = operations.filter { it.status == OperationStatus.COMPLETED }
        return if (operations.isNotEmpty()) {
            (completedOperations.size.toDouble() / operations.size) * 100.0
        } else 100.0
    }
    
    private fun calculatePortRevenue(arrivals: List<VesselScheduleEntry>): Double {
        return arrivals.sumOf { it.allocation.estimatedCost }
    }
    
    private fun calculateUtilizationRate(portId: String, period: TimePeriod): Double {
        val portState = _portStates[portId] ?: return 0.0
        // Simplified calculation - would need more detailed tracking in practice
        return portState.currentUtilization.overallUtilization
    }
}

// Data classes and supporting types

/**
 * Current state of a port
 */
data class PortState(
    val port: Port,
    val currentUtilization: PortUtilization,
    val weather: WeatherCondition,
    val operationalStatus: OperationalStatus,
    val lastUpdated: LocalDateTime
)

/**
 * Port utilization metrics
 */
data class PortUtilization(
    val berthUtilization: Double = 0.0,      // Percentage of berths occupied
    val craneUtilization: Double = 0.0,      // Percentage of cranes in use
    val storageUtilization: Double = 0.0,    // Percentage of storage capacity used
    val overallUtilization: Double = 0.0     // Overall utilization metric
)

/**
 * Port operational status
 */
enum class OperationalStatus {
    OPERATIONAL,
    LIMITED_OPERATIONS,
    SUSPENDED,
    EMERGENCY_ONLY,
    CLOSED
}

/**
 * Berth allocation for a vessel
 */
data class BerthAllocation(
    val id: String,
    val portId: String,
    val vessel: Vessel,
    val berthNumber: Int,
    val arrivalTime: LocalDateTime,
    val departureTime: LocalDateTime,
    val operations: List<PlannedOperation>,
    val status: AllocationStatus,
    val estimatedCost: Double
)

/**
 * Status of berth allocation
 */
enum class AllocationStatus {
    REQUESTED,
    CONFIRMED,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED
}

/**
 * Planned operation during port stay
 */
data class PlannedOperation(
    val type: OperationType,
    val commodity: Commodity,
    val quantity: Double,
    val priority: CargoPriority = CargoPriority.NORMAL
)

/**
 * Types of port operations
 */
enum class OperationType {
    LOADING,
    UNLOADING,
    TRANSSHIPMENT,
    BUNKERING,
    MAINTENANCE,
    INSPECTION
}

/**
 * Actual port operation being performed
 */
data class PortOperation(
    val id: String,
    val allocationId: String,
    val type: OperationType,
    val commodity: Commodity,
    val quantity: Double,
    val status: OperationStatus,
    val scheduledStart: LocalDateTime,
    val estimatedDuration: Long, // minutes
    val actualStart: LocalDateTime? = null,
    val actualEnd: LocalDateTime? = null,
    val efficiency: Double = 1.0
)

/**
 * Status of port operation
 */
enum class OperationStatus {
    WAITING,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED,
    DELAYED
}

/**
 * Vessel schedule entry
 */
data class VesselScheduleEntry(
    val allocation: BerthAllocation,
    var actualArrival: LocalDateTime? = null,
    var actualDeparture: LocalDateTime? = null,
    val delays: MutableList<OperationDelay> = mutableListOf()
)

/**
 * Operation delay information
 */
data class OperationDelay(
    val type: DelayType,
    val durationMinutes: Long,
    val reason: String,
    val timestamp: LocalDateTime
)

/**
 * Types of delays
 */
enum class DelayType {
    ARRIVAL,
    DEPARTURE,
    OPERATION,
    WEATHER,
    EQUIPMENT,
    BUREAUCRATIC
}

/**
 * Result of vessel arrival processing
 */
data class VesselArrivalResult(
    val allocationId: String,
    val arrivalDelay: OperationDelay?,
    val queuePosition: Int,
    val estimatedWaitTime: Long, // minutes
    val operations: List<PortOperation>
)

/**
 * Result of vessel departure processing
 */
data class VesselDepartureResult(
    val allocationId: String,
    val departureDelay: OperationDelay?,
    val totalPortTime: Long, // minutes
    val completedOperations: List<PortOperation>,
    val totalCost: Double
)

/**
 * Port performance metrics for a time period
 */
data class PortPerformanceMetrics(
    val portId: String,
    val period: TimePeriod,
    val totalVessels: Int,
    val onTimeArrivals: Int,
    val averageTurnaroundTime: Double, // minutes
    val totalCargoHandled: Double,
    val operationalEfficiency: Double, // percentage
    val revenueGenerated: Double,
    val utilizationRate: Double // percentage
)

/**
 * Time period for performance analysis
 */
data class TimePeriod(
    val start: LocalDateTime,
    val end: LocalDateTime
)

// Helper result classes
data class CompatibilityResult(val compatible: Boolean, val issues: List<String>)
data class PreconditionResult(val success: Boolean, val issues: List<String>)

// Port events
sealed class PortEvent {
    data class PortInitialized(val portState: PortState) : PortEvent()
    data class BerthAllocated(val allocation: BerthAllocation) : PortEvent()
    data class VesselArrived(val vessel: Vessel, val time: LocalDateTime) : PortEvent()
    data class VesselDeparted(val vessel: Vessel, val time: LocalDateTime) : PortEvent()
    data class OperationStarted(val operation: PortOperation) : PortEvent()
    data class OperationCompleted(val operation: PortOperation) : PortEvent()
    data class UtilizationChanged(val portId: String, val utilization: PortUtilization) : PortEvent()
}

// Custom exceptions
class PortNotFoundException(portId: String) : Exception("Port not found: $portId")
class AllocationNotFoundException(allocationId: String) : Exception("Allocation not found: $allocationId")
class OperationNotFoundException(operationId: String) : Exception("Operation not found: $operationId")
class IncompatibleVesselException(issues: List<String>) : Exception("Vessel incompatible: ${issues.joinToString()}")
class NoAvailableBerthException(message: String) : Exception(message)
class OperationCannotStartException(issues: List<String>) : Exception("Operation cannot start: ${issues.joinToString()}")