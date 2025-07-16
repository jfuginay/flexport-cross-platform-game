package com.flexport.rendering.core

import android.view.Surface
import com.flexport.rendering.batch.SpriteBatch
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.shader.ShaderProgram
import com.flexport.rendering.texture.Texture
import com.flexport.rendering.texture.TextureRegion
import kotlinx.coroutines.flow.StateFlow

/**
 * Abstract base class for renderers (OpenGL ES and Vulkan implementations)
 */
abstract class Renderer(protected val config: RenderConfig) {
    
    abstract val isInitialized: StateFlow<Boolean>
    abstract val currentFPS: StateFlow<Int>
    
    /**
     * Initialize the renderer with a surface
     */
    abstract suspend fun initialize(surface: Surface, width: Int, height: Int)
    
    /**
     * Begin a new frame
     */
    abstract fun beginFrame()
    
    /**
     * End the current frame and present
     */
    abstract fun endFrame()
    
    /**
     * Clear the screen with the specified color
     */
    abstract fun clear(r: Float, g: Float, b: Float, a: Float = 1.0f)
    
    /**
     * Set the viewport dimensions
     */
    abstract fun setViewport(x: Int, y: Int, width: Int, height: Int)
    
    /**
     * Create a new sprite batch
     */
    abstract fun createSpriteBatch(maxSprites: Int = 1000): SpriteBatch
    
    /**
     * Create a new shader program
     */
    abstract fun createShaderProgram(vertexSource: String, fragmentSource: String): ShaderProgram
    
    /**
     * Load a texture from byte array
     */
    abstract suspend fun loadTexture(data: ByteArray, width: Int, height: Int): Texture
    
    /**
     * Create a texture region from a texture
     */
    fun createTextureRegion(
        texture: Texture,
        x: Int = 0,
        y: Int = 0,
        width: Int = texture.width,
        height: Int = texture.height
    ): TextureRegion {
        return TextureRegion(texture, x, y, width, height)
    }
    
    /**
     * Set the active camera
     */
    abstract fun setCamera(camera: Camera2D)
    
    /**
     * Get the default camera
     */
    abstract fun getDefaultCamera(): Camera2D
    
    /**
     * Resize the rendering surface
     */
    abstract fun resize(width: Int, height: Int)
    
    /**
     * Cleanup resources
     */
    abstract fun dispose()
    
    /**
     * Get renderer statistics
     */
    abstract fun getStats(): RenderStats
}

/**
 * Data class for rendering statistics
 */
data class RenderStats(
    val drawCalls: Int,
    val verticesRendered: Int,
    val textureBinds: Int,
    val shaderSwitches: Int,
    val frameTimeMs: Float
)