package com.flexport.game.graphics

import android.content.Context
import android.opengl.GLES30
import android.opengl.Matrix
import com.flexport.game.models.Ship
import com.flexport.game.graphics.shaders.ShipShader
import com.flexport.game.graphics.sprites.AnimatedSprite
import com.flexport.game.graphics.sprites.WakeEffect
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.*

/**
 * High-performance ship sprite renderer with animations and effects
 * Features: Sprite batching, wake trails, animated ship movement, LOD system
 */
class ShipSpriteRenderer(private val context: Context) {
    
    // Shader and rendering components
    private lateinit var shipShader: ShipShader
    private lateinit var wakeEffect: WakeEffect
    
    // Sprite batching for performance
    private val maxSpritesPerBatch = 256
    private val verticesPerSprite = 4
    private val indicesPerSprite = 6
    private val floatsPerVertex = 8 // Position(3) + TexCoord(2) + Color(3)
    
    private lateinit var batchVertexBuffer: FloatBuffer
    private lateinit var batchIndexBuffer: ByteBuffer
    private var currentBatchSize = 0
    
    // Ship animation states
    private val shipAnimations = mutableMapOf<String, ShipAnimation>()
    
    // Performance monitoring
    private var lastBatchCount = 0
    private var totalSpritesRendered = 0
    
    // LOD distances
    private val lodDistances = floatArrayOf(50f, 100f, 200f, 500f)
    
    fun initialize() {
        // Initialize shader
        shipShader = ShipShader(context)
        
        // Initialize wake effect system
        wakeEffect = WakeEffect(context)
        
        // Setup sprite batching buffers
        setupBatchingBuffers()
        
        // OpenGL setup
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
    }
    
    private fun setupBatchingBuffers() {
        // Vertex buffer for batched sprites
        val totalVertices = maxSpritesPerBatch * verticesPerSprite * floatsPerVertex
        val vbb = ByteBuffer.allocateDirect(totalVertices * 4)
        vbb.order(ByteOrder.nativeOrder())
        batchVertexBuffer = vbb.asFloatBuffer()
        
        // Index buffer for batched sprites
        val totalIndices = maxSpritesPerBatch * indicesPerSprite
        batchIndexBuffer = ByteBuffer.allocateDirect(totalIndices)
        batchIndexBuffer.order(ByteOrder.nativeOrder())
        
        // Generate index pattern for quads
        for (i in 0 until maxSpritesPerBatch) {
            val baseIndex = (i * verticesPerSprite).toByte()
            // Triangle 1
            batchIndexBuffer.put(baseIndex)
            batchIndexBuffer.put((baseIndex + 1).toByte())
            batchIndexBuffer.put((baseIndex + 2).toByte())
            // Triangle 2
            batchIndexBuffer.put(baseIndex)
            batchIndexBuffer.put((baseIndex + 2).toByte())
            batchIndexBuffer.put((baseIndex + 3).toByte())
        }
        batchIndexBuffer.position(0)
    }
    
