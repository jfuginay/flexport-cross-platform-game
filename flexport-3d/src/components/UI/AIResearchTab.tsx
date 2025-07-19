// @ts-nocheck
import React, { useState, useEffect } from 'react';
import { useGameStore } from '../../store/gameStore';
import './AIResearchTab.css';

interface TrendData {
  route: string;
  demand: number;
  trend: 'up' | 'down' | 'stable';
  profitability: number;
  recommendation: string;
}

interface MarketInsight {
  type: 'warning' | 'opportunity' | 'info';
  title: string;
  description: string;
  action?: string;
}

export const AIResearchTab: React.FC = () => {
  const { ports, contracts, fleet, aiDevelopmentLevel } = useGameStore();
  const [activeTab, setActiveTab] = useState('trends');
  const [trends, setTrends] = useState<TrendData[]>([]);
  const [insights, setInsights] = useState<MarketInsight[]>([]);

  useEffect(() => {
    // Generate trend data based on contracts and routes
    const routeStats = new Map<string, { count: number; value: number }>();
    
    contracts.forEach(contract => {
      const route = `${contract.origin.name} → ${contract.destination.name}`;
      const stats = routeStats.get(route) || { count: 0, value: 0 };
      stats.count++;
      stats.value += contract.value;
      routeStats.set(route, stats);
    });

    const newTrends: TrendData[] = Array.from(routeStats.entries())
      .map(([route, stats]) => {
        const randomValue = Math.random();
        const trend: 'up' | 'down' | 'stable' = randomValue > 0.6 ? 'up' : randomValue > 0.3 ? 'stable' : 'down';
        
        return {
          route,
          demand: stats.count,
          trend,
          profitability: Math.round((stats.value / stats.count) / 1000) * 1000,
          recommendation: stats.count > 2 ? 'High Priority' : 'Monitor'
        };
      })
      .sort((a, b) => b.profitability - a.profitability)
      .slice(0, 10);

    setTrends(newTrends);

    // Generate insights
    const newInsights: MarketInsight[] = [];
    
    // Fleet utilization insight
    const idleShips = fleet.filter(s => s.status === 'IDLE').length;
    if (idleShips > fleet.length * 0.3) {
      newInsights.push({
        type: 'warning',
        title: 'High Fleet Idle Rate',
        description: `${idleShips} ships are idle. Consider accepting more contracts or selling excess capacity.`,
        action: 'View Contracts'
      });
    }

    // High demand routes
    const highDemandRoutes = trends.filter(t => t.demand > 3);
    if (highDemandRoutes.length > 0) {
      newInsights.push({
        type: 'opportunity',
        title: 'High Demand Routes Detected',
        description: `${highDemandRoutes.length} routes show high demand. Consider positioning ships accordingly.`,
        action: 'View Routes'
      });
    }

    // Port congestion
    const congestedPorts = ports.filter(p => p.availableBerths < 2);
    if (congestedPorts.length > 0) {
      newInsights.push({
        type: 'info',
        title: 'Port Congestion Alert',
        description: `${congestedPorts.map(p => p.name).join(', ')} showing low berth availability.`,
      });
    }

    setInsights(newInsights);
  }, [contracts, fleet, ports]);

  const getTrendIcon = (trend: 'up' | 'down' | 'stable') => {
    return trend === 'up' ? '📈' : trend === 'down' ? '📉' : '➡️';
  };

  const getInsightIcon = (type: 'warning' | 'opportunity' | 'info') => {
    return type === 'warning' ? '⚠️' : type === 'opportunity' ? '✨' : 'ℹ️';
  };

  return (
    <div className="ai-research-tab">
      <div className="research-header">
        <h2>AI Market Intelligence</h2>
        <div className="ai-level">
          <span>AI Development Level</span>
          <div className="level-bar">
            <div className="level-fill" style={{ width: `${aiDevelopmentLevel}%` }} />
          </div>
          <span>{aiDevelopmentLevel.toFixed(1)}%</span>
        </div>
      </div>

      <div className="research-tabs">
        <button 
          className={`tab ${activeTab === 'trends' ? 'active' : ''}`}
          onClick={() => setActiveTab('trends')}
        >
          📊 Market Trends
        </button>
        <button 
          className={`tab ${activeTab === 'insights' ? 'active' : ''}`}
          onClick={() => setActiveTab('insights')}
        >
          💡 Insights & Alerts
        </button>
        <button 
          className={`tab ${activeTab === 'predictions' ? 'active' : ''}`}
          onClick={() => setActiveTab('predictions')}
        >
          🔮 Predictions
        </button>
      </div>

      <div className="research-content">
        {activeTab === 'trends' && (
          <div className="trends-section">
            <h3>Top Shipping Routes by Profitability</h3>
            <div className="trends-list">
              {trends.map((trend, index) => (
                <div key={index} className="trend-item">
                  <div className="trend-rank">#{index + 1}</div>
                  <div className="trend-route">
                    <h4>{trend.route}</h4>
                    <div className="trend-stats">
                      <span className="stat">
                        <span className="label">Demand:</span>
                        <span className="value">{trend.demand} contracts</span>
                      </span>
                      <span className="stat">
                        <span className="label">Avg Value:</span>
                        <span className="value">${trend.profitability.toLocaleString()}</span>
                      </span>
                    </div>
                  </div>
                  <div className="trend-indicator">
                    <span className="trend-icon">{getTrendIcon(trend.trend)}</span>
                    <span className={`trend-label ${trend.trend}`}>{trend.trend}</span>
                  </div>
                  <div className={`recommendation ${trend.recommendation.toLowerCase().replace(' ', '-')}`}>
                    {trend.recommendation}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'insights' && (
          <div className="insights-section">
            <h3>Real-time Market Insights</h3>
            <div className="insights-list">
              {insights.map((insight, index) => (
                <div key={index} className={`insight-card ${insight.type}`}>
                  <div className="insight-icon">{getInsightIcon(insight.type)}</div>
                  <div className="insight-content">
                    <h4>{insight.title}</h4>
                    <p>{insight.description}</p>
                    {insight.action && (
                      <button className="insight-action">{insight.action}</button>
                    )}
                  </div>
                </div>
              ))}
            </div>

            <div className="market-summary">
              <h4>Market Summary</h4>
              <div className="summary-grid">
                <div className="summary-item">
                  <span className="label">Total Contracts</span>
                  <span className="value">{contracts.length}</span>
                </div>
                <div className="summary-item">
                  <span className="label">Active Routes</span>
                  <span className="value">{trends.length}</span>
                </div>
                <div className="summary-item">
                  <span className="label">Fleet Utilization</span>
                  <span className="value">
                    {Math.round((fleet.filter(s => s.status !== 'IDLE').length / fleet.length) * 100)}%
                  </span>
                </div>
                <div className="summary-item">
                  <span className="label">Avg Contract Value</span>
                  <span className="value">
                    ${Math.round(contracts.reduce((sum, c) => sum + c.value, 0) / contracts.length).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'predictions' && (
          <div className="predictions-section">
            <h3>AI-Powered Predictions</h3>
            <div className="prediction-cards">
              <div className="prediction-card">
                <h4>🌊 Demand Forecast</h4>
                <p>Expected 23% increase in Asia-Pacific routes over next 7 days</p>
                <div className="confidence">Confidence: {Math.min(95, aiDevelopmentLevel + 20).toFixed(0)}%</div>
              </div>
              <div className="prediction-card">
                <h4>💰 Price Trends</h4>
                <p>Container shipping rates likely to rise 15% due to port congestion</p>
                <div className="confidence">Confidence: {Math.min(92, aiDevelopmentLevel + 15).toFixed(0)}%</div>
              </div>
              <div className="prediction-card">
                <h4>⚡ Efficiency Tip</h4>
                <p>Repositioning 2 ships to Singapore could increase revenue by $2.3M</p>
                <div className="confidence">Confidence: {Math.min(88, aiDevelopmentLevel + 10).toFixed(0)}%</div>
              </div>
            </div>

            {aiDevelopmentLevel < 50 && (
              <div className="ai-upgrade-prompt">
                <p>🧠 Increase AI Development Level for more accurate predictions</p>
                <div className="progress-hint">Current accuracy limited by AI level</div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};