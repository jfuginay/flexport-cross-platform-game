package com.flexport.economics.markets

import com.flexport.economics.models.Employee
import com.flexport.economics.models.EmployeeType
import com.flexport.economics.models.SkillLevel
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.pow

/**
 * Market for labor including engineers, sales, and operations staff.
 * Handles wages, employment contracts, and skill levels.
 */
class LaborMarket : AbstractMarket() {
    
    // Available workers by type
    private val availableWorkers = ConcurrentHashMap<String, Worker>()
    
    // Employment contracts
    private val employmentContracts = ConcurrentHashMap<String, EmploymentContract>()
    
    // Wage indices by employee type
    private val wageIndices = mutableMapOf(
        EmployeeType.ENGINEER to 100000.0, // Base annual salary
        EmployeeType.SALES to 60000.0,
        EmployeeType.OPERATIONS to 50000.0,
        EmployeeType.PILOT to 120000.0,
        EmployeeType.SHIP_CAPTAIN to 100000.0,
        EmployeeType.DOCK_WORKER to 40000.0,
        EmployeeType.WAREHOUSE_MANAGER to 70000.0,
        EmployeeType.LOGISTICS_COORDINATOR to 65000.0,
        EmployeeType.CUSTOMER_SERVICE to 45000.0,
        EmployeeType.EXECUTIVE to 200000.0
    )
    
    // Labor market statistics
    private val unemploymentRates = mutableMapOf<EmployeeType, Double>()
    private val averageExperience = mutableMapOf<EmployeeType, Double>()
    private val skillShortages = mutableMapOf<EmployeeType, Double>()
    
    // Training programs
    private val trainingPrograms = ConcurrentHashMap<String, TrainingProgram>()
    
    // Labor unions and their influence
    private val unionStrength = mutableMapOf<EmployeeType, Double>()
    
    init {
        // Initialize unemployment rates
        EmployeeType.values().forEach { type ->
            unemploymentRates[type] = 0.05 // 5% baseline
            averageExperience[type] = 5.0 // 5 years average
            skillShortages[type] = 0.0
            unionStrength[type] = when (type) {
                EmployeeType.DOCK_WORKER -> 0.8
                EmployeeType.PILOT -> 0.7
                EmployeeType.SHIP_CAPTAIN -> 0.6
                else -> 0.3
            }
        }
        
        // Generate initial worker pool
        generateInitialWorkerPool()
    }
    
    /**
     * Generate initial pool of available workers
     */
    private fun generateInitialWorkerPool() {
        val workerCounts = mapOf(
            EmployeeType.ENGINEER to 100,
            EmployeeType.SALES to 150,
            EmployeeType.OPERATIONS to 200,
            EmployeeType.PILOT to 50,
            EmployeeType.SHIP_CAPTAIN to 40,
            EmployeeType.DOCK_WORKER to 300,
            EmployeeType.WAREHOUSE_MANAGER to 80,
            EmployeeType.LOGISTICS_COORDINATOR to 120,
            EmployeeType.CUSTOMER_SERVICE to 180,
            EmployeeType.EXECUTIVE to 20
        )
        
        workerCounts.forEach { (type, count) ->
            repeat(count) {
                val worker = generateWorker(type)
                availableWorkers[worker.id] = worker
            }
        }
    }
    
    /**
     * Generate a random worker with appropriate characteristics
     */
    private fun generateWorker(type: EmployeeType): Worker {
        val id = "WORKER-${System.currentTimeMillis()}-${Math.random().toString().substring(2, 8)}"
        
        // Generate experience based on normal distribution
        val baseExperience = when (type) {
            EmployeeType.EXECUTIVE -> 15.0
            EmployeeType.PILOT, EmployeeType.SHIP_CAPTAIN -> 10.0
            EmployeeType.ENGINEER -> 5.0
            else -> 3.0
        }
        val experience = (baseExperience + (Math.random() - 0.5) * 10).coerceIn(0.0, 40.0)
        
        // Skill level based on experience
        val skillLevel = when {
            experience < 2 -> SkillLevel.JUNIOR
            experience < 5 -> SkillLevel.MID
            experience < 10 -> SkillLevel.SENIOR
            else -> SkillLevel.EXPERT
        }
        
        // Productivity factor
        val productivity = 0.8 + Math.random() * 0.4 // 0.8 to 1.2
        
        // Expected salary based on type, skill, and market conditions
        val baseSalary = wageIndices[type] ?: 50000.0
        val expectedSalary = baseSalary * 
            (1 + experience * 0.03) * // 3% per year experience
            skillLevel.multiplier *
            productivity
        
        return Worker(
            id = id,
            name = generateRandomName(),
            type = type,
            skillLevel = skillLevel,
            experience = experience,
            productivity = productivity,
            expectedSalary = expectedSalary,
            available = true,
            specializations = generateSpecializations(type),
            certifications = generateCertifications(type)
        )
    }
    
