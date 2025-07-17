package com.flexport.game.rendering

import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.flexport.game.models.Port
import com.flexport.game.models.Ship
import com.flexport.game.rendering.shaders.ShaderProgram
import com.flexport.game.rendering.shaders.WaterShader
import com.flexport.game.rendering.sprites.ShipSprite
import com.flexport.game.rendering.sprites.PortSprite
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * OpenGL ES 3.0 renderer for the game map
 */
class MapRenderer(
    private val context: Context,
    private var initialZoom: Float,
    private var initialCenterLat: Double,
    private var initialCenterLon: Double,
    private val onPortSelected: (String) -> Unit,
    private val onZoomChanged: (Float) -> Unit,
    private val onCenterChanged: (Double, Double) -> Unit
) : GLSurfaceView.Renderer {
    
    // Matrices
    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val vpMatrix = FloatArray(16)
    
    // Shaders
    private lateinit var waterShader: WaterShader
    private lateinit var spriteShader: ShaderProgram
    
    // Game objects
    private var ports = emptyList<Port>()
    private var ships = emptyList<Ship>()
    private var routes = emptyList<Route>()
    
    // Sprites
    private val portSprites = mutableMapOf<String, PortSprite>()
    private val shipSprites = mutableMapOf<String, ShipSprite>()
    
    // Camera state
    private var zoom = initialZoom
    private var centerLat = initialCenterLat
    private var centerLon = initialCenterLon
    
    // Animation
    private var time = 0f
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        // Set clear color (ocean blue)
        GLES30.glClearColor(0.05f, 0.15f, 0.3f, 1.0f)
        
        // Enable depth testing
        GLES30.glEnable(GLES30.GL_DEPTH_TEST)
        GLES30.glDepthFunc(GLES30.GL_LEQUAL)
        
        // Enable blending for transparency
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        
        // Initialize shaders
        waterShader = WaterShader(context)
        spriteShader = ShaderProgram(context, "sprite_vertex.glsl", "sprite_fragment.glsl")
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES30.glViewport(0, 0, width, height)
        
        // Calculate projection matrix
        val ratio = width.toFloat() / height.toFloat()
        Matrix.frustumM(projectionMatrix, 0, -ratio, ratio, -1f, 1f, 1f, 100f)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        // Clear the screen
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT or GLES30.GL_DEPTH_BUFFER_BIT)
        
        // Update time for animations
        time += 0.016f // ~60 FPS
        
        // Update view matrix based on camera position
        updateViewMatrix()
        
        // Calculate view-projection matrix
        Matrix.multiplyMM(vpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        
        // Render layers in order
        renderWater()
        renderRoutes()
        renderPorts()
        renderShips()
    }
    
    private fun updateViewMatrix() {
        Matrix.setLookAtM(
            viewMatrix, 0,
            0f, 0f, zoom, // Camera position
            centerLon.toFloat(), centerLat.toFloat(), 0f, // Look at center
            0f, 1f, 0f // Up vector
        )
    }
    
    private fun renderWater() {
        waterShader.use()
        waterShader.setTime(time)
        waterShader.setViewProjectionMatrix(vpMatrix)
        waterShader.render()
    }
    
    private fun renderRoutes() {
        // TODO: Implement route rendering with lines/curves
        spriteShader.use()
        routes.forEach { route ->
            // Render route lines between ports
        }
    }
    
    private fun renderPorts() {
        spriteShader.use()
        spriteShader.setUniformMatrix4fv("u_VPMatrix", vpMatrix)
        
        ports.forEach { port ->
            val sprite = portSprites.getOrPut(port.id) {
                PortSprite(context, port)
            }
            
            // Convert lat/lon to world coordinates
            val worldX = port.position.longitude.toFloat()
            val worldY = port.position.latitude.toFloat()
            
            sprite.render(spriteShader, worldX, worldY, zoom)
        }
    }
    
    private fun renderShips() {
        spriteShader.use()
        spriteShader.setUniformMatrix4fv("u_VPMatrix", vpMatrix)
        
        ships.forEach { ship ->
            val sprite = shipSprites.getOrPut(ship.id) {
                ShipSprite(context, ship)
            }
            
            // Get ship position (would come from route/movement system)
            val worldX = 0f // TODO: Get from ship position
            val worldY = 0f // TODO: Get from ship position
            
            sprite.render(spriteShader, worldX, worldY, zoom, time)
        }
    }
    
    // Public methods to update game state
    fun updatePorts(newPorts: List<Port>) {
        ports = newPorts
    }
    
    fun updateShips(newShips: List<Ship>) {
        ships = newShips
    }
    
    fun updateRoutes(newRoutes: List<Route>) {
        routes = newRoutes
    }
    
    fun setZoomLevel(newZoom: Float) {
        zoom = newZoom.coerceIn(0.5f, 10f)
        onZoomChanged(zoom)
    }
    
    fun setCenter(lat: Double, lon: Double) {
        centerLat = lat
        centerLon = lon
        onCenterChanged(centerLat, centerLon)
    }
    
    // Touch handling methods
    fun handleTap(x: Float, y: Float, viewWidth: Int, viewHeight: Int) {
        // Convert screen coordinates to world coordinates
        val worldCoords = screenToWorld(x, y, viewWidth, viewHeight)
        
        // Check if a port was tapped
        ports.forEach { port ->
            val portX = port.position.longitude.toFloat()
            val portY = port.position.latitude.toFloat()
            
            val distance = kotlin.math.sqrt(
                (worldCoords.first - portX) * (worldCoords.first - portX) +
                (worldCoords.second - portY) * (worldCoords.second - portY)
            )
            
            if (distance < 0.5f / zoom) { // Adjust threshold based on zoom
                onPortSelected(port.id)
                return
            }
        }
    }
    
    fun handlePinch(scaleFactor: Float) {
        setZoomLevel(zoom * scaleFactor)
    }
    
    fun handlePan(dx: Float, dy: Float) {
        // Convert screen delta to world delta based on zoom
        val worldDx = dx / (100f * zoom)
        val worldDy = dy / (100f * zoom)
        
        setCenter(centerLat - worldDy, centerLon + worldDx)
    }
    
    private fun screenToWorld(screenX: Float, screenY: Float, viewWidth: Int, viewHeight: Int): Pair<Float, Float> {
        // Normalize screen coordinates
        val normalizedX = (screenX / viewWidth) * 2f - 1f
        val normalizedY = 1f - (screenY / viewHeight) * 2f
        
        // Create inverse VP matrix
        val invVPMatrix = FloatArray(16)
        Matrix.invertM(invVPMatrix, 0, vpMatrix, 0)
        
        // Transform to world coordinates
        val worldCoords = FloatArray(4)
        Matrix.multiplyMV(worldCoords, 0, invVPMatrix, 0, floatArrayOf(normalizedX, normalizedY, 0f, 1f), 0)
        
        return Pair(worldCoords[0] / worldCoords[3], worldCoords[1] / worldCoords[3])
    }
}

// Simple route data class (should be in models)
data class Route(
    val id: String,
    val startPortId: String,
    val endPortId: String,
    val waypoints: List<Pair<Double, Double>> = emptyList()
)