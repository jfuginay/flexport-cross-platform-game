package com.flexport.rendering.texture

/**
 * Represents a region of a texture (for texture atlases)
 */
class TextureRegion(
    val texture: Texture,
    x: Int = 0,
    y: Int = 0,
    width: Int = texture.width,
    height: Int = texture.height
) {
    var regionX = x
        private set
    var regionY = y
        private set
    var regionWidth = width
        private set
    var regionHeight = height
        private set
    
    // UV coordinates (normalized)
    var u: Float = 0f
        private set
    var v: Float = 0f
        private set
    var u2: Float = 0f
        private set
    var v2: Float = 0f
        private set
    
    init {
        setRegion(x, y, width, height)
    }
    
    /**
     * Set the region of the texture
     */
    fun setRegion(x: Int, y: Int, width: Int, height: Int) {
        regionX = x
        regionY = y
        regionWidth = width
        regionHeight = height
        
        // Calculate UV coordinates
        u = x.toFloat() / texture.width.toFloat()
        v = y.toFloat() / texture.height.toFloat()
        u2 = (x + width).toFloat() / texture.width.toFloat()
        v2 = (y + height).toFloat() / texture.height.toFloat()
    }
    
    /**
     * Create a new texture region with the same texture but different bounds
     */
    fun split(x: Int, y: Int, width: Int, height: Int): TextureRegion {
        return TextureRegion(
            texture,
            regionX + x,
            regionY + y,
            width,
            height
        )
    }
    
    /**
     * Split this region into a grid of regions
     */
    fun split(tileWidth: Int, tileHeight: Int): Array<Array<TextureRegion>> {
        val rows = regionHeight / tileHeight
        val cols = regionWidth / tileWidth
        
        return Array(rows) { row ->
            Array(cols) { col ->
                split(
                    col * tileWidth,
                    row * tileHeight,
                    tileWidth,
                    tileHeight
                )
            }
        }
    }
    
    /**
     * Flip the region horizontally
     */
    fun flip(x: Boolean, y: Boolean) {
        if (x) {
            val temp = u
            u = u2
            u2 = temp
        }
        if (y) {
            val temp = v
            v = v2
            v2 = temp
        }
    }
}