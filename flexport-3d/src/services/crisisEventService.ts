import { executiveNotificationService, ExecutiveAlert } from './executiveNotificationService';
import { useGameStore } from '../store/gameStore';
import { weatherService, WeatherAlert } from './weatherService';

export interface CrisisEvent {
  id: string;
  type: 'UNION_NEGOTIATION' | 'PORT_STRIKE' | 'WEATHER_DISRUPTION' | 'PIRACY' | 'REGULATORY_CHANGE';
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  title: string;
  description: string;
  impact: {
    routes?: string[];
    ports?: string[];
    financialCost?: number;
    reputationCost?: number;
    duration?: number; // hours
  };
  options: CrisisOption[];
  expiresIn?: number; // minutes
}

export interface CrisisOption {
  id: string;
  label: string;
  action: string;
  cost?: number;
  consequences: {
    financial?: number;
    reputation?: number;
    resolution?: string;
  };
}

class CrisisEventService {
  private activeEvents: Map<string, CrisisEvent> = new Map();
  private eventHistory: CrisisEvent[] = [];
  private weatherMonitoringStarted = false;

  public triggerUnionCrisis(): void {
    const crisis: CrisisEvent = {
      id: `CRISIS-${Date.now()}`,
      type: 'UNION_NEGOTIATION',
      severity: 'CRITICAL',
      title: 'Union Negotiation Crisis',
      description: "Your dockworkers' union is demanding better pay and conditions amid rising inflation. The union leader is threatening a strike that could halt operations at your main port for weeks. You have three options to resolve this.",
      impact: {
        ports: ['Los Angeles', 'Long Beach'],
        financialCost: 500000,
        reputationCost: 15,
        duration: 168 // 1 week
      },
      options: [
        {
          id: 'pay-off',
          label: 'Pay Off Leader',
          action: 'pay_off_leader',
          cost: 250000,
          consequences: {
            financial: -250000,
            reputation: -10,
            resolution: 'Crisis averted through backroom deal'
          }
        },
        {
          id: 'raise-wages',
          label: 'Raise Wages',
          action: 'raise_wages',
          cost: 1000000,
          consequences: {
            financial: -1000000,
            reputation: 10,
            resolution: 'Workers satisfied, productivity increased'
          }
        },
        {
          id: 'call-bluff',
          label: 'Call Their Bluff',
          action: 'call_bluff',
          cost: 0,
          consequences: {
            financial: -2000000,
            reputation: -25,
            resolution: 'Strike occurs, major disruptions'
          }
        }
      ],
      expiresIn: 10 // 10 minutes to decide
    };

    this.triggerCrisis(crisis);
  }

  public triggerRandomCrisis(): void {
    const crisisTypes = [
      this.createPortStrikeCrisis,
      this.createPiracyCrisis,
      this.createGenericWeatherCrisis,
      this.createRegulatoryChangeCrisis
    ];

    const randomCrisis = crisisTypes[Math.floor(Math.random() * crisisTypes.length)];
    this.triggerCrisis(randomCrisis.call(this));
  }

  private createPortStrikeCrisis(): CrisisEvent {
    return {
      id: `CRISIS-${Date.now()}`,
      type: 'PORT_STRIKE',
      severity: 'HIGH',
      title: 'Port Workers Strike',
      description: 'Dock workers at major ports are striking. Operations are severely impacted.',
      impact: {
        ports: ['Rotterdam', 'Hamburg'],
        financialCost: 300000,
        duration: 72
      },
      options: [
        {
          id: 'negotiate',
          label: 'Negotiate Settlement',
          action: 'negotiate',
          cost: 150000,
          consequences: {
            financial: -150000,
            reputation: 5,
            resolution: 'Strike ends peacefully'
          }
        },
        {
          id: 'reroute',
          label: 'Reroute Ships',
          action: 'reroute',
          cost: 75000,
          consequences: {
            financial: -75000,
            reputation: 0,
            resolution: 'Operations continue with delays'
          }
        }
      ],
      expiresIn: 15
    };
  }

