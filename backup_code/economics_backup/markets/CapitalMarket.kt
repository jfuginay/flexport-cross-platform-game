package com.flexport.economics.markets

import com.flexport.economics.models.FinancialInstrument
import com.flexport.economics.models.InstrumentType
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Market for financial instruments including debt, equity, and investments.
 * Handles interest rates, dividends, and investment opportunities.
 */
class CapitalMarket : AbstractMarket() {
    
    // Interest rate dynamics
    private var baseInterestRate = 0.05 // 5% annual
    private var riskFreeRate = 0.02 // 2% annual
    private var marketRiskPremium = 0.07 // 7% annual
    
    // Market indices
    private var marketIndex = 1000.0
    private var bondIndex = 100.0
    
    // Outstanding financial instruments
    private val bonds = ConcurrentHashMap<String, Bond>()
    private val equities = ConcurrentHashMap<String, Equity>()
    private val loans = ConcurrentHashMap<String, Loan>()
    
    // Credit ratings
    private val creditRatings = ConcurrentHashMap<String, CreditRating>()
    
    // Market volatility
    private var marketVolatility = 0.15 // 15% annual volatility
    private val volatilityHistory = mutableListOf<Double>()
    
    /**
     * Issue a new bond
     */
    fun issueBond(
        issuerId: String,
        principal: Double,
        couponRate: Double,
        maturityYears: Int,
        rating: CreditRating = CreditRating.BBB
    ): Bond {
        val bondId = "BOND-${System.currentTimeMillis()}-${issuerId.take(4)}"
        
        // Adjust coupon rate based on credit rating
        val riskAdjustedRate = couponRate + rating.riskPremium
        
        val bond = Bond(
            id = bondId,
            issuerId = issuerId,
            principal = principal,
            couponRate = riskAdjustedRate,
            maturityDate = System.currentTimeMillis() + (maturityYears * 365L * 24 * 60 * 60 * 1000),
            rating = rating,
            currentPrice = calculateBondPrice(principal, riskAdjustedRate, maturityYears)
        )
        
        bonds[bondId] = bond
        creditRatings[issuerId] = rating
        
        return bond
    }
    
    /**
     * Issue new equity (IPO or secondary offering)
     */
    fun issueEquity(
        companyId: String,
        shares: Long,
        initialPrice: Double,
        sector: String,
        beta: Double = 1.0
    ): Equity {
        val equityId = "EQ-${companyId}"
        
        val equity = Equity(
            id = equityId,
            companyId = companyId,
            totalShares = shares,
            currentPrice = initialPrice,
            sector = sector,
            beta = beta,
            dividendYield = 0.02, // 2% initial dividend yield
            marketCap = shares * initialPrice
        )
        
        equities[equityId] = equity
        
        // Create initial sell order for IPO
        addSellOrder(shares.toDouble(), initialPrice, companyId)
        
        return equity
    }
    
    /**
     * Create a loan agreement
     */
    fun createLoan(
        lenderId: String,
        borrowerId: String,
        principal: Double,
        interestRate: Double,
        termMonths: Int,
        collateral: String? = null
    ): Loan {
        val loanId = "LOAN-${System.currentTimeMillis()}"
        
        // Adjust interest rate based on borrower's credit rating
        val borrowerRating = creditRatings[borrowerId] ?: CreditRating.BB
        val riskAdjustedRate = interestRate + borrowerRating.riskPremium
        
        val loan = Loan(
            id = loanId,
            lenderId = lenderId,
            borrowerId = borrowerId,
            principal = principal,
            interestRate = riskAdjustedRate,
            remainingPrincipal = principal,
            monthlyPayment = calculateMonthlyPayment(principal, riskAdjustedRate, termMonths),
            termMonths = termMonths,
            remainingMonths = termMonths,
            collateral = collateral,
            status = LoanStatus.ACTIVE
        )
        
        loans[loanId] = loan
        
        return loan
    }
    
    /**
     * Calculate bond price using present value formula
     */
    private fun calculateBondPrice(
        principal: Double,
        couponRate: Double,
        yearsToMaturity: Int
    ): Double {
        val yieldToMaturity = baseInterestRate
        var price = 0.0
        
        // Present value of coupon payments
        for (year in 1..yearsToMaturity) {
            price += (principal * couponRate) / (1 + yieldToMaturity).pow(year)
        }
        
        // Present value of principal
        price += principal / (1 + yieldToMaturity).pow(yearsToMaturity)
        
        return price
    }
    
    /**
     * Calculate monthly loan payment
     */
    private fun calculateMonthlyPayment(
        principal: Double,
        annualRate: Double,
        months: Int
    ): Double {
        val monthlyRate = annualRate / 12
        return principal * (monthlyRate * (1 + monthlyRate).pow(months)) / 
               ((1 + monthlyRate).pow(months) - 1)
    }
    
