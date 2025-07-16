package com.flexport.input

import android.content.Context
import com.flexport.game.ecs.EntityManager
import com.flexport.ecs.systems.TouchInputSystem
import com.flexport.input.interactions.CameraController
import com.flexport.input.interactions.SelectionManager
import com.flexport.input.interactions.RouteCreationHandler
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.ui.GameSurfaceView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * Complete integration example for the FlexPort touch input system
 * This class demonstrates how to wire together all the touch input components
 */
class TouchInputIntegration(
    private val context: Context,
    private val gameSurfaceView: GameSurfaceView,
    private val camera: Camera2D,
    private val entityManager: EntityManager
) {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    // Core input system components
    private val touchInputManager = TouchInputManager(camera)
    private val hapticFeedbackManager = HapticFeedbackManager(context)
    private val inputOptimizer = InputPerformanceOptimizer()
    
    // ECS integration
    private val touchInputSystem = TouchInputSystem(entityManager, touchInputManager)
    
    // Game-specific interaction handlers
    private val cameraController = CameraController(camera, touchInputManager)
    private val selectionManager = SelectionManager(entityManager, touchInputManager)
    private val routeCreationHandler = RouteCreationHandler(entityManager, touchInputManager)
    
    // Input state
    private var currentInputMode = InputMode.NORMAL
    
    enum class InputMode {
        NORMAL,           // Standard gameplay input
        CAMERA_ONLY,      // Only camera controls active
        ROUTE_CREATION,   // Route creation mode
        SELECTION_ONLY,   // Only selection active
        DISABLED          // All input disabled
    }
    
    /**
     * Initialize the complete touch input system
     */
    suspend fun initialize() {
        // Set up the game surface view
        gameSurfaceView.setTouchInputManager(touchInputManager)
        gameSurfaceView.setHapticEnabled(true)
        
        // Initialize all systems
        touchInputSystem.initialize()
        
        // Set up interaction handlers
        setupCameraController()
        setupSelectionManager()
        setupRouteCreationHandler()
        setupHapticFeedback()
        
        // Configure input modes
        setInputMode(InputMode.NORMAL)
    }
    
    private fun setupCameraController() {
        // Configure camera control settings
        cameraController.isPanEnabled = true
        cameraController.isZoomEnabled = true
        cameraController.panSensitivity = 1f
        cameraController.zoomSensitivity = 1f
        cameraController.smoothingEnabled = true
        cameraController.smoothingFactor = 0.1f
        
        // Set world bounds (example: 10000x10000 world)
        cameraController.setWorldBounds(-5000f, -5000f, 10000f, 10000f)
    }
    
    private fun setupSelectionManager() {
        // Configure selection settings
        selectionManager.setSelectionMode(SelectionManager.SelectionMode.MULTIPLE)
        selectionManager.allowBoxSelection = true
        
        // Listen for selection events
        scope.launch {
            selectionManager.selectionEvents.collect { event ->
                handleSelectionEvent(event)
            }
        }
    }
    
    private fun setupRouteCreationHandler() {
        // Configure route creation settings
        routeCreationHandler.isRouteCreationEnabled = true
        routeCreationHandler.minimumDragDistance = 50f
        routeCreationHandler.snapDistance = 100f
        
        // Listen for route events
        scope.launch {
            routeCreationHandler.routeEvents.collect { event ->
                handleRouteEvent(event)
            }
        }
    }
    
    private fun setupHapticFeedback() {
        // Listen for touch events to provide haptic feedback
        scope.launch {
            touchInputManager.touchEvents.collect { touchEvent ->
                when (touchEvent.action) {
                    TouchEvent.TouchAction.DOWN -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.TAP, 0.3f)
                    }
                    else -> { /* No haptic for other touch actions */ }
                }
            }
        }
        
        // Listen for gesture events for haptic feedback
        scope.launch {
            touchInputManager.gestureEvents.collect { gestureEvent ->
                when (gestureEvent) {
                    is GestureEvent.Tap -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.BUTTON_PRESS, 0.5f)
                    }
                    is GestureEvent.LongPress -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.LONG_PRESS, 0.8f)
                    }
                    is GestureEvent.DragStart -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.DRAG_START, 0.6f)
                    }
                    is GestureEvent.DragEnd -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.DRAG_END, 0.4f)
                    }
                    is GestureEvent.Pinch -> {
                        hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.ZOOM, 0.2f)
                    }
                    else -> { /* No haptic for other gestures */ }
                }
            }
        }
    }
    
    private fun handleSelectionEvent(event: SelectionManager.SelectionEvent) {
        when (event) {
            is SelectionManager.SelectionEvent.EntitySelected -> {
                hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.SELECTION, 0.4f)
                println("Entity selected: ${event.entityId}")
            }
            is SelectionManager.SelectionEvent.EntityDeselected -> {
                hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.TAP, 0.2f)
                println("Entity deselected: ${event.entityId}")
            }
            is SelectionManager.SelectionEvent.SelectionCleared -> {
                println("Selection cleared, ${event.previousSelection.size} entities deselected")
            }
            is SelectionManager.SelectionEvent.BoxSelectionCompleted -> {
                if (event.selectedEntities.isNotEmpty()) {
                    hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.SUCCESS, 0.6f)
                }
                println("Box selection completed: ${event.selectedEntities.size} entities selected")
            }
            else -> { /* Handle other selection events */ }
        }
    }
    
    private fun handleRouteEvent(event: RouteCreationHandler.RouteEvent) {
        when (event) {
            is RouteCreationHandler.RouteEvent.RouteCreationStarted -> {
                hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.DRAG_START, 0.7f)
                println("Route creation started from entity: ${event.startEntityId}")
            }
            is RouteCreationHandler.RouteEvent.RouteCreationCompleted -> {
                if (event.isValid) {
                    hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.SUCCESS, 0.8f)
                    println("Route created: ${event.startEntityId} -> ${event.endEntityId}")
                } else {
                    hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.ERROR, 0.6f)
                    println("Invalid route attempted")
                }
            }
            is RouteCreationHandler.RouteEvent.RouteCreationCancelled -> {
                hapticFeedbackManager.triggerHaptic(HapticFeedbackManager.HapticType.TAP, 0.3f)
                println("Route creation cancelled")
            }
            else -> { /* Handle other route events */ }
        }
    }
    
    /**
     * Update all input systems (call this from your main game loop)
     */
    suspend fun update(deltaTime: Float) {
        // Update ECS touch input system
        touchInputSystem.update(deltaTime)
        
        // Update camera controller
        cameraController.update(deltaTime)
        
        // Process batched input events for performance
        inputOptimizer.processBatchedEvents(
            touchInputManager.touchEvents as kotlinx.coroutines.flow.MutableSharedFlow,
            touchInputManager.gestureEvents as kotlinx.coroutines.flow.MutableSharedFlow
        )
    }
    
    /**
     * Set the current input mode to enable/disable different interaction types
     */
    fun setInputMode(mode: InputMode) {
        currentInputMode = mode
        
        when (mode) {
            InputMode.NORMAL -> {
                touchInputManager.isInputEnabled = true
                cameraController.isPanEnabled = true
                cameraController.isZoomEnabled = true
                selectionManager.setSelectionMode(SelectionManager.SelectionMode.MULTIPLE)
                routeCreationHandler.isRouteCreationEnabled = true
            }
            InputMode.CAMERA_ONLY -> {
                touchInputManager.isInputEnabled = true
                cameraController.isPanEnabled = true
                cameraController.isZoomEnabled = true
                selectionManager.setSelectionMode(SelectionManager.SelectionMode.SINGLE)
                routeCreationHandler.isRouteCreationEnabled = false
            }
            InputMode.ROUTE_CREATION -> {
                touchInputManager.isInputEnabled = true
                cameraController.isPanEnabled = false
                cameraController.isZoomEnabled = false
                selectionManager.setSelectionMode(SelectionManager.SelectionMode.SINGLE)
                routeCreationHandler.isRouteCreationEnabled = true
            }
            InputMode.SELECTION_ONLY -> {
                touchInputManager.isInputEnabled = true
                cameraController.isPanEnabled = false
                cameraController.isZoomEnabled = false
                selectionManager.setSelectionMode(SelectionManager.SelectionMode.MULTIPLE)
                routeCreationHandler.isRouteCreationEnabled = false
            }
            InputMode.DISABLED -> {
                touchInputManager.isInputEnabled = false
            }
        }
    }
    
    /**
     * Get the current input mode
     */
    fun getCurrentInputMode(): InputMode = currentInputMode
    
    /**
     * Focus camera on a specific world position
     */
    fun focusCameraOn(x: Float, y: Float, zoom: Float? = null) {
        cameraController.focusOn(x, y, zoom, animate = true)
    }
    
    /**
     * Get currently selected entities
     */
    fun getSelectedEntities(): Set<String> = selectionManager.getSelectedEntities()
    
    /**
     * Select entities programmatically
     */
    fun selectEntities(entityIds: Collection<String>, clearPrevious: Boolean = true) {
        selectionManager.selectEntities(entityIds, clearPrevious)
    }
    
    /**
     * Clear all selections
     */
    fun clearSelection() {
        selectionManager.clearSelectionProgrammatically()
    }
    
    /**
     * Enable or disable haptic feedback
     */
    fun setHapticEnabled(enabled: Boolean) {
        hapticFeedbackManager.isHapticEnabled = enabled
        gameSurfaceView.setHapticEnabled(enabled)
    }
    
    /**
     * Set haptic feedback intensity
     */
    fun setHapticIntensity(intensity: Float) {
        hapticFeedbackManager.globalIntensity = intensity
        gameSurfaceView.setHapticIntensity(intensity)
    }
    
    /**
     * Get input performance statistics
     */
    fun getInputPerformanceStats(): InputPerformanceOptimizer.PerformanceStats {
        return inputOptimizer.getPerformanceStats()
    }
    
    /**
     * Reset input performance statistics
     */
    fun resetInputPerformanceStats() {
        inputOptimizer.resetStats()
        gameSurfaceView.resetInputPerformanceStats()
    }
    
    /**
     * Enable or disable debug mode for all input systems
     */
    fun setDebugMode(enabled: Boolean) {
        touchInputManager.debugMode = enabled
        gameSurfaceView.setInputDebugMode(enabled)
    }
    
    /**
     * Dispose of all input systems and clean up resources
     */
    fun dispose() {
        touchInputSystem.dispose()
        cameraController.dispose()
        selectionManager.dispose()
        routeCreationHandler.dispose()
        touchInputManager.dispose()
        inputOptimizer.clear()
        hapticFeedbackManager.saveHapticSettings()
    }
}