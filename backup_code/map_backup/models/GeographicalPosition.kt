package com.flexport.map.models

import com.flexport.rendering.math.Vector2
import kotlin.math.*

/**
 * Represents a geographical position with latitude and longitude
 */
data class GeographicalPosition(
    val latitude: Double,
    val longitude: Double
) {
    init {
        require(latitude in -90.0..90.0) { "Latitude must be between -90 and 90 degrees" }
        require(longitude in -180.0..180.0) { "Longitude must be between -180 and 180 degrees" }
    }
    
    /**
     * Calculate distance to another position using Haversine formula
     * Returns distance in nautical miles
     */
    fun distanceTo(other: GeographicalPosition): Double {
        val earthRadiusNm = 3440.065 // Earth radius in nautical miles
        
        val dLat = Math.toRadians(other.latitude - latitude)
        val dLon = Math.toRadians(other.longitude - longitude)
        
        val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(latitude)) * cos(Math.toRadians(other.latitude)) *
                sin(dLon / 2) * sin(dLon / 2)
        
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusNm * c
    }
    
    /**
     * Calculate bearing to another position in degrees (0-360)
     */
    fun bearingTo(other: GeographicalPosition): Double {
        val dLon = Math.toRadians(other.longitude - longitude)
        val lat1 = Math.toRadians(latitude)
        val lat2 = Math.toRadians(other.latitude)
        
        val y = sin(dLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        val bearing = Math.toDegrees(atan2(y, x))
        return (bearing + 360) % 360
    }
    
    /**
     * Convert to screen coordinates for map rendering
     * Uses Mercator projection
     */
    fun toScreenCoordinates(mapWidth: Float, mapHeight: Float): Vector2 {
        val x = ((longitude + 180.0) / 360.0 * mapWidth).toFloat()
        
        val latRad = Math.toRadians(latitude)
        val mercN = ln(tan(PI / 4 + latRad / 2))
        val y = (mapHeight / 2 - (mapWidth * mercN / (2 * PI))).toFloat()
        
        return Vector2(x, y)
    }
    
    companion object {
        /**
         * Create position from screen coordinates
         */
        fun fromScreenCoordinates(screenX: Float, screenY: Float, mapWidth: Float, mapHeight: Float): GeographicalPosition {
            val longitude = (screenX / mapWidth * 360.0 - 180.0)
            
            val mercN = (mapHeight / 2 - screenY) * 2 * PI / mapWidth
            val latitude = Math.toDegrees(2 * atan(exp(mercN)) - PI / 2)
            
            return GeographicalPosition(latitude, longitude)
        }
    }
}

/**
 * Represents a geographical region or boundary
 */
data class GeographicalBounds(
    val northEast: GeographicalPosition,
    val southWest: GeographicalPosition
) {
    val center: GeographicalPosition
        get() = GeographicalPosition(
            (northEast.latitude + southWest.latitude) / 2,
            (northEast.longitude + southWest.longitude) / 2
        )
    
    fun contains(position: GeographicalPosition): Boolean {
        return position.latitude <= northEast.latitude &&
               position.latitude >= southWest.latitude &&
               position.longitude <= northEast.longitude &&
               position.longitude >= southWest.longitude
    }
}