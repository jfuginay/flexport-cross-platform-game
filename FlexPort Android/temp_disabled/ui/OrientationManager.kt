package com.flexport.game.ui

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Manages orientation state and provides utilities for dual-view implementation
 */
class OrientationManager private constructor(private val context: Context) {
    
    companion object {
        @Volatile
        private var INSTANCE: OrientationManager? = null
        
        fun getInstance(context: Context): OrientationManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: OrientationManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    private val _orientation = MutableStateFlow(getCurrentOrientation())
    val orientation: StateFlow<DeviceOrientation> = _orientation.asStateFlow()
    
    private val _isTablet = MutableStateFlow(isTabletDevice())
    val isTablet: StateFlow<Boolean> = _isTablet.asStateFlow()
    
    fun updateOrientation(configuration: Configuration) {
        _orientation.value = when (configuration.orientation) {
            Configuration.ORIENTATION_LANDSCAPE -> DeviceOrientation.LANDSCAPE
            Configuration.ORIENTATION_PORTRAIT -> DeviceOrientation.PORTRAIT
            else -> DeviceOrientation.PORTRAIT
        }
    }
    
    private fun getCurrentOrientation(): DeviceOrientation {
        return when (context.resources.configuration.orientation) {
            Configuration.ORIENTATION_LANDSCAPE -> DeviceOrientation.LANDSCAPE
            Configuration.ORIENTATION_PORTRAIT -> DeviceOrientation.PORTRAIT
            else -> DeviceOrientation.PORTRAIT
        }
    }
    
    private fun isTabletDevice(): Boolean {
        val configuration = context.resources.configuration
        return configuration.screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK >= 
               Configuration.SCREENLAYOUT_SIZE_LARGE
    }
    
    fun shouldShowDualPane(): Boolean {
        return isTablet.value && orientation.value == DeviceOrientation.LANDSCAPE
    }
}

enum class DeviceOrientation {
    PORTRAIT,
    LANDSCAPE
}

/**
 * Composable that provides orientation state
 */
@Composable
fun rememberOrientation(): State<DeviceOrientation> {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val orientationManager = remember { OrientationManager.getInstance(context) }
    
    DisposableEffect(configuration.orientation) {
        orientationManager.updateOrientation(configuration)
        onDispose { }
    }
    
    return orientationManager.orientation.collectAsState()
}

/**
 * Composable that provides tablet state
 */
@Composable
fun rememberIsTablet(): State<Boolean> {
    val context = LocalContext.current
    val orientationManager = remember { OrientationManager.getInstance(context) }
    return orientationManager.isTablet.collectAsState()
}

/**
 * Data class for maintaining view state across orientation changes
 */
data class DualViewState(
    val selectedPortId: String? = null,
    val mapZoomLevel: Float = 1.0f,
    val mapCenterLat: Double = 0.0,
    val mapCenterLon: Double = 0.0,
    val isDashboardExpanded: Boolean = false,
    val activeTab: DashboardTab = DashboardTab.FLEET
)

enum class DashboardTab {
    FLEET,
    ECONOMICS,
    PORTS,
    MULTIPLAYER
}