import SwiftUI
import Combine

public struct EnhancedFinancialDashboardView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showingEconomicEvents = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var cancellables = Set<AnyCancellable>()
    
    enum TimeRange: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Back Button
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Financial Dashboard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Real-time economic overview")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            gameManager.navigateTo(.game)
                        }) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    
                    // Financial Summary Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        FinancialSummaryCard(
                            title: "Net Worth",
                            value: "$\(formatCurrency(gameManager.gameState.playerAssets.money))",
                            trend: .up,
                            trendValue: "12.3%",
                            color: .green
                        )
                        
                        FinancialSummaryCard(
                            title: "Daily Revenue",
                            value: "$\(formatCurrency(calculateDailyRevenue()))",
                            trend: .up,
                            trendValue: "8.7%",
                            color: .blue
                        )
                        
                        FinancialSummaryCard(
                            title: "Fleet Value",
                            value: "$\(formatCurrency(calculateFleetValue()))",
                            trend: .down,
                            trendValue: "2.1%",
                            color: .orange
                        )
                        
                        FinancialSummaryCard(
                            title: "Daily Costs",
                            value: "$\(formatCurrency(calculateDailyCosts()))",
                            trend: .up,
                            trendValue: "3.4%",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Economic Events Section
                    GroupBox("Recent Economic Events") {
                        VStack(spacing: 12) {
                            ForEach(getRecentEconomicEvents(), id: \.id) { event in
                                EconomicEventRow(event: event)
                            }
                            
                            if getRecentEconomicEvents().isEmpty {
                                Text("No recent economic events")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding()
                            }
                            
                            Button("View All Events") {
                                showingEconomicEvents = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Market Analysis
                    GroupBox("Market Analysis") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Market Conditions")
                                    .font(.headline)
                                Spacer()
                                Text("Stable")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(6)
                                    .font(.caption)
                            }
                            
                            MarketIndicatorRow(
                                name: "Freight Rates",
                                value: "+15.3%",
                                isPositive: true
                            )
                            
                            MarketIndicatorRow(
                                name: "Fuel Prices",
                                value: "-8.7%",
                                isPositive: true
                            )
                            
                            MarketIndicatorRow(
                                name: "Port Congestion",
                                value: "+22.1%",
                                isPositive: false
                            )
                            
                            Button("Trigger Market Event") {
                                triggerRandomEconomicEvent()
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Cash Flow Projection
                    GroupBox("Cash Flow Projection") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next 30 Days")
                                .font(.headline)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Projected Income")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(formatCurrency(calculateProjectedIncome()))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Projected Expenses")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(formatCurrency(calculateProjectedExpenses()))")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Net Cash Flow")
                                    .font(.headline)
                                Spacer()
                                Text("$\(formatCurrency(calculateProjectedIncome() - calculateProjectedExpenses()))")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(calculateProjectedIncome() > calculateProjectedExpenses() ? .green : .red)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEconomicEvents) {
                EconomicEventsDetailView()
                    .environmentObject(gameManager)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.1fK", amount / 1_000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
    
    private func calculateDailyRevenue() -> Double {
        return gameManager.gameState.tradeRoutes.reduce(0) { total, route in
            total + (route.profitMargin * 1000) // Simplified calculation
        }
    }
    
    private func calculateFleetValue() -> Double {
        return gameManager.gameState.playerAssets.ships.reduce(0) { total, ship in
            total + 1_250_000 // Simplified ship value
        }
    }
    
    private func calculateDailyCosts() -> Double {
        return gameManager.gameState.playerAssets.ships.reduce(0) { total, ship in
            total + ship.maintenanceCost
        }
    }
    
    private func calculateProjectedIncome() -> Double {
        return calculateDailyRevenue() * 30
    }
    
    private func calculateProjectedExpenses() -> Double {
        return calculateDailyCosts() * 30
    }
    
    private func getRecentEconomicEvents() -> [EconomicEventStruct] {
        // This would integrate with our ECS economic event system
        return [
            EconomicEventStruct(
                id: UUID(),
                type: "Port Strike",
                description: "Labor strike at Singapore port affecting container throughput",
                impact: "-15% revenue",
                severity: .medium,
                timestamp: Date()
            ),
            EconomicEventStruct(
                id: UUID(),
                type: "Fuel Price Drop",
                description: "Global oil prices decreased due to increased supply",
                impact: "+8% profit margin",
                severity: .low,
                timestamp: Date().addingTimeInterval(-3600)
            )
        ]
    }
    
    private func triggerRandomEconomicEvent() {
        // This would integrate with our ECS systems to trigger real events
        let events = ["Hurricane", "Tsunami", "Port Strike", "Fuel Crisis", "Trade War"]
        let randomEvent = events.randomElement() ?? "Market Fluctuation"
        
        // Trigger haptic feedback
        AdvancedHapticManager.shared.playEventHaptic(.economicImpact, intensity: 0.8, duration: 1.0)
        
        // Trigger spatial audio
        SpatialAudioEngine.shared.playEmergencyAlert(
            .generalAlarm,
            at: SIMD3<Float>(0, 0, 0),
            severity: 0.7
        )
        
        print("Triggered economic event: \(randomEvent)")
    }
}

struct EconomicEventStruct {
    let id: UUID
    let type: String
    let description: String
    let impact: String
    let severity: EventSeverity
    let timestamp: Date
    
    enum EventSeverity {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

struct FinancialSummaryCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let trendValue: String
    let color: Color
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: trend.icon)
                    .foregroundColor(trend.color)
                    .font(.caption)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(trendValue)
                .font(.caption)
                .foregroundColor(trend.color)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct EconomicEventRow: View {
    let event: EconomicEventStruct
    
    var body: some View {
        HStack {
            Circle()
                .fill(event.severity.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(event.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.impact)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(event.impact.contains("+") ? .green : .red)
                Text(timeAgo(from: event.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
}

struct MarketIndicatorRow: View {
    let name: String
    let value: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isPositive ? .green : .red)
        }
    }
}

struct EconomicEventsDetailView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(getAllEconomicEvents(), id: \.id) { event in
                        EconomicEventDetailCard(event: event)
                    }
                }
                .padding()
            }
            .navigationTitle("Economic Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getAllEconomicEvents() -> [EconomicEventStruct] {
        // This would pull from our ECS economic event system
        return [
            EconomicEventStruct(
                id: UUID(),
                type: "Port Strike",
                description: "Labor strike at Singapore port affecting container throughput by 40%. Expected duration: 3-5 days.",
                impact: "-15% revenue",
                severity: .medium,
                timestamp: Date()
            ),
            EconomicEventStruct(
                id: UUID(),
                type: "Fuel Price Drop",
                description: "Global oil prices decreased by 12% due to increased supply from new drilling operations in the North Sea.",
                impact: "+8% profit margin",
                severity: .low,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            EconomicEventStruct(
                id: UUID(),
                type: "Hurricane Warning",
                description: "Category 3 hurricane approaching the Gulf Coast. Port closures expected for 2-3 days.",
                impact: "-25% operations",
                severity: .high,
                timestamp: Date().addingTimeInterval(-7200)
            )
        ]
    }
}

struct EconomicEventDetailCard: View {
    let event: EconomicEventStruct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.type)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(timeAgo(from: event.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.impact)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(event.impact.contains("+") ? .green : .red)
                    
                    Text(event.severity.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(event.severity.color.opacity(0.2))
                        .foregroundColor(event.severity.color)
                        .cornerRadius(6)
                }
            }
            
            Text(event.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
            
            Button("View Details") {
                // Handle detail view
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func timeAgo(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 {
            return "\(minutes) minutes ago"
        } else {
            let hours = minutes / 60
            return "\(hours) hours ago"
        }
    }
}

extension EconomicEventStruct.EventSeverity: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        default: return nil
        }
    }
}