package com.flexport.game.graphics.sprites

import android.content.Context
import android.opengl.GLES30
import com.flexport.game.graphics.shaders.BaseShader
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.*

/**
 * Wake effect system for ship trails using point sprites and particle simulation
 */
class WakeEffect(private val context: Context) {
    
    private lateinit var wakeShader: WakeShader
    
    // Wake particle system
    private val maxWakePoints = 1000
    private var wakePoints = Array(maxWakePoints) { WakePoint() }
    private var activeWakePoints = 0
    
    // Buffers for rendering
    private lateinit var wakeVertexBuffer: FloatBuffer
    private val floatsPerWakePoint = 7 // Position(3) + Size(1) + Age(1) + Alpha(1) + Intensity(1)
    
    fun initialize() {
        wakeShader = WakeShader(context)
        
        // Setup wake point buffer
        val bufferSize = maxWakePoints * floatsPerWakePoint * 4
        val bb = ByteBuffer.allocateDirect(bufferSize)
        bb.order(ByteOrder.nativeOrder())
        wakeVertexBuffer = bb.asFloatBuffer()
        
        // OpenGL setup for point sprites
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
    }
    
    fun addWakePoint(x: Float, y: Float, z: Float, heading: Float, velocity: Float, deltaTime: Float) {
        if (velocity < 0.1f) return // No wake for stationary ships
        
        // Calculate wake spawn positions (behind the ship)
        val wakeOffset = 1.0f // Distance behind ship
        val wakeSpread = 0.3f // Width of wake
        
        val headingCos = cos(heading)
        val headingSin = sin(heading)
        
        // Create wake points on both sides of the ship
        for (side in -1..1 step 2) {
            val sideOffset = side * wakeSpread
            val wakeX = x - headingCos * wakeOffset + headingSin * sideOffset
            val wakeY = y - headingSin * wakeOffset - headingCos * sideOffset
            
            if (activeWakePoints < maxWakePoints) {
                val wakePoint = wakePoints[activeWakePoints]
                wakePoint.reset(wakeX, wakeY, z, velocity)
                activeWakePoints++
            }
        }
    }
    
    fun render(vpMatrix: FloatArray, deltaTime: Float) {
        if (activeWakePoints == 0) return
        
        // Update wake points and remove expired ones
        updateWakePoints(deltaTime)
        
        // Prepare vertex data
        wakeVertexBuffer.clear()
        var validPoints = 0
        
        for (i in 0 until activeWakePoints) {
            val wake = wakePoints[i]
            if (wake.isAlive) {
                // Position
                wakeVertexBuffer.put(wake.x)
                wakeVertexBuffer.put(wake.y)
                wakeVertexBuffer.put(wake.z)
                
                // Size (grows then shrinks)
                val ageRatio = wake.age / wake.maxAge
                val sizeFactor = sin(ageRatio * PI).toFloat()
                wakeVertexBuffer.put(wake.size * sizeFactor)
                
                // Age and alpha
                wakeVertexBuffer.put(wake.age)
                wakeVertexBuffer.put(1f - ageRatio) // Alpha fades over time
                
                // Intensity based on initial velocity
                wakeVertexBuffer.put(wake.intensity)
                
                validPoints++
            }
        }
        
        if (validPoints == 0) return
        
        wakeVertexBuffer.position(0)
        
        // Render wake points as sprites
        wakeShader.use()
        wakeShader.setViewProjectionMatrix(vpMatrix)
        
        // Setup vertex attributes
        val positionHandle = wakeShader.getAttributeLocation("a_Position")
        val sizeHandle = wakeShader.getAttributeLocation("a_Size")
        val ageHandle = wakeShader.getAttributeLocation("a_Age")
        val alphaHandle = wakeShader.getAttributeLocation("a_Alpha")
        val intensityHandle = wakeShader.getAttributeLocation("a_Intensity")
        
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glEnableVertexAttribArray(sizeHandle)
        GLES30.glEnableVertexAttribArray(ageHandle)
        GLES30.glEnableVertexAttribArray(alphaHandle)
        GLES30.glEnableVertexAttribArray(intensityHandle)
        
        val stride = floatsPerWakePoint * 4
        
        wakeVertexBuffer.position(0)
        GLES30.glVertexAttribPointer(positionHandle, 3, GLES30.GL_FLOAT, false, stride, wakeVertexBuffer)
        
        wakeVertexBuffer.position(3)
        GLES30.glVertexAttribPointer(sizeHandle, 1, GLES30.GL_FLOAT, false, stride, wakeVertexBuffer)
        
        wakeVertexBuffer.position(4)
        GLES30.glVertexAttribPointer(ageHandle, 1, GLES30.GL_FLOAT, false, stride, wakeVertexBuffer)
        
        wakeVertexBuffer.position(5)
        GLES30.glVertexAttribPointer(alphaHandle, 1, GLES30.GL_FLOAT, false, stride, wakeVertexBuffer)
        
        wakeVertexBuffer.position(6)
        GLES30.glVertexAttribPointer(intensityHandle, 1, GLES30.GL_FLOAT, false, stride, wakeVertexBuffer)
        
        // Draw wake points
        GLES30.glDrawArrays(GLES30.GL_POINTS, 0, validPoints)
        
        // Cleanup
        GLES30.glDisableVertexAttribArray(positionHandle)
        GLES30.glDisableVertexAttribArray(sizeHandle)
        GLES30.glDisableVertexAttribArray(ageHandle)
        GLES30.glDisableVertexAttribArray(alphaHandle)
        GLES30.glDisableVertexAttribArray(intensityHandle)
    }
    
