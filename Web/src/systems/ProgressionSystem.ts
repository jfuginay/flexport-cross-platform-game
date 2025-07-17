import { GameState, PlayerState, Achievement, Ship, TradeRoute, CommodityType } from '@/types';
import { useGameStore } from '@/core/GameStateStore';

interface LevelRequirement {
  level: number;
  experienceRequired: number;
  unlocks: string[];
  rewards: {
    cash?: number;
    researchPoints?: number;
    shipSlots?: number;
    routeSlots?: number;
  };
}

interface ExperienceReward {
  action: string;
  baseXP: number;
  multipliers?: Record<string, number>;
}

export class ProgressionSystem {
  private gameState: GameState;
  private levelRequirements: LevelRequirement[] = [];
  private experienceRewards: ExperienceReward[] = [];
  private achievementProgress: Map<string, number> = new Map();
  
  private readonly MAX_LEVEL = 50;
  private readonly BASE_XP_REQUIREMENT = 100;
  private readonly XP_GROWTH_RATE = 1.15;

  constructor(gameState: GameState) {
    this.gameState = gameState;
    this.initializeLevelRequirements();
    this.initializeExperienceRewards();
    this.initializeAchievements();
  }

  private initializeLevelRequirements(): void {
    for (let level = 1; level <= this.MAX_LEVEL; level++) {
      const experienceRequired = Math.floor(
        this.BASE_XP_REQUIREMENT * Math.pow(this.XP_GROWTH_RATE, level - 1)
      );

      const unlocks: string[] = [];
      const rewards: LevelRequirement['rewards'] = {};

      // Define level-specific unlocks and rewards
      if (level === 2) unlocks.push('basic_trade_routes');
      if (level === 3) unlocks.push('bulk_carrier_ships');
      if (level === 5) {
        unlocks.push('container_ships', 'advanced_navigation');
        rewards.researchPoints = 5;
      }
      if (level === 8) {
        unlocks.push('tanker_ships', 'fuel_efficiency_upgrade');
        rewards.shipSlots = 1;
      }
      if (level === 10) {
        unlocks.push('market_analytics', 'crew_management');
        rewards.cash = 500000;
        rewards.researchPoints = 10;
      }
      if (level === 12) unlocks.push('general_cargo_ships');
      if (level === 15) {
        unlocks.push('trade_route_optimization', 'roro_ships');
        rewards.routeSlots = 2;
        rewards.researchPoints = 15;
      }
      if (level === 18) unlocks.push('refrigerated_ships', 'advanced_cargo_handling');
      if (level === 20) {
        unlocks.push('fleet_management', 'automated_trading');
        rewards.cash = 1000000;
        rewards.shipSlots = 2;
      }
      if (level === 22) unlocks.push('heavy_lift_ships');
      if (level === 25) {
        unlocks.push('ai_assisted_navigation', 'predictive_maintenance');
        rewards.researchPoints = 25;
        rewards.routeSlots = 3;
      }
      if (level === 30) {
        unlocks.push('global_trade_network', 'market_manipulation');
        rewards.cash = 2500000;
        rewards.shipSlots = 3;
      }
      if (level === 35) {
        unlocks.push('quantum_logistics', 'hyperloop_integration');
        rewards.researchPoints = 50;
      }
      if (level === 40) {
        unlocks.push('autonomous_fleet_operations', 'supply_chain_ai');
        rewards.cash = 5000000;
        rewards.shipSlots = 5;
      }
      if (level === 45) {
        unlocks.push('singularity_resistance', 'market_dominance');
        rewards.researchPoints = 100;
      }
      if (level === 50) {
        unlocks.push('logistics_mastery', 'infinite_scalability');
        rewards.cash = 10000000;
        rewards.shipSlots = 10;
        rewards.routeSlots = 10;
      }

      // Every 5 levels, grant bonus rewards
      if (level % 5 === 0) {
        rewards.cash = (rewards.cash || 0) + level * 50000;
        rewards.researchPoints = (rewards.researchPoints || 0) + level / 2;
      }

      this.levelRequirements.push({
        level,
        experienceRequired,
        unlocks,
        rewards
      });
    }
  }

