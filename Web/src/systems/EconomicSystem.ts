import { GameState, Market, MarketType, CommodityType, EconomicEvent, Ship, Cargo } from '@/types';
import { PortData } from '@/utils/PortData';
import { ProgressionSystem } from './ProgressionSystem';

export class EconomicSystem {
  private gameState: GameState;
  private progressionSystem: ProgressionSystem | null = null;
  private updateInterval = 0;
  private readonly UPDATE_FREQUENCY = 5; // Update every 5 seconds
  private readonly VOLATILITY_BASE = 0.05;
  private readonly TREND_DECAY = 0.98;

  private readonly COMMODITY_BASE_PRICES: Record<CommodityType, number> = {
    steel: 850,
    oil: 75,
    grain: 280,
    electronics: 1200,
    textiles: 450,
    chemicals: 920,
    machinery: 2100,
    coal: 120,
  };

  private readonly MARKET_INTERCONNECTIONS = {
    goods: {
      capital: 0.3,   // Interest rates affect commodity financing
      assets: 0.4,    // Ship prices affect transport costs
      labor: 0.2,     // Worker costs affect production
    },
    capital: {
      goods: 0.2,     // Commodity prices affect investment returns
      assets: 0.6,    // Asset prices heavily tied to credit availability
      labor: 0.3,     // Employment affects interest rates
    },
    assets: {
      goods: 0.3,     // Commodity demand affects ship values
      capital: 0.5,   // Credit availability affects asset purchases
      labor: 0.2,     // Labor costs affect operating expenses
    },
    labor: {
      goods: 0.4,     // Commodity production drives employment
      capital: 0.3,   // Interest rates affect hiring
      assets: 0.2,    // Asset investments create jobs
    },
  };

  constructor(gameState: GameState) {
    this.gameState = gameState;
    this.initializeMarkets();
  }

  private initializeMarkets(): void {
    this.initializeGoodsMarket();
    this.initializeCapitalMarket();
    this.initializeAssetsMarket();
    this.initializeLaborMarket();
  }

  private initializeGoodsMarket(): void {
    const goodsMarket = this.gameState.markets.goods;
    
    Object.keys(this.COMMODITY_BASE_PRICES).forEach(commodity => {
      const basePrice = this.COMMODITY_BASE_PRICES[commodity as CommodityType];
      const volatility = this.VOLATILITY_BASE * (0.5 + Math.random());
      
      goodsMarket.prices[commodity] = basePrice * (0.8 + Math.random() * 0.4);
      goodsMarket.trends[commodity] = (Math.random() - 0.5) * 0.1;
      goodsMarket.volatility[commodity] = volatility;
      goodsMarket.volume[commodity] = 1000 + Math.random() * 5000;
    });
  }

  private initializeCapitalMarket(): void {
    const capitalMarket = this.gameState.markets.capital;
    
    capitalMarket.prices['interest_rate'] = 0.03 + Math.random() * 0.05;
    capitalMarket.prices['credit_availability'] = 0.7 + Math.random() * 0.25;
    capitalMarket.prices['investment_confidence'] = 0.6 + Math.random() * 0.3;
    
    capitalMarket.trends['interest_rate'] = (Math.random() - 0.5) * 0.002;
    capitalMarket.trends['credit_availability'] = (Math.random() - 0.5) * 0.02;
    capitalMarket.trends['investment_confidence'] = (Math.random() - 0.5) * 0.03;
    
    capitalMarket.volatility['interest_rate'] = 0.001;
    capitalMarket.volatility['credit_availability'] = 0.01;
    capitalMarket.volatility['investment_confidence'] = 0.02;
    
    capitalMarket.volume['lending'] = 50000000 + Math.random() * 200000000;
    capitalMarket.volume['borrowing'] = 45000000 + Math.random() * 180000000;
  }

