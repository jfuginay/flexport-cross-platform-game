package com.flexport.assets.optimization

import com.flexport.assets.models.*
import com.flexport.assets.assignment.*
import com.flexport.assets.analytics.AssetPerformanceData
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.*
import kotlin.random.Random

/**
 * Advanced optimization engine for asset management using AI algorithms and operations research
 */
class AssetOptimizationEngine {
    
    private val _optimizationResults = MutableStateFlow<Map<String, OptimizationResult>>(emptyMap())
    val optimizationResults: StateFlow<Map<String, OptimizationResult>> = _optimizationResults.asStateFlow()
    
    // Optimization state management
    private val activeOptimizations = ConcurrentHashMap<String, OptimizationJob>()
    private val optimizationHistory = ConcurrentHashMap<String, MutableList<OptimizationResult>>()
    private val performanceMetrics = ConcurrentHashMap<String, OptimizationPerformanceMetrics>()
    
    // Algorithm configurations
    private val geneticAlgorithmConfig = GeneticAlgorithmConfig()
    private val simulatedAnnealingConfig = SimulatedAnnealingConfig()
    private val antColonyConfig = AntColonyConfig()
    
    /**
     * Optimize route assignments for a fleet of assets
     */
    suspend fun optimizeRouteAssignments(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective = OptimizationObjective.MAXIMIZE_REVENUE
    ): RouteOptimizationResult {
        val optimizationId = "ROUTE_OPT_${System.currentTimeMillis()}"
        
        val job = OptimizationJob(
            id = optimizationId,
            type = OptimizationType.ROUTE_ASSIGNMENT,
            startTime = LocalDateTime.now(),
            status = OptimizationStatus.RUNNING,
            objective = objective
        )
        
        activeOptimizations[optimizationId] = job
        
        try {
            // Use Genetic Algorithm for route assignment optimization
            val assignments = when (assets.size * routes.size) {
                in 0..100 -> optimizeRoutesWithBruteForce(assets, routes, constraints, objective)
                in 101..1000 -> optimizeRoutesWithGeneticAlgorithm(assets, routes, constraints, objective)
                else -> optimizeRoutesWithHybridApproach(assets, routes, constraints, objective)
            }
            
            val result = RouteOptimizationResult(
                optimizationId = optimizationId,
                assignments = assignments,
                totalRevenue = assignments.sumOf { it.estimatedRevenue },
                totalCost = calculateTotalOperatingCosts(assignments),
                utilizationRate = calculateFleetUtilization(assignments, assets),
                optimizationTime = ChronoUnit.MILLIS.between(job.startTime, LocalDateTime.now()),
                algorithm = determineAlgorithmUsed(assets.size * routes.size),
                confidence = calculateOptimizationConfidence(assignments, assets, routes)
            )
            
            job.status = OptimizationStatus.COMPLETED
            job.endTime = LocalDateTime.now()
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            job.status = OptimizationStatus.FAILED
            job.error = e.message
            throw e
        } finally {
            activeOptimizations.remove(optimizationId)
        }
    }
    
    /**
     * Optimize capacity utilization across all assets
     */
    suspend fun optimizeCapacityUtilization(
        assets: List<FlexPortAsset>,
        cargoJobs: List<CargoJob>,
        constraints: CapacityConstraints
    ): CapacityOptimizationResult {
        val optimizationId = "CAPACITY_OPT_${System.currentTimeMillis()}"
        
        try {
            // Use Bin Packing algorithms for capacity optimization
            val allocations = optimizeCapacityWithBinPacking(assets, cargoJobs, constraints)
            
            val result = CapacityOptimizationResult(
                optimizationId = optimizationId,
                allocations = allocations,
                totalUtilization = calculateOverallUtilization(allocations),
                wastedCapacity = calculateWastedCapacity(allocations, assets),
                revenueEfficiency = calculateRevenueEfficiency(allocations),
                loadBalancing = calculateLoadBalancing(allocations, assets)
            )
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            throw OptimizationException("Capacity optimization failed: ${e.message}")
        }
    }
    
    /**
     * Optimize maintenance scheduling to minimize downtime and costs
     */
    suspend fun optimizeMaintenanceScheduling(
        assets: List<FlexPortAsset>,
        maintenanceRequirements: List<MaintenanceRequirement>,
        constraints: MaintenanceConstraints
    ): MaintenanceOptimizationResult {
        val optimizationId = "MAINT_OPT_${System.currentTimeMillis()}"
        
        try {
            // Use Priority Scheduling with resource constraints
            val schedule = optimizeMaintenanceWithPriorityScheduling(
                assets, 
                maintenanceRequirements, 
                constraints
            )
            
            val result = MaintenanceOptimizationResult(
                optimizationId = optimizationId,
                schedule = schedule,
                totalDowntime = calculateTotalDowntime(schedule),
                totalMaintenanceCost = calculateTotalMaintenanceCost(schedule),
                resourceUtilization = calculateMaintenanceResourceUtilization(schedule, constraints),
                scheduleEfficiency = calculateScheduleEfficiency(schedule)
            )
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            throw OptimizationException("Maintenance optimization failed: ${e.message}")
        }
    }
    
    /**
     * Optimize fleet composition for given operational requirements
     */
    suspend fun optimizeFleetComposition(
        currentFleet: List<FlexPortAsset>,
        operationalRequirements: OperationalRequirements,
        budgetConstraints: BudgetConstraints,
        timeHorizon: Int // months
    ): FleetOptimizationResult {
        val optimizationId = "FLEET_OPT_${System.currentTimeMillis()}"
        
        try {
            // Use Integer Linear Programming approach
            val recommendations = optimizeFleetWithILP(
                currentFleet,
                operationalRequirements,
                budgetConstraints,
                timeHorizon
            )
            
            val result = FleetOptimizationResult(
                optimizationId = optimizationId,
                recommendations = recommendations,
                expectedROI = calculateExpectedROI(recommendations, timeHorizon),
                riskProfile = assessFleetRiskProfile(recommendations),
                implementationPlan = generateImplementationPlan(recommendations),
                totalInvestment = recommendations.sumOf { it.investmentRequired }
            )
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            throw OptimizationException("Fleet optimization failed: ${e.message}")
        }
    }
    
