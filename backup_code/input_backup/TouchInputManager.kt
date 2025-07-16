package com.flexport.input

import android.view.MotionEvent
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.performance.ObjectPool
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Central manager for touch input handling with coordinate conversion and event pooling
 */
class TouchInputManager(
    private val camera: Camera2D? = null
) {
    
    // Event streams
    private val _touchEvents = MutableSharedFlow<TouchEvent>(extraBufferCapacity = 64)
    val touchEvents: SharedFlow<TouchEvent> = _touchEvents.asSharedFlow()
    
    private val _gestureEvents = MutableSharedFlow<GestureEvent>(extraBufferCapacity = 32)
    val gestureEvents: SharedFlow<GestureEvent> = _gestureEvents.asSharedFlow()
    
    // Gesture detectors
    private val gestureDetector = GestureDetector()
    private val multiTouchGestureDetector = MultiTouchGestureDetector()
    
    // Touch state
    private val touchState = TouchState()
    
    // Object pools for memory efficiency
    private val vector2Pool = ObjectPool<Vector2> { Vector2() }
    private val touchEventPool = ObjectPool<TouchEvent> { 
        TouchEvent(0, TouchEvent.TouchAction.DOWN, Vector2(), Vector2())
    }
    
    // Input configuration
    var isInputEnabled = true
    var debugMode = false
    
    init {
        setupGestureListeners()
    }
    
    private fun setupGestureListeners() {
        gestureDetector.setGestureListener(object : GestureDetector.GestureListener {
            override fun onTap(e: GestureEvent.Tap): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onDoubleTap(e: GestureEvent.Tap): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onLongPress(e: GestureEvent.LongPress): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onPanStart(e: GestureEvent.Pan): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onPan(e: GestureEvent.Pan): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onPanEnd(e: GestureEvent.Pan): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onDragStart(e: GestureEvent.DragStart): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onDrag(e: GestureEvent.Drag): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onDragEnd(e: GestureEvent.DragEnd): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
        })
        
        multiTouchGestureDetector.setGestureListener(object : MultiTouchGestureDetector.MultiTouchGestureListener {
            override fun onPinchStart(e: GestureEvent.Pinch): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onPinch(e: GestureEvent.Pinch): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onPinchEnd(e: GestureEvent.Pinch): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
            
            override fun onTwoFingerPan(e: GestureEvent.Pan): Boolean {
                _gestureEvents.tryEmit(e)
                return true
            }
        })
    }
    
    /**
     * Handle Android MotionEvent
     */
    fun handleMotionEvent(event: MotionEvent): Boolean {
        if (!isInputEnabled) return false
        
        val action = event.actionMasked
        val pointerIndex = event.actionIndex
        val pointerId = event.getPointerId(pointerIndex)
        
        when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                handlePointerDown(event, pointerId, pointerIndex)
            }
            MotionEvent.ACTION_MOVE -> {
                handlePointerMove(event)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                handlePointerUp(event, pointerId, pointerIndex)
            }
            MotionEvent.ACTION_CANCEL -> {
                handleCancel(event)
            }
        }
        
        // Update gesture detectors
        updateGestureDetectors()
        
        return true
    }
    
    private fun handlePointerDown(event: MotionEvent, pointerId: Int, pointerIndex: Int) {
        val screenX = event.getX(pointerIndex)
        val screenY = event.getY(pointerIndex)
        val worldPos = screenToWorld(screenX, screenY)
        val screenPos = Vector2(screenX, screenY)
        
        // Create or update pointer
        val pointer = touchState.pointers.getOrPut(pointerId) { TouchPointer(pointerId) }
        pointer.isDown = true
        pointer.startTime = event.eventTime
        pointer.lastTime = event.eventTime
        pointer.startWorldPosition.set(worldPos)
        pointer.currentWorldPosition.set(worldPos)
        pointer.previousWorldPosition.set(worldPos)
        pointer.startScreenPosition.set(screenPos)
        pointer.currentScreenPosition.set(screenPos)
        pointer.previousScreenPosition.set(screenPos)
        pointer.pressure = event.getPressure(pointerIndex)
        
        // Create touch event
        val touchEvent = TouchEvent(
            pointerId = pointerId,
            action = TouchEvent.TouchAction.DOWN,
            worldPosition = worldPos,
            screenPosition = screenPos,
            timestamp = event.eventTime,
            pressure = pointer.pressure
        )
        
        // Emit events
        _touchEvents.tryEmit(touchEvent)
        gestureDetector.onTouchEvent(touchEvent)
        
        if (debugMode) {
            println("Touch DOWN: pointerId=$pointerId, world=(${worldPos.x}, ${worldPos.y}), screen=(${screenPos.x}, ${screenPos.y})")
        }
    }
    
    private fun handlePointerMove(event: MotionEvent) {
        for (i in 0 until event.pointerCount) {
            val pointerId = event.getPointerId(i)
            val pointer = touchState.pointers[pointerId] ?: continue
            
            if (!pointer.isDown) continue
            
            val screenX = event.getX(i)
            val screenY = event.getY(i)
            val worldPos = screenToWorld(screenX, screenY)
            val screenPos = Vector2(screenX, screenY)
            
            // Update pointer
            pointer.updatePosition(worldPos.x, worldPos.y, screenPos.x, screenPos.y, event.eventTime)
            pointer.pressure = event.getPressure(i)
            
            // Create touch event
            val touchEvent = TouchEvent(
                pointerId = pointerId,
                action = TouchEvent.TouchAction.MOVE,
                worldPosition = worldPos,
                screenPosition = screenPos,
                timestamp = event.eventTime,
                pressure = pointer.pressure
            )
            
            // Emit events
            _touchEvents.tryEmit(touchEvent)
            gestureDetector.onTouchEvent(touchEvent)
        }
        
        if (debugMode && touchState.getPointerCount() > 0) {
            val activePointers = touchState.getActivePointers()
            println("Touch MOVE: ${activePointers.size} pointers active")
        }
    }
    
    private fun handlePointerUp(event: MotionEvent, pointerId: Int, pointerIndex: Int) {
        val pointer = touchState.pointers[pointerId] ?: return
        
        val screenX = event.getX(pointerIndex)
        val screenY = event.getY(pointerIndex)
        val worldPos = screenToWorld(screenX, screenY)
        val screenPos = Vector2(screenX, screenY)
        
        // Update pointer final position
        pointer.updatePosition(worldPos.x, worldPos.y, screenPos.x, screenPos.y, event.eventTime)
        
        // Create touch event
        val touchEvent = TouchEvent(
            pointerId = pointerId,
            action = TouchEvent.TouchAction.UP,
            worldPosition = worldPos,
            screenPosition = screenPos,
            timestamp = event.eventTime,
            pressure = pointer.pressure
        )
        
        // Emit events
        _touchEvents.tryEmit(touchEvent)
        gestureDetector.onTouchEvent(touchEvent)
        
        // Clean up pointer
        pointer.isDown = false
        touchState.removePointer(pointerId)
        
        if (debugMode) {
            println("Touch UP: pointerId=$pointerId, world=(${worldPos.x}, ${worldPos.y}), screen=(${screenPos.x}, ${screenPos.y})")
        }
    }
    
    private fun handleCancel(event: MotionEvent) {
        for (pointerId in touchState.pointers.keys.toList()) {
            val pointer = touchState.pointers[pointerId] ?: continue
            
            val touchEvent = TouchEvent(
                pointerId = pointerId,
                action = TouchEvent.TouchAction.CANCEL,
                worldPosition = pointer.currentWorldPosition.cpy(),
                screenPosition = pointer.currentScreenPosition.cpy(),
                timestamp = event.eventTime,
                pressure = pointer.pressure
            )
            
            _touchEvents.tryEmit(touchEvent)
            gestureDetector.onTouchEvent(touchEvent)
        }
        
        touchState.clear()
        
        if (debugMode) {
            println("Touch CANCEL: All pointers cleared")
        }
    }
    
    private fun updateGestureDetectors() {
        // Update multi-touch gesture detector
        multiTouchGestureDetector.onTouchEvent(touchState)
    }
    
    /**
     * Convert screen coordinates to world coordinates
     */
    private fun screenToWorld(screenX: Float, screenY: Float): Vector2 {
        return camera?.unproject(screenX, screenY) ?: Vector2(screenX, screenY)
    }
    
    /**
     * Convert world coordinates to screen coordinates
     */
    fun worldToScreen(worldX: Float, worldY: Float): Vector2 {
        return camera?.project(worldX, worldY) ?: Vector2(worldX, worldY)
    }
    
    /**
     * Get current touch state
     */
    fun getTouchState(): TouchState = touchState
    
    /**
     * Check if any pointer is currently touching the screen
     */
    fun isAnyPointerDown(): Boolean = touchState.getPointerCount() > 0
    
    /**
     * Get the number of active pointers
     */
    fun getActivePointerCount(): Int = touchState.getPointerCount()
    
    /**
     * Enable or disable touch input processing
     */
    fun setInputEnabled(enabled: Boolean) {
        isInputEnabled = enabled
        if (!enabled) {
            touchState.clear()
        }
    }
    
    /**
     * Clear all touch state
     */
    fun clearTouchState() {
        touchState.clear()
    }
    
    /**
     * Set the camera for coordinate conversion
     */
    fun setCamera(camera: Camera2D) {
        // Update camera reference if needed
    }
    
    /**
     * Dispose of resources
     */
    fun dispose() {
        touchState.clear()
        vector2Pool.clear()
        touchEventPool.clear()
    }
}