  private initializeAssetsMarket(): void {
    const assetsMarket = this.gameState.markets.assets;
    
    const shipTypes = ['bulk_carrier', 'container_ship', 'tanker', 'general_cargo', 'roro', 'refrigerated', 'heavy_lift'];
    
    shipTypes.forEach(shipType => {
      const basePrice = this.getShipBasePrice(shipType);
      assetsMarket.prices[shipType] = basePrice * (0.85 + Math.random() * 0.3);
      assetsMarket.trends[shipType] = (Math.random() - 0.5) * 0.05;
      assetsMarket.volatility[shipType] = 0.02 + Math.random() * 0.03;
      assetsMarket.volume[shipType] = 10 + Math.random() * 50;
    });

    assetsMarket.prices['warehouse_small'] = 500000 + Math.random() * 200000;
    assetsMarket.prices['warehouse_large'] = 2000000 + Math.random() * 1000000;
    assetsMarket.prices['port_facilities'] = 10000000 + Math.random() * 5000000;
  }

  private initializeLaborMarket(): void {
    const laborMarket = this.gameState.markets.labor;
    
    const specializations = ['navigation', 'engineering', 'logistics', 'finance', 'ai_specialist'];
    
    specializations.forEach(spec => {
      laborMarket.prices[spec] = 40000 + Math.random() * 60000; // Annual salary
      laborMarket.trends[spec] = (Math.random() - 0.5) * 0.1;
      laborMarket.volatility[spec] = 0.02 + Math.random() * 0.03;
      laborMarket.volume[spec] = 100 + Math.random() * 500; // Available workers
    });
    
    laborMarket.prices['general_crew'] = 25000 + Math.random() * 15000;
    laborMarket.prices['captain'] = 80000 + Math.random() * 40000;
    laborMarket.prices['port_worker'] = 35000 + Math.random() * 15000;
  }

  private getShipBasePrice(shipType: string): number {
    const basePrices: Record<string, number> = {
      bulk_carrier: 25000000,
      container_ship: 50000000,
      tanker: 40000000,
      general_cargo: 15000000,
      roro: 35000000,
      refrigerated: 45000000,
      heavy_lift: 60000000,
    };
    return basePrices[shipType] || 30000000;
  }

  public update(deltaTime: number): void {
    this.updateInterval += deltaTime;
    
    if (this.updateInterval >= this.UPDATE_FREQUENCY) {
      this.updateMarketPrices();
      this.applyMarketInterconnections();
      this.processEconomicEvents();
      this.calculateSupplyDemand();
      this.updateAIMarketImpact();
      
      this.updateInterval = 0;
    }
  }

  private updateMarketPrices(): void {
    Object.values(this.gameState.markets).forEach(market => {
      Object.keys(market.prices).forEach(item => {
        const currentPrice = market.prices[item];
        const trend = market.trends[item] || 0;
        const volatility = market.volatility[item] || 0.02;
        
        // Apply trend
        let newPrice = currentPrice * (1 + trend);
        
        // Add random volatility
        const randomChange = (Math.random() - 0.5) * volatility * 2;
        newPrice *= (1 + randomChange);
        
        // Prevent negative prices and extreme values
        newPrice = Math.max(newPrice, currentPrice * 0.5);
        newPrice = Math.min(newPrice, currentPrice * 2.0);
        
        market.prices[item] = newPrice;
        
        // Decay trends toward zero
        market.trends[item] = trend * this.TREND_DECAY;
      });
    });
  }

  private applyMarketInterconnections(): void {
    const marketTypes: MarketType[] = ['goods', 'capital', 'assets', 'labor'];
    
    marketTypes.forEach(sourceType => {
      const sourceMarket = this.gameState.markets[sourceType];
      const interconnections = this.MARKET_INTERCONNECTIONS[sourceType];
      
      Object.entries(interconnections).forEach(([targetType, influence]) => {
        const targetMarket = this.gameState.markets[targetType as MarketType];
        
        // Calculate average trend from source market
        const sourceTrends = Object.values(sourceMarket.trends);
        const avgSourceTrend = sourceTrends.reduce((sum, trend) => sum + trend, 0) / sourceTrends.length;
        
        // Apply influence to target market trends
        Object.keys(targetMarket.trends).forEach(item => {
          const currentTrend = targetMarket.trends[item];
          const influenceAmount = avgSourceTrend * influence * 0.1;
          targetMarket.trends[item] = currentTrend + influenceAmount;
        });
      });
    });
  }

