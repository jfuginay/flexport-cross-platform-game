package com.flexport.rendering.ui

import android.content.Context
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.view.MotionEvent
import com.flexport.rendering.core.RenderConfig
import com.flexport.rendering.opengl.GLRenderer
import com.flexport.input.TouchInputManager
import com.flexport.input.HapticFeedbackManager
import com.flexport.input.InputPerformanceOptimizer

/**
 * Custom GLSurfaceView for game rendering with advanced touch input handling
 */
class GameSurfaceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : GLSurfaceView(context, attrs) {
    
    private var glRenderer: GLRenderer? = null
    private var inputHandler: GameInputHandler? = null
    
    // New touch input system
    private var touchInputManager: TouchInputManager? = null
    private var hapticFeedbackManager: HapticFeedbackManager? = null
    private var inputOptimizer = InputPerformanceOptimizer()
    
    // Performance tracking
    private var lastFrameTime = 0L
    private var frameCount = 0
    private var lastFpsCalculation = 0L
    private var currentFps = 0f
    
    init {
        // Set OpenGL ES 3.0
        setEGLContextClientVersion(3)
        
        // Create renderer
        val config = RenderConfig()
        glRenderer = GLRenderer(config)
        setRenderer(glRenderer)
        
        // Only render when explicitly requested
        renderMode = RENDERMODE_WHEN_DIRTY
        
        // Initialize haptic feedback
        hapticFeedbackManager = HapticFeedbackManager(context)
        
        // Enable performance optimizations
        setupPerformanceOptimizations()
    }
    
    private fun setupPerformanceOptimizations() {
        // Configure input optimization settings
        inputOptimizer.resetStats()
    }
    
    /**
     * Set the touch input manager for advanced input handling
     */
    fun setTouchInputManager(manager: TouchInputManager) {
        this.touchInputManager = manager
    }
    
    /**
     * Set the legacy input handler (maintained for compatibility)
     */
    fun setInputHandler(handler: GameInputHandler) {
        this.inputHandler = handler
    }
    
    /**
     * Get the haptic feedback manager
     */
    fun getHapticFeedbackManager(): HapticFeedbackManager? = hapticFeedbackManager
    
    /**
     * Get input performance statistics
     */
    fun getInputPerformanceStats(): InputPerformanceOptimizer.PerformanceStats {
        return inputOptimizer.getPerformanceStats()
    }
    
    /**
     * Enhanced touch event handling with performance optimizations
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val currentTime = System.nanoTime()
        
        // Throttle input processing for performance
        if (!inputOptimizer.shouldProcessInput()) {
            return true
        }
        
        // Try new touch input system first
        val handled = touchInputManager?.handleMotionEvent(event) ?: false
        
        // Fallback to legacy input handler if new system didn't handle it
        if (!handled) {
            inputHandler?.handleTouchEvent(event)
        }
        
        // Update performance metrics
        updatePerformanceMetrics(currentTime)
        
        // Request a new frame
        requestRender()
        
        return true
    }
    
    private fun updatePerformanceMetrics(currentTime: Long) {
        frameCount++
        
        if (lastFpsCalculation == 0L) {
            lastFpsCalculation = currentTime
        }
        
        val timeSinceLastFps = currentTime - lastFpsCalculation
        if (timeSinceLastFps >= 1_000_000_000L) { // 1 second in nanoseconds
            currentFps = frameCount * 1_000_000_000f / timeSinceLastFps
            frameCount = 0
            lastFpsCalculation = currentTime
        }
        
        lastFrameTime = currentTime
    }
    
    /**
     * Get current FPS
     */
    fun getCurrentFps(): Float = currentFps
    
    /**
     * Enable or disable haptic feedback
     */
    fun setHapticEnabled(enabled: Boolean) {
        hapticFeedbackManager?.setHapticEnabled(enabled)
    }
    
    /**
     * Set haptic feedback intensity
     */
    fun setHapticIntensity(intensity: Float) {
        hapticFeedbackManager?.setGlobalIntensity(intensity)
    }
    
    /**
     * Enable or disable input performance optimizations
     */
    fun setInputOptimizationsEnabled(enabled: Boolean) {
        if (!enabled) {
            inputOptimizer.clear()
        }
    }
    
    /**
     * Reset input performance statistics
     */
    fun resetInputPerformanceStats() {
        inputOptimizer.resetStats()
    }
    
    fun getRenderer(): GLRenderer? = glRenderer
    
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        glRenderer?.dispose()
        touchInputManager?.dispose()
        inputOptimizer.clear()
        hapticFeedbackManager?.saveHapticSettings()
    }
    
    override fun onResume() {
        super.onResume()
        // Reset performance counters on resume
        lastFrameTime = 0L
        frameCount = 0
        lastFpsCalculation = 0L
        currentFps = 0f
    }
    
    override fun onPause() {
        super.onPause()
        // Save haptic settings
        hapticFeedbackManager?.saveHapticSettings()
        // Cancel any ongoing haptic feedback
        hapticFeedbackManager?.cancelHaptic()
    }
    
    /**
     * Configure touch input sensitivity
     */
    fun configureTouchSensitivity(
        tapTimeout: Long = 150L,
        longPressTimeout: Long = 500L,
        touchSlop: Float = 10f
    ) {
        // These would be passed to the TouchInputManager if it supported configuration
        // For now, this is a placeholder for future enhancement
    }
    
    /**
     * Enable debug mode for touch input
     */
    fun setInputDebugMode(enabled: Boolean) {
        touchInputManager?.debugMode = enabled
    }
}

/**
 * Interface for handling game input (legacy support)
 */
interface GameInputHandler {
    fun handleTouchEvent(event: MotionEvent)
}