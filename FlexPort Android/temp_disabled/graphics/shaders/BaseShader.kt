package com.flexport.game.graphics.shaders

import android.content.Context
import android.opengl.GLES30
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Base shader class for OpenGL ES 3.0 shaders
 * Handles shader compilation, linking, and resource management
 */
abstract class BaseShader(
    private val context: Context,
    private val vertexShaderFile: String,
    private val fragmentShaderFile: String
) {
    
    protected var program: Int = 0
        private set
    
    private var vertexShader: Int = 0
    private var fragmentShader: Int = 0
    
    init {
        createShaderProgram()
    }
    
    private fun createShaderProgram() {
        // Load and compile shaders
        val vertexShaderSource = loadShaderSource(vertexShaderFile)
        val fragmentShaderSource = loadShaderSource(fragmentShaderFile)
        
        vertexShader = compileShader(GLES30.GL_VERTEX_SHADER, vertexShaderSource)
        fragmentShader = compileShader(GLES30.GL_FRAGMENT_SHADER, fragmentShaderSource)
        
        // Create and link program
        program = GLES30.glCreateProgram()
        if (program == 0) {
            throw RuntimeException("Failed to create shader program")
        }
        
        GLES30.glAttachShader(program, vertexShader)
        GLES30.glAttachShader(program, fragmentShader)
        GLES30.glLinkProgram(program)
        
        // Check link status
        val linkStatus = IntArray(1)
        GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == GLES30.GL_FALSE) {
            val error = GLES30.glGetProgramInfoLog(program)
            GLES30.glDeleteProgram(program)
            throw RuntimeException("Failed to link shader program: $error")
        }
        
        // Clean up individual shaders (they're linked into the program now)
        GLES30.glDetachShader(program, vertexShader)
        GLES30.glDetachShader(program, fragmentShader)
        GLES30.glDeleteShader(vertexShader)
        GLES30.glDeleteShader(fragmentShader)
    }
    
    private fun loadShaderSource(filename: String): String {
        return try {
            val inputStream = context.assets.open("shaders/$filename")
            val reader = BufferedReader(InputStreamReader(inputStream))
            val source = reader.readText()
            reader.close()
            source
        } catch (e: Exception) {
            throw RuntimeException("Failed to load shader source: $filename", e)
        }
    }
    
    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES30.glCreateShader(type)
        if (shader == 0) {
            throw RuntimeException("Failed to create shader of type: $type")
        }
        
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        
        // Check compilation status
        val compileStatus = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compileStatus, 0)
        if (compileStatus[0] == GLES30.GL_FALSE) {
            val error = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            val shaderType = if (type == GLES30.GL_VERTEX_SHADER) "vertex" else "fragment"
            throw RuntimeException("Failed to compile $shaderType shader: $error")
        }
        
        return shader
    }
    
    open fun use() {
        GLES30.glUseProgram(program)
    }
    
    fun cleanup() {
        if (program != 0) {
            GLES30.glDeleteProgram(program)
            program = 0
        }
    }
    
    // Utility methods for setting uniforms
    protected fun setUniform1i(name: String, value: Int) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniform1i(location, value)
        }
    }
    
    protected fun setUniform1f(name: String, value: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniform1f(location, value)
        }
    }
    
    protected fun setUniform2f(name: String, x: Float, y: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniform2f(location, x, y)
        }
    }
    
    protected fun setUniform3f(name: String, x: Float, y: Float, z: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniform3f(location, x, y, z)
        }
    }
    
    protected fun setUniform4f(name: String, x: Float, y: Float, z: Float, w: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniform4f(location, x, y, z, w)
        }
    }
    
    protected fun setUniformMatrix4fv(name: String, matrix: FloatArray) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location != -1) {
            GLES30.glUniformMatrix4fv(location, 1, false, matrix, 0)
        }
    }
}