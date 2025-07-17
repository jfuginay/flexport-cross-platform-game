import { GameState } from '@/types';

export class UISystem {
  private gameState: GameState;
  private uiContainer: HTMLElement;
  private panels: Map<string, HTMLElement> = new Map();
  private isInitialized = false;

  constructor(gameState: GameState) {
    this.gameState = gameState;
    this.uiContainer = document.getElementById('ui-overlay')!;
    this.initialize();
  }

  private initialize(): void {
    if (this.isInitialized) return;
    
    this.createMainHUD();
    this.createEconomicDashboard();
    this.createFleetPanel();
    this.createSingularityWarning();
    this.createMinimapPanel();
    this.createControlsPanel();
    
    this.setupEventListeners();
    this.isInitialized = true;
  }

  private createMainHUD(): void {
    const hud = document.createElement('div');
    hud.className = 'main-hud ui-panel';
    hud.style.cssText = `
      position: absolute;
      top: 20px;
      left: 20px;
      padding: 20px;
      min-width: 300px;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 12px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    `;

    hud.innerHTML = `
      <div class="hud-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h2 style="margin: 0; color: #3b82f6; font-size: 18px;">Flexport Empire</h2>
        <div class="game-time" style="font-size: 12px; color: #94a3b8;"></div>
      </div>
      
      <div class="player-stats" style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px;">
        <div class="stat-item">
          <div style="font-size: 12px; color: #94a3b8;">Cash</div>
          <div class="cash-value" style="font-size: 16px; font-weight: bold; color: #10b981;">$0</div>
        </div>
        <div class="stat-item">
          <div style="font-size: 12px; color: #94a3b8;">Level</div>
          <div class="level-value" style="font-size: 16px; font-weight: bold; color: #3b82f6;">1</div>
        </div>
        <div class="stat-item">
          <div style="font-size: 12px; color: #94a3b8;">Ships</div>
          <div class="ships-value" style="font-size: 16px; font-weight: bold; color: #6366f1;">0</div>
        </div>
        <div class="stat-item">
          <div style="font-size: 12px; color: #94a3b8;">Routes</div>
          <div class="routes-value" style="font-size: 16px; font-weight: bold; color: #8b5cf6;">0</div>
        </div>
      </div>
      
      <div class="quick-actions" style="display: flex; gap: 8px; flex-wrap: wrap;">
        <button class="btn btn-primary" id="buy-ship-btn">Buy Ship</button>
        <button class="btn btn-secondary" id="create-route-btn">New Route</button>
        <button class="btn btn-secondary" id="markets-btn">Markets</button>
        <button class="btn btn-secondary" id="achievements-btn">Achievements</button>
      </div>
    `;

    this.panels.set('hud', hud);
    this.uiContainer.appendChild(hud);
  }

  private createEconomicDashboard(): void {
    const dashboard = document.createElement('div');
    dashboard.className = 'economic-dashboard ui-panel';
    dashboard.style.cssText = `
      position: absolute;
      top: 20px;
      right: 20px;
      padding: 20px;
      width: 320px;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 12px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      display: none;
    `;

    dashboard.innerHTML = `
      <div class="dashboard-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="margin: 0; color: #3b82f6; font-size: 16px;">Market Dashboard</h3>
        <button class="close-btn" style="background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 18px;">&times;</button>
      </div>
      
      <div class="market-tabs" style="display: flex; margin-bottom: 16px;">
        <button class="tab-btn active" data-market="goods" style="flex: 1; padding: 8px; background: #3b82f6; border: none; color: white; cursor: pointer; border-radius: 4px 0 0 4px;">Goods</button>
        <button class="tab-btn" data-market="capital" style="flex: 1; padding: 8px; background: #374151; border: none; color: white; cursor: pointer;">Capital</button>
        <button class="tab-btn" data-market="assets" style="flex: 1; padding: 8px; background: #374151; border: none; color: white; cursor: pointer;">Assets</button>
        <button class="tab-btn" data-market="labor" style="flex: 1; padding: 8px; background: #374151; border: none; color: white; cursor: pointer; border-radius: 0 4px 4px 0;">Labor</button>
      </div>
      
      <div class="market-content">
        <div class="market-summary" style="margin-bottom: 16px;">
          <div style="font-size: 12px; color: #94a3b8; margin-bottom: 8px;">Market Overview</div>
          <div class="market-indicators" style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 12px;"></div>
        </div>
        
        <div class="market-items" style="max-height: 200px; overflow-y: auto;">
          <!-- Market items will be populated dynamically -->
        </div>
      </div>
    `;

    this.panels.set('dashboard', dashboard);
    this.uiContainer.appendChild(dashboard);
  }

