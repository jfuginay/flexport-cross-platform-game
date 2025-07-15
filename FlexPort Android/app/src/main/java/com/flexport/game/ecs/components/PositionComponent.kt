package com.flexport.game.ecs.components

import com.flexport.game.ecs.core.Component

/**
 * Component representing an entity's position in 2D space
 */
data class PositionComponent(
    var x: Float = 0f,
    var y: Float = 0f,
    var rotation: Float = 0f // Rotation in radians
) : Component {
    
    /**
     * Set position
     */
    fun set(x: Float, y: Float) {
        this.x = x
        this.y = y
    }
    
    /**
     * Calculate distance to another position
     */
    fun distanceTo(other: PositionComponent): Float {
        val dx = other.x - x
        val dy = other.y - y
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
    
    /**
     * Calculate squared distance (more performant for comparisons)
     */
    fun distanceSquaredTo(other: PositionComponent): Float {
        val dx = other.x - x
        val dy = other.y - y
        return dx * dx + dy * dy
    }
}