package com.flexport.game.graphics.shaders

import android.content.Context
import android.opengl.GLES30
import com.flexport.game.graphics.OpenGLOceanRenderer
import com.flexport.game.graphics.WaveParameters

/**
 * Advanced water shader with multiple wave layers, realistic lighting, and foam effects
 */
class AdvancedWaterShader(
    context: Context,
    private val performanceLevel: OpenGLOceanRenderer.PerformanceLevel
) : BaseShader(context, "advanced_water_vertex.glsl", "advanced_water_fragment.glsl") {
    
    // Uniform locations
    private var uVPMatrix: Int = 0
    private var uTime: Int = 0
    private var uCameraPosition: Int = 0
    private var uWindDirection: Int = 0
    private var uWindStrength: Int = 0
    private var uSunDirection: Int = 0
    
    // Wave parameter uniforms
    private var uWaveAmplitudes: Int = 0
    private var uWaveWavelengths: Int = 0
    private var uWaveSpeeds: Int = 0
    private var uWaveDirections: Int = 0
    private var uWaveSteepnesses: Int = 0
    private var uWavePhases: Int = 0
    private var uWaveCount: Int = 0
    
    // Texture uniforms
    private var uFoamTexture: Int = 0
    private var uCausticsTexture: Int = 0
    private var uPerformanceLevel: Int = 0
    
    // Attribute locations
    private var aPosition: Int = 0
    private var aTexCoord: Int = 0
    
    init {
        getUniformLocations()
        getAttributeLocations()
    }
    
    private fun getUniformLocations() {
        uVPMatrix = GLES30.glGetUniformLocation(program, "u_VPMatrix")
        uTime = GLES30.glGetUniformLocation(program, "u_Time")
        uCameraPosition = GLES30.glGetUniformLocation(program, "u_CameraPosition")
        uWindDirection = GLES30.glGetUniformLocation(program, "u_WindDirection")
        uWindStrength = GLES30.glGetUniformLocation(program, "u_WindStrength")
        uSunDirection = GLES30.glGetUniformLocation(program, "u_SunDirection")
        
        uWaveAmplitudes = GLES30.glGetUniformLocation(program, "u_WaveAmplitudes")
        uWaveWavelengths = GLES30.glGetUniformLocation(program, "u_WaveWavelengths")
        uWaveSpeeds = GLES30.glGetUniformLocation(program, "u_WaveSpeeds")
        uWaveDirections = GLES30.glGetUniformLocation(program, "u_WaveDirections")
        uWaveSteepnesses = GLES30.glGetUniformLocation(program, "u_WaveSteepnesses")
        uWavePhases = GLES30.glGetUniformLocation(program, "u_WavePhases")
        uWaveCount = GLES30.glGetUniformLocation(program, "u_WaveCount")
        
        uFoamTexture = GLES30.glGetUniformLocation(program, "u_FoamTexture")
        uCausticsTexture = GLES30.glGetUniformLocation(program, "u_CausticsTexture")
        uPerformanceLevel = GLES30.glGetUniformLocation(program, "u_PerformanceLevel")
    }
    
    private fun getAttributeLocations() {
        aPosition = GLES30.glGetAttribLocation(program, "a_Position")
        aTexCoord = GLES30.glGetAttribLocation(program, "a_TexCoord")
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(uVPMatrix, 1, false, matrix, 0)
    }
    
    fun setTime(time: Float) {
        GLES30.glUniform1f(uTime, time)
    }
    
    fun setCameraPosition(position: FloatArray) {
        GLES30.glUniform3fv(uCameraPosition, 1, position, 0)
    }
    
    fun setWindParameters(direction: FloatArray, strength: Float) {
        GLES30.glUniform2fv(uWindDirection, 1, direction, 0)
        GLES30.glUniform1f(uWindStrength, strength)
    }
    
    fun setSunDirection(direction: FloatArray) {
        GLES30.glUniform3fv(uSunDirection, 1, direction, 0)
    }
    
    fun setWaveParameters(
        amplitudes: FloatArray,
        wavelengths: FloatArray,
        speeds: FloatArray,
        directions: FloatArray,
        steepnesses: FloatArray,
        phases: FloatArray
    ) {
        val waveCount = amplitudes.size
        GLES30.glUniform1i(uWaveCount, waveCount)
        GLES30.glUniform1fv(uWaveAmplitudes, waveCount, amplitudes, 0)
        GLES30.glUniform1fv(uWaveWavelengths, waveCount, wavelengths, 0)
        GLES30.glUniform1fv(uWaveSpeeds, waveCount, speeds, 0)
        GLES30.glUniform2fv(uWaveDirections, waveCount, directions, 0)
        GLES30.glUniform1fv(uWaveSteepnesses, waveCount, steepnesses, 0)
        GLES30.glUniform1fv(uWavePhases, waveCount, phases, 0)
    }
    
    fun setFoamTexture(textureUnit: Int) {
        GLES30.glUniform1i(uFoamTexture, textureUnit)
    }
    
    fun setCausticsTexture(textureUnit: Int) {
        GLES30.glUniform1i(uCausticsTexture, textureUnit)
    }
    
    fun getAttributeLocation(name: String): Int {
        return when (name) {
            "a_Position" -> aPosition
            "a_TexCoord" -> aTexCoord
            else -> -1
        }
    }
    
    override fun use() {
        super.use()
        // Set performance level constant
        GLES30.glUniform1i(uPerformanceLevel, performanceLevel.ordinal)
    }
}