  private createFleetPanel(): void {
    const fleet = document.createElement('div');
    fleet.className = 'fleet-panel ui-panel';
    fleet.style.cssText = `
      position: absolute;
      bottom: 20px;
      left: 20px;
      padding: 20px;
      width: 400px;
      max-height: 300px;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 12px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      display: none;
    `;

    fleet.innerHTML = `
      <div class="fleet-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="margin: 0; color: #3b82f6; font-size: 16px;">Fleet Management</h3>
        <button class="close-btn" style="background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 18px;">&times;</button>
      </div>
      
      <div class="fleet-summary" style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 16px; font-size: 12px;">
        <div class="summary-item">
          <div style="color: #94a3b8;">Total Ships</div>
          <div class="total-ships" style="font-size: 16px; font-weight: bold; color: #10b981;">0</div>
        </div>
        <div class="summary-item">
          <div style="color: #94a3b8;">Active</div>
          <div class="active-ships" style="font-size: 16px; font-weight: bold; color: #3b82f6;">0</div>
        </div>
        <div class="summary-item">
          <div style="color: #94a3b8;">Capacity</div>
          <div class="total-capacity" style="font-size: 16px; font-weight: bold; color: #f59e0b;">0</div>
        </div>
        <div class="summary-item">
          <div style="color: #94a3b8;">Maintenance</div>
          <div class="maintenance-cost" style="font-size: 16px; font-weight: bold; color: #ef4444;">$0</div>
        </div>
      </div>
      
      <div class="ship-list" style="max-height: 180px; overflow-y: auto;">
        <!-- Ship items will be populated dynamically -->
      </div>
    `;

    this.panels.set('fleet', fleet);
    this.uiContainer.appendChild(fleet);
  }

  private createSingularityWarning(): void {
    const warning = document.createElement('div');
    warning.className = 'singularity-warning ui-panel';
    warning.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      padding: 24px;
      max-width: 500px;
      background: linear-gradient(135deg, rgba(239, 68, 68, 0.95), rgba(185, 28, 28, 0.95));
      backdrop-filter: blur(10px);
      border: 2px solid rgba(239, 68, 68, 0.8);
      border-radius: 16px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
      text-align: center;
      display: none;
      z-index: 1000;
    `;

    warning.innerHTML = `
      <div class="warning-icon" style="font-size: 48px; margin-bottom: 16px;">⚠️</div>
      <h2 style="margin: 0 0 16px 0; font-size: 24px;">AI Singularity Alert</h2>
      <div class="singularity-progress" style="margin-bottom: 16px;">
        <div style="font-size: 14px; margin-bottom: 8px;">Singularity Progress</div>
        <div class="progress-bar" style="width: 100%; height: 8px; background: rgba(255,255,255,0.3); border-radius: 4px; overflow: hidden;">
          <div class="progress-fill" style="height: 100%; background: linear-gradient(90deg, #fbbf24, #f59e0b); transition: width 0.3s ease; width: 0%;"></div>
        </div>
        <div class="progress-text" style="font-size: 12px; margin-top: 4px;">0% Complete</div>
      </div>
      <p class="warning-message" style="margin: 0 0 20px 0; font-size: 14px; line-height: 1.5;"></p>
      <div class="time-remaining" style="font-size: 12px; color: rgba(255,255,255,0.8); margin-bottom: 16px;"></div>
      <button class="acknowledge-btn btn" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); color: white; padding: 8px 16px; border-radius: 6px; cursor: pointer;">Acknowledge</button>
    `;

    this.panels.set('warning', warning);
    this.uiContainer.appendChild(warning);
  }

  private createMinimapPanel(): void {
    const minimap = document.createElement('div');
    minimap.className = 'minimap-panel ui-panel';
    minimap.style.cssText = `
      position: absolute;
      bottom: 20px;
      right: 20px;
      width: 200px;
      height: 150px;
      background: rgba(15, 23, 42, 0.95);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 12px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    `;

    minimap.innerHTML = `
      <div class="minimap-header" style="padding: 8px 12px; border-bottom: 1px solid rgba(59, 130, 246, 0.3); font-size: 12px; font-weight: bold;">
        World Map
      </div>
      <div class="minimap-content" style="position: relative; width: 100%; height: calc(100% - 32px); background: linear-gradient(135deg, #1e293b, #334155); overflow: hidden;">
        <!-- Minimap will be rendered here -->
      </div>
    `;

    this.panels.set('minimap', minimap);
    this.uiContainer.appendChild(minimap);
  }

  private createControlsPanel(): void {
    const controls = document.createElement('div');
    controls.className = 'controls-panel ui-panel';
    controls.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      padding: 24px;
      max-width: 600px;
      background: rgba(15, 23, 42, 0.98);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 16px;
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
      display: none;
      z-index: 1000;
    `;

