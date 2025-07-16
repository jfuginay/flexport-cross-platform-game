package com.flexport.ecs.components

import com.flexport.ecs.core.Component

/**
 * Component for entities that can be interacted with via touch gestures
 */
data class InteractableComponent(
    var isEnabled: Boolean = true,
    var supportsTap: Boolean = true,
    var supportsLongPress: Boolean = false,
    var supportsDrag: Boolean = false,
    var supportsContextMenu: Boolean = false,
    var dragThreshold: Float = 10f, // Minimum distance to start drag
    var longPressThreshold: Long = 500L, // Time in milliseconds for long press
    var onTapCallback: (() -> Unit)? = null,
    var onLongPressCallback: (() -> Unit)? = null,
    var onDragStartCallback: ((Float, Float) -> Unit)? = null,
    var onDragCallback: ((Float, Float, Float, Float) -> Unit)? = null, // deltaX, deltaY, totalX, totalY
    var onDragEndCallback: ((Float, Float) -> Unit)? = null,
    var onContextMenuCallback: (() -> Unit)? = null
) : Component {
    
    // Internal state tracking
    var isDragging: Boolean = false
        internal set
    var dragStartX: Float = 0f
        internal set
    var dragStartY: Float = 0f
        internal set
    var totalDragX: Float = 0f
        internal set
    var totalDragY: Float = 0f
        internal set
    var lastTouchTime: Long = 0L
        internal set
    
    /**
     * Reset drag state
     */
    fun resetDragState() {
        isDragging = false
        dragStartX = 0f
        dragStartY = 0f
        totalDragX = 0f
        totalDragY = 0f
    }
    
    /**
     * Check if drag threshold has been exceeded
     */
    fun isDragThresholdExceeded(currentX: Float, currentY: Float): Boolean {
        val deltaX = currentX - dragStartX
        val deltaY = currentY - dragStartY
        val distance = kotlin.math.sqrt(deltaX * deltaX + deltaY * deltaY)
        return distance >= dragThreshold
    }
}