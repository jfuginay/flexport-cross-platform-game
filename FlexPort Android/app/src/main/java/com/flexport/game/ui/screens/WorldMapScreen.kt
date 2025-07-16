package com.flexport.game.ui.screens

import com.flexport.game.models.Port
import com.flexport.game.models.PortType
import com.flexport.game.models.GeographicalPosition

import android.view.MotionEvent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flexport.input.*
import com.flexport.input.interactions.*
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.math.Vector2
import kotlin.math.*

/**
 * World Map Screen with integrated touch controls for pan, zoom, and port selection
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun WorldMapScreen(
    onNavigateBack: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    // Touch input state
    var cameraPosition by remember { mutableStateOf(Vector2(0f, 0f)) }
    var zoomLevel by remember { mutableStateOf(1f) }
    var selectedPort by remember { mutableStateOf<PortDisplayData?>(null) }
    
    // Touch input managers
    val camera = remember { Camera2D(1080f, 1920f) }
    val touchInputManager = remember { TouchInputManager(camera) }
    
    // Sample ports data
    val ports = remember { generateSamplePorts() }
    
    // Update camera with current state
    LaunchedEffect(cameraPosition, zoomLevel) {
        camera.position.set(cameraPosition)
        camera.zoom = zoomLevel
    }
    
    Column(
        modifier = modifier.fillMaxSize()
    ) {
        // Top App Bar with controls
        TopAppBar(
            title = { 
                Text(
                    text = "World Map",
                    style = MaterialTheme.typography.h6.copy(
                        fontWeight = FontWeight.Medium
                    )
                )
            },
            navigationIcon = {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            },
            actions = {
                // Zoom controls
                IconButton(
                    onClick = { zoomLevel = (zoomLevel * 1.2f).coerceAtMost(5f) }
                ) {
                    Icon(
                        imageVector = Icons.Default.ZoomIn,
                        contentDescription = "Zoom In"
                    )
                }
                IconButton(
                    onClick = { zoomLevel = (zoomLevel / 1.2f).coerceAtLeast(0.2f) }
                ) {
                    Icon(
                        imageVector = Icons.Default.ZoomOut,
                        contentDescription = "Zoom Out"
                    )
                }
                IconButton(
                    onClick = { 
                        cameraPosition = Vector2(0f, 0f)
                        zoomLevel = 1f
                    }
                ) {
                    Icon(
                        imageVector = Icons.Default.CenterFocusWeak,
                        contentDescription = "Center Map"
                    )
                }
            },
            backgroundColor = MaterialTheme.colors.primary,
            contentColor = Color.White,
            elevation = 4.dp
        )
        
        // Map content area with touch handling
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF0D4A6B)) // Ocean blue
        ) {
            // Map canvas with touch input
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer(
                        scaleX = zoomLevel,
                        scaleY = zoomLevel,
                        translationX = -cameraPosition.x * zoomLevel,
                        translationY = -cameraPosition.y * zoomLevel
                    )
                    .pointerInput(Unit) {
                        detectTransformGestures { centroid, pan, zoom, _ ->
                            // Handle pan
                            val panDelta = pan / zoomLevel
                            cameraPosition = Vector2(
                                (cameraPosition.x + panDelta.x).toFloat(),
                                (cameraPosition.y + panDelta.y).toFloat()
                            )
                            
                            // Handle zoom
                            zoomLevel = (zoomLevel * zoom).coerceIn(0.2f, 5f)
                        }
                    }
                    .pointerInput(Unit) {
                        detectTapGestures { offset ->
                            // Convert screen coordinates to world coordinates
                            val worldPos = camera.unproject(offset.x, offset.y)
                            
                            // Check if tap is on a port
                            val tappedPort = ports.find { portData ->
                                // Convert geographical position to screen position
                                val screenPos = convertGeoToScreen(portData.port.position)
                                val distance = Vector2.dst(
                                    worldPos.x, worldPos.y,
                                    screenPos.x, screenPos.y
                                )
                                distance < 50f // Port selection radius
                            }
                            
                            selectedPort = tappedPort
                        }
                    }
            ) {
                drawMap(ports, selectedPort)
            }
            
            // UI Overlay
            WorldMapOverlay(
                selectedPort = selectedPort,
                onClosePortDetails = { selectedPort = null },
                zoomLevel = zoomLevel,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

@Composable
private fun WorldMapOverlay(
    selectedPort: PortDisplayData?,
    onClosePortDetails: () -> Unit,
    zoomLevel: Float,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        // Zoom level indicator
        Card(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp),
            elevation = 4.dp,
            backgroundColor = MaterialTheme.colors.surface.copy(alpha = 0.9f)
        ) {
            Text(
                text = "Zoom: ${String.format("%.1f", zoomLevel)}x",
                modifier = Modifier.padding(8.dp),
                style = MaterialTheme.typography.caption,
                color = MaterialTheme.colors.onSurface
            )
        }
        
        // Instructions card
        Card(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(16.dp),
            elevation = 4.dp,
            backgroundColor = MaterialTheme.colors.surface.copy(alpha = 0.9f)
        ) {
            Column(
                modifier = Modifier.padding(12.dp)
            ) {
                Text(
                    text = "Touch Controls:",
                    style = MaterialTheme.typography.caption,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colors.onSurface
                )
                Text(
                    text = "• Pinch to zoom",
                    style = MaterialTheme.typography.caption,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.8f)
                )
                Text(
                    text = "• Drag to pan",
                    style = MaterialTheme.typography.caption,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.8f)
                )
                Text(
                    text = "• Tap ports to select",
                    style = MaterialTheme.typography.caption,
                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.8f)
                )
            }
        }
        
        // Port details panel
        if (selectedPort != null) {
            PortDetailsPanel(
                port = selectedPort,
                onClose = onClosePortDetails,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
            )
        }
    }
}

@Composable
private fun PortDetailsPanel(
    port: PortDisplayData,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp)),
        elevation = 8.dp,
        backgroundColor = MaterialTheme.colors.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = port.port.name,
                        style = MaterialTheme.typography.h6,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colors.onSurface
                    )
                    Text(
                        text = port.country,
                        style = MaterialTheme.typography.body2,
                        color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
                    )
                }
                
                IconButton(onClick = onClose) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = MaterialTheme.colors.onSurface
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(12.dp))
            
            // Port details
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                PortDetailItem("Capacity", "${port.port.capacity / 1000000}M TEU")
                PortDetailItem("Throughput", "${port.throughput}M")
                PortDetailItem("Efficiency", "${port.efficiency}%")
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = { /* Handle trade route creation */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Route,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Create Route")
                }
                
                OutlinedButton(
                    onClick = { /* Handle port info */ },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Details")
                }
            }
        }
    }
}

