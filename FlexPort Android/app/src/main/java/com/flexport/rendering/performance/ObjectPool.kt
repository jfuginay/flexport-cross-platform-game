package com.flexport.rendering.performance

/**
 * Simple object pool for memory efficiency
 */
class ObjectPool<T>(
    private val factory: () -> T,
    private val reset: (T) -> Unit = {},
    initialSize: Int = 16
) {
    
    private val pool = ArrayDeque<T>(initialSize)
    
    init {
        // Pre-populate pool with initial objects
        repeat(initialSize) {
            pool.addLast(factory())
        }
    }
    
    /**
     * Obtain an object from the pool
     */
    fun obtain(): T {
        return if (pool.isNotEmpty()) {
            pool.removeFirst()
        } else {
            factory()
        }
    }
    
    /**
     * Return an object to the pool
     */
    fun free(obj: T) {
        reset(obj)
        pool.addLast(obj)
        
        // Limit pool size to prevent memory leaks
        if (pool.size > 100) {
            pool.removeFirst()
        }
    }
    
    /**
     * Clear the pool
     */
    fun clear() {
        pool.clear()
    }
    
    /**
     * Get current pool size
     */
    fun size(): Int = pool.size
}