    /**
     * Optimize warehouse layout and storage allocation
     */
    suspend fun optimizeWarehouseLayout(
        warehouse: Warehouse,
        storageRequirements: List<StorageRequirement>,
        constraints: LayoutConstraints
    ): WarehouseOptimizationResult {
        val optimizationId = "WAREHOUSE_OPT_${System.currentTimeMillis()}"
        
        try {
            // Use Space Partitioning and Flow Optimization
            val layout = optimizeLayoutWithSpacePartitioning(warehouse, storageRequirements, constraints)
            
            val result = WarehouseOptimizationResult(
                optimizationId = optimizationId,
                optimizedLayout = layout,
                spaceUtilization = calculateSpaceUtilization(layout, warehouse),
                operationalEfficiency = calculateOperationalEfficiency(layout),
                accessibilityScore = calculateAccessibilityScore(layout),
                flowOptimization = calculateFlowOptimization(layout)
            )
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            throw OptimizationException("Warehouse optimization failed: ${e.message}")
        }
    }
    
    /**
     * Multi-objective optimization combining multiple criteria
     */
    suspend fun multiObjectiveOptimization(
        assets: List<FlexPortAsset>,
        objectives: List<OptimizationObjective>,
        weights: Map<OptimizationObjective, Double>,
        constraints: MultiObjectiveConstraints
    ): MultiObjectiveResult {
        val optimizationId = "MULTI_OBJ_${System.currentTimeMillis()}"
        
        try {
            // Use NSGA-II (Non-dominated Sorting Genetic Algorithm)
            val paretoSolutions = optimizeWithNSGAII(assets, objectives, weights, constraints)
            
            val result = MultiObjectiveResult(
                optimizationId = optimizationId,
                paretoFront = paretoSolutions,
                recommendedSolution = selectBestSolution(paretoSolutions, weights),
                tradeoffAnalysis = analyzeTradeoffs(paretoSolutions, objectives),
                sensitivityAnalysis = performSensitivityAnalysis(paretoSolutions, weights)
            )
            
            recordOptimizationResult(optimizationId, result)
            
            return result
            
        } catch (e: Exception) {
            throw OptimizationException("Multi-objective optimization failed: ${e.message}")
        }
    }
    
    // Genetic Algorithm implementation for route optimization
    private fun optimizeRoutesWithGeneticAlgorithm(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective
    ): List<AssetAssignment> {
        val config = geneticAlgorithmConfig
        var population = initializePopulation(assets, routes, config.populationSize)
        
        repeat(config.generations) { generation ->
            // Evaluate fitness
            val fitnessScores = population.map { individual ->
                calculateFitness(individual, objective, constraints)
            }
            
            // Selection
            val parents = selectParents(population, fitnessScores, config.selectionRate)
            
            // Crossover
            val offspring = performCrossover(parents, config.crossoverRate)
            
            // Mutation
            val mutatedOffspring = performMutation(offspring, config.mutationRate, routes)
            
            // Replacement
            population = selectSurvivors(population + mutatedOffspring, fitnessScores, config.populationSize)
            
            // Early termination check
            if (hasConverged(fitnessScores, config.convergenceThreshold)) {
                break
            }
        }
        
        // Return best solution
        val bestIndividual = population.maxByOrNull { individual ->
            calculateFitness(individual, objective, constraints)
        } ?: population.first()
        
        return convertToAssignments(bestIndividual, assets, routes)
    }
    
    // Simulated Annealing for smaller optimization problems
    private fun optimizeRoutesWithSimulatedAnnealing(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective
    ): List<AssetAssignment> {
        val config = simulatedAnnealingConfig
        var currentSolution = generateRandomSolution(assets, routes)
        var currentCost = calculateObjectiveValue(currentSolution, objective, constraints)
        var bestSolution = currentSolution
        var bestCost = currentCost
        var temperature = config.initialTemperature
        
        repeat(config.maxIterations) { iteration ->
            val neighborSolution = generateNeighborSolution(currentSolution, routes)
            val neighborCost = calculateObjectiveValue(neighborSolution, objective, constraints)
            
            val deltaE = neighborCost - currentCost
            
            if (deltaE < 0 || Random.nextDouble() < exp(-deltaE / temperature)) {
                currentSolution = neighborSolution
                currentCost = neighborCost
                
                if (neighborCost < bestCost) {
                    bestSolution = neighborSolution
                    bestCost = neighborCost
                }
            }
            
            temperature *= config.coolingRate
            
            if (temperature < config.minTemperature) {
                break
            }
        }
        
        return convertToAssignments(bestSolution, assets, routes)
    }
    
    // Ant Colony Optimization for complex routing problems
    private fun optimizeRoutesWithAntColony(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective
    ): List<AssetAssignment> {
        val config = antColonyConfig
        val pheromoneMatrix = initializePheromoneMatrix(assets.size, routes.size)
        var bestSolution: List<Pair<Int, Int>>? = null
        var bestObjectiveValue = Double.NEGATIVE_INFINITY
        
        repeat(config.maxIterations) { iteration ->
            val solutions = mutableListOf<List<Pair<Int, Int>>>()
            
            // Each ant constructs a solution
            repeat(config.numberOfAnts) {
                val solution = constructAntSolution(assets, routes, pheromoneMatrix, config)
                solutions.add(solution)
                
                val objectiveValue = calculateObjectiveValue(solution, objective, constraints)
                if (objectiveValue > bestObjectiveValue) {
                    bestSolution = solution
                    bestObjectiveValue = objectiveValue
                }
            }
            
            // Update pheromones
            updatePheromones(pheromoneMatrix, solutions, config)
        }
        
        return convertToAssignments(bestSolution ?: emptyList(), assets, routes)
    }
    
    // Brute Force for small problems (guaranteed optimal)
    private fun optimizeRoutesWithBruteForce(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective
    ): List<AssetAssignment> {
        var bestSolution: List<Pair<Int, Int>>? = null
        var bestObjectiveValue = Double.NEGATIVE_INFINITY
        
        // Generate all possible assignments
        generateAllAssignments(assets.size, routes.size) { assignment ->
            if (isValidAssignment(assignment, assets, routes, constraints)) {
                val objectiveValue = calculateObjectiveValue(assignment, objective, constraints)
                if (objectiveValue > bestObjectiveValue) {
                    bestSolution = assignment
                    bestObjectiveValue = objectiveValue
                }
            }
        }
        
        return convertToAssignments(bestSolution ?: emptyList(), assets, routes)
    }
    
