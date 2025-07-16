package com.flexport.ecs.components

import com.flexport.ecs.core.Component
import com.flexport.rendering.camera.Camera2D

/**
 * Component that holds a camera for rendering
 */
data class CameraComponent(
    var camera: Camera2D? = null,
    var isActive: Boolean = false
) : Component