    /**
     * Post a job opening
     */
    fun postJobOpening(
        employerId: String,
        type: EmployeeType,
        requiredSkillLevel: SkillLevel,
        offeredSalary: Double,
        benefits: Benefits,
        jobDescription: String
    ): JobPosting {
        val jobId = "JOB-${System.currentTimeMillis()}"
        
        val posting = JobPosting(
            id = jobId,
            employerId = employerId,
            type = type,
            requiredSkillLevel = requiredSkillLevel,
            offeredSalary = offeredSalary,
            benefits = benefits,
            description = jobDescription,
            postedDate = System.currentTimeMillis(),
            applications = mutableListOf()
        )
        
        // Match with available workers
        matchWorkersToJob(posting)
        
        // Create buy order in the market
        val demandQuantity = 1.0
        addBuyOrder(demandQuantity, offeredSalary, employerId)
        
        return posting
    }
    
    /**
     * Match available workers to job posting
     */
    private fun matchWorkersToJob(posting: JobPosting) {
        availableWorkers.values
            .filter { worker ->
                worker.available &&
                worker.type == posting.type &&
                worker.skillLevel.ordinal >= posting.requiredSkillLevel.ordinal &&
                worker.expectedSalary <= posting.offeredSalary * 1.2 // Within 20% of offered
            }
            .forEach { worker ->
                val application = JobApplication(
                    workerId = worker.id,
                    jobId = posting.id,
                    applicationDate = System.currentTimeMillis(),
                    status = ApplicationStatus.PENDING
                )
                posting.applications.add(application)
            }
    }
    
    /**
     * Hire a worker
     */
    fun hireWorker(
        employerId: String,
        workerId: String,
        agreedSalary: Double,
        contractType: ContractType,
        contractDuration: Int? = null // months, if fixed-term
    ): EmploymentContract {
        val worker = availableWorkers[workerId] ?: throw IllegalArgumentException("Worker not found")
        
        val contractId = "CONTRACT-${System.currentTimeMillis()}"
        
        val contract = EmploymentContract(
            id = contractId,
            employerId = employerId,
            workerId = workerId,
            employeeType = worker.type,
            salary = agreedSalary,
            contractType = contractType,
            startDate = System.currentTimeMillis(),
            endDate = if (contractType == ContractType.FIXED_TERM && contractDuration != null) {
                System.currentTimeMillis() + contractDuration * 30L * 24 * 60 * 60 * 1000
            } else null,
            status = ContractStatus.ACTIVE,
            performanceRating = 3.0 // Start with average rating
        )
        
        // Update worker availability
        worker.available = false
        employmentContracts[contractId] = contract
        
        // Remove from available pool
        availableWorkers.remove(workerId)
        
        return contract
    }
    
    /**
     * Terminate employment contract
     */
    fun terminateContract(
        contractId: String,
        reason: TerminationReason,
        severanceMultiplier: Double = 1.0
    ) {
        val contract = employmentContracts[contractId] ?: return
        
        contract.status = ContractStatus.TERMINATED
        contract.terminationReason = reason
        contract.terminationDate = System.currentTimeMillis()
        
        // Calculate severance if applicable
        if (reason != TerminationReason.GROSS_MISCONDUCT) {
            val monthsWorked = ((System.currentTimeMillis() - contract.startDate) / 
                (30.0 * 24 * 60 * 60 * 1000)).toInt()
            contract.severancePayment = contract.salary / 12 * monthsWorked * 0.25 * severanceMultiplier
        }
        
        // Return worker to available pool
        val worker = getWorkerById(contract.workerId)
        if (worker != null) {
            worker.available = true
            availableWorkers[worker.id] = worker
        }
    }
    
