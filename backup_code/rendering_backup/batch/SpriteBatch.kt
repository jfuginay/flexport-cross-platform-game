package com.flexport.rendering.batch

import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.shader.ShaderProgram
import com.flexport.rendering.texture.Texture
import com.flexport.rendering.texture.TextureRegion

/**
 * Abstract base class for sprite batching
 */
abstract class SpriteBatch(val maxSprites: Int) {
    
    protected var drawing = false
    protected var currentTexture: Texture? = null
    protected var vertexIndex = 0
    protected var spriteCount = 0
    
    val projectionMatrix = com.flexport.rendering.math.Matrix4()
    
    abstract var shader: ShaderProgram?
    abstract var blendingEnabled: Boolean
    
    /**
     * Begin a new batch
     */
    open fun begin() {
        if (drawing) throw IllegalStateException("SpriteBatch.end must be called before begin")
        drawing = true
        shader?.use()
    }
    
    /**
     * End the current batch and flush
     */
    open fun end() {
        if (!drawing) throw IllegalStateException("SpriteBatch.begin must be called before end")
        flush()
        drawing = false
    }
    
    /**
     * Set the projection matrix (usually from camera)
     */
    fun setProjectionMatrix(matrix: com.flexport.rendering.math.Matrix4) {
        if (drawing) flush()
        projectionMatrix.set(matrix)
        if (drawing) setupMatrices()
    }
    
    /**
     * Set the camera to use for projection
     */
    fun setCamera(camera: Camera2D) {
        setProjectionMatrix(camera.combined)
    }
    
    /**
     * Draw a texture at the specified position
     */
    abstract fun draw(
        texture: Texture,
        x: Float,
        y: Float,
        width: Float = texture.width.toFloat(),
        height: Float = texture.height.toFloat()
    )
    
    /**
     * Draw a texture with rotation and scaling
     */
    abstract fun draw(
        texture: Texture,
        x: Float,
        y: Float,
        originX: Float,
        originY: Float,
        width: Float,
        height: Float,
        scaleX: Float,
        scaleY: Float,
        rotation: Float,
        flipX: Boolean = false,
        flipY: Boolean = false
    )
    
    /**
     * Draw a texture region
     */
    abstract fun draw(
        region: TextureRegion,
        x: Float,
        y: Float,
        width: Float = region.regionWidth.toFloat(),
        height: Float = region.regionHeight.toFloat()
    )
    
    /**
     * Draw a texture region with rotation and scaling
     */
    abstract fun draw(
        region: TextureRegion,
        x: Float,
        y: Float,
        originX: Float,
        originY: Float,
        width: Float,
        height: Float,
        scaleX: Float,
        scaleY: Float,
        rotation: Float
    )
    
    /**
     * Draw with tinting color
     */
    abstract fun setColor(r: Float, g: Float, b: Float, a: Float)
    
    /**
     * Get the current tint color
     */
    abstract fun getColor(): FloatArray
    
    /**
     * Flush the current batch
     */
    protected abstract fun flush()
    
    /**
     * Setup matrices for shader
     */
    protected abstract fun setupMatrices()
    
    /**
     * Dispose resources
     */
    abstract fun dispose()
    
    /**
     * Get current sprite count in batch
     */
    fun getSpriteCount(): Int = spriteCount
    
    /**
     * Check if currently drawing
     */
    fun isDrawing(): Boolean = drawing
}