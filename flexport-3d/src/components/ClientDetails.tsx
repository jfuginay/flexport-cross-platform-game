import React, { useState } from 'react';
import { useGameStore } from '../store/gameStore';
import { Contract } from '../types/game.types';
import '../styles/ClientDetails.css';

interface ClientInfo {
  name: string;
  industry: string;
  totalContracts: number;
  completedContracts: number;
  totalRevenue: number;
  averageRating: number;
  preferredRoutes: { origin: string; destination: string; count: number }[];
  contractHistory: Contract[];
}

export const ClientDetails: React.FC = () => {
  const { contracts } = useGameStore();
  const [selectedClient, setSelectedClient] = useState<string | null>(null);
  
  // Group contracts by client
  const clientData = contracts.reduce((acc, contract) => {
    const client = contract.client;
    if (!acc[client]) {
      acc[client] = {
        name: client,
        industry: (contract as any).industry || 'General Logistics',
        totalContracts: 0,
        completedContracts: 0,
        totalRevenue: 0,
        averageRating: 0,
        preferredRoutes: [],
        contractHistory: [],
      };
    }
    
    acc[client].totalContracts++;
    acc[client].contractHistory.push(contract);
    
    if (contract.status === 'COMPLETED') {
      acc[client].completedContracts++;
      acc[client].totalRevenue += contract.payment;
    }
    
    // Track preferred routes
    const existingRoute = acc[client].preferredRoutes.find(
      r => r.origin === contract.origin.name && r.destination === contract.destination.name
    );
    
    if (existingRoute) {
      existingRoute.count++;
    } else {
      acc[client].preferredRoutes.push({
        origin: contract.origin.name,
        destination: contract.destination.name,
        count: 1,
      });
    }
    
    return acc;
  }, {} as Record<string, ClientInfo>);
  
  // Calculate completion rate and ratings
  Object.values(clientData).forEach(client => {
    const completionRate = client.totalContracts > 0 
      ? (client.completedContracts / client.totalContracts) * 100 
      : 0;
    client.averageRating = Math.min(5, 3 + (completionRate / 50));
  });
  
  // Sort routes by frequency
  Object.values(clientData).forEach(client => {
    client.preferredRoutes.sort((a, b) => b.count - a.count);
  });
  
  const clientList = Object.values(clientData).sort((a, b) => b.totalRevenue - a.totalRevenue);
  
  return (
    <div className="client-details-container">
      <h2>Client Management</h2>
      
      <div className="client-overview">
        <div className="client-stats">
          <div className="stat">
            <span className="label">Total Clients</span>
            <span className="value">{clientList.length}</span>
          </div>
          <div className="stat">
            <span className="label">Active Contracts</span>
            <span className="value">{contracts.filter(c => c.status === 'ACTIVE').length}</span>
          </div>
          <div className="stat">
            <span className="label">Completion Rate</span>
            <span className="value">
              {contracts.length > 0 
                ? Math.round((contracts.filter(c => c.status === 'COMPLETED').length / contracts.length) * 100)
                : 0}%
            </span>
          </div>
        </div>
      </div>
      
      <div className="client-list-section">
        <h3>Top Clients</h3>
        <div className="client-list">
          {clientList.map(client => (
            <div 
              key={client.name}
              className={`client-card ${selectedClient === client.name ? 'selected' : ''}`}
              onClick={() => setSelectedClient(client.name === selectedClient ? null : client.name)}
            >
              <div className="client-header">
                <h4>{client.name}</h4>
                <span className="industry">{client.industry}</span>
              </div>
              
              <div className="client-summary">
                <div className="summary-item">
                  <span className="label">Contracts:</span>
                  <span className="value">{client.completedContracts}/{client.totalContracts}</span>
                </div>
                <div className="summary-item">
                  <span className="label">Revenue:</span>
                  <span className="value">${(client.totalRevenue / 1000000).toFixed(1)}M</span>
                </div>
                <div className="summary-item">
                  <span className="label">Rating:</span>
                  <span className="rating">
                    {'★'.repeat(Math.floor(client.averageRating))}
                    {'☆'.repeat(5 - Math.floor(client.averageRating))}
                  </span>
                </div>
              </div>
              
              {selectedClient === client.name && (
                <div className="client-details">
                  <h5>Preferred Routes</h5>
                  <ul className="route-list">
                    {client.preferredRoutes.slice(0, 3).map((route, idx) => (
                      <li key={idx}>
                        {route.origin} → {route.destination} ({route.count} shipments)
                      </li>
                    ))}
                  </ul>
                  
                  <h5>Recent Contracts</h5>
                  <div className="contract-history">
                    {client.contractHistory.slice(-5).reverse().map(contract => (
                      <div key={contract.id} className="history-item">
                        <span className={`status status-${contract.status.toLowerCase()}`}>
                          {contract.status}
                        </span>
                        <span className="cargo">{contract.cargo}</span>
                        <span className="value">${(contract.payment / 1000).toFixed(0)}K</span>
                      </div>
                    ))}
                  </div>
                  
                  <div className="client-actions">
                    <button className="priority-client-btn">
                      Mark as Priority Client
                    </button>
                    <button className="negotiate-btn">
                      Negotiate Rates
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
      
      <div className="client-insights">
        <h3>Market Insights</h3>
        <div className="insights-grid">
          <div className="insight-card">
            <h4>Most Profitable Industry</h4>
            <p>{getMostProfitableIndustry(clientList)}</p>
          </div>
          <div className="insight-card">
            <h4>Busiest Trade Route</h4>
            <p>{getBusiestRoute(contracts)}</p>
          </div>
          <div className="insight-card">
            <h4>Average Contract Value</h4>
            <p>${getAverageContractValue(contracts)}</p>
          </div>
        </div>
      </div>
    </div>
  );
};

function getMostProfitableIndustry(clients: ClientInfo[]): string {
  const industryRevenue: Record<string, number> = {};
  
  clients.forEach(client => {
    if (!industryRevenue[client.industry]) {
      industryRevenue[client.industry] = 0;
    }
    industryRevenue[client.industry] += client.totalRevenue;
  });
  
  const sorted = Object.entries(industryRevenue).sort(([, a], [, b]) => b - a);
  return sorted[0]?.[0] || 'N/A';
}

function getBusiestRoute(contracts: Contract[]): string {
  const routeCounts: Record<string, number> = {};
  
  contracts.forEach(contract => {
    const route = `${contract.origin.name} - ${contract.destination.name}`;
    routeCounts[route] = (routeCounts[route] || 0) + 1;
  });
  
  const sorted = Object.entries(routeCounts).sort(([, a], [, b]) => b - a);
  return sorted[0]?.[0] || 'N/A';
}

function getAverageContractValue(contracts: Contract[]): string {
  if (contracts.length === 0) return '0';
  const total = contracts.reduce((sum, c) => sum + c.payment, 0);
  return (total / contracts.length / 1000).toFixed(0) + 'K';
}