    fun renderShips(
        ships: List<Ship>,
        viewMatrix: FloatArray,
        projectionMatrix: FloatArray,
        cameraPosition: FloatArray,
        deltaTime: Float
    ) {
        if (ships.isEmpty()) return
        
        totalSpritesRendered = 0
        lastBatchCount = 0
        
        // Sort ships by distance for proper alpha blending and LOD
        val sortedShips = ships.sortedBy { ship ->
            val shipPos = getShipWorldPosition(ship)
            val dx = cameraPosition[0] - shipPos[0]
            val dy = cameraPosition[1] - shipPos[1] 
            val dz = cameraPosition[2] - shipPos[2]
            sqrt(dx * dx + dy * dy + dz * dz)
        }
        
        // Calculate view-projection matrix
        val vpMatrix = FloatArray(16)
        Matrix.multiplyMM(vpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        
        // Update ship animations
        updateShipAnimations(sortedShips, deltaTime)
        
        // Render wake effects first (behind ships)
        renderWakeEffects(sortedShips, vpMatrix, deltaTime)
        
        // Batch render ships by LOD level
        shipShader.use()
        shipShader.setViewProjectionMatrix(vpMatrix)
        shipShader.setTime(System.currentTimeMillis() / 1000f)
        
        // Render ships in batches
        var currentBatch = mutableListOf<ShipRenderData>()
        
        for (ship in sortedShips) {
            val distance = getDistanceToCamera(ship, cameraPosition)
            val lodLevel = getLODLevel(distance)
            
            // Skip ships that are too far away
            if (lodLevel >= 4) continue
            
            val renderData = createShipRenderData(ship, distance, lodLevel, deltaTime)
            currentBatch.add(renderData)
            
            // Flush batch if full or LOD level changes
            if (currentBatch.size >= maxSpritesPerBatch || 
                (currentBatch.isNotEmpty() && currentBatch.last().lodLevel != lodLevel)) {
                renderShipBatch(currentBatch, vpMatrix)
                currentBatch.clear()
                lastBatchCount++
            }
        }
        
        // Render remaining ships in batch
        if (currentBatch.isNotEmpty()) {
            renderShipBatch(currentBatch, vpMatrix)
            lastBatchCount++
        }
    }
    
    private fun updateShipAnimations(ships: List<Ship>, deltaTime: Float) {
        ships.forEach { ship ->
            val animation = shipAnimations.getOrPut(ship.id) {
                ShipAnimation(ship)
            }
            animation.update(ship, deltaTime)
        }
    }
    
    private fun renderWakeEffects(ships: List<Ship>, vpMatrix: FloatArray, deltaTime: Float) {
        ships.forEach { ship ->
            if (ship.velocity > 0.1f) { // Only render wake for moving ships
                val shipPos = getShipWorldPosition(ship)
                val animation = shipAnimations[ship.id]
                val heading = animation?.heading ?: 0f
                
                wakeEffect.addWakePoint(
                    shipPos[0], shipPos[1], shipPos[2],
                    heading, ship.velocity, deltaTime
                )
            }
        }
        
        wakeEffect.render(vpMatrix, deltaTime)
    }
    
    private fun createShipRenderData(
        ship: Ship, 
        distance: Float, 
        lodLevel: Int, 
        deltaTime: Float
    ): ShipRenderData {
        val animation = shipAnimations[ship.id]!!
        val worldPos = getShipWorldPosition(ship)
        
        // Calculate sprite size based on LOD and ship type
        val baseSize = getShipBaseSize(ship.shipType)
        val lodScale = when (lodLevel) {
            0 -> 1.0f      // Full detail
            1 -> 0.8f      // High detail
            2 -> 0.6f      // Medium detail
            3 -> 0.4f      // Low detail
            else -> 0.2f   // Minimal detail
        }
        val finalSize = baseSize * lodScale
        
        // Calculate color based on ship status and efficiency
        val baseColor = getShipTypeColor(ship.shipType)
        val efficiencyFactor = (ship.fuelEfficiency / 100f).coerceIn(0f, 1f)
        val statusColor = when {
            ship.velocity < 0.1f -> floatArrayOf(0.7f, 0.7f, 0.7f, 1f) // Stationary
            efficiencyFactor > 0.8f -> floatArrayOf(0.2f, 0.8f, 0.2f, 1f) // High efficiency
            efficiencyFactor < 0.3f -> floatArrayOf(0.8f, 0.3f, 0.2f, 1f) // Low efficiency
            else -> baseColor
        }
        
        return ShipRenderData(
            ship = ship,
            worldPosition = worldPos,
            size = finalSize,
            rotation = animation.heading,
            color = statusColor,
            textureIndex = getShipTextureIndex(ship.shipType),
            lodLevel = lodLevel,
            animationPhase = animation.bobPhase
        )
    }
    
    private fun renderShipBatch(batch: List<ShipRenderData>, vpMatrix: FloatArray) {
        if (batch.isEmpty()) return
        
        batchVertexBuffer.clear()
        currentBatchSize = batch.size
        
        // Fill vertex buffer with sprite data
        batch.forEach { renderData ->
            addSpriteToBuffer(renderData)
        }
        
        batchVertexBuffer.position(0)
        
        // Set up vertex attributes
        val positionHandle = shipShader.getAttributeLocation("a_Position")
        val texCoordHandle = shipShader.getAttributeLocation("a_TexCoord")
        val colorHandle = shipShader.getAttributeLocation("a_Color")
        
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glEnableVertexAttribArray(texCoordHandle)
        GLES30.glEnableVertexAttribArray(colorHandle)
        
        val stride = floatsPerVertex * 4 // 4 bytes per float
        
        // Position attribute (3 floats)
        batchVertexBuffer.position(0)
        GLES30.glVertexAttribPointer(positionHandle, 3, GLES30.GL_FLOAT, false, stride, batchVertexBuffer)
        
        // Texture coordinate attribute (2 floats, offset by 3)
        batchVertexBuffer.position(3)
        GLES30.glVertexAttribPointer(texCoordHandle, 2, GLES30.GL_FLOAT, false, stride, batchVertexBuffer)
        
        // Color attribute (3 floats, offset by 5)
        batchVertexBuffer.position(5)
        GLES30.glVertexAttribPointer(colorHandle, 3, GLES30.GL_FLOAT, false, stride, batchVertexBuffer)
        
        // Draw the batch
        val indexCount = currentBatchSize * indicesPerSprite
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indexCount, GLES30.GL_UNSIGNED_BYTE, batchIndexBuffer)
        
        // Disable attributes
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(texCoordHandle)
        GLES30.glDisableVertexAttribArray(colorHandle)
        
        totalSpritesRendered += currentBatchSize
    }
    
