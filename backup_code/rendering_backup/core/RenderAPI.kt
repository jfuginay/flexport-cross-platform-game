package com.flexport.rendering.core

/**
 * Enum representing supported rendering APIs
 */
enum class RenderAPI {
    OPENGL_ES,
    VULKAN
}

/**
 * Data class for rendering configuration
 */
data class RenderConfig(
    val api: RenderAPI = RenderAPI.OPENGL_ES,
    val vsyncEnabled: Boolean = true,
    val multisampleCount: Int = 4,
    val targetFPS: Int = 60,
    val enableDebugLayer: Boolean = false
)