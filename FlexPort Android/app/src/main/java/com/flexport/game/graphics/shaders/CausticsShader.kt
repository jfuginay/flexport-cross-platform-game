package com.flexport.game.graphics.shaders

import android.content.Context
import android.opengl.GLES30

/**
 * Caustics shader for underwater light patterns
 */
class CausticsShader(context: Context) : BaseShader(context, "caustics_vertex.glsl", "caustics_fragment.glsl") {
    
    private var uVPMatrix: Int = 0
    private var uTime: Int = 0
    private var uSunDirection: Int = 0
    
    init {
        getUniformLocations()
    }
    
    private fun getUniformLocations() {
        uVPMatrix = GLES30.glGetUniformLocation(program, "u_VPMatrix")
        uTime = GLES30.glGetUniformLocation(program, "u_Time")
        uSunDirection = GLES30.glGetUniformLocation(program, "u_SunDirection")
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(uVPMatrix, 1, false, matrix, 0)
    }
    
    fun setTime(time: Float) {
        GLES30.glUniform1f(uTime, time)
    }
    
    fun setSunDirection(direction: FloatArray) {
        GLES30.glUniform3fv(uSunDirection, 1, direction, 0)
    }
}