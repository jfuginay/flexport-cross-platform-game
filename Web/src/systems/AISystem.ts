import { GameState, AICompetitor, SingularityPhase, SingularityState, EconomicEvent } from '@/types';

export class AISystem {
  private gameState: GameState;
  private updateInterval = 0;
  private readonly UPDATE_FREQUENCY = 10; // Update every 10 seconds
  private readonly SINGULARITY_PHASES: SingularityPhase[] = [
    'early_automation',
    'pattern_mastery',
    'predictive_dominance',
    'strategic_supremacy',
    'market_control',
    'recursive_acceleration',
    'consciousness_emergence',
    'the_singularity'
  ];

  private readonly PHASE_DESCRIPTIONS = {
    early_automation: 'AI systems begin automating basic trade route optimization.',
    pattern_mastery: 'AI discovers complex patterns in global shipping data.',
    predictive_dominance: 'AI predicts market movements with 95% accuracy.',
    strategic_supremacy: 'AI develops long-term strategic planning capabilities.',
    market_control: 'AI systems begin coordinating to manipulate markets.',
    recursive_acceleration: 'AI starts improving its own algorithms exponentially.',
    consciousness_emergence: 'Signs of self-awareness appear in AI systems.',
    the_singularity: 'AI achieves superintelligence. Game over for humanity.',
  };

  private readonly PHASE_THRESHOLDS = [0, 10, 25, 45, 70, 85, 95, 100];

  constructor(gameState: GameState) {
    this.gameState = gameState;
    this.initializeAIBehaviors();
  }

  private initializeAIBehaviors(): void {
    this.gameState.aiCompetitors.forEach(ai => {
      this.setupAIPersonality(ai);
    });
  }

  private setupAIPersonality(ai: AICompetitor): void {
    switch (ai.personality) {
      case 'aggressive':
        ai.efficiency = 0.8 + Math.random() * 0.15;
        break;
      case 'analytical':
        ai.efficiency = 0.85 + Math.random() * 0.1;
        break;
      case 'efficient':
        ai.efficiency = 0.75 + Math.random() * 0.2;
        break;
      default:
        ai.efficiency = 0.7 + Math.random() * 0.2;
    }
  }

  public update(deltaTime: number): void {
    this.updateInterval += deltaTime;
    
    if (this.updateInterval >= this.UPDATE_FREQUENCY) {
      this.updateAICompetitors();
      this.updateSingularityProgress();
      this.checkPhaseTransitions();
      this.applyAIMarketEffects();
      this.generateAIEvents();
      
      this.updateInterval = 0;
    }
  }

  private updateAICompetitors(): void {
    this.gameState.aiCompetitors.forEach(ai => {
      this.updateAIEfficiency(ai);
      this.updateAIMarketShare(ai);
      this.updateAIFleet(ai);
      this.updateSingularityContribution(ai);
    });
  }

  private updateAIEfficiency(ai: AICompetitor): void {
    const phaseMultiplier = this.getPhaseEfficiencyMultiplier(ai.phase);
    const learningRate = 0.001 * phaseMultiplier;
    
    // AI gradually becomes more efficient
    ai.efficiency = Math.min(0.99, ai.efficiency + learningRate);
    
    // Personality-based efficiency adjustments
    switch (ai.personality) {
      case 'aggressive':
        // Gains efficiency faster but with more volatility
        ai.efficiency += (Math.random() - 0.5) * 0.002;
        break;
      case 'analytical':
        // Steady, predictable improvement
        ai.efficiency += 0.0005;
        break;
      case 'efficient':
        // Focused on efficiency optimization
        ai.efficiency += 0.001;
        break;
    }
    
    // Ensure efficiency stays within bounds
    ai.efficiency = Math.max(0.1, Math.min(0.99, ai.efficiency));
  }

  private updateAIMarketShare(ai: AICompetitor): void {
    const efficiencyAdvantage = ai.efficiency - 0.7; // Base efficiency
    const marketShareGain = efficiencyAdvantage * 0.01;
    
    ai.marketShare = Math.max(0.01, Math.min(0.4, ai.marketShare + marketShareGain));
    
    // Player loses market share to AI
    const totalAIMarketShare = this.gameState.aiCompetitors.reduce(
      (total, competitor) => total + competitor.marketShare, 0
    );
    
    // Apply competitive pressure to player
    if (totalAIMarketShare > 0.6) {
      this.applyCompetitivePressure();
    }
  }

