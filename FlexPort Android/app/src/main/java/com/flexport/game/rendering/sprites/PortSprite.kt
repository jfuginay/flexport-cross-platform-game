package com.flexport.game.rendering.sprites

import android.content.Context
import android.opengl.GLES30
import com.flexport.game.rendering.shaders.ShaderProgram
import com.flexport.game.viewmodels.Port
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Sprite for rendering ports on the map
 */
class PortSprite(
    private val context: Context,
    private val port: Port
) {
    private val vertexBuffer: FloatBuffer
    private val indexBuffer: ByteBuffer
    
    // Port sprite quad (size varies based on port importance)
    private val size = when (port.capacity) {
        in 0..20000 -> 0.3f    // Small port
        in 20000..40000 -> 0.5f // Medium port
        else -> 0.8f           // Large port
    }
    
    private val vertices = floatArrayOf(
        // X, Y, Z, U, V
        -size, -size, 0f, 0f, 1f,  // Bottom-left
         size, -size, 0f, 1f, 1f,  // Bottom-right
         size,  size, 0f, 1f, 0f,  // Top-right
        -size,  size, 0f, 0f, 0f   // Top-left
    )
    
    private val indices = byteArrayOf(
        0, 1, 2,  // First triangle
        0, 2, 3   // Second triangle
    )
    
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
    
    fun render(shader: ShaderProgram, worldX: Float, worldY: Float, zoom: Float) {
        // Calculate scale based on zoom (ports get smaller when zoomed out)
        val scale = (1.0f + zoom * 0.5f).coerceAtMost(2.0f)
        
        // Set model matrix for positioning and scaling
        val modelMatrix = FloatArray(16)
        android.opengl.Matrix.setIdentityM(modelMatrix, 0)
        android.opengl.Matrix.translateM(modelMatrix, 0, worldX, worldY, 0.1f)
        android.opengl.Matrix.scaleM(modelMatrix, 0, scale, scale, 1f)
        
        shader.setUniformMatrix4fv("u_ModelMatrix", modelMatrix)
        
        // Set port color based on type and utilization
        val utilization = port.currentLoad.toFloat() / port.capacity
        val portColor = when (port.type) {
            com.flexport.game.models.PortType.SEA -> floatArrayOf(0.2f, 0.4f, 0.8f, 1.0f)
            com.flexport.game.models.PortType.AIR -> floatArrayOf(0.4f, 0.8f, 0.2f, 1.0f)
            com.flexport.game.models.PortType.RAIL -> floatArrayOf(0.8f, 0.4f, 0.2f, 1.0f)
            com.flexport.game.models.PortType.MULTIMODAL -> floatArrayOf(0.6f, 0.2f, 0.8f, 1.0f)
        }
        
        // Adjust color based on utilization (red tint for overloaded)
        if (utilization > 0.9f) {
            portColor[0] = 0.8f
            portColor[1] = 0.2f
            portColor[2] = 0.2f
        }
        
        shader.setUniform4f("u_Color", portColor[0], portColor[1], portColor[2], portColor[3])
        
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
        
        // Draw the port
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indices.size, GLES30.GL_UNSIGNED_BYTE, indexBuffer)
        
        // Disable attributes
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(texCoordHandle)
    }
}