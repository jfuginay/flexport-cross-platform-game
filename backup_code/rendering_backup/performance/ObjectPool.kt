package com.flexport.rendering.performance

import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Generic object pool for reducing garbage collection pressure
 */
class ObjectPool<T>(
    private val factory: () -> T,
    private val reset: (T) -> Unit = {},
    private val maxSize: Int = 100
) {
    private val pool = ConcurrentLinkedQueue<T>()
    
    /**
     * Get an object from the pool or create a new one
     */
    fun obtain(): T {
        return pool.poll() ?: factory()
    }
    
    /**
     * Return an object to the pool
     */
    fun release(obj: T) {
        if (pool.size < maxSize) {
            reset(obj)
            pool.offer(obj)
        }
    }
    
    /**
     * Get current pool size
     */
    fun size(): Int = pool.size
    
    /**
     * Clear all objects from the pool
     */
    fun clear() {
        pool.clear()
    }
}

/**
 * Pool for Vector2 objects
 */
object Vector2Pool {
    private val pool = ObjectPool(
        factory = { com.flexport.rendering.math.Vector2() },
        reset = { it.set(0f, 0f) }
    )
    
    fun obtain(): com.flexport.rendering.math.Vector2 = pool.obtain()
    fun release(vector: com.flexport.rendering.math.Vector2) = pool.release(vector)
}

/**
 * Pool for Vector3 objects
 */
object Vector3Pool {
    private val pool = ObjectPool(
        factory = { com.flexport.rendering.math.Vector3() },
        reset = { it.set(0f, 0f, 0f) }
    )
    
    fun obtain(): com.flexport.rendering.math.Vector3 = pool.obtain()
    fun release(vector: com.flexport.rendering.math.Vector3) = pool.release(vector)
}

/**
 * Pool for Rectangle objects
 */
object RectanglePool {
    private val pool = ObjectPool(
        factory = { com.flexport.rendering.math.Rectangle() },
        reset = { it.set(0f, 0f, 0f, 0f) }
    )
    
    fun obtain(): com.flexport.rendering.math.Rectangle = pool.obtain()
    fun release(rectangle: com.flexport.rendering.math.Rectangle) = pool.release(rectangle)
}