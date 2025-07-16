package com.flexport.map.rendering

import com.flexport.rendering.math.Vector2
import com.flexport.rendering.opengl.GLSpriteBatch
import kotlin.math.*

/**
 * Specialized renderer for drawing trade routes and shipping lanes
 */
class RouteRenderer {
    
    private val lineSegments = mutableListOf<LineSegment>()
    private val dashPatterns = mapOf(
        LineDash.SHORT to floatArrayOf(5.0f, 5.0f),
        LineDash.MEDIUM to floatArrayOf(10.0f, 10.0f),
        LineDash.LONG to floatArrayOf(20.0f, 10.0f),
        LineDash.SOLID to floatArrayOf(1.0f, 0.0f)
    )
    
    /**
     * Render a line between two points
     */
    fun renderLine(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        dash: LineDash = LineDash.NONE
    ) {
        when (dash) {
            LineDash.NONE -> renderSolidLine(spriteBatch, start, end, width)
            else -> renderDashedLine(spriteBatch, start, end, width, dash)
        }
    }
    
    /**
     * Render animated line with flowing effects
     */
    fun renderAnimatedLine(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        animationOffset: Float,
        dash: LineDash = LineDash.SOLID
    ) {
        // Render base line
        renderLine(spriteBatch, start, end, width, dash)
        
        // Add flowing animation effect
        renderFlowEffect(spriteBatch, start, end, width * 0.3f, animationOffset)
    }
    
    /**
     * Render curved route between multiple points
     */
    fun renderCurvedRoute(
        spriteBatch: GLSpriteBatch,
        points: List<Vector2>,
        width: Float,
        curvature: Float = 0.2f
    ) {
        if (points.size < 2) return
        
        for (i in 0 until points.size - 1) {
            val start = points[i]
            val end = points[i + 1]
            
            if (curvature > 0.0f && points.size > 2) {
                renderCurvedSegment(spriteBatch, start, end, width, curvature)
            } else {
                renderSolidLine(spriteBatch, start, end, width)
            }
        }
    }
    
    /**
     * Render route with cargo capacity visualization
     */
    fun renderCapacityRoute(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        baseWidth: Float,
        capacityUtilization: Float // 0.0 to 1.0
    ) {
        val utilizedWidth = baseWidth * capacityUtilization
        val unusedWidth = baseWidth - utilizedWidth
        
        // Render unused capacity (gray)
        if (unusedWidth > 0) {
            val oldColor = spriteBatch.color
            spriteBatch.setColor(0.5f, 0.5f, 0.5f, 0.6f)
            renderSolidLine(spriteBatch, start, end, baseWidth)
            spriteBatch.color = oldColor
        }
        
        // Render utilized capacity (colored)
        if (utilizedWidth > 0) {
            renderSolidLine(spriteBatch, start, end, utilizedWidth)
        }
    }
    
    /**
     * Render route with directional arrows
     */
    fun renderDirectionalRoute(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        arrowSpacing: Float = 50.0f
    ) {
        // Render base line
        renderSolidLine(spriteBatch, start, end, width)
        
        // Add directional arrows
        val distance = start.dst(end)
        val direction = Vector2(end.x - start.x, end.y - start.y).nor()
        val numArrows = max(1, (distance / arrowSpacing).toInt())
        
        for (i in 1..numArrows) {
            val progress = i.toFloat() / (numArrows + 1)
            val arrowPos = Vector2(
                start.x + direction.x * distance * progress,
                start.y + direction.y * distance * progress
            )
            
            renderArrow(spriteBatch, arrowPos, direction, width * 1.5f)
        }
    }
    
    private fun renderSolidLine(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float
    ) {
        val distance = start.dst(end)
        val angle = atan2(end.y - start.y, end.x - start.x) * 180.0f / PI.toFloat()
        
        spriteBatch.draw(
            null, // Use default white texture
            start.x,
            start.y - width / 2,
            0f,
            width / 2,
            distance,
            width,
            1f,
            1f,
            angle
        )
    }
    
    private fun renderDashedLine(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        dash: LineDash
    ) {
        val pattern = dashPatterns[dash] ?: return
        val dashLength = pattern[0]
        val gapLength = pattern[1]
        val totalLength = start.dst(end)
        val direction = Vector2(end.x - start.x, end.y - start.y).nor()
        
        var currentDistance = 0.0f
        var isDash = true
        
        while (currentDistance < totalLength) {
            val segmentLength = if (isDash) dashLength else gapLength
            val segmentEnd = min(currentDistance + segmentLength, totalLength)
            
            if (isDash) {
                val segmentStart = Vector2(
                    start.x + direction.x * currentDistance,
                    start.y + direction.y * currentDistance
                )
                val segmentEndPoint = Vector2(
                    start.x + direction.x * segmentEnd,
                    start.y + direction.y * segmentEnd
                )
                
                renderSolidLine(spriteBatch, segmentStart, segmentEndPoint, width)
            }
            
            currentDistance = segmentEnd
            isDash = !isDash
        }
    }
    
