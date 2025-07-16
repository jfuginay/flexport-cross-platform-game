package com.flexport.rendering.math

import kotlinx.serialization.Serializable
import kotlin.math.max
import kotlin.math.min

/**
 * Rectangle class for bounds checking and collision detection
 */
@Serializable
data class Rectangle(
    var x: Float = 0f,
    var y: Float = 0f,
    var width: Float = 0f,
    var height: Float = 0f
) {
    
    /**
     * Set rectangle bounds
     */
    fun set(x: Float, y: Float, width: Float, height: Float): Rectangle {
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        return this
    }
    
    fun set(other: Rectangle): Rectangle {
        this.x = other.x
        this.y = other.y
        this.width = other.width
        this.height = other.height
        return this
    }
    
    /**
     * Get the center X coordinate
     */
    fun getCenterX(): Float = x + width / 2f
    
    /**
     * Get the center Y coordinate
     */
    fun getCenterY(): Float = y + height / 2f
    
    /**
     * Get the center as a Vector2
     */
    fun getCenter(out: Vector2 = Vector2()): Vector2 {
        out.x = getCenterX()
        out.y = getCenterY()
        return out
    }
    
    /**
     * Set the center position
     */
    fun setCenter(centerX: Float, centerY: Float): Rectangle {
        x = centerX - width / 2f
        y = centerY - height / 2f
        return this
    }
    
    fun setCenter(center: Vector2): Rectangle = setCenter(center.x, center.y)
    
    /**
     * Check if a point is inside this rectangle
     */
    fun contains(x: Float, y: Float): Boolean {
        return x >= this.x && x <= this.x + width &&
               y >= this.y && y <= this.y + height
    }
    
    fun contains(point: Vector2): Boolean = contains(point.x, point.y)
    
    /**
     * Check if this rectangle contains another rectangle
     */
    fun contains(other: Rectangle): Boolean {
        return other.x >= x && other.x + other.width <= x + width &&
               other.y >= y && other.y + other.height <= y + height
    }
    
    /**
     * Check if this rectangle overlaps with another
     */
    fun overlaps(other: Rectangle): Boolean {
        return x < other.x + other.width &&
               x + width > other.x &&
               y < other.y + other.height &&
               y + height > other.y
    }
    
    /**
     * Merge this rectangle with another, resulting in the smallest rectangle containing both
     */
    fun merge(other: Rectangle): Rectangle {
        val minX = min(x, other.x)
        val minY = min(y, other.y)
        val maxX = max(x + width, other.x + other.width)
        val maxY = max(y + height, other.y + other.height)
        
        x = minX
        y = minY
        width = maxX - minX
        height = maxY - minY
        
        return this
    }
    
    /**
     * Calculate the aspect ratio (width / height)
     */
    fun getAspectRatio(): Float = if (height == 0f) 0f else width / height
    
    /**
     * Calculate the area
     */
    fun getArea(): Float = width * height
    
    /**
     * Calculate the perimeter
     */
    fun getPerimeter(): Float = 2f * (width + height)
    
    /**
     * Create a copy of this rectangle
     */
    fun cpy(): Rectangle = Rectangle(x, y, width, height)
    
    /**
     * Get vertices of the rectangle
     */
    fun getVertices(out: FloatArray? = null): FloatArray {
        val vertices = out ?: FloatArray(8)
        vertices[0] = x           // Bottom-left X
        vertices[1] = y           // Bottom-left Y
        vertices[2] = x + width   // Bottom-right X
        vertices[3] = y           // Bottom-right Y
        vertices[4] = x + width   // Top-right X
        vertices[5] = y + height  // Top-right Y
        vertices[6] = x           // Top-left X
        vertices[7] = y + height  // Top-left Y
        return vertices
    }
    
    /**
     * Expand the rectangle by the given amount in all directions
     */
    fun expand(amount: Float): Rectangle {
        x -= amount
        y -= amount
        width += amount * 2f
        height += amount * 2f
        return this
    }
    
    /**
     * Check if rectangle is valid (positive width and height)
     */
    fun isValid(): Boolean = width > 0f && height > 0f
    
    override fun toString(): String = "Rectangle($x, $y, $width, $height)"
    
    companion object {
        /**
         * Create a rectangle from center position and size
         */
        fun fromCenter(centerX: Float, centerY: Float, width: Float, height: Float): Rectangle {
            return Rectangle(
                centerX - width / 2f,
                centerY - height / 2f,
                width,
                height
            )
        }
        
        /**
         * Create a rectangle from two points
         */
        fun fromPoints(x1: Float, y1: Float, x2: Float, y2: Float): Rectangle {
            val minX = min(x1, x2)
            val minY = min(y1, y2)
            val maxX = max(x1, x2)
            val maxY = max(y1, y2)
            
            return Rectangle(minX, minY, maxX - minX, maxY - minY)
        }
    }
}