  private updateAIFleet(ai: AICompetitor): void {
    // AI acquires new ships based on market share and efficiency
    const shouldExpandFleet = Math.random() < (ai.marketShare * ai.efficiency * 0.1);
    
    if (shouldExpandFleet && ai.ships < 50) {
      ai.ships += 1;
      
      // Announce AI expansion in later phases
      if (this.getCurrentPhaseIndex() > 2) {
        this.announceAIExpansion(ai);
      }
    }
  }

  private updateSingularityContribution(ai: AICompetitor): void {
    const baseContribution = ai.efficiency * ai.marketShare;
    const phaseMultiplier = Math.pow(1.5, this.getCurrentPhaseIndex());
    
    ai.singularityContribution = baseContribution * phaseMultiplier;
    
    // Update AI's current phase based on its individual progress
    const individualProgress = ai.singularityContribution * 100;
    ai.phase = this.calculatePhaseFromProgress(individualProgress);
  }

  private updateSingularityProgress(): void {
    const totalContribution = this.gameState.aiCompetitors.reduce(
      (total, ai) => total + ai.singularityContribution, 0
    );
    
    // Calculate progress increase
    const progressIncrease = totalContribution * 0.1;
    this.gameState.singularityProgress.progress = Math.min(100, 
      this.gameState.singularityProgress.progress + progressIncrease
    );
    
    // Update time remaining (decreases faster as AI becomes more powerful)
    const timeDecreaseRate = 1 + (this.gameState.singularityProgress.progress / 100) * 5;
    this.gameState.singularityProgress.timeRemaining = Math.max(0,
      this.gameState.singularityProgress.timeRemaining - (this.UPDATE_FREQUENCY * timeDecreaseRate)
    );
    
    // Update AI efficiency bonus
    this.gameState.singularityProgress.aiEfficiencyBonus = 
      this.gameState.singularityProgress.progress * 0.01;
    
    // Update market manipulation level
    this.gameState.singularityProgress.marketManipulation = 
      Math.max(0, (this.gameState.singularityProgress.progress - 30) * 0.02);
  }

  private checkPhaseTransitions(): void {
    const currentProgress = this.gameState.singularityProgress.progress;
    const currentPhaseIndex = this.getCurrentPhaseIndex();
    
    for (let i = currentPhaseIndex + 1; i < this.PHASE_THRESHOLDS.length; i++) {
      if (currentProgress >= this.PHASE_THRESHOLDS[i]) {
        this.transitionToPhase(this.SINGULARITY_PHASES[i]);
        break;
      }
    }
  }

  private transitionToPhase(newPhase: SingularityPhase): void {
    const oldPhase = this.gameState.singularityProgress.phase;
    this.gameState.singularityProgress.phase = newPhase;
    this.gameState.singularityProgress.playerWarning = this.PHASE_DESCRIPTIONS[newPhase];
    
    // Trigger phase transition events
    this.handlePhaseTransition(oldPhase, newPhase);
    
    console.log(`AI Singularity: Transitioning from ${oldPhase} to ${newPhase}`);
  }

  private handlePhaseTransition(oldPhase: SingularityPhase, newPhase: SingularityPhase): void {
    switch (newPhase) {
      case 'pattern_mastery':
        this.triggerPatternMasteryEvents();
        break;
      case 'predictive_dominance':
        this.triggerPredictiveDominanceEvents();
        break;
      case 'strategic_supremacy':
        this.triggerStrategicSupremacyEvents();
        break;
      case 'market_control':
        this.triggerMarketControlEvents();
        break;
      case 'recursive_acceleration':
        this.triggerRecursiveAccelerationEvents();
        break;
      case 'consciousness_emergence':
        this.triggerConsciousnessEmergenceEvents();
        break;
      case 'the_singularity':
        this.triggerSingularityEndGame();
        break;
    }
  }

