export interface PerformanceMetrics {
  fps: number;
  frameTime: number;
  updateTime: number;
  renderTime: number;
  networkLatency: number;
  memoryUsage: number;
  drawCalls: number;
  spriteCount: number;
  particleCount: number;
}

export interface PerformanceConfig {
  targetFPS: number;
  lowFPSThreshold: number;
  highLatencyThreshold: number;
  autoQualityEnabled: boolean;
  qualityLevel: 'low' | 'medium' | 'high' | 'ultra';
}

export class PerformanceMonitor {
  private metrics: PerformanceMetrics;
  private config: PerformanceConfig;
  private frameCount = 0;
  private lastFrameTime = 0;
  private frameTimeSum = 0;
  private updateTimeSum = 0;
  private renderTimeSum = 0;
  private metricsHistory: PerformanceMetrics[] = [];
  private maxHistorySize = 60; // 1 second at 60 FPS
  private callbacks: Set<(metrics: PerformanceMetrics) => void> = new Set();
  private performanceNow = performance.now.bind(performance);

  constructor(config?: Partial<PerformanceConfig>) {
    this.config = {
      targetFPS: 60,
      lowFPSThreshold: 30,
      highLatencyThreshold: 100,
      autoQualityEnabled: true,
      qualityLevel: 'high',
      ...config
    };

    this.metrics = {
      fps: 0,
      frameTime: 0,
      updateTime: 0,
      renderTime: 0,
      networkLatency: 0,
      memoryUsage: 0,
      drawCalls: 0,
      spriteCount: 0,
      particleCount: 0
    };

    // Start monitoring memory if available
    this.startMemoryMonitoring();
  }

  private startMemoryMonitoring(): void {
    if ('memory' in performance) {
      setInterval(() => {
        const memory = (performance as any).memory;
        this.metrics.memoryUsage = memory.usedJSHeapSize / (1024 * 1024); // Convert to MB
      }, 1000);
    }
  }

  public beginFrame(): void {
    this.lastFrameTime = this.performanceNow();
  }

  public endFrame(): void {
    const currentTime = this.performanceNow();
    const frameTime = currentTime - this.lastFrameTime;
    
    this.frameTimeSum += frameTime;
    this.frameCount++;

    // Update metrics every second
    if (this.frameCount >= this.config.targetFPS) {
      this.updateMetrics();
    }

    // Add to history
    this.metricsHistory.push({ ...this.metrics });
    if (this.metricsHistory.length > this.maxHistorySize) {
      this.metricsHistory.shift();
    }
  }

  private updateMetrics(): void {
    const avgFrameTime = this.frameTimeSum / this.frameCount;
    this.metrics.fps = Math.round(1000 / avgFrameTime);
    this.metrics.frameTime = avgFrameTime;
    this.metrics.updateTime = this.updateTimeSum / this.frameCount;
    this.metrics.renderTime = this.renderTimeSum / this.frameCount;

    // Reset counters
    this.frameCount = 0;
    this.frameTimeSum = 0;
    this.updateTimeSum = 0;
    this.renderTimeSum = 0;

    // Notify listeners
    this.callbacks.forEach(callback => callback(this.metrics));

    // Auto-adjust quality if enabled
    if (this.config.autoQualityEnabled) {
      this.autoAdjustQuality();
    }
  }

  private autoAdjustQuality(): void {
    const avgFPS = this.getAverageFPS();
    
    if (avgFPS < this.config.lowFPSThreshold) {
      // Downgrade quality
      switch (this.config.qualityLevel) {
        case 'ultra':
          this.setQualityLevel('high');
          break;
        case 'high':
          this.setQualityLevel('medium');
          break;
        case 'medium':
          this.setQualityLevel('low');
          break;
      }
    } else if (avgFPS > this.config.targetFPS - 5) {
      // Upgrade quality if performance is good
      switch (this.config.qualityLevel) {
        case 'low':
          this.setQualityLevel('medium');
          break;
        case 'medium':
          this.setQualityLevel('high');
          break;
        case 'high':
          this.setQualityLevel('ultra');
          break;
      }
    }
  }

