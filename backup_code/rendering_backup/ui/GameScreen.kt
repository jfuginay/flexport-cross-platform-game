package com.flexport.rendering.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.flexport.rendering.core.RenderStats

/**
 * Composable that combines OpenGL game rendering with Compose UI overlay
 */
@Composable
fun GameScreen(
    modifier: Modifier = Modifier,
    showDebugOverlay: Boolean = false,
    onInputEvent: (GameInputEvent) -> Unit = {}
) {
    val context = LocalContext.current
    var renderStats by remember { mutableStateOf<RenderStats?>(null) }
    var gameSurfaceView by remember { mutableStateOf<GameSurfaceView?>(null) }
    
    Box(modifier = modifier.fillMaxSize()) {
        // OpenGL rendering surface
        AndroidView(
            factory = { ctx ->
                GameSurfaceView(ctx).also { view ->
                    gameSurfaceView = view
                    view.setInputHandler(object : GameInputHandler {
                        override fun handleTouchEvent(event: android.view.MotionEvent) {
                            val inputEvent = when (event.action) {
                                android.view.MotionEvent.ACTION_DOWN -> 
                                    GameInputEvent.TouchDown(event.x, event.y)
                                android.view.MotionEvent.ACTION_MOVE -> 
                                    GameInputEvent.TouchMove(event.x, event.y)
                                android.view.MotionEvent.ACTION_UP -> 
                                    GameInputEvent.TouchUp(event.x, event.y)
                                else -> GameInputEvent.TouchUp(event.x, event.y)
                            }
                            onInputEvent(inputEvent)
                        }
                    })
                }
            },
            modifier = Modifier.fillMaxSize()
        )
        
        // UI Overlay
        if (showDebugOverlay) {
            DebugOverlay(
                renderStats = renderStats,
                modifier = Modifier.align(Alignment.TopEnd)
            )
        }
        
        // Game UI
        GameUI(
            modifier = Modifier.fillMaxSize(),
            onMenuClick = { onInputEvent(GameInputEvent.MenuClick) },
            onPauseClick = { onInputEvent(GameInputEvent.PauseClick) }
        )
        
        // Update render stats periodically
        LaunchedEffect(gameSurfaceView) {
            gameSurfaceView?.getRenderer()?.let { renderer ->
                while (true) {
                    kotlinx.coroutines.delay(500) // Update every 500ms
                    renderStats = renderer.getStats()
                }
            }
        }
    }
}

/**
 * Debug overlay showing rendering statistics
 */
@Composable
fun DebugOverlay(
    renderStats: RenderStats?,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.padding(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.Black.copy(alpha = 0.7f)
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = "DEBUG",
                style = MaterialTheme.typography.titleSmall,
                color = Color.White
            )
            
            if (renderStats != null) {
                Text(
                    text = "FPS: ${(1000f / renderStats.frameTimeMs).toInt()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
                Text(
                    text = "Draw calls: ${renderStats.drawCalls}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
                Text(
                    text = "Vertices: ${renderStats.verticesRendered}",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
                Text(
                    text = "Frame time: ${"%.2f".format(renderStats.frameTimeMs)}ms",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
            } else {
                Text(
                    text = "Loading...",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White
                )
            }
        }
    }
}

/**
 * Game UI overlay with controls
 */
@Composable
fun GameUI(
    modifier: Modifier = Modifier,
    onMenuClick: () -> Unit,
    onPauseClick: () -> Unit
) {
    Box(modifier = modifier) {
        // Top bar with menu and pause buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .align(Alignment.TopStart),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            IconButton(
                onClick = onMenuClick,
                colors = IconButtonDefaults.iconButtonColors(
                    containerColor = Color.Black.copy(alpha = 0.5f)
                )
            ) {
                Text("≡", color = Color.White)
            }
            
            IconButton(
                onClick = onPauseClick,
                colors = IconButtonDefaults.iconButtonColors(
                    containerColor = Color.Black.copy(alpha = 0.5f)
                )
            ) {
                Text("⏸", color = Color.White)
            }
        }
        
        // Bottom controls could go here
        // For example: virtual joystick, action buttons, etc.
    }
}

/**
 * Sealed class for game input events
 */
sealed class GameInputEvent {
    data class TouchDown(val x: Float, val y: Float) : GameInputEvent()
    data class TouchMove(val x: Float, val y: Float) : GameInputEvent()
    data class TouchUp(val x: Float, val y: Float) : GameInputEvent()
    object MenuClick : GameInputEvent()
    object PauseClick : GameInputEvent()
}