    /**
     * Update market with financial dynamics
     */
    override fun update(deltaTime: Float) {
        super.update(deltaTime)
        
        // Update interest rates based on market conditions
        updateInterestRates(deltaTime)
        
        // Update equity prices
        updateEquityPrices(deltaTime)
        
        // Process loan payments
        processLoanPayments(deltaTime)
        
        // Update market indices
        updateMarketIndices()
        
        // Calculate and store volatility
        calculateMarketVolatility()
    }
    
    /**
     * Update interest rates based on economic conditions
     */
    private fun updateInterestRates(deltaTime: Float) {
        // Simple mean reversion model for interest rates
        val targetRate = 0.05 // 5% long-term target
        val meanReversionSpeed = 0.1
        
        baseInterestRate += meanReversionSpeed * (targetRate - baseInterestRate) * deltaTime / 86400f
        
        // Add some randomness
        baseInterestRate += (Math.random() - 0.5) * 0.001
        baseInterestRate = baseInterestRate.coerceIn(0.001, 0.20) // Between 0.1% and 20%
    }
    
    /**
     * Update equity prices using CAPM and market dynamics
     */
    private fun updateEquityPrices(deltaTime: Float) {
        val marketReturn = (marketIndex - 1000.0) / 1000.0 // Market return from baseline
        
        equities.values.forEach { equity ->
            // Expected return using CAPM
            val expectedReturn = riskFreeRate + equity.beta * marketRiskPremium
            
            // Add market volatility
            val randomReturn = (Math.random() - 0.5) * marketVolatility * sqrt(deltaTime / 86400.0)
            
            // Update price
            val priceChange = equity.currentPrice * (expectedReturn * deltaTime / 31536000f + randomReturn)
            equity.currentPrice += priceChange
            equity.currentPrice = equity.currentPrice.coerceAtLeast(0.01) // Prevent negative prices
            
            // Update market cap
            equity.marketCap = equity.totalShares * equity.currentPrice
            
            // Pay dividends quarterly
            if (System.currentTimeMillis() % (90L * 24 * 60 * 60 * 1000) < deltaTime * 1000) {
                val dividendPerShare = equity.currentPrice * equity.dividendYield / 4
                // In real implementation, this would distribute to shareholders
            }
        }
    }
    
    /**
     * Process loan payments and defaults
     */
    private fun processLoanPayments(deltaTime: Float) {
        val monthsPassed = deltaTime / (30f * 24 * 60 * 60)
        
        loans.values.forEach { loan ->
            if (loan.status == LoanStatus.ACTIVE && monthsPassed >= 1.0) {
                loan.remainingMonths--
                
                // Process payment
                val interestPayment = loan.remainingPrincipal * loan.interestRate / 12
                val principalPayment = loan.monthlyPayment - interestPayment
                loan.remainingPrincipal -= principalPayment
                
                // Check for default (simplified - based on borrower's credit rating)
                val defaultProbability = creditRatings[loan.borrowerId]?.defaultProbability ?: 0.05
                if (Math.random() < defaultProbability * monthsPassed) {
                    loan.status = LoanStatus.DEFAULTED
                    // In real implementation, would trigger collateral seizure
                }
                
                // Check if loan is paid off
                if (loan.remainingMonths <= 0 || loan.remainingPrincipal <= 0) {
                    loan.status = LoanStatus.PAID_OFF
                }
            }
        }
    }
    
    /**
     * Update market indices
     */
    private fun updateMarketIndices() {
        // Stock market index - weighted average of equity prices
        if (equities.isNotEmpty()) {
            val totalMarketCap = equities.values.sumOf { it.marketCap }
            var weightedPriceChange = 0.0
            
            equities.values.forEach { equity ->
                val weight = equity.marketCap / totalMarketCap
                val priceChangeRatio = equity.currentPrice / (equity.currentPrice - 
                    (equity.priceHistory.lastOrNull() ?: equity.currentPrice))
                weightedPriceChange += weight * priceChangeRatio
            }
            
            marketIndex *= weightedPriceChange
        }
        
        // Bond index - based on average bond yields
        if (bonds.isNotEmpty()) {
            val avgYield = bonds.values.map { it.couponRate }.average()
            bondIndex = 100.0 / avgYield // Inverse relationship between yields and prices
        }
    }
    
    /**
     * Calculate market volatility
     */
    private fun calculateMarketVolatility() {
        if (equities.isEmpty()) return
        
        // Calculate standard deviation of returns
        val returns = mutableListOf<Double>()
        equities.values.forEach { equity ->
            if (equity.priceHistory.size >= 2) {
                val return1 = ln(equity.currentPrice / equity.priceHistory.last())
                returns.add(return1)
            }
        }
        
        if (returns.isNotEmpty()) {
            val avgReturn = returns.average()
            val variance = returns.map { (it - avgReturn).pow(2) }.average()
            marketVolatility = sqrt(variance * 252) // Annualized volatility
            
            volatilityHistory.add(marketVolatility)
            if (volatilityHistory.size > 100) {
                volatilityHistory.removeAt(0)
            }
        }
    }
    