  private createPiracyCrisis(): CrisisEvent {
    return {
      id: `CRISIS-${Date.now()}`,
      type: 'PIRACY',
      severity: 'HIGH',
      title: 'Piracy Threat Detected',
      description: 'Intelligence reports indicate increased piracy activity along your shipping routes.',
      impact: {
        routes: ['Indian Ocean', 'Gulf of Aden'],
        financialCost: 200000,
        reputationCost: 5
      },
      options: [
        {
          id: 'hire-security',
          label: 'Hire Armed Security',
          action: 'hire_security',
          cost: 100000,
          consequences: {
            financial: -100000,
            reputation: 5,
            resolution: 'Ships protected, routes secured'
          }
        },
        {
          id: 'change-route',
          label: 'Change Routes',
          action: 'change_route',
          cost: 50000,
          consequences: {
            financial: -50000,
            reputation: -5,
            resolution: 'Longer but safer routes taken'
          }
        }
      ],
      expiresIn: 20
    };
  }

  private createGenericWeatherCrisis(): CrisisEvent {
    return {
      id: `CRISIS-${Date.now()}`,
      type: 'WEATHER_DISRUPTION',
      severity: 'MEDIUM',
      title: 'Severe Storm Warning',
      description: 'A major storm system threatens your fleet in the Pacific.',
      impact: {
        routes: ['Trans-Pacific'],
        financialCost: 150000,
        duration: 48
      },
      options: [
        {
          id: 'shelter',
          label: 'Seek Shelter',
          action: 'seek_shelter',
          cost: 75000,
          consequences: {
            financial: -75000,
            reputation: 5,
            resolution: 'Fleet safely weathered the storm'
          }
        },
        {
          id: 'continue',
          label: 'Continue Operations',
          action: 'continue',
          cost: 0,
          consequences: {
            financial: -300000,
            reputation: -10,
            resolution: 'Some damage sustained'
          }
        }
      ],
      expiresIn: 5
    };
  }

  private createRegulatoryChangeCrisis(): CrisisEvent {
    return {
      id: `CRISIS-${Date.now()}`,
      type: 'REGULATORY_CHANGE',
      severity: 'MEDIUM',
      title: 'New Environmental Regulations',
      description: 'New emissions standards require immediate fleet upgrades.',
      impact: {
        financialCost: 500000,
        reputationCost: 0
      },
      options: [
        {
          id: 'comply',
          label: 'Full Compliance',
          action: 'comply',
          cost: 500000,
          consequences: {
            financial: -500000,
            reputation: 15,
            resolution: 'Fleet fully compliant, reputation enhanced'
          }
        },
        {
          id: 'partial',
          label: 'Partial Compliance',
          action: 'partial_comply',
          cost: 200000,
          consequences: {
            financial: -200000,
            reputation: -5,
            resolution: 'Minimal compliance achieved'
          }
        }
      ],
      expiresIn: 30
    };
  }

  private triggerCrisis(crisis: CrisisEvent): void {
    this.activeEvents.set(crisis.id, crisis);
    
    // Send executive notification
    const alert: ExecutiveAlert = {
      type: this.mapCrisisTypeToAlert(crisis.type),
      severity: crisis.severity === 'CRITICAL' ? 'CRITICAL' : 'HIGH',
      affectedRoutes: crisis.impact.routes,
      financialImpact: crisis.impact.financialCost,
      timeToRespond: crisis.expiresIn
    };

    const sentMessage = executiveNotificationService.sendSecureMessage(alert, {
      message: crisis.description,
      actions: crisis.options.map(opt => ({
        label: opt.label,
        action: opt.id, // Use option ID instead of action
        consequence: opt.consequences.resolution
      }))
    });
    
    // Store the crisis with the message ID for proper resolution
    this.activeEvents.delete(crisis.id);
    crisis.id = sentMessage.id;
    this.activeEvents.set(crisis.id, crisis);

    // Set expiration timer
    if (crisis.expiresIn) {
      setTimeout(() => {
        if (this.activeEvents.has(crisis.id)) {
          this.autoResolveCrisis(crisis.id);
        }
      }, crisis.expiresIn * 60000);
    }
  }

