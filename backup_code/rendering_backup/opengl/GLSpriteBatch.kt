package com.flexport.rendering.opengl

import android.opengl.GLES30
import com.flexport.rendering.batch.SpriteBatch
import com.flexport.rendering.shader.ShaderProgram
import com.flexport.rendering.texture.Texture
import com.flexport.rendering.texture.TextureRegion
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * OpenGL ES implementation of SpriteBatch
 */
class GLSpriteBatch(
    private val renderer: GLRenderer,
    maxSprites: Int = 1000
) : SpriteBatch(maxSprites) {
    
    companion object {
        const val VERTEX_SIZE = 2 + 2 + 1 // position (2) + texCoords (2) + color (1 packed)
        const val SPRITE_SIZE = 4 * VERTEX_SIZE // 4 vertices per sprite
    }
    
    private val vertices = FloatArray(maxSprites * SPRITE_SIZE)
    private val vertexBuffer: FloatBuffer
    
    private var vao = 0
    private var vbo = 0
    private var ebo = 0
    
    override var shader: ShaderProgram? = null
        set(value) {
            if (drawing) flush()
            field = value
            if (drawing) setupMatrices()
        }
    
    override var blendingEnabled = true
        set(value) {
            if (field != value) {
                flush()
                field = value
            }
        }
    
    private var color = floatArrayOf(1f, 1f, 1f, 1f)
    private var colorPacked = packColor(1f, 1f, 1f, 1f)
    
    init {
        // Allocate vertex buffer
        vertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        
        // Create VAO, VBO, and EBO
        val buffers = IntArray(3)
        GLES30.glGenVertexArrays(1, buffers, 0)
        vao = buffers[0]
        GLES30.glGenBuffers(2, buffers, 1)
        vbo = buffers[1]
        ebo = buffers[2]
        
        // Setup VAO
        GLES30.glBindVertexArray(vao)
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo)
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, vertices.size * 4, null, GLES30.GL_DYNAMIC_DRAW)
        
        // Setup vertex attributes
        // Position
        GLES30.glVertexAttribPointer(0, 2, GLES30.GL_FLOAT, false, VERTEX_SIZE * 4, 0)
        GLES30.glEnableVertexAttribArray(0)
        
        // Texture coordinates
        GLES30.glVertexAttribPointer(1, 2, GLES30.GL_FLOAT, false, VERTEX_SIZE * 4, 2 * 4)
        GLES30.glEnableVertexAttribArray(1)
        
        // Color (packed)
        GLES30.glVertexAttribPointer(2, 4, GLES30.GL_UNSIGNED_BYTE, true, VERTEX_SIZE * 4, 4 * 4)
        GLES30.glEnableVertexAttribArray(2)
        
        // Setup element buffer for indexed drawing
        GLES30.glBindBuffer(GLES30.GL_ELEMENT_ARRAY_BUFFER, ebo)
        val indices = createQuadIndices(maxSprites)
        val indexBuffer = ByteBuffer.allocateDirect(indices.size * 2)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
            .put(indices)
            .position(0)
        GLES30.glBufferData(GLES30.GL_ELEMENT_ARRAY_BUFFER, indices.size * 2, indexBuffer, GLES30.GL_STATIC_DRAW)
        
        GLES30.glBindVertexArray(0)
    }
    
    override fun begin() {
        super.begin()
        setupMatrices()
    }
    
    override fun draw(texture: Texture, x: Float, y: Float, width: Float, height: Float) {
        if (!drawing) throw IllegalStateException("SpriteBatch.begin must be called before draw")
        
        switchTexture(texture)
        
        if (vertexIndex >= vertices.size) flush()
        
        val u = 0f
        val v = 0f
        val u2 = 1f
        val v2 = 1f
        
        // Bottom left
        vertices[vertexIndex++] = x
        vertices[vertexIndex++] = y
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        // Top left
        vertices[vertexIndex++] = x
        vertices[vertexIndex++] = y + height
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Top right
        vertices[vertexIndex++] = x + width
        vertices[vertexIndex++] = y + height
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Bottom right
        vertices[vertexIndex++] = x + width
        vertices[vertexIndex++] = y
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        spriteCount++
    }
    
    override fun draw(
        texture: Texture,
        x: Float, y: Float,
        originX: Float, originY: Float,
        width: Float, height: Float,
        scaleX: Float, scaleY: Float,
        rotation: Float,
        flipX: Boolean, flipY: Boolean
    ) {
        if (!drawing) throw IllegalStateException("SpriteBatch.begin must be called before draw")
        
        switchTexture(texture)
        
        if (vertexIndex >= vertices.size) flush()
        
        // Calculate corner points
        val worldOriginX = x + originX
        val worldOriginY = y + originY
        var fx = -originX
        var fy = -originY
        var fx2 = width - originX
        var fy2 = height - originY
        
        // Scale
        if (scaleX != 1f || scaleY != 1f) {
            fx *= scaleX
            fy *= scaleY
            fx2 *= scaleX
            fy2 *= scaleY
        }
        
        // Construct corner points
        val p1x = fx
        val p1y = fy
        val p2x = fx
        val p2y = fy2
        val p3x = fx2
        val p3y = fy2
        val p4x = fx2
        val p4y = fy
        
        var x1: Float
        var y1: Float
        var x2: Float
        var y2: Float
        var x3: Float
        var y3: Float
        var x4: Float
        var y4: Float
        
        // Rotate
        if (rotation != 0f) {
            val cos = cos(rotation * Math.PI.toFloat() / 180f)
            val sin = sin(rotation * Math.PI.toFloat() / 180f)
            
            x1 = cos * p1x - sin * p1y
            y1 = sin * p1x + cos * p1y
            
            x2 = cos * p2x - sin * p2y
            y2 = sin * p2x + cos * p2y
            
            x3 = cos * p3x - sin * p3y
            y3 = sin * p3x + cos * p3y
            
            x4 = cos * p4x - sin * p4y
            y4 = sin * p4x + cos * p4y
        } else {
            x1 = p1x
            y1 = p1y
            x2 = p2x
            y2 = p2y
            x3 = p3x
            y3 = p3y
            x4 = p4x
            y4 = p4y
        }
        
        x1 += worldOriginX
        y1 += worldOriginY
        x2 += worldOriginX
        y2 += worldOriginY
        x3 += worldOriginX
        y3 += worldOriginY
        x4 += worldOriginX
        y4 += worldOriginY
        
        var u = 0f
        var v = 0f
        var u2 = 1f
        var v2 = 1f
        
        if (flipX) {
            val tmp = u
            u = u2
            u2 = tmp
        }
        
        if (flipY) {
            val tmp = v
            v = v2
            v2 = tmp
        }
        
        // Bottom left
        vertices[vertexIndex++] = x1
        vertices[vertexIndex++] = y1
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        // Top left
        vertices[vertexIndex++] = x2
        vertices[vertexIndex++] = y2
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Top right
        vertices[vertexIndex++] = x3
        vertices[vertexIndex++] = y3
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Bottom right
        vertices[vertexIndex++] = x4
        vertices[vertexIndex++] = y4
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        spriteCount++
    }
    
    override fun draw(region: TextureRegion, x: Float, y: Float, width: Float, height: Float) {
        if (!drawing) throw IllegalStateException("SpriteBatch.begin must be called before draw")
        
        switchTexture(region.texture)
        
        if (vertexIndex >= vertices.size) flush()
        
        val u = region.u
        val v = region.v
        val u2 = region.u2
        val v2 = region.v2
        
        // Bottom left
        vertices[vertexIndex++] = x
        vertices[vertexIndex++] = y
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        // Top left
        vertices[vertexIndex++] = x
        vertices[vertexIndex++] = y + height
        vertices[vertexIndex++] = u
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Top right
        vertices[vertexIndex++] = x + width
        vertices[vertexIndex++] = y + height
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v
        vertices[vertexIndex++] = colorPacked
        
        // Bottom right
        vertices[vertexIndex++] = x + width
        vertices[vertexIndex++] = y
        vertices[vertexIndex++] = u2
        vertices[vertexIndex++] = v2
        vertices[vertexIndex++] = colorPacked
        
        spriteCount++
    }
    
    override fun draw(
        region: TextureRegion,
        x: Float, y: Float,
        originX: Float, originY: Float,
        width: Float, height: Float,
        scaleX: Float, scaleY: Float,
        rotation: Float
    ) {
        // Reuse the texture draw method with region's UV coordinates
        draw(region.texture, x, y, originX, originY, width, height, scaleX, scaleY, rotation, false, false)
    }
    
    override fun setColor(r: Float, g: Float, b: Float, a: Float) {
        color[0] = r
        color[1] = g
        color[2] = b
        color[3] = a
        colorPacked = packColor(r, g, b, a)
    }
    
    override fun getColor(): FloatArray = color.copyOf()
    
    override fun flush() {
        if (spriteCount == 0) return
        
        // Upload vertex data
        vertexBuffer.clear()
        vertexBuffer.put(vertices, 0, vertexIndex)
        vertexBuffer.position(0)
        
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo)
        GLES30.glBufferSubData(GLES30.GL_ARRAY_BUFFER, 0, vertexIndex * 4, vertexBuffer)
        
        // Bind texture
        currentTexture?.let { texture ->
            if (texture is GLTexture) {
                GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
                GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, texture.textureId)
                renderer.incrementTextureBinds()
            }
        }
        
        // Enable/disable blending
        if (blendingEnabled) {
            GLES30.glEnable(GLES30.GL_BLEND)
            GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        } else {
            GLES30.glDisable(GLES30.GL_BLEND)
        }
        
        // Draw
        GLES30.glBindVertexArray(vao)
        GLES30.glDrawElements(GLES30.GL_TRIANGLES, spriteCount * 6, GLES30.GL_UNSIGNED_SHORT, 0)
        GLES30.glBindVertexArray(0)
        
        // Update statistics
        renderer.incrementDrawCalls()
        renderer.addVerticesRendered(spriteCount * 4)
        
        // Reset
        vertexIndex = 0
        spriteCount = 0
    }
    
    override fun setupMatrices() {
        shader?.let { program ->
            if (program is GLShaderProgram) {
                program.setUniformMatrix4("u_projTrans", projectionMatrix)
            }
        }
    }
    
    override fun dispose() {
        val buffers = intArrayOf(vbo, ebo)
        GLES30.glDeleteBuffers(2, buffers, 0)
        GLES30.glDeleteVertexArrays(1, intArrayOf(vao), 0)
    }
    
    private fun switchTexture(texture: Texture) {
        if (currentTexture != texture) {
            flush()
            currentTexture = texture
        }
    }
    
    private fun packColor(r: Float, g: Float, b: Float, a: Float): Float {
        val intBits = ((a * 255).toInt() shl 24) or
                     ((b * 255).toInt() shl 16) or
                     ((g * 255).toInt() shl 8) or
                     (r * 255).toInt()
        return Float.fromBits(intBits)
    }
    
    private fun createQuadIndices(maxSprites: Int): ShortArray {
        val indices = ShortArray(maxSprites * 6)
        var j = 0
        for (i in 0 until maxSprites) {
            val offset = (i * 4).toShort()
            indices[j++] = offset
            indices[j++] = (offset + 1).toShort()
            indices[j++] = (offset + 2).toShort()
            indices[j++] = (offset + 2).toShort()
            indices[j++] = (offset + 3).toShort()
            indices[j++] = offset
        }
        return indices
    }
}