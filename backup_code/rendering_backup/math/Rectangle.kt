package com.flexport.rendering.math

/**
 * Rectangle class for bounds checking and culling
 */
data class Rectangle(
    var x: Float = 0f,
    var y: Float = 0f,
    var width: Float = 0f,
    var height: Float = 0f
) {
    
    fun set(x: Float, y: Float, width: Float, height: Float): Rectangle {
        this.x = x
        this.y = y
        this.width = width
        this.height = height
        return this
    }
    
    fun set(rect: Rectangle): Rectangle {
        this.x = rect.x
        this.y = rect.y
        this.width = rect.width
        this.height = rect.height
        return this
    }
    
    fun contains(x: Float, y: Float): Boolean {
        return x >= this.x && x < this.x + width && y >= this.y && y < this.y + height
    }
    
    fun contains(point: Vector2): Boolean = contains(point.x, point.y)
    
    fun contains(rectangle: Rectangle): Boolean {
        val xmin = rectangle.x
        val xmax = xmin + rectangle.width
        val ymin = rectangle.y
        val ymax = ymin + rectangle.height
        
        return xmin > x && xmin < x + width &&
               xmax > x && xmax < x + width &&
               ymin > y && ymin < y + height &&
               ymax > y && ymax < y + height
    }
    
    fun overlaps(rectangle: Rectangle): Boolean {
        return x < rectangle.x + rectangle.width &&
               x + width > rectangle.x &&
               y < rectangle.y + rectangle.height &&
               y + height > rectangle.y
    }
    
    fun merge(rect: Rectangle): Rectangle {
        val minX = minOf(x, rect.x)
        val maxX = maxOf(x + width, rect.x + rect.width)
        val minY = minOf(y, rect.y)
        val maxY = maxOf(y + height, rect.y + rect.height)
        
        x = minX
        y = minY
        width = maxX - minX
        height = maxY - minY
        
        return this
    }
    
    fun getCenter(vector: Vector2 = Vector2()): Vector2 {
        vector.x = x + width / 2
        vector.y = y + height / 2
        return vector
    }
    
    fun getArea(): Float = width * height
    
    fun getPerimeter(): Float = 2 * (width + height)
    
    fun getAspectRatio(): Float = if (height == 0f) Float.POSITIVE_INFINITY else width / height
}