@Composable
private fun PortDetailItem(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.subtitle2,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colors.onSurface
        )
        Text(
            text = label,
            style = MaterialTheme.typography.caption,
            color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f)
        )
    }
}

private fun DrawScope.drawMap(ports: List<PortDisplayData>, selectedPort: PortDisplayData?) {
    // Draw simplified world map background
    drawRect(
        color = Color(0xFF1B5E20), // Land color
        topLeft = Offset(-1000f, -1000f),
        size = androidx.compose.ui.geometry.Size(2000f, 2000f)
    )
    
    // Draw some landmasses (simplified)
    val landmasses = listOf(
        // North America
        Offset(-800f, -400f) to androidx.compose.ui.geometry.Size(600f, 300f),
        // Europe
        Offset(-200f, -300f) to androidx.compose.ui.geometry.Size(300f, 200f),
        // Asia
        Offset(200f, -500f) to androidx.compose.ui.geometry.Size(700f, 400f),
        // Africa
        Offset(-100f, 0f) to androidx.compose.ui.geometry.Size(400f, 500f),
        // South America
        Offset(-600f, 200f) to androidx.compose.ui.geometry.Size(300f, 600f),
        // Australia
        Offset(500f, 300f) to androidx.compose.ui.geometry.Size(200f, 150f)
    )
    
    landmasses.forEach { (offset, size) ->
        drawRect(
            color = Color(0xFF2E7D32),
            topLeft = offset,
            size = size
        )
    }
    
    // Draw ports
    ports.forEach { portData ->
        val isSelected = portData == selectedPort
        val portColor = if (isSelected) Color(0xFFFFEB3B) else Color(0xFFFF5722)
        val portRadius = if (isSelected) 25f else 20f
        
        // Convert geographical position to screen position
        val screenPos = convertGeoToScreen(portData.port.position)
        
        // Port circle
        drawCircle(
            color = portColor,
            radius = portRadius,
            center = Offset(screenPos.x, screenPos.y)
        )
        
        // Port border
        drawCircle(
            color = Color.White,
            radius = portRadius,
            center = Offset(screenPos.x, screenPos.y),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3f)
        )
        
        // Selection indicator
        if (isSelected) {
            drawCircle(
                color = Color(0xFFFFEB3B).copy(alpha = 0.3f),
                radius = 40f,
                center = Offset(screenPos.x, screenPos.y)
            )
        }
    }
}

