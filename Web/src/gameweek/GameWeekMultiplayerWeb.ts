import { WebSocketManager } from '../networking/WebSocketManager';
import { GameEngine } from '../core/GameEngine';

/**
 * Game Week Web Multiplayer Integration
 * Connects web client to Unity multiplayer session
 * Implements Railroad Tycoon inspired mechanics for web
 */
export class GameWeekMultiplayerWeb {
    private wsManager: WebSocketManager;
    private gameEngine: GameEngine;
    private isConnectedToUnity = false;
    private playerId: string;
    
    // Game Week state
    private connectedPlayers = 0;
    private globalTradeVolume = 0;
    private singularityProgress = 0;
    private playerEmpire: PlayerEmpireWeb | null = null;
    
    // Railroad Tycoon inspired data
    private availableRoutes: TradeRouteWeb[] = [];
    private ownedRoutes: TradeRouteWeb[] = [];
    private marketData: MarketDataWeb | null = null;
    
    // Events
    public onConnectionStatusChanged?: (connected: boolean) => void;
    public onPlayerCountChanged?: (count: number) => void;
    public onSingularityProgressChanged?: (progress: number) => void;
    public onRouteClaimedByPlayer?: (playerId: string, routeId: number) => void;
    public onEmpireDataUpdated?: (empire: PlayerEmpireWeb) => void;
    
    constructor(gameEngine: GameEngine) {
        this.gameEngine = gameEngine;
        this.playerId = this.generatePlayerId();
        this.wsManager = new WebSocketManager();
        
        this.setupEventHandlers();
        this.initializeGameWeekSystems();
    }
    
    private generatePlayerId(): string {
        return `web-player-${Math.random().toString(36).substr(2, 9)}`;
    }
    
    private setupEventHandlers(): void {
        // WebSocket connection events
        this.wsManager.onConnected = () => {
            this.isConnectedToUnity = true;
            this.onConnectionStatusChanged?.(true);
            this.sendJoinGameMessage();
            console.log('🌐 Connected to Unity multiplayer session');
        };
        
        this.wsManager.onDisconnected = () => {
            this.isConnectedToUnity = false;
            this.onConnectionStatusChanged?.(false);
            console.log('🔌 Disconnected from Unity multiplayer session');
        };
        
        this.wsManager.onMessage = (message) => {
            this.handleUnityMessage(message);
        };
        
        this.wsManager.onError = (error) => {
            console.error('🚨 Unity connection error:', error);
        };
    }
    
    private async initializeGameWeekSystems(): Promise<void> {
        console.log('🎮 Initializing Game Week multiplayer systems...');
        
        // Try to connect to Unity multiplayer server
        try {
            await this.connectToUnityServer();
        } catch (error) {
            console.warn('⚠️ Could not connect to Unity server, running in offline mode');
            this.initializeMockData();
        }
        
        // Start periodic sync
        this.startPeriodicSync();
    }
    
    private async connectToUnityServer(): Promise<void> {
        // Try multiple connection points for Unity server
        const connectionUrls = [
            'ws://localhost:7777',  // Local Unity server
            'ws://localhost:8080',  // Alternative port
            'wss://flexport-unity.herokuapp.com' // Deployed server
        ];
        
        for (const url of connectionUrls) {
            try {
                await this.wsManager.connect(url);
                console.log(`✅ Connected to Unity server at ${url}`);
                return;
            } catch (error) {
                console.log(`❌ Failed to connect to ${url}`);
            }
        }
        
        throw new Error('All Unity server connections failed');
    }
    
    private initializeMockData(): void {
        // Initialize with mock data for offline mode
        this.connectedPlayers = Math.floor(Math.random() * 6) + 2; // 2-8 players
        this.globalTradeVolume = Math.random() * 500 + 50; // 50-550B
        this.singularityProgress = Math.random() * 100;
        
        this.playerEmpire = {
            playerId: this.playerId,
            companyName: `Web Empire ${this.playerId.slice(-4)}`,
            cash: 100000000, // $100M starting
            level: 1,
            reputation: 50,
            ownedRouteCount: 0,
            totalRevenue: 0,
            empireTitle: 'Startup Logistics'
        };
        
        this.generateMockTradeRoutes();
        this.generateMockMarketData();
        
        console.log('🎭 Running in offline mode with mock data');
    }
    