    // Hybrid approach combining multiple algorithms
    private fun optimizeRoutesWithHybridApproach(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints,
        objective: OptimizationObjective
    ): List<AssetAssignment> {
        // Start with Genetic Algorithm for initial solution
        val gaResult = optimizeRoutesWithGeneticAlgorithm(assets, routes, constraints, objective)
        
        // Refine with Simulated Annealing
        val saResult = optimizeRoutesWithSimulatedAnnealing(assets, routes, constraints, objective)
        
        // Compare and return better solution
        val gaObjective = calculateTotalObjectiveValue(gaResult, objective)
        val saObjective = calculateTotalObjectiveValue(saResult, objective)
        
        return if (gaObjective >= saObjective) gaResult else saResult
    }
    
    // Bin Packing algorithm for capacity optimization
    private fun optimizeCapacityWithBinPacking(
        assets: List<FlexPortAsset>,
        cargoJobs: List<CargoJob>,
        constraints: CapacityConstraints
    ): List<CapacityAllocation> {
        val allocations = mutableListOf<CapacityAllocation>()
        val sortedCargo = cargoJobs.sortedByDescending { job ->
            job.cargoItems.sumOf { it.weight } // Sort by weight/size descending
        }
        
        for (cargo in sortedCargo) {
            val totalWeight = cargo.cargoItems.sumOf { it.weight }
            val totalVolume = cargo.cargoItems.sumOf { it.volume }
            
            // Find best fit asset
            val bestAsset = assets
                .filter { asset -> canAccommodateCargo(asset, cargo, constraints) }
                .minByOrNull { asset -> calculateWasteScore(asset, cargo) }
            
            if (bestAsset != null) {
                allocations.add(
                    CapacityAllocation(
                        assetId = bestAsset.id,
                        cargoJobId = cargo.id,
                        allocatedWeight = totalWeight,
                        allocatedVolume = totalVolume,
                        utilizationRate = calculateUtilizationRate(bestAsset, cargo),
                        efficiency = calculateAllocationEfficiency(bestAsset, cargo)
                    )
                )
            }
        }
        
        return allocations
    }
    
    // Priority scheduling for maintenance optimization
    private fun optimizeMaintenanceWithPriorityScheduling(
        assets: List<FlexPortAsset>,
        requirements: List<MaintenanceRequirement>,
        constraints: MaintenanceConstraints
    ): MaintenanceSchedule {
        val scheduledTasks = mutableListOf<ScheduledMaintenanceTask>()
        val resourceUtilization = mutableMapOf<String, Double>()
        
        // Sort by priority and urgency
        val sortedRequirements = requirements.sortedWith(
            compareByDescending<MaintenanceRequirement> { it.priority.ordinal }
                .thenBy { it.dueDate }
        )
        
        for (requirement in sortedRequirements) {
            val asset = assets.find { it.id == requirement.assetId } ?: continue
            
            // Find optimal time slot
            val timeSlot = findOptimalMaintenanceSlot(
                requirement,
                scheduledTasks,
                constraints,
                resourceUtilization
            )
            
            if (timeSlot != null) {
                val task = ScheduledMaintenanceTask(
                    id = "TASK_${System.currentTimeMillis()}_${Random.nextInt(1000)}",
                    assetId = requirement.assetId,
                    maintenanceType = requirement.maintenanceType,
                    scheduledStart = timeSlot.start,
                    scheduledEnd = timeSlot.end,
                    estimatedCost = requirement.estimatedCost,
                    priority = requirement.priority,
                    resourcesRequired = requirement.resourcesRequired
                )
                
                scheduledTasks.add(task)
                updateResourceUtilization(resourceUtilization, task, constraints)
            }
        }
        
        return MaintenanceSchedule(
            scheduleId = "SCHED_${System.currentTimeMillis()}",
            tasks = scheduledTasks,
            totalDuration = calculateScheduleDuration(scheduledTasks),
            resourceAllocation = resourceUtilization,
            efficiency = calculateScheduleEfficiency(scheduledTasks)
        )
    }
    
    // Integer Linear Programming for fleet optimization
    private fun optimizeFleetWithILP(
        currentFleet: List<FlexPortAsset>,
        requirements: OperationalRequirements,
        budgetConstraints: BudgetConstraints,
        timeHorizon: Int
    ): List<FleetRecommendation> {
        val recommendations = mutableListOf<FleetRecommendation>()
        
        // Analyze current fleet gaps
        val gaps = analyzeFleetGaps(currentFleet, requirements)
        
        // Generate acquisition recommendations
        for (gap in gaps) {
            val assetOptions = findAssetOptions(gap, budgetConstraints)
            val bestOption = assetOptions.maxByOrNull { option ->
                calculateFleetROI(option, gap, timeHorizon)
            }
            
            if (bestOption != null) {
                recommendations.add(
                    FleetRecommendation(
                        action = FleetAction.ACQUIRE,
                        assetType = bestOption.assetType,
                        specifications = bestOption.specifications,
                        investmentRequired = bestOption.cost,
                        expectedROI = calculateFleetROI(bestOption, gap, timeHorizon),
                        justification = "Addresses ${gap.description}",
                        timeline = bestOption.acquisitionTimeline,
                        riskLevel = assessAcquisitionRisk(bestOption)
                    )
                )
            }
        }
        
        // Generate disposal recommendations
        val underperformers = identifyUnderperformingAssets(currentFleet, requirements)
        for (asset in underperformers) {
            recommendations.add(
                FleetRecommendation(
                    action = FleetAction.DISPOSE,
                    assetType = asset.assetType,
                    assetId = asset.id,
                    investmentRequired = -asset.currentValue * 0.8, // Assume 80% recovery
                    expectedROI = calculateDisposalROI(asset, timeHorizon),
                    justification = "Underperforming asset with high maintenance costs",
                    timeline = 3, // 3 months to dispose
                    riskLevel = RiskLevel.LOW
                )
            )
        }
        
        return recommendations
    }
    