  public measureUpdate<T>(fn: () => T): T {
    const start = this.performanceNow();
    const result = fn();
    this.updateTimeSum += this.performanceNow() - start;
    return result;
  }

  public measureRender<T>(fn: () => T): T {
    const start = this.performanceNow();
    const result = fn();
    this.renderTimeSum += this.performanceNow() - start;
    return result;
  }

  public setNetworkLatency(latency: number): void {
    this.metrics.networkLatency = latency;
  }

  public setDrawCalls(count: number): void {
    this.metrics.drawCalls = count;
  }

  public setSpriteCount(count: number): void {
    this.metrics.spriteCount = count;
  }

  public setParticleCount(count: number): void {
    this.metrics.particleCount = count;
  }

  public getMetrics(): PerformanceMetrics {
    return { ...this.metrics };
  }

  public getAverageFPS(): number {
    if (this.metricsHistory.length === 0) return this.config.targetFPS;
    
    const sum = this.metricsHistory.reduce((acc, m) => acc + m.fps, 0);
    return sum / this.metricsHistory.length;
  }

  public getAverageFrameTime(): number {
    if (this.metricsHistory.length === 0) return 16.67; // 60 FPS
    
    const sum = this.metricsHistory.reduce((acc, m) => acc + m.frameTime, 0);
    return sum / this.metricsHistory.length;
  }

  public isLowPerformance(): boolean {
    return this.getAverageFPS() < this.config.lowFPSThreshold;
  }

  public isHighLatency(): boolean {
    return this.metrics.networkLatency > this.config.highLatencyThreshold;
  }

  public getQualityLevel(): string {
    return this.config.qualityLevel;
  }

  public setQualityLevel(level: 'low' | 'medium' | 'high' | 'ultra'): void {
    this.config.qualityLevel = level;
    console.log(`Performance: Quality level changed to ${level}`);
  }

  public onMetricsUpdate(callback: (metrics: PerformanceMetrics) => void): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }

  public getQualitySettings(): {
    particlesEnabled: boolean;
    particleCount: number;
    shadowsEnabled: boolean;
    antialiasingEnabled: boolean;
    textureQuality: 'low' | 'medium' | 'high';
    effectsQuality: 'low' | 'medium' | 'high';
    maxVisibleShips: number;
    renderDistance: number;
  } {
    switch (this.config.qualityLevel) {
      case 'low':
        return {
          particlesEnabled: false,
          particleCount: 0,
          shadowsEnabled: false,
          antialiasingEnabled: false,
          textureQuality: 'low',
          effectsQuality: 'low',
          maxVisibleShips: 20,
          renderDistance: 500
        };
      case 'medium':
        return {
          particlesEnabled: true,
          particleCount: 50,
          shadowsEnabled: false,
          antialiasingEnabled: true,
          textureQuality: 'medium',
          effectsQuality: 'medium',
          maxVisibleShips: 50,
          renderDistance: 1000
        };
      case 'high':
        return {
          particlesEnabled: true,
          particleCount: 100,
          shadowsEnabled: true,
          antialiasingEnabled: true,
          textureQuality: 'high',
          effectsQuality: 'high',
          maxVisibleShips: 100,
          renderDistance: 2000
        };
      case 'ultra':
        return {
          particlesEnabled: true,
          particleCount: 200,
          shadowsEnabled: true,
          antialiasingEnabled: true,
          textureQuality: 'high',
          effectsQuality: 'high',
          maxVisibleShips: 200,
          renderDistance: 5000
        };
    }
  }

  public reset(): void {
    this.frameCount = 0;
    this.frameTimeSum = 0;
    this.updateTimeSum = 0;
    this.renderTimeSum = 0;
    this.metricsHistory = [];
  }
}

// Singleton instance
let performanceMonitor: PerformanceMonitor | null = null;

