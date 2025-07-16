package com.flexport.rendering.opengl

import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.view.Surface
import com.flexport.rendering.batch.SpriteBatch
import com.flexport.rendering.camera.Camera2D
import com.flexport.rendering.camera.OrthographicCamera
import com.flexport.rendering.core.RenderConfig
import com.flexport.rendering.core.RenderStats
import com.flexport.rendering.core.Renderer
import com.flexport.rendering.shader.ShaderProgram
import com.flexport.rendering.texture.Texture
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * OpenGL ES 3.0 renderer implementation
 */
class GLRenderer(config: RenderConfig) : Renderer(config), GLSurfaceView.Renderer {
    
    private val _isInitialized = MutableStateFlow(false)
    override val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()
    
    private val _currentFPS = MutableStateFlow(0)
    override val currentFPS: StateFlow<Int> = _currentFPS.asStateFlow()
    
    private var screenWidth = 0
    private var screenHeight = 0
    
    private lateinit var defaultCamera: OrthographicCamera
    private var activeCamera: Camera2D? = null
    
    // Performance tracking
    private var frameStartTime = 0L
    private var frameCount = 0
    private var fpsStartTime = 0L
    
    // Statistics
    private var drawCalls = 0
    private var verticesRendered = 0
    private var textureBinds = 0
    private var shaderSwitches = 0
    private var lastFrameTimeMs = 0f
    
    private val spriteBatches = mutableListOf<GLSpriteBatch>()
    private val shaderPrograms = mutableListOf<GLShaderProgram>()
    private val textures = mutableListOf<GLTexture>()
    
    override suspend fun initialize(surface: Surface, width: Int, height: Int) {
        // OpenGL ES initialization is handled by GLSurfaceView
        screenWidth = width
        screenHeight = height
    }
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        // Enable required OpenGL features
        GLES30.glEnable(GLES30.GL_BLEND)
        GLES30.glBlendFunc(GLES30.GL_SRC_ALPHA, GLES30.GL_ONE_MINUS_SRC_ALPHA)
        
        if (this.config.multisampleCount > 1) {
            GLES30.glEnable(GLES30.GL_MULTISAMPLE)
        }
        
        // Set clear color
        GLES30.glClearColor(0f, 0f, 0f, 1f)
        
        // Create default camera
        defaultCamera = OrthographicCamera(screenWidth.toFloat(), screenHeight.toFloat())
        
        _isInitialized.value = true
        fpsStartTime = System.currentTimeMillis()
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        resize(width, height)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        // Frame timing
        frameStartTime = System.nanoTime()
        
        // FPS calculation
        frameCount++
        val currentTime = System.currentTimeMillis()
        if (currentTime - fpsStartTime >= 1000) {
            _currentFPS.value = frameCount
            frameCount = 0
            fpsStartTime = currentTime
        }
    }
    
    override fun beginFrame() {
        // Reset statistics
        drawCalls = 0
        verticesRendered = 0
        textureBinds = 0
        shaderSwitches = 0
    }
    
    override fun endFrame() {
        // Calculate frame time
        val frameEndTime = System.nanoTime()
        lastFrameTimeMs = (frameEndTime - frameStartTime) / 1_000_000f
        
        // Ensure we hit target FPS if vsync is disabled
        if (!config.vsyncEnabled) {
            val targetFrameTime = 1000f / config.targetFPS
            val sleepTime = (targetFrameTime - lastFrameTimeMs).toLong()
            if (sleepTime > 0) {
                Thread.sleep(sleepTime)
            }
        }
    }
    
    override fun clear(r: Float, g: Float, b: Float, a: Float) {
        GLES30.glClearColor(r, g, b, a)
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
    }
    
    override fun setViewport(x: Int, y: Int, width: Int, height: Int) {
        GLES30.glViewport(x, y, width, height)
    }
    
    override fun createSpriteBatch(maxSprites: Int): SpriteBatch {
        val batch = GLSpriteBatch(this, maxSprites)
        spriteBatches.add(batch)
        return batch
    }
    
    override fun createShaderProgram(vertexSource: String, fragmentSource: String): ShaderProgram {
        val program = GLShaderProgram(vertexSource, fragmentSource)
        shaderPrograms.add(program)
        return program
    }
    
    override suspend fun loadTexture(data: ByteArray, width: Int, height: Int): Texture {
        val texture = GLTexture(data, width, height)
        textures.add(texture)
        return texture
    }
    
    override fun setCamera(camera: Camera2D) {
        activeCamera = camera
    }
    
    override fun getDefaultCamera(): Camera2D = defaultCamera
    
    override fun resize(width: Int, height: Int) {
        screenWidth = width
        screenHeight = height
        GLES30.glViewport(0, 0, width, height)
        defaultCamera.setViewportSize(width.toFloat(), height.toFloat())
        defaultCamera.update()
    }
    
    override fun dispose() {
        spriteBatches.forEach { it.dispose() }
        shaderPrograms.forEach { it.dispose() }
        textures.forEach { it.dispose() }
        
        spriteBatches.clear()
        shaderPrograms.clear()
        textures.clear()
    }
    
    override fun getStats(): RenderStats {
        return RenderStats(
            drawCalls = drawCalls,
            verticesRendered = verticesRendered,
            textureBinds = textureBinds,
            shaderSwitches = shaderSwitches,
            frameTimeMs = lastFrameTimeMs
        )
    }
    
    fun getCurrentCamera(): Camera2D = activeCamera ?: defaultCamera
    
    fun incrementDrawCalls() { drawCalls++ }
    fun addVerticesRendered(count: Int) { verticesRendered += count }
    fun incrementTextureBinds() { textureBinds++ }
    fun incrementShaderSwitches() { shaderSwitches++ }
}