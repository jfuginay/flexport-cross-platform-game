package com.flexport.map.rendering

import com.flexport.map.models.*
import com.flexport.rendering.math.Vector2
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.opengl.GLRenderer
import com.flexport.rendering.opengl.GLSpriteBatch
import com.flexport.rendering.texture.Texture
import android.graphics.*
import kotlinx.coroutines.*
import kotlin.math.*

/**
 * Renders the world map, ports, and trade routes
 */
class MapRenderer(
    private val glRenderer: GLRenderer,
    private val spriteBatch: GLSpriteBatch,
    private val camera: Camera2D
) {
    
    private val mapTexture: Texture? = null // World map texture
    private val portTextures = mutableMapOf<PortSize, Texture>()
    private val routeRenderer = RouteRenderer()
    private val animationManager = RouteAnimationManager()
    
    private var mapWidth = 4096f
    private var mapHeight = 2048f
    
    // Rendering settings
    private var showPortLabels = true
    private var showRouteLabels = true
    private var showTrafficDensity = true
    private var minZoomForLabels = 0.5f
    private var minZoomForDetailedPorts = 1.0f
    
    /**
     * Render the complete map view
     */
    suspend fun render(
        ports: List<Port>,
        routes: List<TradeRoute>,
        vessels: List<VesselPosition>,
        deltaTime: Float
    ) = withContext(Dispatchers.Main) {
        
        spriteBatch.begin(camera.combined)
        
        // Render map background
        renderMapBackground()
        
        // Render shipping lanes and traffic density
        if (showTrafficDensity && camera.zoom >= 0.3f) {
            renderShippingLanes(routes)
        }
        
        // Render trade routes
        renderTradeRoutes(routes, deltaTime)
        
        // Render ports
        renderPorts(ports)
        
        // Render vessels
        renderVessels(vessels, deltaTime)
        
        // Render UI overlays
        if (camera.zoom >= minZoomForLabels) {
            renderPortLabels(ports)
        }
        
        if (showRouteLabels && camera.zoom >= minZoomForLabels) {
            renderRouteLabels(routes)
        }
        
        spriteBatch.end()
        
        // Update animations
        animationManager.update(deltaTime)
    }
    
    /**
     * Render the world map background
     */
    private fun renderMapBackground() {
        mapTexture?.let { texture ->
            val mapBounds = getMapBounds()
            spriteBatch.draw(
                texture,
                mapBounds.x,
                mapBounds.y,
                mapBounds.width,
                mapBounds.height
            )
        } ?: run {
            // Render simple blue background if no map texture
            spriteBatch.setColor(0.2f, 0.4f, 0.8f, 1.0f)
            spriteBatch.draw(
                null, // Use default white texture
                -mapWidth / 2,
                -mapHeight / 2,
                mapWidth,
                mapHeight
            )
            spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
        }
    }
    
    /**
     * Render shipping lanes and traffic density
     */
    private fun renderShippingLanes(routes: List<TradeRoute>) {
        val trafficDensity = calculateTrafficDensity(routes)
        
        trafficDensity.forEach { (segment, density) ->
            val alpha = (density / 100.0f).coerceIn(0.1f, 0.8f)
            val color = interpolateColor(Color.GREEN, Color.RED, density / 100.0f)
            
            spriteBatch.setColor(
                Color.red(color) / 255.0f,
                Color.green(color) / 255.0f,
                Color.blue(color) / 255.0f,
                alpha
            )
            
            renderShippingLane(segment.start, segment.end, 2.0f)
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render individual shipping lane
     */
    private fun renderShippingLane(start: GeographicalPosition, end: GeographicalPosition, width: Float) {
        val startScreen = start.toScreenCoordinates(mapWidth, mapHeight)
        val endScreen = end.toScreenCoordinates(mapWidth, mapHeight)
        
        routeRenderer.renderLine(
            spriteBatch,
            startScreen,
            endScreen,
            width,
            LineDash.NONE
        )
    }
    
    /**
     * Render trade routes with different styles based on status
     */
    private fun renderTradeRoutes(routes: List<TradeRoute>, deltaTime: Float) {
        routes.forEach { route ->
            when (route.status) {
                RouteStatus.ACTIVE -> renderActiveRoute(route, deltaTime)
                RouteStatus.PLANNING -> renderPlannedRoute(route)
                RouteStatus.DELAYED -> renderDelayedRoute(route, deltaTime)
                RouteStatus.SUSPENDED -> renderSuspendedRoute(route)
                else -> renderInactiveRoute(route)
            }
        }
    }
    
    /**
     * Render active trade route with animation
     */
    private fun renderActiveRoute(route: TradeRoute, deltaTime: Float) {
        val points = route.allPorts.map { port ->
            port.position.toScreenCoordinates(mapWidth, mapHeight)
        }
        
        // Animate cargo flow along the route
        val flowAnimation = animationManager.getFlowAnimation(route.id)
        val flowOffset = flowAnimation?.getCurrentOffset(deltaTime) ?: 0.0f
        
        spriteBatch.setColor(0.2f, 0.8f, 0.2f, 0.8f)
        
        for (i in 0 until points.size - 1) {
            routeRenderer.renderAnimatedLine(
                spriteBatch,
                points[i],
                points[i + 1],
                4.0f,
                flowOffset,
                LineDash.SOLID
            )
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render planned route (dashed line)
     */
    private fun renderPlannedRoute(route: TradeRoute) {
        val points = route.allPorts.map { port ->
            port.position.toScreenCoordinates(mapWidth, mapHeight)
        }
        
        spriteBatch.setColor(0.8f, 0.8f, 0.2f, 0.6f)
        
        for (i in 0 until points.size - 1) {
            routeRenderer.renderLine(
                spriteBatch,
                points[i],
                points[i + 1],
                3.0f,
                LineDash.MEDIUM
            )
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render delayed route with warning animation
     */
    private fun renderDelayedRoute(route: TradeRoute, deltaTime: Float) {
        val points = route.allPorts.map { port ->
            port.position.toScreenCoordinates(mapWidth, mapHeight)
        }
        
        // Pulsing red color for delayed routes
        val pulseIntensity = (sin(animationManager.getTotalTime() * 3.0f) + 1.0f) / 2.0f
        val red = 0.8f + 0.2f * pulseIntensity
        
        spriteBatch.setColor(red, 0.2f, 0.2f, 0.8f)
        
        for (i in 0 until points.size - 1) {
            routeRenderer.renderLine(
                spriteBatch,
                points[i],
                points[i + 1],
                4.0f,
                LineDash.LONG
            )
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render suspended route (dotted line)
     */
    private fun renderSuspendedRoute(route: TradeRoute) {
        val points = route.allPorts.map { port ->
            port.position.toScreenCoordinates(mapWidth, mapHeight)
        }
        
        spriteBatch.setColor(0.5f, 0.5f, 0.5f, 0.5f)
        
        for (i in 0 until points.size - 1) {
            routeRenderer.renderLine(
                spriteBatch,
                points[i],
                points[i + 1],
                2.0f,
                LineDash.SHORT
            )
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render inactive route (very faint)
     */
    private fun renderInactiveRoute(route: TradeRoute) {
        val points = route.allPorts.map { port ->
            port.position.toScreenCoordinates(mapWidth, mapHeight)
        }
        
        spriteBatch.setColor(0.3f, 0.3f, 0.3f, 0.3f)
        
        for (i in 0 until points.size - 1) {
            routeRenderer.renderLine(
                spriteBatch,
                points[i],
                points[i + 1],
                1.0f,
                LineDash.NONE
            )
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render ports with different icons based on size and type
     */
    private fun renderPorts(ports: List<Port>) {
        ports.forEach { port ->
            val screenPos = port.position.toScreenCoordinates(mapWidth, mapHeight)
            renderPort(port, screenPos)
        }
    }
    
    /**
     * Render individual port
     */
    private fun renderPort(port: Port, screenPos: Vector2) {
        val texture = getPortTexture(port.size)
        val scale = getPortScale(port.size, camera.zoom)
        val color = getPortColor(port)
        
        spriteBatch.setColor(color.red / 255.0f, color.green / 255.0f, color.blue / 255.0f, 1.0f)
        
        texture?.let {
            spriteBatch.draw(
                it,
                screenPos.x - it.width * scale / 2,
                screenPos.y - it.height * scale / 2,
                it.width * scale,
                it.height * scale
            )
        }
        
        // Render capacity indicator if detailed view
        if (camera.zoom >= minZoomForDetailedPorts) {
            renderPortCapacityIndicator(port, screenPos)
        }
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render port capacity indicator
     */
    private fun renderPortCapacityIndicator(port: Port, screenPos: Vector2) {
        val utilizationPercentage = calculatePortUtilization(port)
        val barWidth = 20.0f * camera.zoom
        val barHeight = 4.0f * camera.zoom
        
        // Background bar
        spriteBatch.setColor(0.3f, 0.3f, 0.3f, 0.8f)
        spriteBatch.draw(
            null,
            screenPos.x - barWidth / 2,
            screenPos.y - 25.0f * camera.zoom,
            barWidth,
            barHeight
        )
        
        // Utilization bar
        val utilizationColor = when {
            utilizationPercentage < 0.5f -> Color.GREEN
            utilizationPercentage < 0.8f -> Color.YELLOW
            else -> Color.RED
        }
        
        spriteBatch.setColor(
            Color.red(utilizationColor) / 255.0f,
            Color.green(utilizationColor) / 255.0f,
            Color.blue(utilizationColor) / 255.0f,
            0.9f
        )
        
        spriteBatch.draw(
            null,
            screenPos.x - barWidth / 2,
            screenPos.y - 25.0f * camera.zoom,
            barWidth * utilizationPercentage,
            barHeight
        )
    }
    
    /**
     * Render vessels at their current positions
     */
    private fun renderVessels(vessels: List<VesselPosition>, deltaTime: Float) {
        vessels.forEach { vesselPos ->
            renderVessel(vesselPos, deltaTime)
        }
    }
    
    /**
     * Render individual vessel
     */
    private fun renderVessel(vesselPos: VesselPosition, deltaTime: Float) {
        val screenPos = vesselPos.position.toScreenCoordinates(mapWidth, mapHeight)
        val texture = getVesselTexture(vesselPos.vessel.type)
        val scale = getVesselScale(vesselPos.vessel.type, camera.zoom)
        
        // Calculate rotation based on heading
        val rotation = vesselPos.heading
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
        
        texture?.let {
            spriteBatch.draw(
                it,
                screenPos.x - it.width * scale / 2,
                screenPos.y - it.height * scale / 2,
                it.width * scale / 2,
                it.height * scale / 2,
                it.width * scale,
                it.height * scale,
                1.0f,
                1.0f,
                rotation
            )
        }
        
        // Render vessel wake if moving
        if (vesselPos.speed > 0.1f) {
            renderVesselWake(vesselPos, screenPos)
        }
    }
    
    /**
     * Render vessel wake trail
     */
    private fun renderVesselWake(vesselPos: VesselPosition, screenPos: Vector2) {
        val wakeLength = 30.0f * camera.zoom
        val wakeAngle = vesselPos.heading + 180.0f // Opposite direction
        
        val wakeEnd = Vector2(
            screenPos.x + cos(Math.toRadians(wakeAngle.toDouble())).toFloat() * wakeLength,
            screenPos.y + sin(Math.toRadians(wakeAngle.toDouble())).toFloat() * wakeLength
        )
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 0.3f)
        
        routeRenderer.renderLine(
            spriteBatch,
            screenPos,
            wakeEnd,
            2.0f * vesselPos.speed / 20.0f, // Width based on speed
            LineDash.NONE
        )
        
        spriteBatch.setColor(1.0f, 1.0f, 1.0f, 1.0f)
    }
    
    /**
     * Render port labels
     */
    private fun renderPortLabels(ports: List<Port>) {
        // Port labels would be rendered using text rendering system
        // For now, we'll just mark the positions where labels should go
        ports.forEach { port ->
            val screenPos = port.position.toScreenCoordinates(mapWidth, mapHeight)
            // TODO: Render text label at screenPos offset by port size
        }
    }
    
    /**
     * Render route labels
     */
    private fun renderRouteLabels(routes: List<TradeRoute>) {
        routes.filter { it.status == RouteStatus.ACTIVE }.forEach { route ->
            val midpoint = calculateRouteMidpoint(route)
            val screenPos = midpoint.toScreenCoordinates(mapWidth, mapHeight)
            // TODO: Render route name and cargo info at screenPos
        }
    }
    
    // Helper functions
    
    private fun getMapBounds(): RectF {
        return RectF(-mapWidth / 2, -mapHeight / 2, mapWidth / 2, mapHeight / 2)
    }
    
    private fun getPortTexture(size: PortSize): Texture? {
        return portTextures[size]
    }
    
    private fun getPortScale(size: PortSize, zoom: Float): Float {
        val baseScale = when (size) {
            PortSize.SMALL -> 0.5f
            PortSize.MEDIUM -> 0.75f
            PortSize.LARGE -> 1.0f
            PortSize.MEGA -> 1.5f
        }
        return baseScale * zoom.coerceIn(0.5f, 2.0f)
    }
    
    private fun getPortColor(port: Port): Int {
        return when (port.portType) {
            PortType.COMMERCIAL -> Color.BLUE
            PortType.INDUSTRIAL -> Color.GRAY
            PortType.ENERGY -> Color.YELLOW
            PortType.CONTAINER -> Color.GREEN
            PortType.BULK -> Color.BROWN
            else -> Color.WHITE
        }
    }
    
    private fun getVesselTexture(type: VesselType): Texture? {
        // Return appropriate texture based on vessel type
        return null // TODO: Load vessel textures
    }
    
    private fun getVesselScale(type: VesselType, zoom: Float): Float {
        val baseScale = when (type) {
            VesselType.CONTAINER_SHIP -> 1.0f
            VesselType.BULK_CARRIER -> 0.9f
            VesselType.TANKER -> 0.8f
            else -> 0.7f
        }
        return baseScale * zoom.coerceIn(0.3f, 1.5f)
    }
    
    private fun calculatePortUtilization(port: Port): Float {
        // Calculate current port utilization based on traffic
        // This would be calculated from active routes and cargo
        return 0.6f // Placeholder
    }
    
    private fun calculateTrafficDensity(routes: List<TradeRoute>): Map<RouteSegment, Float> {
        val segmentTraffic = mutableMapOf<RouteSegment, Int>()
        
        routes.filter { it.status == RouteStatus.ACTIVE }.forEach { route ->
            val ports = route.allPorts
            for (i in 0 until ports.size - 1) {
                val segment = RouteSegment(ports[i].position, ports[i + 1].position)
                segmentTraffic[segment] = segmentTraffic.getOrDefault(segment, 0) + 1
            }
        }
        
        val maxTraffic = segmentTraffic.values.maxOrNull() ?: 1
        return segmentTraffic.mapValues { (it.value.toFloat() / maxTraffic) * 100.0f }
    }
    
    private fun calculateRouteMidpoint(route: TradeRoute): GeographicalPosition {
        val totalDistance = route.getTotalDistance()
        val halfDistance = totalDistance / 2.0
        
        var currentDistance = 0.0
        val ports = route.allPorts
        
        for (i in 0 until ports.size - 1) {
            val segmentDistance = ports[i].position.distanceTo(ports[i + 1].position)
            
            if (currentDistance + segmentDistance >= halfDistance) {
                val ratio = (halfDistance - currentDistance) / segmentDistance
                return interpolatePosition(ports[i].position, ports[i + 1].position, ratio)
            }
            
            currentDistance += segmentDistance
        }
        
        return route.destination.position
    }
    
    private fun interpolatePosition(start: GeographicalPosition, end: GeographicalPosition, ratio: Double): GeographicalPosition {
        val lat = start.latitude + (end.latitude - start.latitude) * ratio
        val lon = start.longitude + (end.longitude - start.longitude) * ratio
        return GeographicalPosition(lat, lon)
    }
    
    private fun interpolateColor(color1: Int, color2: Int, ratio: Float): Int {
        val r1 = Color.red(color1)
        val g1 = Color.green(color1)
        val b1 = Color.blue(color1)
        
        val r2 = Color.red(color2)
        val g2 = Color.green(color2)
        val b2 = Color.blue(color2)
        
        val r = (r1 + (r2 - r1) * ratio).toInt().coerceIn(0, 255)
        val g = (g1 + (g2 - g1) * ratio).toInt().coerceIn(0, 255)
        val b = (b1 + (b2 - b1) * ratio).toInt().coerceIn(0, 255)
        
        return Color.rgb(r, g, b)
    }
    
    // Configuration methods
    fun setShowPortLabels(show: Boolean) { showPortLabels = show }
    fun setShowRouteLabels(show: Boolean) { showRouteLabels = show }
    fun setShowTrafficDensity(show: Boolean) { showTrafficDensity = show }
}

/**
 * Represents a vessel's current position and movement
 */
data class VesselPosition(
    val vessel: Vessel,
    val position: GeographicalPosition,
    val heading: Float, // Degrees
    val speed: Float,   // Knots
    val route: TradeRoute?
)

/**
 * Route segment for traffic density calculation
 */
data class RouteSegment(
    val start: GeographicalPosition,
    val end: GeographicalPosition
)

/**
 * Line dash patterns for route rendering
 */
enum class LineDash {
    NONE,
    SHORT,
    MEDIUM,
    LONG,
    SOLID
}