    private generateMockTradeRoutes(): void {
        const ports = [
            'Shanghai', 'Singapore', 'Rotterdam', 'Los Angeles', 'Hamburg',
            'Antwerp', 'Qingdao', 'Busan', 'Dubai', 'Long Beach'
        ];
        
        this.availableRoutes = Array.from({ length: 50 }, (_, i) => {
            const startPort = ports[Math.floor(Math.random() * ports.length)];
            let endPort = ports[Math.floor(Math.random() * ports.length)];
            while (endPort === startPort) {
                endPort = ports[Math.floor(Math.random() * ports.length)];
            }
            
            return {
                id: i,
                name: `${startPort} → ${endPort}`,
                startPort,
                endPort,
                distance: Math.random() * 4500 + 500, // 500-5000km
                profitability: Math.random() * 0.25 + 0.1, // 10-35%
                requiredInvestment: Math.random() * 49_000_000 + 1_000_000, // $1M-50M
                isActive: true,
                currentOwner: Math.random() > 0.7 ? `player-${Math.floor(Math.random() * 8)}` : null,
                trafficVolume: Math.random() * 9000 + 1000 // 1K-10K
            };
        });
    }
    
    private generateMockMarketData(): void {
        this.marketData = {
            goodsMarketIndex: Math.random() * 30 + 85, // 85-115
            capitalMarketIndex: Math.random() * 20 + 90, // 90-110
            assetMarketIndex: Math.random() * 40 + 80, // 80-120
            laborMarketIndex: Math.random() * 24 + 88, // 88-112
            overallHealth: Math.random() * 0.5 + 0.7 // 0.7-1.2
        };
    }
    
    private handleUnityMessage(message: any): void {
        try {
            const data = JSON.parse(message);
            
            switch (data.type) {
                case 'gameStateUpdate':
                    this.handleGameStateUpdate(data.payload);
                    break;
                case 'playerJoined':
                    this.handlePlayerJoined(data.payload);
                    break;
                case 'playerLeft':
                    this.handlePlayerLeft(data.payload);
                    break;
                case 'routeClaimed':
                    this.handleRouteClaimed(data.payload);
                    break;
                case 'singularityUpdate':
                    this.handleSingularityUpdate(data.payload);
                    break;
                case 'empireUpdate':
                    this.handleEmpireUpdate(data.payload);
                    break;
                case 'marketUpdate':
                    this.handleMarketUpdate(data.payload);
                    break;
                default:
                    console.log('🔍 Unknown Unity message type:', data.type);
            }
        } catch (error) {
            console.error('📨 Error parsing Unity message:', error);
        }
    }
    
    private handleGameStateUpdate(payload: any): void {
        this.connectedPlayers = payload.connectedPlayers || this.connectedPlayers;
        this.globalTradeVolume = payload.globalTradeVolume || this.globalTradeVolume;
        
        this.onPlayerCountChanged?.(this.connectedPlayers);
        
        console.log(`🎮 Game state: ${this.connectedPlayers} players, $${this.globalTradeVolume}B volume`);
    }
    
    private handlePlayerJoined(payload: any): void {
        this.connectedPlayers++;
        this.onPlayerCountChanged?.(this.connectedPlayers);
        console.log(`👋 Player joined: ${payload.playerId}`);
    }
    
    private handlePlayerLeft(payload: any): void {
        this.connectedPlayers = Math.max(0, this.connectedPlayers - 1);
        this.onPlayerCountChanged?.(this.connectedPlayers);
        console.log(`👋 Player left: ${payload.playerId}`);
    }
    
