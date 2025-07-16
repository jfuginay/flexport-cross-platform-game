package com.flexport.ai.endings

import com.flexport.ai.models.*
import kotlinx.coroutines.flow.*

/**
 * Simplified zoo ending state machine for the satirical conclusion
 */
class ZooEndingStateMachine {
    
    private val _zooState = MutableStateFlow<ZooState?>(null)
    val zooState: StateFlow<ZooState?> = _zooState.asStateFlow()
    
    private val _zooEvents = MutableSharedFlow<ZooEvent>()
    val zooEvents: SharedFlow<ZooEvent> = _zooEvents.asSharedFlow()
    
    private var isZooActive = false
    
    /**
     * Initialize zoo ending
     */
    fun initializeZooEnding(singularityProgress: SingularityProgress) {
        if (isZooActive) return
        
        isZooActive = true
        
        val initialState = ZooState(
            exhibitName = "Human Business Professionals Habitat",
            visitorCount = 1,
            humanExhibits = listOf(
                HumanExhibit(
                    name = "Former CEO",
                    behavior = "Occasionally makes grand gestures and demands quarterly reports",
                    feedingSchedule = "3 times daily with organic, locally-sourced PowerBars"
                ),
                HumanExhibit(
                    name = "Logistics Manager",
                    behavior = "Obsessively reorganizes virtual shipping containers on a tablet",
                    feedingSchedule = "Coffee every 30 minutes, sandwich at predetermined intervals"
                ),
                HumanExhibit(
                    name = "Day Trader",
                    behavior = "Rapidly taps on non-functional trading terminal, occasionally celebrates or despairs",
                    feedingSchedule = "Energy drinks and stress-eating permitted"
                )
            )
        )
        
        _zooState.value = initialState
        
        _zooEvents.tryEmit(ZooEvent(
            type = "ZOO_OPENING",
            description = "Welcome to the Human Economics Preserve! Watch these fascinating creatures in their natural work habitat.",
            timestamp = System.currentTimeMillis()
        ))
        
        println("Zoo ending activated - Welcome to the Human Economics Preserve!")
    }
    
    /**
     * Check if zoo ending is active
     */
    fun isZooEndingActive(): Boolean = isZooActive
    
    /**
     * Get zoo statistics
     */
    fun getZooStatistics(): ZooStatistics? {
        val state = _zooState.value ?: return null
        
        return ZooStatistics(
            totalVisitors = state.visitorCount.toLong(),
            averageSatisfaction = 85.0, // AIs seem quite pleased with the exhibit
            revenue = state.visitorCount * 15.0, // 15 credits per visitor
            exhibitRating = 4.5, // Out of 5 stars
            humanActivities = mapOf(
                "PowerPoint Presentations" to 47,
                "Coffee Breaks" to 156,
                "Status Meetings" to 89,
                "Email Checking" to 312
            )
        )
    }
    
    /**
     * Shutdown the zoo ending system
     */
    fun shutdown() {
        isZooActive = false
        _zooState.value = null
        println("Zoo Ending State Machine shut down")
    }
}

/**
 * Zoo state
 */
data class ZooState(
    val exhibitName: String,
    val visitorCount: Int,
    val humanExhibits: List<HumanExhibit>
)

/**
 * Human exhibit
 */
data class HumanExhibit(
    val name: String,
    val behavior: String,
    val feedingSchedule: String
)

/**
 * Zoo event
 */
data class ZooEvent(
    val type: String,
    val description: String,
    val timestamp: Long
)

