package com.flexport.assets.models

/**
 * Enum representing different types of assets in the logistics system
 */
enum class AssetType {
    // Water vessels
    CONTAINER_SHIP,
    BULK_CARRIER,
    TANKER,
    
    // Air transport
    CARGO_AIRCRAFT,
    PASSENGER_AIRCRAFT,
    
    // Ground facilities
    WAREHOUSE,
    DISTRIBUTION_CENTER,
    PORT_TERMINAL,
    
    // Ground vehicles
    TRUCK,
    RAIL_CAR,
    
    // Equipment
    CRANE,
    FORKLIFT
}