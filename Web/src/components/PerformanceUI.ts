import { getPerformanceMonitor, PerformanceMetrics } from '@/utils/Performance';

export class PerformanceUI {
  private container: HTMLDivElement;
  private metricsElement: HTMLDivElement;
  private graphCanvas: HTMLCanvasElement;
  private graphContext: CanvasRenderingContext2D;
  private performanceMonitor = getPerformanceMonitor();
  private isVisible = false;
  private fpsHistory: number[] = [];
  private latencyHistory: number[] = [];
  private maxHistoryLength = 60;
  private updateInterval: ReturnType<typeof setInterval> | null = null;

  constructor() {
    this.container = this.createContainer();
    this.metricsElement = this.createMetricsElement();
    this.graphCanvas = this.createGraphCanvas();
    this.graphContext = this.graphCanvas.getContext('2d')!;
    
    this.container.appendChild(this.metricsElement);
    this.container.appendChild(this.graphCanvas);
    document.body.appendChild(this.container);
    
    this.setupEventListeners();
    this.startMonitoring();
  }

  private createContainer(): HTMLDivElement {
    const container = document.createElement('div');
    container.id = 'performance-ui';
    container.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      width: 250px;
      background: rgba(15, 23, 42, 0.95);
      border: 1px solid rgba(59, 130, 246, 0.5);
      border-radius: 8px;
      padding: 10px;
      font-family: monospace;
      font-size: 12px;
      color: #e2e8f0;
      z-index: 10000;
      display: none;
      backdrop-filter: blur(10px);
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
    `;
    return container;
  }

  private createMetricsElement(): HTMLDivElement {
    const element = document.createElement('div');
    element.style.cssText = `
      margin-bottom: 10px;
      line-height: 1.4;
    `;
    return element;
  }

  private createGraphCanvas(): HTMLCanvasElement {
    const canvas = document.createElement('canvas');
    canvas.width = 230;
    canvas.height = 80;
    canvas.style.cssText = `
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 4px;
      width: 100%;
      height: 80px;
    `;
    return canvas;
  }

  private setupEventListeners(): void {
    // Toggle with F3 key
    document.addEventListener('keydown', (event) => {
      if (event.key === 'F3') {
        event.preventDefault();
        this.toggle();
      }
    });

    // Listen for metrics updates
    this.performanceMonitor.onMetricsUpdate((metrics) => {
      if (this.isVisible) {
        this.updateDisplay(metrics);
      }
      this.updateHistory(metrics);
    });
  }

  private startMonitoring(): void {
    // Update display at 10 FPS
    this.updateInterval = setInterval(() => {
      if (this.isVisible) {
        this.drawGraph();
      }
    }, 100);
  }

  public toggle(): void {
    this.isVisible = !this.isVisible;
    this.container.style.display = this.isVisible ? 'block' : 'none';
  }

  public show(): void {
    this.isVisible = true;
    this.container.style.display = 'block';
  }

  public hide(): void {
    this.isVisible = false;
    this.container.style.display = 'none';
  }

  private updateDisplay(metrics: PerformanceMetrics): void {
    const quality = this.performanceMonitor.getQualityLevel();
    const fpsColor = metrics.fps >= 55 ? '#10b981' : 
                    metrics.fps >= 30 ? '#f59e0b' : '#ef4444';
    const latencyColor = metrics.networkLatency <= 50 ? '#10b981' : 
                        metrics.networkLatency <= 100 ? '#f59e0b' : '#ef4444';

    this.metricsElement.innerHTML = `
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>FPS:</span>
        <span style="color: ${fpsColor}">${metrics.fps.toFixed(0)}</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Frame Time:</span>
        <span>${metrics.frameTime.toFixed(1)}ms</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Update:</span>
        <span>${metrics.updateTime.toFixed(1)}ms</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Render:</span>
        <span>${metrics.renderTime.toFixed(1)}ms</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Latency:</span>
        <span style="color: ${latencyColor}">${metrics.networkLatency.toFixed(0)}ms</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Draw Calls:</span>
        <span>${metrics.drawCalls}</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Sprites:</span>
        <span>${metrics.spriteCount}</span>
      </div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Particles:</span>
        <span>${metrics.particleCount}</span>
      </div>
      ${metrics.memoryUsage > 0 ? `
      <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
        <span>Memory:</span>
        <span>${metrics.memoryUsage.toFixed(1)}MB</span>
      </div>
      ` : ''}
      <div style="display: flex; justify-content: space-between; margin-top: 10px; padding-top: 10px; border-top: 1px solid rgba(59, 130, 246, 0.3);">
        <span>Quality:</span>
        <span style="color: #3b82f6; text-transform: uppercase;">${quality}</span>
      </div>
    `;
  }

  private updateHistory(metrics: PerformanceMetrics): void {
    this.fpsHistory.push(metrics.fps);
    this.latencyHistory.push(metrics.networkLatency);

    if (this.fpsHistory.length > this.maxHistoryLength) {
      this.fpsHistory.shift();
    }
    if (this.latencyHistory.length > this.maxHistoryLength) {
      this.latencyHistory.shift();
    }
  }

  private drawGraph(): void {
    const ctx = this.graphContext;
    const width = this.graphCanvas.width;
    const height = this.graphCanvas.height;

    // Clear canvas
    ctx.fillStyle = 'rgba(15, 23, 42, 0.8)';
    ctx.fillRect(0, 0, width, height);

    // Draw grid
    ctx.strokeStyle = 'rgba(59, 130, 246, 0.2)';
    ctx.lineWidth = 1;
    
    // Horizontal lines
    for (let i = 0; i <= 4; i++) {
      const y = (height / 4) * i;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // Draw FPS line
    if (this.fpsHistory.length > 1) {
      ctx.strokeStyle = '#10b981';
      ctx.lineWidth = 2;
      ctx.beginPath();

      for (let i = 0; i < this.fpsHistory.length; i++) {
        const x = (i / (this.maxHistoryLength - 1)) * width;
        const fps = Math.min(this.fpsHistory[i], 120); // Cap at 120 for display
        const y = height - (fps / 120) * height;

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }

      ctx.stroke();
    }

    // Draw latency line
    if (this.latencyHistory.length > 1) {
      ctx.strokeStyle = '#f59e0b';
      ctx.lineWidth = 2;
      ctx.beginPath();

      for (let i = 0; i < this.latencyHistory.length; i++) {
        const x = (i / (this.maxHistoryLength - 1)) * width;
        const latency = Math.min(this.latencyHistory[i], 200); // Cap at 200ms for display
        const y = height - (latency / 200) * height;

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }

      ctx.stroke();
    }

    // Draw labels
    ctx.fillStyle = '#e2e8f0';
    ctx.font = '10px monospace';
    ctx.textAlign = 'left';
    ctx.fillText('120 FPS', 2, 10);
    ctx.fillText('0', 2, height - 2);
    
    ctx.textAlign = 'right';
    ctx.fillStyle = '#f59e0b';
    ctx.fillText('200ms', width - 2, 10);

    // Draw legend
    ctx.textAlign = 'center';
    ctx.fillStyle = '#10b981';
    ctx.fillText('FPS', width / 4, height - 5);
    ctx.fillStyle = '#f59e0b';
    ctx.fillText('Latency', (width * 3) / 4, height - 5);
  }

  public destroy(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }

    if (this.container.parentNode) {
      this.container.parentNode.removeChild(this.container);
    }
  }
}