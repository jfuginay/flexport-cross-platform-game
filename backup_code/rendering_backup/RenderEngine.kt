package com.flexport.rendering

import android.content.Context
import com.flexport.ecs.core.EntityManager
import com.flexport.ecs.systems.RenderSystem
import com.flexport.rendering.core.RenderAPI
import com.flexport.rendering.core.RenderConfig
import com.flexport.rendering.core.Renderer
import com.flexport.rendering.opengl.GLRenderer
import com.flexport.rendering.performance.PerformanceMonitor
import com.flexport.rendering.texture.TextureManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Main rendering engine that coordinates all rendering systems
 */
class RenderEngine(
    private val context: Context,
    private val config: RenderConfig = RenderConfig()
) {
    
    private val renderScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    
    private val renderer: Renderer = when (config.api) {
        RenderAPI.OPENGL_ES -> GLRenderer(config)
        RenderAPI.VULKAN -> throw UnsupportedOperationException("Vulkan not yet implemented")
    }
    
    val textureManager = TextureManager(context, renderer)
    val performanceMonitor = PerformanceMonitor()
    
    private lateinit var renderSystem: RenderSystem
    
    var isInitialized = false
        private set
    
    /**
     * Initialize the render engine
     */
    suspend fun initialize(entityManager: EntityManager) {
        renderSystem = RenderSystem(renderer, entityManager)
        renderSystem.initialize()
        isInitialized = true
    }
    
    /**
     * Render a frame
     */
    fun renderFrame() {
        if (!isInitialized) return
        
        performanceMonitor.startFrame()
        
        renderScope.launch {
            try {
                renderSystem.render()
            } catch (e: Exception) {
                // Log error but don't crash the game
                println("Render error: ${e.message}")
            }
        }
        
        performanceMonitor.endFrame()
    }
    
    /**
     * Resize the rendering surface
     */
    fun resize(width: Int, height: Int) {
        renderer.resize(width, height)
    }
    
    /**
     * Get the underlying renderer
     */
    fun getRenderer(): Renderer = renderer
    
    /**
     * Get render statistics
     */
    fun getStats() = renderer.getStats()
    
    /**
     * Dispose of all resources
     */
    fun dispose() {
        if (isInitialized) {
            renderScope.launch {
                renderSystem.dispose()
            }
        }
        textureManager.dispose()
        renderer.dispose()
    }
    
    /**
     * Create a builder for configuring the render engine
     */
    companion object {
        fun builder(context: Context) = RenderEngineBuilder(context)
    }
}

/**
 * Builder for configuring the render engine
 */
class RenderEngineBuilder(private val context: Context) {
    private var config = RenderConfig()
    
    fun withAPI(api: RenderAPI) = apply {
        config = config.copy(api = api)
    }
    
    fun withVSync(enabled: Boolean) = apply {
        config = config.copy(vsyncEnabled = enabled)
    }
    
    fun withMultisampling(sampleCount: Int) = apply {
        config = config.copy(multisampleCount = sampleCount)
    }
    
    fun withTargetFPS(fps: Int) = apply {
        config = config.copy(targetFPS = fps)
    }
    
    fun withDebugLayer(enabled: Boolean) = apply {
        config = config.copy(enableDebugLayer = enabled)
    }
    
    fun build() = RenderEngine(context, config)
}