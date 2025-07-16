package com.flexport.ecs.systems

import com.flexport.ecs.components.CameraComponent
import com.flexport.ecs.components.SpriteComponent
import com.flexport.ecs.components.TransformComponent
import com.flexport.ecs.core.Entity
import com.flexport.ecs.core.EntityManager
import com.flexport.rendering.batch.SpriteBatch
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.core.Renderer
import com.flexport.rendering.math.Rectangle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * System responsible for rendering sprites
 */
class RenderSystem(
    private val renderer: Renderer,
    private val entityManager: EntityManager
) {
    
    private lateinit var spriteBatch: SpriteBatch
    private var activeCamera: Camera2D? = null
    
    // For frustum culling
    private val visibleBounds = Rectangle()
    
    // For depth sorting
    private val renderableEntities = mutableListOf<RenderableEntity>()
    
    data class RenderableEntity(
        val entity: Entity,
        val transform: TransformComponent,
        val sprite: SpriteComponent
    )
    
    suspend fun initialize() = withContext(Dispatchers.Main) {
        spriteBatch = renderer.createSpriteBatch(1000)
        activeCamera = renderer.getDefaultCamera()
    }
    
    suspend fun render() = withContext(Dispatchers.Main) {
        // Find active camera
        findActiveCamera()
        
        val camera = activeCamera ?: return@withContext
        
        // Update camera
        camera.update()
        
        // Get visible bounds for culling
        visibleBounds.set(camera.getVisibleBounds())
        
        // Collect renderable entities
        collectRenderableEntities()
        
        // Sort by layer and then by Y position (for depth)
        renderableEntities.sortWith { a, b ->
            val layerCompare = a.sprite.layer.compareTo(b.sprite.layer)
            if (layerCompare != 0) {
                layerCompare
            } else {
                // Sort by Y position (higher Y = further back)
                b.transform.y.compareTo(a.transform.y)
            }
        }
        
        // Begin rendering
        renderer.beginFrame()
        renderer.clear(0.1f, 0.1f, 0.2f, 1.0f) // Dark blue background
        
        spriteBatch.setCamera(camera)
        spriteBatch.begin()
        
        // Render all sprites
        for (renderable in renderableEntities) {
            renderSprite(renderable)
        }
        
        spriteBatch.end()
        renderer.endFrame()
        
        // Clear for next frame
        renderableEntities.clear()
    }
    
    private fun findActiveCamera() {
        val cameraEntities = entityManager.getEntitiesWithComponents(CameraComponent::class)
        
        for (entity in cameraEntities) {
            val cameraComponent = entityManager.getComponent(entity, CameraComponent::class)
            if (cameraComponent?.isActive == true && cameraComponent.camera != null) {
                activeCamera = cameraComponent.camera
                return
            }
        }
        
        // Fallback to default camera
        activeCamera = renderer.getDefaultCamera()
    }
    
    private fun collectRenderableEntities() {
        val spriteEntities = entityManager.getEntitiesWithComponents(
            TransformComponent::class,
            SpriteComponent::class
        )
        
        for (entity in spriteEntities) {
            val transform = entityManager.getComponent(entity, TransformComponent::class)
            val sprite = entityManager.getComponent(entity, SpriteComponent::class)
            
            if (transform != null && sprite != null && sprite.visible && sprite.hasTexture()) {
                // Frustum culling
                if (isVisible(transform, sprite)) {
                    renderableEntities.add(RenderableEntity(entity, transform, sprite))
                }
            }
        }
    }
    
    private fun isVisible(transform: TransformComponent, sprite: SpriteComponent): Boolean {
        // Simple AABB check against camera bounds
        val entityBounds = Rectangle(
            transform.x - transform.originX,
            transform.y - transform.originY,
            sprite.width,
            sprite.height
        )
        
        return visibleBounds.overlaps(entityBounds)
    }
    
    private fun renderSprite(renderable: RenderableEntity) {
        val transform = renderable.transform
        val sprite = renderable.sprite
        
        // Set tint color
        spriteBatch.setColor(sprite.tintR, sprite.tintG, sprite.tintB, sprite.alpha)
        
        if (sprite.textureRegion != null) {
            // Render texture region
            if (transform.rotation != 0f || transform.scaleX != 1f || transform.scaleY != 1f) {
                spriteBatch.draw(
                    sprite.textureRegion!!,
                    transform.x,
                    transform.y,
                    transform.originX,
                    transform.originY,
                    sprite.width,
                    sprite.height,
                    transform.scaleX,
                    transform.scaleY,
                    transform.rotation
                )
            } else {
                spriteBatch.draw(
                    sprite.textureRegion!!,
                    transform.x,
                    transform.y,
                    sprite.width,
                    sprite.height
                )
            }
        } else if (sprite.texture != null) {
            // Render texture
            if (transform.rotation != 0f || transform.scaleX != 1f || transform.scaleY != 1f) {
                spriteBatch.draw(
                    sprite.texture!!,
                    transform.x,
                    transform.y,
                    transform.originX,
                    transform.originY,
                    sprite.width,
                    sprite.height,
                    transform.scaleX,
                    transform.scaleY,
                    transform.rotation,
                    sprite.flipX,
                    sprite.flipY
                )
            } else {
                spriteBatch.draw(
                    sprite.texture!!,
                    transform.x,
                    transform.y,
                    sprite.width,
                    sprite.height
                )
            }
        }
    }
    
    suspend fun dispose() = withContext(Dispatchers.Main) {
        if (::spriteBatch.isInitialized) {
            spriteBatch.dispose()
        }
    }
    
    fun getStats() = renderer.getStats()
}