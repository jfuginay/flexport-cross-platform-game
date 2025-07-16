package com.flexport.game.ecs.components

import com.flexport.game.ecs.Component
import kotlinx.serialization.Serializable

/**
 * Component that makes an entity selectable
 * Tracks selection state and provides selection-related functionality
 */
@Serializable
data class SelectableComponent(
    private var selected: Boolean = false,
    val selectable: Boolean = true,
    val selectionGroup: String? = null,
    val multiSelectable: Boolean = true,
    val selectionPriority: Int = 0
) : Component {
    
    /**
     * Check if the entity is currently selected
     */
    fun isSelected(): Boolean = selected
    
    /**
     * Set the selection state
     */
    fun setSelected(selected: Boolean): SelectableComponent {
        if (selectable) {
            this.selected = selected
        }
        return this
    }
    
    /**
     * Toggle selection state
     */
    fun toggleSelection(): SelectableComponent {
        if (selectable) {
            this.selected = !this.selected
        }
        return this
    }
    
    /**
     * Check if this entity can be selected
     */
    fun canBeSelected(): Boolean = selectable
    
    /**
     * Check if this entity belongs to a selection group
     */
    fun hasSelectionGroup(): Boolean = selectionGroup != null
    
    /**
     * Check if this entity is in the same selection group as another
     */
    fun isInSameGroup(other: SelectableComponent): Boolean {
        return selectionGroup != null && selectionGroup == other.selectionGroup
    }
    
    /**
     * Create a copy with updated selection state
     */
    fun withSelection(selected: Boolean): SelectableComponent {
        return copy().apply { setSelected(selected) }
    }
    
    /**
     * Create a copy with updated selectability
     */
    fun withSelectability(selectable: Boolean): SelectableComponent {
        return copy(selectable = selectable)
    }
    
    companion object {
        // Common selection groups
        const val GROUP_SHIPS = "ships"
        const val GROUP_PORTS = "ports"
        const val GROUP_UI = "ui"
        const val GROUP_ROUTES = "routes"
        const val GROUP_MARKERS = "markers"
        
        /**
         * Create a selectable component for a specific group
         */
        fun forGroup(group: String, multiSelectable: Boolean = true): SelectableComponent {
            return SelectableComponent(
                selectionGroup = group,
                multiSelectable = multiSelectable
            )
        }
        
        /**
         * Create a single-select only component
         */
        fun singleSelect(group: String? = null): SelectableComponent {
            return SelectableComponent(
                selectionGroup = group,
                multiSelectable = false
            )
        }
        
        /**
         * Create a non-selectable component (useful for visual indicators)
         */
        fun nonSelectable(): SelectableComponent {
            return SelectableComponent(selectable = false)
        }
    }
}