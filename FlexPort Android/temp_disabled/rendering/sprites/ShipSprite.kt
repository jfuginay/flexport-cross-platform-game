package com.flexport.game.rendering.sprites

import android.content.Context
import android.opengl.GLES30
import com.flexport.game.models.Ship
import com.flexport.game.rendering.shaders.ShaderProgram
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * Sprite for rendering ships on the map with animation
 */
class ShipSprite(
    private val context: Context,
    private val ship: Ship
) {
    private val vertexBuffer: FloatBuffer
    private val indexBuffer: ByteBuffer
    
    // Ship sprite - triangle shape pointing forward
    private val size = when (ship.capacity) {
        in 0..5000 -> 0.2f     // Small ship
        in 5000..10000 -> 0.3f // Medium ship
        else -> 0.4f           // Large ship
    }
    
    // Triangle pointing upward (north)
    private val vertices = floatArrayOf(
        // X, Y, Z, U, V
        0f,    size,   0f, 0.5f, 0f,   // Top (bow)
        -size, -size,  0f, 0f,   1f,   // Bottom-left (stern)
        size,  -size,  0f, 1f,   1f    // Bottom-right (stern)
    )
    
    private val indices = byteArrayOf(0, 1, 2)
    
    init {
        // Initialize vertex buffer
        val vbb = ByteBuffer.allocateDirect(vertices.size * 4)
        vbb.order(ByteOrder.nativeOrder())
        vertexBuffer = vbb.asFloatBuffer()
        vertexBuffer.put(vertices)
        vertexBuffer.position(0)
        
        // Initialize index buffer
        indexBuffer = ByteBuffer.allocateDirect(indices.size)
        indexBuffer.order(ByteOrder.nativeOrder())
        indexBuffer.put(indices)
        indexBuffer.position(0)
    }
    
    fun render(shader: ShaderProgram, worldX: Float, worldY: Float, zoom: Float, time: Float) {
        // Calculate scale based on zoom
        val scale = (0.5f + zoom * 0.3f).coerceAtMost(1.5f)
        
        // Add subtle bobbing animation
        val bobbing = sin(time * 2f + worldX + worldY) * 0.05f
        
        // TODO: Get actual heading from ship's route/movement
        val heading = time * 0.1f // Mock rotation for demo
        
        // Set model matrix for positioning, rotation, and scaling
        val modelMatrix = FloatArray(16)
        android.opengl.Matrix.setIdentityM(modelMatrix, 0)
        android.opengl.Matrix.translateM(modelMatrix, 0, worldX, worldY + bobbing, 0.2f)
        android.opengl.Matrix.rotateM(modelMatrix, 0, Math.toDegrees(heading.toDouble()).toFloat(), 0f, 0f, 1f)
        android.opengl.Matrix.scaleM(modelMatrix, 0, scale, scale, 1f)
        
        shader.setUniformMatrix4fv("u_ModelMatrix", modelMatrix)
        
        // Set ship color based on efficiency and status
        val efficiency = (ship.fuelEfficiency / 100.0).toFloat()
        val shipColor = floatArrayOf(
            0.8f + efficiency * 0.2f,  // Red component
            0.6f + efficiency * 0.4f,  // Green component
            0.4f,                      // Blue component
            1.0f                       // Alpha
        )
        
        shader.setUniform4f("u_Color", shipColor[0], shipColor[1], shipColor[2], shipColor[3])
        shader.setUniform1f("u_Time", time)
        
        // Enable attributes
        val positionHandle = GLES30.glGetAttribLocation(shader.program, "a_Position")
        val texCoordHandle = GLES30.glGetAttribLocation(shader.program, "a_TexCoord")
        
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glEnableVertexAttribArray(texCoordHandle)
        
        // Prepare vertex data
        val stride = 5 * 4 // 5 floats per vertex * 4 bytes per float
        vertexBuffer.position(0)
        GLES30.glVertexAttribPointer(positionHandle, 3, GLES30.GL_FLOAT, false, stride, vertexBuffer)
        
        vertexBuffer.position(3)
        GLES30.glVertexAttribPointer(texCoordHandle, 2, GLES30.GL_FLOAT, false, stride, vertexBuffer)
        
        // Draw the ship
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indices.size, GLES30.GL_UNSIGNED_BYTE, indexBuffer)
        
        // Disable attributes
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(texCoordHandle)
    }
}