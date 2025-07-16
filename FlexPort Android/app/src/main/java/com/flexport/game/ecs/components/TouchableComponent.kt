package com.flexport.game.ecs.components

import com.flexport.game.ecs.Component
import com.flexport.rendering.math.Rectangle
import com.flexport.rendering.math.Vector2
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

/**
 * Component that makes an entity touchable/clickable
 * Provides bounds checking and touch priority for overlapping entities
 */
@Serializable
data class TouchableComponent(
    val bounds: Rectangle,
    val priority: Int = 0,
    val enabled: Boolean = true,
    @Transient val touchOffset: Vector2 = Vector2.ZERO
) : Component {
    
    /**
     * Check if a point is within the touchable bounds
     */
    fun contains(x: Float, y: Float): Boolean {
        if (!enabled) return false
        
        // Apply offset to the touch position
        val offsetX = x - touchOffset.x
        val offsetY = y - touchOffset.y
        
        return bounds.contains(offsetX, offsetY)
    }
    
    /**
     * Check if a point is within the touchable bounds
     */
    fun contains(point: Vector2): Boolean = contains(point.x, point.y)
    
    /**
     * Update the bounds of this touchable area
     */
    fun setBounds(x: Float, y: Float, width: Float, height: Float): TouchableComponent {
        bounds.set(x, y, width, height)
        return this
    }
    
    /**
     * Enable or disable touch interaction
     */
    fun setEnabled(enabled: Boolean): TouchableComponent {
        return copy(enabled = enabled)
    }
    
    /**
     * Set the touch priority (higher values are checked first)
     */
    fun setPriority(priority: Int): TouchableComponent {
        return copy(priority = priority)
    }
    
    companion object {
        // Common priority levels
        const val PRIORITY_UI_OVERLAY = 1000
        const val PRIORITY_UI_ELEMENT = 100
        const val PRIORITY_GAME_OBJECT = 10
        const val PRIORITY_BACKGROUND = 0
        
        /**
         * Create a touchable component from center position and size
         */
        fun fromCenter(centerX: Float, centerY: Float, width: Float, height: Float, priority: Int = PRIORITY_GAME_OBJECT): TouchableComponent {
            val bounds = Rectangle(
                centerX - width / 2f,
                centerY - height / 2f,
                width,
                height
            )
            return TouchableComponent(bounds, priority)
        }
        
        /**
         * Create a touchable component with circular bounds (approximated as square)
         */
        fun circular(centerX: Float, centerY: Float, radius: Float, priority: Int = PRIORITY_GAME_OBJECT): TouchableComponent {
            val diameter = radius * 2f
            return fromCenter(centerX, centerY, diameter, diameter, priority)
        }
    }
}