package com.flexport.economics.markets

import com.flexport.economics.models.Asset
import com.flexport.economics.models.AssetType
import com.flexport.economics.models.AssetCondition
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.exp
import kotlin.math.pow

/**
 * Market for physical assets like ships, planes, and warehouses.
 * Handles depreciation, maintenance costs, and asset valuations.
 */
class AssetMarket : AbstractMarket() {
    
    // Active assets in the market
    private val ships = ConcurrentHashMap<String, Ship>()
    private val aircraft = ConcurrentHashMap<String, Aircraft>()
    private val warehouses = ConcurrentHashMap<String, Warehouse>()
    private val vehicles = ConcurrentHashMap<String, Vehicle>()
    
    // Lease agreements
    private val leaseAgreements = ConcurrentHashMap<String, LeaseAgreement>()
    
    // Asset utilization rates
    private val utilizationRates = ConcurrentHashMap<String, Double>()
    
    // Market factors
    private var fuelPrice = 100.0 // Base fuel price
    private var maintenanceCostIndex = 1.0
    private var insurancePremiumRate = 0.02 // 2% of asset value annually
    
    /**
     * List a ship for sale or lease
     */
    fun listShip(
        ownerId: String,
        model: String,
        capacity: Double, // TEU for containers
        age: Int,
        condition: AssetCondition,
        specifications: ShipSpecifications
    ): Ship {
        val shipId = "SHIP-${System.currentTimeMillis()}"
        
        val ship = Ship(
            id = shipId,
            ownerId = ownerId,
            model = model,
            capacity = capacity,
            age = age,
            condition = condition,
            specifications = specifications,
            currentValue = calculateShipValue(specifications, age, condition),
            operatingCosts = calculateShipOperatingCosts(specifications)
        )
        
        ships[shipId] = ship
        utilizationRates[shipId] = 0.0
        
        // Create sell order for the ship
        addSellOrder(1.0, ship.currentValue, ownerId)
        
        return ship
    }
    
    /**
     * List an aircraft for sale or lease
     */
    fun listAircraft(
        ownerId: String,
        model: String,
        cargoCapacity: Double, // kg
        passengerCapacity: Int,
        range: Double, // km
        age: Int,
        condition: AssetCondition,
        specifications: AircraftSpecifications
    ): Aircraft {
        val aircraftId = "AIR-${System.currentTimeMillis()}"
        
        val aircraft = Aircraft(
            id = aircraftId,
            ownerId = ownerId,
            model = model,
            cargoCapacity = cargoCapacity,
            passengerCapacity = passengerCapacity,
            range = range,
            age = age,
            condition = condition,
            specifications = specifications,
            currentValue = calculateAircraftValue(specifications, age, condition),
            operatingCosts = calculateAircraftOperatingCosts(specifications)
        )
        
        aircraft[aircraftId] = aircraft
        utilizationRates[aircraftId] = 0.0
        
        // Create sell order
        addSellOrder(1.0, aircraft.currentValue, ownerId)
        
        return aircraft
    }
    
    /**
     * List a warehouse for sale or lease
     */
    fun listWarehouse(
        ownerId: String,
        location: String,
        storageCapacity: Double, // cubic meters
        specifications: WarehouseSpecifications
    ): Warehouse {
        val warehouseId = "WH-${System.currentTimeMillis()}"
        
        val warehouse = Warehouse(
            id = warehouseId,
            ownerId = ownerId,
            location = location,
            storageCapacity = storageCapacity,
            specifications = specifications,
            currentValue = calculateWarehouseValue(specifications, location),
            monthlyOperatingCost = calculateWarehouseOperatingCosts(specifications)
        )
        
        warehouses[warehouseId] = warehouse
        utilizationRates[warehouseId] = 0.0
        
        // Create sell order
        addSellOrder(1.0, warehouse.currentValue, ownerId)
        
        return warehouse
    }
    
