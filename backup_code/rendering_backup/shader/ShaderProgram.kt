package com.flexport.rendering.shader

import com.flexport.rendering.math.Matrix4
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.math.Vector3

/**
 * Abstract base class for shader programs
 */
abstract class ShaderProgram {
    
    abstract val isCompiled: Boolean
    
    /**
     * Use this shader program for rendering
     */
    abstract fun use()
    
    /**
     * Set a uniform float value
     */
    abstract fun setUniformf(name: String, value: Float)
    
    /**
     * Set a uniform vec2 value
     */
    abstract fun setUniformf(name: String, x: Float, y: Float)
    
    /**
     * Set a uniform vec3 value
     */
    abstract fun setUniformf(name: String, x: Float, y: Float, z: Float)
    
    /**
     * Set a uniform vec4 value
     */
    abstract fun setUniformf(name: String, x: Float, y: Float, z: Float, w: Float)
    
    /**
     * Set a uniform int value
     */
    abstract fun setUniformi(name: String, value: Int)
    
    /**
     * Set a uniform Vector2 value
     */
    fun setUniformf(name: String, vector: Vector2) {
        setUniformf(name, vector.x, vector.y)
    }
    
    /**
     * Set a uniform Vector3 value
     */
    fun setUniformf(name: String, vector: Vector3) {
        setUniformf(name, vector.x, vector.y, vector.z)
    }
    
    /**
     * Set a uniform matrix value
     */
    abstract fun setUniformMatrix4(name: String, matrix: Matrix4, transpose: Boolean = false)
    
    /**
     * Get the location of a uniform variable
     */
    abstract fun getUniformLocation(name: String): Int
    
    /**
     * Get the location of an attribute
     */
    abstract fun getAttributeLocation(name: String): Int
    
    /**
     * Dispose of shader resources
     */
    abstract fun dispose()
    
    /**
     * Get shader compilation log
     */
    abstract fun getLog(): String
}