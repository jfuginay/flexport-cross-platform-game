package com.flexport.rendering.math

import kotlin.math.sqrt

/**
 * 2D vector implementation
 */
data class Vector2(
    var x: Float = 0f,
    var y: Float = 0f
) {
    
    fun set(x: Float, y: Float): Vector2 {
        this.x = x
        this.y = y
        return this
    }
    
    fun set(v: Vector2): Vector2 {
        this.x = v.x
        this.y = v.y
        return this
    }
    
    fun add(x: Float, y: Float): Vector2 {
        this.x += x
        this.y += y
        return this
    }
    
    fun add(v: Vector2): Vector2 {
        this.x += v.x
        this.y += v.y
        return this
    }
    
    fun sub(x: Float, y: Float): Vector2 {
        this.x -= x
        this.y -= y
        return this
    }
    
    fun sub(v: Vector2): Vector2 {
        this.x -= v.x
        this.y -= v.y
        return this
    }
    
    fun mul(scalar: Float): Vector2 {
        this.x *= scalar
        this.y *= scalar
        return this
    }
    
    fun div(scalar: Float): Vector2 {
        this.x /= scalar
        this.y /= scalar
        return this
    }
    
    fun dst(x: Float, y: Float): Float {
        val dx = this.x - x
        val dy = this.y - y
        return sqrt(dx * dx + dy * dy)
    }
    
    fun dst(v: Vector2): Float = dst(v.x, v.y)
    
    fun dst2(x: Float, y: Float): Float {
        val dx = this.x - x
        val dy = this.y - y
        return dx * dx + dy * dy
    }
    
    fun dst2(v: Vector2): Float = dst2(v.x, v.y)
    
    fun len(): Float = sqrt(x * x + y * y)
    
    fun len2(): Float = x * x + y * y
    
    fun nor(): Vector2 {
        val len = len()
        if (len != 0f) {
            x /= len
            y /= len
        }
        return this
    }
    
    fun dot(v: Vector2): Float = x * v.x + y * v.y
    
    fun cpy(): Vector2 = Vector2(x, y)
    
    fun isZero(): Boolean = x == 0f && y == 0f
    
    companion object {
        val ZERO = Vector2(0f, 0f)
        val ONE = Vector2(1f, 1f)
        val X = Vector2(1f, 0f)
        val Y = Vector2(0f, 1f)
    }
}