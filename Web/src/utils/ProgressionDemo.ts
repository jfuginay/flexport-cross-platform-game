import { GameEngine } from '@/core/GameEngine';
import { ShipType } from '@/types';

/**
 * Demo utility to showcase the progression system
 * This can be called from the browser console for testing
 */
export class ProgressionDemo {
  private gameEngine: any;

  constructor(gameEngine: any) {
    this.gameEngine = gameEngine;
  }

  /**
   * Simulate a basic trade to earn XP
   */
  public simulateTrade(): void {
    const economicSystem = this.gameEngine.systems.get('economic');
    const shipSystem = this.gameEngine.systems.get('ship');
    const progressionSystem = this.gameEngine.systems.get('progression');

    if (!economicSystem || !shipSystem || !progressionSystem) {
      console.error('Required systems not found');
      return;
    }

    // Get the first ship or create one
    let ship = this.gameEngine.gameState.player.ships[0];
    if (!ship) {
      try {
        ship = shipSystem.createShip('general_cargo', 'Demo Trader', 'singapore');
        console.log('🚢 Created demo ship:', ship.name);
      } catch (error) {
        console.error('Failed to create ship:', error);
        return;
      }
    }

    // Simulate cargo
    const mockCargo = [
      { type: 'steel', quantity: 1000, value: 850000, destination: 'shanghai' },
      { type: 'electronics', quantity: 500, value: 600000, destination: 'shanghai' }
    ];

    // Calculate trade values
    const revenue = mockCargo.reduce((sum, cargo) => sum + cargo.value, 0);
    const cost = revenue * 0.7; // 30% profit margin

    // Process the trade
    economicSystem.processTrade(ship, mockCargo, revenue, cost);

    const profit = revenue - cost;
    console.log(`💰 Trade completed! Revenue: $${revenue.toLocaleString()}, Profit: $${profit.toLocaleString()}`);
    
    // Show current progression
    this.showProgressionStatus();
  }

  /**
   * Grant bonus XP for testing
   */
  public grantBonusXP(amount: number = 500): void {
    const progressionSystem = this.gameEngine.systems.get('progression');
    if (!progressionSystem) return;

    // We'll simulate this by doing multiple market analyses
    const iterations = Math.floor(amount / 30); // Market analysis gives 30 XP
    
    for (let i = 0; i < iterations; i++) {
      progressionSystem.grantExperience('market_analysis');
    }

    console.log(`🎁 Granted approximately ${iterations * 30} bonus XP`);
    this.showProgressionStatus();
  }

  /**
   * Show current progression status
   */
  public showProgressionStatus(): void {
    const player = this.gameEngine.gameState.player;
    const progressionSystem = this.gameEngine.systems.get('progression');
    
    if (!progressionSystem) return;

    const progress = progressionSystem.getProgressToNextLevel();
    const achievementStats = progressionSystem.getAchievementStats();

    console.log(`
📊 PROGRESSION STATUS
====================
👤 Player: ${player.name}
🎯 Level: ${progress.currentLevel}
⭐ XP: ${progress.currentXP.toLocaleString()} / ${progress.requiredXP.toLocaleString()} (${progress.progress.toFixed(1)}%)
💰 Cash: $${player.cash.toLocaleString()}
🚢 Ships: ${player.ships.length}
📈 Routes: ${player.tradeRoutes.length}
🏆 Achievements: ${achievementStats.unlocked} / ${achievementStats.total} (${achievementStats.percentage.toFixed(1)}%)
    `);

    // Show next unlocks
    const nextUnlocks = progressionSystem.getUnlocksForLevel(progress.nextLevel);
    if (nextUnlocks.length > 0) {
      console.log(`🔓 Next level unlocks: ${nextUnlocks.join(', ')}`);
    }
  }

  /**
   * Fast level up for testing
   */
  public fastLevelUp(): void {
    const progressionSystem = this.gameEngine.systems.get('progression');
    if (!progressionSystem) return;

    const progress = progressionSystem.getProgressToNextLevel();
    const xpNeeded = progress.requiredXP - progress.currentXP;
    
    if (xpNeeded > 0) {
      this.grantBonusXP(xpNeeded + 100); // Grant enough XP to level up
    }
  }

