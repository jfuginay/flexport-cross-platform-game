package com.flexport.game.rendering.shaders

import android.content.Context
import android.opengl.GLES30
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Animated water shader for the ocean background
 */
class WaterShader(context: Context) : ShaderProgram(context, "water_vertex.glsl", "water_fragment.glsl") {
    
    private val vertexBuffer: FloatBuffer
    private val indexBuffer: ByteBuffer
    
    private var timeLocation: Int = 0
    private var vpMatrixLocation: Int = 0
    private var waveParamsLocation: Int = 0
    
    // Water mesh (large quad)
    private val vertices = floatArrayOf(
        // X, Y, Z, U, V
        -50f, -50f, 0f, 0f, 0f,  // Bottom-left
         50f, -50f, 0f, 50f, 0f,  // Bottom-right
         50f,  50f, 0f, 50f, 50f, // Top-right
        -50f,  50f, 0f, 0f, 50f   // Top-left
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
        
        // Get uniform locations
        use()
        timeLocation = GLES30.glGetUniformLocation(program, "u_Time")
        vpMatrixLocation = GLES30.glGetUniformLocation(program, "u_VPMatrix")
        waveParamsLocation = GLES30.glGetUniformLocation(program, "u_WaveParams")
    }
    
    fun setTime(time: Float) {
        GLES30.glUniform1f(timeLocation, time)
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(vpMatrixLocation, 1, false, matrix, 0)
    }
    
    fun setWaveParameters(amplitude: Float = 0.5f, frequency: Float = 0.1f, speed: Float = 1.0f) {
        GLES30.glUniform3f(waveParamsLocation, amplitude, frequency, speed)
    }
    
    fun render() {
        // Enable attributes
        val positionHandle = GLES30.glGetAttribLocation(program, "a_Position")
        val texCoordHandle = GLES30.glGetAttribLocation(program, "a_TexCoord")
        
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glEnableVertexAttribArray(texCoordHandle)
        
        // Prepare vertex data
        val stride = 5 * 4 // 5 floats per vertex * 4 bytes per float
        vertexBuffer.position(0)
        GLES30.glVertexAttribPointer(positionHandle, 3, GLES30.GL_FLOAT, false, stride, vertexBuffer)
        
        vertexBuffer.position(3)
        GLES30.glVertexAttribPointer(texCoordHandle, 2, GLES30.GL_FLOAT, false, stride, vertexBuffer)
        
        // Draw the water
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indices.size, GLES30.GL_UNSIGNED_BYTE, indexBuffer)
        
        // Disable attributes
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(texCoordHandle)
    }
}