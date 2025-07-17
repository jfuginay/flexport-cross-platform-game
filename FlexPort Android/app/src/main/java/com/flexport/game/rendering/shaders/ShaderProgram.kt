package com.flexport.game.rendering.shaders

import android.content.Context
import android.opengl.GLES30
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Base class for OpenGL shader programs
 */
open class ShaderProgram(
    private val context: Context,
    private val vertexShaderAsset: String,
    private val fragmentShaderAsset: String
) {
    protected var program: Int = 0
        private set
    
    init {
        val vertexShader = loadShader(GLES30.GL_VERTEX_SHADER, vertexShaderAsset)
        val fragmentShader = loadShader(GLES30.GL_FRAGMENT_SHADER, fragmentShaderAsset)
        
        program = GLES30.glCreateProgram()
        GLES30.glAttachShader(program, vertexShader)
        GLES30.glAttachShader(program, fragmentShader)
        GLES30.glLinkProgram(program)
        
        // Check link status
        val linkStatus = IntArray(1)
        GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            val log = GLES30.glGetProgramInfoLog(program)
            GLES30.glDeleteProgram(program)
            throw RuntimeException("Error linking shader program: $log")
        }
        
        // Clean up shaders (they're linked to the program now)
        GLES30.glDeleteShader(vertexShader)
        GLES30.glDeleteShader(fragmentShader)
    }
    
    private fun loadShader(type: Int, assetName: String): Int {
        val shaderCode = loadShaderCode(assetName)
        
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, shaderCode)
        GLES30.glCompileShader(shader)
        
        // Check compile status
        val compileStatus = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compileStatus, 0)
        if (compileStatus[0] == 0) {
            val log = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            throw RuntimeException("Error compiling shader $assetName: $log")
        }
        
        return shader
    }
    
    private fun loadShaderCode(assetName: String): String {
        return try {
            val inputStream = context.assets.open("shaders/$assetName")
            val reader = BufferedReader(InputStreamReader(inputStream))
            val sb = StringBuilder()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                sb.append(line).append("\n")
            }
            reader.close()
            sb.toString()
        } catch (e: Exception) {
            Log.e("ShaderProgram", "Failed to load shader $assetName", e)
            // Return a default shader if loading fails
            if (assetName.contains("vertex")) {
                getDefaultVertexShader()
            } else {
                getDefaultFragmentShader()
            }
        }
    }
    
    fun use() {
        GLES30.glUseProgram(program)
    }
    
    fun setUniformMatrix4fv(name: String, matrix: FloatArray) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location >= 0) {
            GLES30.glUniformMatrix4fv(location, 1, false, matrix, 0)
        }
    }
    
    fun setUniform1f(name: String, value: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location >= 0) {
            GLES30.glUniform1f(location, value)
        }
    }
    
    fun setUniform3f(name: String, x: Float, y: Float, z: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location >= 0) {
            GLES30.glUniform3f(location, x, y, z)
        }
    }
    
    fun setUniform4f(name: String, x: Float, y: Float, z: Float, w: Float) {
        val location = GLES30.glGetUniformLocation(program, name)
        if (location >= 0) {
            GLES30.glUniform4f(location, x, y, z, w)
        }
    }
    
    fun delete() {
        if (program != 0) {
            GLES30.glDeleteProgram(program)
            program = 0
        }
    }
    
    // Default shaders for fallback
    private fun getDefaultVertexShader(): String = """
        #version 300 es
        in vec4 a_Position;
        uniform mat4 u_VPMatrix;
        void main() {
            gl_Position = u_VPMatrix * a_Position;
        }
    """.trimIndent()
    
    private fun getDefaultFragmentShader(): String = """
        #version 300 es
        precision mediump float;
        out vec4 fragColor;
        void main() {
            fragColor = vec4(0.0, 0.5, 1.0, 1.0);
        }
    """.trimIndent()
}