package com.flexport.game.ecs.components

import com.flexport.game.ecs.core.Component

/**
 * Component representing an entity's velocity in 2D space
 */
data class VelocityComponent(
    var dx: Float = 0f,
    var dy: Float = 0f,
    var angularVelocity: Float = 0f, // Rotation speed in radians per second
    var maxSpeed: Float = 100f
) : Component {
    
    /**
     * Set velocity
     */
    fun set(dx: Float, dy: Float) {
        this.dx = dx
        this.dy = dy
    }
    
    /**
     * Get current speed
     */
    fun getSpeed(): Float {
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
    
    /**
     * Normalize velocity to max speed if exceeding
     */
    fun clampToMaxSpeed() {
        val currentSpeed = getSpeed()
        if (currentSpeed > maxSpeed && currentSpeed > 0) {
            val scale = maxSpeed / currentSpeed
            dx *= scale
            dy *= scale
        }
    }
    
    /**
     * Apply acceleration
     */
    fun accelerate(ax: Float, ay: Float, deltaTime: Float) {
        dx += ax * deltaTime
        dy += ay * deltaTime
        clampToMaxSpeed()
    }
}