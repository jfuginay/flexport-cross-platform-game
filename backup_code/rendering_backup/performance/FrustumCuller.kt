package com.flexport.rendering.performance

import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.math.Rectangle

/**
 * Frustum culler for optimizing rendering by culling off-screen objects
 */
class FrustumCuller {
    
    private val cameraFrustum = Rectangle()
    private val expandedFrustum = Rectangle()
    
    /**
     * Update the frustum based on camera
     */
    fun updateFrustum(camera: Camera2D, expansionMargin: Float = 100f) {
        cameraFrustum.set(camera.getVisibleBounds())
        
        // Expand frustum slightly to avoid popping at edges
        expandedFrustum.set(
            cameraFrustum.x - expansionMargin,
            cameraFrustum.y - expansionMargin,
            cameraFrustum.width + expansionMargin * 2,
            cameraFrustum.height + expansionMargin * 2
        )
    }
    
    /**
     * Test if a point is visible
     */
    fun isVisible(x: Float, y: Float): Boolean {
        return expandedFrustum.contains(x, y)
    }
    
    /**
     * Test if a rectangle is visible
     */
    fun isVisible(bounds: Rectangle): Boolean {
        return expandedFrustum.overlaps(bounds)
    }
    
    /**
     * Test if a sprite at position with size is visible
     */
    fun isVisible(x: Float, y: Float, width: Float, height: Float): Boolean {
        // Quick point test first
        if (isVisible(x + width * 0.5f, y + height * 0.5f)) {
            return true
        }
        
        // Full bounds test
        return expandedFrustum.overlaps(
            Rectangle(x, y, width, height)
        )
    }
    
    /**
     * Get the current frustum bounds
     */
    fun getFrustum(): Rectangle = expandedFrustum
    
    /**
     * Get visible area in world coordinates
     */
    fun getVisibleArea(): Float = expandedFrustum.getArea()
}

/**
 * Spatial partitioning for efficient culling of large numbers of objects
 */
class SpatialGrid(
    private val cellSize: Float = 256f
) {
    private val grid = mutableMapOf<Long, MutableList<SpatialObject>>()
    private val objectCells = mutableMapOf<SpatialObject, MutableSet<Long>>()
    
    /**
     * Add an object to the spatial grid
     */
    fun addObject(obj: SpatialObject) {
        removeObject(obj) // Remove from old cells first
        
        val cells = getCellsForBounds(obj.bounds)
        objectCells[obj] = cells.toMutableSet()
        
        for (cellKey in cells) {
            grid.getOrPut(cellKey) { mutableListOf() }.add(obj)
        }
    }
    
    /**
     * Remove an object from the spatial grid
     */
    fun removeObject(obj: SpatialObject) {
        objectCells[obj]?.let { cells ->
            for (cellKey in cells) {
                grid[cellKey]?.remove(obj)
                if (grid[cellKey]?.isEmpty() == true) {
                    grid.remove(cellKey)
                }
            }
            objectCells.remove(obj)
        }
    }
    
    /**
     * Update an object's position in the grid
     */
    fun updateObject(obj: SpatialObject) {
        addObject(obj) // This will remove from old cells and add to new ones
    }
    
    /**
     * Query objects that potentially intersect with the given bounds
     */
    fun queryRegion(bounds: Rectangle): List<SpatialObject> {
        val result = mutableSetOf<SpatialObject>()
        val cells = getCellsForBounds(bounds)
        
        for (cellKey in cells) {
            grid[cellKey]?.let { objects ->
                for (obj in objects) {
                    if (obj.bounds.overlaps(bounds)) {
                        result.add(obj)
                    }
                }
            }
        }
        
        return result.toList()
    }
    
    /**
     * Clear all objects from the grid
     */
    fun clear() {
        grid.clear()
        objectCells.clear()
    }
    
    private fun getCellsForBounds(bounds: Rectangle): List<Long> {
        val cells = mutableListOf<Long>()
        
        val startX = (bounds.x / cellSize).toInt()
        val startY = (bounds.y / cellSize).toInt()
        val endX = ((bounds.x + bounds.width) / cellSize).toInt()
        val endY = ((bounds.y + bounds.height) / cellSize).toInt()
        
        for (x in startX..endX) {
            for (y in startY..endY) {
                cells.add(getCellKey(x, y))
            }
        }
        
        return cells
    }
    
    private fun getCellKey(x: Int, y: Int): Long {
        return (x.toLong() shl 32) or (y.toLong() and 0xFFFFFFFFL)
    }
    
    /**
     * Get debug info about the grid
     */
    fun getDebugInfo(): SpatialGridDebugInfo {
        return SpatialGridDebugInfo(
            totalCells = grid.size,
            totalObjects = objectCells.size,
            averageObjectsPerCell = if (grid.isEmpty()) 0f else grid.values.sumOf { it.size } / grid.size.toFloat()
        )
    }
}

/**
 * Interface for objects that can be spatially partitioned
 */
interface SpatialObject {
    val bounds: Rectangle
}

/**
 * Debug information for spatial grid
 */
data class SpatialGridDebugInfo(
    val totalCells: Int,
    val totalObjects: Int,
    val averageObjectsPerCell: Float
)