// Port display data
data class PortDisplayData(
    val port: Port,
    val country: String,
    val throughput: Double,
    val efficiency: Int
)

// Sample data generator
private fun generateSamplePorts(): List<PortDisplayData> {
    return listOf(
        PortDisplayData(
            Port("shanghai", "Shanghai", GeographicalPosition(31.2304, 121.4737), PortType.SEA, 47300000),
            "China", 43.5, 92
        ),
        PortDisplayData(
            Port("singapore", "Singapore", GeographicalPosition(1.3521, 103.8198), PortType.SEA, 37200000),
            "Singapore", 36.6, 95
        ),
        PortDisplayData(
            Port("rotterdam", "Rotterdam", GeographicalPosition(51.9244, 4.4777), PortType.SEA, 14800000),
            "Netherlands", 14.8, 88
        ),
        PortDisplayData(
            Port("los_angeles", "Los Angeles", GeographicalPosition(33.7406, -118.2706), PortType.SEA, 9300000),
            "USA", 9.2, 85
        ),
        PortDisplayData(
            Port("hamburg", "Hamburg", GeographicalPosition(53.5511, 9.9937), PortType.SEA, 8900000),
            "Germany", 8.7, 87
        ),
        PortDisplayData(
            Port("antwerp", "Antwerp", GeographicalPosition(51.2194, 4.4025), PortType.SEA, 12000000),
            "Belgium", 11.1, 89
        ),
        PortDisplayData(
            Port("dubai", "Dubai", GeographicalPosition(25.2048, 55.2708), PortType.SEA, 15400000),
            "UAE", 14.1, 90
        ),
        PortDisplayData(
            Port("new_york", "New York", GeographicalPosition(40.7128, -74.0060), PortType.SEA, 7000000),
            "USA", 6.8, 82
        ),
        PortDisplayData(
            Port("hong_kong", "Hong Kong", GeographicalPosition(22.3193, 114.1694), PortType.SEA, 18000000),
            "China", 17.8, 94
        ),
        PortDisplayData(
            Port("long_beach", "Long Beach", GeographicalPosition(33.7701, -118.1937), PortType.SEA, 8100000),
            "USA", 7.6, 83
        ),
        PortDisplayData(
            Port("tokyo", "Tokyo", GeographicalPosition(35.6762, 139.6503), PortType.SEA, 5100000),
            "Japan", 4.9, 91
        ),
        PortDisplayData(
            Port("busan", "Busan", GeographicalPosition(35.1796, 129.0756), PortType.SEA, 22000000),
            "South Korea", 21.7, 93
        ),
        PortDisplayData(
            Port("valencia", "Valencia", GeographicalPosition(39.4699, -0.3763), PortType.SEA, 5400000),
            "Spain", 5.2, 86
        ),
        PortDisplayData(
            Port("felixstowe", "Felixstowe", GeographicalPosition(51.9557, 1.3053), PortType.SEA, 4000000),
            "UK", 3.8, 84
        ),
        PortDisplayData(
            Port("santos", "Santos", GeographicalPosition(-23.9619, -46.3328), PortType.SEA, 4300000),
            "Brazil", 4.1, 81
        )
    )
}

// Helper function to convert geographical coordinates to screen coordinates
private fun convertGeoToScreen(position: GeographicalPosition): Vector2 {
    // Simple mercator projection (not accurate but good enough for visualization)
    val x = ((position.longitude + 180f) * 2.77f - 500f).toFloat()
    val y = (-(position.latitude - 90f) * 5.55f - 500f).toFloat()
    return Vector2(x, y)
}

@Preview(showBackground = true)
@Composable
fun WorldMapScreenPreview() {
    MaterialTheme {
        WorldMapScreen()
    }
}