    /**
     * Get current market conditions
     */
    fun getMarketConditions(): MarketConditions {
        return MarketConditions(
            baseInterestRate = baseInterestRate,
            riskFreeRate = riskFreeRate,
            marketIndex = marketIndex,
            bondIndex = bondIndex,
            marketVolatility = marketVolatility,
            totalEquityMarketCap = equities.values.sumOf { it.marketCap },
            totalBondsOutstanding = bonds.values.sumOf { it.principal },
            totalLoansOutstanding = loans.values
                .filter { it.status == LoanStatus.ACTIVE }
                .sumOf { it.remainingPrincipal }
        )
    }
    
    override fun executeTrade(
        buyOrder: Order.BuyOrder,
        sellOrder: Order.SellOrder,
        price: Double,
        quantity: Double
    ) {
        // In capital markets, we're trading financial instruments
        // This would update ownership records
    }
    
    override fun processEvent(event: MarketEvent) {
        when (event) {
            is CapitalMarketEvent -> {
                when (event) {
                    is CapitalMarketEvent.InterestRateChange -> {
                        baseInterestRate = event.newRate
                        riskFreeRate = event.newRate * 0.4 // Risk-free is 40% of base
                    }
                    is CapitalMarketEvent.MarketCrash -> {
                        marketIndex *= (1 - event.severity)
                        marketVolatility *= (1 + event.severity)
                        equities.values.forEach { 
                            it.currentPrice *= (1 - event.severity * it.beta)
                        }
                    }
                    is CapitalMarketEvent.CreditCrunch -> {
                        // Increase interest rates and reduce lending
                        baseInterestRate *= 1.5
                        creditRatings.values.forEach { rating ->
                            rating.riskPremium *= 1.3
                        }
                    }
                    is CapitalMarketEvent.QuantitativeEasing -> {
                        // Lower interest rates and increase liquidity
                        baseInterestRate *= 0.7
                        riskFreeRate *= 0.5
                    }
                }
            }
            else -> {
                // Handle other event types
            }
        }
    }
}

/**
 * Represents a bond instrument
 */
data class Bond(
    val id: String,
    val issuerId: String,
    val principal: Double,
    val couponRate: Double,
    val maturityDate: Long,
    val rating: CreditRating,
    var currentPrice: Double
)

/**
 * Represents an equity instrument
 */
data class Equity(
    val id: String,
    val companyId: String,
    val totalShares: Long,
    var currentPrice: Double,
    val sector: String,
    val beta: Double, // Systematic risk measure
    var dividendYield: Double,
    var marketCap: Double,
    val priceHistory: MutableList<Double> = mutableListOf()
)

/**
 * Represents a loan agreement
 */
data class Loan(
    val id: String,
    val lenderId: String,
    val borrowerId: String,
    val principal: Double,
    val interestRate: Double,
    var remainingPrincipal: Double,
    val monthlyPayment: Double,
    val termMonths: Int,
    var remainingMonths: Int,
    val collateral: String?,
    var status: LoanStatus
)

/**
 * Loan status
 */
enum class LoanStatus {
    ACTIVE,
    PAID_OFF,
    DEFAULTED,
    RESTRUCTURED
}

/**
 * Credit rating with associated risk
 */
data class CreditRating(
    val rating: String,
    var riskPremium: Double,
    var defaultProbability: Double
) {
    companion object {
        val AAA = CreditRating("AAA", 0.005, 0.0001)
        val AA = CreditRating("AA", 0.01, 0.0003)
        val A = CreditRating("A", 0.015, 0.0008)
        val BBB = CreditRating("BBB", 0.025, 0.002)
        val BB = CreditRating("BB", 0.05, 0.01)
        val B = CreditRating("B", 0.08, 0.04)
        val CCC = CreditRating("CCC", 0.15, 0.15)
    }
}

/**
 * Current market conditions
 */
data class MarketConditions(
    val baseInterestRate: Double,
    val riskFreeRate: Double,
    val marketIndex: Double,
    val bondIndex: Double,
    val marketVolatility: Double,
    val totalEquityMarketCap: Double,
    val totalBondsOutstanding: Double,
    val totalLoansOutstanding: Double
)

/**
 * Capital market specific events
 */
sealed class CapitalMarketEvent : MarketEvent() {
    data class InterestRateChange(
        override val timestamp: Long,
        override val impact: MarketImpact,
        val newRate: Double
    ) : CapitalMarketEvent()
    
    data class MarketCrash(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.CRITICAL,
        val severity: Double // 0.0 to 1.0
    ) : CapitalMarketEvent()
    
    data class CreditCrunch(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH
    ) : CapitalMarketEvent()
    
    data class QuantitativeEasing(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH,
        val amount: Double
    ) : CapitalMarketEvent()
}