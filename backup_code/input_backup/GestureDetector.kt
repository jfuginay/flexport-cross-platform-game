package com.flexport.input

import com.flexport.rendering.math.Vector2
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Detects gestures from touch input
 */
class GestureDetector(
    private val tapTimeout: Long = 150L,
    private val longPressTimeout: Long = 500L,
    private val doubleTapTimeout: Long = 300L,
    private val touchSlop: Float = 10f,
    private val minimumFlingVelocity: Float = 100f,
    private val maximumFlingVelocity: Float = 8000f
) {
    
    private var gestureListener: GestureListener? = null
    
    // Single touch state
    private var downTime: Long = 0
    private var downX: Float = 0f
    private var downY: Float = 0f
    private var isLongPressTriggered: Boolean = false
    private var isDragTriggered: Boolean = false
    private var lastTapTime: Long = 0
    private var tapCount: Int = 0
    
    // Pan/drag state
    private var panStartX: Float = 0f
    private var panStartY: Float = 0f
    private var lastPanX: Float = 0f
    private var lastPanY: Float = 0f
    private var panStartTime: Long = 0
    
    // Velocity tracking
    private val velocityTracker = VelocityTracker()
    
    interface GestureListener {
        fun onTap(e: GestureEvent.Tap): Boolean = false
        fun onDoubleTap(e: GestureEvent.Tap): Boolean = false
        fun onLongPress(e: GestureEvent.LongPress): Boolean = false
        fun onPanStart(e: GestureEvent.Pan): Boolean = false
        fun onPan(e: GestureEvent.Pan): Boolean = false
        fun onPanEnd(e: GestureEvent.Pan): Boolean = false
        fun onDragStart(e: GestureEvent.DragStart): Boolean = false
        fun onDrag(e: GestureEvent.Drag): Boolean = false
        fun onDragEnd(e: GestureEvent.DragEnd): Boolean = false
    }
    
    fun setGestureListener(listener: GestureListener) {
        this.gestureListener = listener
    }
    
    fun onTouchEvent(event: TouchEvent): Boolean {
        when (event.action) {
            TouchEvent.TouchAction.DOWN -> {
                return onTouchDown(event)
            }
            TouchEvent.TouchAction.MOVE -> {
                return onTouchMove(event)
            }
            TouchEvent.TouchAction.UP -> {
                return onTouchUp(event)
            }
            TouchEvent.TouchAction.CANCEL -> {
                return onTouchCancel(event)
            }
        }
    }
    
    private fun onTouchDown(event: TouchEvent): Boolean {
        downTime = event.timestamp
        downX = event.worldPosition.x
        downY = event.worldPosition.y
        isLongPressTriggered = false
        isDragTriggered = false
        
        panStartX = event.worldPosition.x
        panStartY = event.worldPosition.y
        lastPanX = event.worldPosition.x
        lastPanY = event.worldPosition.y
        panStartTime = event.timestamp
        
        velocityTracker.clear()
        velocityTracker.addMovement(event)
        
        return true
    }
    
    private fun onTouchMove(event: TouchEvent): Boolean {
        velocityTracker.addMovement(event)
        
        val deltaX = event.worldPosition.x - downX
        val deltaY = event.worldPosition.y - downY
        val distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // Check for long press (only if we haven't moved too much)
        if (!isLongPressTriggered && !isDragTriggered && 
            distance < touchSlop && 
            event.timestamp - downTime >= longPressTimeout) {
            
            isLongPressTriggered = true
            val longPressEvent = GestureEvent.LongPress(
                worldPosition = event.worldPosition.cpy(),
                screenPosition = event.screenPosition.cpy(),
                duration = event.timestamp - downTime
            )
            gestureListener?.onLongPress(longPressEvent)
            return true
        }
        
        // Check for drag start
        if (!isDragTriggered && distance >= touchSlop) {
            isDragTriggered = true
            
            val dragStartEvent = GestureEvent.DragStart(
                worldPosition = Vector2(downX, downY),
                screenPosition = event.screenPosition.cpy()
            )
            gestureListener?.onDragStart(dragStartEvent)
            
            // Also trigger pan start
            val panStartEvent = GestureEvent.Pan(
                startWorldPosition = Vector2(panStartX, panStartY),
                currentWorldPosition = event.worldPosition.cpy(),
                deltaWorldPosition = Vector2(deltaX, deltaY),
                startScreenPosition = event.screenPosition.cpy(),
                currentScreenPosition = event.screenPosition.cpy(),
                deltaScreenPosition = Vector2(0f, 0f),
                velocity = Vector2()
            )
            gestureListener?.onPanStart(panStartEvent)
        }
        
        // Handle ongoing drag/pan
        if (isDragTriggered) {
            val panDeltaX = event.worldPosition.x - lastPanX
            val panDeltaY = event.worldPosition.y - lastPanY
            val totalDeltaX = event.worldPosition.x - panStartX
            val totalDeltaY = event.worldPosition.y - panStartY
            
            val velocity = velocityTracker.getVelocity()
            
            // Drag event
            val dragEvent = GestureEvent.Drag(
                startWorldPosition = Vector2(downX, downY),
                currentWorldPosition = event.worldPosition.cpy(),
                deltaWorldPosition = Vector2(panDeltaX, panDeltaY),
                totalWorldDelta = Vector2(totalDeltaX, totalDeltaY),
                startScreenPosition = event.screenPosition.cpy(),
                currentScreenPosition = event.screenPosition.cpy(),
                deltaScreenPosition = Vector2(0f, 0f),
                totalScreenDelta = Vector2(0f, 0f)
            )
            gestureListener?.onDrag(dragEvent)
            
            // Pan event
            val panEvent = GestureEvent.Pan(
                startWorldPosition = Vector2(panStartX, panStartY),
                currentWorldPosition = event.worldPosition.cpy(),
                deltaWorldPosition = Vector2(panDeltaX, panDeltaY),
                startScreenPosition = event.screenPosition.cpy(),
                currentScreenPosition = event.screenPosition.cpy(),
                deltaScreenPosition = Vector2(0f, 0f),
                velocity = velocity
            )
            gestureListener?.onPan(panEvent)
            
            lastPanX = event.worldPosition.x
            lastPanY = event.worldPosition.y
        }
        
        return true
    }
    
    private fun onTouchUp(event: TouchEvent): Boolean {
        velocityTracker.addMovement(event)
        
        val deltaX = event.worldPosition.x - downX
        val deltaY = event.worldPosition.y - downY
        val distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        val duration = event.timestamp - downTime
        
        if (isDragTriggered) {
            // End drag
            val velocity = velocityTracker.getVelocity()
            val totalDeltaX = event.worldPosition.x - downX
            val totalDeltaY = event.worldPosition.y - downY
            
            val dragEndEvent = GestureEvent.DragEnd(
                startWorldPosition = Vector2(downX, downY),
                endWorldPosition = event.worldPosition.cpy(),
                totalWorldDelta = Vector2(totalDeltaX, totalDeltaY),
                startScreenPosition = event.screenPosition.cpy(),
                endScreenPosition = event.screenPosition.cpy(),
                totalScreenDelta = Vector2(0f, 0f),
                velocity = velocity
            )
            gestureListener?.onDragEnd(dragEndEvent)
            
            // End pan
            val panEndEvent = GestureEvent.Pan(
                startWorldPosition = Vector2(panStartX, panStartY),
                currentWorldPosition = event.worldPosition.cpy(),
                deltaWorldPosition = Vector2(event.worldPosition.x - lastPanX, event.worldPosition.y - lastPanY),
                startScreenPosition = event.screenPosition.cpy(),
                currentScreenPosition = event.screenPosition.cpy(),
                deltaScreenPosition = Vector2(0f, 0f),
                velocity = velocity
            )
            gestureListener?.onPanEnd(panEndEvent)
            
        } else if (!isLongPressTriggered && distance < touchSlop && duration < tapTimeout) {
            // Handle tap/double tap
            val currentTime = event.timestamp
            
            if (currentTime - lastTapTime <= doubleTapTimeout) {
                tapCount++
            } else {
                tapCount = 1
            }
            
            val tapEvent = GestureEvent.Tap(
                worldPosition = event.worldPosition.cpy(),
                screenPosition = event.screenPosition.cpy()
            )
            
            if (tapCount == 2) {
                gestureListener?.onDoubleTap(tapEvent)
                tapCount = 0
            } else {
                gestureListener?.onTap(tapEvent)
            }
            
            lastTapTime = currentTime
        }
        
        reset()
        return true
    }
    
    private fun onTouchCancel(event: TouchEvent): Boolean {
        reset()
        return true
    }
    
    private fun reset() {
        isLongPressTriggered = false
        isDragTriggered = false
        velocityTracker.clear()
    }
}

/**
 * Simple velocity tracker for gesture detection
 */
private class VelocityTracker {
    private val positions = mutableListOf<Pair<Vector2, Long>>()
    private val maxSamples = 5
    
    fun clear() {
        positions.clear()
    }
    
    fun addMovement(event: TouchEvent) {
        positions.add(Pair(event.worldPosition.cpy(), event.timestamp))
        if (positions.size > maxSamples) {
            positions.removeAt(0)
        }
    }
    
    fun getVelocity(): Vector2 {
        if (positions.size < 2) return Vector2.ZERO
        
        val first = positions.first()
        val last = positions.last()
        
        val deltaTime = (last.second - first.second) / 1000f // Convert to seconds
        if (deltaTime <= 0f) return Vector2.ZERO
        
        val deltaX = last.first.x - first.first.x
        val deltaY = last.first.y - first.first.y
        
        return Vector2(deltaX / deltaTime, deltaY / deltaTime)
    }
}