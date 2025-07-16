package com.flexport.rendering.camera

import com.flexport.rendering.math.Rectangle
import com.flexport.rendering.math.Vector2

/**
 * Simple 2D camera for coordinate conversion
 */
class Camera2D(
    var viewportWidth: Float = 1080f,
    var viewportHeight: Float = 1920f
) {
    
    // Camera position in world coordinates
    var position = Vector2(0f, 0f)
    
    // Camera zoom level (1.0 = normal, >1.0 = zoomed in, <1.0 = zoomed out)
    var zoom = 1f
        set(value) {
            field = value.coerceIn(0.1f, 10f)
        }
    
    /**
     * Convert screen coordinates to world coordinates
     */
    fun unproject(screenX: Float, screenY: Float): Vector2 {
        // Simple implementation - scale by zoom and offset by camera position
        val worldX = (screenX - viewportWidth / 2f) * zoom + position.x
        val worldY = (screenY - viewportHeight / 2f) * zoom + position.y
        return Vector2(worldX, worldY)
    }
    
    /**
     * Convert world coordinates to screen coordinates
     */
    fun project(worldX: Float, worldY: Float): Vector2 {
        val screenX = (worldX - position.x) / zoom + viewportWidth / 2f
        val screenY = (worldY - position.y) / zoom + viewportHeight / 2f
        return Vector2(screenX, screenY)
    }
    
    /**
     * Update viewport size
     */
    fun setViewport(width: Float, height: Float) {
        viewportWidth = width
        viewportHeight = height
    }
    
    /**
     * Move camera by delta
     */
    fun translate(dx: Float, dy: Float) {
        position.add(dx, dy)
    }
    
    /**
     * Set camera position
     */
    fun setPosition(x: Float, y: Float) {
        position.set(x, y)
    }
    
    /**
     * Get the visible bounds of the camera in world coordinates
     */
    fun getVisibleBounds(): Rectangle {
        val halfWidth = (viewportWidth * zoom) / 2f
        val halfHeight = (viewportHeight * zoom) / 2f
        return Rectangle(
            position.x - halfWidth,
            position.y - halfHeight,
            viewportWidth * zoom,
            viewportHeight * zoom
        )
    }
    
    /**
     * Smoothly move camera to target position
     */
    fun smoothMoveTo(targetX: Float, targetY: Float, factor: Float) {
        val invFactor = 1f - factor
        position.x = position.x * invFactor + targetX * factor
        position.y = position.y * invFactor + targetY * factor
    }
    
    /**
     * Smoothly zoom camera to target zoom level
     */
    fun smoothZoom(targetZoom: Float, factor: Float) {
        val invFactor = 1f - factor
        zoom = zoom * invFactor + targetZoom * factor
    }
}