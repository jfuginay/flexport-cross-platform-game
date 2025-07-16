package com.flexport.ecs.components

import com.flexport.ecs.core.Component

/**
 * Component for rendering visual representation of an entity
 */
data class RenderComponent(
    var textureId: String = "",
    var width: Float = 32f,
    var height: Float = 32f,
    var layer: Int = 0, // Rendering layer for z-ordering
    var isVisible: Boolean = true,
    var tint: Int = 0xFFFFFFFF.toInt(), // ARGB color
    var scaleX: Float = 1f,
    var scaleY: Float = 1f
) : Component {
    
    /**
     * Set size
     */
    fun setSize(width: Float, height: Float) {
        this.width = width
        this.height = height
    }
    
    /**
     * Set scale
     */
    fun setScale(scale: Float) {
        this.scaleX = scale
        this.scaleY = scale
    }
    
    /**
     * Get actual rendered width
     */
    fun getRenderedWidth(): Float = width * scaleX
    
    /**
     * Get actual rendered height
     */
    fun getRenderedHeight(): Float = height * scaleY
}