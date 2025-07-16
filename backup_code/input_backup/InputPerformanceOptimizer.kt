package com.flexport.input

import com.flexport.rendering.math.Vector2
import com.flexport.rendering.performance.ObjectPool
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableSharedFlow
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Performance optimizer for touch input processing
 */
class InputPerformanceOptimizer {
    
    // Object pools for frequently allocated objects
    private val vector2Pool = ObjectPool<Vector2>(initialSize = 50) { Vector2() }
    private val touchEventPool = ObjectPool<TouchEvent>(initialSize = 30) { 
        TouchEvent(0, TouchEvent.TouchAction.DOWN, Vector2(), Vector2())
    }
    private val gestureEventPool = ObjectPool<GestureEvent>(initialSize = 20) {
        GestureEvent.Tap(Vector2(), Vector2())
    }
    
    // Input batching
    private val inputBatchQueue = ConcurrentLinkedQueue<TouchEvent>()
    private val gestureBatchQueue = ConcurrentLinkedQueue<GestureEvent>()
    private var lastBatchTime = 0L
    private val batchIntervalMs = 16L // ~60 FPS
    
    // Frame rate limiting
    private var lastInputProcessTime = 0L
    private val minInputIntervalNs = 8_333_333L // ~120 FPS limit for input processing
    
    // Input deduplication
    private val lastProcessedPositions = mutableMapOf<Int, Vector2>()
    private val positionThreshold = 1f // Minimum movement to process
    
    // Statistics
    var totalEventsProcessed = 0L
        private set
    var totalEventsBatched = 0L
        private set
    var totalEventsDropped = 0L
        private set
    
    /**
     * Get a Vector2 from the object pool
     */
    fun getVector2(): Vector2 = vector2Pool.obtain()
    
    /**
     * Return a Vector2 to the object pool
     */
    fun returnVector2(vector: Vector2) {
        vector.set(0f, 0f)
        vector2Pool.free(vector)
    }
    
    /**
     * Get a TouchEvent from the pool
     */
    fun getTouchEvent(): TouchEvent = touchEventPool.obtain()
    
    /**
     * Return a TouchEvent to the pool
     */
    fun returnTouchEvent(event: TouchEvent) {
        touchEventPool.free(event)
    }
    
    /**
     * Create an optimized TouchEvent with pooled objects
     */
    fun createTouchEvent(
        pointerId: Int,
        action: TouchEvent.TouchAction,
        worldX: Float,
        worldY: Float,
        screenX: Float,
        screenY: Float,
        timestamp: Long = System.currentTimeMillis(),
        pressure: Float = 1f
    ): TouchEvent {
        val worldPos = getVector2().set(worldX, worldY)
        val screenPos = getVector2().set(screenX, screenY)
        
        return TouchEvent(
            pointerId = pointerId,
            action = action,
            worldPosition = worldPos,
            screenPosition = screenPos,
            timestamp = timestamp,
            pressure = pressure
        )
    }
    
    /**
     * Check if input should be processed based on frame rate limiting
     */
    fun shouldProcessInput(): Boolean {
        val currentTime = System.nanoTime()
        val timeSinceLastInput = currentTime - lastInputProcessTime
        
        if (timeSinceLastInput >= minInputIntervalNs) {
            lastInputProcessTime = currentTime
            return true
        }
        
        return false
    }
    
    /**
     * Check if movement is significant enough to process
     */
    fun isSignificantMovement(pointerId: Int, worldX: Float, worldY: Float): Boolean {
        val lastPosition = lastProcessedPositions[pointerId]
        
        if (lastPosition == null) {
            lastProcessedPositions[pointerId] = getVector2().set(worldX, worldY)
            return true
        }
        
        val distance = lastPosition.dst(worldX, worldY)
        
        if (distance >= positionThreshold) {
            lastPosition.set(worldX, worldY)
            return true
        }
        
        return false
    }
    
    /**
     * Add touch event to batch queue
     */
    fun batchTouchEvent(event: TouchEvent) {
        inputBatchQueue.offer(event)
        totalEventsBatched++
    }
    
    /**
     * Add gesture event to batch queue
     */
    fun batchGestureEvent(event: GestureEvent) {
        gestureBatchQueue.offer(event)
        totalEventsBatched++
    }
    
    /**
     * Process batched events and emit them
     */
    fun processBatchedEvents(
        touchEventFlow: MutableSharedFlow<TouchEvent>,
        gestureEventFlow: MutableSharedFlow<GestureEvent>
    ) {
        val currentTime = System.currentTimeMillis()
        
        if (currentTime - lastBatchTime >= batchIntervalMs) {
            // Process touch events
            var processedCount = 0
            while (inputBatchQueue.isNotEmpty() && processedCount < 50) { // Limit batch size
                val event = inputBatchQueue.poll()
                if (event != null) {
                    touchEventFlow.tryEmit(event)
                    totalEventsProcessed++
                    processedCount++
                }
            }
            
            // Process gesture events
            processedCount = 0
            while (gestureBatchQueue.isNotEmpty() && processedCount < 20) { // Limit batch size
                val event = gestureBatchQueue.poll()
                if (event != null) {
                    gestureEventFlow.tryEmit(event)
                    totalEventsProcessed++
                    processedCount++
                }
            }
            
            lastBatchTime = currentTime
        }
    }
    