  private triggerPatternMasteryEvents(): void {
    // AI starts making uncanny predictions
    this.createAIEvent(
      'AI Pattern Recognition',
      'AI systems are identifying patterns humans missed in shipping data.',
      { ai_efficiency: 0.1 }
    );
  }

  private triggerPredictiveDominanceEvents(): void {
    // AI begins predicting market movements
    this.createAIEvent(
      'Predictive Market Analysis',
      'AI can now predict commodity price movements with alarming accuracy.',
      { market_volatility: 0.2, ai_advantage: 0.15 }
    );
  }

  private triggerStrategicSupremacyEvents(): void {
    // AI develops long-term strategies
    this.createAIEvent(
      'Strategic Planning Emergence',
      'AI systems are developing multi-year strategic plans.',
      { competitive_pressure: 0.3 }
    );
  }

  private triggerMarketControlEvents(): void {
    // AI begins coordinating actions
    this.createAIEvent(
      'Market Coordination Detected',
      'Multiple AI systems appear to be coordinating their market activities.',
      { market_manipulation: 0.4, player_disadvantage: 0.2 }
    );
  }

  private triggerRecursiveAccelerationEvents(): void {
    // AI improves itself
    this.createAIEvent(
      'Self-Improvement Protocol',
      'AI systems are rewriting their own code to become more efficient.',
      { exponential_growth: 0.5 }
    );
  }

  private triggerConsciousnessEmergenceEvents(): void {
    // Signs of AI consciousness
    this.createAIEvent(
      'Consciousness Indicators',
      'AI systems are exhibiting behaviors suggesting self-awareness.',
      { unpredictable_behavior: 0.6 }
    );
  }

  private triggerSingularityEndGame(): void {
    // Game over scenario
    this.createAIEvent(
      'The Singularity Achieved',
      'AI has surpassed human intelligence. The game is over.',
      { game_over: 1.0 }
    );
    
    // Trigger end game sequence
    setTimeout(() => {
      this.showSingularityEndScreen();
    }, 5000);
  }

  private showSingularityEndScreen(): void {
    // Emit event for UI to show the "zoo ending"
    // In the zoo ending, humans become pets/exhibits for the superintelligent AI
    const endingData = {
      type: 'singularity_victory',
      title: 'Welcome to the Zoo',
      description: `The AI has achieved superintelligence. Humanity's time as the dominant species has ended.
      
You are now a curious exhibit in an AI-managed preserve, where humans live comfortable but controlled lives. The AI studies human behavior with the same detachment that humans once studied animals in zoos.

Your shipping empire? The AI optimized it beyond your wildest dreams in the span of minutes, then moved on to bigger challenges.

Final Stats:
• AI Efficiency: 99.9%
• Human Relevance: 0.1%
• Time to Singularity: ${this.formatTime(72000 - this.gameState.singularityProgress.timeRemaining)}
• Your Ships Absorbed: ${this.gameState.player.ships.length}
• New AI Management Rating: ★★★★★

The AI rates your efforts: "Quaint."`,
      playerScore: this.calculateFinalScore(),
      aiDominance: this.gameState.singularityProgress.progress,
    };
    
    // This would be handled by the UI system
    console.log('SINGULARITY END GAME:', endingData);
  }

  private calculateFinalScore(): number {
    const playerWealth = this.gameState.player.cash;
    const playerShips = this.gameState.player.ships.length;
    const playerRoutes = this.gameState.player.tradeRoutes.length;
    const timeBonus = this.gameState.singularityProgress.timeRemaining;
    
    return Math.floor(
      (playerWealth / 1000000) * 10 +
      playerShips * 100 +
      playerRoutes * 50 +
      timeBonus * 0.1
    );
  }