  private initializeExperienceRewards(): void {
    this.experienceRewards = [
      // Trading XP
      { action: 'complete_trade', baseXP: 50, multipliers: { profit_margin: 2.0, distance: 1.5 } },
      { action: 'profitable_trade', baseXP: 100, multipliers: { profit_amount: 0.001 } },
      { action: 'establish_route', baseXP: 200 },
      { action: 'optimize_route', baseXP: 150 },
      
      // Fleet Management XP
      { action: 'purchase_ship', baseXP: 300, multipliers: { ship_tier: 1.5 } },
      { action: 'upgrade_ship', baseXP: 100 },
      { action: 'maintain_fleet', baseXP: 25 },
      { action: 'crew_hire', baseXP: 50 },
      
      // Market Activities XP
      { action: 'market_analysis', baseXP: 30 },
      { action: 'price_prediction', baseXP: 75, multipliers: { accuracy: 2.0 } },
      { action: 'arbitrage_success', baseXP: 250 },
      
      // Strategic Actions XP
      { action: 'port_expansion', baseXP: 500 },
      { action: 'research_complete', baseXP: 150, multipliers: { research_tier: 1.5 } },
      { action: 'compete_ai_win', baseXP: 400 },
      
      // Milestone XP
      { action: 'first_million', baseXP: 1000 },
      { action: 'fleet_size_milestone', baseXP: 500, multipliers: { fleet_size: 10 } },
      { action: 'trade_volume_milestone', baseXP: 750, multipliers: { volume: 0.0001 } },
      
      // Daily/Recurring XP
      { action: 'daily_login', baseXP: 100 },
      { action: 'weekly_profit', baseXP: 500, multipliers: { profit_percentage: 1.5 } },
      { action: 'monthly_dominance', baseXP: 2000 }
    ];
  }

  private initializeAchievements(): void {
    const achievements: Achievement[] = [
      // Trading Achievements
      {
        id: 'first_trade',
        name: 'First Steps',
        description: 'Complete your first trade',
        unlocked: false,
        progress: 0,
        maxProgress: 1
      },
      {
        id: 'trade_master',
        name: 'Trade Master',
        description: 'Complete 100 successful trades',
        unlocked: false,
        progress: 0,
        maxProgress: 100
      },
      {
        id: 'profit_king',
        name: 'Profit King',
        description: 'Earn $10 million in total profit',
        unlocked: false,
        progress: 0,
        maxProgress: 10000000
      },
      
      // Fleet Achievements
      {
        id: 'fleet_builder',
        name: 'Fleet Builder',
        description: 'Own 10 ships',
        unlocked: false,
        progress: 0,
        maxProgress: 10
      },
      {
        id: 'diverse_fleet',
        name: 'Diverse Operations',
        description: 'Own one ship of each type',
        unlocked: false,
        progress: 0,
        maxProgress: 7
      },
      {
        id: 'fleet_admiral',
        name: 'Fleet Admiral',
        description: 'Command 50 ships',
        unlocked: false,
        progress: 0,
        maxProgress: 50
      },
      
      // Route Achievements
      {
        id: 'route_planner',
        name: 'Route Planner',
        description: 'Establish 5 trade routes',
        unlocked: false,
        progress: 0,
        maxProgress: 5
      },
      {
        id: 'global_network',
        name: 'Global Network',
        description: 'Have routes connecting all continents',
        unlocked: false,
        progress: 0,
        maxProgress: 7
      },
      
      // Market Achievements
      {
        id: 'market_watcher',
        name: 'Market Watcher',
        description: 'Track market trends for 7 days',
        unlocked: false,
        progress: 0,
        maxProgress: 7
      },
      {
        id: 'arbitrage_expert',
        name: 'Arbitrage Expert',
        description: 'Profit from 50 arbitrage opportunities',
        unlocked: false,
        progress: 0,
        maxProgress: 50
      },
      
      // Progression Achievements
      {
        id: 'level_10',
        name: 'Rising Star',
        description: 'Reach level 10',
        unlocked: false,
        progress: 0,
        maxProgress: 10
      },
      {
        id: 'level_25',
        name: 'Industry Leader',
        description: 'Reach level 25',
        unlocked: false,
        progress: 0,
        maxProgress: 25
      },
      {
        id: 'level_50',
        name: 'Logistics Legend',
        description: 'Reach level 50',
        unlocked: false,
        progress: 0,
        maxProgress: 50
      },
      
      // Special Achievements
      {
        id: 'singularity_survivor',
        name: 'Singularity Survivor',
        description: 'Survive an AI singularity event',
        unlocked: false,
        progress: 0,
        maxProgress: 1
      },
      {
        id: 'efficiency_master',
        name: 'Efficiency Master',
        description: 'Achieve 95% fleet efficiency',
        unlocked: false,
        progress: 0,
        maxProgress: 95
      },
      {
        id: 'monopolist',
        name: 'Monopolist',
        description: 'Control 50% of a commodity market',
        unlocked: false,
        progress: 0,
        maxProgress: 50
      }
    ];

    // Update player's achievements if they don't exist
    if (this.gameState.player.achievements.length === 0) {
      this.gameState.player.achievements = achievements;
    }
  }