  private mapCrisisTypeToAlert(type: string): 'UNION_CRISIS' | 'PORT_STRIKE' | 'REGULATORY_CHANGE' | 'MARKET_CRASH' | 'SECURITY_BREACH' {
    const mapping = {
      'UNION_NEGOTIATION': 'UNION_CRISIS' as const,
      'PORT_STRIKE': 'PORT_STRIKE' as const,
      'REGULATORY_CHANGE': 'REGULATORY_CHANGE' as const,
      'PIRACY': 'SECURITY_BREACH' as const,
      'WEATHER_DISRUPTION': 'PORT_STRIKE' as const
    };
    return mapping[type] || 'MARKET_CRASH';
  }

  public resolveCrisis(crisisId: string, optionId: string): void {
    const crisis = this.activeEvents.get(crisisId);
    if (!crisis) return;

    const option = crisis.options.find(opt => opt.id === optionId);
    if (!option) return;

    // Apply consequences
    const gameStore = useGameStore.getState();
    const currentMoney = gameStore.money;
    const currentRep = gameStore.reputation;
    
    if (option.consequences.financial) {
      const newMoney = Math.max(0, currentMoney + option.consequences.financial);
      useGameStore.setState({ money: newMoney });
      
      // Show financial impact notification
      this.showImpactNotification('financial', option.consequences.financial);
    }
    
    if (option.consequences.reputation) {
      const newRep = Math.max(0, Math.min(100, currentRep + option.consequences.reputation));
      useGameStore.setState({ reputation: newRep });
      
      // Show reputation impact notification
      this.showImpactNotification('reputation', option.consequences.reputation);
    }

    // Additional global power consequences
    this.applyGlobalPowerConsequences(crisis, option);

    // Log resolution
    console.log(`Crisis resolved: ${crisis.title} - ${option.consequences.resolution}`);

    // Move to history
    this.eventHistory.push(crisis);
    this.activeEvents.delete(crisisId);
  }

