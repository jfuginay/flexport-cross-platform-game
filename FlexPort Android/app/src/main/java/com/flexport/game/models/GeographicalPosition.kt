package com.flexport.game.models

import kotlinx.serialization.Serializable

/**
 * Represents a geographical position on Earth using latitude and longitude coordinates.
 * This is a core model used throughout the game for positioning ports, ships, and routes.
 */
@Serializable
data class GeographicalPosition(
    val latitude: Double,
    val longitude: Double
) {
    init {
        require(latitude in -90.0..90.0) { "Latitude must be between -90 and 90 degrees" }
        require(longitude in -180.0..180.0) { "Longitude must be between -180 and 180 degrees" }
    }
    
    /**
     * Calculate the distance between two geographical positions using Haversine formula.
     * Returns distance in nautical miles.
     */
    fun distanceTo(other: GeographicalPosition): Double {
        val earthRadiusNm = 3440.065 // Earth radius in nautical miles
        
        val lat1Rad = Math.toRadians(latitude)
        val lat2Rad = Math.toRadians(other.latitude)
        val deltaLatRad = Math.toRadians(other.latitude - latitude)
        val deltaLonRad = Math.toRadians(other.longitude - longitude)
        
        val a = kotlin.math.sin(deltaLatRad / 2) * kotlin.math.sin(deltaLatRad / 2) +
                kotlin.math.cos(lat1Rad) * kotlin.math.cos(lat2Rad) *
                kotlin.math.sin(deltaLonRad / 2) * kotlin.math.sin(deltaLonRad / 2)
        
        val c = 2 * kotlin.math.atan2(kotlin.math.sqrt(a), kotlin.math.sqrt(1 - a))
        
        return earthRadiusNm * c
    }
    
    /**
     * Calculate the bearing from this position to another in degrees (0-360).
     */
    fun bearingTo(other: GeographicalPosition): Double {
        val lat1Rad = Math.toRadians(latitude)
        val lat2Rad = Math.toRadians(other.latitude)
        val deltaLonRad = Math.toRadians(other.longitude - longitude)
        
        val y = kotlin.math.sin(deltaLonRad) * kotlin.math.cos(lat2Rad)
        val x = kotlin.math.cos(lat1Rad) * kotlin.math.sin(lat2Rad) -
                kotlin.math.sin(lat1Rad) * kotlin.math.cos(lat2Rad) * kotlin.math.cos(deltaLonRad)
        
        val bearingRad = kotlin.math.atan2(y, x)
        return (Math.toDegrees(bearingRad) + 360) % 360
    }
    
    override fun toString(): String {
        val latDirection = if (latitude >= 0) "N" else "S"
        val lonDirection = if (longitude >= 0) "E" else "W"
        return "${kotlin.math.abs(latitude)}°$latDirection, ${kotlin.math.abs(longitude)}°$lonDirection"
    }
}