import React, { useMemo } from 'react';
import { useGameStore } from '../../store/gameStore';
import './FinancesPanel.css';

export const FinancesPanel: React.FC = () => {
  const { money, fleet, contracts, ports } = useGameStore();
  
  const financialStats = useMemo(() => {
    const completedContracts = contracts.filter(c => c.status === 'COMPLETED');
    const activeContracts = contracts.filter(c => c.status === 'ACTIVE');
    
    const totalRevenue = completedContracts.reduce((sum, c) => sum + c.value, 0);
    const potentialRevenue = activeContracts.reduce((sum, c) => sum + c.value, 0);
    const fleetValue = fleet.reduce((sum, ship) => sum + ship.value, 0);
    const ownedPortsValue = ports.filter(p => p.isPlayerOwned).length * 10000000; // $10M per port
    
    const totalAssets = money + fleetValue + ownedPortsValue;
    const monthlyExpenses = fleet.length * 50000; // $50k per ship maintenance
    
    return {
      totalRevenue,
      potentialRevenue,
      fleetValue,
      ownedPortsValue,
      totalAssets,
      monthlyExpenses,
      profitMargin: totalRevenue > 0 ? ((totalRevenue - monthlyExpenses) / totalRevenue * 100).toFixed(1) : 0
    };
  }, [money, fleet, contracts, ports]);
  
  const transactionHistory = [
    { id: 1, type: 'income', description: 'Contract completed: Singapore → LA', amount: 425000, date: new Date() },
    { id: 2, type: 'expense', description: 'Ship maintenance: Container Ship Alpha', amount: -50000, date: new Date() },
    { id: 3, type: 'income', description: 'Contract completed: Dubai → Rotterdam', amount: 380000, date: new Date() },
    { id: 4, type: 'expense', description: 'Port fees: Singapore', amount: -25000, date: new Date() },
    { id: 5, type: 'income', description: 'Contract completed: Shanghai → LA', amount: 520000, date: new Date() },
  ];
  
  return (
    <div className="finances-panel">
      <h3>Financial Overview</h3>
      
      <div className="finance-cards">
        <div className="finance-card primary">
          <span className="card-icon">💰</span>
          <div className="card-content">
            <span className="card-label">Current Balance</span>
            <span className="card-value">${money.toLocaleString()}</span>
          </div>
        </div>
        
        <div className="finance-card">
          <span className="card-icon">📈</span>
          <div className="card-content">
            <span className="card-label">Total Revenue</span>
            <span className="card-value">${financialStats.totalRevenue.toLocaleString()}</span>
          </div>
        </div>
        
        <div className="finance-card">
          <span className="card-icon">🏦</span>
          <div className="card-content">
            <span className="card-label">Total Assets</span>
            <span className="card-value">${financialStats.totalAssets.toLocaleString()}</span>
          </div>
        </div>
        
        <div className="finance-card">
          <span className="card-icon">📊</span>
          <div className="card-content">
            <span className="card-label">Profit Margin</span>
            <span className="card-value">{financialStats.profitMargin}%</span>
          </div>
        </div>
      </div>
      
      <div className="assets-breakdown">
        <h4>Assets Breakdown</h4>
        <div className="breakdown-list">
          <div className="breakdown-item">
            <span className="item-label">Cash on Hand</span>
            <span className="item-value">${money.toLocaleString()}</span>
          </div>
          <div className="breakdown-item">
            <span className="item-label">Fleet Value</span>
            <span className="item-value">${financialStats.fleetValue.toLocaleString()}</span>
          </div>
          <div className="breakdown-item">
            <span className="item-label">Port Assets</span>
            <span className="item-value">${financialStats.ownedPortsValue.toLocaleString()}</span>
          </div>
          <div className="breakdown-item">
            <span className="item-label">Pending Revenue</span>
            <span className="item-value pending">${financialStats.potentialRevenue.toLocaleString()}</span>
          </div>
        </div>
      </div>
      
      <div className="transaction-history">
        <h4>Recent Transactions</h4>
        <div className="transactions-list">
          {transactionHistory.map(transaction => (
            <div key={transaction.id} className={`transaction-item ${transaction.type}`}>
              <div className="transaction-info">
                <span className="transaction-desc">{transaction.description}</span>
                <span className="transaction-date">
                  {transaction.date.toLocaleDateString()}
                </span>
              </div>
              <span className={`transaction-amount ${transaction.type}`}>
                {transaction.type === 'expense' ? '' : '+'}${Math.abs(transaction.amount).toLocaleString()}
              </span>
            </div>
          ))}
        </div>
      </div>
      
      <div className="financial-advice">
        <h4>AI Financial Advisor</h4>
        <div className="advice-card">
          <span className="advice-icon">💡</span>
          <p>
            Consider expanding your fleet. With your current profit margin of {financialStats.profitMargin}%, 
            investing in 2-3 more container ships could increase revenue by 40%.
          </p>
        </div>
      </div>
    </div>
  );
};