    /**
     * Create a training program
     */
    fun createTrainingProgram(
        organizerId: String,
        targetType: EmployeeType,
        fromLevel: SkillLevel,
        toLevel: SkillLevel,
        durationWeeks: Int,
        costPerParticipant: Double
    ): TrainingProgram {
        val programId = "TRAINING-${System.currentTimeMillis()}"
        
        val program = TrainingProgram(
            id = programId,
            organizerId = organizerId,
            targetType = targetType,
            fromLevel = fromLevel,
            toLevel = toLevel,
            durationWeeks = durationWeeks,
            costPerParticipant = costPerParticipant,
            participants = mutableListOf(),
            startDate = System.currentTimeMillis(),
            completionRate = 0.8 // 80% expected completion
        )
        
        trainingPrograms[programId] = program
        
        return program
    }
    
    override fun update(deltaTime: Float) {
        super.update(deltaTime)
        
        // Update wage indices based on supply and demand
        updateWageIndices()
        
        // Process training programs
        processTrainingPrograms(deltaTime)
        
        // Update unemployment rates
        updateUnemploymentRates()
        
        // Generate new workers entering the market
        generateNewWorkers(deltaTime)
        
        // Process retirement
        processRetirements(deltaTime)
        
        // Update union negotiations
        processUnionNegotiations(deltaTime)
    }
    
    /**
     * Update wage indices based on market conditions
     */
    private fun updateWageIndices() {
        EmployeeType.values().forEach { type ->
            val demand = buyOrders.values
                .filter { it.id.contains(type.name) }
                .sumOf { it.quantity }
            
            val supply = availableWorkers.values
                .filter { it.type == type }
                .size.toDouble()
            
            val supplyDemandRatio = if (demand > 0) supply / demand else 2.0
            
            // Adjust wages based on supply/demand
            val wageAdjustment = when {
                supplyDemandRatio < 0.5 -> 1.10 // 10% increase
                supplyDemandRatio < 0.8 -> 1.05 // 5% increase
                supplyDemandRatio > 2.0 -> 0.95 // 5% decrease
                supplyDemandRatio > 1.5 -> 0.98 // 2% decrease
                else -> 1.0
            }
            
            // Apply union influence
            val unionInfluence = 1.0 + unionStrength[type]!! * 0.02 // Up to 2% from unions
            
            wageIndices[type] = wageIndices[type]!! * wageAdjustment * unionInfluence
        }
    }
    
    /**
     * Process ongoing training programs
     */
    private fun processTrainingPrograms(deltaTime: Float) {
        val weeksPassed = deltaTime / (7f * 24 * 60 * 60)
        
        trainingPrograms.values.forEach { program ->
            if (program.participants.isNotEmpty()) {
                val progress = weeksPassed / program.durationWeeks
                
                // Graduate participants who complete the program
                if (progress >= 1.0) {
                    program.participants.forEach { participantId ->
                        if (Math.random() < program.completionRate) {
                            // Upgrade worker skill level
                            val worker = availableWorkers[participantId] ?: getWorkerById(participantId)
                            worker?.let {
                                it.skillLevel = program.toLevel
                                it.experience += program.durationWeeks / 52.0 // Add fractional year
                            }
                        }
                    }
                    program.participants.clear()
                }
            }
        }
    }
    
    /**
     * Update unemployment rates
     */
    private fun updateUnemploymentRates() {
        EmployeeType.values().forEach { type ->
            val totalWorkers = availableWorkers.values.count { it.type == type } +
                employmentContracts.values.count { 
                    it.employeeType == type && it.status == ContractStatus.ACTIVE 
                }
            
            val unemployed = availableWorkers.values.count { it.type == type }
            
            unemploymentRates[type] = if (totalWorkers > 0) {
                unemployed.toDouble() / totalWorkers
            } else 0.0
        }
    }
    
    /**
     * Generate new workers entering the job market
     */
    private fun generateNewWorkers(deltaTime: Float) {
        val monthsPassed = deltaTime / (30f * 24 * 60 * 60)
        
        // New graduates entering market
        if (monthsPassed >= 1.0) {
            EmployeeType.values().forEach { type ->
                val newWorkerCount = when (type) {
                    EmployeeType.ENGINEER -> 5
                    EmployeeType.SALES -> 8
                    EmployeeType.OPERATIONS -> 10
                    else -> 3
                }
                
                repeat(newWorkerCount) {
                    val worker = generateWorker(type)
                    worker.experience = 0.0 // Fresh graduates
                    worker.skillLevel = SkillLevel.JUNIOR
                    availableWorkers[worker.id] = worker
                }
            }
        }
    }
    