    private fun addSpriteToBuffer(renderData: ShipRenderData) {
        val pos = renderData.worldPosition
        val size = renderData.size
        val rotation = renderData.rotation
        val color = renderData.color
        
        // Calculate sprite corners with rotation
        val cos = cos(rotation)
        val sin = sin(rotation)
        val halfSize = size * 0.5f
        
        // Add animation bobbing
        val bobbing = sin(renderData.animationPhase) * 0.02f
        
        // Vertex positions (clockwise from bottom-left)
        val vertices = arrayOf(
            floatArrayOf(-halfSize, -halfSize, 0f), // Bottom-left
            floatArrayOf(halfSize, -halfSize, 0f),  // Bottom-right
            floatArrayOf(halfSize, halfSize, 0f),   // Top-right
            floatArrayOf(-halfSize, halfSize, 0f)   // Top-left
        )
        
        val texCoords = arrayOf(
            floatArrayOf(0f, 1f), // Bottom-left
            floatArrayOf(1f, 1f), // Bottom-right
            floatArrayOf(1f, 0f), // Top-right
            floatArrayOf(0f, 0f)  // Top-left
        )
        
        // Add each vertex to the buffer
        for (i in 0..3) {
            val vertex = vertices[i]
            val texCoord = texCoords[i]
            
            // Rotate vertex
            val rotatedX = vertex[0] * cos - vertex[1] * sin
            val rotatedY = vertex[0] * sin + vertex[1] * cos
            
            // World position with rotation and bobbing
            batchVertexBuffer.put(pos[0] + rotatedX)
            batchVertexBuffer.put(pos[1] + rotatedY + bobbing)
            batchVertexBuffer.put(pos[2])
            
            // Texture coordinates
            batchVertexBuffer.put(texCoord[0])
            batchVertexBuffer.put(texCoord[1])
            
            // Color
            batchVertexBuffer.put(color[0])
            batchVertexBuffer.put(color[1])
            batchVertexBuffer.put(color[2])
        }
    }
    
    // Helper methods
    private fun getShipWorldPosition(ship: Ship): FloatArray {
        // Convert ship coordinates to world position
        // This would integrate with your coordinate system
        return floatArrayOf(
            ship.currentPosition.x.toFloat(),
            ship.currentPosition.y.toFloat(),
            0f // Assume ships are at sea level
        )
    }
    