export function getPerformanceMonitor(): PerformanceMonitor {
  if (!performanceMonitor) {
    performanceMonitor = new PerformanceMonitor();
  }
  return performanceMonitor;
}

// Object pooling for performance
export class ObjectPool<T> {
  private pool: T[] = [];
  private createFn: () => T;
  private resetFn: (obj: T) => void;
  private maxSize: number;

  constructor(
    createFn: () => T,
    resetFn: (obj: T) => void,
    initialSize = 10,
    maxSize = 100
  ) {
    this.createFn = createFn;
    this.resetFn = resetFn;
    this.maxSize = maxSize;

    // Pre-populate pool
    for (let i = 0; i < initialSize; i++) {
      this.pool.push(createFn());
    }
  }

  public get(): T {
    if (this.pool.length > 0) {
      return this.pool.pop()!;
    }
    return this.createFn();
  }

  public release(obj: T): void {
    if (this.pool.length < this.maxSize) {
      this.resetFn(obj);
      this.pool.push(obj);
    }
  }

  public clear(): void {
    this.pool = [];
  }

  public getSize(): number {
    return this.pool.length;
  }
}

// Throttle function for performance
export function throttle<T extends (...args: any[]) => any>(
  fn: T,
  delay: number
): T {
  let lastCall = 0;
  let timeout: ReturnType<typeof setTimeout> | null = null;

  return ((...args: Parameters<T>) => {
    const now = Date.now();
    const timeSinceLastCall = now - lastCall;

    if (timeSinceLastCall >= delay) {
      lastCall = now;
      return fn(...args);
    } else if (!timeout) {
      timeout = setTimeout(() => {
        lastCall = Date.now();
        timeout = null;
        fn(...args);
      }, delay - timeSinceLastCall);
    }
  }) as T;
}

// Spatial indexing for efficient collision detection
export class SpatialIndex<T extends { x: number; y: number }> {
  private cellSize: number;
  private cells: Map<string, Set<T>> = new Map();

  constructor(cellSize = 100) {
    this.cellSize = cellSize;
  }

  private getCellKey(x: number, y: number): string {
    const cellX = Math.floor(x / this.cellSize);
    const cellY = Math.floor(y / this.cellSize);
    return `${cellX},${cellY}`;
  }

  public add(item: T): void {
    const key = this.getCellKey(item.x, item.y);
    if (!this.cells.has(key)) {
      this.cells.set(key, new Set());
    }
    this.cells.get(key)!.add(item);
  }

  public remove(item: T): void {
    const key = this.getCellKey(item.x, item.y);
    const cell = this.cells.get(key);
    if (cell) {
      cell.delete(item);
      if (cell.size === 0) {
        this.cells.delete(key);
      }
    }
  }

  public update(item: T, oldX: number, oldY: number): void {
    const oldKey = this.getCellKey(oldX, oldY);
    const newKey = this.getCellKey(item.x, item.y);
    
    if (oldKey !== newKey) {
      const oldCell = this.cells.get(oldKey);
      if (oldCell) {
        oldCell.delete(item);
        if (oldCell.size === 0) {
          this.cells.delete(oldKey);
        }
      }
      this.add(item);
    }
  }

  public getNearby(x: number, y: number, radius: number): T[] {
    const results: T[] = [];
    const cellRadius = Math.ceil(radius / this.cellSize);
    const centerCellX = Math.floor(x / this.cellSize);
    const centerCellY = Math.floor(y / this.cellSize);

    for (let dx = -cellRadius; dx <= cellRadius; dx++) {
      for (let dy = -cellRadius; dy <= cellRadius; dy++) {
        const key = `${centerCellX + dx},${centerCellY + dy}`;
        const cell = this.cells.get(key);
        if (cell) {
          cell.forEach(item => {
            const distance = Math.sqrt(
              Math.pow(item.x - x, 2) + Math.pow(item.y - y, 2)
            );
            if (distance <= radius) {
              results.push(item);
            }
          });
        }
      }
    }

    return results;
  }

  public clear(): void {
    this.cells.clear();
  }
}