    /**
     * Process worker retirements
     */
    private fun processRetirements(deltaTime: Float) {
        val yearsPassed = deltaTime / (365f * 24 * 60 * 60)
        
        // Check for retirement
        employmentContracts.values
            .filter { it.status == ContractStatus.ACTIVE }
            .forEach { contract ->
                val worker = getWorkerById(contract.workerId)
                if (worker != null && worker.experience > 40) {
                    // Retirement probability increases with age
                    val retirementProb = (worker.experience - 40) * 0.1 * yearsPassed
                    if (Math.random() < retirementProb) {
                        terminateContract(contract.id, TerminationReason.RETIREMENT, 2.0)
                    }
                }
            }
    }
    
    /**
     * Process union negotiations
     */
    private fun processUnionNegotiations(deltaTime: Float) {
        val monthsPassed = deltaTime / (30f * 24 * 60 * 60)
        
        // Annual union negotiations
        if (monthsPassed >= 12.0) {
            EmployeeType.values().forEach { type ->
                val unionPower = unionStrength[type]!!
                if (Math.random() < unionPower) {
                    // Union successfully negotiates wage increase
                    val increase = 1.0 + unionPower * 0.05 // Up to 5% increase
                    wageIndices[type] = wageIndices[type]!! * increase
                }
            }
        }
    }
    
    override fun executeTrade(
        buyOrder: Order.BuyOrder,
        sellOrder: Order.SellOrder,
        price: Double,
        quantity: Double
    ) {
        // In labor market, this represents hiring
        // The actual hiring is handled through hireWorker method
    }
    
    override fun processEvent(event: MarketEvent) {
        when (event) {
            is LaborMarketEvent -> {
                when (event) {
                    is LaborMarketEvent.SkillShortage -> {
                        skillShortages[event.employeeType] = event.severity
                        // Increase wages for shortage skills
                        wageIndices[event.employeeType] = 
                            wageIndices[event.employeeType]!! * (1 + event.severity * 0.2)
                    }
                    is LaborMarketEvent.LaborStrike -> {
                        // Reduce available workers
                        val affectedWorkers = availableWorkers.values
                            .filter { it.type == event.employeeType }
                        affectedWorkers.forEach { it.available = false }
                    }
                    is LaborMarketEvent.MinimumWageChange -> {
                        // Adjust all wages that fall below new minimum
                        val minWage = event.newMinimumWage
                        wageIndices.forEach { (type, wage) ->
                            if (wage < minWage) {
                                wageIndices[type] = minWage
                            }
                        }
                    }
                    is LaborMarketEvent.EducationReform -> {
                        // Improve skill levels of new workers
                        // This would affect generateWorker method
                    }
                }
            }
            else -> {
                // Handle other event types
            }
        }
    }
    
    /**
     * Get worker by ID (including employed workers)
     */
    private fun getWorkerById(workerId: String): Worker? {
        // This would be implemented with a proper worker registry
        // For now, return from available workers
        return availableWorkers[workerId]
    }
    
    /**
     * Get labor market statistics
     */
    fun getLaborMarketStats(): LaborMarketStats {
        return LaborMarketStats(
            unemploymentRates = unemploymentRates.toMap(),
            averageWages = wageIndices.toMap(),
            skillShortages = skillShortages.toMap(),
            totalEmployed = employmentContracts.values.count { it.status == ContractStatus.ACTIVE },
            totalUnemployed = availableWorkers.size,
            averageProductivity = availableWorkers.values.map { it.productivity }.average()
        )
    }
    
    /**
     * Generate random worker name
     */
    private fun generateRandomName(): String {
        val firstNames = listOf("John", "Jane", "Michael", "Sarah", "David", "Emma", "Chris", "Lisa")
        val lastNames = listOf("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis")
        return "${firstNames.random()} ${lastNames.random()}"
    }
    
    /**
     * Generate specializations based on employee type
     */
    private fun generateSpecializations(type: EmployeeType): Set<String> {
        return when (type) {
            EmployeeType.ENGINEER -> setOf("Backend", "Frontend", "DevOps").shuffled().take(2).toSet()
            EmployeeType.PILOT -> setOf("Commercial", "Cargo", "International").shuffled().take(1).toSet()
            EmployeeType.SHIP_CAPTAIN -> setOf("Container", "Tanker", "Bulk Carrier").shuffled().take(1).toSet()
            else -> emptySet()
        }
    }
    