    private fun getDistanceToCamera(ship: Ship, cameraPosition: FloatArray): Float {
        val shipPos = getShipWorldPosition(ship)
        val dx = cameraPosition[0] - shipPos[0]
        val dy = cameraPosition[1] - shipPos[1]
        val dz = cameraPosition[2] - shipPos[2]
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    private fun getLODLevel(distance: Float): Int {
        return lodDistances.indexOfFirst { distance <= it }.takeIf { it >= 0 } ?: lodDistances.size
    }
    
    private fun getShipBaseSize(shipType: String): Float {
        return when (shipType.lowercase()) {
            "container" -> 2.0f
            "tanker" -> 2.5f
            "bulk_carrier" -> 2.2f
            "general_cargo" -> 1.8f
            "roro" -> 1.6f
            "refrigerated" -> 1.7f
            "heavy_lift" -> 2.8f
            else -> 1.5f
        }
    }
    
    private fun getShipTypeColor(shipType: String): FloatArray {
        return when (shipType.lowercase()) {
            "container" -> floatArrayOf(0.2f, 0.6f, 0.8f, 1f)  // Blue
            "tanker" -> floatArrayOf(0.8f, 0.4f, 0.2f, 1f)     // Orange
            "bulk_carrier" -> floatArrayOf(0.6f, 0.6f, 0.6f, 1f) // Gray
            "general_cargo" -> floatArrayOf(0.4f, 0.8f, 0.4f, 1f) // Green
            "roro" -> floatArrayOf(0.8f, 0.6f, 0.2f, 1f)       // Yellow
            "refrigerated" -> floatArrayOf(0.6f, 0.8f, 0.8f, 1f) // Cyan
            "heavy_lift" -> floatArrayOf(0.8f, 0.2f, 0.6f, 1f) // Magenta
            else -> floatArrayOf(0.7f, 0.7f, 0.7f, 1f)         // Default gray
        }
    }
    
    private fun getShipTextureIndex(shipType: String): Int {
        // Return texture atlas index for ship type
        return when (shipType.lowercase()) {
            "container" -> 0
            "tanker" -> 1
            "bulk_carrier" -> 2
            "general_cargo" -> 3
            "roro" -> 4
            "refrigerated" -> 5
            "heavy_lift" -> 6
            else -> 0
        }
    }
    
    fun getPerformanceStats(): ShipRenderingStats {
        return ShipRenderingStats(
            totalSpritesRendered = totalSpritesRendered,
            batchCount = lastBatchCount,
            averageSpritesPerBatch = if (lastBatchCount > 0) totalSpritesRendered / lastBatchCount else 0
        )
    }
    
    fun cleanup() {
        shipShader.cleanup()
        wakeEffect.cleanup()
    }
}

// Supporting data classes
data class ShipRenderData(
    val ship: Ship,
    val worldPosition: FloatArray,
    val size: Float,
    val rotation: Float,
    val color: FloatArray,
    val textureIndex: Int,
    val lodLevel: Int,
    val animationPhase: Float
)

class ShipAnimation(ship: Ship) {
    var heading: Float = 0f
    var bobPhase: Float = 0f
    var velocity: Float = 0f
    
    private var targetHeading: Float = 0f
    private val headingSpeed = 2f // radians per second
    
    fun update(ship: Ship, deltaTime: Float) {
        // Update velocity
        velocity = ship.velocity
        
        // Calculate target heading based on ship movement
        // This would integrate with your navigation system
        targetHeading = calculateTargetHeading(ship)
        
        // Smooth heading interpolation
        val headingDiff = targetHeading - heading
        val normalizedDiff = atan2(sin(headingDiff), cos(headingDiff))
        heading += normalizedDiff * headingSpeed * deltaTime
        
        // Update bobbing animation
        bobPhase += deltaTime * 2f // 2 radians per second
        if (bobPhase > 2 * PI) bobPhase -= (2 * PI).toFloat()
    }
    
    private fun calculateTargetHeading(ship: Ship): Float {
        // Calculate heading based on ship's movement direction
        // This is a placeholder - integrate with your actual navigation system
        return 0f
    }
}

data class ShipRenderingStats(
    val totalSpritesRendered: Int,
    val batchCount: Int,
    val averageSpritesPerBatch: Int
)