    /**
     * Create a lease agreement for an asset
     */
    fun createLeaseAgreement(
        assetId: String,
        lesseeId: String,
        monthlyPayment: Double,
        termMonths: Int,
        maintenanceIncluded: Boolean = false
    ): LeaseAgreement {
        val leaseId = "LEASE-${System.currentTimeMillis()}"
        
        val agreement = LeaseAgreement(
            id = leaseId,
            assetId = assetId,
            lesseeId = lesseeId,
            monthlyPayment = monthlyPayment,
            termMonths = termMonths,
            remainingMonths = termMonths,
            maintenanceIncluded = maintenanceIncluded,
            startDate = System.currentTimeMillis(),
            status = LeaseStatus.ACTIVE
        )
        
        leaseAgreements[leaseId] = agreement
        
        return agreement
    }
    
    /**
     * Calculate ship value based on specifications and condition
     */
    private fun calculateShipValue(
        specs: ShipSpecifications,
        age: Int,
        condition: AssetCondition
    ): Double {
        val baseValue = specs.deadweightTonnage * 1000 + // $1000 per DWT
                       specs.maxSpeed * 10000 + // Speed premium
                       specs.fuelEfficiency * 50000 // Efficiency premium
        
        // Depreciation: 5% per year, accelerating after 10 years
        val depreciationRate = if (age <= 10) 0.05 else 0.08
        val ageMultiplier = (1 - depreciationRate).pow(age)
        
        // Condition multiplier
        val conditionMultiplier = when (condition) {
            AssetCondition.EXCELLENT -> 1.1
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 0.85
            AssetCondition.POOR -> 0.6
            AssetCondition.NEEDS_REPAIR -> 0.4
        }
        
        return baseValue * ageMultiplier * conditionMultiplier
    }
    
    /**
     * Calculate aircraft value
     */
    private fun calculateAircraftValue(
        specs: AircraftSpecifications,
        age: Int,
        condition: AssetCondition
    ): Double {
        val baseValue = specs.maxTakeoffWeight * 500 + // $500 per kg MTOW
                       specs.cruiseSpeed * 20000 + // Speed premium
                       specs.fuelCapacity * 100 // Fuel capacity value
        
        // Aircraft depreciate faster: 7% per year
        val depreciationRate = 0.07
        val ageMultiplier = (1 - depreciationRate).pow(age)
        
        val conditionMultiplier = when (condition) {
            AssetCondition.EXCELLENT -> 1.15
            AssetCondition.GOOD -> 1.0
            AssetCondition.FAIR -> 0.8
            AssetCondition.POOR -> 0.5
            AssetCondition.NEEDS_REPAIR -> 0.3
        }
        
        return baseValue * ageMultiplier * conditionMultiplier
    }
    
    /**
     * Calculate warehouse value based on location and specifications
     */
    private fun calculateWarehouseValue(
        specs: WarehouseSpecifications,
        location: String
    ): Double {
        val baseValuePerSqm = 500.0 // $500 per square meter
        val baseValue = specs.floorArea * baseValuePerSqm
        
        // Location multiplier (simplified - in real implementation would use actual location data)
        val locationMultiplier = when {
            location.contains("Port") -> 1.5
            location.contains("Airport") -> 1.4
            location.contains("City") -> 1.2
            else -> 1.0
        }
        
        // Feature multipliers
        val featureMultiplier = 1.0 +
            (if (specs.temperatureControlled) 0.2 else 0.0) +
            (if (specs.securityLevel == SecurityLevel.HIGH) 0.1 else 0.0) +
            (specs.loadingDocks * 0.02) // 2% per loading dock
        
        return baseValue * locationMultiplier * featureMultiplier
    }
    