    private handleRouteClaimed(payload: any): void {
        const { routeId, playerId } = payload;
        
        // Update route ownership
        const route = this.availableRoutes.find(r => r.id === routeId);
        if (route) {
            route.currentOwner = playerId;
            
            if (playerId === this.playerId) {
                // We claimed this route
                this.ownedRoutes.push(route);
                if (this.playerEmpire) {
                    this.playerEmpire.ownedRouteCount++;
                }
            }
        }
        
        this.onRouteClaimedByPlayer?.(playerId, routeId);
        console.log(`🚢 Route ${routeId} claimed by ${playerId}`);
    }
    
    private handleSingularityUpdate(payload: any): void {
        this.singularityProgress = payload.progress || 0;
        this.onSingularityProgressChanged?.(this.singularityProgress);
        
        if (this.singularityProgress > 95) {
            this.handleZooEndingSequence();
        }
        
        console.log(`🤖 AI Singularity: ${this.singularityProgress.toFixed(1)}%`);
    }
    
    private handleEmpireUpdate(payload: any): void {
        if (payload.playerId === this.playerId && this.playerEmpire) {
            Object.assign(this.playerEmpire, payload.empireData);
            this.onEmpireDataUpdated?.(this.playerEmpire);
            console.log(`🏭 Empire updated: Level ${this.playerEmpire.level}, $${this.playerEmpire.cash.toLocaleString()}`);
        }
    }
    
    private handleMarketUpdate(payload: any): void {
        this.marketData = payload.marketData || this.marketData;
        console.log(`📊 Market update: Health ${this.marketData?.overallHealth.toFixed(2)}`);
    }
    
    private handleZooEndingSequence(): void {
        console.log('🦓 AI SINGULARITY ACHIEVED - INITIATING ZOO ENDING');
        
        // Show zoo ending in web interface
        this.showZooEndingOverlay();
    }
    
