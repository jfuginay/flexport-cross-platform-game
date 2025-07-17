package com.flexport.game.ui.components

import android.content.Context
import android.opengl.GLSurfaceView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.flexport.game.rendering.MapRenderer
import com.flexport.game.ui.DualViewState
import com.flexport.game.viewmodels.GameViewModel

/**
 * OpenGL ES powered map view for landscape mode
 */
@Composable
fun MapView(
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    gameViewModel: GameViewModel,
    modifier: Modifier = Modifier
) {
    val ports by gameViewModel.ports.collectAsState()
    val ships by gameViewModel.ships.collectAsState()
    val routes by gameViewModel.routes.collectAsState()
    
    Box(modifier = modifier) {
        AndroidView(
            factory = { context ->
                createGLSurfaceView(
                    context = context,
                    dualViewState = dualViewState,
                    onDualViewStateChange = onDualViewStateChange,
                    gameViewModel = gameViewModel
                )
            },
            update = { glSurfaceView ->
                // Update renderer with latest game state
                (glSurfaceView.renderer as? MapRenderer)?.apply {
                    updatePorts(ports)
                    updateShips(ships)
                    updateRoutes(routes)
                    setZoomLevel(dualViewState.mapZoomLevel)
                    setCenter(dualViewState.mapCenterLat, dualViewState.mapCenterLon)
                }
            },
            modifier = Modifier.fillMaxSize()
        )
    }
}

private fun createGLSurfaceView(
    context: Context,
    dualViewState: DualViewState,
    onDualViewStateChange: (DualViewState) -> Unit,
    gameViewModel: GameViewModel
): GLSurfaceView {
    return GLSurfaceView(context).apply {
        setEGLContextClientVersion(3) // OpenGL ES 3.0
        
        val renderer = MapRenderer(
            context = context,
            initialZoom = dualViewState.mapZoomLevel,
            initialCenterLat = dualViewState.mapCenterLat,
            initialCenterLon = dualViewState.mapCenterLon,
            onPortSelected = { portId ->
                onDualViewStateChange(dualViewState.copy(selectedPortId = portId))
            },
            onZoomChanged = { zoom ->
                onDualViewStateChange(dualViewState.copy(mapZoomLevel = zoom))
            },
            onCenterChanged = { lat, lon ->
                onDualViewStateChange(dualViewState.copy(
                    mapCenterLat = lat,
                    mapCenterLon = lon
                ))
            }
        )
        
        setRenderer(renderer)
        renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
    }
}