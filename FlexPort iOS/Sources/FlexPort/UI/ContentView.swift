import SwiftUI

public enum GameScreen {
    case mainMenu
    case game
    case settings
    case financialDashboard
    case fleetManagement
    case researchTree
    case tradeRoutes
}

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            switch gameManager.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .game:
                GameView()
            case .settings:
                SettingsView()
            case .financialDashboard:
                // EnhancedFinancialDashboardView()
                FinancialDashboardPlaceholder()
            case .fleetManagement:
                InlineFleetManagementView()
            case .researchTree:
                // ResearchTreeView()
                ResearchTreePlaceholder()
            case .tradeRoutes:
                // EnhancedTradeRouteView()
                TradeRoutePlaceholder()
            }
        }
    }
}

// MARK: - Temporary Placeholder Views

struct FinancialDashboardPlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Financial Dashboard")
                .font(.largeTitle)
                .padding()
            
            Text("Financial overview coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct FleetManagementPlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Fleet Management")
                .font(.largeTitle)
                .padding()
            
            Text("Fleet management coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct ResearchTreePlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Research Tree")
                .font(.largeTitle)
                .padding()
            
            Text("Research tree coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct TradeRoutePlaceholder: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack {
            Text("Trade Routes")
                .font(.largeTitle)
                .padding()
            
            Text("Trade routes coming soon!")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back to Game") {
                gameManager.navigateTo(.game)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}


// MARK: - Inline Fleet Management View

struct InlineFleetManagementView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedShip: Ship?
    @State private var showingShipDetails = false
    @State private var showingPurchaseView = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Fleet Summary with Back Button
                HStack {
                    VStack(alignment: .leading) {
                        Text("Fleet Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(gameManager.gameState.playerAssets.ships.count) Ships")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button(action: {
                            showingPurchaseView = true
                        }) {
                            Label("Buy Ship", systemImage: "plus.circle.fill")
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
                
                // Ship List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(gameManager.gameState.playerAssets.ships, id: \.id) { ship in
                            InlineShipCard(ship: ship, isSelected: selectedShip?.id == ship.id)
                                .onTapGesture {
                                    selectedShip = ship
                                    showingShipDetails = true
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingShipDetails) {
                if let ship = selectedShip {
                    InlineShipDetailView(ship: ship)
                }
            }
            .sheet(isPresented: $showingPurchaseView) {
                InlineShipPurchaseView()
            }
        }
    }
}

struct InlineShipCard: View {
    let ship: Ship
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Ship Icon
            Image(systemName: "ferry.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ship.name)
                    .font(.headline)
                
                HStack {
                    Label("\(ship.capacity) TEU", systemImage: "shippingbox.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(Int(ship.speed)) knots", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Maintenance: $\(Int(ship.maintenanceCost))/day")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Ship Status
            VStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Active")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct InlineShipDetailView: View {
    let ship: Ship
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Ship Header
                    HStack {
                        Image(systemName: "ferry.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(ship.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Container Ship")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Ship Stats
                    GroupBox("Specifications") {
                        VStack(spacing: 12) {
                            InlineStatRow(label: "Capacity", value: "\(ship.capacity) TEU")
                            InlineStatRow(label: "Speed", value: "\(Int(ship.speed)) knots")
                            InlineStatRow(label: "Efficiency", value: "\(Int(ship.efficiency * 100))%")
                            InlineStatRow(label: "Daily Maintenance", value: "$\(Int(ship.maintenanceCost))")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Current Route
                    GroupBox("Current Route") {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Hong Kong")
                            Image(systemName: "arrow.right")
                            Text("Singapore")
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            // Assign to route
                        }) {
                            Label("Assign to Route", systemImage: "map")
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

struct InlineStatRow: View {
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

struct InlineShipPurchaseView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(gameManager.gameState.markets.assetMarket.availableShips, id: \.id) { ship in
                        InlineShipPurchaseCard(ship: ship)
                    }
                }
                .padding()
            }
            .navigationTitle("Ship Market")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InlineShipPurchaseCard: View {
    let ship: Ship
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(ship.name)
                    .font(.headline)
                Spacer()
                Text("$1,250,000") // Placeholder price
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 20) {
                Label("\(ship.capacity) TEU", systemImage: "shippingbox.fill")
                Label("\(Int(ship.speed)) kn", systemImage: "speedometer")
                Label("\(Int(ship.efficiency * 100))%", systemImage: "leaf.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button(action: {
                // Purchase ship
                let newShip = Ship(
                    name: ship.name + " " + String(gameManager.gameState.playerAssets.ships.count + 1),
                    capacity: ship.capacity,
                    speed: ship.speed,
                    efficiency: ship.efficiency,
                    maintenanceCost: ship.maintenanceCost
                )
                gameManager.gameState.playerAssets.ships.append(newShip)
                gameManager.gameState.playerAssets.money -= 1250000
            }) {
                Text("Purchase")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(gameManager.gameState.playerAssets.money < 1250000)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
