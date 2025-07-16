package com.flexport.ai.integration

import com.flexport.ai.models.*
import com.flexport.game.ecs.EntityManager
import com.flexport.game.ecs.Entity
import com.flexport.game.ecs.components.*
import com.flexport.ecs.components.*
import com.flexport.game.ecs.PositionComponent
import com.flexport.game.ecs.components.InteractableComponent
import com.flexport.game.ecs.components.SelectableComponent
import com.flexport.game.models.GeographicalPosition
import kotlin.random.Random

/**
 * Helper class for creating and managing AI entities in the ECS system
 */
class AIEntityIntegration(
    private val entityManager: EntityManager
) {
    
    /**
     * Create an AI competitor entity in the ECS
     */
    fun createAICompetitorEntity(competitor: AICompetitor): Entity {
        val entity = entityManager.createEntity("ai_${competitor.id}")
        
        // Add position component (randomized around world)
        val randomLat = Random.nextDouble(-60.0, 60.0)
        val randomLon = Random.nextDouble(-180.0, 180.0)
        entityManager.addComponent(entity, PositionComponent(
            position = GeographicalPosition(randomLat, randomLon),
            heading = 0.0
        ))
        
        // Add AI-specific component
        entityManager.addComponent(entity, AICompetitorComponent(
            competitorId = competitor.id,
            competitorType = competitor.type,
            threatLevel = competitor.getThreatLevel(),
            marketPresence = competitor.marketPresence.toFloat()
        ))
        
        // Add interactable component for UI selection
        entityManager.addComponent(entity, InteractableComponent(
            interactionType = InteractableComponent.InteractionType.CLICK,
            enabled = true,
            metadata = mapOf("type" to "ai_competitor", "radius" to "50")
        ))
        
        // Add selectable component
        entityManager.addComponent(entity, SelectableComponent(
            selected = false,
            selectionPriority = competitor.getThreatLevel().ordinal,
            selectionGroup = "ai_entities"
        ))
        
        return entity
    }
    
    /**
     * Update AI competitor entity with new state
     */
    fun updateAICompetitorEntity(entity: Entity, competitor: AICompetitor) {
        entityManager.getComponent(entity, AICompetitorComponent::class)?.let { aiComponent ->
            val updated = aiComponent.copy(
                threatLevel = competitor.getThreatLevel(),
                marketPresence = competitor.marketPresence.toFloat(),
                lastUpdateTime = System.currentTimeMillis()
            )
            entityManager.removeComponent(entity, AICompetitorComponent::class)
            entityManager.addComponent(entity, updated)
        }
    }
    
    /**
     * Create AI market disruption effect entity
     */
    fun createMarketDisruptionEntity(disruption: MarketDisruption, position: GeographicalPosition): Entity {
        val entity = entityManager.createEntity("disruption_${System.currentTimeMillis()}")
        
        // Add position
        entityManager.addComponent(entity, PositionComponent(
            position = position,
            heading = 0.0
        ))
        
        // Add visual effect component
        entityManager.addComponent(entity, MarketDisruptionComponent(
            market = disruption.market,
            severity = disruption.severity,
            impact = disruption.impact.toFloat(),
            duration = 30000L, // 30 second visual effect
            startTime = System.currentTimeMillis()
        ))
        
        return entity
    }
    
    /**
     * Create singularity warning entity
     */
    fun createSingularityWarningEntity(phase: SingularityPhase, progress: Double): Entity {
        val entity = entityManager.createEntity("singularity_warning_${phase.name}")
        
        // Global warning, centered on world
        entityManager.addComponent(entity, PositionComponent(
            position = GeographicalPosition(0.0, 0.0),
            heading = 0.0
        ))
        
        // Add warning component
        entityManager.addComponent(entity, SingularityWarningComponent(
            phase = phase,
            progress = progress.toFloat(),
            urgency = when {
                progress > 0.9 -> WarningUrgency.CRITICAL
                progress > 0.7 -> WarningUrgency.HIGH
                progress > 0.5 -> WarningUrgency.MEDIUM
                else -> WarningUrgency.LOW
            }
        ))
        
        return entity
    }
    
    /**
     * Clean up expired effect entities
     */
    fun cleanupExpiredEntities() {
        val currentTime = System.currentTimeMillis()
        
        // Clean up expired market disruptions
        entityManager.getAllEntities().filter { entity ->
            entityManager.hasComponent(entity, MarketDisruptionComponent::class)
        }.forEach { entity ->
            entityManager.getComponent(entity, MarketDisruptionComponent::class)?.let { disruption ->
                if (currentTime - disruption.startTime > disruption.duration) {
                    entityManager.destroyEntity(entity)
                }
            }
        }
    }
}

/**
 * AI Competitor component for ECS
 */
data class AICompetitorComponent(
    val competitorId: String,
    val competitorType: AICompetitorType,
    val threatLevel: ThreatLevel,
    val marketPresence: Float,
    val lastUpdateTime: Long = System.currentTimeMillis()
) : com.flexport.game.ecs.Component

/**
 * Market disruption visual effect component
 */
data class MarketDisruptionComponent(
    val market: String,
    val severity: DisruptionLevel,
    val impact: Float,
    val duration: Long,
    val startTime: Long
) : com.flexport.game.ecs.Component

/**
 * Singularity warning component
 */
data class SingularityWarningComponent(
    val phase: SingularityPhase,
    val progress: Float,
    val urgency: WarningUrgency
) : com.flexport.game.ecs.Component

/**
 * Warning urgency levels
 */
enum class WarningUrgency {
    LOW, MEDIUM, HIGH, CRITICAL
}