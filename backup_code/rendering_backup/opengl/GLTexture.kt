package com.flexport.rendering.opengl

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES30
import android.opengl.GLUtils
import com.flexport.rendering.texture.Texture
import com.flexport.rendering.texture.TextureFilter
import com.flexport.rendering.texture.TextureWrap

/**
 * OpenGL ES texture implementation
 */
class GLTexture : Texture {
    
    var textureId: Int = 0
        private set
    
    override var width: Int = 0
        private set
    
    override var height: Int = 0
        private set
    
    override var hasAlpha: Boolean = false
        private set
    
    constructor(bitmap: Bitmap) {
        width = bitmap.width
        height = bitmap.height
        hasAlpha = bitmap.hasAlpha()
        
        // Generate texture
        val textureIds = IntArray(1)
        GLES30.glGenTextures(1, textureIds, 0)
        textureId = textureIds[0]
        
        // Bind and upload
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
        
        // Set default parameters
        setFilter(TextureFilter.LINEAR, TextureFilter.LINEAR)
        setWrap(TextureWrap.CLAMP_TO_EDGE, TextureWrap.CLAMP_TO_EDGE)
        
        // Generate mipmaps
        GLES30.glGenerateMipmap(GLES30.GL_TEXTURE_2D)
        
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
    }
    
    constructor(data: ByteArray, width: Int, height: Int) {
        this.width = width
        this.height = height
        
        // Decode bitmap from data
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)
            ?: throw IllegalArgumentException("Failed to decode texture data")
        
        hasAlpha = bitmap.hasAlpha()
        
        // Generate texture
        val textureIds = IntArray(1)
        GLES30.glGenTextures(1, textureIds, 0)
        textureId = textureIds[0]
        
        // Bind and upload
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
        GLUtils.texImage2D(GLES30.GL_TEXTURE_2D, 0, bitmap, 0)
        
        // Set default parameters
        setFilter(TextureFilter.LINEAR, TextureFilter.LINEAR)
        setWrap(TextureWrap.CLAMP_TO_EDGE, TextureWrap.CLAMP_TO_EDGE)
        
        // Generate mipmaps
        GLES30.glGenerateMipmap(GLES30.GL_TEXTURE_2D)
        
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
        
        // Clean up bitmap
        bitmap.recycle()
    }
    
    override fun bind(unit: Int) {
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0 + unit)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textureId)
    }
    
    override fun setFilter(minFilter: TextureFilter, magFilter: TextureFilter) {
        bind()
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, getGLFilter(minFilter))
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, getGLFilter(magFilter))
    }
    
    override fun setWrap(wrapS: TextureWrap, wrapT: TextureWrap) {
        bind()
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, getGLWrap(wrapS))
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, getGLWrap(wrapT))
    }
    
    override fun dispose() {
        GLES30.glDeleteTextures(1, intArrayOf(textureId), 0)
        textureId = 0
    }
    
    private fun getGLFilter(filter: TextureFilter): Int {
        return when (filter) {
            TextureFilter.NEAREST -> GLES30.GL_NEAREST
            TextureFilter.LINEAR -> GLES30.GL_LINEAR
            TextureFilter.NEAREST_MIPMAP_NEAREST -> GLES30.GL_NEAREST_MIPMAP_NEAREST
            TextureFilter.LINEAR_MIPMAP_NEAREST -> GLES30.GL_LINEAR_MIPMAP_NEAREST
            TextureFilter.NEAREST_MIPMAP_LINEAR -> GLES30.GL_NEAREST_MIPMAP_LINEAR
            TextureFilter.LINEAR_MIPMAP_LINEAR -> GLES30.GL_LINEAR_MIPMAP_LINEAR
        }
    }
    
    private fun getGLWrap(wrap: TextureWrap): Int {
        return when (wrap) {
            TextureWrap.CLAMP_TO_EDGE -> GLES30.GL_CLAMP_TO_EDGE
            TextureWrap.REPEAT -> GLES30.GL_REPEAT
            TextureWrap.MIRRORED_REPEAT -> GLES30.GL_MIRRORED_REPEAT
        }
    }
}