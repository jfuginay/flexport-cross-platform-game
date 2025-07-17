package com.flexport.game.graphics.shaders

import android.content.Context
import android.opengl.GLES30

/**
 * Shader for rendering ship sprites with batching support
 */
class ShipShader(context: Context) : BaseShader(context, "ship_vertex.glsl", "ship_fragment.glsl") {
    
    // Uniform locations
    private var uVPMatrix: Int = 0
    private var uTime: Int = 0
    private var uTextureAtlas: Int = 0
    
    // Attribute locations
    private var aPosition: Int = 0
    private var aTexCoord: Int = 0
    private var aColor: Int = 0
    
    init {
        getUniformLocations()
        getAttributeLocations()
    }
    
    private fun getUniformLocations() {
        uVPMatrix = GLES30.glGetUniformLocation(program, "u_VPMatrix")
        uTime = GLES30.glGetUniformLocation(program, "u_Time")
        uTextureAtlas = GLES30.glGetUniformLocation(program, "u_TextureAtlas")
    }
    
    private fun getAttributeLocations() {
        aPosition = GLES30.glGetAttribLocation(program, "a_Position")
        aTexCoord = GLES30.glGetAttribLocation(program, "a_TexCoord")
        aColor = GLES30.glGetAttribLocation(program, "a_Color")
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(uVPMatrix, 1, false, matrix, 0)
    }
    
    fun setTime(time: Float) {
        GLES30.glUniform1f(uTime, time)
    }
    
    fun setTextureAtlas(textureUnit: Int) {
        GLES30.glUniform1i(uTextureAtlas, textureUnit)
    }
    
    fun getAttributeLocation(name: String): Int {
        return when (name) {
            "a_Position" -> aPosition
            "a_TexCoord" -> aTexCoord
            "a_Color" -> aColor
            else -> -1
        }
    }
}