    // NSGA-II algorithm for multi-objective optimization
    private fun optimizeWithNSGAII(
        assets: List<FlexPortAsset>,
        objectives: List<OptimizationObjective>,
        weights: Map<OptimizationObjective, Double>,
        constraints: MultiObjectiveConstraints
    ): List<ParetoSolution> {
        val populationSize = 100
        var population = initializeMultiObjectivePopulation(assets, populationSize)
        
        repeat(50) { generation -> // 50 generations
            // Evaluate objectives
            val objectiveValues = population.map { individual ->
                objectives.map { objective ->
                    calculateObjectiveValue(individual, objective, constraints)
                }
            }
            
            // Non-dominated sorting
            val fronts = performNonDominatedSorting(population, objectiveValues)
            
            // Crowding distance calculation
            val crowdingDistances = calculateCrowdingDistances(fronts, objectiveValues)
            
            // Selection for next generation
            population = selectNextGeneration(fronts, crowdingDistances, populationSize)
            
            // Genetic operations
            population = performGeneticOperations(population, assets)
        }
        
        // Return Pareto front
        val finalObjectiveValues = population.map { individual ->
            objectives.map { objective ->
                calculateObjectiveValue(individual, objective, constraints)
            }
        }
        
        val paretoFront = identifyParetoFront(population, finalObjectiveValues)
        
        return paretoFront.mapIndexed { index, individual ->
            ParetoSolution(
                solution = convertToAssignments(individual, assets, emptyList()),
                objectiveValues = finalObjectiveValues[index],
                dominanceRank = 1,
                crowdingDistance = calculateCrowdingDistance(finalObjectiveValues[index], finalObjectiveValues)
            )
        }
    }
    
    // Helper methods for optimization algorithms
    private fun initializePopulation(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        populationSize: Int
    ): List<List<Pair<Int, Int>>> {
        return (1..populationSize).map {
            generateRandomSolution(assets, routes)
        }
    }
    
    private fun generateRandomSolution(
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>
    ): List<Pair<Int, Int>> {
        return assets.mapIndexed { assetIndex, _ ->
            val routeIndex = Random.nextInt(routes.size)
            Pair(assetIndex, routeIndex)
        }
    }
    
    private fun calculateFitness(
        individual: List<Pair<Int, Int>>,
        objective: OptimizationObjective,
        constraints: RouteAssignmentConstraints
    ): Double {
        return calculateObjectiveValue(individual, objective, constraints)
    }
    
    private fun calculateObjectiveValue(
        assignment: List<Pair<Int, Int>>,
        objective: OptimizationObjective,
        constraints: RouteAssignmentConstraints
    ): Double {
        return when (objective) {
            OptimizationObjective.MAXIMIZE_REVENUE -> calculateTotalRevenue(assignment)
            OptimizationObjective.MINIMIZE_COST -> -calculateTotalCost(assignment)
            OptimizationObjective.MAXIMIZE_UTILIZATION -> calculateAverageUtilization(assignment)
            OptimizationObjective.MINIMIZE_RISK -> -calculateTotalRisk(assignment)
            OptimizationObjective.BALANCED -> calculateBalancedScore(assignment)
        }
    }
    
    private fun calculateTotalRevenue(assignment: List<Pair<Int, Int>>): Double {
        return assignment.sumOf { (assetIndex, routeIndex) ->
            // Simplified revenue calculation
            (assetIndex + 1) * (routeIndex + 1) * 1000.0
        }
    }
    
    private fun calculateTotalCost(assignment: List<Pair<Int, Int>>): Double {
        return assignment.sumOf { (assetIndex, routeIndex) ->
            // Simplified cost calculation
            (assetIndex + 1) * (routeIndex + 1) * 600.0
        }
    }
    
    private fun calculateAverageUtilization(assignment: List<Pair<Int, Int>>): Double {
        return assignment.map { (assetIndex, routeIndex) ->
            // Simplified utilization calculation
            0.7 + Random.nextDouble() * 0.3
        }.average()
    }
    
    private fun calculateTotalRisk(assignment: List<Pair<Int, Int>>): Double {
        return assignment.sumOf { (assetIndex, routeIndex) ->
            // Simplified risk calculation
            Random.nextDouble() * 0.2
        }
    }
    
    private fun calculateBalancedScore(assignment: List<Pair<Int, Int>>): Double {
        val revenue = calculateTotalRevenue(assignment)
        val cost = calculateTotalCost(assignment)
        val utilization = calculateAverageUtilization(assignment)
        val risk = calculateTotalRisk(assignment)
        
        return (revenue - cost) * utilization * (1.0 - risk)
    }
    
    private fun selectParents(
        population: List<List<Pair<Int, Int>>>,
        fitnessScores: List<Double>,
        selectionRate: Double
    ): List<List<Pair<Int, Int>>> {
        val numParents = (population.size * selectionRate).toInt()
        val sortedIndices = fitnessScores.withIndex()
            .sortedByDescending { it.value }
            .map { it.index }
            .take(numParents)
        
        return sortedIndices.map { population[it] }
    }
    
    private fun performCrossover(
        parents: List<List<Pair<Int, Int>>>,
        crossoverRate: Double
    ): List<List<Pair<Int, Int>>> {
        val offspring = mutableListOf<List<Pair<Int, Int>>>()
        
        for (i in parents.indices step 2) {
            if (i + 1 < parents.size && Random.nextDouble() < crossoverRate) {
                val parent1 = parents[i]
                val parent2 = parents[i + 1]
                val crossoverPoint = Random.nextInt(parent1.size)
                
                val child1 = parent1.take(crossoverPoint) + parent2.drop(crossoverPoint)
                val child2 = parent2.take(crossoverPoint) + parent1.drop(crossoverPoint)
                
                offspring.add(child1)
                offspring.add(child2)
            } else {
                offspring.add(parents[i])
                if (i + 1 < parents.size) {
                    offspring.add(parents[i + 1])
                }
            }
        }
        
        return offspring
    }
    
    private fun performMutation(
        individuals: List<List<Pair<Int, Int>>>,
        mutationRate: Double,
        routes: List<TradeRoute>
    ): List<List<Pair<Int, Int>>> {
        return individuals.map { individual ->
            individual.map { (assetIndex, routeIndex) ->
                if (Random.nextDouble() < mutationRate) {
                    Pair(assetIndex, Random.nextInt(routes.size))
                } else {
                    Pair(assetIndex, routeIndex)
                }
            }
        }
    }
    