    /**
     * Generate certifications based on employee type
     */
    private fun generateCertifications(type: EmployeeType): Set<String> {
        return when (type) {
            EmployeeType.PILOT -> setOf("ATPL", "Type Rating")
            EmployeeType.SHIP_CAPTAIN -> setOf("Master Mariner", "STCW")
            EmployeeType.ENGINEER -> if (Math.random() > 0.5) setOf("AWS Certified") else emptySet()
            else -> emptySet()
        }
    }
}

/**
 * Represents a worker in the labor market
 */
data class Worker(
    val id: String,
    val name: String,
    val type: EmployeeType,
    var skillLevel: SkillLevel,
    var experience: Double, // years
    val productivity: Double, // 0.5 to 1.5
    var expectedSalary: Double,
    var available: Boolean,
    val specializations: Set<String>,
    val certifications: Set<String>
)

/**
 * Job posting
 */
data class JobPosting(
    val id: String,
    val employerId: String,
    val type: EmployeeType,
    val requiredSkillLevel: SkillLevel,
    val offeredSalary: Double,
    val benefits: Benefits,
    val description: String,
    val postedDate: Long,
    val applications: MutableList<JobApplication>
)

/**
 * Job application
 */
data class JobApplication(
    val workerId: String,
    val jobId: String,
    val applicationDate: Long,
    var status: ApplicationStatus
)

/**
 * Application status
 */
enum class ApplicationStatus {
    PENDING,
    REVIEWING,
    INTERVIEWED,
    OFFERED,
    ACCEPTED,
    REJECTED
}

/**
 * Employment contract
 */
data class EmploymentContract(
    val id: String,
    val employerId: String,
    val workerId: String,
    val employeeType: EmployeeType,
    val salary: Double,
    val contractType: ContractType,
    val startDate: Long,
    val endDate: Long?, // null for permanent contracts
    var status: ContractStatus,
    var performanceRating: Double, // 1-5
    var terminationReason: TerminationReason? = null,
    var terminationDate: Long? = null,
    var severancePayment: Double? = null
)

/**
 * Contract types
 */
enum class ContractType {
    PERMANENT,
    FIXED_TERM,
    CONTRACT,
    PART_TIME
}

/**
 * Contract status
 */
enum class ContractStatus {
    ACTIVE,
    TERMINATED,
    EXPIRED,
    SUSPENDED
}

/**
 * Termination reasons
 */
enum class TerminationReason {
    RESIGNATION,
    LAYOFF,
    PERFORMANCE,
    GROSS_MISCONDUCT,
    RETIREMENT,
    CONTRACT_END
}

/**
 * Employee benefits package
 */
data class Benefits(
    val healthInsurance: Boolean,
    val dentalInsurance: Boolean,
    val retirementMatch: Double, // percentage
    val paidTimeOff: Int, // days per year
    val flexibleHours: Boolean,
    val remoteWork: Boolean,
    val stockOptions: Boolean,
    val bonusStructure: BonusStructure?
)

/**
 * Bonus structure
 */
data class BonusStructure(
    val targetBonus: Double, // percentage of salary
    val performanceMultiplier: Double, // 0-2x
    val companyMultiplier: Double // 0-2x based on company performance
)

/**
 * Training program
 */
data class TrainingProgram(
    val id: String,
    val organizerId: String,
    val targetType: EmployeeType,
    val fromLevel: SkillLevel,
    val toLevel: SkillLevel,
    val durationWeeks: Int,
    val costPerParticipant: Double,
    val participants: MutableList<String>,
    val startDate: Long,
    val completionRate: Double
)

/**
 * Labor market statistics
 */
data class LaborMarketStats(
    val unemploymentRates: Map<EmployeeType, Double>,
    val averageWages: Map<EmployeeType, Double>,
    val skillShortages: Map<EmployeeType, Double>,
    val totalEmployed: Int,
    val totalUnemployed: Int,
    val averageProductivity: Double
)

/**
 * Labor market events
 */
sealed class LaborMarketEvent : MarketEvent() {
    data class SkillShortage(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.MEDIUM,
        val employeeType: EmployeeType,
        val severity: Double // 0-1
    ) : LaborMarketEvent()
    
    data class LaborStrike(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.HIGH,
        val employeeType: EmployeeType,
        val duration: Long
    ) : LaborMarketEvent()
    
    data class MinimumWageChange(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.MEDIUM,
        val newMinimumWage: Double
    ) : LaborMarketEvent()
    
    data class EducationReform(
        override val timestamp: Long,
        override val impact: MarketImpact = MarketImpact.LOW,
        val affectedTypes: Set<EmployeeType>
    ) : LaborMarketEvent()
}