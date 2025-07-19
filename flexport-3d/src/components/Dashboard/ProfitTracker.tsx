// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { useSpring, animated } from '@react-spring/web';
import { useGameStore } from '../../store/gameStore';
import './Dashboard.css';

export const ProfitTracker: React.FC = () => {
  const { money } = useGameStore();
  const [previousMoney, setPreviousMoney] = useState(money);
  const [profitHistory, setProfitHistory] = useState<number[]>([]);
  
  const profit = money - previousMoney;
  const isProfitable = profit >= 0;
  
  useEffect(() => {
    const timer = setTimeout(() => {
      setPreviousMoney(money);
      setProfitHistory(prev => [...prev.slice(-19), profit].filter(p => p !== 0));
    }, 5000);
    
    return () => clearTimeout(timer);
  }, [money, profit]);
  
  const profitSpring = useSpring({
    number: Math.abs(profit),
    from: { number: 0 },
    config: { tension: 280, friction: 60 }
  });
  
  return (
    <div className="profit-tracker">
      <h3>Financial Performance</h3>
      
      <div className="profit-display">
        <div className="profit-label">Recent P&L</div>
        <animated.div 
          className={`profit-value ${isProfitable ? 'positive' : 'negative'}`}
        >
          {profitSpring.number.to(n => `${isProfitable ? '+' : '-'}$${n.toLocaleString('en-US', { maximumFractionDigits: 0 })}`)}
        </animated.div>
      </div>
      
      <div className="profit-chart">
        {profitHistory.map((value, index) => (
          <div
            key={index}
            className={`profit-bar ${value >= 0 ? 'positive' : 'negative'}`}
            style={{
              height: `${Math.abs(value) / 10000}px`,
              maxHeight: '40px'
            }}
          />
        ))}
      </div>
      
      <div className="profit-indicators">
        <div className="indicator">
          <span className="dot positive"></span>
          <span>Revenue</span>
        </div>
        <div className="indicator">
          <span className="dot negative"></span>
          <span>Expenses</span>
        </div>
      </div>
    </div>
  );
};