  private showImpactNotification(type: 'financial' | 'reputation', amount: number): void {
    // Create floating notification element
    const notification = document.createElement('div');
    notification.className = `impact-notification ${type} ${amount > 0 ? 'positive' : 'negative'}`;
    notification.textContent = type === 'financial' 
      ? `${amount > 0 ? '+' : ''}$${Math.abs(amount).toLocaleString()}`
      : `${amount > 0 ? '+' : ''}${amount} Reputation`;
    
    notification.style.cssText = `
      position: fixed;
      top: 100px;
      right: 20px;
      padding: 12px 24px;
      background: ${amount > 0 ? '#10b981' : '#ef4444'};
      color: white;
      font-weight: bold;
      border-radius: 8px;
      z-index: 10001;
      animation: slideInRight 0.3s ease-out, fadeOut 0.5s ease-out 2s forwards;
    `;
    
    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 3000);
  }

  private applyGlobalPowerConsequences(crisis: CrisisEvent, option: CrisisOption): void {
    // Every decision affects global standing
    const gameStore = useGameStore.getState();
    
    // Affect port relationships based on decision
    if (crisis.impact.ports) {
      // Decisions affect port efficiency and costs
      const portMultiplier = option.id === 'pay-off' ? 0.9 : // Corruption reduces efficiency
                             option.id === 'raise-wages' ? 1.1 : // Better paid workers = better efficiency
                             0.7; // Strikes severely impact efficiency
      
      // This would affect future port operations
      console.log(`Port efficiency multiplier: ${portMultiplier} for ports:`, crisis.impact.ports);
    }

    // Affect shipping routes
    if (crisis.impact.routes) {
      // Some routes may become more expensive or dangerous
      const routeRiskMultiplier = option.id === 'call-bluff' ? 1.5 : 1.0;
      console.log(`Route risk multiplier: ${routeRiskMultiplier} for routes:`, crisis.impact.routes);
    }

    // Long-term market effects
    const marketConfidence = option.id === 'raise-wages' ? 1.05 : 
                           option.id === 'pay-off' ? 0.95 : 
                           0.85;
    
    // This affects future contract values
    console.log(`Market confidence: ${marketConfidence}`);
  }

  private autoResolveCrisis(crisisId: string): void {
    const crisis = this.activeEvents.get(crisisId);
    if (!crisis) return;

    // Auto-resolve with worst option
    const worstOption = crisis.options.reduce((worst, current) => {
      const worstCost = (worst.consequences.financial || 0) + (worst.consequences.reputation || 0) * 10000;
      const currentCost = (current.consequences.financial || 0) + (current.consequences.reputation || 0) * 10000;
      return currentCost < worstCost ? current : worst;
    });

    this.resolveCrisis(crisisId, worstOption.id);
  }

  public getActiveEvents(): CrisisEvent[] {
    return Array.from(this.activeEvents.values());
  }

  // Start monitoring real-world weather
  public startWeatherMonitoring(): void {
    if (this.weatherMonitoringStarted) return;
    
    this.weatherMonitoringStarted = true;
    weatherService.startWeatherMonitoring((alert: WeatherAlert) => {
      this.createWeatherCrisis(alert);
    });
  }

  private createWeatherCrisis(weatherAlert: WeatherAlert): void {
    const severityMap = {
      'LOW': 'MEDIUM',
      'MEDIUM': 'HIGH',
      'HIGH': 'CRITICAL',
      'EXTREME': 'CRITICAL'
    };

    const crisis: CrisisEvent = {
      id: `CRISIS-WEATHER-${Date.now()}`,
      type: 'WEATHER_DISRUPTION',
      severity: severityMap[weatherAlert.severity] as any,
      title: `⚠️ Weather Alert: ${weatherAlert.location.name}`,
      description: weatherAlert.description,
      impact: {
        routes: weatherAlert.affectedRoutes,
        financialCost: this.calculateWeatherImpactCost(weatherAlert),
        duration: Math.floor((weatherAlert.endTime.getTime() - weatherAlert.startTime.getTime()) / (1000 * 60 * 60))
      },
      options: this.generateWeatherOptions(weatherAlert),
      expiresIn: 30 // 30 minutes to respond
    };

    this.triggerCrisis(crisis);
  }

  private calculateWeatherImpactCost(alert: WeatherAlert): number {
    const baseCost = {
      'HURRICANE': 5000000,
      'STORM': 2000000,
      'HIGH_WAVES': 1000000,
      'FOG': 500000,
      'EXTREME_WEATHER': 3000000
    };

    const severityMultiplier = {
      'LOW': 0.5,
      'MEDIUM': 1,
      'HIGH': 2,
      'EXTREME': 4
    };

    return baseCost[alert.type] * severityMultiplier[alert.severity];
  }

  private generateWeatherOptions(alert: WeatherAlert): CrisisOption[] {
    const options: CrisisOption[] = [];

    if (alert.type === 'HURRICANE' || alert.severity === 'EXTREME') {
      options.push({
        id: 'recall-all',
        label: 'Recall All Ships',
        action: 'recall_all',
        cost: 1000000,
        consequences: {
          financial: -1000000,
          reputation: 10,
          resolution: 'All ships ordered to nearest safe port'
        }
      });
    }

    options.push({
      id: 'reroute',
      label: 'Reroute Affected Ships',
      action: 'reroute_ships',
      cost: 500000,
      consequences: {
        financial: -500000,
        reputation: 5,
        resolution: 'Ships taking longer but safer routes'
      }
    });

    options.push({
      id: 'risk-it',
      label: 'Continue Operations',
      action: 'continue_ops',
      cost: 0,
      consequences: {
        financial: -this.calculateWeatherImpactCost(alert),
        reputation: -20,
        resolution: 'Ships at risk of damage or delays'
      }
    });

    if (alert.type === 'FOG' || alert.type === 'HIGH_WAVES') {
      options.push({
        id: 'wait',
        label: 'Delay Operations',
        action: 'delay_ops',
        cost: 250000,
        consequences: {
          financial: -250000,
          reputation: 0,
          resolution: 'Operations paused until conditions improve'
        }
      });
    }

    return options;
  }
}

export const crisisEventService = new CrisisEventService();