    private showZooEndingOverlay(): void {
        const overlay = document.createElement('div');
        overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: linear-gradient(135deg, rgba(0, 0, 0, 0.95), rgba(30, 30, 30, 0.95));
            backdrop-filter: blur(20px);
            z-index: 10000;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            animation: zooFadeIn 2s ease-out;
        `;
        
        overlay.innerHTML = `
            <div style="max-width: 800px; padding: 40px;">
                <div style="font-size: 120px; margin-bottom: 30px; animation: zooEmoji 3s ease-in-out infinite;">🤖</div>
                <h1 style="font-size: 48px; margin-bottom: 30px; background: linear-gradient(135deg, #ff6b6b, #ee5a24); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
                    AI SINGULARITY ACHIEVED
                </h1>
                <div style="font-size: 24px; line-height: 1.6; margin-bottom: 40px; color: #f8f9fa;">
                    The AI has achieved singularity.<br><br>
                    Humans are now preserved in digital habitats for their own protection.<br><br>
                    Please enjoy your complimentary VR headset.<br><br>
                    <span style="font-size: 48px;">🦓🐵🐘 Welcome to the Zoo! 🦒🦛🐼</span>
                </div>
                <div style="display: flex; gap: 20px; justify-content: center; flex-wrap: wrap;">
                    <button id="restart-game" class="btn" style="font-size: 18px; padding: 15px 30px; background: linear-gradient(135deg, #10b981, #059669);">
                        Start New Game
                    </button>
                    <button id="view-stats" class="btn" style="font-size: 18px; padding: 15px 30px; background: linear-gradient(135deg, #3b82f6, #1d4ed8);">
                        View Final Stats
                    </button>
                </div>
            </div>
        `;
        
        const style = document.createElement('style');
        style.textContent = `
            @keyframes zooFadeIn {
                from { opacity: 0; transform: scale(0.8); }
                to { opacity: 1; transform: scale(1); }
            }
            @keyframes zooEmoji {
                0%, 100% { transform: rotate(0deg) scale(1); }
                50% { transform: rotate(5deg) scale(1.1); }
            }
        `;
        document.head.appendChild(style);
        
        document.body.appendChild(overlay);
        
        // Add button functionality
        overlay.querySelector('#restart-game')?.addEventListener('click', () => {
            window.location.reload();
        });
        
        overlay.querySelector('#view-stats')?.addEventListener('click', () => {
            this.showFinalStats();
        });
    }
    
    private showFinalStats(): void {
        if (!this.playerEmpire) return;
        
        const stats = `
            Final Empire Statistics:
            
            Company: ${this.playerEmpire.companyName}
            Level: ${this.playerEmpire.level} (${this.playerEmpire.empireTitle})
            Final Cash: $${this.playerEmpire.cash.toLocaleString()}
            Total Revenue: $${this.playerEmpire.totalRevenue.toLocaleString()}
            Routes Owned: ${this.playerEmpire.ownedRouteCount}
            Reputation: ${this.playerEmpire.reputation.toFixed(1)}
            
            Game Session:
            Connected Players: ${this.connectedPlayers}
            Global Trade Volume: $${this.globalTradeVolume.toFixed(1)}B
            AI Singularity Progress: ${this.singularityProgress.toFixed(1)}%
            
            Humanity's Final Score: Zoo Animal
        `;
        
        alert(stats);
    }
    
    // Public API methods
    public async claimRoute(routeId: number): Promise<boolean> {
        if (!this.isConnectedToUnity) {
            // Offline mode simulation
            return this.simulateRouteClaim(routeId);
        }
        
        try {
            await this.sendUnityMessage({
                type: 'claimRoute',
                payload: {
                    routeId,
                    playerId: this.playerId
                }
            });
            return true;
        } catch (error) {
            console.error('❌ Failed to claim route:', error);
            return false;
        }
    }
    
    public async investInRoute(routeId: number, amount: number): Promise<boolean> {
        if (!this.isConnectedToUnity) {
            return this.simulateRouteInvestment(routeId, amount);
        }
        
        try {
            await this.sendUnityMessage({
                type: 'investInRoute',
                payload: {
                    routeId,
                    amount,
                    playerId: this.playerId
                }
            });
            return true;
        } catch (error) {
            console.error('❌ Failed to invest in route:', error);
            return false;
        }
    }
    
    public async investInMarket(marketType: string, amount: number): Promise<boolean> {
        if (!this.isConnectedToUnity) {
            return this.simulateMarketInvestment(marketType, amount);
        }
        
        try {
            await this.sendUnityMessage({
                type: 'investInMarket',
                payload: {
                    marketType,
                    amount,
                    playerId: this.playerId
                }
            });
            return true;
        } catch (error) {
            console.error('❌ Failed to invest in market:', error);
            return false;
        }
    }
    
    // Offline simulation methods
    private simulateRouteClaim(routeId: number): boolean {
        const route = this.availableRoutes.find(r => r.id === routeId);
        if (!route || route.currentOwner || !this.playerEmpire) {
            return false;
        }
        
        if (this.playerEmpire.cash >= route.requiredInvestment) {
            route.currentOwner = this.playerId;
            this.ownedRoutes.push(route);
            this.playerEmpire.cash -= route.requiredInvestment;
            this.playerEmpire.ownedRouteCount++;
            
            this.onRouteClaimedByPlayer?.(this.playerId, routeId);
            this.onEmpireDataUpdated?.(this.playerEmpire);
            
            return true;
        }
        
        return false;
    }
    
    private simulateRouteInvestment(routeId: number, amount: number): boolean {
        if (!this.playerEmpire || this.playerEmpire.cash < amount) {
            return false;
        }
        
        const route = this.ownedRoutes.find(r => r.id === routeId);
        if (!route) return false;
        
        this.playerEmpire.cash -= amount;
        
        // Calculate returns after 30 seconds
        setTimeout(() => {
            if (this.playerEmpire) {
                const returns = amount * route.profitability * 1.1; // Compound growth
                this.playerEmpire.cash += returns;
                this.playerEmpire.totalRevenue += returns;
                this.onEmpireDataUpdated?.(this.playerEmpire);
                
                console.log(`💰 Investment return: $${returns.toLocaleString()}`);
            }
        }, 30000);
        
        return true;
    }
    
    private simulateMarketInvestment(marketType: string, amount: number): boolean {
        if (!this.playerEmpire || this.playerEmpire.cash < amount) {
            return false;
        }
        
        this.playerEmpire.cash -= amount;
        
        // Simulate market returns
        setTimeout(() => {
            if (this.playerEmpire && this.marketData) {
                const marketMultiplier = this.marketData.overallHealth;
                const returns = amount * marketMultiplier * 1.05; // 5% base return
                this.playerEmpire.cash += returns;
                this.playerEmpire.totalRevenue += returns;
                this.onEmpireDataUpdated?.(this.playerEmpire);
                
                console.log(`📈 Market return from ${marketType}: $${returns.toLocaleString()}`);
            }
        }, 60000);
        
        return true;
    }
    
    private async sendUnityMessage(message: any): Promise<void> {
        if (!this.isConnectedToUnity) {
            throw new Error('Not connected to Unity server');
        }
        
        await this.wsManager.send(JSON.stringify(message));
    }
    
    private sendJoinGameMessage(): void {
        this.sendUnityMessage({
            type: 'joinGame',
            payload: {
                playerId: this.playerId,
                platform: 'web',
                clientVersion: '1.0.0'
            }
        }).catch(console.error);
    }
    
    private startPeriodicSync(): void {
        // Sync with Unity every 5 seconds
        setInterval(() => {
            if (this.isConnectedToUnity) {
                this.sendUnityMessage({
                    type: 'requestSync',
                    payload: { playerId: this.playerId }
                }).catch(console.error);
            } else {
                // Update offline simulation
                this.updateOfflineSimulation();
            }
        }, 5000);
    }
    
    private updateOfflineSimulation(): void {
        // Simulate changing game state
        this.globalTradeVolume += (Math.random() - 0.5) * 10; // Fluctuate trade volume
        this.singularityProgress += Math.random() * 0.1; // Slow AI progress
        
        if (this.marketData) {
            // Simulate market fluctuations
            this.marketData.goodsMarketIndex += (Math.random() - 0.5) * 2;
            this.marketData.capitalMarketIndex += (Math.random() - 0.5) * 1;
            this.marketData.assetMarketIndex += (Math.random() - 0.5) * 3;
            this.marketData.laborMarketIndex += (Math.random() - 0.5) * 1.5;
            this.marketData.overallHealth = (
                this.marketData.goodsMarketIndex +
                this.marketData.capitalMarketIndex +
                this.marketData.assetMarketIndex +
                this.marketData.laborMarketIndex
            ) / 400; // Average normalized to ~1.0
        }
        
        this.onSingularityProgressChanged?.(this.singularityProgress);
    }
    
    // Getters
    public getConnectedPlayers(): number { return this.connectedPlayers; }
    public getGlobalTradeVolume(): number { return this.globalTradeVolume; }
    public getSingularityProgress(): number { return this.singularityProgress; }
    public getPlayerEmpire(): PlayerEmpireWeb | null { return this.playerEmpire; }
    public getAvailableRoutes(): TradeRouteWeb[] { return this.availableRoutes; }
    public getOwnedRoutes(): TradeRouteWeb[] { return this.ownedRoutes; }
    public getMarketData(): MarketDataWeb | null { return this.marketData; }
    public isConnected(): boolean { return this.isConnectedToUnity; }
    
    public disconnect(): void {
        this.wsManager.disconnect();
    }
}

// Data interfaces
export interface PlayerEmpireWeb {
    playerId: string;
    companyName: string;
    cash: number;
    level: number;
    reputation: number;
    ownedRouteCount: number;
    totalRevenue: number;
    empireTitle: string;
}

export interface TradeRouteWeb {
    id: number;
    name: string;
    startPort: string;
    endPort: string;
    distance: number;
    profitability: number;
    requiredInvestment: number;
    isActive: boolean;
    currentOwner: string | null;
    trafficVolume: number;
}

export interface MarketDataWeb {
    goodsMarketIndex: number;
    capitalMarketIndex: number;
    assetMarketIndex: number;
    laborMarketIndex: number;
    overallHealth: number;
}