  public grantExperience(action: string, context?: Record<string, number>): number {
    const reward = this.experienceRewards.find(r => r.action === action);
    if (!reward) return 0;

    let xpGained = reward.baseXP;

    // Apply multipliers based on context
    if (reward.multipliers && context) {
      Object.entries(reward.multipliers).forEach(([key, multiplier]) => {
        if (context[key] !== undefined) {
          xpGained *= (1 + (context[key] * multiplier));
        }
      });
    }

    // Apply level scaling (higher levels get slightly more XP)
    const levelBonus = 1 + (this.gameState.player.level * 0.02);
    xpGained = Math.floor(xpGained * levelBonus);

    // Update player experience
    const previousLevel = this.gameState.player.level;
    this.gameState.player.experience += xpGained;

    // Check for level up
    this.checkLevelUp();

    // Update achievement progress
    this.updateAchievementProgress(action, context);

    // Return XP gained for UI feedback
    return xpGained;
  }

  private checkLevelUp(): void {
    const currentLevel = this.gameState.player.level;
    const currentXP = this.gameState.player.experience;

    // Find the next level requirement
    const nextLevel = this.levelRequirements.find(
      req => req.level === currentLevel + 1
    );

    if (!nextLevel) return;

    // Check if player has enough XP to level up
    if (currentXP >= nextLevel.experienceRequired) {
      this.levelUp(nextLevel);
    }
  }

  private levelUp(levelRequirement: LevelRequirement): void {
    const store = useGameStore.getState();
    
    // Update player level
    store.updatePlayer({
      level: levelRequirement.level,
      experience: this.gameState.player.experience - levelRequirement.experienceRequired
    });

    // Grant rewards
    const rewards = levelRequirement.rewards;
    if (rewards.cash) {
      store.updatePlayer({
        cash: this.gameState.player.cash + rewards.cash
      });
    }

    if (rewards.researchPoints) {
      store.updatePlayer({
        research: {
          ...this.gameState.player.research,
          availablePoints: this.gameState.player.research.availablePoints + rewards.researchPoints
        }
      });
    }

    // Track unlocks (these would be used by other systems)
    this.applyUnlocks(levelRequirement.unlocks);

    // Grant achievement XP for leveling
    this.grantExperience(`level_${levelRequirement.level}_reached`, {
      level: levelRequirement.level
    });

    // Check for level achievement
    this.updateAchievementProgress('level_reached', { level: levelRequirement.level });

    // Recursive check for multiple level ups
    this.checkLevelUp();
  }

  private applyUnlocks(unlocks: string[]): void {
    // Store unlocks in a way that other systems can check
    // This could be added to the player state or a separate unlocks system
    unlocks.forEach(unlock => {
      console.log(`Unlocked: ${unlock}`);
      // Notify other systems about the unlock
      this.notifyUnlock(unlock);
    });
  }