  private processEconomicEvents(): void {
    // Random economic events
    if (Math.random() < 0.01) { // 1% chance per update
      this.generateRandomEvent();
    }
    
    // Process existing events
    this.gameState.world.economicEvents = this.gameState.world.economicEvents.filter(event => {
      event.duration -= this.UPDATE_FREQUENCY;
      
      if (event.duration > 0) {
        this.applyEventEffects(event);
        return true;
      }
      
      return false;
    });
  }

  private generateRandomEvent(): void {
    const events = [
      {
        type: 'oil_crisis',
        title: 'Oil Supply Disruption',
        description: 'Geopolitical tensions disrupt oil supplies, driving up energy costs.',
        effects: { oil: 0.3, chemicals: 0.15 },
        duration: 30,
        severity: 0.8,
      },
      {
        type: 'tech_boom',
        title: 'Technology Sector Surge',
        description: 'New innovations drive demand for electronics and rare materials.',
        effects: { electronics: 0.25, machinery: 0.2 },
        duration: 45,
        severity: 0.6,
      },
      {
        type: 'harvest_season',
        title: 'Bumper Crop Harvest',
        description: 'Excellent weather conditions lead to record agricultural yields.',
        effects: { grain: -0.2 },
        duration: 20,
        severity: 0.5,
      },
      {
        type: 'trade_war',
        title: 'Trade Restrictions Imposed',
        description: 'New tariffs and trade barriers affect international commerce.',
        effects: { steel: 0.15, textiles: 0.2, electronics: 0.1 },
        duration: 60,
        severity: 0.9,
      },
      {
        type: 'port_strike',
        title: 'Major Port Workers Strike',
        description: 'Labor disputes cause significant delays at key shipping hubs.',
        effects: { general_cargo: 0.1, bulk_carrier: 0.15 },
        duration: 15,
        severity: 0.7,
      },
    ];
    
    const event = events[Math.floor(Math.random() * events.length)];
    const eventWithId = {
      ...event,
      id: `event_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    };
    
    this.gameState.world.economicEvents.push(eventWithId as EconomicEvent);
  }

  private applyEventEffects(event: EconomicEvent): void {
    Object.entries(event.effects).forEach(([item, effect]) => {
      // Apply to goods market
      if (this.gameState.markets.goods.prices[item] !== undefined) {
        const currentTrend = this.gameState.markets.goods.trends[item] || 0;
        this.gameState.markets.goods.trends[item] = currentTrend + (effect * event.severity * 0.01);
      }
      
      // Apply to assets market (ships)
      if (this.gameState.markets.assets.prices[item] !== undefined) {
        const currentTrend = this.gameState.markets.assets.trends[item] || 0;
        this.gameState.markets.assets.trends[item] = currentTrend + (effect * event.severity * 0.01);
      }
    });
  }

  private calculateSupplyDemand(): void {
    const ports = PortData.getAllPorts();
    const goodsMarket = this.gameState.markets.goods;
    
    Object.keys(this.COMMODITY_BASE_PRICES).forEach(commodity => {
      const commodityType = commodity as CommodityType;
      
      // Calculate global supply and demand
      let totalSupply = 0;
      let totalDemand = 0;
      
      ports.forEach(port => {
        totalSupply += port.supplyData[commodityType] || 0;
        totalDemand += port.demandData[commodityType] || 0;
      });
      
      // Apply supply/demand pressure to price trends
      const supplyDemandRatio = totalSupply / (totalDemand + 0.1); // Avoid division by zero
      const pressureEffect = (1 / supplyDemandRatio - 1) * 0.05;
      
      const currentTrend = goodsMarket.trends[commodity] || 0;
      goodsMarket.trends[commodity] = currentTrend + pressureEffect;
      
      // Update volume based on activity
      goodsMarket.volume[commodity] = (totalSupply + totalDemand) * 100;
    });
  }

  private updateAIMarketImpact(): void {
    const singularityProgress = this.gameState.singularityProgress;
    const aiImpact = singularityProgress.progress * 0.1;
    
    // AI systems increasingly manipulate markets
    if (singularityProgress.phase !== 'early_automation') {
      Object.values(this.gameState.markets).forEach(market => {
        Object.keys(market.trends).forEach(item => {
          // AI creates artificial trends and volatility
          const aiManipulation = (Math.random() - 0.5) * aiImpact * 0.02;
          market.trends[item] = (market.trends[item] || 0) + aiManipulation;
          
          // Increase volatility as AI systems compete
          market.volatility[item] = (market.volatility[item] || 0.02) * (1 + aiImpact * 0.5);
        });
      });
    }
  }

  public getMarketSummary(): Record<MarketType, any> {
    return Object.fromEntries(
      Object.entries(this.gameState.markets).map(([type, market]) => [
        type,
        {
          avgPrice: this.calculateAveragePrice(market),
          avgTrend: this.calculateAverageTrend(market),
          totalVolume: this.calculateTotalVolume(market),
          volatility: this.calculateAverageVolatility(market),
        }
      ])
    ) as Record<MarketType, any>;
  }

  private calculateAveragePrice(market: Market): number {
    const prices = Object.values(market.prices);
    return prices.reduce((sum, price) => sum + price, 0) / prices.length;
  }

  private calculateAverageTrend(market: Market): number {
    const trends = Object.values(market.trends);
    return trends.reduce((sum, trend) => sum + trend, 0) / trends.length;
  }

  private calculateTotalVolume(market: Market): number {
    return Object.values(market.volume).reduce((sum, volume) => sum + volume, 0);
  }

  private calculateAverageVolatility(market: Market): number {
    const volatilities = Object.values(market.volatility);
    return volatilities.reduce((sum, vol) => sum + vol, 0) / volatilities.length;
  }

  public getCommodityPrice(commodity: CommodityType): number {
    return this.gameState.markets.goods.prices[commodity] || 0;
  }

  public getShipPrice(shipType: string): number {
    return this.gameState.markets.assets.prices[shipType] || 0;
  }

  public getInterestRate(): number {
    return this.gameState.markets.capital.prices['interest_rate'] || 0.05;
  }

  public getWorkerCost(specialization: string): number {
    return this.gameState.markets.labor.prices[specialization] || 50000;
  }

  public setProgressionSystem(progressionSystem: ProgressionSystem): void {
    this.progressionSystem = progressionSystem;
  }

  public processTrade(ship: Ship, soldCargo: Cargo[], revenue: number, cost: number): void {
    const profit = revenue - cost;
    const profitMargin = cost > 0 ? (profit / cost) : 0;

    // Grant XP for completing the trade
    if (this.progressionSystem) {
      this.progressionSystem.grantExperience('complete_trade', {
        profit_margin: profitMargin,
        distance: ship.destination ? this.calculateTradeDistance(ship) : 1
      });

      // Additional XP for profitable trades
      if (profit > 0) {
        this.progressionSystem.grantExperience('profitable_trade', {
          profit_amount: profit
        });
      }

      // Check for arbitrage opportunities
      if (profitMargin > 0.5) { // 50% profit margin
        this.progressionSystem.grantExperience('arbitrage_success');
      }

      // Milestone checks
      const totalCash = this.gameState.player.cash;
      if (totalCash >= 1000000 && totalCash - profit < 1000000) {
        this.progressionSystem.grantExperience('first_million');
      }
    }
  }

  private calculateTradeDistance(ship: Ship): number {
    // Simplified distance calculation based on current location
    // In a real implementation, this would track the actual route taken
    return Math.random() * 10 + 1; // Random distance between 1-11
  }

  public analyzeMarket(marketType: MarketType): void {
    // Grant XP for market analysis
    if (this.progressionSystem) {
      this.progressionSystem.grantExperience('market_analysis');
    }
  }

  public predictPrice(commodity: CommodityType, prediction: number): void {
    const actualPrice = this.getCommodityPrice(commodity);
    const accuracy = 1 - Math.abs(prediction - actualPrice) / actualPrice;

    if (this.progressionSystem && accuracy > 0.8) {
      this.progressionSystem.grantExperience('price_prediction', {
        accuracy: accuracy
      });
    }
  }
}