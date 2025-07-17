package com.flexport.game.progression

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Event bus for progression system events
 * Allows decoupled communication between progression system and UI/game components
 */
object ProgressionEventBus {
    
    private val _events = MutableSharedFlow<ProgressionEvent>(
        replay = 0,
        extraBufferCapacity = 10
    )
    
    val events: Flow<ProgressionEvent> = _events.asSharedFlow()
    
    fun publish(event: ProgressionEvent) {
        _events.tryEmit(event)
    }
}