    /**
     * Calculate operating costs for ships
     */
    private fun calculateShipOperatingCosts(specs: ShipSpecifications): OperatingCosts {
        val dailyFuelCost = (specs.deadweightTonnage / specs.fuelEfficiency) * fuelPrice
        val dailyCrewCost = specs.crewSize * 200.0 // $200 per crew member per day
        val annualMaintenance = specs.deadweightTonnage * 50.0 // $50 per DWT annually
        val annualInsurance = calculateShipValue(specs, 0, AssetCondition.GOOD) * insurancePremiumRate
        
        return OperatingCosts(
            fuelCostPerDay = dailyFuelCost,
            crewCostPerDay = dailyCrewCost,
            maintenanceCostPerYear = annualMaintenance * maintenanceCostIndex,
            insuranceCostPerYear = annualInsurance,
            portFeesPerDocking = specs.deadweightTonnage * 2.0 // $2 per DWT
        )
    }
    
    /**
     * Calculate operating costs for aircraft
     */
    private fun calculateAircraftOperatingCosts(specs: AircraftSpecifications): OperatingCosts {
        val hourlyFuelCost = specs.fuelConsumptionPerHour * fuelPrice
        val hourlyCrewCost = specs.crewSize * 150.0 // $150 per crew member per hour
        val annualMaintenance = specs.maxTakeoffWeight * 100.0 // $100 per kg MTOW annually
        val annualInsurance = calculateAircraftValue(specs, 0, AssetCondition.GOOD) * insurancePremiumRate * 1.5
        
        return OperatingCosts(
            fuelCostPerDay = hourlyFuelCost * 8, // Assume 8 flight hours per day
            crewCostPerDay = hourlyCrewCost * 8,
            maintenanceCostPerYear = annualMaintenance * maintenanceCostIndex,
            insuranceCostPerYear = annualInsurance,
            portFeesPerDocking = 5000.0 // Fixed landing fee
        )
    }
    
    /**
     * Calculate warehouse operating costs
     */
    private fun calculateWarehouseOperatingCosts(specs: WarehouseSpecifications): Double {
        val baseCostPerSqm = 10.0 // $10 per square meter per month
        var monthlyCost = specs.floorArea * baseCostPerSqm
        
        // Additional costs
        if (specs.temperatureControlled) {
            monthlyCost *= 1.5 // 50% more for temperature control
        }
        
        monthlyCost += specs.loadingDocks * 500 // $500 per loading dock per month
        
        if (specs.securityLevel == SecurityLevel.HIGH) {
            monthlyCost += 5000 // $5000 for high security
        }
        
        return monthlyCost
    }
    
    override fun update(deltaTime: Float) {
        super.update(deltaTime)
        
        // Update asset depreciation
        updateAssetDepreciation(deltaTime)
        
        // Process lease payments
        processLeasePayments(deltaTime)
        
        // Update utilization rates
        updateUtilizationRates()
        
        // Update fuel prices
        updateFuelPrices(deltaTime)
    }
    
    /**
     * Update asset values based on depreciation and condition
     */
    private fun updateAssetDepreciation(deltaTime: Float) {
        val yearFraction = deltaTime / (365f * 24 * 60 * 60)
        
        // Depreciate ships
        ships.values.forEach { ship ->
            ship.age += yearFraction
            ship.currentValue *= (1 - 0.05 * yearFraction) // 5% annual depreciation
            
            // Condition deterioration
            if (Math.random() < 0.01 * yearFraction) {
                ship.condition = deteriorateCondition(ship.condition)
            }
        }
        
        // Depreciate aircraft
        aircraft.values.forEach { aircraft ->
            aircraft.age += yearFraction
            aircraft.currentValue *= (1 - 0.07 * yearFraction) // 7% annual depreciation
            
            if (Math.random() < 0.02 * yearFraction) {
                aircraft.condition = deteriorateCondition(aircraft.condition)
            }
        }
        
        // Warehouses depreciate more slowly
        warehouses.values.forEach { warehouse ->
            warehouse.currentValue *= (1 - 0.02 * yearFraction) // 2% annual depreciation
        }
    }
    
