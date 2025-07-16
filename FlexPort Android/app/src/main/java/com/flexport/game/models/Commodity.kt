package com.flexport.game.models

import kotlinx.serialization.Serializable

/**
 * Represents a tradeable commodity in the FlexPort game.
 * Commodities are the core goods that players transport and trade.
 */
@Serializable
data class Commodity(
    val id: String,
    val name: String,
    val category: CommodityCategory,
    val basePrice: Double, // Base price per unit
    val volatility: Double, // Price volatility factor (0.0 to 1.0)
    val density: Double, // Units per ton (for capacity calculations)
    val perishable: Boolean = false,
    val dangerous: Boolean = false,
    val seasonalMultiplier: Double = 1.0
) {
    /**
     * Calculate current market price based on supply and demand
     */
    fun calculateMarketPrice(supply: Double, demand: Double, marketConditions: Double = 1.0): Double {
        val supplyDemandRatio = if (supply > 0) demand / supply else 2.0
        val volatilityFactor = 1.0 + (volatility * (supplyDemandRatio - 1.0))
        return basePrice * volatilityFactor * marketConditions * seasonalMultiplier
    }
    
    /**
     * Calculate storage cost based on commodity characteristics
     */
    fun getStorageCostPerDay(): Double {
        val baseCost = basePrice * 0.001 // 0.1% of base price per day
        val perishableMultiplier = if (perishable) 3.0 else 1.0
        val dangerousMultiplier = if (dangerous) 2.0 else 1.0
        return baseCost * perishableMultiplier * dangerousMultiplier
    }
    
    /**
     * Calculate insurance cost for transportation
     */
    fun getInsuranceCost(quantity: Int): Double {
        val value = basePrice * quantity
        val riskMultiplier = if (dangerous) 0.05 else 0.01 // 5% for dangerous, 1% for normal
        return value * riskMultiplier
    }
    
    /**
     * Get weight in tons for given quantity
     */
    fun getWeightInTons(quantity: Int): Double {
        return quantity / density
    }
}

@Serializable
enum class CommodityCategory {
    AGRICULTURE,
    ENERGY,
    METALS,
    CHEMICALS,
    MANUFACTURED_GOODS,
    TEXTILES,
    ELECTRONICS,
    FOOD_BEVERAGE,
    AUTOMOTIVE,
    CONSTRUCTION_MATERIALS
}

/**
 * Predefined commodity templates for the game
 */
object CommodityTemplates {
    val WHEAT = Commodity(
        id = "wheat",
        name = "Wheat",
        category = CommodityCategory.AGRICULTURE,
        basePrice = 200.0,
        volatility = 0.3,
        density = 1.35, // tons per cubic meter
        perishable = true,
        seasonalMultiplier = 1.0
    )
    
    val CRUDE_OIL = Commodity(
        id = "crude_oil",
        name = "Crude Oil",
        category = CommodityCategory.ENERGY,
        basePrice = 70.0,
        volatility = 0.5,
        density = 0.85,
        dangerous = true
    )
    
    val IRON_ORE = Commodity(
        id = "iron_ore",
        name = "Iron Ore",
        category = CommodityCategory.METALS,
        basePrice = 120.0,
        volatility = 0.2,
        density = 2.5
    )
    
    val ELECTRONICS = Commodity(
        id = "electronics",
        name = "Electronics",
        category = CommodityCategory.ELECTRONICS,
        basePrice = 2000.0,
        volatility = 0.4,
        density = 0.5
    )
    
    val COAL = Commodity(
        id = "coal",
        name = "Coal",
        category = CommodityCategory.ENERGY,
        basePrice = 80.0,
        volatility = 0.25,
        density = 1.3
    )
    
    val TEXTILES = Commodity(
        id = "textiles",
        name = "Textiles",
        category = CommodityCategory.TEXTILES,
        basePrice = 500.0,
        volatility = 0.3,
        density = 0.3
    )
    
    fun getAllTemplates(): List<Commodity> {
        return listOf(WHEAT, CRUDE_OIL, IRON_ORE, ELECTRONICS, COAL, TEXTILES)
    }
}