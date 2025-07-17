import SwiftUI
import Charts

// MARK: - Portrait Fleet Management Dashboard
struct PortraitGameView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @State private var selectedTab = 0
    @State private var showingShipDetails = false
    @State private var selectedShip: Ship?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Tab View
            TabView(selection: $selectedTab) {
                FleetOverviewTab()
                    .tag(0)
                
                PortStatusTab()
                    .tag(1)
                
                EconomicPerformanceTab()
                    .tag(2)
                
                MultiplayerStatusTab()
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingShipDetails) {
            if let ship = selectedShip {
                ShipDetailSheet(ship: ship)
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FlexPort Empire")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let room = multiplayerManager.currentSession {
                        Text("Room: \(room.id.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Connection Status Indicator
                ConnectionStatusBadge()
            }
            
            // Financial Summary
            HStack(spacing: 20) {
                StatCard(
                    icon: "dollarsign.circle.fill",
                    value: "$\(Int(gameManager.gameState.playerAssets.money / 1000))K",
                    label: "Cash",
                    color: .green
                )
                
                StatCard(
                    icon: "ferry.fill",
                    value: "\(gameManager.gameState.playerAssets.ships.count)",
                    label: "Ships",
                    color: .blue
                )
                
                StatCard(
                    icon: "building.2.fill",
                    value: "\(gameManager.gameState.playerAssets.warehouses.count)",
                    label: "Warehouses",
                    color: .orange
                )
                
                StatCard(
                    icon: "star.fill",
                    value: "\(Int(gameManager.gameState.playerAssets.reputation))",
                    label: "Rep",
                    color: .purple
                )
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Connection Status Badge
struct ConnectionStatusBadge: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            Text(connectionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    var connectionColor: Color {
        switch multiplayerManager.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .reconnecting:
            return .yellow
        }
    }
    
    var connectionText: String {
        switch multiplayerManager.connectionState {
        case .connected:
            return "Online"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Offline"
        case .reconnecting:
            return "Reconnecting..."
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Fleet Overview Tab
struct FleetOverviewTab: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Fleet Summary Card
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Fleet Performance", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Capacity")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalCapacity) TEU")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Utilization")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(utilizationRate))%")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(utilizationColor)
                            }
                        }
                        
                        ProgressView(value: utilizationRate / 100)
                            .tint(utilizationColor)
                    }
                }
                
                // Ship List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Ships")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(gameManager.gameState.playerAssets.ships) { ship in
                        ShipRowView(ship: ship)
                            .padding(.horizontal)
                    }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    Button(action: {
                        // Buy new ship
                    }) {
                        Label("Purchase New Ship", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        // Optimize routes
                    }) {
                        Label("Optimize All Routes", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
    
    var totalCapacity: Int {
        gameManager.gameState.playerAssets.ships.reduce(0) { $0 + $1.capacity }
    }
    
    var utilizationRate: Double {
        // Calculate based on active routes and cargo
        return 75.0 // Placeholder
    }
    
    var utilizationColor: Color {
        if utilizationRate > 80 {
            return .green
        } else if utilizationRate > 60 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Ship Row View
struct ShipRowView: View {
    let ship: Ship
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "ferry.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ship.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Label("\(ship.capacity) TEU", systemImage: "shippingbox")
                                .font(.caption)
                            
                            Label("\(Int(ship.speed)) kn", systemImage: "speedometer")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        StatusBadge(status: .active)
                        Text("Hong Kong → LA")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Daily Cost: $\(Int(ship.maintenanceCost))", systemImage: "dollarsign.circle")
                        Spacer()
                        Label("Efficiency: \(Int(ship.efficiency * 100))%", systemImage: "leaf.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button("Details") {
                            // Show details
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Reassign") {
                            // Reassign ship
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .padding(.top, -8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    enum Status {
        case active, idle, maintenance
        
        var color: Color {
            switch self {
            case .active: return .green
            case .idle: return .orange
            case .maintenance: return .red
            }
        }
        
        var text: String {
            switch self {
            case .active: return "Active"
            case .idle: return "Idle"
            case .maintenance: return "Maintenance"
            }
        }
    }
    
    let status: Status
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            
            Text(status.text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.2))
        .cornerRadius(6)
    }
}

// MARK: - Port Status Tab
struct PortStatusTab: View {
    @EnvironmentObject var gameManager: GameManager
    
    let majorPorts = [
        (name: "Singapore", congestion: 0.45, goodsAvailable: 125000),
        (name: "Hong Kong", congestion: 0.72, goodsAvailable: 98000),
        (name: "Shanghai", congestion: 0.88, goodsAvailable: 145000),
        (name: "Los Angeles", congestion: 0.65, goodsAvailable: 110000),
        (name: "Rotterdam", congestion: 0.52, goodsAvailable: 87000)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Port Overview Map Placeholder
                GroupBox {
                    VStack(spacing: 8) {
                        HStack {
                            Label("Global Port Status", systemImage: "map.fill")
                                .font(.headline)
                            Spacer()
                            Button("View Map") {
                                // Switch to landscape
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        // Simple port status visualization
                        HStack(spacing: 4) {
                            ForEach(majorPorts.prefix(3), id: \.name) { port in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(congestionColor(port.congestion))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(port.name.prefix(3)))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text("\(Int(port.congestion * 100))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Port Details List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Port Details")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(majorPorts, id: \.name) { port in
                        PortStatusRow(
                            name: port.name,
                            congestion: port.congestion,
                            goodsAvailable: port.goodsAvailable
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    func congestionColor(_ congestion: Double) -> Color {
        if congestion < 0.5 {
            return .green
        } else if congestion < 0.75 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Port Status Row
struct PortStatusRow: View {
    let name: String
    let congestion: Double
    let goodsAvailable: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Label("\(goodsAvailable / 1000)K tons", systemImage: "shippingbox.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("5 ships", systemImage: "ferry")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Congestion")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        ProgressView(value: congestion)
                            .tint(congestionColor)
                            .frame(width: 60)
                        
                        Text("\(Int(congestion * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(congestionColor)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    var congestionColor: Color {
        if congestion < 0.5 {
            return .green
        } else if congestion < 0.75 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Economic Performance Tab
struct EconomicPerformanceTab: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Revenue Chart
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Revenue Trend", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        
                        // Simple revenue chart placeholder
                        RevenueChartView()
                            .frame(height: 200)
                    }
                }
                
                // Key Metrics
                VStack(spacing: 12) {
                    MetricRow(
                        title: "Daily Revenue",
                        value: "$125,000",
                        change: "+12.5%",
                        isPositive: true
                    )
                    
                    MetricRow(
                        title: "Operating Costs",
                        value: "$45,000",
                        change: "+3.2%",
                        isPositive: false
                    )
                    
                    MetricRow(
                        title: "Net Profit",
                        value: "$80,000",
                        change: "+18.7%",
                        isPositive: true
                    )
                    
                    MetricRow(
                        title: "Fleet Efficiency",
                        value: "82%",
                        change: "+5.1%",
                        isPositive: true
                    )
                }
                .padding(.horizontal)
                
                // Trade Routes Performance
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Top Trade Routes", systemImage: "arrow.triangle.swap")
                            .font(.headline)
                        
                        ForEach(0..<3) { index in
                            HStack {
                                Text("Hong Kong → LA")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("$\(25000 - index * 3000)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("per trip")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if index < 2 {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Revenue Chart View
struct RevenueChartView: View {
    var body: some View {
        Chart {
            ForEach(0..<7) { day in
                LineMark(
                    x: .value("Day", day),
                    y: .value("Revenue", Double.random(in: 80000...150000))
                )
                .foregroundStyle(.blue)
                
                AreaMark(
                    x: .value("Day", day),
                    y: .value("Revenue", Double.random(in: 80000...150000))
                )
                .foregroundStyle(.linearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("$\(intValue / 1000)K")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

// MARK: - Metric Row
struct MetricRow: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(change)
                        .font(.caption)
                }
                .foregroundColor(isPositive ? .green : .red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Multiplayer Status Tab
struct MultiplayerStatusTab: View {
    @ObservedObject var multiplayerManager = MultiplayerManager.shared
    @State private var showingLobby = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection Status
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Label("Multiplayer Status", systemImage: "network")
                                .font(.headline)
                            
                            Spacer()
                            
                            ConnectionStatusBadge()
                        }
                        
                        if let session = multiplayerManager.currentSession {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Session ID:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(session.id.prefix(12) + "...")
                                        .font(.caption)
                                        .fontFamily(.monospaced)
                                }
                                
                                HStack {
                                    Text("Players:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(multiplayerManager.connectedPlayers.count)/16")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Text("Game Mode:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(multiplayerManager.gameMode == .realtime ? "Real-time" : "Turn-based")
                                        .font(.caption)
                                }
                            }
                        } else {
                            Text("Not connected to a game")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    }
                }
                
                // Network Metrics
                if multiplayerManager.connectionState == .connected {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Network Performance", systemImage: "speedometer")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                NetworkMetricRow(
                                    label: "Latency",
                                    value: "\(Int(multiplayerManager.networkMetrics.latency * 1000))ms",
                                    status: latencyStatus
                                )
                                
                                NetworkMetricRow(
                                    label: "Bandwidth",
                                    value: "\(Int(multiplayerManager.networkMetrics.bandwidth)) KB/s",
                                    status: .good
                                )
                                
                                NetworkMetricRow(
                                    label: "Messages/sec",
                                    value: "\(Int(multiplayerManager.networkMetrics.messagesReceivedPerSecond))",
                                    status: .good
                                )
                            }
                        }
                    }
                }
                
                // Player List
                if !multiplayerManager.connectedPlayers.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Connected Players", systemImage: "person.3.fill")
                                .font(.headline)
                            
                            ForEach(multiplayerManager.connectedPlayers, id: \.self) { playerId in
                                PlayerRow(playerId: playerId)
                            }
                        }
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    if multiplayerManager.currentSession == nil {
                        Button(action: {
                            showingLobby = true
                        }) {
                            Label("Join Multiplayer Game", systemImage: "network")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: {
                            Task {
                                await multiplayerManager.leaveGameSession()
                            }
                        }) {
                            Label("Leave Game", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingLobby) {
            MultiplayerLobbyView()
        }
    }
    
    var latencyStatus: NetworkMetricRow.Status {
        let latency = multiplayerManager.networkMetrics.latency * 1000
        if latency < 50 {
            return .good
        } else if latency < 150 {
            return .warning
        } else {
            return .poor
        }
    }
}

// MARK: - Network Metric Row
struct NetworkMetricRow: View {
    enum Status {
        case good, warning, poor
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .poor: return .red
            }
        }
    }
    
    let label: String
    let value: String
    let status: Status
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Player Row
struct PlayerRow: View {
    let playerId: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(playerId.prefix(2)).uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Player \(playerId.prefix(8))")
                    .font(.subheadline)
                
                Text("Active • 125 ships")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "wifi")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        (icon: "ferry.fill", label: "Fleet"),
        (icon: "building.2.fill", label: "Ports"),
        (icon: "chart.line.uptrend.xyaxis", label: "Economy"),
        (icon: "network", label: "Multiplayer")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.title3)
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                        
                        Text(tabs[index].label)
                            .font(.caption2)
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == index ?
                        Color.blue.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .overlay(
            Divider()
                .frame(maxHeight: 0.5)
                .background(Color(.separator)),
            alignment: .top
        )
    }
}

// MARK: - Ship Detail Sheet
struct ShipDetailSheet: View {
    let ship: Ship
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Ship Info
                    HStack {
                        Image(systemName: "ferry.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(ship.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Container Ship")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Specifications
                    GroupBox("Specifications") {
                        VStack(spacing: 12) {
                            DetailRow(label: "Capacity", value: "\(ship.capacity) TEU")
                            DetailRow(label: "Speed", value: "\(Int(ship.speed)) knots")
                            DetailRow(label: "Efficiency", value: "\(Int(ship.efficiency * 100))%")
                            DetailRow(label: "Daily Cost", value: "$\(Int(ship.maintenanceCost))")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Current Route
                    GroupBox("Current Route") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Hong Kong", systemImage: "location.circle.fill")
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                                Label("Los Angeles", systemImage: "location.circle")
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Distance: 11,650 km")
                                Spacer()
                                Text("ETA: 18 days")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            // Reassign route
                        }) {
                            Label("Change Route", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            // Sell ship
                        }) {
                            Label("Sell Ship", systemImage: "dollarsign.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ship Details")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}