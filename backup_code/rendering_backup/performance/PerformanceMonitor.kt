package com.flexport.rendering.performance

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Performance monitoring system for tracking rendering metrics
 */
class PerformanceMonitor {
    
    private val _metrics = MutableStateFlow(PerformanceMetrics())
    val metrics: StateFlow<PerformanceMetrics> = _metrics.asStateFlow()
    
    // Frame timing
    private var frameStartTime = 0L
    private var frameCount = 0
    private var totalFrameTime = 0L
    private var fpsTimer = 0L
    private val frameHistory = mutableListOf<Long>()
    private val maxFrameHistory = 60 // Keep last 60 frames
    
    // Memory tracking
    private var lastGCCount = 0
    private var gcCount = 0
    
    // Performance thresholds
    companion object {
        const val TARGET_FPS = 60
        const val TARGET_FRAME_TIME_MS = 16.67f // 1000ms / 60fps
        const val FRAME_TIME_WARNING_MS = 20f
        const val FRAME_TIME_CRITICAL_MS = 33f
    }
    
    /**
     * Called at the start of each frame
     */
    fun startFrame() {
        frameStartTime = System.nanoTime()
    }
    
    /**
     * Called at the end of each frame
     */
    fun endFrame() {
        val frameEndTime = System.nanoTime()
        val frameTimeNs = frameEndTime - frameStartTime
        val frameTimeMs = frameTimeNs / 1_000_000f
        
        frameCount++
        totalFrameTime += frameTimeNs
        
        // Update frame history
        frameHistory.add(frameTimeNs)
        if (frameHistory.size > maxFrameHistory) {
            frameHistory.removeAt(0)
        }
        
        // Update FPS every second
        val currentTime = System.currentTimeMillis()
        if (currentTime - fpsTimer >= 1000) {
            updateMetrics(currentTime)
            fpsTimer = currentTime
        }
    }
    
    private fun updateMetrics(currentTime: Long) {
        val fps = if (totalFrameTime > 0) {
            (frameCount * 1_000_000_000L) / totalFrameTime
        } else 0L
        
        val avgFrameTimeMs = if (frameCount > 0) {
            (totalFrameTime / frameCount) / 1_000_000f
        } else 0f
        
        val minFrameTimeMs = if (frameHistory.isNotEmpty()) {
            frameHistory.minOf { it } / 1_000_000f
        } else 0f
        
        val maxFrameTimeMs = if (frameHistory.isNotEmpty()) {
            frameHistory.maxOf { it } / 1_000_000f
        } else 0f
        
        // Check for performance issues
        val performanceLevel = when {
            avgFrameTimeMs <= TARGET_FRAME_TIME_MS -> PerformanceLevel.EXCELLENT
            avgFrameTimeMs <= FRAME_TIME_WARNING_MS -> PerformanceLevel.GOOD
            avgFrameTimeMs <= FRAME_TIME_CRITICAL_MS -> PerformanceLevel.WARNING
            else -> PerformanceLevel.CRITICAL
        }
        
        // Get memory info
        val runtime = Runtime.getRuntime()
        val usedMemoryMB = (runtime.totalMemory() - runtime.freeMemory()) / 1024f / 1024f
        val maxMemoryMB = runtime.maxMemory() / 1024f / 1024f
        val memoryUsagePercent = (usedMemoryMB / maxMemoryMB) * 100f
        
        // Detect GC events (rough estimation)
        val newGCCount = System.gc().let { gcCount++ }
        val gcEvents = newGCCount - lastGCCount
        lastGCCount = newGCCount
        
        _metrics.value = PerformanceMetrics(
            fps = fps.toInt(),
            averageFrameTimeMs = avgFrameTimeMs,
            minFrameTimeMs = minFrameTimeMs,
            maxFrameTimeMs = maxFrameTimeMs,
            usedMemoryMB = usedMemoryMB,
            maxMemoryMB = maxMemoryMB,
            memoryUsagePercent = memoryUsagePercent,
            gcEventsPerSecond = gcEvents,
            performanceLevel = performanceLevel,
            frameDrops = frameHistory.count { it / 1_000_000f > FRAME_TIME_CRITICAL_MS },
            timestamp = currentTime
        )
        
        // Reset counters
        frameCount = 0
        totalFrameTime = 0L
    }
    
    /**
     * Force garbage collection (for testing only)
     */
    fun forceGC() {
        System.gc()
    }
    
    /**
     * Reset all metrics
     */
    fun reset() {
        frameCount = 0
        totalFrameTime = 0L
        frameHistory.clear()
        fpsTimer = System.currentTimeMillis()
        _metrics.value = PerformanceMetrics()
    }
    
    /**
     * Get performance summary as string
     */
    fun getPerformanceSummary(): String {
        val m = metrics.value
        return """
            FPS: ${m.fps}
            Frame Time: ${"%.2f".format(m.averageFrameTimeMs)}ms (min: ${"%.2f".format(m.minFrameTimeMs)}ms, max: ${"%.2f".format(m.maxFrameTimeMs)}ms)
            Memory: ${"%.1f".format(m.usedMemoryMB)}MB / ${"%.1f".format(m.maxMemoryMB)}MB (${"%.1f".format(m.memoryUsagePercent)}%)
            Performance: ${m.performanceLevel}
            Frame Drops: ${m.frameDrops}
        """.trimIndent()
    }
}

/**
 * Performance metrics data class
 */
data class PerformanceMetrics(
    val fps: Int = 0,
    val averageFrameTimeMs: Float = 0f,
    val minFrameTimeMs: Float = 0f,
    val maxFrameTimeMs: Float = 0f,
    val usedMemoryMB: Float = 0f,
    val maxMemoryMB: Float = 0f,
    val memoryUsagePercent: Float = 0f,
    val gcEventsPerSecond: Int = 0,
    val performanceLevel: PerformanceLevel = PerformanceLevel.GOOD,
    val frameDrops: Int = 0,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * Performance level indicators
 */
enum class PerformanceLevel(val description: String) {
    EXCELLENT("60+ FPS, smooth"),
    GOOD("45-60 FPS, mostly smooth"),
    WARNING("30-45 FPS, noticeable stuttering"),
    CRITICAL("< 30 FPS, poor experience")
}