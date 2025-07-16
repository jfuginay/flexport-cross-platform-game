package com.flexport.rendering.ui

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.SurfaceView
import com.flexport.input.TouchInputManager

/**
 * Custom SurfaceView for game rendering with touch input integration
 */
class GameSurfaceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : SurfaceView(context, attrs, defStyle) {
    
    private var touchInputManager: TouchInputManager? = null
    private var isHapticEnabled = true
    private var hapticIntensity = 1f
    private var inputDebugMode = false
    
    // Performance tracking
    private var totalTouchEvents = 0L
    private var lastPerformanceReportTime = 0L
    private val performanceReportInterval = 1000L // Report every second
    
    init {
        // Enable touch events
        isFocusable = true
        isFocusableInTouchMode = true
    }
    
    /**
     * Set the touch input manager
     */
    fun setTouchInputManager(manager: TouchInputManager) {
        touchInputManager = manager
    }
    
    /**
     * Handle touch events
     */
    override fun onTouchEvent(event: MotionEvent): Boolean {
        touchInputManager?.let { manager ->
            if (manager.handleMotionEvent(event)) {
                totalTouchEvents++
                
                // Performance reporting in debug mode
                if (inputDebugMode) {
                    reportPerformance()
                }
                
                return true
            }
        }
        
        return super.onTouchEvent(event)
    }
    
    /**
     * Enable or disable haptic feedback
     */
    fun setHapticEnabled(enabled: Boolean) {
        isHapticEnabled = enabled
    }
    
    /**
     * Set haptic feedback intensity
     */
    fun setHapticIntensity(intensity: Float) {
        hapticIntensity = intensity.coerceIn(0f, 1f)
    }
    
    /**
     * Enable or disable input debug mode
     */
    fun setInputDebugMode(enabled: Boolean) {
        inputDebugMode = enabled
        
        if (!enabled) {
            totalTouchEvents = 0L
            lastPerformanceReportTime = 0L
        }
    }
    
    /**
     * Reset input performance statistics
     */
    fun resetInputPerformanceStats() {
        totalTouchEvents = 0L
        lastPerformanceReportTime = System.currentTimeMillis()
    }
    
    /**
     * Report performance statistics
     */
    private fun reportPerformance() {
        val currentTime = System.currentTimeMillis()
        val timeDelta = currentTime - lastPerformanceReportTime
        
        if (timeDelta >= performanceReportInterval) {
            val eventsPerSecond = (totalTouchEvents * 1000) / timeDelta
            println("Input Performance: $eventsPerSecond events/sec")
            
            totalTouchEvents = 0L
            lastPerformanceReportTime = currentTime
        }
    }
    
    /**
     * Get the current haptic settings
     */
    fun getHapticSettings(): Pair<Boolean, Float> {
        return Pair(isHapticEnabled, hapticIntensity)
    }
}