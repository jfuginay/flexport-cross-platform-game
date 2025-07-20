// Hook to integrate advisor with game events
import { useEffect } from 'react';
import { useGameStore } from '../store/gameStore';

export interface AdvisorEvent {
  type: 'crisis_resolved' | 'contract_completed' | 'ship_purchased' | 'milestone';
  data: any;
  timestamp: Date;
}

class AdvisorEventBus {
  private listeners: ((event: AdvisorEvent) => void)[] = [];

  subscribe(callback: (event: AdvisorEvent) => void) {
    this.listeners.push(callback);
    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  }

  emit(event: AdvisorEvent) {
    this.listeners.forEach(listener => listener(event));
  }
}

export const advisorEventBus = new AdvisorEventBus();

export const useAdvisorIntegration = () => {
  const { money, fleet, contracts, reputation } = useGameStore();

  // Track milestones
  useEffect(() => {
    // First million
    if (money >= 1000000 && money < 1100000) {
      advisorEventBus.emit({
        type: 'milestone',
        data: {
          milestone: 'first_million',
          message: 'Congratulations on your first million! Now scale up operations.'
        },
        timestamp: new Date()
      });
    }

    // Fleet milestones
    if (fleet.length === 5) {
      advisorEventBus.emit({
        type: 'milestone',
        data: {
          milestone: 'fleet_5',
          message: 'Five ships! You\'re becoming a real player in global logistics.'
        },
        timestamp: new Date()
      });
    }

    if (fleet.length === 10) {
      advisorEventBus.emit({
        type: 'milestone',
        data: {
          milestone: 'fleet_10',
          message: 'Ten ships! You\'re now a major shipping company. Keep expanding!'
        },
        timestamp: new Date()
      });
    }
  }, [money, fleet, contracts, reputation]);

  return advisorEventBus;
};