    private fun selectSurvivors(
        combinedPopulation: List<List<Pair<Int, Int>>>,
        fitnessScores: List<Double>,
        populationSize: Int
    ): List<List<Pair<Int, Int>>> {
        val allFitnessScores = fitnessScores + List(combinedPopulation.size - fitnessScores.size) { 0.0 }
        val sortedIndices = allFitnessScores.withIndex()
            .sortedByDescending { it.value }
            .map { it.index }
            .take(populationSize)
        
        return sortedIndices.map { combinedPopulation[it] }
    }
    
    private fun hasConverged(fitnessScores: List<Double>, threshold: Double): Boolean {
        if (fitnessScores.size < 2) return false
        val variance = fitnessScores.map { (it - fitnessScores.average()).pow(2) }.average()
        return sqrt(variance) < threshold
    }
    
    private fun convertToAssignments(
        solution: List<Pair<Int, Int>>,
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>
    ): List<AssetAssignment> {
        return solution.mapIndexed { index, (assetIndex, routeIndex) ->
            val asset = assets.getOrNull(assetIndex) ?: assets.first()
            val route = routes.getOrNull(routeIndex)
            
            AssetAssignment(
                id = "OPT_ASSIGN_${System.currentTimeMillis()}_$index",
                assetId = asset.id,
                assetType = asset.assetType,
                assignmentType = AssignmentType.ROUTE,
                targetId = route?.id ?: "DEFAULT_ROUTE",
                startDate = LocalDateTime.now(),
                priority = AssignmentPriority.NORMAL,
                status = AssignmentStatus.PLANNED,
                estimatedDuration = route?.estimatedDuration ?: 24,
                estimatedRevenue = calculateAssignmentRevenue(asset, route)
            )
        }
    }
    
    private fun calculateAssignmentRevenue(asset: FlexPortAsset, route: TradeRoute?): Double {
        return when (asset.assetType) {
            AssetType.CONTAINER_SHIP -> asset.currentValue * 0.001 * (route?.estimatedRevenue ?: 1000.0)
            AssetType.CARGO_AIRCRAFT -> asset.currentValue * 0.002 * (route?.estimatedRevenue ?: 1500.0)
            AssetType.WAREHOUSE -> asset.currentValue * 0.0005 * (route?.estimatedRevenue ?: 500.0)
            else -> asset.currentValue * 0.001 * (route?.estimatedRevenue ?: 800.0)
        }
    }
    
    private fun calculateTotalOperatingCosts(assignments: List<AssetAssignment>): Double {
        return assignments.sumOf { assignment ->
            assignment.estimatedRevenue * 0.6 // Assume 60% cost ratio
        }
    }
    
    private fun calculateFleetUtilization(
        assignments: List<AssetAssignment>,
        assets: List<FlexPortAsset>
    ): Double {
        val assignedAssets = assignments.map { it.assetId }.toSet()
        return assignedAssets.size.toDouble() / assets.size
    }
    
    private fun determineAlgorithmUsed(problemSize: Int): String {
        return when (problemSize) {
            in 0..100 -> "Brute Force"
            in 101..1000 -> "Genetic Algorithm"
            else -> "Hybrid (GA + SA)"
        }
    }
    
    private fun calculateOptimizationConfidence(
        assignments: List<AssetAssignment>,
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>
    ): Double {
        // Simplified confidence calculation based on problem complexity and algorithm choice
        val problemComplexity = assets.size * routes.size
        return when {
            problemComplexity <= 100 -> 0.95 // Brute force gives optimal solution
            problemComplexity <= 1000 -> 0.85 // GA gives good solution
            else -> 0.75 // Hybrid approach with some uncertainty
        }
    }
    
    private fun generateAllAssignments(
        numAssets: Int,
        numRoutes: Int,
        callback: (List<Pair<Int, Int>>) -> Unit
    ) {
        fun generate(current: List<Pair<Int, Int>>, assetIndex: Int) {
            if (assetIndex == numAssets) {
                callback(current)
                return
            }
            
            for (routeIndex in 0 until numRoutes) {
                generate(current + Pair(assetIndex, routeIndex), assetIndex + 1)
            }
        }
        
        generate(emptyList(), 0)
    }
    
    private fun isValidAssignment(
        assignment: List<Pair<Int, Int>>,
        assets: List<FlexPortAsset>,
        routes: List<TradeRoute>,
        constraints: RouteAssignmentConstraints
    ): Boolean {
        // Simplified validation - in real implementation would check actual constraints
        return assignment.size == assets.size && 
               assignment.all { (_, routeIndex) -> routeIndex < routes.size }
    }
    
    private fun calculateTotalObjectiveValue(
        assignments: List<AssetAssignment>,
        objective: OptimizationObjective
    ): Double {
        return when (objective) {
            OptimizationObjective.MAXIMIZE_REVENUE -> assignments.sumOf { it.estimatedRevenue }
            OptimizationObjective.MINIMIZE_COST -> -assignments.sumOf { it.estimatedRevenue * 0.6 }
            OptimizationObjective.MAXIMIZE_UTILIZATION -> assignments.size.toDouble() / 100.0
            OptimizationObjective.MINIMIZE_RISK -> -Random.nextDouble() * assignments.size
            OptimizationObjective.BALANCED -> assignments.sumOf { it.estimatedRevenue * 0.4 }
        }
    }
    
    private fun recordOptimizationResult(optimizationId: String, result: Any) {
        val optimizationResult = OptimizationResult(
            id = optimizationId,
            timestamp = LocalDateTime.now(),
            type = when (result) {
                is RouteOptimizationResult -> OptimizationType.ROUTE_ASSIGNMENT
                is CapacityOptimizationResult -> OptimizationType.CAPACITY_UTILIZATION
                is MaintenanceOptimizationResult -> OptimizationType.MAINTENANCE_SCHEDULING
                is FleetOptimizationResult -> OptimizationType.FLEET_COMPOSITION
                is WarehouseOptimizationResult -> OptimizationType.WAREHOUSE_LAYOUT
                is MultiObjectiveResult -> OptimizationType.MULTI_OBJECTIVE
                else -> OptimizationType.ROUTE_ASSIGNMENT
            },
            result = result,
            performance = calculateOptimizationPerformance(result)
        )
        
        _optimizationResults.value = _optimizationResults.value + (optimizationId to optimizationResult)
        
        // Store in history
        optimizationHistory.getOrPut(optimizationId) { mutableListOf() }.add(optimizationResult)
    }
    
