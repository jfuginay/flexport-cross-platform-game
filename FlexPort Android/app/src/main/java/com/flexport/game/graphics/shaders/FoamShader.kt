package com.flexport.game.graphics.shaders

import android.content.Context
import android.opengl.GLES30
import com.flexport.game.graphics.WaveParameters

/**
 * Foam shader for generating realistic ocean foam effects
 */
class FoamShader(context: Context) : BaseShader(context, "foam_vertex.glsl", "foam_fragment.glsl") {
    
    private var uVPMatrix: Int = 0
    private var uTime: Int = 0
    private var uWaveCount: Int = 0
    private var uWaveAmplitudes: Int = 0
    private var uWaveWavelengths: Int = 0
    private var uWaveSpeeds: Int = 0
    private var uWaveDirections: Int = 0
    
    init {
        getUniformLocations()
    }
    
    private fun getUniformLocations() {
        uVPMatrix = GLES30.glGetUniformLocation(program, "u_VPMatrix")
        uTime = GLES30.glGetUniformLocation(program, "u_Time")
        uWaveCount = GLES30.glGetUniformLocation(program, "u_WaveCount")
        uWaveAmplitudes = GLES30.glGetUniformLocation(program, "u_WaveAmplitudes")
        uWaveWavelengths = GLES30.glGetUniformLocation(program, "u_WaveWavelengths")
        uWaveSpeeds = GLES30.glGetUniformLocation(program, "u_WaveSpeeds")
        uWaveDirections = GLES30.glGetUniformLocation(program, "u_WaveDirections")
    }
    
    fun setViewProjectionMatrix(matrix: FloatArray) {
        GLES30.glUniformMatrix4fv(uVPMatrix, 1, false, matrix, 0)
    }
    
    fun setTime(time: Float) {
        GLES30.glUniform1f(uTime, time)
    }
    
    fun setWaveParameters(waves: List<WaveParameters>) {
        val waveCount = waves.size
        val amplitudes = FloatArray(waveCount)
        val wavelengths = FloatArray(waveCount)
        val speeds = FloatArray(waveCount)
        val directions = FloatArray(waveCount * 2)
        
        waves.forEachIndexed { index, wave ->
            amplitudes[index] = wave.amplitude
            wavelengths[index] = wave.wavelength
            speeds[index] = wave.speed
            directions[index * 2] = kotlin.math.cos(wave.direction)
            directions[index * 2 + 1] = kotlin.math.sin(wave.direction)
        }
        
        GLES30.glUniform1i(uWaveCount, waveCount)
        GLES30.glUniform1fv(uWaveAmplitudes, waveCount, amplitudes, 0)
        GLES30.glUniform1fv(uWaveWavelengths, waveCount, wavelengths, 0)
        GLES30.glUniform1fv(uWaveSpeeds, waveCount, speeds, 0)
        GLES30.glUniform2fv(uWaveDirections, waveCount, directions, 0)
    }
}