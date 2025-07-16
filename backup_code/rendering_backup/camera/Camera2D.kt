package com.flexport.rendering.camera

import com.flexport.rendering.math.Matrix4
import com.flexport.rendering.math.Rectangle
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.math.Vector3

/**
 * Base class for 2D cameras
 */
abstract class Camera2D {
    
    val position = Vector3()
    val direction = Vector3(0f, 0f, -1f)
    val up = Vector3(0f, 1f, 0f)
    
    val projection = Matrix4()
    val view = Matrix4()
    val combined = Matrix4()
    val invProjectionView = Matrix4()
    
    var viewportWidth = 0f
        protected set
    var viewportHeight = 0f
        protected set
    
    var zoom = 1f
        set(value) {
            field = value.coerceIn(MIN_ZOOM, MAX_ZOOM)
            update()
        }
    
    /**
     * Update the camera matrices
     */
    open fun update() {
        view.setToLookAt(position, position.cpy().add(direction), up)
        combined.set(projection).mul(view)
        invProjectionView.set(combined).inv()
    }
    
    /**
     * Set the viewport size
     */
    open fun setViewportSize(width: Float, height: Float) {
        viewportWidth = width
        viewportHeight = height
        update()
    }
    
    /**
     * Translate the camera by the given amount
     */
    fun translate(x: Float, y: Float) {
        position.x += x
        position.y += y
        update()
    }
    
    /**
     * Set the camera position
     */
    fun setPosition(x: Float, y: Float) {
        position.x = x
        position.y = y
        update()
    }
    
    /**
     * Get the visible bounds of the camera
     */
    abstract fun getVisibleBounds(): Rectangle
    
    /**
     * Unproject screen coordinates to world coordinates
     */
    fun unproject(screenCoords: Vector3): Vector3 {
        screenCoords.x = (2f * screenCoords.x) / viewportWidth - 1f
        screenCoords.y = (2f * (viewportHeight - screenCoords.y)) / viewportHeight - 1f
        screenCoords.z = 2f * screenCoords.z - 1f
        screenCoords.prj(invProjectionView)
        return screenCoords
    }
    
    /**
     * Unproject screen coordinates to world coordinates (2D convenience method)
     */
    fun unproject(screenX: Float, screenY: Float): Vector2 {
        val unprojected = unproject(Vector3(screenX, screenY, 0f))
        return Vector2(unprojected.x, unprojected.y)
    }
    
    /**
     * Project world coordinates to screen coordinates
     */
    fun project(worldCoords: Vector3): Vector3 {
        worldCoords.prj(combined)
        worldCoords.x = viewportWidth * (worldCoords.x + 1f) / 2f
        worldCoords.y = viewportHeight * (1f - worldCoords.y) / 2f
        worldCoords.z = (worldCoords.z + 1f) / 2f
        return worldCoords
    }
    
    /**
     * Project world coordinates to screen coordinates (2D convenience method)
     */
    fun project(worldX: Float, worldY: Float): Vector2 {
        val projected = project(Vector3(worldX, worldY, 0f))
        return Vector2(projected.x, projected.y)
    }
    
    /**
     * Smoothly move the camera to a target position
     */
    fun smoothMoveTo(targetX: Float, targetY: Float, alpha: Float) {
        position.x += (targetX - position.x) * alpha
        position.y += (targetY - position.y) * alpha
        update()
    }
    
    /**
     * Apply smooth zoom
     */
    fun smoothZoom(targetZoom: Float, alpha: Float) {
        zoom += (targetZoom - zoom) * alpha
    }
    
    companion object {
        const val MIN_ZOOM = 0.1f
        const val MAX_ZOOM = 10f
    }
}