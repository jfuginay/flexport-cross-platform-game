package com.flexport.game.ecs.components

import com.flexport.game.ecs.Component
import kotlinx.serialization.Serializable

/**
 * Component that makes an entity interactable for UI and gameplay purposes
 * Supports various interaction types like click, hover, drag, etc.
 */
@Serializable
data class InteractableComponent(
    val interactionType: InteractionType = InteractionType.CLICK,
    val enabled: Boolean = true,
    val requiresSelection: Boolean = false,
    val consumesInput: Boolean = true,
    val interactionGroup: String? = null,
    val cooldownMs: Long = 0L,
    private var lastInteractionTime: Long = 0L,
    val metadata: Map<String, String> = emptyMap()
) : Component {
    
    /**
     * Types of interactions supported
     */
    enum class InteractionType {
        CLICK,          // Single tap/click
        DOUBLE_CLICK,   // Double tap/click
        LONG_PRESS,     // Press and hold
        DRAG,           // Drag interaction
        HOVER,          // Hover (for mouse/cursor)
        CONTEXT_MENU,   // Right-click or long-press menu
        CUSTOM          // Custom interaction defined by metadata
    }
    
    /**
     * Check if the entity can be interacted with
     */
    fun canInteract(): Boolean {
        if (!enabled) return false
        
        // Check cooldown
        if (cooldownMs > 0) {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastInteractionTime < cooldownMs) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Record an interaction and update cooldown
     */
    fun recordInteraction(): InteractableComponent {
        lastInteractionTime = System.currentTimeMillis()
        return this
    }
    
    /**
     * Get remaining cooldown time in milliseconds
     */
    fun getRemainingCooldown(): Long {
        if (cooldownMs <= 0) return 0L
        
        val currentTime = System.currentTimeMillis()
        val elapsed = currentTime - lastInteractionTime
        
        return if (elapsed >= cooldownMs) 0L else cooldownMs - elapsed
    }
    
    /**
     * Check if this interaction requires the entity to be selected first
     */
    fun needsSelection(): Boolean = requiresSelection
    
    /**
     * Check if this interaction consumes the input event
     */
    fun shouldConsumeInput(): Boolean = consumesInput
    
    /**
     * Get metadata value by key
     */
    fun getMetadata(key: String): String? = metadata[key]
    
    /**
     * Check if metadata contains a key
     */
    fun hasMetadata(key: String): Boolean = metadata.containsKey(key)
    
    /**
     * Create a copy with updated enabled state
     */
    fun withEnabled(enabled: Boolean): InteractableComponent {
        return copy(enabled = enabled)
    }
    
    /**
     * Create a copy with updated metadata
     */
    fun withMetadata(key: String, value: String): InteractableComponent {
        return copy(metadata = metadata + (key to value))
    }
    
    /**
     * Create a copy with multiple metadata updates
     */
    fun withMetadata(updates: Map<String, String>): InteractableComponent {
        return copy(metadata = metadata + updates)
    }
    
    companion object {
        // Common interaction groups
        const val GROUP_UI_BUTTONS = "ui_buttons"
        const val GROUP_GAME_OBJECTS = "game_objects"
        const val GROUP_MAP_MARKERS = "map_markers"
        const val GROUP_MENU_ITEMS = "menu_items"
        
        // Common metadata keys
        const val META_ACTION = "action"
        const val META_TARGET = "target"
        const val META_TOOLTIP = "tooltip"
        const val META_SOUND = "sound"
        const val META_ANIMATION = "animation"
        
        /**
         * Create a simple clickable interaction
         */
        fun clickable(
            enabled: Boolean = true,
            consumesInput: Boolean = true,
            metadata: Map<String, String> = emptyMap()
        ): InteractableComponent {
            return InteractableComponent(
                interactionType = InteractionType.CLICK,
                enabled = enabled,
                consumesInput = consumesInput,
                metadata = metadata
            )
        }
        
        /**
         * Create a draggable interaction
         */
        fun draggable(
            enabled: Boolean = true,
            requiresSelection: Boolean = true,
            metadata: Map<String, String> = emptyMap()
        ): InteractableComponent {
            return InteractableComponent(
                interactionType = InteractionType.DRAG,
                enabled = enabled,
                requiresSelection = requiresSelection,
                metadata = metadata
            )
        }
        
        /**
         * Create a context menu interaction
         */
        fun contextMenu(
            enabled: Boolean = true,
            requiresSelection: Boolean = false,
            metadata: Map<String, String> = emptyMap()
        ): InteractableComponent {
            return InteractableComponent(
                interactionType = InteractionType.CONTEXT_MENU,
                enabled = enabled,
                requiresSelection = requiresSelection,
                metadata = metadata
            )
        }
        
        /**
         * Create an interaction with cooldown
         */
        fun withCooldown(
            interactionType: InteractionType,
            cooldownMs: Long,
            metadata: Map<String, String> = emptyMap()
        ): InteractableComponent {
            return InteractableComponent(
                interactionType = interactionType,
                cooldownMs = cooldownMs,
                metadata = metadata
            )
        }
    }
}