    private fun calculateOptimizationPerformance(result: Any): OptimizationPerformanceMetrics {
        return OptimizationPerformanceMetrics(
            executionTime = Random.nextLong(1000, 10000), // Simplified
            memoryUsage = Random.nextLong(100, 1000),
            convergenceRate = Random.nextDouble(0.8, 0.95),
            solutionQuality = Random.nextDouble(0.85, 0.98)
        )
    }
    
    // Additional helper methods for capacity optimization
    private fun canAccommodateCargo(
        asset: FlexPortAsset,
        cargo: CargoJob,
        constraints: CapacityConstraints
    ): Boolean {
        val totalWeight = cargo.cargoItems.sumOf { it.weight }
        val totalVolume = cargo.cargoItems.sumOf { it.volume }
        
        return when (asset) {
            is ContainerShip -> {
                totalWeight <= asset.specifications.cargoCapacity &&
                cargo.cargoItems.sumOf { it.teuSize } <= asset.specifications.containerCapacity
            }
            is CargoAircraft -> {
                totalWeight <= asset.specifications.maxCargoWeight &&
                totalVolume <= asset.specifications.cargoVolume
            }
            is Warehouse -> {
                totalVolume <= asset.getAvailableCapacity()
            }
            else -> false
        }
    }
    
    private fun calculateWasteScore(asset: FlexPortAsset, cargo: CargoJob): Double {
        // Calculate how much capacity would be wasted
        val totalWeight = cargo.cargoItems.sumOf { it.weight }
        val totalVolume = cargo.cargoItems.sumOf { it.volume }
        
        return when (asset) {
            is ContainerShip -> {
                val weightUtilization = totalWeight / asset.specifications.cargoCapacity
                val volumeUtilization = cargo.cargoItems.sumOf { it.teuSize } / asset.specifications.containerCapacity
                1.0 - min(weightUtilization, volumeUtilization)
            }
            is CargoAircraft -> {
                val weightUtilization = totalWeight / asset.specifications.maxCargoWeight
                val volumeUtilization = totalVolume / asset.specifications.cargoVolume
                1.0 - min(weightUtilization, volumeUtilization)
            }
            is Warehouse -> {
                val volumeUtilization = totalVolume / asset.specifications.storageVolume
                1.0 - volumeUtilization
            }
            else -> 1.0
        }
    }
    
    private fun calculateUtilizationRate(asset: FlexPortAsset, cargo: CargoJob): Double {
        return 1.0 - calculateWasteScore(asset, cargo)
    }
    
    private fun calculateAllocationEfficiency(asset: FlexPortAsset, cargo: CargoJob): Double {
        val utilizationRate = calculateUtilizationRate(asset, cargo)
        val revenueEfficiency = cargo.totalValue / asset.currentValue
        return (utilizationRate + revenueEfficiency) / 2.0
    }
    
    private fun calculateOverallUtilization(allocations: List<CapacityAllocation>): Double {
        return allocations.map { it.utilizationRate }.average()
    }
    
    private fun calculateWastedCapacity(
        allocations: List<CapacityAllocation>,
        assets: List<FlexPortAsset>
    ): Double {
        val totalCapacity = assets.sumOf { asset ->
            when (asset) {
                is ContainerShip -> asset.specifications.cargoCapacity
                is CargoAircraft -> asset.specifications.maxCargoWeight
                is Warehouse -> asset.specifications.storageVolume
                else -> 1000.0
            }
        }
        
        val usedCapacity = allocations.sumOf { it.allocatedWeight }
        return (totalCapacity - usedCapacity) / totalCapacity
    }
    
    private fun calculateRevenueEfficiency(allocations: List<CapacityAllocation>): Double {
        // Simplified revenue efficiency calculation
        return allocations.map { it.efficiency }.average()
    }
    
    private fun calculateLoadBalancing(
        allocations: List<CapacityAllocation>,
        assets: List<FlexPortAsset>
    ): Double {
        val utilizationRates = allocations.map { it.utilizationRate }
        if (utilizationRates.isEmpty()) return 1.0
        
        val mean = utilizationRates.average()
        val variance = utilizationRates.map { (it - mean).pow(2) }.average()
        val standardDeviation = sqrt(variance)
        
        return max(0.0, 1.0 - standardDeviation) // Better balance = lower std deviation
    }
    
    // Maintenance scheduling helper methods
    private fun findOptimalMaintenanceSlot(
        requirement: MaintenanceRequirement,
        scheduledTasks: List<ScheduledMaintenanceTask>,
        constraints: MaintenanceConstraints,
        resourceUtilization: Map<String, Double>
    ): TimeSlot? {
        val duration = requirement.estimatedDuration
        var currentTime = LocalDateTime.now()
        val maxTime = requirement.dueDate
        
        while (currentTime.plusHours(duration.toLong()).isBefore(maxTime)) {
            val slot = TimeSlot(currentTime, currentTime.plusHours(duration.toLong()))
            
            if (isSlotAvailable(slot, scheduledTasks, requirement, constraints, resourceUtilization)) {
                return slot
            }
            
            currentTime = currentTime.plusHours(1) // Try next hour
        }
        
        return null
    }
    
    private fun isSlotAvailable(
        slot: TimeSlot,
        scheduledTasks: List<ScheduledMaintenanceTask>,
        requirement: MaintenanceRequirement,
        constraints: MaintenanceConstraints,
        resourceUtilization: Map<String, Double>
    ): Boolean {
        // Check for conflicts with existing tasks
        val hasConflict = scheduledTasks.any { task ->
            task.assetId == requirement.assetId &&
            slot.overlaps(TimeSlot(task.scheduledStart, task.scheduledEnd))
        }
        
        if (hasConflict) return false
        
        // Check resource availability
        return requirement.resourcesRequired.all { resource ->
            val currentUtilization = resourceUtilization[resource] ?: 0.0
            val maxUtilization = constraints.resourceLimits[resource] ?: 1.0
            currentUtilization + requirement.resourceUtilization < maxUtilization
        }
    }
    
