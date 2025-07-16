package com.flexport.rendering.math

import kotlin.math.*

/**
 * 2D Vector class for touch input and rendering calculations
 */
data class Vector2(
    var x: Float = 0f,
    var y: Float = 0f
) {
    
    constructor(other: Vector2) : this(other.x, other.y)
    
    /**
     * Set vector components
     */
    fun set(x: Float, y: Float): Vector2 {
        this.x = x
        this.y = y
        return this
    }
    
    fun set(other: Vector2): Vector2 {
        this.x = other.x
        this.y = other.y
        return this
    }
    
    /**
     * Create a copy of this vector
     */
    fun cpy(): Vector2 = Vector2(x, y)
    
    /**
     * Add another vector to this one
     */
    fun add(other: Vector2): Vector2 {
        x += other.x
        y += other.y
        return this
    }
    
    fun add(dx: Float, dy: Float): Vector2 {
        x += dx
        y += dy
        return this
    }
    
    /**
     * Subtract another vector from this one
     */
    fun sub(other: Vector2): Vector2 {
        x -= other.x
        y -= other.y
        return this
    }
    
    fun sub(dx: Float, dy: Float): Vector2 {
        x -= dx
        y -= dy
        return this
    }
    
    /**
     * Multiply by scalar
     */
    fun scl(scalar: Float): Vector2 {
        x *= scalar
        y *= scalar
        return this
    }
    
    /**
     * Multiply by scalar (alias for scl)
     */
    fun mul(scalar: Float): Vector2 = scl(scalar)
    
    /**
     * Get length (magnitude) of vector
     */
    fun len(): Float = sqrt(x * x + y * y)
    
    /**
     * Get squared length (faster than len() when only comparing)
     */
    fun len2(): Float = x * x + y * y
    
    /**
     * Normalize vector to unit length
     */
    fun nor(): Vector2 {
        val length = len()
        if (length != 0f) {
            x /= length
            y /= length
        }
        return this
    }
    
    /**
     * Calculate distance to another point
     */
    fun dst(other: Vector2): Float {
        val dx = x - other.x
        val dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /**
     * Calculate squared distance (faster than dst() when only comparing)
     */
    fun dst2(other: Vector2): Float {
        val dx = x - other.x
        val dy = y - other.y
        return dx * dx + dy * dy
    }
    
    /**
     * Calculate dot product
     */
    fun dot(other: Vector2): Float = x * other.x + y * other.y
    
    /**
     * Calculate cross product (2D cross product returns scalar)
     */
    fun crs(other: Vector2): Float = x * other.y - y * other.x
    
    /**
     * Get angle in radians
     */
    fun angle(): Float = atan2(y, x)
    
    /**
     * Get angle in degrees
     */
    fun angleDeg(): Float = angle() * 180f / PI.toFloat()
    
    /**
     * Rotate vector by angle in radians
     */
    fun rotate(radians: Float): Vector2 {
        val cos = cos(radians)
        val sin = sin(radians)
        val newX = x * cos - y * sin
        val newY = x * sin + y * cos
        x = newX
        y = newY
        return this
    }
    
    /**
     * Linear interpolation toward another vector
     */
    fun lerp(target: Vector2, alpha: Float): Vector2 {
        val invAlpha = 1f - alpha
        x = x * invAlpha + target.x * alpha
        y = y * invAlpha + target.y * alpha
        return this
    }
    
    /**
     * Check if vector is zero
     */
    fun isZero(): Boolean = x == 0f && y == 0f
    
    /**
     * Check if vector is near zero (within epsilon)
     */
    fun isZero(epsilon: Float): Boolean = len2() < epsilon * epsilon
    
    /**
     * Set to zero
     */
    fun setZero(): Vector2 {
        x = 0f
        y = 0f
        return this
    }
    
    override fun toString(): String = "($x, $y)"
    
    companion object {
        val ZERO = Vector2(0f, 0f)
        val X = Vector2(1f, 0f)
        val Y = Vector2(0f, 1f)
        
        /**
         * Calculate distance between two points
         */
        fun dst(x1: Float, y1: Float, x2: Float, y2: Float): Float {
            val dx = x1 - x2
            val dy = y1 - y2
            return sqrt(dx * dx + dy * dy)
        }
        
        /**
         * Calculate squared distance between two points
         */
        fun dst2(x1: Float, y1: Float, x2: Float, y2: Float): Float {
            val dx = x1 - x2
            val dy = y1 - y2
            return dx * dx + dy * dy
        }
    }
}