    private fun updateWakePoints(deltaTime: Float) {
        var writeIndex = 0
        
        for (i in 0 until activeWakePoints) {
            val wake = wakePoints[i]
            wake.update(deltaTime)
            
            if (wake.isAlive) {
                // Move valid wake points to front of array
                if (writeIndex != i) {
                    wakePoints[writeIndex] = wakePoints[i]
                    wakePoints[i] = WakePoint() // Reset the old position
                }
                writeIndex++
            }
        }
        
        activeWakePoints = writeIndex
    }
    
    fun cleanup() {
        wakeShader.cleanup()
    }
    
    // Wake point data structure
    private class WakePoint {
        var x = 0f
        var y = 0f
        var z = 0f
        var size = 0f
        var age = 0f
        var maxAge = 3f // 3 seconds lifetime
        var intensity = 0f
        
        val isAlive: Boolean get() = age < maxAge
        
        fun reset(newX: Float, newY: Float, newZ: Float, velocity: Float) {
            x = newX
            y = newY
            z = newZ
            age = 0f
            intensity = (velocity / 30f).coerceIn(0.2f, 1f) // Normalize velocity
            size = 0.5f + intensity * 0.5f // Size based on intensity
            maxAge = 2f + intensity * 2f // Longer wake for faster ships
        }
        
        fun update(deltaTime: Float) {
            age += deltaTime
            
            // Simulate wake spreading and fading
            if (isAlive) {
                size += deltaTime * 0.2f // Wake grows over time
            }
        }
    }
}

// Wake-specific shader
private class WakeShader(context: Context) : BaseShader(context, "wake_vertex.glsl", "wake_fragment.glsl") {
    
    private var uVPMatrix: Int = 0
    
    // Attribute locations
    private var aPosition: Int = 0
    private var aSize: Int = 0
    private var aAge: Int = 0
    private var aAlpha: Int = 0
    private var aIntensity: Int = 0
    
    init {
        getUniformLocations()
        getAttributeLocations()
    }
    
    private fun getUniformLocations() {
        uVPMatrix = GLES30.glGetUniformLocation(program, "u_VPMatrix")
    }
    
    private fun getAttributeLocations() {
        aPosition = GLES30.glGetAttribLocation(program, "a_Position")
        aSize = GLES30.glGetAttribLocation(program, "a_Size")
        aAge = GLES30.glGetAttribLocation(program, "a_Age")
        aAlpha = GLES30.glGetAttribLocation(program, "a_Alpha")
        aIntensity = GLES30.glGetAttribLocation(program, "a_Intensity")
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(uVPMatrix, 1, false, matrix, 0)
    }
    
    fun getAttributeLocation(name: String): Int {
        return when (name) {
            "a_Position" -> aPosition
            "a_Size" -> aSize
            "a_Age" -> aAge
            "a_Alpha" -> aAlpha
            "a_Intensity" -> aIntensity
            else -> -1
        }
    }
}