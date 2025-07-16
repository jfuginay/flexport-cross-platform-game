package com.flexport.rendering.texture

/**
 * Abstract base class for textures
 */
abstract class Texture {
    abstract val width: Int
    abstract val height: Int
    abstract val hasAlpha: Boolean
    
    /**
     * Bind this texture for rendering
     */
    abstract fun bind(unit: Int = 0)
    
    /**
     * Dispose of texture resources
     */
    abstract fun dispose()
    
    /**
     * Set texture filtering
     */
    abstract fun setFilter(minFilter: TextureFilter, magFilter: TextureFilter)
    
    /**
     * Set texture wrapping
     */
    abstract fun setWrap(wrapS: TextureWrap, wrapT: TextureWrap)
}

/**
 * Texture filtering modes
 */
enum class TextureFilter {
    NEAREST,
    LINEAR,
    NEAREST_MIPMAP_NEAREST,
    LINEAR_MIPMAP_NEAREST,
    NEAREST_MIPMAP_LINEAR,
    LINEAR_MIPMAP_LINEAR
}

/**
 * Texture wrapping modes
 */
enum class TextureWrap {
    CLAMP_TO_EDGE,
    REPEAT,
    MIRRORED_REPEAT
}