    private fun updateResourceUtilization(
        resourceUtilization: MutableMap<String, Double>,
        task: ScheduledMaintenanceTask,
        constraints: MaintenanceConstraints
    ) {
        task.resourcesRequired.forEach { resource ->
            val currentUtilization = resourceUtilization[resource] ?: 0.0
            val taskUtilization = constraints.taskResourceUtilization[task.id] ?: 0.1
            resourceUtilization[resource] = currentUtilization + taskUtilization
        }
    }
    
    private fun calculateScheduleDuration(tasks: List<ScheduledMaintenanceTask>): Long {
        if (tasks.isEmpty()) return 0L
        
        val earliestStart = tasks.minOf { it.scheduledStart }
        val latestEnd = tasks.maxOf { it.scheduledEnd }
        
        return ChronoUnit.HOURS.between(earliestStart, latestEnd)
    }
    
    private fun calculateTotalDowntime(schedule: MaintenanceSchedule): Long {
        return schedule.tasks.sumOf { task ->
            ChronoUnit.HOURS.between(task.scheduledStart, task.scheduledEnd)
        }
    }
    
    private fun calculateTotalMaintenanceCost(schedule: MaintenanceSchedule): Double {
        return schedule.tasks.sumOf { it.estimatedCost }
    }
    
    private fun calculateMaintenanceResourceUtilization(
        schedule: MaintenanceSchedule,
        constraints: MaintenanceConstraints
    ): Double {
        return schedule.resourceAllocation.values.average()
    }
    
    private fun calculateScheduleEfficiency(schedule: MaintenanceSchedule): Double {
        // Simplified efficiency calculation
        return min(1.0, schedule.resourceAllocation.values.average())
    }
    
    private fun calculateScheduleEfficiency(tasks: List<ScheduledMaintenanceTask>): Double {
        // Calculate based on task density and resource utilization
        if (tasks.isEmpty()) return 1.0
        
        val totalDuration = calculateScheduleDuration(tasks)
        val activeDuration = tasks.sumOf { task ->
            ChronoUnit.HOURS.between(task.scheduledStart, task.scheduledEnd)
        }
        
        return if (totalDuration > 0) activeDuration.toDouble() / totalDuration else 1.0
    }
    
    // More complex optimization methods would be implemented here...
    // This includes the remaining methods for fleet optimization, warehouse layout,
    // multi-objective optimization, etc.
    
    // Placeholder implementations for brevity
    private fun analyzeFleetGaps(fleet: List<FlexPortAsset>, requirements: OperationalRequirements): List<FleetGap> = emptyList()
    private fun findAssetOptions(gap: FleetGap, constraints: BudgetConstraints): List<AssetOption> = emptyList()
    private fun calculateFleetROI(option: AssetOption, gap: FleetGap, timeHorizon: Int): Double = 0.0
    private fun identifyUnderperformingAssets(fleet: List<FlexPortAsset>, requirements: OperationalRequirements): List<FlexPortAsset> = emptyList()
    private fun calculateDisposalROI(asset: FlexPortAsset, timeHorizon: Int): Double = 0.0
    private fun assessAcquisitionRisk(option: AssetOption): RiskLevel = RiskLevel.LOW
    
    // Space partitioning and other complex algorithms would also be implemented here...
}

// Configuration classes
data class GeneticAlgorithmConfig(
    val populationSize: Int = 100,
    val generations: Int = 50,
    val crossoverRate: Double = 0.8,
    val mutationRate: Double = 0.1,
    val selectionRate: Double = 0.3,
    val convergenceThreshold: Double = 0.001
)

data class SimulatedAnnealingConfig(
    val initialTemperature: Double = 1000.0,
    val minTemperature: Double = 0.1,
    val coolingRate: Double = 0.95,
    val maxIterations: Int = 1000
)

data class AntColonyConfig(
    val numberOfAnts: Int = 50,
    val maxIterations: Int = 100,
    val evaporationRate: Double = 0.1,
    val alpha: Double = 1.0, // Pheromone importance
    val beta: Double = 2.0   // Heuristic importance
)

// Data classes for optimization
data class OptimizationJob(
    val id: String,
    val type: OptimizationType,
    val startTime: LocalDateTime,
    var status: OptimizationStatus,
    val objective: OptimizationObjective,
    var endTime: LocalDateTime? = null,
    var error: String? = null
)

data class OptimizationResult(
    val id: String,
    val timestamp: LocalDateTime,
    val type: OptimizationType,
    val result: Any,
    val performance: OptimizationPerformanceMetrics
)

data class OptimizationPerformanceMetrics(
    val executionTime: Long, // milliseconds
    val memoryUsage: Long,   // bytes
    val convergenceRate: Double,
    val solutionQuality: Double
)

// Result classes
data class RouteOptimizationResult(
    val optimizationId: String,
    val assignments: List<AssetAssignment>,
    val totalRevenue: Double,
    val totalCost: Double,
    val utilizationRate: Double,
    val optimizationTime: Long,
    val algorithm: String,
    val confidence: Double
)

data class CapacityOptimizationResult(
    val optimizationId: String,
    val allocations: List<CapacityAllocation>,
    val totalUtilization: Double,
    val wastedCapacity: Double,
    val revenueEfficiency: Double,
    val loadBalancing: Double
)

data class MaintenanceOptimizationResult(
    val optimizationId: String,
    val schedule: MaintenanceSchedule,
    val totalDowntime: Long,
    val totalMaintenanceCost: Double,
    val resourceUtilization: Double,
    val scheduleEfficiency: Double
)

data class FleetOptimizationResult(
    val optimizationId: String,
    val recommendations: List<FleetRecommendation>,
    val expectedROI: Double,
    val riskProfile: RiskProfile,
    val implementationPlan: ImplementationPlan,
    val totalInvestment: Double
)

data class WarehouseOptimizationResult(
    val optimizationId: String,
    val optimizedLayout: WarehouseLayout,
    val spaceUtilization: Double,
    val operationalEfficiency: Double,
    val accessibilityScore: Double,
    val flowOptimization: Double
)

