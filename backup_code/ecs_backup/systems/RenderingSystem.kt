package com.flexport.ecs.systems

import com.flexport.ecs.components.PositionComponent
import com.flexport.ecs.components.RenderComponent
import com.flexport.ecs.core.ComponentType
import com.flexport.ecs.core.Entity
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.core.System

/**
 * Interface for the actual rendering implementation
 */
interface Renderer {
    fun beginFrame()
    fun drawSprite(
        textureId: String,
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        rotation: Float,
        tint: Int
    )
    fun endFrame()
}

/**
 * System responsible for rendering entities with visual components
 */
class RenderingSystem(
    entityManager: EntityManager,
    private val renderer: Renderer
) : System(entityManager) {
    
    private data class RenderableEntity(
        val entity: Entity,
        val position: PositionComponent,
        val render: RenderComponent
    )
    
    override fun getRequiredComponents(): Array<ComponentType> {
        return arrayOf(PositionComponent::class, RenderComponent::class)
    }
    
    override suspend fun update(deltaTime: Float) {
        val entities = entityManager.getEntitiesWithComponents(
            PositionComponent::class,
            RenderComponent::class
        )
        
        // Collect renderable entities
        val renderables = entities.mapNotNull { entity ->
            val position = entityManager.getComponent(entity, PositionComponent::class)
            val render = entityManager.getComponent(entity, RenderComponent::class)
            
            if (position != null && render != null && render.isVisible) {
                RenderableEntity(entity, position, render)
            } else null
        }
        
        // Sort by layer for proper rendering order
        val sortedRenderables = renderables.sortedBy { it.render.layer }
        
        // Render all entities
        renderer.beginFrame()
        
        sortedRenderables.forEach { renderable ->
            renderer.drawSprite(
                textureId = renderable.render.textureId,
                x = renderable.position.x - renderable.render.getRenderedWidth() / 2,
                y = renderable.position.y - renderable.render.getRenderedHeight() / 2,
                width = renderable.render.getRenderedWidth(),
                height = renderable.render.getRenderedHeight(),
                rotation = renderable.position.rotation,
                tint = renderable.render.tint
            )
        }
        
        renderer.endFrame()
    }
}