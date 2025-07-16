package com.flexport.input.interactions

import com.flexport.rendering.camera.Camera2D
import com.flexport.input.GestureEvent
import com.flexport.input.TouchInputManager
import com.flexport.rendering.math.Vector2
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

/**
 * Handles camera controls through touch input (pan, zoom, etc.)
 */
class CameraController(
    private val camera: Camera2D,
    private val touchInputManager: TouchInputManager
) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Camera control settings
    var isPanEnabled = true
    var isZoomEnabled = true
    var panSensitivity = 1f
    var zoomSensitivity = 1f
    var minZoom = 0.1f
    var maxZoom = 10f
    var smoothingEnabled = true
    var smoothingFactor = 0.1f
    
    // World bounds for camera movement (optional)
    var worldBounds: com.flexport.rendering.math.Rectangle? = null
    
    // Smooth movement targets
    private var targetX = camera.position.x
    private var targetY = camera.position.y
    private var targetZoom = camera.zoom
    
    // Momentum and inertia
    private var panVelocity = Vector2()
    private var velocityDecay = 0.95f
    private var minimumVelocity = 1f
    
    // State tracking
    private var isUserInteracting = false
    private var lastPanX = 0f
    private var lastPanY = 0f
    
    init {
        targetX = camera.position.x
        targetY = camera.position.y
        targetZoom = camera.zoom
        
        setupGestureHandling()
    }
    
    private fun setupGestureHandling() {
        scope.launch {
            touchInputManager.gestureEvents.collect { gestureEvent ->
                handleGestureEvent(gestureEvent)
            }
        }
    }
    
    private fun handleGestureEvent(event: GestureEvent) {
        when (event) {
            is GestureEvent.Pan -> handlePan(event)
            is GestureEvent.Pinch -> handlePinch(event)
            else -> { /* Other gestures handled elsewhere */ }
        }
    }
    
    private fun handlePan(event: GestureEvent.Pan) {
        if (!isPanEnabled) return
        
        when {
            // Pan start - begin user interaction
            event.deltaWorldPosition.len() == 0f -> {
                isUserInteracting = true
                panVelocity.set(0f, 0f)
                lastPanX = event.currentWorldPosition.x
                lastPanY = event.currentWorldPosition.y
            }
            
            // Pan in progress
            else -> {
                if (touchInputManager.getActivePointerCount() == 1) {
                    // Single finger pan - move camera
                    val deltaX = -event.deltaWorldPosition.x * panSensitivity
                    val deltaY = -event.deltaWorldPosition.y * panSensitivity
                    
                    moveCamera(deltaX, deltaY)
                    
                    // Update velocity for momentum
                    panVelocity.set(event.velocity).mul(-panSensitivity)
                }
            }
        }
    }
    
    private fun handlePinch(event: GestureEvent.Pinch) {
        if (!isZoomEnabled) return
        
        isUserInteracting = true
        panVelocity.set(0f, 0f)
        
        val zoomChange = event.deltaScale * zoomSensitivity
        val newZoom = (camera.zoom * (1f + zoomChange)).coerceIn(minZoom, maxZoom)
        
        if (smoothingEnabled) {
            targetZoom = newZoom
        } else {
            camera.zoom = newZoom
        }
        
        // Zoom towards the pinch center
        val screenCenter = Vector2(camera.viewportWidth / 2f, camera.viewportHeight / 2f)
        val pinchOffset = Vector2(
            event.centerScreenPosition.x - screenCenter.x,
            event.centerScreenPosition.y - screenCenter.y
        )
        
        // Adjust camera position to zoom towards pinch point
        val worldOffset = camera.unproject(pinchOffset.x, pinchOffset.y)
        val adjustmentFactor = (newZoom - camera.zoom) / camera.zoom
        
        val deltaX = worldOffset.x * adjustmentFactor
        val deltaY = worldOffset.y * adjustmentFactor
        
        moveCamera(deltaX, deltaY)
    }
    
    private fun moveCamera(deltaX: Float, deltaY: Float) {
        val newX = camera.position.x + deltaX
        val newY = camera.position.y + deltaY
        
        // Apply world bounds if set
        val constrainedPos = constrainToWorldBounds(newX, newY)
        
        if (smoothingEnabled) {
            targetX = constrainedPos.x
            targetY = constrainedPos.y
        } else {
            camera.setPosition(constrainedPos.x, constrainedPos.y)
        }
    }
    
    private fun constrainToWorldBounds(x: Float, y: Float): Vector2 {
        val bounds = worldBounds ?: return Vector2(x, y)
        
        val visibleBounds = camera.getVisibleBounds()
        val halfWidth = visibleBounds.width / 2f
        val halfHeight = visibleBounds.height / 2f
        
        val constrainedX = x.coerceIn(
            bounds.x + halfWidth,
            bounds.x + bounds.width - halfWidth
        )
        val constrainedY = y.coerceIn(
            bounds.y + halfHeight,
            bounds.y + bounds.height - halfHeight
        )
        
        return Vector2(constrainedX, constrainedY)
    }
    
    /**
     * Update camera with smooth movement and momentum
     */
    fun update(deltaTime: Float) {
        // Check if user is still interacting
        if (touchInputManager.getActivePointerCount() == 0) {
            isUserInteracting = false
        }
        
        // Apply smooth movement
        if (smoothingEnabled) {
            camera.smoothMoveTo(targetX, targetY, smoothingFactor)
            camera.smoothZoom(targetZoom, smoothingFactor)
        }
        
        // Apply momentum when not interacting
        if (!isUserInteracting && panVelocity.len() > minimumVelocity) {
            val momentumDeltaX = panVelocity.x * deltaTime
            val momentumDeltaY = panVelocity.y * deltaTime
            
            moveCamera(momentumDeltaX, momentumDeltaY)
            
            // Apply velocity decay
            panVelocity.mul(velocityDecay)
        }
    }
    
    /**
     * Set camera position with optional animation
     */
    fun setCameraPosition(x: Float, y: Float, animate: Boolean = true) {
        if (animate && smoothingEnabled) {
            targetX = x
            targetY = y
        } else {
            camera.setPosition(x, y)
            targetX = x
            targetY = y
        }
    }
    
    /**
     * Set camera zoom with optional animation
     */
    fun setCameraZoom(zoom: Float, animate: Boolean = true) {
        val constrainedZoom = zoom.coerceIn(minZoom, maxZoom)
        
        if (animate && smoothingEnabled) {
            targetZoom = constrainedZoom
        } else {
            camera.zoom = constrainedZoom
            targetZoom = constrainedZoom
        }
    }
    
    /**
     * Focus camera on a specific point
     */
    fun focusOn(x: Float, y: Float, zoom: Float? = null, animate: Boolean = true) {
        setCameraPosition(x, y, animate)
        zoom?.let { setCameraZoom(it, animate) }
    }
    
    /**
     * Reset camera to default position and zoom
     */
    fun reset(animate: Boolean = true) {
        setCameraPosition(0f, 0f, animate)
        setCameraZoom(1f, animate)
        panVelocity.set(0f, 0f)
    }
    
    /**
     * Get current camera position
     */
    fun getCameraPosition(): Vector2 = Vector2(camera.position.x, camera.position.y)
    
    /**
     * Get current camera zoom
     */
    fun getCameraZoom(): Float = camera.zoom
    
    /**
     * Check if camera is currently being controlled by user
     */
    fun isUserControlling(): Boolean = isUserInteracting
    
    /**
     * Set world bounds for camera movement
     */
    fun setWorldBounds(x: Float, y: Float, width: Float, height: Float) {
        worldBounds = com.flexport.rendering.math.Rectangle(x, y, width, height)
    }
    
    /**
     * Clear world bounds
     */
    fun clearWorldBounds() {
        worldBounds = null
    }
    
    /**
     * Dispose resources
     */
    fun dispose() {
        // Clean up coroutines and resources
    }
}