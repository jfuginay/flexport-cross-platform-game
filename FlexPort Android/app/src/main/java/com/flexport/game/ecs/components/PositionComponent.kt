package com.flexport.game.ecs.components

import com.flexport.game.ecs.Component
import kotlinx.serialization.Serializable

/**
 * Component that stores the position of an entity in the game world
 */
@Serializable
data class PositionComponent(
    var x: Float = 0f,
    var y: Float = 0f,
    var z: Float = 0f // Optional for 3D or layering
) : Component {
    
    /**
     * Set position from another PositionComponent
     */
    fun set(other: PositionComponent): PositionComponent {
        this.x = other.x
        this.y = other.y
        this.z = other.z
        return this
    }
    
    /**
     * Set position from coordinates
     */
    fun set(x: Float, y: Float, z: Float = this.z): PositionComponent {
        this.x = x
        this.y = y
        this.z = z
        return this
    }
    
    /**
     * Add to current position
     */
    fun add(dx: Float, dy: Float, dz: Float = 0f): PositionComponent {
        this.x += dx
        this.y += dy
        this.z += dz
        return this
    }
    
    /**
     * Calculate distance to another position
     */
    fun distanceTo(other: PositionComponent): Float {
        val dx = x - other.x
        val dy = y - other.y
        val dz = z - other.z
        return kotlin.math.sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    /**
     * Calculate 2D distance to another position (ignoring Z)
     */
    fun distance2DTo(other: PositionComponent): Float {
        val dx = x - other.x
        val dy = y - other.y
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
    
    /**
     * Create a copy of this position
     */
    fun copy(): PositionComponent {
        return PositionComponent(x, y, z)
    }
    
    override fun toString(): String {
        return "Position($x, $y, $z)"
    }
}

