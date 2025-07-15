package com.flexport.game.ecs.components

import com.flexport.game.ecs.core.Component

/**
 * Types of cargo/goods in the game
 */
enum class CargoType {
    ELECTRONICS,
    TEXTILES,
    FOOD,
    RAW_MATERIALS,
    MACHINERY,
    CHEMICALS,
    CONSUMER_GOODS
}

/**
 * Represents a cargo item with type and quantity
 */
data class CargoItem(
    val type: CargoType,
    var quantity: Int,
    var purchasePrice: Float = 0f // Price per unit when purchased
)

/**
 * Component for economic interactions and market data
 */
data class EconomicComponent(
    var balance: Float = 0f, // Current money balance
    var creditLimit: Float = 0f,
    var creditUsed: Float = 0f,
    val cargo: MutableList<CargoItem> = mutableListOf(),
    val priceModifiers: MutableMap<CargoType, Float> = mutableMapOf(), // Local price modifiers
    var lastTransactionTime: Long = 0L,
    var totalRevenue: Float = 0f,
    var totalExpenses: Float = 0f
) : Component {
    
    /**
     * Get available credit
     */
    fun getAvailableCredit(): Float = creditLimit - creditUsed
    
    /**
     * Check if can afford transaction
     */
    fun canAfford(amount: Float): Boolean {
        return balance >= amount || (balance + getAvailableCredit()) >= amount
    }
    
    /**
     * Process payment
     */
    fun processPayment(amount: Float): Boolean {
        if (!canAfford(amount)) return false
        
        if (balance >= amount) {
            balance -= amount
        } else {
            val creditNeeded = amount - balance
            balance = 0f
            creditUsed += creditNeeded
        }
        
        totalExpenses += amount
        lastTransactionTime = java.lang.System.currentTimeMillis()
        return true
    }
    
    /**
     * Receive payment
     */
    fun receivePayment(amount: Float) {
        balance += amount
        totalRevenue += amount
        lastTransactionTime = java.lang.System.currentTimeMillis()
        
        // Pay off credit if any
        if (creditUsed > 0 && balance > 0) {
            val payoff = minOf(balance, creditUsed)
            balance -= payoff
            creditUsed -= payoff
        }
    }
    
    /**
     * Get cargo of specific type
     */
    fun getCargoOfType(type: CargoType): CargoItem? {
        return cargo.find { it.type == type }
    }
    
    /**
     * Add cargo
     */
    fun addCargo(type: CargoType, quantity: Int, pricePerUnit: Float) {
        val existing = getCargoOfType(type)
        if (existing != null) {
            // Calculate weighted average price
            val totalValue = existing.quantity * existing.purchasePrice + quantity * pricePerUnit
            val totalQuantity = existing.quantity + quantity
            existing.quantity = totalQuantity
            existing.purchasePrice = totalValue / totalQuantity
        } else {
            cargo.add(CargoItem(type, quantity, pricePerUnit))
        }
    }
    
    /**
     * Remove cargo
     */
    fun removeCargo(type: CargoType, quantity: Int): Boolean {
        val cargoItem = getCargoOfType(type) ?: return false
        if (cargoItem.quantity < quantity) return false
        
        cargoItem.quantity -= quantity
        if (cargoItem.quantity == 0) {
            cargo.remove(cargoItem)
        }
        return true
    }
    
    /**
     * Get total cargo value at purchase prices
     */
    fun getTotalCargoValue(): Float {
        return cargo.sumOf { (it.quantity * it.purchasePrice).toDouble() }.toFloat()
    }
    
    /**
     * Get profit margin
     */
    fun getProfitMargin(): Float {
        return if (totalRevenue > 0) {
            (totalRevenue - totalExpenses) / totalRevenue
        } else 0f
    }
}