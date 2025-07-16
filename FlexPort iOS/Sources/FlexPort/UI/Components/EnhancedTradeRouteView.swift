import SwiftUI
import Combine

public struct EnhancedTradeRouteView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showingNewRouteCreator = false
    @State private var selectedRoute: TradeRoute?
    @State private var showingRouteDetails = false
    @State private var searchText = ""
    
    var filteredRoutes: [TradeRoute] {
        if searchText.isEmpty {
            return gameManager.gameState.tradeRoutes
        } else {
            return gameManager.gameState.tradeRoutes.filter { route in
                route.name.localizedCaseInsensitiveContains(searchText) ||
                route.startPort.localizedCaseInsensitiveContains(searchText) ||
                route.endPort.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Back Button
                HStack {
                    VStack(alignment: .leading) {
                        Text("Trade Routes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("\(gameManager.gameState.tradeRoutes.count) active routes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button(action: {
                            showingNewRouteCreator = true
                        }) {
                            Label("New Route", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            gameManager.navigateTo(.game)
                        }) {
                            Label("Back", systemImage: "chevron.left")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                
                // Search and Filter Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search routes...", text: $searchText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button("Filter") {
                        // Add filter functionality
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Route Performance Summary
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        RouteMetricCard(
                            title: "Total Revenue",
                            value: "$\(formatCurrency(calculateTotalRevenue()))",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        RouteMetricCard(
                            title: "Active Ships",
                            value: "\(calculateActiveShips())",
                            icon: "ferry.fill",
                            color: .blue
                        )
                        
                        RouteMetricCard(
                            title: "Avg Profit",
                            value: "\(String(format: "%.1f", calculateAverageProfit()))%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange
                        )
                        
                        RouteMetricCard(
                            title: "Routes at Risk",
                            value: "\(calculateRoutesAtRisk())",
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Routes List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredRoutes.isEmpty {
                            EmptyRouteState()
                        } else {
                            ForEach(filteredRoutes, id: \.id) { route in
                                EnhancedRouteCard(route: route)
                                    .onTapGesture {
                                        selectedRoute = route
                                        showingRouteDetails = true
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewRouteCreator) {
                NewRouteCreatorView()
                    .environmentObject(gameManager)
            }
            .sheet(isPresented: $showingRouteDetails) {
                if let route = selectedRoute {
                    RouteDetailView(route: route)
                        .environmentObject(gameManager)
                }
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
    
    private func calculateTotalRevenue() -> Double {
        return filteredRoutes.reduce(0) { total, route in
            total + (route.profitMargin * 10000) // Simplified calculation
        }
    }
    
    private func calculateActiveShips() -> Int {
        return filteredRoutes.reduce(0) { total, route in
            total + route.assignedShips.count
        }
    }
    
    private func calculateAverageProfit() -> Double {
        guard !filteredRoutes.isEmpty else { return 0 }
        let totalProfit = filteredRoutes.reduce(0) { $0 + $1.profitMargin }
        return totalProfit / Double(filteredRoutes.count)
    }
    
    private func calculateRoutesAtRisk() -> Int {
        return filteredRoutes.filter { $0.profitMargin < 10.0 }.count
    }
}

struct RouteMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct EnhancedRouteCard: View {
    let route: TradeRoute
    @State private var showingRiskAlert = false
    
    private var riskLevel: RiskLevel {
        if route.profitMargin < 5 {
            return .high
        } else if route.profitMargin < 15 {
            return .medium
        } else {
            return .low
        }
    }
    
    enum RiskLevel {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
        
        var text: String {
            switch self {
            case .low: return "Low Risk"
            case .medium: return "Medium Risk"
            case .high: return "High Risk"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Route Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(route.startPort)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(route.endPort)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", route.profitMargin))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(riskLevel.color)
                    
                    Text("Profit Margin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Route Stats
            HStack(spacing: 20) {
                RouteStatItem(
                    icon: "ferry.fill",
                    value: "\(route.assignedShips.count)",
                    label: "Ships"
                )
                
                RouteStatItem(
                    icon: "shippingbox.fill",
                    value: route.goodsType,
                    label: "Cargo"
                )
                
                RouteStatItem(
                    icon: "clock.fill",
                    value: "5 days",
                    label: "Duration"
                )
                
                Spacer()
                
                // Risk Indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(riskLevel.color)
                        .frame(width: 8, height: 8)
                    Text(riskLevel.text)
                        .font(.caption)
                        .foregroundColor(riskLevel.color)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Optimize") {
                    optimizeRoute()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
                
                Button("Assign Ship") {
                    // Assign ship action
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(6)
                
                Spacer()
                
                if riskLevel == .high {
                    Button("⚠️ Risk Alert") {
                        showingRiskAlert = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .alert("Route Risk Alert", isPresented: $showingRiskAlert) {
            Button("OK") { }
        } message: {
            Text("This route has a profit margin below 5%. Consider reviewing cargo pricing or operational efficiency.")
        }
    }
    
    private func optimizeRoute() {
        // Trigger route optimization with haptic feedback
        AdvancedHapticManager.shared.playSuccessHaptic(intensity: 0.6)
        
        // Play optimization sound
        SpatialAudioEngine.shared.playSound(
            "optimization_complete",
            at: SIMD3<Float>(0, 0, 0),
            volume: 0.5
        )
        
        print("Optimizing route: \(route.name)")
    }
}

struct RouteStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}

struct EmptyRouteState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Trade Routes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first trade route to start earning revenue from shipping operations.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Route") {
                // Trigger new route creation
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
}

struct NewRouteCreatorView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    @State private var routeName = ""
    @State private var startPort = "Singapore"
    @State private var endPort = "Los Angeles"
    @State private var cargoType = "General Cargo"
    @State private var estimatedProfit = 18.5
    
    let availablePorts = ["Singapore", "Hong Kong", "Shanghai", "Los Angeles", "New York", "London", "Dubai", "Rotterdam", "Hamburg", "Tokyo"]
    let cargoTypes = ["General Cargo", "Containers", "Bulk", "Refrigerated", "Hazardous", "Automotive", "Electronics"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Route Information") {
                    TextField("Route Name", text: $routeName)
                    
                    Picker("Start Port", selection: $startPort) {
                        ForEach(availablePorts, id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                    
                    Picker("End Port", selection: $endPort) {
                        ForEach(availablePorts, id: \.self) { port in
                            Text(port).tag(port)
                        }
                    }
                    
                    Picker("Cargo Type", selection: $cargoType) {
                        ForEach(cargoTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section("Route Analysis") {
                    HStack {
                        Text("Estimated Profit Margin")
                        Spacer()
                        Text("\(String(format: "%.1f", estimatedProfit))%")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text("8,420 nautical miles")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Text("14 days")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Risk Level")
                        Spacer()
                        Text("Medium")
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Market Conditions") {
                    HStack {
                        Text("Demand")
                        Spacer()
                        HStack {
                            ForEach(0..<4) { _ in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    HStack {
                        Text("Competition")
                        Spacer()
                        HStack {
                            ForEach(0..<2) { _ in
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                            }
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Create Route") {
                        createRoute()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("New Trade Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            generateRouteName()
        }
    }
    
    private func generateRouteName() {
        if routeName.isEmpty {
            routeName = "Route \(startPort) → \(endPort)"
        }
    }
    
    private func createRoute() {
        let newRoute = TradeRoute(
            id: UUID(),
            name: routeName.isEmpty ? "Route \(startPort) → \(endPort)" : routeName,
            startPort: startPort,
            endPort: endPort,
            assignedShips: [],
            goodsType: cargoType,
            profitMargin: estimatedProfit
        )
        
        gameManager.gameState.tradeRoutes.append(newRoute)
        
        // Trigger success haptic
        AdvancedHapticManager.shared.playSuccessHaptic(intensity: 0.8)
        
        // Play creation sound
        SpatialAudioEngine.shared.playSound(
            "route_created",
            at: SIMD3<Float>(0, 0, 0),
            volume: 0.6
        )
        
        dismiss()
    }
}

struct RouteDetailView: View {
    let route: TradeRoute
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Route Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(route.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label(route.startPort, systemImage: "location.circle")
                            Image(systemName: "arrow.right")
                            Label(route.endPort, systemImage: "location.circle.fill")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Performance Metrics
                    GroupBox("Performance") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Profit Margin")
                                Spacer()
                                Text("\(String(format: "%.1f", route.profitMargin))%")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Total Revenue (30 days)")
                                Spacer()
                                Text("$425,000")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Assigned Ships")
                                Spacer()
                                Text("\(route.assignedShips.count)")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Cargo Type")
                                Spacer()
                                Text(route.goodsType)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Route Analytics
                    GroupBox("Analytics") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Route Efficiency")
                                .font(.headline)
                            
                            // Simple efficiency bar
                            HStack {
                                Text("Efficiency")
                                    .font(.caption)
                                Spacer()
                                ProgressView(value: 0.75)
                                    .frame(width: 100)
                                Text("75%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("On-time Delivery")
                                    .font(.caption)
                                Spacer()
                                ProgressView(value: 0.92)
                                    .frame(width: 100)
                                Text("92%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Fuel Efficiency")
                                    .font(.caption)
                                Spacer()
                                ProgressView(value: 0.68)
                                    .frame(width: 100)
                                Text("68%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Optimize Route") {
                            optimizeRoute()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        
                        Button("Edit Route") {
                            // Edit route
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Pause Route") {
                            // Pause route
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.orange)
                    }
                    .padding()
                }
            }
            .navigationTitle("Route Details")
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
    
    private func optimizeRoute() {
        // Trigger optimization with haptic feedback
        AdvancedHapticManager.shared.playSuccessHaptic(intensity: 0.7)
        
        // Play optimization sound
        SpatialAudioEngine.shared.playSound(
            "route_optimized",
            at: SIMD3<Float>(0, 0, 0),
            volume: 0.5
        )
        
        print("Optimizing route: \(route.name)")
    }
}