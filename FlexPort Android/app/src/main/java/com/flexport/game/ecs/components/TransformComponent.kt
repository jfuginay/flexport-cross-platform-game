package com.flexport.game.ecs.components

import com.flexport.game.ecs.core.Component

/**
 * Component for entity position, rotation, and scale
 */
data class TransformComponent(
    var x: Float = 0f,
    var y: Float = 0f,
    var rotation: Float = 0f,
    var scaleX: Float = 1f,
    var scaleY: Float = 1f,
    var originX: Float = 0f,
    var originY: Float = 0f
) : Component {
    
    /**
     * Set position
     */
    fun setPosition(x: Float, y: Float) {
        this.x = x
        this.y = y
    }
    
    /**
     * Translate by offset
     */
    fun translate(dx: Float, dy: Float) {
        this.x += dx
        this.y += dy
    }
    
    /**
     * Set scale uniformly
     */
    fun setScale(scale: Float) {
        this.scaleX = scale
        this.scaleY = scale
    }
    
    /**
     * Set origin (rotation and scale pivot point)
     */
    fun setOrigin(originX: Float, originY: Float) {
        this.originX = originX
        this.originY = originY
    }
    
    /**
     * Rotate by degrees
     */
    fun rotate(degrees: Float) {
        rotation += degrees
        // Keep rotation in 0-360 range
        while (rotation >= 360f) rotation -= 360f
        while (rotation < 0f) rotation += 360f
    }
}