  private notifyUnlock(unlock: string): void {
    // Create a custom event that other systems can listen to
    const event = new CustomEvent('progression:unlock', {
      detail: { unlock, playerId: this.gameState.player.id }
    });
    window.dispatchEvent(event);
  }

  private updateAchievementProgress(action: string, context?: Record<string, any>): void {
    const achievements = this.gameState.player.achievements;

    achievements.forEach(achievement => {
      if (achievement.unlocked) return;

      let shouldUpdate = false;
      let progressIncrement = 0;

      switch (achievement.id) {
        case 'first_trade':
          if (action === 'complete_trade') {
            shouldUpdate = true;
            progressIncrement = 1;
          }
          break;

        case 'trade_master':
          if (action === 'complete_trade') {
            shouldUpdate = true;
            progressIncrement = 1;
          }
          break;

        case 'profit_king':
          if (action === 'profitable_trade' && context?.profit_amount) {
            shouldUpdate = true;
            progressIncrement = context.profit_amount;
          }
          break;

        case 'fleet_builder':
        case 'fleet_admiral':
          if (action === 'purchase_ship') {
            shouldUpdate = true;
            achievement.progress = this.gameState.player.ships.length;
          }
          break;

        case 'diverse_fleet':
          if (action === 'purchase_ship') {
            const uniqueShipTypes = new Set(
              this.gameState.player.ships.map(ship => ship.type)
            );
            achievement.progress = uniqueShipTypes.size;
            shouldUpdate = true;
          }
          break;

        case 'route_planner':
          if (action === 'establish_route') {
            shouldUpdate = true;
            achievement.progress = this.gameState.player.tradeRoutes.length;
          }
          break;

        case 'level_10':
        case 'level_25':
        case 'level_50':
          if (action === 'level_reached' && context?.level) {
            achievement.progress = context.level;
            shouldUpdate = true;
          }
          break;

        case 'arbitrage_expert':
          if (action === 'arbitrage_success') {
            shouldUpdate = true;
            progressIncrement = 1;
          }
          break;

        case 'efficiency_master':
          if (action === 'fleet_efficiency_check') {
            const avgEfficiency = this.calculateFleetEfficiency();
            achievement.progress = Math.floor(avgEfficiency * 100);
            shouldUpdate = true;
          }
          break;
      }

      if (shouldUpdate) {
        if (progressIncrement > 0) {
          achievement.progress = Math.min(
            achievement.progress + progressIncrement,
            achievement.maxProgress
          );
        }

        // Check if achievement is completed
        if (achievement.progress >= achievement.maxProgress) {
          achievement.unlocked = true;
          achievement.progress = achievement.maxProgress;
          
          // Grant achievement reward XP
          this.grantExperience('achievement_unlocked', {
            rarity: this.getAchievementRarity(achievement.id)
          });

          // Notify about achievement unlock
          this.notifyAchievementUnlock(achievement);
        }
      }
    });
  }

  private calculateFleetEfficiency(): number {
    const ships = this.gameState.player.ships;
    if (ships.length === 0) return 0;

    const totalEfficiency = ships.reduce((sum, ship) => sum + ship.efficiency, 0);
    return totalEfficiency / ships.length;
  }

  private getAchievementRarity(achievementId: string): number {
    // Return a rarity score (1-5) based on achievement difficulty
    const rarityMap: Record<string, number> = {
      'first_trade': 1,
      'trade_master': 2,
      'profit_king': 3,
      'fleet_builder': 2,
      'diverse_fleet': 3,
      'fleet_admiral': 4,
      'route_planner': 2,
      'global_network': 4,
      'market_watcher': 2,
      'arbitrage_expert': 3,
      'level_10': 2,
      'level_25': 3,
      'level_50': 5,
      'singularity_survivor': 5,
      'efficiency_master': 4,
      'monopolist': 5
    };

    return rarityMap[achievementId] || 1;
  }

