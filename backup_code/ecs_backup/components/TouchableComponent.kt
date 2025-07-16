package com.flexport.ecs.components

import com.flexport.ecs.core.Component
import com.flexport.rendering.math.Rectangle

/**
 * Component that makes an entity touchable/clickable
 */
data class TouchableComponent(
    var bounds: Rectangle = Rectangle(),
    var isEnabled: Boolean = true,
    var consumesTouch: Boolean = true, // Whether this component consumes touch events
    var priority: Int = 0 // Higher priority gets touch events first
) : Component {
    
    /**
     * Check if a point is within the touchable bounds
     */
    fun contains(x: Float, y: Float): Boolean {
        return isEnabled && bounds.contains(x, y)
    }
    
    /**
     * Set the bounds from position and size
     */
    fun setBounds(x: Float, y: Float, width: Float, height: Float) {
        bounds.set(x, y, width, height)
    }
    
    /**
     * Set the bounds from center position and size
     */
    fun setBoundsFromCenter(centerX: Float, centerY: Float, width: Float, height: Float) {
        bounds.set(centerX - width / 2f, centerY - height / 2f, width, height)
    }
}