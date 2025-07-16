package com.flexport.input

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.annotation.RequiresApi

/**
 * Manages haptic feedback for touch interactions
 */
class HapticFeedbackManager(private val context: Context) {
    
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
    
    // Settings
    var isHapticEnabled = true
    var globalIntensity = 1f // 0.0 to 1.0
    
    // Predefined haptic patterns
    enum class HapticType {
        TAP,           // Light tap feedback
        BUTTON_PRESS,  // Medium button press
        SELECTION,     // Entity selection
        LONG_PRESS,    // Long press confirmation
        DRAG_START,    // Start of drag operation
        DRAG_END,      // End of drag operation
        ERROR,         // Error or invalid action
        SUCCESS,       // Successful action
        ZOOM,          // Zoom gesture
        NOTIFICATION   // General notification
    }
    
    init {
        // Load haptic preferences (you might want to load from SharedPreferences)
        loadHapticSettings()
    }
    
    /**
     * Trigger haptic feedback for a specific type
     */
    fun triggerHaptic(type: HapticType, intensity: Float = 1f) {
        if (!isHapticEnabled || !vibrator.hasVibrator()) return
        
        val adjustedIntensity = (intensity * globalIntensity).coerceIn(0f, 1f)
        if (adjustedIntensity <= 0f) return
        
        when (type) {
            HapticType.TAP -> performTapFeedback(adjustedIntensity)
            HapticType.BUTTON_PRESS -> performButtonPressFeedback(adjustedIntensity)
            HapticType.SELECTION -> performSelectionFeedback(adjustedIntensity)
            HapticType.LONG_PRESS -> performLongPressFeedback(adjustedIntensity)
            HapticType.DRAG_START -> performDragStartFeedback(adjustedIntensity)
            HapticType.DRAG_END -> performDragEndFeedback(adjustedIntensity)
            HapticType.ERROR -> performErrorFeedback(adjustedIntensity)
            HapticType.SUCCESS -> performSuccessFeedback(adjustedIntensity)
            HapticType.ZOOM -> performZoomFeedback(adjustedIntensity)
            HapticType.NOTIFICATION -> performNotificationFeedback(adjustedIntensity)
        }
    }
    