    controls.innerHTML = `
      <div class="controls-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <h2 style="margin: 0; color: #3b82f6; font-size: 20px;">Game Controls</h2>
        <button class="close-btn" style="background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 24px;">&times;</button>
      </div>
      
      <div class="controls-content" style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px;">
        <div class="control-section">
          <h3 style="margin: 0 0 12px 0; color: #f1f5f9; font-size: 16px;">Navigation</h3>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>Mouse/Touch:</strong> Drag to pan map
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>Scroll/Pinch:</strong> Zoom in/out
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>WASD/Arrows:</strong> Pan map
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>+/- Keys:</strong> Zoom control
          </div>
        </div>
        
        <div class="control-section">
          <h3 style="margin: 0 0 12px 0; color: #f1f5f9; font-size: 16px;">Game Actions</h3>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>Click Port:</strong> View port details
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>M:</strong> Toggle markets dashboard
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>F:</strong> Find port
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>Space:</strong> Pause/Resume
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>Esc:</strong> Close dialogs
          </div>
          <div class="control-item" style="margin-bottom: 8px; font-size: 14px;">
            <strong>H:</strong> Show this help
          </div>
        </div>
      </div>
    `;

    this.panels.set('controls', controls);
    this.uiContainer.appendChild(controls);
  }

  private setupEventListeners(): void {
    // Main HUD button listeners
    const hudPanel = this.panels.get('hud');
    if (hudPanel) {
      hudPanel.querySelector('#buy-ship-btn')?.addEventListener('click', () => {
        this.showBuyShipDialog();
      });
      
      hudPanel.querySelector('#create-route-btn')?.addEventListener('click', () => {
        this.showCreateRouteDialog();
      });
      
      hudPanel.querySelector('#markets-btn')?.addEventListener('click', () => {
        this.togglePanel('dashboard');
      });
    }

    // Dashboard close and tab listeners
    const dashboard = this.panels.get('dashboard');
    if (dashboard) {
      dashboard.querySelector('.close-btn')?.addEventListener('click', () => {
        this.hidePanel('dashboard');
      });
      
      dashboard.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const market = (e.target as HTMLElement).dataset.market;
          if (market) this.switchMarketTab(market);
        });
      });
    }

    // Fleet panel close listener
    const fleet = this.panels.get('fleet');
    if (fleet) {
      fleet.querySelector('.close-btn')?.addEventListener('click', () => {
        this.hidePanel('fleet');
      });
    }

    // Singularity warning acknowledge
    const warning = this.panels.get('warning');
    if (warning) {
      warning.querySelector('.acknowledge-btn')?.addEventListener('click', () => {
        this.hidePanel('warning');
      });
    }

    // Controls panel close
    const controls = this.panels.get('controls');
    if (controls) {
      controls.querySelector('.close-btn')?.addEventListener('click', () => {
        this.hidePanel('controls');
      });
    }

    // Global event listeners
    document.addEventListener('keydown', (e) => {
      this.handleKeyPress(e.code);
    });
  }

  private handleKeyPress(keyCode: string): void {
    switch (keyCode) {
      case 'KeyM':
        this.togglePanel('dashboard');
        break;
      case 'KeyF':
        this.togglePanel('fleet');
        break;
      case 'KeyH':
        this.togglePanel('controls');
        break;
      case 'Escape':
        this.hideAllModals();
        break;
    }
  }

  private showBuyShipDialog(): void {
    // Implementation for ship purchase dialog
    console.log('Buy ship dialog would open here');
  }

  private showCreateRouteDialog(): void {
    // Implementation for route creation dialog
    console.log('Create route dialog would open here');
  }

  private switchMarketTab(market: string): void {
    const dashboard = this.panels.get('dashboard');
    if (!dashboard) return;

    // Update tab styles
    dashboard.querySelectorAll('.tab-btn').forEach(btn => {
      btn.classList.remove('active');
      (btn as HTMLElement).style.background = '#374151';
    });
    
    const activeTab = dashboard.querySelector(`[data-market="${market}"]`);
    if (activeTab) {
      activeTab.classList.add('active');
      (activeTab as HTMLElement).style.background = '#3b82f6';
    }

    // Update market content
    this.updateMarketDisplay(market);
  }

  private updateMarketDisplay(marketType: string): void {
    const dashboard = this.panels.get('dashboard');
    if (!dashboard) return;

    const market = this.gameState.markets[marketType as keyof typeof this.gameState.markets];
    if (!market) return;

    const indicators = dashboard.querySelector('.market-indicators');
    const items = dashboard.querySelector('.market-items');
    
    if (indicators && items) {
      // Update market indicators
      indicators.innerHTML = `
        <div style="color: #10b981;">Avg Price: $${this.formatNumber(this.calculateAveragePrice(market))}</div>
        <div style="color: ${this.calculateAverageTrend(market) > 0 ? '#10b981' : '#ef4444'};">
          Trend: ${this.calculateAverageTrend(market) > 0 ? '↗' : '↘'} ${(this.calculateAverageTrend(market) * 100).toFixed(1)}%
        </div>
        <div style="color: #f59e0b;">Volume: ${this.formatNumber(this.calculateTotalVolume(market))}</div>
        <div style="color: #8b5cf6;">Volatility: ${(this.calculateAverageVolatility(market) * 100).toFixed(1)}%</div>
      `;

      // Update market items
      items.innerHTML = Object.entries(market.prices).map(([item, price]) => `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid rgba(59, 130, 246, 0.1);">
          <div style="font-size: 14px; text-transform: capitalize;">${item.replace('_', ' ')}</div>
          <div style="text-align: right;">
            <div style="font-size: 14px; font-weight: bold;">$${this.formatNumber(price)}</div>
            <div style="font-size: 12px; color: ${(market.trends[item] || 0) > 0 ? '#10b981' : '#ef4444'};">
              ${(market.trends[item] || 0) > 0 ? '↗' : '↘'} ${((market.trends[item] || 0) * 100).toFixed(1)}%
            </div>
          </div>
        </div>
      `).join('');
    }
  }

  private togglePanel(panelName: string): void {
    const panel = this.panels.get(panelName);
    if (!panel) return;

    const isVisible = panel.style.display !== 'none';
    if (isVisible) {
      this.hidePanel(panelName);
    } else {
      this.showPanel(panelName);
    }
  }

  private showPanel(panelName: string): void {
    const panel = this.panels.get(panelName);
    if (panel) {
      panel.style.display = 'block';
      
      // Update content when showing
      if (panelName === 'dashboard') {
        this.updateMarketDisplay('goods');
      } else if (panelName === 'fleet') {
        this.updateFleetDisplay();
      }
    }
  }

  private hidePanel(panelName: string): void {
    const panel = this.panels.get(panelName);
    if (panel) {
      panel.style.display = 'none';
    }
  }

  private hideAllModals(): void {
    ['dashboard', 'fleet', 'controls', 'warning'].forEach(panel => {
      this.hidePanel(panel);
    });
  }

  private updateFleetDisplay(): void {
    const fleet = this.panels.get('fleet');
    if (!fleet) return;

    const ships = this.gameState.player.ships;
    const totalCapacity = ships.reduce((sum, ship) => sum + ship.capacity, 0);
    const totalMaintenance = ships.reduce((sum, ship) => sum + ship.maintenanceCost, 0);
    const activeShips = ships.filter(ship => ship.status !== 'docked').length;

    // Update summary
    const summary = fleet.querySelector('.fleet-summary');
    if (summary) {
      (summary.querySelector('.total-ships') as HTMLElement).textContent = ships.length.toString();
      (summary.querySelector('.active-ships') as HTMLElement).textContent = activeShips.toString();
      (summary.querySelector('.total-capacity') as HTMLElement).textContent = this.formatNumber(totalCapacity);
      (summary.querySelector('.maintenance-cost') as HTMLElement).textContent = `$${this.formatNumber(totalMaintenance)}`;
    }

    // Update ship list
    const shipList = fleet.querySelector('.ship-list');
    if (shipList) {
      shipList.innerHTML = ships.map(ship => `
        <div class="ship-item" style="display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid rgba(59, 130, 246, 0.1);">
          <div>
            <div style="font-size: 14px; font-weight: bold;">${ship.name}</div>
            <div style="font-size: 12px; color: #94a3b8; text-transform: capitalize;">${ship.type.replace('_', ' ')} • ${ship.status.replace('_', ' ')}</div>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 12px; color: #10b981;">⛽ ${Math.round(ship.fuel)}%</div>
            <div style="font-size: 12px; color: #f59e0b;">🔧 ${Math.round(ship.condition)}%</div>
          </div>
        </div>
      `).join('');
    }
  }

  public update(deltaTime: number): void {
    this.updateHUD();
    this.updateSingularityWarning();
    this.updateGameTime(deltaTime);
  }

  private updateHUD(): void {
    const hud = this.panels.get('hud');
    if (!hud) return;

    const player = this.gameState.player;
    
    (hud.querySelector('.cash-value') as HTMLElement).textContent = `$${this.formatNumber(player.cash)}`;
    (hud.querySelector('.level-value') as HTMLElement).textContent = player.level.toString();
    (hud.querySelector('.ships-value') as HTMLElement).textContent = player.ships.length.toString();
    (hud.querySelector('.routes-value') as HTMLElement).textContent = player.tradeRoutes.length.toString();
  }

  private updateSingularityWarning(): void {
    const warning = this.panels.get('warning');
    if (!warning) return;

    const singularity = this.gameState.singularityProgress;
    const shouldShow = singularity.progress > 10 && warning.style.display === 'none';
    
    if (shouldShow) {
      this.showPanel('warning');
    }

    // Update progress bar
    const progressFill = warning.querySelector('.progress-fill') as HTMLElement;
    const progressText = warning.querySelector('.progress-text') as HTMLElement;
    const message = warning.querySelector('.warning-message') as HTMLElement;
    const timeRemaining = warning.querySelector('.time-remaining') as HTMLElement;

    if (progressFill && progressText && message && timeRemaining) {
      progressFill.style.width = `${singularity.progress}%`;
      progressText.textContent = `${Math.round(singularity.progress)}% Complete`;
      message.textContent = singularity.playerWarning;
      timeRemaining.textContent = `Time Remaining: ${this.formatTime(singularity.timeRemaining)}`;
    }
  }

  private updateGameTime(deltaTime: number): void {
    const hud = this.panels.get('hud');
    if (!hud) return;

    const gameTimeElement = hud.querySelector('.game-time') as HTMLElement;
    if (gameTimeElement) {
      const gameTime = this.gameState.gameTime;
      const hours = Math.floor(gameTime / 3600);
      const minutes = Math.floor((gameTime % 3600) / 60);
      gameTimeElement.textContent = `Day ${Math.floor(hours / 24) + 1}, ${hours % 24}:${minutes.toString().padStart(2, '0')}`;
    }
  }

  private calculateAveragePrice(market: any): number {
    const prices = Object.values(market.prices) as number[];
    return prices.reduce((sum, price) => sum + price, 0) / prices.length;
  }

  private calculateAverageTrend(market: any): number {
    const trends = Object.values(market.trends) as number[];
    return trends.reduce((sum, trend) => sum + trend, 0) / trends.length;
  }

  private calculateTotalVolume(market: any): number {
    return Object.values(market.volume).reduce((sum: number, volume: any) => sum + volume, 0);
  }

  private calculateAverageVolatility(market: any): number {
    const volatilities = Object.values(market.volatility) as number[];
    return volatilities.reduce((sum, vol) => sum + vol, 0) / volatilities.length;
  }

  private formatNumber(num: number): string {
    if (num >= 1000000000) {
      return (num / 1000000000).toFixed(1) + 'B';
    }
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return Math.round(num).toString();
  }

  private formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }

  public handleResize(width: number, height: number): void {
    // Adjust panel positions for different screen sizes
    if (width < 768) {
      // Mobile layout adjustments
      const hud = this.panels.get('hud');
      const dashboard = this.panels.get('dashboard');
      
      if (hud) {
        hud.style.width = '90%';
        hud.style.left = '5%';
      }
      
      if (dashboard) {
        dashboard.style.width = '90%';
        dashboard.style.right = '5%';
        dashboard.style.left = 'auto';
      }
    }
  }

  public destroy(): void {
    this.panels.forEach(panel => {
      panel.removeEventListener?.('click', () => {});
      panel.remove();
    });
    this.panels.clear();
  }
}