    private fun renderCurvedSegment(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        curvature: Float
    ) {
        // Create bezier curve control point
        val midpoint = Vector2((start.x + end.x) / 2, (start.y + end.y) / 2)
        val distance = start.dst(end)
        val perpendicular = Vector2(-(end.y - start.y), end.x - start.x).nor()
        val controlPoint = Vector2(
            midpoint.x + perpendicular.x * distance * curvature,
            midpoint.y + perpendicular.y * distance * curvature
        )
        
        // Render curve as series of line segments
        val segments = max(8, (distance / 20.0f).toInt())
        var previousPoint = start
        
        for (i in 1..segments) {
            val t = i.toFloat() / segments
            val currentPoint = calculateBezierPoint(start, controlPoint, end, t)
            renderSolidLine(spriteBatch, previousPoint, currentPoint, width)
            previousPoint = currentPoint
        }
    }
    
    private fun renderFlowEffect(
        spriteBatch: GLSpriteBatch,
        start: Vector2,
        end: Vector2,
        width: Float,
        animationOffset: Float
    ) {
        val distance = start.dst(end)
        val direction = Vector2(end.x - start.x, end.y - start.y).nor()
        val flowSpacing = 30.0f
        val flowLength = 15.0f
        
        var currentOffset = animationOffset % flowSpacing
        
        while (currentOffset < distance) {
            val flowStart = Vector2(
                start.x + direction.x * currentOffset,
                start.y + direction.y * currentOffset
            )
            val flowEnd = Vector2(
                start.x + direction.x * min(currentOffset + flowLength, distance),
                start.y + direction.y * min(currentOffset + flowLength, distance)
            )
            
            val oldColor = spriteBatch.color
            spriteBatch.setColor(1.0f, 1.0f, 1.0f, 0.8f)
            renderSolidLine(spriteBatch, flowStart, flowEnd, width)
            spriteBatch.color = oldColor
            
            currentOffset += flowSpacing
        }
    }
    
    private fun renderArrow(
        spriteBatch: GLSpriteBatch,
        position: Vector2,
        direction: Vector2,
        size: Float
    ) {
        val arrowLength = size
        val arrowWidth = size * 0.6f
        
        // Calculate arrow points
        val tip = Vector2(
            position.x + direction.x * arrowLength / 2,
            position.y + direction.y * arrowLength / 2
        )
        
        val base = Vector2(
            position.x - direction.x * arrowLength / 2,
            position.y - direction.y * arrowLength / 2
        )
        
        val perpendicular = Vector2(-direction.y, direction.x)
        
        val leftWing = Vector2(
            base.x + perpendicular.x * arrowWidth / 2,
            base.y + perpendicular.y * arrowWidth / 2
        )
        
        val rightWing = Vector2(
            base.x - perpendicular.x * arrowWidth / 2,
            base.y - perpendicular.y * arrowWidth / 2
        )
        
        // Render arrow as triangle
        renderTriangle(spriteBatch, tip, leftWing, rightWing)
    }
    
    private fun renderTriangle(
        spriteBatch: GLSpriteBatch,
        point1: Vector2,
        point2: Vector2,
        point3: Vector2
    ) {
        // Simple triangle rendering using lines
        renderSolidLine(spriteBatch, point1, point2, 2.0f)
        renderSolidLine(spriteBatch, point2, point3, 2.0f)
        renderSolidLine(spriteBatch, point3, point1, 2.0f)
    }
    
    private fun calculateBezierPoint(
        start: Vector2,
        control: Vector2,
        end: Vector2,
        t: Float
    ): Vector2 {
        val oneMinusT = 1.0f - t
        return Vector2(
            oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }
}

/**
 * Manages animations for route rendering
 */
class RouteAnimationManager {
    
    private val flowAnimations = mutableMapOf<String, FlowAnimation>()
    private var totalTime = 0.0f
    
    fun update(deltaTime: Float) {
        totalTime += deltaTime
        flowAnimations.values.forEach { it.update(deltaTime) }
    }
    
    fun getFlowAnimation(routeId: String): FlowAnimation {
        return flowAnimations.getOrPut(routeId) {
            FlowAnimation(speed = 50.0f) // 50 pixels per second
        }
    }
    
    fun getTotalTime(): Float = totalTime
    
    fun removeAnimation(routeId: String) {
        flowAnimations.remove(routeId)
    }
    
    fun clearAnimations() {
        flowAnimations.clear()
    }
}

/**
 * Animation for cargo flow along routes
 */
class FlowAnimation(
    private val speed: Float = 50.0f // pixels per second
) {
    private var currentOffset = 0.0f
    
    fun update(deltaTime: Float) {
        currentOffset += speed * deltaTime
    }
    
    fun getCurrentOffset(deltaTime: Float): Float {
        return currentOffset
    }
    
    fun reset() {
        currentOffset = 0.0f
    }
}

/**
 * Line segment for rendering
 */
private data class LineSegment(
    val start: Vector2,
    val end: Vector2,
    val width: Float,
    val color: Int
)