import SwiftUI

struct GameSummaryView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player Status Header
                VStack(spacing: 12) {
                    Text("FlexPort Command Center")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 24) {
                        StatusCard(
                            title: "Net Worth",
                            value: "$\(formatCurrency(calculateNetWorth()))",
                            icon: "banknote.fill",
                            color: .green
                        )
                        
                        StatusCard(
                            title: "Fleet Size",
                            value: "\(gameManager.gameState.playerAssets.ships.count)",
                            icon: "ferry.fill",
                            color: .blue
                        )
                        
                        StatusCard(
                            title: "Reputation",
                            value: "\(Int(gameManager.gameState.playerAssets.reputation))",
                            icon: "star.fill",
                            color: .orange
                        )
                    }
                }
                .padding()
                
                // Quick Actions
                GroupBox("Quick Actions") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        QuickActionButton(
                            title: "New Trade Route",
                            icon: "map.fill",
                            color: .blue
                        ) {
                            // Action for new trade route
                        }
                        
                        QuickActionButton(
                            title: "Buy Ship",
                            icon: "plus.circle.fill",
                            color: .green
                        ) {
                            // Action for buying ship
                        }
                        
                        QuickActionButton(
                            title: "Market Analysis",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        ) {
                            // Action for market analysis
                        }
                        
                        QuickActionButton(
                            title: "Research",
                            icon: "brain.head.profile",
                            color: .orange
                        ) {
                            // Action for research
                        }
                    }
                }
                .padding(.horizontal)
                
                // Recent Activity
                GroupBox("Recent Activity") {
                    VStack(alignment: .leading, spacing: 12) {
                        ActivityRow(
                            icon: "ferry.fill",
                            title: "Pacific Voyager completed route",
                            subtitle: "Shanghai → Los Angeles",
                            time: "2 hours ago",
                            profit: 45000
                        )
                        
                        ActivityRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Electronics price increased",
                            subtitle: "+8.5% market movement",
                            time: "4 hours ago",
                            profit: nil
                        )
                        
                        ActivityRow(
                            icon: "brain.head.profile",
                            title: "Research completed",
                            subtitle: "Container Optimization",
                            time: "1 day ago",
                            profit: nil
                        )
                        
                        ActivityRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "AI competitor activity detected",
                            subtitle: "QuantumLogistics expanding fleet",
                            time: "6 hours ago",
                            profit: nil,
                            isWarning: true
                        )
                    }
                }
                .padding(.horizontal)
                
                // AI Threat Assessment
                if gameManager.singularityProgress > 0.2 {
                    GroupBox("AI Threat Assessment") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.red)
                                Text("AI Development Status")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(gameManager.singularityProgress * 100))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            ProgressView(value: gameManager.singularityProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            
                            Text(threatDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Performance Metrics
                GroupBox("Performance This Week") {
                    VStack(spacing: 12) {
                        MetricRow(label: "Revenue", value: "$1,250,000", change: "+12.5%", isPositive: true)
                        MetricRow(label: "Expenses", value: "$890,000", change: "+3.2%", isPositive: false)
                        MetricRow(label: "Net Profit", value: "$360,000", change: "+28.7%", isPositive: true)
                        MetricRow(label: "Route Efficiency", value: "87%", change: "+2.1%", isPositive: true)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
    }
    
    private func calculateNetWorth() -> Double {
        let cashValue = gameManager.gameState.playerAssets.money
        let fleetValue = gameManager.gameState.playerAssets.ships.reduce(0) { total, ship in
            // Estimate ship value based on capacity and efficiency
            total + (Double(ship.capacity) * ship.efficiency * 1000)
        }
        return cashValue + fleetValue
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", amount / 1_000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    private var threatDescription: String {
        switch gameManager.singularityProgress {
        case 0..<0.3:
            return "AI systems are in early development phase. Minimal threat to human operations."
        case 0.3..<0.6:
            return "AI competitors showing enhanced learning capabilities. Monitor closely."
        case 0.6..<0.8:
            return "Advanced AI systems detected. Significant competitive threat emerging."
        default:
            return "CRITICAL: AI singularity approaching. Immediate countermeasures required."
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let profit: Double?
    var isWarning: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isWarning ? .red : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let profit = profit {
                    Text("+$\(Int(profit))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Text(time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
            
            Text(change)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isPositive ? .green : .red)
        }
    }
}