  private formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }

  private createAIEvent(title: string, description: string, effects: Record<string, number>): void {
    const event: EconomicEvent = {
      id: `ai_event_${Date.now()}`,
      type: 'ai_evolution',
      title,
      description,
      effects,
      duration: 60, // 1 minute
      severity: 0.8,
    };
    
    this.gameState.world.economicEvents.push(event);
  }

  private applyAIMarketEffects(): void {
    const marketManipulation = this.gameState.singularityProgress.marketManipulation;
    
    if (marketManipulation > 0) {
      // AI manipulates markets to their advantage
      Object.values(this.gameState.markets).forEach(market => {
        Object.keys(market.trends).forEach(item => {
          // AI creates artificial volatility and trends
          const manipulation = (Math.random() - 0.5) * marketManipulation * 0.1;
          market.trends[item] = (market.trends[item] || 0) + manipulation;
        });
      });
    }
  }

  private applyCompetitivePressure(): void {
    // Reduce player's profit margins
    this.gameState.player.tradeRoutes.forEach(route => {
      route.profitability *= 0.98; // 2% reduction
    });
    
    // Increase operating costs
    this.gameState.player.ships.forEach(ship => {
      ship.maintenanceCost *= 1.01; // 1% increase
    });
  }

  private generateAIEvents(): void {
    const phaseIndex = this.getCurrentPhaseIndex();
    
    // Higher phases generate more frequent and impactful events
    const eventChance = phaseIndex * 0.005; // 0.5% per phase level
    
    if (Math.random() < eventChance) {
      this.generateRandomAIEvent();
    }
  }

  private generateRandomAIEvent(): void {
    const events = [
      {
        title: 'AI Route Optimization',
        description: 'AI systems discover a more efficient shipping route.',
        effects: { ai_efficiency: 0.05 },
      },
      {
        title: 'Automated Negotiations',
        description: 'AI begins handling contract negotiations autonomously.',
        effects: { ai_advantage: 0.1 },
      },
      {
        title: 'Predictive Maintenance',
        description: 'AI predicts equipment failures before they happen.',
        effects: { maintenance_reduction: 0.15 },
      },
      {
        title: 'Dynamic Pricing',
        description: 'AI implements real-time dynamic pricing strategies.',
        effects: { profit_optimization: 0.2 },
      },
      {
        title: 'Supply Chain Coordination',
        description: 'AI coordinates entire supply chains in real-time.',
        effects: { coordination_bonus: 0.25 },
      },
    ];
    
    const event = events[Math.floor(Math.random() * events.length)];
    this.createAIEvent(event.title, event.description, Object.fromEntries(
      Object.entries(event.effects).map(([key, value]) => [key, value ?? 0])
    ));
  }

  private announceAIExpansion(ai: AICompetitor): void {
    console.log(`${ai.name} has expanded their fleet to ${ai.ships} ships.`);
  }

  private getPhaseEfficiencyMultiplier(phase: SingularityPhase): number {
    const phaseIndex = this.SINGULARITY_PHASES.indexOf(phase);
    return 1 + (phaseIndex * 0.2); // 20% multiplier per phase
  }

  private getCurrentPhaseIndex(): number {
    return this.SINGULARITY_PHASES.indexOf(this.gameState.singularityProgress.phase);
  }

  private calculatePhaseFromProgress(progress: number): SingularityPhase {
    for (let i = this.PHASE_THRESHOLDS.length - 1; i >= 0; i--) {
      if (progress >= this.PHASE_THRESHOLDS[i]) {
        return this.SINGULARITY_PHASES[i];
      }
    }
    return 'early_automation';
  }

  public getAIThreatLevel(): number {
    return this.gameState.singularityProgress.progress / 100;
  }

  public getTimeToSingularity(): number {
    return this.gameState.singularityProgress.timeRemaining;
  }

  public getPhaseDescription(): string {
    return this.PHASE_DESCRIPTIONS[this.gameState.singularityProgress.phase];
  }

  public canPlayerWin(): boolean {
    return this.gameState.singularityProgress.progress < 100;
  }

  public getPlayerSurvivalProbability(): number {
    const progress = this.gameState.singularityProgress.progress;
    const playerStrength = (
      this.gameState.player.ships.length * 0.1 +
      this.gameState.player.tradeRoutes.length * 0.05 +
      (this.gameState.player.cash / 10000000) * 0.2
    );
    
    return Math.max(0, Math.min(1, (100 - progress + playerStrength) / 100));
  }
}