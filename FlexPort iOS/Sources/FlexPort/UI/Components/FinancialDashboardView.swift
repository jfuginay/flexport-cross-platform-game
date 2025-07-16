import SwiftUI

public struct FinancialDashboardView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedTimeRange = TimeRange.week
    @State private var showingDetailedAnalysis = false
    
    enum TimeRange: String, CaseIterable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        case year = "1Y"
    }
    
    // Sample data for charts
    let revenueData = [
        RevenuePoint(date: Date().addingTimeInterval(-6 * 86400), amount: 125000),
        RevenuePoint(date: Date().addingTimeInterval(-5 * 86400), amount: 132000),
        RevenuePoint(date: Date().addingTimeInterval(-4 * 86400), amount: 128000),
        RevenuePoint(date: Date().addingTimeInterval(-3 * 86400), amount: 145000),
        RevenuePoint(date: Date().addingTimeInterval(-2 * 86400), amount: 151000),
        RevenuePoint(date: Date().addingTimeInterval(-1 * 86400), amount: 148000),
        RevenuePoint(date: Date(), amount: 156000)
    ]
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Balance
                VStack(spacing: 8) {
                    Text("Financial Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("$\(Int(gameManager.gameState.playerAssets.money))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("+12.5%")
                            .foregroundColor(.green)
                        Text("vs last week")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding()
                
                // Time Range Selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Revenue Chart
                GroupBox {
                    VStack(alignment: .leading) {
                        Text("Revenue Trend")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        // Simple line chart placeholder
                        VStack {
                            HStack {
                                ForEach(Array(revenueData.enumerated()), id: \.offset) { index, item in
                                    VStack {
                                        Spacer()
                                        Rectangle()
                                            .fill(.green)
                                            .frame(width: 20, height: CGFloat(item.amount / 2000))
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                    }
                                }
                            }
                            .frame(height: 200)
                            
                            HStack {
                                Text("Revenue: $125K - $156K")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Key Metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(
                        title: "Daily Revenue",
                        value: "$156K",
                        change: "+8.2%",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Operating Costs",
                        value: "$89K",
                        change: "+3.1%",
                        icon: "chart.line.downtrend.xyaxis",
                        color: .orange
                    )
                    
                    MetricCard(
                        title: "Net Profit",
                        value: "$67K",
                        change: "+15.4%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Fleet Utilization",
                        value: "87%",
                        change: "+2.3%",
                        icon: "percent",
                        color: .purple
                    )
                }
                .padding(.horizontal)
                
                // Expense Breakdown
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Expense Breakdown")
                            .font(.headline)
                        
                        ExpenseRow(category: "Fuel", amount: 42000, percentage: 0.47, color: .red)
                        ExpenseRow(category: "Maintenance", amount: 18000, percentage: 0.20, color: .orange)
                        ExpenseRow(category: "Labor", amount: 15000, percentage: 0.17, color: .blue)
                        ExpenseRow(category: "Port Fees", amount: 8000, percentage: 0.09, color: .purple)
                        ExpenseRow(category: "Other", amount: 6000, percentage: 0.07, color: .gray)
                    }
                }
                .padding(.horizontal)
                
                // Market Analysis Button
                Button(action: {
                    showingDetailedAnalysis = true
                }) {
                    Label("View Market Analysis", systemImage: "chart.xyaxis.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                // Back to Game Button
                Button(action: {
                    gameManager.navigateTo(.game)
                }) {
                    Label("Back to Game", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingDetailedAnalysis) {
            MarketAnalysisView()
        }
    }
}

struct RevenuePoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(change)
                    .font(.caption)
                    .foregroundColor(change.hasPrefix("+") ? .green : .red)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ExpenseRow: View {
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(category)
                    .font(.subheadline)
                Spacer()
                Text("$\(Int(amount))")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MarketAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Market Analysis")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Commodity Prices
                    GroupBox("Commodity Prices") {
                        VStack(spacing: 12) {
                            CommodityRow(name: "Electronics", price: 2450, change: 3.2)
                            CommodityRow(name: "Textiles", price: 890, change: -1.5)
                            CommodityRow(name: "Machinery", price: 3200, change: 0.8)
                            CommodityRow(name: "Food Products", price: 1100, change: 2.1)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Trade Routes Performance
                    GroupBox("Top Trade Routes") {
                        VStack(spacing: 12) {
                            RouteRow(from: "Shanghai", to: "Los Angeles", profit: 45000)
                            RouteRow(from: "Singapore", to: "Rotterdam", profit: 38000)
                            RouteRow(from: "Hong Kong", to: "New York", profit: 42000)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CommodityRow: View {
    let name: String
    let price: Double
    let change: Double
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text("$\(Int(price))/TEU")
                .fontWeight(.medium)
            Text("\(change > 0 ? "+" : "")\(change, specifier: "%.1f")%")
                .font(.caption)
                .foregroundColor(change > 0 ? .green : .red)
        }
    }
}

struct RouteRow: View {
    let from: String
    let to: String
    let profit: Double
    
    var body: some View {
        HStack {
            Text("\(from) → \(to)")
            Spacer()
            Text("$\(Int(profit))")
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
    }
}