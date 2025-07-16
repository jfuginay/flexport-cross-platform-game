package com.flexport.input

import com.flexport.rendering.math.Vector2

/**
 * Represents a touch event in the game
 */
data class TouchEvent(
    val pointerId: Int,
    val action: TouchAction,
    val worldPosition: Vector2,
    val screenPosition: Vector2,
    val timestamp: Long = System.currentTimeMillis(),
    val pressure: Float = 1f
) {
    enum class TouchAction {
        DOWN,
        UP,
        MOVE,
        CANCEL
    }
    
    fun reset() {
        // Data class - no reset needed, new instances are created
    }
}

/**
 * Represents a gesture event
 */
sealed class GestureEvent(
    val timestamp: Long = System.currentTimeMillis()
) {
    data class Tap(
        val worldPosition: Vector2,
        val screenPosition: Vector2
    ) : GestureEvent()
    
    data class LongPress(
        val worldPosition: Vector2,
        val screenPosition: Vector2,
        val duration: Long
    ) : GestureEvent()
    
    data class Pan(
        val startWorldPosition: Vector2,
        val currentWorldPosition: Vector2,
        val deltaWorldPosition: Vector2,
        val startScreenPosition: Vector2,
        val currentScreenPosition: Vector2,
        val deltaScreenPosition: Vector2,
        val velocity: Vector2
    ) : GestureEvent()
    
    data class Pinch(
        val centerWorldPosition: Vector2,
        val centerScreenPosition: Vector2,
        val scale: Float,
        val deltaScale: Float,
        val distance: Float
    ) : GestureEvent()
    
    data class DragStart(
        val worldPosition: Vector2,
        val screenPosition: Vector2
    ) : GestureEvent()
    
    data class Drag(
        val startWorldPosition: Vector2,
        val currentWorldPosition: Vector2,
        val deltaWorldPosition: Vector2,
        val totalWorldDelta: Vector2,
        val startScreenPosition: Vector2,
        val currentScreenPosition: Vector2,
        val deltaScreenPosition: Vector2,
        val totalScreenDelta: Vector2
    ) : GestureEvent()
    
    data class DragEnd(
        val startWorldPosition: Vector2,
        val endWorldPosition: Vector2,
        val totalWorldDelta: Vector2,
        val startScreenPosition: Vector2,
        val endScreenPosition: Vector2,
        val totalScreenDelta: Vector2,
        val velocity: Vector2
    ) : GestureEvent()
}

/**
 * Tracks the state of a touch pointer
 */
data class TouchPointer(
    val id: Int,
    var isDown: Boolean = false,
    var startTime: Long = 0L,
    var lastTime: Long = 0L,
    val startWorldPosition: Vector2 = Vector2(),
    val currentWorldPosition: Vector2 = Vector2(),
    val previousWorldPosition: Vector2 = Vector2(),
    val startScreenPosition: Vector2 = Vector2(),
    val currentScreenPosition: Vector2 = Vector2(),
    val previousScreenPosition: Vector2 = Vector2(),
    val velocity: Vector2 = Vector2(),
    var pressure: Float = 1f
) {
    fun reset() {
        isDown = false
        startTime = 0L
        lastTime = 0L
        startWorldPosition.set(0f, 0f)
        currentWorldPosition.set(0f, 0f)
        previousWorldPosition.set(0f, 0f)
        startScreenPosition.set(0f, 0f)
        currentScreenPosition.set(0f, 0f)
        previousScreenPosition.set(0f, 0f)
        velocity.set(0f, 0f)
        pressure = 1f
    }
    
    fun updatePosition(worldX: Float, worldY: Float, screenX: Float, screenY: Float, time: Long) {
        previousWorldPosition.set(currentWorldPosition)
        previousScreenPosition.set(currentScreenPosition)
        currentWorldPosition.set(worldX, worldY)
        currentScreenPosition.set(screenX, screenY)
        
        if (lastTime > 0) {
            val dt = (time - lastTime) / 1000f // Convert to seconds
            if (dt > 0) {
                velocity.set(
                    (currentWorldPosition.x - previousWorldPosition.x) / dt,
                    (currentWorldPosition.y - previousWorldPosition.y) / dt
                )
            }
        }
        
        lastTime = time
    }
    
    fun getTotalWorldDelta(): Vector2 {
        return Vector2(
            currentWorldPosition.x - startWorldPosition.x,
            currentWorldPosition.y - startWorldPosition.y
        )
    }
    
    fun getTotalScreenDelta(): Vector2 {
        return Vector2(
            currentScreenPosition.x - startScreenPosition.x,
            currentScreenPosition.y - startScreenPosition.y
        )
    }
    
    fun getWorldDelta(): Vector2 {
        return Vector2(
            currentWorldPosition.x - previousWorldPosition.x,
            currentWorldPosition.y - previousWorldPosition.y
        )
    }
    
    fun getScreenDelta(): Vector2 {
        return Vector2(
            currentScreenPosition.x - previousScreenPosition.x,
            currentScreenPosition.y - previousScreenPosition.y
        )
    }
}

/**
 * Overall touch input state
 */
data class TouchState(
    val pointers: MutableMap<Int, TouchPointer> = mutableMapOf(),
    var gestureInProgress: Boolean = false,
    var currentGestureType: GestureType? = null
) {
    
    enum class GestureType {
        TAP,
        LONG_PRESS,
        PAN,
        PINCH,
        DRAG
    }
    
    fun getActivePointers(): List<TouchPointer> {
        return pointers.values.filter { it.isDown }
    }
    
    fun getPointerCount(): Int {
        return getActivePointers().size
    }
    
    fun clear() {
        pointers.clear()
        gestureInProgress = false
        currentGestureType = null
    }
    
    fun removePointer(pointerId: Int) {
        pointers.remove(pointerId)
        if (pointers.isEmpty()) {
            gestureInProgress = false
            currentGestureType = null
        }
    }
}