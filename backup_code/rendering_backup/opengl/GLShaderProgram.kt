package com.flexport.rendering.opengl

import android.opengl.GLES30
import com.flexport.rendering.math.Matrix4
import com.flexport.rendering.shader.ShaderProgram
import java.nio.FloatBuffer

/**
 * OpenGL ES shader program implementation
 */
class GLShaderProgram(
    vertexShaderSource: String,
    fragmentShaderSource: String
) : ShaderProgram() {
    
    private var programId: Int = 0
    private var vertexShaderId: Int = 0
    private var fragmentShaderId: Int = 0
    
    override var isCompiled: Boolean = false
        private set
    
    private val uniformLocations = mutableMapOf<String, Int>()
    private val attributeLocations = mutableMapOf<String, Int>()
    
    private var log = ""
    
    init {
        compileShaders(vertexShaderSource, fragmentShaderSource)
    }
    
    private fun compileShaders(vertexSource: String, fragmentSource: String) {
        // Compile vertex shader
        vertexShaderId = loadShader(GLES30.GL_VERTEX_SHADER, vertexSource)
        if (vertexShaderId == 0) {
            return
        }
        
        // Compile fragment shader
        fragmentShaderId = loadShader(GLES30.GL_FRAGMENT_SHADER, fragmentSource)
        if (fragmentShaderId == 0) {
            return
        }
        
        // Create program
        programId = GLES30.glCreateProgram()
        if (programId == 0) {
            log += "Failed to create shader program\n"
            return
        }
        
        // Attach shaders
        GLES30.glAttachShader(programId, vertexShaderId)
        GLES30.glAttachShader(programId, fragmentShaderId)
        
        // Link program
        GLES30.glLinkProgram(programId)
        
        // Check link status
        val linkStatus = IntArray(1)
        GLES30.glGetProgramiv(programId, GLES30.GL_LINK_STATUS, linkStatus, 0)
        
        if (linkStatus[0] == GLES30.GL_FALSE) {
            log += GLES30.glGetProgramInfoLog(programId) + "\n"
            dispose()
            return
        }
        
        isCompiled = true
    }
    
    private fun loadShader(type: Int, source: String): Int {
        val shader = GLES30.glCreateShader(type)
        if (shader == 0) {
            log += "Failed to create shader of type $type\n"
            return 0
        }
        
        GLES30.glShaderSource(shader, source)
        GLES30.glCompileShader(shader)
        
        val compileStatus = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compileStatus, 0)
        
        if (compileStatus[0] == GLES30.GL_FALSE) {
            log += GLES30.glGetShaderInfoLog(shader) + "\n"
            GLES30.glDeleteShader(shader)
            return 0
        }
        
        return shader
    }
    
    override fun use() {
        if (isCompiled) {
            GLES30.glUseProgram(programId)
        }
    }
    
    override fun setUniformf(name: String, value: Float) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniform1f(location, value)
        }
    }
    
    override fun setUniformf(name: String, x: Float, y: Float) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniform2f(location, x, y)
        }
    }
    
    override fun setUniformf(name: String, x: Float, y: Float, z: Float) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniform3f(location, x, y, z)
        }
    }
    
    override fun setUniformf(name: String, x: Float, y: Float, z: Float, w: Float) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniform4f(location, x, y, z, w)
        }
    }
    
    override fun setUniformi(name: String, value: Int) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniform1i(location, value)
        }
    }
    
    override fun setUniformMatrix4(name: String, matrix: Matrix4, transpose: Boolean) {
        val location = getUniformLocation(name)
        if (location != -1) {
            GLES30.glUniformMatrix4fv(location, 1, transpose, matrix.values, 0)
        }
    }
    
    override fun getUniformLocation(name: String): Int {
        return uniformLocations.getOrPut(name) {
            GLES30.glGetUniformLocation(programId, name)
        }
    }
    
    override fun getAttributeLocation(name: String): Int {
        return attributeLocations.getOrPut(name) {
            GLES30.glGetAttribLocation(programId, name)
        }
    }
    
    override fun dispose() {
        if (vertexShaderId != 0) {
            GLES30.glDeleteShader(vertexShaderId)
            vertexShaderId = 0
        }
        
        if (fragmentShaderId != 0) {
            GLES30.glDeleteShader(fragmentShaderId)
            fragmentShaderId = 0
        }
        
        if (programId != 0) {
            GLES30.glDeleteProgram(programId)
            programId = 0
        }
        
        isCompiled = false
    }
    
    override fun getLog(): String = log
    
    companion object {
        /**
         * Default vertex shader for sprite rendering
         */
        const val DEFAULT_VERTEX_SHADER = """
            #version 300 es
            
            layout(location = 0) in vec2 a_position;
            layout(location = 1) in vec2 a_texCoord;
            layout(location = 2) in vec4 a_color;
            
            uniform mat4 u_projTrans;
            
            out vec2 v_texCoord;
            out vec4 v_color;
            
            void main() {
                v_texCoord = a_texCoord;
                v_color = a_color;
                gl_Position = u_projTrans * vec4(a_position, 0.0, 1.0);
            }
        """
        
        /**
         * Default fragment shader for sprite rendering
         */
        const val DEFAULT_FRAGMENT_SHADER = """
            #version 300 es
            precision mediump float;
            
            in vec2 v_texCoord;
            in vec4 v_color;
            
            uniform sampler2D u_texture;
            
            out vec4 fragColor;
            
            void main() {
                fragColor = texture(u_texture, v_texCoord) * v_color;
            }
        """
    }
}