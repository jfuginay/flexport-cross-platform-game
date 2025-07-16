package com.flexport.ai.integration

import com.flexport.ai.models.*
import com.flexport.economics.EconomicEngine
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.delay

/**
 * Test class for AI Singularity system integration
 */
object AISingularityTest {
    
    /**
     * Test basic AI system initialization
     */
    fun testBasicInitialization() {
        println("=== Testing AI Singularity System Initialization ===")
        
        runBlocking {
            // Create dependencies
            val economicEngine = EconomicEngine()
            
            // Create integration bridge (entityManager is optional)
            val integrationBridge = GameIntegrationBridge(
                economicEngine = economicEngine,
                entityManager = null
            )
            
            // Initialize the system
            println("Initializing AI system...")
            integrationBridge.initialize()
            
            // Wait for initialization
            delay(1000)
            
            // Get system status
            val status = integrationBridge.getSystemStatus()
            if (status != null) {
                println("✓ AI System initialized successfully")
                println("  - Current Phase: ${status.progression.currentPhase.displayName}")
                println("  - Overall Progress: ${(status.progression.overallProgress * 100).toInt()}%")
                println("  - AI Competitors: ${status.competitors.size}")
                println("  - Total Pressure: ${status.pressure.totalPressure}")
                println("  - Economic Impact: ${status.economicImpact.overallEconomicShift}")
                
                // Test player actions
                println("\nTesting player actions...")
                integrationBridge.recordPlayerAction(
                    PlayerActionType.RESIST_AI,
                    ActionEffectiveness.MEDIUM
                )
                
                delay(500)
                
                integrationBridge.recordPlayerAction(
                    PlayerActionType.INNOVATE_DEFENSE,
                    ActionEffectiveness.HIGH
                )
                
                println("✓ Player actions recorded successfully")
                
                // Test phase advancement
                println("\nTesting phase advancement...")
                integrationBridge.forcePhaseAdvancement()
                
                delay(1000)
                
                val updatedStatus = integrationBridge.getSystemStatus()
                if (updatedStatus != null) {
                    println("✓ Phase advanced to: ${updatedStatus.progression.currentPhase.displayName}")
                }
                
                // Test entity creation
                println("\nTesting entity integration...")
                integrationBridge.updateAIEntities()
                
                // Since we don't have entityManager, we can't check entities directly
                println("✓ Entity update completed")
                
                // Clean up
                println("\nShutting down system...")
                integrationBridge.shutdown()
                println("✓ System shut down successfully")
                
            } else {
                println("✗ Failed to initialize AI system")
            }
        }
        
        println("\n=== Test Complete ===")
    }
    
    /**
     * Test AI competitor evolution
     */
    fun testAICompetitorEvolution() {
        println("=== Testing AI Competitor Evolution ===")
        
        runBlocking {
            val economicEngine = EconomicEngine()
            val integrationBridge = GameIntegrationBridge(economicEngine)
            
            integrationBridge.initialize()
            delay(1000)
            
            val initialStatus = integrationBridge.getSystemStatus()
            val initialCompetitors = initialStatus?.competitors ?: emptyList()
            
            println("Initial competitors:")
            initialCompetitors.forEach { competitor ->
                println("  - ${competitor.name}: Power=${competitor.getTotalPower()}, Threat=${competitor.getThreatLevel()}")
            }
            
            // Force multiple phase advancements
            repeat(3) {
                println("\nAdvancing phase ${it + 1}...")
                integrationBridge.forcePhaseAdvancement()
                delay(2000)
            }
            
            val evolvedStatus = integrationBridge.getSystemStatus()
            val evolvedCompetitors = evolvedStatus?.competitors ?: emptyList()
            
            println("\nEvolved competitors:")
            evolvedCompetitors.forEach { competitor ->
                println("  - ${competitor.name}: Power=${competitor.getTotalPower()}, Threat=${competitor.getThreatLevel()}")
            }
            
            integrationBridge.shutdown()
        }
        
        println("\n=== Test Complete ===")
    }
    
    /**
     * Test economic integration
     */
    fun testEconomicIntegration() {
        println("=== Testing Economic Integration ===")
        
        runBlocking {
            val economicEngine = EconomicEngine()
            val integrationBridge = GameIntegrationBridge(economicEngine)
            
            integrationBridge.initialize()
            delay(1000)
            
            // Get initial economic state
            val initialEconomic = economicEngine.getMarketSummary()
            println("Initial economic state:")
            println("  - Total Market Value: ${initialEconomic.totalMarketValue}")
            println("  - Inflation Rate: ${initialEconomic.inflationRate * 100}%")
            println("  - Market Volatility: ${initialEconomic.marketVolatility * 100}%")
            
            // Force AI market manipulation
            repeat(5) {
                integrationBridge.forcePhaseAdvancement()
                delay(3000)
            }
            
            // Check economic changes
            val finalEconomic = economicEngine.getMarketSummary()
            println("\nFinal economic state:")
            println("  - Total Market Value: ${finalEconomic.totalMarketValue}")
            println("  - Inflation Rate: ${finalEconomic.inflationRate * 100}%")
            println("  - Market Volatility: ${finalEconomic.marketVolatility * 100}%")
            
            integrationBridge.shutdown()
        }
        
        println("\n=== Test Complete ===")
    }
}