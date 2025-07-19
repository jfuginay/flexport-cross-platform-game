import React, { useState, useEffect } from 'react';
import { useGameStore } from '../store/gameStore';
import './DailyRewards.css';

interface DailyReward {
  day: number;
  reward: {
    type: 'money' | 'ship' | 'boost';
    amount: number;
    description: string;
  };
}

const DAILY_REWARDS: DailyReward[] = [
  { day: 1, reward: { type: 'money', amount: 10000, description: '$10,000' } },
  { day: 2, reward: { type: 'money', amount: 25000, description: '$25,000' } },
  { day: 3, reward: { type: 'boost', amount: 2, description: '2x Speed Boost' } },
  { day: 4, reward: { type: 'money', amount: 50000, description: '$50,000' } },
  { day: 5, reward: { type: 'ship', amount: 1, description: 'Free Container Ship' } },
  { day: 6, reward: { type: 'money', amount: 75000, description: '$75,000' } },
  { day: 7, reward: { type: 'ship', amount: 1, description: 'Premium Cargo Ship' } },
];

export const DailyRewards: React.FC = () => {
  const [currentStreak, setCurrentStreak] = useState(0);
  const [canClaim, setCanClaim] = useState(false);
  const [showRewards, setShowRewards] = useState(false);
  const { addMoney, addShip } = useGameStore();
  
  useEffect(() => {
    // Check last claim time
    const lastClaim = localStorage.getItem('lastDailyReward');
    const streak = parseInt(localStorage.getItem('dailyStreak') || '0');
    
    if (lastClaim) {
      const lastClaimDate = new Date(lastClaim);
      const now = new Date();
      const hoursSinceLastClaim = (now.getTime() - lastClaimDate.getTime()) / (1000 * 60 * 60);
      
      if (hoursSinceLastClaim >= 24) {
        setCanClaim(true);
        if (hoursSinceLastClaim > 48) {
          // Reset streak if more than 48 hours
          setCurrentStreak(0);
        } else {
          setCurrentStreak(streak);
        }
      } else {
        setCurrentStreak(streak);
      }
    } else {
      // First time
      setCanClaim(true);
      setCurrentStreak(0);
    }
    
    // Show rewards popup if can claim
    if (canClaim) {
      setShowRewards(true);
    }
  }, [canClaim]);
  
  const claimReward = () => {
    const todayReward = DAILY_REWARDS[currentStreak % 7];
    
    switch (todayReward.reward.type) {
      case 'money':
        addMoney(todayReward.reward.amount);
        break;
      case 'ship':
        // Add a basic ship
        addShip({
          name: `Daily Reward Ship ${Date.now()}`,
          type: 'CONTAINER',
          capacity: 5000,
          speed: 0.02,
          price: 0
        });
        break;
      case 'boost':
        // Implement boost logic
        localStorage.setItem('speedBoost', JSON.stringify({
          multiplier: todayReward.reward.amount,
          expires: Date.now() + 3600000 // 1 hour
        }));
        break;
    }
    
    // Update streak
    const newStreak = currentStreak + 1;
    setCurrentStreak(newStreak);
    localStorage.setItem('dailyStreak', newStreak.toString());
    localStorage.setItem('lastDailyReward', new Date().toISOString());
    
    setCanClaim(false);
    setShowRewards(false);
  };
  
  if (!showRewards) return null;
  
  return (
    <div className="daily-rewards-overlay">
      <div className="daily-rewards-modal">
        <h2>Daily Rewards</h2>
        <p className="streak-text">Login Streak: {currentStreak} days</p>
        
        <div className="rewards-grid">
          {DAILY_REWARDS.map((reward, index) => {
            const isToday = index === (currentStreak % 7);
            const isClaimed = index < (currentStreak % 7);
            
            return (
              <div 
                key={reward.day}
                className={`reward-item ${isToday ? 'today' : ''} ${isClaimed ? 'claimed' : ''}`}
              >
                <div className="reward-day">Day {reward.day}</div>
                <div className="reward-icon">
                  {reward.reward.type === 'money' && '💰'}
                  {reward.reward.type === 'ship' && '🚢'}
                  {reward.reward.type === 'boost' && '⚡'}
                </div>
                <div className="reward-description">{reward.reward.description}</div>
              </div>
            );
          })}
        </div>
        
        {canClaim ? (
          <button className="claim-button" onClick={claimReward}>
            Claim Today's Reward
          </button>
        ) : (
          <button className="close-button" onClick={() => setShowRewards(false)}>
            Close
          </button>
        )}
        
        <p className="comeback-text">Come back tomorrow for more rewards!</p>
      </div>
    </div>
  );
};