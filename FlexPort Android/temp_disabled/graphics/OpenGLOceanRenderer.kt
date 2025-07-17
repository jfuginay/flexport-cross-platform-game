package com.flexport.game.graphics

import android.content.Context
import android.opengl.GLES30
import android.opengl.Matrix
import com.flexport.game.graphics.shaders.AdvancedWaterShader
import com.flexport.game.graphics.shaders.FoamShader
import com.flexport.game.graphics.shaders.CausticsShader
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import kotlin.math.*

/**
 * Advanced OpenGL ES 3.0 ocean renderer with realistic water simulation
 * Features: Multiple wave types, foam effects, caustics, dynamic lighting
 */
class OpenGLOceanRenderer(
    private val context: Context,
    private val performanceLevel: PerformanceLevel = PerformanceLevel.HIGH
) {
    
    enum class PerformanceLevel(val meshResolution: Int, val waveComplexity: Int) {
        LOW(32, 2),      // 32x32 mesh, 2 wave layers
        MEDIUM(64, 4),   // 64x64 mesh, 4 wave layers  
        HIGH(128, 6),    // 128x128 mesh, 6 wave layers
        ULTRA(256, 8)    // 256x256 mesh, 8 wave layers
    }
    
    // Shaders
    private lateinit var waterShader: AdvancedWaterShader
    private lateinit var foamShader: FoamShader
    private lateinit var causticsShader: CausticsShader
    
    // Mesh data
    private lateinit var vertexBuffer: FloatBuffer
    private lateinit var indexBuffer: ShortBuffer
    private lateinit var normalBuffer: FloatBuffer
    
    // Ocean mesh properties
    private val meshSize = performanceLevel.meshResolution
    private val oceanScale = 200f // World units
    private val vertexCount = meshSize * meshSize
    private val indexCount = (meshSize - 1) * (meshSize - 1) * 6
    
    // Wave parameters (multiple wave types for realistic ocean)
    private val waveParams = mutableListOf<WaveParameters>()
    
    // Animation and lighting
    private var time = 0f
    private var windDirection = floatArrayOf(1f, 0f) // Normalized wind vector
    private var windStrength = 1f
    private var sunDirection = floatArrayOf(0.7f, 0.7f, 0.3f) // Normalized sun vector
    
    // Framebuffers for multi-pass rendering
    private var foamTexture = 0
    private var causticsTexture = 0
    private var depthTexture = 0
    
    // Performance monitoring
    private var lastFrameTime = 0L
    private var adaptiveQuality = true
    
    init {
        initializeWaveParameters()
        generateOceanMesh()
    }
    
    fun initialize() {
        // Initialize shaders
        waterShader = AdvancedWaterShader(context, performanceLevel)
        foamShader = FoamShader(context)
        causticsShader = CausticsShader(context)
        
        // Generate textures and framebuffers
        generateFramebuffers()
        
        // Setup OpenGL state
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        GLES30.glEnable(GLES30.GL_CULL_FACE)
        GLES30.glCullFace(GLES30.GL_BACK)
    }
    
    private fun initializeWaveParameters() {
        // Generate multiple wave layers for realistic ocean simulation
        val complexity = performanceLevel.waveComplexity
        
        for (i in 0 until complexity) {
            val amplitude = 0.5f * (1f - i * 0.15f) // Decreasing amplitude
            val wavelength = 10f + i * 5f // Increasing wavelength
            val speed = sqrt(9.81f * 2f * PI.toFloat() / wavelength) // Realistic wave speed
            val direction = i * 45f // Vary directions
            
            waveParams.add(
                WaveParameters(
                    amplitude = amplitude,
                    wavelength = wavelength,
                    speed = speed,
                    direction = Math.toRadians(direction.toDouble()).toFloat(),
                    steepness = 0.3f / (wavelength * amplitude * complexity), // Prevent self-intersection
                    phase = (i * 0.5f) // Offset phases
                )
            )
        }
    }
    
    private fun generateOceanMesh() {
        val vertices = FloatArray(vertexCount * 3) // X, Y, Z
        val texCoords = FloatArray(vertexCount * 2) // U, V
        val indices = ShortArray(indexCount)
        
        // Generate vertices in a grid
        var vertexIndex = 0
        var texIndex = 0
        
        for (z in 0 until meshSize) {
            for (x in 0 until meshSize) {
                // Position (Y will be computed in vertex shader)
                vertices[vertexIndex++] = (x.toFloat() / (meshSize - 1) - 0.5f) * oceanScale
                vertices[vertexIndex++] = 0f // Base height
                vertices[vertexIndex++] = (z.toFloat() / (meshSize - 1) - 0.5f) * oceanScale
                
                // Texture coordinates
                texCoords[texIndex++] = x.toFloat() / (meshSize - 1)
                texCoords[texIndex++] = z.toFloat() / (meshSize - 1)
            }
        }
        
        // Generate indices for triangle strips
        var indexPos = 0
        for (z in 0 until meshSize - 1) {
            for (x in 0 until meshSize - 1) {
                val topLeft = (z * meshSize + x).toShort()
                val topRight = (z * meshSize + x + 1).toShort()
                val bottomLeft = ((z + 1) * meshSize + x).toShort()
                val bottomRight = ((z + 1) * meshSize + x + 1).toShort()
                
                // First triangle
                indices[indexPos++] = topLeft
                indices[indexPos++] = bottomLeft
                indices[indexPos++] = topRight
                
                // Second triangle
                indices[indexPos++] = topRight
                indices[indexPos++] = bottomLeft
                indices[indexPos++] = bottomRight
            }
        }
        
        // Create buffers
        val vbb = ByteBuffer.allocateDirect(vertices.size * 4)
        vbb.order(ByteOrder.nativeOrder())
        vertexBuffer = vbb.asFloatBuffer()
        vertexBuffer.put(vertices)
        vertexBuffer.position(0)
        
        val ibb = ByteBuffer.allocateDirect(indices.size * 2)
        ibb.order(ByteOrder.nativeOrder())
        indexBuffer = ibb.asShortBuffer()
        indexBuffer.put(indices)
        indexBuffer.position(0)
    }
    
    private fun generateFramebuffers() {
        val textures = IntArray(3)
        GLES30.glGenTextures(3, textures, 0)
        
        foamTexture = textures[0]
        causticsTexture = textures[1]
        depthTexture = textures[2]
        
        // Setup foam texture (for foam effects)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, foamTexture)
        GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA, 512, 512, 0, 
                           GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
        
        // Setup caustics texture (for underwater light patterns)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, causticsTexture)
        GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA, 256, 256, 0,
                           GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
    }
    
    fun render(
        viewMatrix: FloatArray,
        projectionMatrix: FloatArray,
        cameraPosition: FloatArray,
        deltaTime: Float
    ) {
        val frameStart = System.currentTimeMillis()
        
        // Update animation time
        time += deltaTime
        
        // Calculate view-projection matrix
        val vpMatrix = FloatArray(16)
        Matrix.multiplyMM(vpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        
        // Adaptive quality based on performance
        if (adaptiveQuality) {
            adjustQualityBasedOnPerformance()
        }
        
        // Multi-pass rendering
        renderCaustics(vpMatrix, cameraPosition)
        renderFoam(vpMatrix, cameraPosition)
        renderMainWater(vpMatrix, cameraPosition)
        
        // Performance monitoring
        lastFrameTime = System.currentTimeMillis() - frameStart
    }
    
    private fun renderMainWater(vpMatrix: FloatArray, cameraPosition: FloatArray) {
        waterShader.use()
        
        // Set matrices
        waterShader.setViewProjectionMatrix(vpMatrix)
        waterShader.setCameraPosition(cameraPosition)
        
        // Set time and animation parameters
        waterShader.setTime(time)
        waterShader.setWindParameters(windDirection, windStrength)
        waterShader.setSunDirection(sunDirection)
        
        // Set wave parameters
        val amplitudes = FloatArray(waveParams.size)
        val wavelengths = FloatArray(waveParams.size)
        val speeds = FloatArray(waveParams.size)
        val directions = FloatArray(waveParams.size * 2) // x, z components
        val steepnesses = FloatArray(waveParams.size)
        val phases = FloatArray(waveParams.size)
        
        waveParams.forEachIndexed { index, wave ->
            amplitudes[index] = wave.amplitude
            wavelengths[index] = wave.wavelength
            speeds[index] = wave.speed
            directions[index * 2] = cos(wave.direction)
            directions[index * 2 + 1] = sin(wave.direction)
            steepnesses[index] = wave.steepness
            phases[index] = wave.phase
        }
        
        waterShader.setWaveParameters(amplitudes, wavelengths, speeds, directions, steepnesses, phases)
        
        // Bind foam and caustics textures
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, foamTexture)
        waterShader.setFoamTexture(0)
        
        GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, causticsTexture)
        waterShader.setCausticsTexture(1)
        
        // Render the ocean mesh
        renderMesh()
    }
    
    private fun renderFoam(vpMatrix: FloatArray, cameraPosition: FloatArray) {
        // Render to foam texture
        foamShader.use()
        foamShader.setViewProjectionMatrix(vpMatrix)
        foamShader.setTime(time)
        foamShader.setWaveParameters(waveParams)
        
        renderMesh()
    }
    
    private fun renderCaustics(vpMatrix: FloatArray, cameraPosition: FloatArray) {
        // Render to caustics texture
        causticsShader.use()
        causticsShader.setViewProjectionMatrix(vpMatrix)
        causticsShader.setTime(time)
        causticsShader.setSunDirection(sunDirection)
        
        renderMesh()
    }
    
    private fun renderMesh() {
        // Enable vertex attributes
        val positionHandle = waterShader.getAttributeLocation("a_Position")
        val texCoordHandle = waterShader.getAttributeLocation("a_TexCoord")
        
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glEnableVertexAttribArray(texCoordHandle)
        
        // Bind vertex data
        vertexBuffer.position(0)
        GLES30.glVertexAttribPointer(positionHandle, 3, GLES30.GL_FLOAT, false, 0, vertexBuffer)
        
        // TODO: Add texture coordinate buffer
        // GLES30.glVertexAttribPointer(texCoordHandle, 2, GLES30.GL_FLOAT, false, 0, texCoordBuffer)
        
        // Draw the mesh
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, indexCount, GLES30.GL_UNSIGNED_SHORT, indexBuffer)
        
        // Disable attributes
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(texCoordHandle)
    }
    
    private fun adjustQualityBasedOnPerformance() {
        // Adjust rendering quality based on frame time
        if (lastFrameTime > 33) { // Less than 30 FPS
            // Reduce quality
            windStrength *= 0.95f
        } else if (lastFrameTime < 16) { // More than 60 FPS
            // Can increase quality
            windStrength = minOf(windStrength * 1.01f, 2f)
        }
    }
    
    // MARK: - Dynamic Parameters
    
    fun setWindDirection(direction: Float) {
        windDirection[0] = cos(direction)
        windDirection[1] = sin(direction)
    }
    
    fun setWindStrength(strength: Float) {
        windStrength = strength.coerceIn(0f, 3f)
    }
    
    fun setSunDirection(x: Float, y: Float, z: Float) {
        val length = sqrt(x * x + y * y + z * z)
        if (length > 0) {
            sunDirection[0] = x / length
            sunDirection[1] = y / length
            sunDirection[2] = z / length
        }
    }
    
    fun setTimeOfDay(hour: Float) {
        // Update sun direction based on time of day (0-24)
        val angle = (hour / 24f) * 2f * PI.toFloat()
        setSunDirection(cos(angle), sin(angle) * 0.8f + 0.2f, sin(angle * 0.5f))
    }
    
    fun getPerformanceInfo(): PerformanceInfo {
        return PerformanceInfo(
            lastFrameTimeMs = lastFrameTime,
            fps = if (lastFrameTime > 0) 1000f / lastFrameTime else 0f,
            vertexCount = vertexCount,
            triangleCount = indexCount / 3,
            performanceLevel = performanceLevel
        )
    }
    
    fun cleanup() {
        // Clean up OpenGL resources
        val textures = intArrayOf(foamTexture, causticsTexture, depthTexture)
        GLES30.glDeleteTextures(3, textures, 0)
        
        waterShader.cleanup()
        foamShader.cleanup()
        causticsShader.cleanup()
    }
}

// Supporting data classes
data class WaveParameters(
    val amplitude: Float,
    val wavelength: Float,
    val speed: Float,
    val direction: Float, // Radians
    val steepness: Float,
    val phase: Float
)

data class PerformanceInfo(
    val lastFrameTimeMs: Long,
    val fps: Float,
    val vertexCount: Int,
    val triangleCount: Int,
    val performanceLevel: OpenGLOceanRenderer.PerformanceLevel
)