    /**
     * Deteriorate asset condition
     */
    private fun deteriorateCondition(current: AssetCondition): AssetCondition {
        return when (current) {
            AssetCondition.EXCELLENT -> AssetCondition.GOOD
            AssetCondition.GOOD -> AssetCondition.FAIR
            AssetCondition.FAIR -> AssetCondition.POOR
            AssetCondition.POOR -> AssetCondition.NEEDS_REPAIR
            AssetCondition.NEEDS_REPAIR -> AssetCondition.NEEDS_REPAIR
        }
    }
    
    /**
     * Process lease payments
     */
    private fun processLeasePayments(deltaTime: Float) {
        val monthsPassed = deltaTime / (30f * 24 * 60 * 60)
        
        leaseAgreements.values.forEach { lease ->
            if (lease.status == LeaseStatus.ACTIVE && monthsPassed >= 1.0) {
                lease.remainingMonths--
                
                // In real implementation, process payment transfer
                
                if (lease.remainingMonths <= 0) {
                    lease.status = LeaseStatus.COMPLETED
                }
            }
        }
    }
    
    /**
     * Update asset utilization rates
     */
    private fun updateUtilizationRates() {
        // In real implementation, this would track actual usage
        // For now, simulate with random utilization
        utilizationRates.keys.forEach { assetId ->
            utilizationRates[assetId] = 0.5 + Math.random() * 0.4 // 50-90% utilization
        }
    }
    
    /**
     * Update fuel prices based on market conditions
     */
    private fun updateFuelPrices(deltaTime: Float) {
        // Simple random walk for fuel prices
        fuelPrice *= (1.0 + (Math.random() - 0.5) * 0.01) // ±0.5% change
        fuelPrice = fuelPrice.coerceIn(50.0, 200.0) // Keep within reasonable bounds
    }
    
    override fun executeTrade(
        buyOrder: Order.BuyOrder,
        sellOrder: Order.SellOrder,
        price: Double,
        quantity: Double
    ) {
        // Transfer asset ownership
        // In real implementation, would update asset ownership records
    }
    
    override fun processEvent(event: MarketEvent) {
        when (event) {
            is AssetMarketEvent -> {
                when (event) {
                    is AssetMarketEvent.FuelPriceShock -> {
                        fuelPrice *= event.multiplier
                    }
                    is AssetMarketEvent.MaintenanceCostChange -> {
                        maintenanceCostIndex = event.newIndex
                    }
                    is AssetMarketEvent.InsurancePremiumChange -> {
                        insurancePremiumRate = event.newRate
                    }
                    is AssetMarketEvent.AssetBubble -> {
                        // Inflate asset prices
                        val inflationFactor = 1.0 + event.severity
                        ships.values.forEach { it.currentValue *= inflationFactor }
                        aircraft.values.forEach { it.currentValue *= inflationFactor }
                        warehouses.values.forEach { it.currentValue *= inflationFactor }
                    }
                }
            }
            else -> {
                // Handle other event types
            }
        }
    }
    
    /**
     * Get market statistics for a specific asset type
     */
    fun getAssetTypeStats(assetType: AssetType): AssetMarketStats {
        val assets = when (assetType) {
            AssetType.SHIP -> ships.values
            AssetType.AIRCRAFT -> aircraft.values
            AssetType.WAREHOUSE -> warehouses.values
            AssetType.VEHICLE -> vehicles.values
        }
        
        return AssetMarketStats(
            assetType = assetType,
            totalAssets = assets.size,
            averageValue = assets.map { it.currentValue }.average(),
            averageAge = when (assetType) {
                AssetType.SHIP -> ships.values.map { it.age }.average()
                AssetType.AIRCRAFT -> aircraft.values.map { it.age }.average()
                else -> 0.0
            },
            averageUtilization = assets.map { 
                utilizationRates[it.id] ?: 0.0 
            }.average(),
            totalLeased = leaseAgreements.values.count { lease ->
                lease.status == LeaseStatus.ACTIVE && 
                assets.any { it.id == lease.assetId }
            }
        )
    }
}

/**
 * Ship asset
 */