  private notifyAchievementUnlock(achievement: Achievement): void {
    const event = new CustomEvent('progression:achievement', {
      detail: { achievement, playerId: this.gameState.player.id }
    });
    window.dispatchEvent(event);
  }

  public getProgressToNextLevel(): {
    currentLevel: number;
    nextLevel: number;
    currentXP: number;
    requiredXP: number;
    progress: number;
  } {
    const currentLevel = this.gameState.player.level;
    const currentXP = this.gameState.player.experience;
    
    const nextLevelReq = this.levelRequirements.find(
      req => req.level === currentLevel + 1
    );

    if (!nextLevelReq) {
      // Max level reached
      return {
        currentLevel,
        nextLevel: currentLevel,
        currentXP,
        requiredXP: 0,
        progress: 100
      };
    }

    const progress = (currentXP / nextLevelReq.experienceRequired) * 100;

    return {
      currentLevel,
      nextLevel: nextLevelReq.level,
      currentXP,
      requiredXP: nextLevelReq.experienceRequired,
      progress: Math.min(progress, 100)
    };
  }

  public getUnlocksForLevel(level: number): string[] {
    const levelReq = this.levelRequirements.find(req => req.level === level);
    return levelReq?.unlocks || [];
  }

  public getAvailableUnlocks(): string[] {
    const allUnlocks: string[] = [];
    
    this.levelRequirements
      .filter(req => req.level <= this.gameState.player.level)
      .forEach(req => allUnlocks.push(...req.unlocks));

    return [...new Set(allUnlocks)]; // Remove duplicates
  }

  public isFeatureUnlocked(feature: string): boolean {
    return this.getAvailableUnlocks().includes(feature);
  }

  public update(deltaTime: number): void {
    // Periodic checks and updates
    this.checkFleetEfficiencyAchievement(deltaTime);
    this.checkMarketDominanceAchievement();
    this.checkDailyLogin();
  }

  private checkFleetEfficiencyAchievement(deltaTime: number): void {
    // Check every 10 seconds
    if (Math.random() < deltaTime / 10) {
      this.updateAchievementProgress('fleet_efficiency_check');
    }
  }

  private checkMarketDominanceAchievement(): void {
    // Check market share for monopolist achievement
    const commodityMarketShares = this.calculateCommodityMarketShares();
    
    Object.values(commodityMarketShares).forEach(share => {
      if (share >= 50) {
        const monopolistAchievement = this.gameState.player.achievements.find(
          a => a.id === 'monopolist'
        );
        if (monopolistAchievement && !monopolistAchievement.unlocked) {
          monopolistAchievement.progress = Math.floor(share);
          if (share >= monopolistAchievement.maxProgress) {
            monopolistAchievement.unlocked = true;
            this.notifyAchievementUnlock(monopolistAchievement);
          }
        }
      }
    });
  }

  private calculateCommodityMarketShares(): Record<CommodityType, number> {
    // Simplified market share calculation
    const shares: Partial<Record<CommodityType, number>> = {};
    const playerCargo = this.gameState.player.ships.reduce((total, ship) => {
      ship.cargo.forEach(cargo => {
        shares[cargo.type] = (shares[cargo.type] || 0) + cargo.quantity;
      });
      return total;
    }, 0);

    // Convert to percentages (simplified - in real game would compare to total market)
    Object.keys(shares).forEach(commodity => {
      shares[commodity as CommodityType] = Math.min(
        (shares[commodity as CommodityType]! / 10000) * 100,
        100
      );
    });

    return shares as Record<CommodityType, number>;
  }

  private checkDailyLogin(): void {
    // This would normally check against a stored last login timestamp
    // For now, we'll simulate it with a random check
    if (Math.random() < 0.0001) {
      this.grantExperience('daily_login');
    }
  }

  public getAchievementStats(): {
    total: number;
    unlocked: number;
    percentage: number;
  } {
    const achievements = this.gameState.player.achievements;
    const unlocked = achievements.filter(a => a.unlocked).length;
    
    return {
      total: achievements.length,
      unlocked,
      percentage: (unlocked / achievements.length) * 100
    };
  }
}