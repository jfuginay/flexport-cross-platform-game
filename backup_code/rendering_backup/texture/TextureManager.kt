package com.flexport.rendering.texture

import android.content.Context
import android.graphics.BitmapFactory
import com.flexport.rendering.core.Renderer
import com.flexport.rendering.opengl.GLTexture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.InputStream

/**
 * Manager for loading and caching textures and atlases
 */
class TextureManager(
    private val context: Context,
    private val renderer: Renderer
) {
    
    private val textures = mutableMapOf<String, Texture>()
    private val atlases = mutableMapOf<String, TextureAtlas>()
    
    /**
     * Load a texture from assets
     */
    suspend fun loadTexture(assetPath: String): Texture = withContext(Dispatchers.IO) {
        // Check cache first
        textures[assetPath]?.let { return@withContext it }
        
        // Load from assets
        val inputStream = context.assets.open(assetPath)
        val bitmap = BitmapFactory.decodeStream(inputStream)
        inputStream.close()
        
        val texture = withContext(Dispatchers.Main) {
            GLTexture(bitmap)
        }
        
        bitmap.recycle()
        
        // Cache and return
        textures[assetPath] = texture
        texture
    }
    
    /**
     * Load a texture atlas from assets
     */
    suspend fun loadTextureAtlas(
        textureAssetPath: String,
        atlasDataAssetPath: String
    ): TextureAtlas = withContext(Dispatchers.IO) {
        // Check cache first
        atlases[atlasDataAssetPath]?.let { return@withContext it }
        
        // Load texture
        val texture = loadTexture(textureAssetPath)
        
        // Load atlas data
        val atlasDataStream = context.assets.open(atlasDataAssetPath)
        val atlasDataJson = atlasDataStream.bufferedReader().use { it.readText() }
        atlasDataStream.close()
        
        val atlasData = Json.decodeFromString<AtlasData>(atlasDataJson)
        val atlas = TextureAtlas(texture, atlasData)
        
        // Cache and return
        atlases[atlasDataAssetPath] = atlas
        atlas
    }
    
    /**
     * Create a texture atlas from a grid
     */
    suspend fun createGridAtlas(
        textureAssetPath: String,
        tileWidth: Int,
        tileHeight: Int,
        startX: Int = 0,
        startY: Int = 0,
        namePrefix: String = "tile"
    ): TextureAtlas = withContext(Dispatchers.IO) {
        val cacheKey = "${textureAssetPath}_grid_${tileWidth}x${tileHeight}_${startX}_${startY}"
        
        // Check cache first
        atlases[cacheKey]?.let { return@withContext it }
        
        // Load texture
        val texture = loadTexture(textureAssetPath)
        
        // Create grid atlas
        val atlas = TextureAtlas.createFromGrid(
            texture, tileWidth, tileHeight, startX, startY, namePrefix
        )
        
        // Cache and return
        atlases[cacheKey] = atlas
        atlas
    }
    
    /**
     * Get a cached texture
     */
    fun getTexture(assetPath: String): Texture? {
        return textures[assetPath]
    }
    
    /**
     * Get a cached atlas
     */
    fun getAtlas(atlasPath: String): TextureAtlas? {
        return atlases[atlasPath]
    }
    
    /**
     * Preload a list of textures
     */
    suspend fun preloadTextures(assetPaths: List<String>) {
        for (path in assetPaths) {
            loadTexture(path)
        }
    }
    
    /**
     * Clear all cached textures and atlases
     */
    fun clearCache() {
        textures.values.forEach { it.dispose() }
        textures.clear()
        atlases.clear()
    }
    
    /**
     * Dispose of all resources
     */
    fun dispose() {
        clearCache()
    }
    
    /**
     * Get memory usage info
     */
    fun getMemoryInfo(): TextureMemoryInfo {
        var totalTextures = textures.size
        var totalAtlases = atlases.size
        var estimatedMemoryMB = 0f
        
        textures.values.forEach { texture ->
            // Rough estimate: width * height * 4 bytes (RGBA)
            estimatedMemoryMB += (texture.width * texture.height * 4) / (1024f * 1024f)
        }
        
        return TextureMemoryInfo(
            totalTextures = totalTextures,
            totalAtlases = totalAtlases,
            estimatedMemoryMB = estimatedMemoryMB
        )
    }
}

/**
 * Data class for texture memory information
 */
data class TextureMemoryInfo(
    val totalTextures: Int,
    val totalAtlases: Int,
    val estimatedMemoryMB: Float
)