// @ts-nocheck
import React from 'react';
import './AIResearchPanel.css';

export const AIResearchPanel: React.FC = () => {
  const marketTrends = [
    { route: 'Asia → North America', trend: 'up', change: '+12%', demand: 'High' },
    { route: 'Europe → Asia', trend: 'stable', change: '+2%', demand: 'Medium' },
    { route: 'Middle East → Europe', trend: 'down', change: '-5%', demand: 'Low' },
    { route: 'South America → Asia', trend: 'up', change: '+8%', demand: 'High' },
  ];
  
  const insights = [
    { icon: '🚨', title: 'Suez Canal Congestion', description: 'Delays expected for next 48 hours' },
    { icon: '📈', title: 'Container Shortage', description: 'Asia ports reporting 15% shortage' },
    { icon: '⚡', title: 'Fuel Prices Rising', description: 'Bunker fuel up 8% this week' },
    { icon: '🌪️', title: 'Weather Alert', description: 'Typhoon approaching East Asia routes' },
  ];
  
  return (
    <div className="ai-research-panel">
      <h3>AI Market Intelligence</h3>
      
      <div className="market-overview">
        <h4>Global Trade Trends</h4>
        <div className="trends-list">
          {marketTrends.map((trend, index) => (
            <div key={index} className="trend-item">
              <div className="trend-route">{trend.route}</div>
              <div className={`trend-indicator ${trend.trend}`}>
                {trend.trend === 'up' ? '📈' : trend.trend === 'down' ? '📉' : '➡️'}
                <span className="trend-change">{trend.change}</span>
              </div>
              <div className={`demand-badge ${trend.demand.toLowerCase()}`}>
                {trend.demand}
              </div>
            </div>
          ))}
        </div>
      </div>
      
      <div className="ai-insights">
        <h4>Real-Time Insights</h4>
        <div className="insights-grid">
          {insights.map((insight, index) => (
            <div key={index} className="insight-card">
              <span className="insight-icon">{insight.icon}</span>
              <div className="insight-content">
                <h5>{insight.title}</h5>
                <p>{insight.description}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      
      <div className="ai-recommendations">
        <h4>AI Recommendations</h4>
        <div className="recommendation-card">
          <span className="rec-icon">🤖</span>
          <div className="rec-content">
            <p>
              <strong>Optimize Asia Routes:</strong> Current market conditions favor 
              Asia-North America routes. Consider reallocating 2-3 vessels from 
              underperforming European routes for a potential 25% revenue increase.
            </p>
            <button className="apply-rec-btn">Apply Recommendation</button>
          </div>
        </div>
      </div>
      
      <div className="singularity-warning">
        <span className="warning-icon">⚠️</span>
        <p>AI Learning Progress: 42% - Estimated time to singularity: 184 days</p>
      </div>
    </div>
  );
};