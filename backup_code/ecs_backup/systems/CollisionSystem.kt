package com.flexport.ecs.systems

import com.flexport.ecs.components.AssetComponent
import com.flexport.ecs.components.AssetType
import com.flexport.ecs.components.PositionComponent
import com.flexport.ecs.components.RenderComponent
import com.flexport.ecs.core.ComponentType
import com.flexport.ecs.core.Entity
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.core.System
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap

/**
 * Represents a collision between two entities
 */
data class Collision(
    val entityA: Entity,
    val entityB: Entity,
    val distance: Float
)

/**
 * Interface for handling collision events
 */
interface CollisionHandler {
    suspend fun onCollision(entityA: Entity, entityB: Entity, distance: Float)
}

/**
 * System responsible for detecting and handling collisions between entities
 */
class CollisionSystem(
    entityManager: EntityManager,
    private val collisionHandler: CollisionHandler? = null
) : System(entityManager) {
    
    private val spatialGrid = SpatialGrid(cellSize = 100f)
    private val collisionMutex = Mutex()
    private val processedCollisions = ConcurrentHashMap<String, Boolean>()
    
    override fun getRequiredComponents(): Array<ComponentType> {
        return arrayOf(PositionComponent::class, RenderComponent::class)
    }
    
    override suspend fun update(deltaTime: Float) {
        processedCollisions.clear()
        
        val entities = entityManager.getEntitiesWithComponents(
            PositionComponent::class,
            RenderComponent::class
        )
        
        // Update spatial grid
        spatialGrid.clear()
        entities.forEach { entity ->
            val position = entityManager.getComponent(entity, PositionComponent::class)
            if (position != null) {
                spatialGrid.insert(entity, position.x, position.y)
            }
        }
        
        // Check collisions in parallel
        val collisions = mutableListOf<Collision>()
        val collisionMutex = Mutex()
        
        coroutineScope {
            entities.chunked(50).forEach { chunk ->
                launch {
                    val localCollisions = mutableListOf<Collision>()
                    
                    chunk.forEach { entity ->
                        val position = entityManager.getComponent(entity, PositionComponent::class)
                        val render = entityManager.getComponent(entity, RenderComponent::class)
                        
                        if (position != null && render != null) {
                            // Get nearby entities from spatial grid
                            val nearby = spatialGrid.getNearby(
                                position.x,
                                position.y,
                                maxOf(render.getRenderedWidth(), render.getRenderedHeight())
                            )
                            
                            nearby.forEach { other ->
                                if (entity != other && shouldCheckCollision(entity, other)) {
                                    val collision = checkCollision(entity, other)
                                    if (collision != null) {
                                        localCollisions.add(collision)
                                    }
                                }
                            }
                        }
                    }
                    
                    collisionMutex.withLock {
                        collisions.addAll(localCollisions)
                    }
                }
            }
        }
        
        // Handle collisions
        collisions.forEach { collision ->
            collisionHandler?.onCollision(
                collision.entityA,
                collision.entityB,
                collision.distance
            )
        }
    }
    
    private fun shouldCheckCollision(entityA: Entity, entityB: Entity): Boolean {
        val key = if (entityA.id < entityB.id) {
            "${entityA.id}-${entityB.id}"
        } else {
            "${entityB.id}-${entityA.id}"
        }
        
        return processedCollisions.putIfAbsent(key, true) == null
    }
    
    private fun checkCollision(entityA: Entity, entityB: Entity): Collision? {
        val posA = entityManager.getComponent(entityA, PositionComponent::class) ?: return null
        val posB = entityManager.getComponent(entityB, PositionComponent::class) ?: return null
        val renderA = entityManager.getComponent(entityA, RenderComponent::class) ?: return null
        val renderB = entityManager.getComponent(entityB, RenderComponent::class) ?: return null
        
        // Simple circle collision detection
        val radiusA = maxOf(renderA.getRenderedWidth(), renderA.getRenderedHeight()) / 2
        val radiusB = maxOf(renderB.getRenderedWidth(), renderB.getRenderedHeight()) / 2
        val distance = posA.distanceTo(posB)
        
        return if (distance < radiusA + radiusB) {
            Collision(entityA, entityB, distance)
        } else null
    }
}

/**
 * Spatial grid for efficient collision detection
 */
class SpatialGrid(private val cellSize: Float) {
    private val grid = ConcurrentHashMap<String, MutableList<Entity>>()
    
    fun clear() {
        grid.clear()
    }
    
    fun insert(entity: Entity, x: Float, y: Float) {
        val cellX = (x / cellSize).toInt()
        val cellY = (y / cellSize).toInt()
        val key = "$cellX,$cellY"
        
        grid.computeIfAbsent(key) { mutableListOf() }.add(entity)
    }
    
    fun getNearby(x: Float, y: Float, radius: Float): List<Entity> {
        val result = mutableListOf<Entity>()
        val cellRadius = kotlin.math.ceil(radius / cellSize).toInt()
        val centerCellX = (x / cellSize).toInt()
        val centerCellY = (y / cellSize).toInt()
        
        for (dx in -cellRadius..cellRadius) {
            for (dy in -cellRadius..cellRadius) {
                val key = "${centerCellX + dx},${centerCellY + dy}"
                grid[key]?.let { result.addAll(it) }
            }
        }
        
        return result
    }
}