data class Ship(
    override val id: String,
    override var ownerId: String,
    val model: String,
    val capacity: Double,
    var age: Double,
    override var condition: AssetCondition,
    val specifications: ShipSpecifications,
    override var currentValue: Double,
    val operatingCosts: OperatingCosts
) : Asset

/**
 * Aircraft asset
 */
data class Aircraft(
    override val id: String,
    override var ownerId: String,
    val model: String,
    val cargoCapacity: Double,
    val passengerCapacity: Int,
    val range: Double,
    var age: Double,
    override var condition: AssetCondition,
    val specifications: AircraftSpecifications,
    override var currentValue: Double,
    val operatingCosts: OperatingCosts
) : Asset

/**
 * Warehouse asset
 */
data class Warehouse(
    override val id: String,
    override var ownerId: String,
    val location: String,
    val storageCapacity: Double,
    val specifications: WarehouseSpecifications,
    override var currentValue: Double,
    override var condition: AssetCondition = AssetCondition.GOOD,
    val monthlyOperatingCost: Double
) : Asset

/**
 * Vehicle asset (trucks, vans, etc.)
 */
data class Vehicle(
    override val id: String,
    override var ownerId: String,
    val model: String,
    val cargoCapacity: Double,
    var age: Double,
    override var condition: AssetCondition,
    override var currentValue: Double
) : Asset

/**
 * Ship specifications
 */
data class ShipSpecifications(
    val deadweightTonnage: Double,
    val maxSpeed: Double, // knots
    val fuelEfficiency: Double, // km per liter
    val crewSize: Int,
    val containerCapacity: Int? = null // TEU
)

/**
 * Aircraft specifications
 */
data class AircraftSpecifications(
    val maxTakeoffWeight: Double, // kg
    val cruiseSpeed: Double, // km/h
    val fuelCapacity: Double, // liters
    val fuelConsumptionPerHour: Double, // liters/hour
    val crewSize: Int
)

/**
 * Warehouse specifications
 */
data class WarehouseSpecifications(
    val floorArea: Double, // square meters
    val ceilingHeight: Double, // meters
    val loadingDocks: Int,
    val temperatureControlled: Boolean,
    val securityLevel: SecurityLevel
)

/**
 * Security levels for warehouses
 */
enum class SecurityLevel {
    BASIC,
    MEDIUM,
    HIGH
}

/**
 * Operating costs structure
 */
data class OperatingCosts(
    val fuelCostPerDay: Double,
    val crewCostPerDay: Double,
    val maintenanceCostPerYear: Double,
    val insuranceCostPerYear: Double,
    val portFeesPerDocking: Double
)

/**
 * Lease agreement
 */
data class LeaseAgreement(
    val id: String,
    val assetId: String,
    val lesseeId: String,
    val monthlyPayment: Double,
    val termMonths: Int,
    var remainingMonths: Int,
    val maintenanceIncluded: Boolean,
    val startDate: Long,
    var status: LeaseStatus
)

/**
 * Lease status
 */
enum class LeaseStatus {
    ACTIVE,
    COMPLETED,
    TERMINATED,
    DEFAULT
}

/**
 * Asset market statistics
 */
data class AssetMarketStats(
    val assetType: AssetType,
    val totalAssets: Int,
    val averageValue: Double,
    val averageAge: Double,
    val averageUtilization: Double,
    val totalLeased: Int
)

/**
 * Asset market events
 */
sealed class AssetMarketEvent : MarketEvent() {
    data class FuelPriceShock(
        override val timestamp: Long,
        override val impact: MarketImpact,
        val multiplier: Double
    ) : AssetMarketEvent()
    
    data class MaintenanceCostChange(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.MEDIUM,
        val newIndex: Double
    ) : AssetMarketEvent()
    
    data class InsurancePremiumChange(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.LOW,
        val newRate: Double
    ) : AssetMarketEvent()
    
    data class AssetBubble(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH,
        val severity: Double
    ) : AssetMarketEvent()
}