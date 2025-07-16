package com.flexport.rendering.texture

import kotlinx.serialization.Serializable

/**
 * Texture atlas for efficient sprite rendering
 */
class TextureAtlas(
    val texture: Texture,
    private val atlasData: AtlasData
) {
    
    private val regions = mutableMapOf<String, TextureRegion>()
    
    init {
        createRegions()
    }
    
    private fun createRegions() {
        for (sprite in atlasData.sprites) {
            val region = TextureRegion(
                texture,
                sprite.x,
                sprite.y,
                sprite.width,
                sprite.height
            )
            regions[sprite.name] = region
        }
    }
    
    /**
     * Get a texture region by name
     */
    fun getRegion(name: String): TextureRegion? {
        return regions[name]
    }
    
    /**
     * Get all region names
     */
    fun getRegionNames(): Set<String> {
        return regions.keys
    }
    
    /**
     * Check if a region exists
     */
    fun hasRegion(name: String): Boolean {
        return regions.containsKey(name)
    }
    
    /**
     * Get texture regions for animation frames
     */
    fun getAnimationFrames(namePattern: String): List<TextureRegion> {
        val frames = mutableListOf<TextureRegion>()
        val sortedNames = regions.keys.filter { it.startsWith(namePattern) }.sorted()
        
        for (name in sortedNames) {
            regions[name]?.let { frames.add(it) }
        }
        
        return frames
    }
    
    /**
     * Get texture regions by prefix
     */
    fun getRegionsByPrefix(prefix: String): Map<String, TextureRegion> {
        return regions.filterKeys { it.startsWith(prefix) }
    }
    
    /**
     * Create a new atlas from a grid layout
     */
    companion object {
        fun createFromGrid(
            texture: Texture,
            tileWidth: Int,
            tileHeight: Int,
            startX: Int = 0,
            startY: Int = 0,
            namePrefix: String = "tile"
        ): TextureAtlas {
            val sprites = mutableListOf<SpriteData>()
            
            val cols = (texture.width - startX) / tileWidth
            val rows = (texture.height - startY) / tileHeight
            
            var index = 0
            for (row in 0 until rows) {
                for (col in 0 until cols) {
                    sprites.add(
                        SpriteData(
                            name = "${namePrefix}_${index++}",
                            x = startX + col * tileWidth,
                            y = startY + row * tileHeight,
                            width = tileWidth,
                            height = tileHeight
                        )
                    )
                }
            }
            
            val atlasData = AtlasData(sprites)
            return TextureAtlas(texture, atlasData)
        }
    }
}

/**
 * Data class for atlas configuration
 */
@Serializable
data class AtlasData(
    val sprites: List<SpriteData>
)

/**
 * Data class for individual sprite in atlas
 */
@Serializable
data class SpriteData(
    val name: String,
    val x: Int,
    val y: Int,
    val width: Int,
    val height: Int
)