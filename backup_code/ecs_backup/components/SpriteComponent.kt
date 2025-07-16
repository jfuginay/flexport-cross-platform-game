package com.flexport.ecs.components

import com.flexport.ecs.core.Component
import com.flexport.rendering.texture.Texture
import com.flexport.rendering.texture.TextureRegion

/**
 * Component for sprite rendering
 */
data class SpriteComponent(
    var texture: Texture? = null,
    var textureRegion: TextureRegion? = null,
    var width: Float = 0f,
    var height: Float = 0f,
    var tintR: Float = 1f,
    var tintG: Float = 1f,
    var tintB: Float = 1f,
    var alpha: Float = 1f,
    var flipX: Boolean = false,
    var flipY: Boolean = false,
    var visible: Boolean = true,
    var layer: Int = 0 // For depth sorting
) : Component {
    
    /**
     * Set tint color
     */
    fun setTint(r: Float, g: Float, b: Float, a: Float = alpha) {
        tintR = r
        tintG = g
        tintB = b
        alpha = a
    }
    
    /**
     * Set sprite size
     */
    fun setSize(width: Float, height: Float) {
        this.width = width
        this.height = height
    }
    
    /**
     * Set sprite size from texture
     */
    fun setSizeFromTexture() {
        texture?.let {
            width = it.width.toFloat()
            height = it.height.toFloat()
        } ?: textureRegion?.let {
            width = it.regionWidth.toFloat()
            height = it.regionHeight.toFloat()
        }
    }
    
    /**
     * Get the effective texture to render
     */
    fun getEffectiveTexture(): Texture? {
        return texture ?: textureRegion?.texture
    }
    
    /**
     * Check if sprite has a texture to render
     */
    fun hasTexture(): Boolean {
        return texture != null || textureRegion != null
    }
}