package com.flexport.economics.models

/**
 * Types of financial instruments
 */
enum class InstrumentType {
    BOND,
    EQUITY,
    LOAN,
    DERIVATIVE,
    COMMODITY_FUTURE,
    CURRENCY
}

/**
 * Base class for all financial instruments
 */
abstract class FinancialInstrument {
    abstract val id: String
    abstract val type: InstrumentType
    abstract val currentValue: Double
    abstract val issuerId: String
    abstract val maturityDate: Long?
    
    /**
     * Calculate the current market value of the instrument
     */
    abstract fun calculateMarketValue(): Double
    
    /**
     * Get the risk rating of the instrument
     */
    abstract fun getRiskRating(): Double
}