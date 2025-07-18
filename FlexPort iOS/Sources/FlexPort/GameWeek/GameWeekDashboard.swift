import SwiftUI
import UnityFramework

/// Game Week Requirement: Working companion app
/// Focus: Asset tracking + CRUD operations while Unity handles graphics
struct GameWeekDashboard: View {
    @StateObject private var empireViewModel = TradeEmpireViewModel()
    @StateObject private var singularityViewModel = SingularityViewModel()
    @StateObject private var unityBridge = UnityGameBridge()
    
    @State private var selectedTab = 0
    @State private var isConnectedToUnity = false
    @State private var lastSyncTime = Date()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Unity Game Monitoring View
            unityMonitoringTab
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("Game")
                }
                .tag(0)
            
            // Trade Empire Management
            empireManagementTab
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Empire")
                }
                .tag(1)
            
            // Market Monitoring
            marketMonitoringTab
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Markets")
                }
                .tag(2)
            
            // AI Singularity Tracker
            singularityTrackerTab
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Progress")
                }
                .tag(3)
        }
        .navigationTitle("FlexPort Game Week")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await initializeGameWeekSystems()
        }
        .refreshable {
            await syncWithUnityGame()
        }
    }
    
    // MARK: - Unity Monitoring Tab
    private var unityMonitoringTab: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Unity Connection Status
                connectionStatusCard
                
                // Unity Game View (Read-only monitoring)
                if isConnectedToUnity {
                    UnityGameView(mode: .monitoring)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    SingularityProgressOverlay(progress: singularityViewModel.progress)
                                        .padding()
                                }
                                Spacer()
                            }
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Connecting to Unity Game...")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                // Quick Game Stats
                gameStatsGrid
                
                Spacer()
            }
            .padding()
            .navigationTitle("Game Monitor")
        }
    }
    
    // MARK: - Empire Management Tab
    private var empireManagementTab: some View {
        NavigationView {
            List {
                Section("Trade Empire Status") {
                    empireStatusCard
                }
                
                Section("Trade Routes") {
                    ForEach(empireViewModel.tradeRoutes) { route in
                        TradeRouteRow(route: route, onInvest: { route in
                            Task {
                                await empireViewModel.investInRoute(route)
                            }
                        })
                        .swipeActions(edge: .trailing) {
                            Button("Invest") {
                                Task {
                                    await empireViewModel.investInRoute(route)
                                }
                            }
                            .tint(.green)
                            
                            Button("Upgrade") {
                                Task {
                                    await empireViewModel.upgradeRoute(route)
                                }
                            }
                            .tint(.blue)
                        }
                    }
                }
                
                Section("Available Routes") {
                    ForEach(empireViewModel.availableRoutes) { route in
                        AvailableRouteRow(route: route, onClaim: { route in
                            Task {
                                await empireViewModel.claimRoute(route)
                            }
                        })
                    }
                }
            }
            .navigationTitle("Trade Empire")
            .refreshable {
                await empireViewModel.syncWithUnityGame()
            }
        }
    }
    
    // MARK: - Market Monitoring Tab
    private var marketMonitoringTab: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Ryan's Four Markets Overview
                    FourMarketsOverviewCard(markets: empireViewModel.fourMarkets)
                    
                    // Market Performance Grid
                    MarketPerformanceGrid(markets: empireViewModel.fourMarkets)
                    
                    // Recent Market Events
                    MarketEventsSection(events: empireViewModel.recentMarketEvents)
                    
                    // Investment Opportunities
                    InvestmentOpportunitiesSection(
                        opportunities: empireViewModel.investmentOpportunities,
                        onInvest: { marketType, amount in
                            Task {
                                await empireViewModel.investInMarket(marketType, amount)
                            }
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Market Monitor")
            .refreshable {
                await empireViewModel.refreshMarketData()
            }
        }
    }
    
    // MARK: - AI Singularity Tracker Tab
    private var singularityTrackerTab: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Singularity Progress Card
                    SingularityProgressCard(
                        progress: singularityViewModel.progress,
                        currentPhase: singularityViewModel.currentPhase,
                        timeRemaining: singularityViewModel.estimatedTimeToSingularity
                    )
                    
                    // AI Milestones
                    AIMilestonesSection(milestones: singularityViewModel.aiMilestones)
                    
                    // Threat Assessment
                    ThreatAssessmentCard(
                        automationLevel: empireViewModel.playerAutomationLevel,
                        aiCapabilities: singularityViewModel.currentAICapabilities
                    )
                    
                    // Zoo Ending Preview (if close to singularity)
                    if singularityViewModel.progress > 80 {
                        ZooEndingPreviewCard()
                    }
                }
                .padding()
            }
            .navigationTitle("AI Singularity")
            .refreshable {
                await singularityViewModel.updateSingularityData()
            }
        }
    }
    
    // MARK: - Supporting Views
    private var connectionStatusCard: some View {
        HStack {
            Circle()
                .fill(isConnectedToUnity ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            Text(isConnectedToUnity ? "Connected to Unity Game" : "Connecting...")
                .font(.headline)
            
            Spacer()
            
            Text("Last sync: \(lastSyncTime, formatter: timeFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var empireStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Empire Level \(empireViewModel.empireLevel)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(empireViewModel.empireTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(empireViewModel.cash, specifier: "%.0f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Routes Owned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(empireViewModel.ownedRouteCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            // Progress to next level
            if empireViewModel.nextLevelProgress < 1.0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress to next level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: empireViewModel.nextLevelProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var gameStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Players Online",
                value: "\(empireViewModel.connectedPlayers)",
                icon: "person.3.fill",
                color: .green
            )
            
            StatCard(
                title: "Global Trade Volume",
                value: "$\(empireViewModel.globalTradeVolume, specifier: "%.1f")B",
                icon: "globe",
                color: .blue
            )
            
            StatCard(
                title: "AI Progress",
                value: "\(singularityViewModel.progress, specifier: "%.1f")%",
                icon: "brain.head.profile",
                color: singularityViewModel.progress > 50 ? .red : .orange
            )
            
            StatCard(
                title: "Session Time",
                value: empireViewModel.sessionDuration,
                icon: "clock",
                color: .purple
            )
        }
    }
    
    // MARK: - Helper Functions
    private func initializeGameWeekSystems() async {
        // Initialize Unity bridge
        await unityBridge.initializeConnection()
        isConnectedToUnity = unityBridge.isConnected
        
        // Start real-time sync with Unity game
        await startRealtimeSync()
        
        // Initialize view models with Unity data
        await empireViewModel.initializeWithUnityData(unityBridge)
        await singularityViewModel.initializeWithUnityData(unityBridge)
    }
    
    private func syncWithUnityGame() async {
        lastSyncTime = Date()
        
        // Sync all view models with Unity
        await empireViewModel.syncWithUnityGame()
        await singularityViewModel.updateSingularityData()
        
        // Update connection status
        isConnectedToUnity = unityBridge.isConnected
    }
    
    private func startRealtimeSync() async {
        // Start background sync every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await syncWithUnityGame()
            }
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Supporting Data Types
struct TradeRoute: Identifiable {
    let id: Int
    let name: String
    let startPort: String
    let endPort: String
    let distance: Float
    let profitability: Float
    let requiredInvestment: Float
    let isOwned: Bool
    let currentOwner: UInt64?
    let trafficVolume: Float
}

struct MarketData {
    let goodsMarketIndex: Float
    let capitalMarketIndex: Float
    let assetMarketIndex: Float
    let laborMarketIndex: Float
    let overallHealth: Float
}

// MARK: - Preview
struct GameWeekDashboard_Previews: PreviewProvider {
    static var previews: some View {
        GameWeekDashboard()
    }
}