package com.flexport.input

import com.flexport.rendering.math.Vector2
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Detects multi-touch gestures like pinch-to-zoom
 */
class MultiTouchGestureDetector(
    private val touchSlop: Float = 10f
) {
    
    private var gestureListener: MultiTouchGestureListener? = null
    
    // Pinch gesture state
    private var isPinchInProgress = false
    private var initialDistance = 0f
    private var previousDistance = 0f
    private var previousScale = 1f
    private var pinchCenter = Vector2()
    private var pinchStartTime = 0L
    
    // Two-finger pan state
    private var isTwoFingerPanInProgress = false
    private var twoFingerPanStart = Vector2()
    private var lastTwoFingerPanCenter = Vector2()
    
    interface MultiTouchGestureListener {
        fun onPinchStart(e: GestureEvent.Pinch): Boolean = false
        fun onPinch(e: GestureEvent.Pinch): Boolean = false
        fun onPinchEnd(e: GestureEvent.Pinch): Boolean = false
        fun onTwoFingerPan(e: GestureEvent.Pan): Boolean = false
    }
    
    fun setGestureListener(listener: MultiTouchGestureListener) {
        this.gestureListener = listener
    }
    
    fun onTouchEvent(touchState: TouchState): Boolean {
        val activePointers = touchState.getActivePointers()
        
        when (activePointers.size) {
            0 -> {
                endAllGestures()
                return false
            }
            1 -> {
                endAllGestures()
                return false
            }
            2 -> {
                return handleTwoFingerGestures(activePointers)
            }
            else -> {
                // More than 2 fingers - end gestures for now
                endAllGestures()
                return false
            }
        }
    }
    
    private fun handleTwoFingerGestures(pointers: List<TouchPointer>): Boolean {
        val pointer1 = pointers[0]
        val pointer2 = pointers[1]
        
        val distance = calculateDistance(pointer1.currentWorldPosition, pointer2.currentWorldPosition)
        val center = calculateCenter(pointer1.currentWorldPosition, pointer2.currentWorldPosition)
        
        // Detect pinch gesture
        if (!isPinchInProgress) {
            // Check if this looks like a pinch start
            val finger1Movement = pointer1.getTotalWorldDelta().len()
            val finger2Movement = pointer2.getTotalWorldDelta().len()
            
            if (finger1Movement > touchSlop || finger2Movement > touchSlop) {
                // Check if fingers are moving in opposite directions (pinch pattern)
                val finger1Delta = pointer1.getWorldDelta()
                val finger2Delta = pointer2.getWorldDelta()
                val dot = finger1Delta.dot(finger2Delta)
                
                // If dot product is negative, fingers are moving in generally opposite directions
                if (dot < 0) {
                    startPinchGesture(distance, center)
                } else {
                    // Fingers moving in same direction - might be two-finger pan
                    startTwoFingerPan(center)
                }
            }
        } else {
            // Continue pinch gesture
            updatePinchGesture(distance, center)
        }
        
        // Handle two-finger pan
        if (isTwoFingerPanInProgress && !isPinchInProgress) {
            updateTwoFingerPan(center)
        }
        
        return isPinchInProgress || isTwoFingerPanInProgress
    }
    
    private fun startPinchGesture(distance: Float, center: Vector2) {
        isPinchInProgress = true
        initialDistance = distance
        previousDistance = distance
        previousScale = 1f
        pinchCenter.set(center)
        pinchStartTime = System.currentTimeMillis()
        
        val pinchEvent = GestureEvent.Pinch(
            centerWorldPosition = center.cpy(),
            centerScreenPosition = Vector2(), // Would need screen conversion
            scale = 1f,
            deltaScale = 0f,
            distance = distance
        )
        
        gestureListener?.onPinchStart(pinchEvent)
    }
    
    private fun updatePinchGesture(distance: Float, center: Vector2) {
        if (!isPinchInProgress) return
        
        val scale = distance / initialDistance
        val deltaScale = scale - previousScale
        
        val pinchEvent = GestureEvent.Pinch(
            centerWorldPosition = center.cpy(),
            centerScreenPosition = Vector2(), // Would need screen conversion
            scale = scale,
            deltaScale = deltaScale,
            distance = distance
        )
        
        gestureListener?.onPinch(pinchEvent)
        
        previousDistance = distance
        previousScale = scale
        pinchCenter.set(center)
    }
    
    private fun endPinchGesture() {
        if (!isPinchInProgress) return
        
        val finalScale = previousDistance / initialDistance
        val pinchEvent = GestureEvent.Pinch(
            centerWorldPosition = pinchCenter.cpy(),
            centerScreenPosition = Vector2(), // Would need screen conversion
            scale = finalScale,
            deltaScale = 0f,
            distance = previousDistance
        )
        
        gestureListener?.onPinchEnd(pinchEvent)
        isPinchInProgress = false
    }
    
    private fun startTwoFingerPan(center: Vector2) {
        isTwoFingerPanInProgress = true
        twoFingerPanStart.set(center)
        lastTwoFingerPanCenter.set(center)
    }
    
    private fun updateTwoFingerPan(center: Vector2) {
        if (!isTwoFingerPanInProgress) return
        
        val deltaX = center.x - lastTwoFingerPanCenter.x
        val deltaY = center.y - lastTwoFingerPanCenter.y
        
        val panEvent = GestureEvent.Pan(
            startWorldPosition = twoFingerPanStart.cpy(),
            currentWorldPosition = center.cpy(),
            deltaWorldPosition = Vector2(deltaX, deltaY),
            startScreenPosition = Vector2(), // Would need screen conversion
            currentScreenPosition = Vector2(), // Would need screen conversion
            deltaScreenPosition = Vector2(), // Would need screen conversion
            velocity = Vector2() // Could calculate from history
        )
        
        gestureListener?.onTwoFingerPan(panEvent)
        
        lastTwoFingerPanCenter.set(center)
    }
    
    private fun endAllGestures() {
        if (isPinchInProgress) {
            endPinchGesture()
        }
        isTwoFingerPanInProgress = false
    }
    
    private fun calculateDistance(pos1: Vector2, pos2: Vector2): Float {
        val dx = pos2.x - pos1.x
        val dy = pos2.y - pos1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private fun calculateCenter(pos1: Vector2, pos2: Vector2): Vector2 {
        return Vector2(
            (pos1.x + pos2.x) / 2f,
            (pos1.y + pos2.y) / 2f
        )
    }
}