  /**
   * Unlock specific achievement
   */
  public unlockAchievement(achievementId: string): void {
    const achievement = this.gameEngine.gameState.player.achievements.find(
      a => a.id === achievementId
    );

    if (!achievement) {
      console.error(`Achievement '${achievementId}' not found`);
      this.listAchievements();
      return;
    }

    if (achievement.unlocked) {
      console.log(`✅ Achievement '${achievement.name}' is already unlocked`);
      return;
    }

    achievement.progress = achievement.maxProgress;
    achievement.unlocked = true;

    console.log(`🏆 Unlocked achievement: ${achievement.name}`);
  }

  /**
   * List all achievements
   */
  public listAchievements(): void {
    const achievements = this.gameEngine.gameState.player.achievements;
    
    console.log('\n🏆 ACHIEVEMENTS\n================');
    achievements.forEach(achievement => {
      const status = achievement.unlocked ? '✅' : '⬜';
      const progress = achievement.unlocked 
        ? 'COMPLETE' 
        : `${achievement.progress}/${achievement.maxProgress}`;
      
      console.log(`${status} ${achievement.id}: ${achievement.name} (${progress})`);
      console.log(`   ${achievement.description}\n`);
    });
  }

  /**
   * Create a fleet of ships
   */
  public createFleet(count: number = 5): void {
    const shipSystem = this.gameEngine.systems.get('ship');
    if (!shipSystem) return;

    const shipTypes: ShipType[] = ['general_cargo', 'bulk_carrier'];
    const ports = ['singapore', 'shanghai', 'rotterdam', 'losangeles', 'newyork'];
    
    for (let i = 0; i < count; i++) {
      const shipType = shipTypes[i % shipTypes.length];
      const homePort = ports[i % ports.length];
      const shipName = `Fleet Ship ${i + 1}`;
      
      try {
        shipSystem.createShip(shipType, shipName, homePort);
        console.log(`🚢 Created ${shipType} named '${shipName}' at ${homePort}`);
      } catch (error) {
        console.error(`Failed to create ship: ${error.message}`);
      }
    }

    this.showProgressionStatus();
  }

  /**
   * Simulate multiple trades
   */
  public simulateMultipleTrades(count: number = 10): void {
    console.log(`🔄 Simulating ${count} trades...`);
    
    for (let i = 0; i < count; i++) {
      setTimeout(() => {
        this.simulateTrade();
        if (i === count - 1) {
          console.log('✅ All trades completed!');
          this.showProgressionStatus();
        }
      }, i * 500); // Space out trades to see the progression
    }
  }

  /**
   * Reset progression (for testing)
   */
  public resetProgression(): void {
    const player = this.gameEngine.gameState.player;
    player.level = 1;
    player.experience = 0;
    player.achievements.forEach(a => {
      a.unlocked = false;
      a.progress = 0;
    });
    
    console.log('🔄 Progression reset to level 1');
    this.showProgressionStatus();
  }
}

// Make it available globally for console testing
if (typeof window !== 'undefined') {
  (window as any).ProgressionDemo = ProgressionDemo;
  
  // Add console helper
  (window as any).startProgressionDemo = () => {
    const gameEngine = (window as any).gameEngine;
    if (!gameEngine) {
      console.error('Game engine not found. Make sure the game is loaded.');
      return;
    }
    
    const demo = new ProgressionDemo(gameEngine);
    (window as any).progressionDemo = demo;
    
    console.log(`
🎮 PROGRESSION DEMO LOADED
=========================
Available commands:
  progressionDemo.simulateTrade() - Simulate a trade to earn XP
  progressionDemo.grantBonusXP(amount) - Grant bonus XP
  progressionDemo.showProgressionStatus() - Show current status
  progressionDemo.fastLevelUp() - Level up quickly
  progressionDemo.listAchievements() - List all achievements
  progressionDemo.unlockAchievement(id) - Unlock specific achievement
  progressionDemo.createFleet(count) - Create multiple ships
  progressionDemo.simulateMultipleTrades(count) - Run multiple trades
  progressionDemo.resetProgression() - Reset to level 1
    `);
    
    return demo;
  };
}