    private fun performTapFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(10, (intensity * 100).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((10 * intensity).toLong())
        }
    }
    
    private fun performButtonPressFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(20, (intensity * 120).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((20 * intensity).toLong())
        }
    }
    
    private fun performSelectionFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 15, 10, 10)
            val amplitudes = intArrayOf(0, (intensity * 80).toInt().coerceIn(1, 255), 0, (intensity * 40).toInt().coerceIn(1, 255))
            val effect = VibrationEffect.createWaveform(pattern, amplitudes, -1)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, (15 * intensity).toLong(), 10, (10 * intensity).toLong())
            vibrator.vibrate(pattern, -1)
        }
    }
    
    private fun performLongPressFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(50, (intensity * 150).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((50 * intensity).toLong())
        }
    }
    
    private fun performDragStartFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 30, 20, 20)
            val amplitudes = intArrayOf(0, (intensity * 100).toInt().coerceIn(1, 255), 0, (intensity * 60).toInt().coerceIn(1, 255))
            val effect = VibrationEffect.createWaveform(pattern, amplitudes, -1)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, (30 * intensity).toLong(), 20, (20 * intensity).toLong())
            vibrator.vibrate(pattern, -1)
        }
    }
    
    private fun performDragEndFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(25, (intensity * 90).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((25 * intensity).toLong())
        }
    }
    
    private fun performErrorFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 100, 50, 100, 50, 100)
            val amplitudes = intArrayOf(
                0, 
                (intensity * 200).toInt().coerceIn(1, 255), 
                0, 
                (intensity * 180).toInt().coerceIn(1, 255), 
                0, 
                (intensity * 160).toInt().coerceIn(1, 255)
            )
            val effect = VibrationEffect.createWaveform(pattern, amplitudes, -1)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(
                0, (100 * intensity).toLong(), 
                50, (100 * intensity).toLong(), 
                50, (100 * intensity).toLong()
            )
            vibrator.vibrate(pattern, -1)
        }
    }
    
    private fun performSuccessFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 20, 10, 40)
            val amplitudes = intArrayOf(
                0, 
                (intensity * 100).toInt().coerceIn(1, 255), 
                0, 
                (intensity * 150).toInt().coerceIn(1, 255)
            )
            val effect = VibrationEffect.createWaveform(pattern, amplitudes, -1)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, (20 * intensity).toLong(), 10, (40 * intensity).toLong())
            vibrator.vibrate(pattern, -1)
        }
    }
    
    private fun performZoomFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(5, (intensity * 50).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((5 * intensity).toLong())
        }
    }
    
    private fun performNotificationFeedback(intensity: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val pattern = longArrayOf(0, 30, 100, 30)
            val amplitudes = intArrayOf(
                0, 
                (intensity * 120).toInt().coerceIn(1, 255), 
                0, 
                (intensity * 120).toInt().coerceIn(1, 255)
            )
            val effect = VibrationEffect.createWaveform(pattern, amplitudes, -1)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val pattern = longArrayOf(0, (30 * intensity).toLong(), 100, (30 * intensity).toLong())
            vibrator.vibrate(pattern, -1)
        }
    }
    
    /**
     * Perform custom haptic feedback with specific duration and intensity
     */
    fun performCustomHaptic(durationMs: Long, intensity: Float) {
        if (!isHapticEnabled || !vibrator.hasVibrator()) return
        
        val adjustedIntensity = (intensity * globalIntensity).coerceIn(0f, 1f)
        if (adjustedIntensity <= 0f) return
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createOneShot(durationMs, (adjustedIntensity * 255).toInt().coerceIn(1, 255))
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate((durationMs * adjustedIntensity).toLong())
        }
    }
    
    /**
     * Perform custom pattern haptic feedback
     */
    fun performCustomPattern(pattern: LongArray, intensities: IntArray? = null, repeat: Int = -1) {
        if (!isHapticEnabled || !vibrator.hasVibrator()) return
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && intensities != null) {
            val adjustedIntensities = intensities.map { 
                (it * globalIntensity).toInt().coerceIn(0, 255) 
            }.toIntArray()
            val effect = VibrationEffect.createWaveform(pattern, adjustedIntensities, repeat)
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            val adjustedPattern = pattern.map { (it * globalIntensity).toLong() }.toLongArray()
            vibrator.vibrate(adjustedPattern, repeat)
        }
    }
    
    /**
     * Use predefined system haptic effects (API 29+)
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    fun performPredefinedHaptic(effectId: Int) {
        if (!isHapticEnabled || !vibrator.hasVibrator()) return
        
        val effect = VibrationEffect.createPredefined(effectId)
        vibrator.vibrate(effect)
    }
    
    /**
     * Cancel any ongoing vibration
     */
    fun cancelHaptic() {
        vibrator.cancel()
    }
    
    /**
     * Check if device supports haptic feedback
     */
    fun hasHapticSupport(): Boolean {
        return vibrator.hasVibrator()
    }
    
    /**
     * Check if device supports amplitude control (API 26+)
     */
    fun hasAmplitudeControl(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.hasAmplitudeControl()
        } else {
            false
        }
    }
    
    // Note: setHapticEnabled and setGlobalIntensity are auto-generated by Kotlin for var properties
    
    /**
     * Load haptic settings from preferences
     */
    private fun loadHapticSettings() {
        val prefs = context.getSharedPreferences("haptic_settings", Context.MODE_PRIVATE)
        isHapticEnabled = prefs.getBoolean("haptic_enabled", true)
        globalIntensity = prefs.getFloat("haptic_intensity", 1f)
    }
    
    /**
     * Save haptic settings to preferences
     */
    fun saveHapticSettings() {
        val prefs = context.getSharedPreferences("haptic_settings", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("haptic_enabled", isHapticEnabled)
            .putFloat("haptic_intensity", globalIntensity)
            .apply()
    }
}