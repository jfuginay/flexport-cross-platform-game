package com.flexport.economics.models

/**
 * Types of employees in the logistics business
 */
enum class EmployeeType {
    // Technical staff
    ENGINEER,
    
    // Business staff
    SALES,
    OPERATIONS,
    CUSTOMER_SERVICE,
    LOGISTICS_COORDINATOR,
    
    // Specialized transport staff
    PILOT,
    SHIP_CAPTAIN,
    DOCK_WORKER,
    WAREHOUSE_MANAGER,
    
    // Management
    EXECUTIVE
}

/**
 * Skill levels for employees
 */
enum class SkillLevel(val multiplier: Double) {
    JUNIOR(0.8),
    MID(1.0),
    SENIOR(1.3),
    EXPERT(1.6)
}

/**
 * Employee data class
 */
data class Employee(
    val id: String,
    val name: String,
    val type: EmployeeType,
    val skillLevel: SkillLevel,
    val experience: Double, // years
    val productivity: Double, // productivity factor
    val salary: Double,
    val benefits: Benefits?,
    val performance: PerformanceMetrics
)

/**
 * Performance metrics for employees
 */
data class PerformanceMetrics(
    val efficiency: Double, // 0-1
    val quality: Double, // 0-1
    val reliability: Double, // 0-1
    val teamwork: Double, // 0-1
    val initiative: Double // 0-1
) {
    val overallRating: Double
        get() = (efficiency + quality + reliability + teamwork + initiative) / 5.0
}