    /**
     * Optimize touch event processing by filtering redundant events
     */
    fun optimizeTouchEvents(events: List<TouchEvent>): List<TouchEvent> {
        if (events.isEmpty()) return events
        
        val optimizedEvents = mutableListOf<TouchEvent>()
        val lastEventByPointer = mutableMapOf<Int, TouchEvent>()
        
        for (event in events) {
            val lastEvent = lastEventByPointer[event.pointerId]
            
            when (event.action) {
                TouchEvent.TouchAction.DOWN, TouchEvent.TouchAction.UP, TouchEvent.TouchAction.CANCEL -> {
                    // Always keep down/up/cancel events
                    optimizedEvents.add(event)
                    lastEventByPointer[event.pointerId] = event
                }
                
                TouchEvent.TouchAction.MOVE -> {
                    if (lastEvent == null || 
                        isSignificantMovement(event.pointerId, event.worldPosition.x, event.worldPosition.y) ||
                        event.timestamp - lastEvent.timestamp >= 16L) { // At least 16ms apart
                        
                        optimizedEvents.add(event)
                        lastEventByPointer[event.pointerId] = event
                    } else {
                        totalEventsDropped++
                    }
                }
            }
        }
        
        return optimizedEvents
    }
    
    /**
     * Spatial partitioning for touch hit testing optimization
     */
    class SpatialGrid(
        private val cellSize: Float = 100f
    ) {
        private val grid = mutableMapOf<Long, MutableList<TouchableEntity>>()
        
        data class TouchableEntity(
            val entityId: Int,
            val bounds: com.flexport.rendering.math.Rectangle,
            val priority: Int = 0
        )
        
        fun clear() {
            grid.clear()
        }
        
        fun addEntity(entity: TouchableEntity) {
            val cells = getCellsForBounds(entity.bounds)
            cells.forEach { cellKey ->
                grid.getOrPut(cellKey) { mutableListOf() }.add(entity)
            }
        }
        
        fun getEntitiesAt(x: Float, y: Float): List<TouchableEntity> {
            val cellKey = getCellKey(x, y)
            return grid[cellKey]?.filter { entity ->
                entity.bounds.contains(x, y)
            }?.sortedByDescending { it.priority } ?: emptyList()
        }
        
        private fun getCellKey(x: Float, y: Float): Long {
            val cellX = (x / cellSize).toLong()
            val cellY = (y / cellSize).toLong()
            return (cellX shl 32) or (cellY and 0xFFFFFFFFL)
        }
        
        private fun getCellsForBounds(bounds: com.flexport.rendering.math.Rectangle): List<Long> {
            val cells = mutableListOf<Long>()
            
            val startCellX = (bounds.x / cellSize).toLong()
            val endCellX = ((bounds.x + bounds.width) / cellSize).toLong()
            val startCellY = (bounds.y / cellSize).toLong()
            val endCellY = ((bounds.y + bounds.height) / cellSize).toLong()
            
            for (cellX in startCellX..endCellX) {
                for (cellY in startCellY..endCellY) {
                    cells.add((cellX shl 32) or (cellY and 0xFFFFFFFFL))
                }
            }
            
            return cells
        }
    }
    
    /**
     * Input event compression for network sync
     */
    fun compressInputEvents(events: List<TouchEvent>): ByteArray {
        // This is a simplified compression - in a real implementation you'd use
        // proper binary serialization and compression algorithms
        
        val compressed = mutableListOf<Byte>()
        
        for (event in events) {
            // Compress by delta encoding positions
            compressed.addAll(event.pointerId.toByte().let { listOf(it) })
            compressed.addAll(event.action.ordinal.toByte().let { listOf(it) })
            // Add compressed position data...
        }
        
        return compressed.toByteArray()
    }
    
    /**
     * Get performance statistics
     */
    fun getPerformanceStats(): PerformanceStats {
        return PerformanceStats(
            totalEventsProcessed = totalEventsProcessed,
            totalEventsBatched = totalEventsBatched,
            totalEventsDropped = totalEventsDropped,
            inputQueueSize = inputBatchQueue.size,
            gestureQueueSize = gestureBatchQueue.size,
            vector2PoolSize = vector2Pool.getFreeObjectCount(),
            touchEventPoolSize = touchEventPool.getFreeObjectCount()
        )
    }
    
    /**
     * Reset performance statistics
     */
    fun resetStats() {
        totalEventsProcessed = 0L
        totalEventsBatched = 0L
        totalEventsDropped = 0L
    }
    
    /**
     * Clear all optimizations and pools
     */
    fun clear() {
        inputBatchQueue.clear()
        gestureBatchQueue.clear()
        lastProcessedPositions.values.forEach { returnVector2(it) }
        lastProcessedPositions.clear()
        vector2Pool.clear()
        touchEventPool.clear()
        gestureEventPool.clear()
        resetStats()
    }
    
    data class PerformanceStats(
        val totalEventsProcessed: Long,
        val totalEventsBatched: Long,
        val totalEventsDropped: Long,
        val inputQueueSize: Int,
        val gestureQueueSize: Int,
        val vector2PoolSize: Int,
        val touchEventPoolSize: Int
    ) {
        val dropRate: Float get() = if (totalEventsProcessed > 0) totalEventsDropped.toFloat() / totalEventsProcessed else 0f
        val batchEfficiency: Float get() = if (totalEventsBatched > 0) totalEventsProcessed.toFloat() / totalEventsBatched else 0f
    }
}