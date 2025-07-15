package com.flexport.game.economics.models

import kotlinx.serialization.Serializable

/**
 * Represents different types of commodities that can be traded
 */
enum class CommodityType {
    // Basic goods
    FOOD,
    FUEL,
    RAW_MATERIALS,
    
    // Manufactured goods
    ELECTRONICS,
    MACHINERY,
    VEHICLES,
    CLOTHING,
    
    // Specialized goods
    PHARMACEUTICALS,
    LUXURY_GOODS,
    CONSTRUCTION_MATERIALS,
    
    // Energy
    ELECTRICITY,
    NATURAL_GAS,
    RENEWABLE_ENERGY_CREDITS
}

/**
 * Represents a commodity with its properties
 */
@Serializable
data class Commodity(
    val type: CommodityType,
    val name: String,
    val description: String,
    val unit: CommodityUnit,
    val weight: Double, // kg per unit
    val volume: Double, // cubic meters per unit
    val perishable: Boolean,
    val hazardous: Boolean,
    val baseValue: Double, // Base price per unit
    val storageRequirements: StorageRequirements
)

/**
 * Units of measurement for commodities
 */
enum class CommodityUnit {
    KILOGRAM,
    TON,
    LITER,
    CUBIC_METER,
    BARREL,
    CONTAINER, // Standard shipping container
    PALLET,
    UNIT // For discrete items
}

/**
 * Storage requirements for commodities
 */
@Serializable
data class StorageRequirements(
    val temperatureControlled: Boolean,
    val minTemperature: Float? = null, // Celsius
    val maxTemperature: Float? = null, // Celsius
    val humidity: HumidityRequirement = HumidityRequirement.NORMAL,
    val specialHandling: Set<SpecialHandling> = emptySet()
)

/**
 * Humidity requirements for storage
 */
enum class HumidityRequirement {
    DRY,
    NORMAL,
    HUMID
}

/**
 * Special handling requirements
 */
enum class SpecialHandling {
    FRAGILE,
    FLAMMABLE,
    EXPLOSIVE,
    TOXIC,
    RADIOACTIVE,
    REFRIGERATED,
    FROZEN,
    LIVE_ANIMALS,
    PRESSURIZED
}

/**
 * Predefined commodities in the game
 */
object Commodities {
    val WHEAT = Commodity(
        type = CommodityType.FOOD,
        name = "Wheat",
        description = "Basic grain commodity used for food production",
        unit = CommodityUnit.TON,
        weight = 1000.0,
        volume = 1.3,
        perishable = true,
        hazardous = false,
        baseValue = 250.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = false,
            humidity = HumidityRequirement.DRY
        )
    )
    
    val CRUDE_OIL = Commodity(
        type = CommodityType.FUEL,
        name = "Crude Oil",
        description = "Unrefined petroleum for fuel production",
        unit = CommodityUnit.BARREL,
        weight = 136.4, // kg per barrel
        volume = 0.159, // cubic meters per barrel
        perishable = false,
        hazardous = true,
        baseValue = 80.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = false,
            specialHandling = setOf(SpecialHandling.FLAMMABLE, SpecialHandling.TOXIC)
        )
    )
    
    val ELECTRONICS_COMPONENTS = Commodity(
        type = CommodityType.ELECTRONICS,
        name = "Electronic Components",
        description = "Semiconductors and electronic parts",
        unit = CommodityUnit.CONTAINER,
        weight = 10000.0,
        volume = 33.0,
        perishable = false,
        hazardous = false,
        baseValue = 50000.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = true,
            minTemperature = 10f,
            maxTemperature = 30f,
            humidity = HumidityRequirement.DRY,
            specialHandling = setOf(SpecialHandling.FRAGILE)
        )
    )
    
    val PHARMACEUTICALS = Commodity(
        type = CommodityType.PHARMACEUTICALS,
        name = "Pharmaceutical Products",
        description = "Medical drugs and vaccines",
        unit = CommodityUnit.PALLET,
        weight = 500.0,
        volume = 1.2,
        perishable = true,
        hazardous = false,
        baseValue = 10000.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = true,
            minTemperature = 2f,
            maxTemperature = 8f,
            specialHandling = setOf(SpecialHandling.REFRIGERATED)
        )
    )
    
    val STEEL = Commodity(
        type = CommodityType.RAW_MATERIALS,
        name = "Steel",
        description = "Processed steel for construction and manufacturing",
        unit = CommodityUnit.TON,
        weight = 1000.0,
        volume = 0.127,
        perishable = false,
        hazardous = false,
        baseValue = 800.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = false
        )
    )
    
    val LUXURY_CARS = Commodity(
        type = CommodityType.VEHICLES,
        name = "Luxury Automobiles",
        description = "High-end passenger vehicles",
        unit = CommodityUnit.UNIT,
        weight = 2000.0,
        volume = 10.0,
        perishable = false,
        hazardous = false,
        baseValue = 80000.0,
        storageRequirements = StorageRequirements(
            temperatureControlled = true,
            minTemperature = 5f,
            maxTemperature = 40f,
            specialHandling = setOf(SpecialHandling.FRAGILE)
        )
    )
    
    // Map for easy lookup
    val ALL_COMMODITIES = listOf(
        WHEAT, CRUDE_OIL, ELECTRONICS_COMPONENTS,
        PHARMACEUTICALS, STEEL, LUXURY_CARS
    )
    
    val BY_TYPE = ALL_COMMODITIES.groupBy { it.type }
}