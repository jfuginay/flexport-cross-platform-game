package com.flexport.ecs.components

import com.flexport.ecs.core.Component

/**
 * Component for entities that can be selected
 */
data class SelectableComponent(
    var isSelected: Boolean = false,
    var selectionGroup: String? = null, // Group for multi-selection logic
    var isMultiSelectEnabled: Boolean = false,
    var selectionCallback: ((Boolean) -> Unit)? = null
) : Component {
    
    /**
     * Toggle selection state
     */
    fun toggleSelection() {
        setSelected(!isSelected)
    }
    
    /**
     * Set selection state with callback
     */
    fun setSelected(selected: Boolean) {
        if (isSelected != selected) {
            isSelected = selected
            selectionCallback?.invoke(selected)
        }
    }
}