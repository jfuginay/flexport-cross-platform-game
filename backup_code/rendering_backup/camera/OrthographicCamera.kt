package com.flexport.rendering.camera

import com.flexport.rendering.math.Rectangle

/**
 * Orthographic camera for 2D rendering
 */
class OrthographicCamera(
    viewportWidth: Float = 0f,
    viewportHeight: Float = 0f
) : Camera2D() {
    
    init {
        this.viewportWidth = viewportWidth
        this.viewportHeight = viewportHeight
        update()
    }
    
    override fun update() {
        val halfWidth = viewportWidth * 0.5f * zoom
        val halfHeight = viewportHeight * 0.5f * zoom
        
        projection.setToOrtho(
            -halfWidth, halfWidth,
            -halfHeight, halfHeight,
            0f, 100f
        )
        
        super.update()
    }
    
    override fun getVisibleBounds(): Rectangle {
        val halfWidth = viewportWidth * 0.5f * zoom
        val halfHeight = viewportHeight * 0.5f * zoom
        
        return Rectangle(
            position.x - halfWidth,
            position.y - halfHeight,
            halfWidth * 2f,
            halfHeight * 2f
        )
    }
    
    /**
     * Center the camera on a specific world position
     */
    fun centerOn(x: Float, y: Float) {
        setPosition(x, y)
    }
    
    /**
     * Set camera to show a specific area
     */
    fun fitToArea(x: Float, y: Float, width: Float, height: Float, padding: Float = 0f) {
        // Center on the area
        centerOn(x + width * 0.5f, y + height * 0.5f)
        
        // Calculate zoom to fit the area
        val paddedWidth = width + padding * 2f
        val paddedHeight = height + padding * 2f
        
        val zoomX = viewportWidth / paddedWidth
        val zoomY = viewportHeight / paddedHeight
        
        zoom = minOf(zoomX, zoomY, 1f)
    }
}