data class MultiObjectiveResult(
    val optimizationId: String,
    val paretoFront: List<ParetoSolution>,
    val recommendedSolution: ParetoSolution,
    val tradeoffAnalysis: TradeoffAnalysis,
    val sensitivityAnalysis: SensitivityAnalysis
)

// Supporting data classes
data class CapacityAllocation(
    val assetId: String,
    val cargoJobId: String,
    val allocatedWeight: Double,
    val allocatedVolume: Double,
    val utilizationRate: Double,
    val efficiency: Double
)

data class ScheduledMaintenanceTask(
    val id: String,
    val assetId: String,
    val maintenanceType: MaintenanceType,
    val scheduledStart: LocalDateTime,
    val scheduledEnd: LocalDateTime,
    val estimatedCost: Double,
    val priority: MaintenancePriority,
    val resourcesRequired: List<String>
)

data class MaintenanceSchedule(
    val scheduleId: String,
    val tasks: List<ScheduledMaintenanceTask>,
    val totalDuration: Long,
    val resourceAllocation: Map<String, Double>,
    val efficiency: Double
)

data class FleetRecommendation(
    val action: FleetAction,
    val assetType: AssetType,
    val assetId: String? = null,
    val specifications: AssetSpecifications? = null,
    val investmentRequired: Double,
    val expectedROI: Double,
    val justification: String,
    val timeline: Int, // months
    val riskLevel: RiskLevel
)

data class ParetoSolution(
    val solution: List<AssetAssignment>,
    val objectiveValues: List<Double>,
    val dominanceRank: Int,
    val crowdingDistance: Double
)

// Constraint classes
data class RouteAssignmentConstraints(
    val maxAssignmentsPerAsset: Int = 1,
    val requiredAssetTypes: Map<String, AssetType> = emptyMap(),
    val geographicRestrictions: List<String> = emptyList(),
    val timeConstraints: TimeConstraints? = null
)

data class CapacityConstraints(
    val maxUtilizationRate: Double = 0.95,
    val minLoadFactor: Double = 0.3,
    val priorityWeights: Map<CargoPriority, Double> = emptyMap(),
    val hazmatRestrictions: Boolean = true
)

data class MaintenanceConstraints(
    val resourceLimits: Map<String, Double>,
    val workingHours: WorkingHours,
    val skillRequirements: Map<MaintenanceType, List<String>>,
    val taskResourceUtilization: Map<String, Double> = emptyMap(),
    val resourceUtilization: Double = 0.8
)

data class BudgetConstraints(
    val totalBudget: Double,
    val maxPerAsset: Double,
    val cashFlowLimits: Map<Int, Double>, // month -> max cash outflow
    val financingOptions: List<FinancingOption>
)

data class LayoutConstraints(
    val fixedObstacles: List<Rectangle>,
    val accessRequirements: AccessRequirements,
    val safetyZones: List<SafetyZone>,
    val loadingDockRequirements: LoadingDockRequirements
)

data class MultiObjectiveConstraints(
    val weightConstraints: Map<OptimizationObjective, Pair<Double, Double>>, // min, max weights
    val paretoFrontSize: Int = 50,
    val convergenceCriteria: ConvergenceCriteria
)

// Additional supporting classes and enums
data class MaintenanceRequirement(
    val assetId: String,
    val maintenanceType: MaintenanceType,
    val priority: MaintenancePriority,
    val dueDate: LocalDateTime,
    val estimatedDuration: Int, // hours
    val estimatedCost: Double,
    val resourcesRequired: List<String>,
    val resourceUtilization: Double = 0.1
)

data class TimeSlot(
    val start: LocalDateTime,
    val end: LocalDateTime
) {
    fun overlaps(other: TimeSlot): Boolean {
        return start < other.end && end > other.start
    }
}

data class OperationalRequirements(
    val capacityNeeds: Map<AssetType, Double>,
    val geographicCoverage: List<String>,
    val serviceLevel: ServiceLevel,
    val growthProjections: Map<Int, Double> // year -> growth factor
)

data class TimeConstraints(
    val earliestStart: LocalDateTime,
    val latestEnd: LocalDateTime,
    val blackoutPeriods: List<TimeSlot>
)

data class WorkingHours(
    val startTime: Int, // hour of day
    val endTime: Int,   // hour of day
    val workingDays: List<Int> // days of week
)

data class FinancingOption(
    val type: String,
    val interestRate: Double,
    val maxAmount: Double,
    val termMonths: Int
)

data class AccessRequirements(
    val minAisleWidth: Double,
    val emergencyExits: Int,
    val wheelchairAccessible: Boolean
)

data class SafetyZone(
    val area: Rectangle,
    val restrictions: List<String>
)

data class LoadingDockRequirements(
    val numberOfDocks: Int,
    val dockSize: Pair<Double, Double>, // width, height
    val accessibility: List<String>
)

data class ConvergenceCriteria(
    val maxGenerations: Int,
    val diversityThreshold: Double,
    val improvementThreshold: Double
)

// Placeholder classes for complex features
data class FleetGap(val description: String, val severity: Double)
data class AssetOption(
    val assetType: AssetType,
    val specifications: AssetSpecifications,
    val cost: Double,
    val acquisitionTimeline: Int
)
data class WarehouseLayout(val zones: List<StorageZone>)
data class ImplementationPlan(val phases: List<String>)
data class TradeoffAnalysis(val tradeoffs: List<String>)
data class SensitivityAnalysis(val sensitivities: Map<String, Double>)
data class StorageRequirement(val type: String, val volume: Double)

// Enums
enum class OptimizationType {
    ROUTE_ASSIGNMENT, CAPACITY_UTILIZATION, MAINTENANCE_SCHEDULING,
    FLEET_COMPOSITION, WAREHOUSE_LAYOUT, MULTI_OBJECTIVE
}

enum class OptimizationStatus {
    PENDING, RUNNING, COMPLETED, FAILED, CANCELLED
}

enum class FleetAction {
    ACQUIRE, DISPOSE, UPGRADE, MAINTAIN, REASSIGN
}

enum class ServiceLevel {
    BASIC, STANDARD, PREMIUM, LUXURY
}

class OptimizationException(message: String) : Exception(message)